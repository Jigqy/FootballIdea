--[[
	FootballIdea - Play-Calling Prototype
	=====================================

	A single-file, plain-Lua prototype of the core play-calling mechanic
	described in GAME_DESIGN.md: blind simultaneous calls, resolved by a
	4x4 matchup matrix + team stats + chemistry + down-and-distance, with
	no live/twitch skill component.

	Run it from a terminal with:

		lua5.3 prototype/playcalling.lua

	You play a full "Quick Drive" style match against a CPU opponent
	(3 possessions each). Whichever team has the ball, YOU make that
	side's call (offense when you have the ball, defense when the CPU
	does) so you can feel both sides of the matchup matrix. The CPU always
	controls the other side, using the v1 context-aware AI logic from the
	design doc (down/distance-aware, not adaptive yet).

	This file has no Roblox API dependency on purpose - it's meant to
	prove out the resolution math before any of it touches Roblox/Rojo.
]]

math.randomseed(os.time())
local rng = math.random

--------------------------------------------------------------------------
-- MATCHUP MATRIX
--------------------------------------------------------------------------

local OFFENSE_CATEGORIES = { "run", "quick", "medium", "deep" }
local DEFENSE_CATEGORIES = { "stack_box", "blitz", "man", "zone" }

local CATEGORY_LABELS = {
	run = "Run",
	quick = "Quick Pass",
	medium = "Medium Pass",
	deep = "Deep Pass",
	stack_box = "Stack the Box",
	blitz = "Blitz",
	man = "Man Coverage",
	zone = "Zone Coverage",
}

-- { mean, spread, turnover } - see GAME_DESIGN.md's matchup matrix table.
local MATCHUP_BASELINE = {
	run = {
		stack_box = { mean = 0.5, spread = 2.5, turnover = 0.02 },
		blitz = { mean = 6.0, spread = 4.0, turnover = 0.01 },
		man = { mean = 4.0, spread = 3.5, turnover = 0.01 },
		zone = { mean = 3.5, spread = 3.5, turnover = 0.01 },
	},
	quick = {
		stack_box = { mean = 5.0, spread = 3.0, turnover = 0.01 },
		blitz = { mean = 8.0, spread = 4.5, turnover = 0.01 },
		man = { mean = 4.0, spread = 3.5, turnover = 0.02 },
		zone = { mean = 1.5, spread = 2.5, turnover = 0.03 },
	},
	medium = {
		stack_box = { mean = 7.0, spread = 4.0, turnover = 0.01 },
		blitz = { mean = 4.5, spread = 7.0, turnover = 0.05 },
		man = { mean = 2.0, spread = 3.5, turnover = 0.04 },
		zone = { mean = 4.5, spread = 5.0, turnover = 0.03 },
	},
	deep = {
		stack_box = { mean = 15.0, spread = 9.0, turnover = 0.02 },
		blitz = { mean = -2.0, spread = 5.0, turnover = 0.06 },
		man = { mean = 6.0, spread = 11.0, turnover = 0.08 },
		zone = { mean = 1.0, spread = 6.0, turnover = 0.07 },
	},
}

local RELEVANT_STATS = {
	offense = { run = "runOff", quick = "quickOff", medium = "mediumOff", deep = "deepOff" },
	defense = { stack_box = "boxDef", blitz = "blitzDef", man = "manDef", zone = "zoneDef" },
}
local STAT_SCALE = 0.12 -- yards of mean shift per rating point of differential

--------------------------------------------------------------------------
-- DOWN & DISTANCE
--------------------------------------------------------------------------

local function getZone(down, yardsToGo, isRedZone)
	if isRedZone then
		return "redzone"
	elseif yardsToGo <= 3 then
		return "short"
	elseif yardsToGo <= 7 then
		return "medium"
	else
		return "long"
	end
end

local function getDownDistanceModifier(zone, offenseCategory, defenseCategory)
	local delta, spreadMult = 0, 1.0

	if zone == "short" then
		if offenseCategory == "run" then
			delta = delta + 1.5
			if defenseCategory == "stack_box" then
				delta = delta - 3.0
			end
		end
	elseif zone == "long" then
		if offenseCategory == "quick" then
			delta = delta + 1.0
		end
		if defenseCategory == "blitz" then
			spreadMult = spreadMult * 1.3
		end
	elseif zone == "redzone" then
		if offenseCategory == "deep" then
			delta = delta - 6.0
		end
		if defenseCategory == "man" or defenseCategory == "zone" then
			delta = delta - 1.5
		end
		if offenseCategory == "run" and defenseCategory == "stack_box" then
			delta = delta - 1.0
		end
	end

	return delta, spreadMult
end

--------------------------------------------------------------------------
-- CHEMISTRY (the 8 named bonds, scaled not binary)
--------------------------------------------------------------------------

local CHEMISTRY_BONDS = {
	{ id = "power_unit", side = "offense", category = "run", maxBoost = 0.15, requires = { OL = 3, RB = 1, TE = 1 } },
	{ id = "quick_strike", side = "offense", category = "quick", maxBoost = 0.15, requires = { QB = 1, WR = 1 } },
	{ id = "route_tree", side = "offense", category = "medium", maxBoost = 0.15, requires = { QB = 1, WR = 1, TE = 1 } },
	{ id = "deep_threat", side = "offense", category = "deep", maxBoost = 0.18, requires = { QB = 1, WR = 1 } },
	{ id = "run_stoppers", side = "defense", category = "stack_box", maxBoost = 0.15, requires = { DL = 2, LB = 2 } },
	{ id = "blitz_package", side = "defense", category = "blitz", maxBoost = 0.15, requires = { LB = 2, DL = 1 } },
	{ id = "lockdown_corners", side = "defense", category = "man", maxBoost = 0.15, requires = { CB = 2, S = 1 } },
	{ id = "shutdown_zone", side = "defense", category = "zone", maxBoost = 0.15, requires = { S = 1, LB = 1, CB = 1 } },
}

local function summarizeRoster(roster)
	local counts, ratingSums = {}, {}
	for _, card in ipairs(roster) do
		counts[card.position] = (counts[card.position] or 0) + 1
		ratingSums[card.position] = (ratingSums[card.position] or 0) + card.rating
	end
	return counts, ratingSums
end

local function computeChemistryModifiers(offenseRoster, defenseRoster)
	local offenseCounts, offenseRatingSums = summarizeRoster(offenseRoster)
	local defenseCounts, defenseRatingSums = summarizeRoster(defenseRoster)
	local counts = { offense = offenseCounts, defense = defenseCounts }
	local ratingSums = { offense = offenseRatingSums, defense = defenseRatingSums }

	local modifiers = {}
	for _, bond in ipairs(CHEMISTRY_BONDS) do
		local sideCounts = counts[bond.side]
		local sideRatingSums = ratingSums[bond.side]

		local fillTotal, requirementCount = 0, 0
		local ratingTotal, ratingCount = 0, 0
		for position, needed in pairs(bond.requires) do
			requirementCount = requirementCount + 1
			local have = sideCounts[position] or 0
			fillTotal = fillTotal + math.min(have, needed) / needed
			if have > 0 then
				ratingTotal = ratingTotal + (sideRatingSums[position] or 0)
				ratingCount = ratingCount + math.min(have, needed)
			end
		end

		local fillFraction = fillTotal / requirementCount
		local avgRating = ratingCount > 0 and (ratingTotal / ratingCount) or 0
		local qualityFactor = 0.5 + 0.5 * (avgRating / 99)
		local boost = bond.maxBoost * fillFraction * qualityFactor
		modifiers[bond.category] = (modifiers[bond.category] or 0) + boost
	end
	return modifiers
end

--------------------------------------------------------------------------
-- RESOLVER
--------------------------------------------------------------------------

-- Irwin-Hall-style approximation of a bell curve: average a few uniforms
-- and re-center, instead of needing a real Gaussian sampler.
local function randomSpread(spread)
	local sum = rng() + rng() + rng()
	local unit = (sum / 3 - 0.5) * 2
	return unit * spread
end

local function resolvePlay(offenseCategory, defenseCategory, gameState, offenseTeam, defenseTeam)
	local base = MATCHUP_BASELINE[offenseCategory][defenseCategory]

	local offenseStat = offenseTeam[RELEVANT_STATS.offense[offenseCategory]] or 50
	local defenseStat = defenseTeam[RELEVANT_STATS.defense[defenseCategory]] or 50
	local statDelta = (offenseStat - defenseStat) * STAT_SCALE

	local zone = getZone(gameState.down, gameState.yardsToGo, gameState.isRedZone)
	local ddDelta, spreadMult = getDownDistanceModifier(zone, offenseCategory, defenseCategory)

	local chemMods = computeChemistryModifiers(offenseTeam.roster, defenseTeam.roster)
	local offenseChem = chemMods[offenseCategory] or 0
	local defenseChem = chemMods[defenseCategory] or 0

	local mean = (base.mean + statDelta + ddDelta) * (1 + offenseChem) * (1 - defenseChem)
	local spread = base.spread * spreadMult

	local yards = math.floor(mean + randomSpread(spread) + 0.5)
	local turnover = rng() < base.turnover

	local outcomeBand
	if turnover then
		outcomeBand = "TURNOVER"
		yards = math.min(yards, 0)
	elseif yards <= 0 then
		outcomeBand = "stuffed"
	elseif yards < 4 then
		outcomeBand = "short gain"
	elseif yards < 12 then
		outcomeBand = "gain"
	elseif yards < 25 then
		outcomeBand = "EXPLOSIVE"
	else
		outcomeBand = "BIG PLAY"
	end

	return { yards = yards, outcomeBand = outcomeBand, turnover = turnover, zone = zone }
end

--------------------------------------------------------------------------
-- TEAM PRESETS
--------------------------------------------------------------------------

local userTeam = {
	name = "Ironclad",
	runOff = 70, quickOff = 62, mediumOff = 64, deepOff = 60,
	boxDef = 62, blitzDef = 58, manDef = 60, zoneDef = 63,
	roster = {
		{ position = "QB", rating = 68 },
		{ position = "RB", rating = 78 },
		{ position = "WR", rating = 65 }, { position = "WR", rating = 63 },
		{ position = "TE", rating = 74 },
		{ position = "OL", rating = 80 }, { position = "OL", rating = 78 }, { position = "OL", rating = 76 },
		{ position = "DL", rating = 64 }, { position = "DL", rating = 62 },
		{ position = "LB", rating = 66 }, { position = "LB", rating = 64 },
		{ position = "CB", rating = 60 }, { position = "CB", rating = 58 },
		{ position = "S", rating = 61 },
	},
}

local cpuTeam = {
	name = "Blitzers",
	runOff = 60, quickOff = 72, mediumOff = 68, deepOff = 74,
	boxDef = 58, blitzDef = 76, manDef = 68, zoneDef = 65,
	roster = {
		{ position = "QB", rating = 82 },
		{ position = "RB", rating = 64 },
		{ position = "WR", rating = 80 }, { position = "WR", rating = 76 },
		{ position = "TE", rating = 62 },
		{ position = "OL", rating = 66 }, { position = "OL", rating = 64 }, { position = "OL", rating = 63 },
		{ position = "DL", rating = 74 }, { position = "DL", rating = 72 },
		{ position = "LB", rating = 78 }, { position = "LB", rating = 75 },
		{ position = "CB", rating = 70 }, { position = "CB", rating = 68 },
		{ position = "S", rating = 71 },
	},
}

--------------------------------------------------------------------------
-- v1 CONTEXT-AWARE AI (down/distance-aware, not adaptive - see GAME_DESIGN.md)
--------------------------------------------------------------------------

local AI_OFFENSE_WEIGHTS = {
	short = { { key = "run", w = 0.60 }, { key = "quick", w = 0.20 }, { key = "medium", w = 0.15 }, { key = "deep", w = 0.05 } },
	medium = { { key = "run", w = 0.30 }, { key = "quick", w = 0.25 }, { key = "medium", w = 0.25 }, { key = "deep", w = 0.20 } },
	long = { { key = "run", w = 0.10 }, { key = "quick", w = 0.35 }, { key = "medium", w = 0.30 }, { key = "deep", w = 0.25 } },
	redzone = { { key = "run", w = 0.35 }, { key = "quick", w = 0.30 }, { key = "medium", w = 0.25 }, { key = "deep", w = 0.10 } },
}

local AI_DEFENSE_WEIGHTS = {
	short = { { key = "stack_box", w = 0.55 }, { key = "blitz", w = 0.20 }, { key = "man", w = 0.15 }, { key = "zone", w = 0.10 } },
	medium = { { key = "stack_box", w = 0.20 }, { key = "blitz", w = 0.25 }, { key = "man", w = 0.25 }, { key = "zone", w = 0.30 } },
	long = { { key = "stack_box", w = 0.10 }, { key = "blitz", w = 0.30 }, { key = "man", w = 0.25 }, { key = "zone", w = 0.35 } },
	redzone = { { key = "stack_box", w = 0.30 }, { key = "blitz", w = 0.20 }, { key = "man", w = 0.25 }, { key = "zone", w = 0.25 } },
}

local function pickWeighted(weights)
	local roll, cumulative = rng(), 0
	for _, entry in ipairs(weights) do
		cumulative = cumulative + entry.w
		if roll <= cumulative then
			return entry.key
		end
	end
	return weights[#weights].key
end

local function aiChooseOffense(zone)
	return pickWeighted(AI_OFFENSE_WEIGHTS[zone])
end

local function aiChooseDefense(zone)
	return pickWeighted(AI_DEFENSE_WEIGHTS[zone])
end

--------------------------------------------------------------------------
-- CLI HELPERS
--------------------------------------------------------------------------

local function readMenuChoice(max)
	while true do
		io.write("> ")
		io.flush()
		local line = io.read("*l")
		local n = tonumber(line)
		if n and n >= 1 and n <= max then
			return math.floor(n)
		end
		print("  Enter a number from 1 to " .. max .. ".")
	end
end

local function promptOffenseCategory()
	print("  1) Run          2) Quick Pass     3) Medium Pass    4) Deep Pass")
	local choice = readMenuChoice(4)
	return OFFENSE_CATEGORIES[choice]
end

local function promptDefenseCategory()
	print("  1) Stack the Box 2) Blitz          3) Man Coverage   4) Zone Coverage")
	local choice = readMenuChoice(4)
	return DEFENSE_CATEGORIES[choice]
end

local function describeSituation(offenseName, down, yardsToGo, ballOn)
	local yardLine = ballOn <= 50 and (offenseName .. " " .. ballOn) or ("OPP " .. (100 - ballOn))
	print(string.format("\n%s ball, %s down & %d, at %s", offenseName, ({ "1st", "2nd", "3rd", "4th" })[down], yardsToGo, yardLine))
end

local function flipFieldPosition(ballOn)
	return math.max(2, math.min(98, 100 - ballOn))
end

-- Where the receiving team starts after a punt, in their own frame.
local function puntResultBallOn(ballOn)
	local kickSpot = math.min(ballOn + 40, 98)
	if kickSpot >= 90 then
		return 25 -- ball would've gone into the end zone: touchback
	end
	return flipFieldPosition(kickSpot)
end

local function attemptFieldGoal(ballOn)
	local distance = (100 - ballOn) + 17
	local chance = math.max(0.05, math.min(0.95, 0.95 - (distance - 20) * 0.012))
	local good = rng() < chance
	print(string.format("  %d-yard field goal attempt... %s", distance, good and "GOOD!" or "NO GOOD."))
	return good
end

--------------------------------------------------------------------------
-- GAME LOOP (Quick Drive: 3 possessions each)
--------------------------------------------------------------------------

local POSSESSIONS_PER_TEAM = 3
local scores = { user = 0, cpu = 0 }
local nextBallOn = 25 -- kickoff touchback to start the match

print("==================================================================")
print(" FootballIdea - Play-Calling Prototype")
print("==================================================================")
print(("You are calling plays for the %s. The %s (CPU) call the other side."):format(userTeam.name, cpuTeam.name))
print("You make the call for whichever side has the ball: offense when you")
print("have it, defense when the CPU does. " .. POSSESSIONS_PER_TEAM .. " possessions each - most points wins.")

for possessionIndex = 1, POSSESSIONS_PER_TEAM * 2 do
	local userHasBall = (possessionIndex % 2 == 1)
	local offenseTeam, defenseTeam
	local offenseName, defenseName
	if userHasBall then
		offenseTeam, defenseTeam = userTeam, cpuTeam
		offenseName, defenseName = "You", "CPU"
	else
		offenseTeam, defenseTeam = cpuTeam, userTeam
		offenseName, defenseName = "CPU", "You"
	end

	print(string.format("\n---------------- Possession %d/%d: %s ball ----------------", possessionIndex, POSSESSIONS_PER_TEAM * 2, offenseName))

	local down, yardsToGo, ballOn = 1, 10, nextBallOn
	local possessionOver = false

	while not possessionOver do
		local isRedZone = ballOn >= 80
		local zone = getZone(down, yardsToGo, isRedZone)
		describeSituation(offenseName, down, yardsToGo, ballOn)

		if down == 4 then
			local canKick = ballOn >= 65
			if userHasBall then
				print("  4th down. What's the call?")
				print("  1) Punt" .. (canKick and "          2) Field Goal     3) Go for it" or "                             2) Go for it"))
				local maxChoice = canKick and 3 or 2
				local choice = readMenuChoice(maxChoice)
				if choice == 1 then
					nextBallOn = puntResultBallOn(ballOn)
					print("  You punt it away.")
					possessionOver = true
				elseif (choice == 2 and canKick) then
					if attemptFieldGoal(ballOn) then
						scores.user = scores.user + 3
						nextBallOn = 25
					else
						nextBallOn = flipFieldPosition(ballOn)
					end
					possessionOver = true
				end
				-- choice == "go for it" (2 without kick, or 3 with kick) falls through to a normal play call below
				if possessionOver then
					break
				end
			else
				-- Simple CPU heuristic: kick if in range, otherwise punt unless it's very short yardage deep in your territory.
				if canKick then
					print("  CPU sends out the kicking unit.")
					if attemptFieldGoal(ballOn) then
						scores.cpu = scores.cpu + 3
						nextBallOn = 25
					else
						nextBallOn = flipFieldPosition(ballOn)
					end
					possessionOver = true
					break
				elseif yardsToGo > 2 or ballOn < 40 then
					nextBallOn = puntResultBallOn(ballOn)
					print("  CPU punts it away.")
					possessionOver = true
					break
				end
				-- else: CPU goes for it, falls through
			end
		end

		local offenseCategory, defenseCategory
		if userHasBall then
			print("  Your play call:")
			offenseCategory = promptOffenseCategory()
			defenseCategory = aiChooseDefense(zone)
		else
			offenseCategory = aiChooseOffense(zone)
			print("  Your defensive call:")
			defenseCategory = promptDefenseCategory()
		end

		local wasFourthDown = (down == 4)
		local result = resolvePlay(offenseCategory, defenseCategory, { down = down, yardsToGo = yardsToGo, isRedZone = isRedZone }, offenseTeam, defenseTeam)

		print(string.format("  %s: %s vs %s -> %d yards (%s)", offenseName, CATEGORY_LABELS[offenseCategory], CATEGORY_LABELS[defenseCategory], result.yards, result.outcomeBand))

		if result.turnover then
			print(string.format("  TURNOVER! %s takes over.", defenseName))
			nextBallOn = flipFieldPosition(ballOn)
			possessionOver = true
			break
		end

		ballOn = ballOn + result.yards
		if ballOn >= 100 then
			print(string.format("  TOUCHDOWN, %s!", offenseName))
			if userHasBall then
				scores.user = scores.user + 7
			else
				scores.cpu = scores.cpu + 7
			end
			nextBallOn = 25
			possessionOver = true
			break
		end
		ballOn = math.max(1, ballOn)

		local remaining = yardsToGo - result.yards
		if remaining <= 0 then
			down = 1
			yardsToGo = math.min(10, 100 - ballOn)
		elseif wasFourthDown then
			print(string.format("  Turnover on downs. %s takes over.", defenseName))
			nextBallOn = flipFieldPosition(ballOn)
			possessionOver = true
			break
		else
			down = down + 1
			yardsToGo = remaining
		end
	end

	print(string.format("  SCORE -> You: %d   CPU: %d", scores.user, scores.cpu))
end

print("\n==================================================================")
print(string.format("FINAL SCORE -> You: %d   CPU: %d", scores.user, scores.cpu))
if scores.user > scores.cpu then
	print("You win!")
elseif scores.cpu > scores.user then
	print("CPU wins.")
else
	print("It's a tie.")
end
print("==================================================================")

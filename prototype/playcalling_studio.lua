--[[
	FootballIdea - Play-Calling Prototype (Roblox Studio Command Bar version)
	==========================================================================

	HOW TO RUN: In Roblox Studio, open View > Command Bar, paste this whole
	script in, and press Enter. Output prints to the Output window
	(View > Output).

	Why this is a different file from prototype/playcalling.lua: that one
	is written for a real terminal (it uses io.read/io.write to prompt you
	down-by-down). Roblox's Luau sandbox has no io library and the Command
	Bar can't pause mid-script to wait for typed input - it just runs the
	whole script front-to-back and prints whatever it prints. So this
	version auto-simulates the entire game in one go instead of prompting
	you play-by-play.

	To steer YOUR team's calls instead of letting the AI make every
	decision, fill in USER_OFFENSE_CALLS / USER_DEFENSE_CALLS below before
	running - they're consumed in order, one per down your team faces on
	that side of the ball, and the AI fills in once the list runs out.
	Leave both empty to just watch a full AI vs AI game.
]]

-- EDIT THESE to steer your team's calls, in order. Valid entries:
--   offense: "run", "quick", "medium", "deep"
--   defense: "stack_box", "blitz", "man", "zone"
local USER_OFFENSE_CALLS = {} -- e.g. { "run", "run", "quick", "deep" }
local USER_DEFENSE_CALLS = {} -- e.g. { "stack_box", "blitz", "zone" }

local rngSource = Random.new()
local function rng()
	return rngSource:NextNumber()
end

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
local STAT_SCALE = 0.12

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
-- CHEMISTRY
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
-- v1 CONTEXT-AWARE AI
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

-- Pulls the next call from a pre-set list (in order); falls back to the AI
-- once the list is exhausted or empty. `nextIndex` tables track position.
local nextIndex = { offense = 1, defense = 1 }
local function nextUserOffenseCall(zone)
	local call = USER_OFFENSE_CALLS[nextIndex.offense]
	nextIndex.offense = nextIndex.offense + 1
	return call or aiChooseOffense(zone)
end
local function nextUserDefenseCall(zone)
	local call = USER_DEFENSE_CALLS[nextIndex.defense]
	nextIndex.defense = nextIndex.defense + 1
	return call or aiChooseDefense(zone)
end

--------------------------------------------------------------------------
-- FIELD POSITION HELPERS
--------------------------------------------------------------------------

local function flipFieldPosition(ballOn)
	return math.max(2, math.min(98, 100 - ballOn))
end

local function puntResultBallOn(ballOn)
	local kickSpot = math.min(ballOn + 40, 98)
	if kickSpot >= 90 then
		return 25
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

-- Same heuristic for both sides on 4th down, since neither is interactive here.
local function decideFourthDown(ballOn, yardsToGo)
	if ballOn >= 65 then
		return "fg"
	elseif yardsToGo <= 2 and ballOn >= 90 then
		return "go"
	else
		return "punt"
	end
end

--------------------------------------------------------------------------
-- GAME LOOP (Quick Drive: 3 possessions each, fully auto-simulated)
--------------------------------------------------------------------------

local POSSESSIONS_PER_TEAM = 3
local scores = { user = 0, cpu = 0 }
local nextBallOn = 25

print("==================================================================")
print(" FootballIdea - Play-Calling Prototype (Studio auto-sim)")
print("==================================================================")
print(("%s vs %s - %d possessions each."):format(userTeam.name, cpuTeam.name, POSSESSIONS_PER_TEAM))

for possessionIndex = 1, POSSESSIONS_PER_TEAM * 2 do
	local userHasBall = (possessionIndex % 2 == 1)
	local offenseTeam, defenseTeam, offenseName, defenseName
	if userHasBall then
		offenseTeam, defenseTeam = userTeam, cpuTeam
		offenseName, defenseName = userTeam.name, cpuTeam.name
	else
		offenseTeam, defenseTeam = cpuTeam, userTeam
		offenseName, defenseName = cpuTeam.name, userTeam.name
	end

	print(string.format("\n---------------- Possession %d/%d: %s ball ----------------", possessionIndex, POSSESSIONS_PER_TEAM * 2, offenseName))

	local down, yardsToGo, ballOn = 1, 10, nextBallOn
	local possessionOver = false

	while not possessionOver do
		local isRedZone = ballOn >= 80
		local zone = getZone(down, yardsToGo, isRedZone)
		local yardLine = ballOn <= 50 and (offenseName .. " " .. ballOn) or ("OPP " .. (100 - ballOn))
		print(string.format("%s ball, %s down & %d, at %s", offenseName, ({ "1st", "2nd", "3rd", "4th" })[down], yardsToGo, yardLine))

		if down == 4 then
			local decision = decideFourthDown(ballOn, yardsToGo)
			if decision == "punt" then
				nextBallOn = puntResultBallOn(ballOn)
				print(string.format("  %s punts it away.", offenseName))
				possessionOver = true
				break
			elseif decision == "fg" then
				if attemptFieldGoal(ballOn) then
					if userHasBall then scores.user = scores.user + 3 else scores.cpu = scores.cpu + 3 end
					nextBallOn = 25
				else
					nextBallOn = flipFieldPosition(ballOn)
				end
				possessionOver = true
				break
			end
			-- decision == "go": falls through to a normal play call below
		end

		local offenseCategory, defenseCategory
		if userHasBall then
			offenseCategory = nextUserOffenseCall(zone)
			defenseCategory = aiChooseDefense(zone)
		else
			offenseCategory = aiChooseOffense(zone)
			defenseCategory = nextUserDefenseCall(zone)
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
			if userHasBall then scores.user = scores.user + 7 else scores.cpu = scores.cpu + 7 end
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

	print(string.format("  SCORE -> %s: %d   %s: %d", userTeam.name, scores.user, cpuTeam.name, scores.cpu))
end

print("\n==================================================================")
print(string.format("FINAL SCORE -> %s: %d   %s: %d", userTeam.name, scores.user, cpuTeam.name, scores.cpu))
if scores.user > scores.cpu then
	print(userTeam.name .. " win!")
elseif scores.cpu > scores.user then
	print(cpuTeam.name .. " win.")
else
	print("It's a tie.")
end
print("==================================================================")

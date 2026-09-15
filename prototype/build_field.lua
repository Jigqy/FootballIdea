--[[
	FootballIdea - Field & Player Model Builder (Roblox Studio Command Bar)
	=========================================================================

	Paste this into Studio's Command Bar (View > Command Bar) and run it.
	Builds a roughly-scaled football field in Workspace (turf, yard lines,
	end zones, goal posts) and populates it with simple blocky placeholder
	player models lined up in a Singleback offense vs. Base 4-3 defense
	pre-snap alignment at a configurable line of scrimmage.

	This is the visual layer starting point ("watch players physically on
	the field") - it is NOT yet wired up to the play-calling resolver
	prototypes (playcalling.lua / playcalling_studio.lua). It just proves
	out field scale and gives something to look at.

	Re-running this script clears out whatever it built last time first,
	so it's safe to run repeatedly while retuning the numbers below.
]]

local Workspace = game:GetService("Workspace")

-- === TUNABLE CONSTANTS =====================================================

local STUDS_PER_YARD = 3
local FIELD_WIDTH_YARDS = 53
local FIELD_LENGTH_YARDS = 100 -- goal line to goal line
local END_ZONE_YARDS = 10
local LINE_OF_SCRIMMAGE_YARDS = 50 -- from the offense's own goal line

local OFFENSE_COLOR = BrickColor.new("Bright blue")
local DEFENSE_COLOR = BrickColor.new("Really red")
local HEAD_COLOR = BrickColor.new("Light orange")

-- === CLEANUP ===============================================================

local existingField = Workspace:FindFirstChild("FootballField")
if existingField then
	existingField:Destroy()
end

local field = Instance.new("Model")
field.Name = "FootballField"
field.Parent = Workspace

-- === COORDINATE HELPERS ====================================================

local endZoneStuds = END_ZONE_YARDS * STUDS_PER_YARD
local fieldLengthStuds = FIELD_LENGTH_YARDS * STUDS_PER_YARD
local totalLengthStuds = fieldLengthStuds + endZoneStuds * 2
local fieldWidthStuds = FIELD_WIDTH_YARDS * STUDS_PER_YARD

-- World Z for "N yards from the offense's own goal line" (Z=0 is the very
-- back of that end zone).
local function yardsToZ(yardsFromOwnGoal)
	return endZoneStuds + yardsFromOwnGoal * STUDS_PER_YARD
end

-- === FIELD GEOMETRY =========================================================

local function addPart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.BrickColor = color
	part.Parent = parent
	return part
end

addPart("Turf", Vector3.new(fieldWidthStuds, 1, totalLengthStuds), Vector3.new(0, -0.5, totalLengthStuds / 2), BrickColor.new("Earth green"), field)

addPart("EndZone_Own", Vector3.new(fieldWidthStuds, 0.2, endZoneStuds), Vector3.new(0, 0.1, endZoneStuds / 2), DEFENSE_COLOR, field)
addPart("EndZone_Opp", Vector3.new(fieldWidthStuds, 0.2, endZoneStuds), Vector3.new(0, 0.1, totalLengthStuds - endZoneStuds / 2), OFFENSE_COLOR, field)

addPart("Sideline_Left", Vector3.new(0.5, 0.2, totalLengthStuds), Vector3.new(-fieldWidthStuds / 2, 0.1, totalLengthStuds / 2), BrickColor.new("White"), field)
addPart("Sideline_Right", Vector3.new(0.5, 0.2, totalLengthStuds), Vector3.new(fieldWidthStuds / 2, 0.1, totalLengthStuds / 2), BrickColor.new("White"), field)

for yard = 0, FIELD_LENGTH_YARDS, 10 do
	addPart("YardLine_" .. yard, Vector3.new(fieldWidthStuds, 0.2, 0.5), Vector3.new(0, 0.1, yardsToZ(yard)), BrickColor.new("White"), field)
end

local function buildGoalPost(z, parent)
	local post = Instance.new("Model")
	post.Name = "GoalPost"
	post.Parent = parent
	addPart("Base", Vector3.new(1, 10, 1), Vector3.new(0, 5, z), BrickColor.new("Institutional white"), post)
	addPart("Crossbar", Vector3.new(18, 0.6, 0.6), Vector3.new(0, 10, z), BrickColor.new("New Yeller"), post)
	addPart("UprightLeft", Vector3.new(0.6, 12, 0.6), Vector3.new(-9, 16, z), BrickColor.new("New Yeller"), post)
	addPart("UprightRight", Vector3.new(0.6, 12, 0.6), Vector3.new(9, 16, z), BrickColor.new("New Yeller"), post)
end

buildGoalPost(0, field)
buildGoalPost(totalLengthStuds, field)

-- === PLAYER MODELS ==========================================================

local function createPlayerModel(teamColor, positionLabel, parent)
	local model = Instance.new("Model")
	model.Name = positionLabel
	model.Parent = parent

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.BrickColor = teamColor
	torso.Anchored = true
	torso.CanCollide = false
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.BrickColor = HEAD_COLOR
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model

	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.BrickColor = teamColor
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Parent = model

	local rightArm = leftArm:Clone()
	rightArm.Name = "RightArm"
	rightArm.Parent = model

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.BrickColor = BrickColor.new("Black")
	leftLeg.Anchored = true
	leftLeg.CanCollide = false
	leftLeg.Parent = model

	local rightLeg = leftLeg:Clone()
	rightLeg.Name = "RightLeg"
	rightLeg.Parent = model

	local label = Instance.new("BillboardGui")
	label.Name = "PositionLabel"
	label.Size = UDim2.new(0, 60, 0, 24)
	label.StudsOffset = Vector3.new(0, 1.4, 0)
	label.AlwaysOnTop = true
	label.Parent = head

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.SourceSansBold
	text.TextScaled = true
	text.Text = positionLabel
	text.Parent = label

	model.PrimaryPart = torso
	return model, { torso = torso, head = head, leftArm = leftArm, rightArm = rightArm, leftLeg = leftLeg, rightLeg = rightLeg }
end

-- Positions all six parts relative to a standing CFrame, then welds them so
-- the whole model can be moved as one rigid unit afterward.
local function standPlayerAt(parts, cframe)
	parts.leftLeg.CFrame = cframe * CFrame.new(-0.5, 1, 0)
	parts.rightLeg.CFrame = cframe * CFrame.new(0.5, 1, 0)
	parts.torso.CFrame = cframe * CFrame.new(0, 3, 0)
	parts.head.CFrame = cframe * CFrame.new(0, 4.7, 0)
	parts.leftArm.CFrame = cframe * CFrame.new(-1.5, 3, 0)
	parts.rightArm.CFrame = cframe * CFrame.new(1.5, 3, 0)

	for name, part in pairs(parts) do
		if name ~= "torso" then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = parts.torso
			weld.Part1 = part
			weld.Parent = parts.torso
		end
	end
end

-- x, z in YARDS. facingTowardOpponentGoal = true faces increasing yard
-- count (toward the far end zone), false faces back the other way.
local function placePlayer(teamColor, positionLabel, xYards, zYards, facingTowardOpponentGoal, parent)
	local model, parts = createPlayerModel(teamColor, positionLabel, parent)
	local worldX = xYards * STUDS_PER_YARD
	local worldZ = yardsToZ(zYards)
	local lookDirection = facingTowardOpponentGoal and 0 or math.pi
	local cframe = CFrame.new(worldX, 0, worldZ) * CFrame.Angles(0, lookDirection, 0)
	standPlayerAt(parts, cframe)
	return model
end

local offenseFolder = Instance.new("Folder")
offenseFolder.Name = "Offense"
offenseFolder.Parent = field

local defenseFolder = Instance.new("Folder")
defenseFolder.Name = "Defense"
defenseFolder.Parent = field

local los = LINE_OF_SCRIMMAGE_YARDS

-- Offense: Singleback, 11 personnel (1 QB, 1 RB, 1 TE, 3 WR, 5 OL), facing
-- toward the opponent's goal line.
placePlayer(OFFENSE_COLOR, "C", 0, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "OL", -3, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "OL", 3, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "OL", -6, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "OL", 6, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "TE", 8, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "QB", 0, los - 3, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "RB", 0, los - 7, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "WR", -22, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "WR", 14, los, true, offenseFolder)
placePlayer(OFFENSE_COLOR, "WR", 22, los, true, offenseFolder)

-- Defense: Base 4-3 (4 DL, 3 LB, 2 CB, 2 S), facing back toward the line
-- of scrimmage.
placePlayer(DEFENSE_COLOR, "DL", -4.5, los + 1, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "DL", -1.5, los + 1, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "DL", 1.5, los + 1, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "DL", 4.5, los + 1, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "LB", -8, los + 5, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "LB", 0, los + 5, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "LB", 8, los + 5, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "CB", -22, los + 6, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "CB", 22, los + 6, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "S", -10, los + 12, false, defenseFolder)
placePlayer(DEFENSE_COLOR, "S", 10, los + 12, false, defenseFolder)

print(("Built FootballField with %d offense and %d defense placeholders at the %d-yard line."):format(#offenseFolder:GetChildren(), #defenseFolder:GetChildren(), los))

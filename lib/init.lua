--[[
    Author: cSunix (Nick)
    Description: Handles checking permissions.
]]

type Permission = ModuleScript | string | { [number | string]: string | boolean }

---------------------------------------
-- //       SERVICES
---------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

---------------------------------------
-- //       DEPENDENCIES
---------------------------------------
local Functions = script.Functions
local Promise = require(script.Parent.promise)

local IsAuthorized = {}
IsAuthorized.__index = IsAuthorized -- ?
IsAuthorized.Groups = {}
IsAuthorized.RequireAllKeyword = "RequireAll"
IsAuthorized.AllKeyword = "All"
IsAuthorized.NegateCharacter = "!"
IsAuthorized.SilenceInwardErrors = true

IsAuthorized.StandardRequestPacket = {
	IsNegated = false,
}

---------------------------------------
-- //       PRIVATE FUNCTIONS
---------------------------------------
-- Similar to the JavaScript array.filter(), simply creates a new
-- table with the elements that match the function.
local function Filter(_table: {}, filterFn: (any) -> boolean?)
	local newTable = {}

	for index, value in pairs(_table) do
		if filterFn(index, value) then
			table.insert(newTable, value)
		end
	end

	return newTable
end

-- Find and return a Function module if it exists.
local function GetFunction(functionName: string)
	if Functions:FindFirstChild(functionName) then
		return require(Functions[functionName])
	end
end

-- Find the available groups.
local function GetGroups()
	local NAME = "Groups.auth"

	for _, descendant in ReplicatedStorage:GetDescendants() do
		if descendant:IsA("ModuleScript") and descendant.Name == NAME then
			IsAuthorized.Groups = require(descendant)
		end
	end

	if not next(IsAuthorized.Groups) then
		warn("Groups.auth.lua file could not be found, or is empty!")
	end
end

-- Evaluate (do they have perms?) a singular permission query, for example: 'Group:X:Y-Z', not the whole thing.
local function EvaluatePermissionsQuery(player: Player, strand: string)
	local Keyword = string.split(strand, ":")[1]
	local Packet = IsAuthorized.StandardRequestPacket

	Packet.IsNegated = string.sub(strand, 1, 1) == IsAuthorized.NegateCharacter

	if Packet.IsNegated then
		Keyword = string.sub(Keyword, 2)
	end

	local GroupFunction = GetFunction(Keyword or "")
	if not GroupFunction then
		warn(`No Function called '{Keyword}' found in functions, automatically returning as false.`)
		return false
	end

	if GroupFunction.Realm ~= "Shared" then
		local IsClient = RunService:IsClient()

		if GroupFunction.Realm == "Server" and IsClient then
			return false
		elseif GroupFunction.Realm == "Client" and not IsClient then
			return false
		end
	end

	return GroupFunction.Function(player, IsAuthorized.Groups, strand, Packet)
end

-- Unbundle the standard permission strand into individual queries.
-- A query is an element in the strand, a strand is the { 'x', 'y' 'z', }.
local function SegmentPermissionsStrand(player: Player, permissionsTable: { string })
	local RequireAll = false

	if
		permissionsTable[IsAuthorized.RequireAllKeyword]
		and permissionsTable[IsAuthorized.RequireAllKeyword] == true
	then
		RequireAll = true

		permissionsTable = Filter(permissionsTable, function(index, value)
			return index ~= IsAuthorized.RequireAllKeyword
		end)
	end

	if table.find(permissionsTable, IsAuthorized.AllKeyword) then
		return true
	end

	for _, permissionQuery in pairs(permissionsTable) do
		local QueryResult
		if typeof(permissionQuery) == "table" then
			QueryResult = SegmentPermissionsStrand(player, permissionQuery)
		else
			if IsAuthorized.SilenceInwardErrors then
				local Success

				local ResultFunction = Promise.promisify(EvaluatePermissionsQuery)
				Success, QueryResult = ResultFunction(player, permissionQuery):await()

				if not Success then
					warn(QueryResult) -- QueryResult is now the error response.
					continue
				end
			else
				QueryResult = EvaluatePermissionsQuery(player, permissionQuery)
			end
		end

		if QueryResult and not RequireAll then
			-- If this is successful, and we don't need to worry
			-- about the others, it's good to go.
			return true
		end

		if not QueryResult and RequireAll then
			-- We need everything, and since this is false, we
			-- can immediately return false.
			return false
		end
	end

	-- This looks weird, if it was requireall, it would've already been
	-- caught and returned as false. If it wasn't, it should have already
	-- returned true if something was fine- so actually this is just another
	-- way of saying RequireAll and true or false.
	return RequireAll
end

---------------------------------------
-- //       PUBLIC FUNCTIONS
---------------------------------------
-- Don't be confused by the scary metamethod- all these does
-- is builds in a way of requiring permission modules.
function IsAuthorized:__tostring(module: ModuleScript)
	return require(module)
end

-- This is returned as the IsAuthorized module is instantiated
-- on return.
function IsAuthorized:__call(...)
	if not next(IsAuthorized.Groups) then
		GetGroups()
	end

	local Player: Player, Permission: Permission

	if RunService:IsClient() then
		-- Consider arguments as { [1]: permissions }, if there is no player specified
		-- as { [1]: player, [2]: permissions }
		if not Permission then
			Permission = Player
			Player = Players.LocalPlayer
		end
	else
		Player, Permission = ...
	end

	-- Handle validation:
	assert(
		typeof(Player) == "Instance" and Player:IsA("Player"),
		"Expected a player in IsAuthorized(HERE, ...), got other."
	)
	assert(Permission, "Expected a permission query at IsAuthorized(..., HERE) got null.")

	if typeof(Permission) == "Instance" then
		if not Permission:IsA("ModuleScript") then
			error(`Expected ModuleScript when parsing Permissions got {Permission.ClassName}.`)
		end

		Permission = tostring(self, Permission)

		-- Consider empty permissions as true.
		if not Permission then
			return true
		end
	end

	if typeof(Permission) == "string" then
		Permission = { Permission }
	end

	if typeof(Permission) ~= "table" then
		error(`Invalid permissions at IsAuthorized(..., HERE), got {typeof(Permission)}.`)
	end

	-- Handle permissions parsing & segmentation.
	return SegmentPermissionsStrand(Player, Permission)
end

function IsAuthorized:EvaluateQuery(player: Player, query: string)
	assert(typeof(player) == "Instance", `Expected Instance for player got type {typeof(player)}.`)
	assert(typeof(query) == "string", `Expected string query got type {typeof(query)}.`)

	assert(player:IsA("Player"), `Expected Player for Player, got Class {player.ClassName}.`)

	return EvaluatePermissionsQuery(player, query)
end

function IsAuthorized:Async(...)
	local args = table.pack(...)
	return Promise.new(function(success, reject)
		local isAuthorized = self(table.unpack(args))

		if isAuthorized then
			success()
		else
			reject()
		end
	end)
end

return setmetatable({}, IsAuthorized)

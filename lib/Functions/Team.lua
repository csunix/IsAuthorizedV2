---------------------------------------
-- //       SERVICES
---------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

---------------------------------------
-- //       DEPENDENCIES
---------------------------------------
---------------------------------------
-- //       EXPORT
---------------------------------------
return {
	AutoEvaluate = function(Player: Player) end,
	Realm = "Shared",

	Function = function(Player: Player, Groups, Arguments: string, RequestPacket: { [string]: boolean })
		local Team
		local Split = string.split(Arguments, ":")

		Team = Split[2]
        
		assert(Team, "Expected Team in Team Function, got null." .. debug.traceback())
		assert(Teams[Team], `Expected valid team, could not find {Team} in Teams.\n{debug.traceback()}`)
        
		local ShouldNegate = RequestPacket.IsNegated

		local Result = Player.Team == Teams[Team]
		return ShouldNegate and not Result or Result
	end,
}

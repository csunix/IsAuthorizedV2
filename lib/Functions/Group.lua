---------------------------------------
-- //       SERVICES
---------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		local Group, RankRange
		local Split = string.split(Arguments, ":")

		Group = Split[2]
		RankRange = Split[3]

		assert(Group, "Expected Group in Group Function, got null." .. debug.traceback())
		assert(Groups[Group], `Expected valid group, could not find {Group} in Groups.\n{debug.traceback()}`)

		if not RankRange or RankRange == "*" then
			local GroupId = Groups[Group]

			return Player:IsInGroup(GroupId)
		end

		local function GetGroupRank(Player, GroupId)
			return Player:GetRankInGroup(GroupId)
		end

		local function IsInRange(Rank)
			if string.find(RankRange, "-") then
				local Minimum, Maximum
				local RangeSplit = string.split(RankRange, "-")

				Minimum = tonumber(RangeSplit[1])
				Maximum = tonumber(RangeSplit[2])

				if not Minimum or not Maximum then
					error(
						`RankRange Argument does not have a numerical minimum or maximum. {RankRange}\n{debug.traceback()}`
					)
				end

				return Rank > tonumber(Minimum) and Rank < tonumber(Maximum)
			else
				if string.find(RankRange, "+") then
					local Numbers, _ = string.gsub(RankRange, "%D", "")
					local TargetRank = tonumber(Numbers)

					if not TargetRank then
						error(
							`Expected numerical argument for target rank, got {Numbers}.\n{debug.traceback()}`
						)
					end

					return Rank >= TargetRank
				elseif string.find(RankRange, "<") then
					local Numbers, _ = string.gsub(RankRange, "%D", "")
					local TargetRank = tonumber(Numbers)

					if not TargetRank then
						error(
							`Expected numerical argument for target rank, got {Numbers}.\n{debug.traceback()}`
						)
					end

					return Rank <= TargetRank
				else
					local TargetRank = tonumber(RankRange)

					if not TargetRank then
						error(`Expected numerical argument for target rank, got {RankRange}.\n{debug.traceback()}`)
					end

					return Rank == TargetRank
				end
			end
		end

		local GroupId = Groups[Group]
		local ShouldNegate = RequestPacket.IsNegated

		local Result = IsInRange(GetGroupRank(Player, GroupId))
		return ShouldNegate and not Result or Result
	end,
}

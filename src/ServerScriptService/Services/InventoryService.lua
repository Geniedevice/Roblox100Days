-- 인벤토리. 아이템 개수는 플레이어 Attribute(Wood, Stone, Food, Water)에 두고 HUD가 바로 읽는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SurvivalStats = require(script.Parent.SurvivalStats)

local InventoryService = {}

function InventoryService.Get(player, item)
	return player:GetAttribute(item) or 0
end

function InventoryService.Add(player, item, amount)
	player:SetAttribute(item, InventoryService.Get(player, item) + amount)
end

-- 4단계 제작에서도 쓴다. 모자라면 false.
function InventoryService.Remove(player, item, amount)
	local have = InventoryService.Get(player, item)
	if have < amount then
		return false
	end
	player:SetAttribute(item, have - amount)
	return true
end

function InventoryService.Start()
	Remotes.UseItem.OnServerInvoke = function(player, item)
		local data = typeof(item) == "string" and Config.Items[item]
		if not data or not (data.Hunger or data.Thirst) then
			return false
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or not InventoryService.Remove(player, item, 1) then
			return false
		end
		SurvivalStats.Add(player, data.Hunger or 0, data.Thirst or 0)
		return true
	end
end

return InventoryService

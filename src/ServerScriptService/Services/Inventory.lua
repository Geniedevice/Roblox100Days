-- 코인과 아이템 개수. 값은 플레이어 데이터(Coins, Items)에 두고, HUD가 읽도록 플레이어 Attribute
-- (Coins, Item_<Id>)에 그대로 비춘다. 개수를 바꾸는 곳은 전부 여기를 거친다.
local DataService = require(script.Parent.DataService)

local Inventory = {}

function Inventory.Sync(player)
	local profile = DataService.Get(player)
	player:SetAttribute("Coins", profile.Coins)
	for id, count in profile.Items do
		player:SetAttribute("Item_" .. id, count)
	end
end

function Inventory.Count(player, id)
	local profile = DataService.Get(player)
	return profile and profile.Items[id] or 0
end

-- amount < 0이면 뺀다. 모자라면 아무것도 바꾸지 않고 false.
function Inventory.Add(player, id, amount)
	local profile = DataService.Get(player)
	local count = (profile and profile.Items[id] or 0) + amount
	if not profile or count < 0 then
		return false
	end
	profile.Items[id] = if count > 0 then count else nil
	player:SetAttribute("Item_" .. id, if count > 0 then count else nil)
	return true
end

function Inventory.AddCoins(player, amount)
	local profile = DataService.Get(player)
	if not profile or profile.Coins + amount < 0 then
		return false
	end
	profile.Coins += amount
	player:SetAttribute("Coins", profile.Coins)
	return true
end

return Inventory

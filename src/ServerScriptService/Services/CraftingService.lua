-- 제작. 재료를 검사·차감하고 결과(바리케이드 설치, 무기 지급)를 적용한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)
local CombatService = require(script.Parent.CombatService)
local InventoryService = require(script.Parent.InventoryService)

local CraftingService = {}

local function findRecipe(id)
	for _, recipe in Config.Crafting do
		if recipe.Id == id then
			return recipe
		end
	end
	return nil
end

local function canAfford(player, cost)
	for item, amount in cost do
		if InventoryService.Get(player, item) < amount then
			return false
		end
	end
	return true
end

-- 플레이어가 보는 방향 앞 지면에 세운다. 지면을 못 찾으면 false.
local function placeInFront(player, root, recipe)
	local place = recipe.Place
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		return false
	end
	look = look.Unit

	local spot = root.Position + look * Config.Barricade.PlaceDistance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(spot + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
	if not hit then
		return false
	end

	local position = hit.Position + Vector3.new(0, place.Size.Y / 2, 0)
	BaseService.PlaceBarricade(CFrame.lookAt(position, position + look), recipe, player:GetAttribute("BarricadeBonus") or 0)
	return true
end

function CraftingService.Start()
	-- 반환: 성공 여부, 화면에 띄울 문구
	Remotes.RequestCraft.OnServerInvoke = function(player, id)
		local recipe = typeof(id) == "string" and findRecipe(id)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not recipe or not root or not humanoid or humanoid.Health <= 0 then
			return false, "지금은 제작할 수 없습니다"
		end
		if not canAfford(player, recipe.Cost) then
			return false, "재료가 부족합니다"
		end
		if recipe.Weapon and player:GetAttribute("Has" .. recipe.Weapon) then
			return false, "이미 가지고 있습니다"
		end
		if recipe.Place and not placeInFront(player, root, recipe) then
			return false, "여기에는 설치할 수 없습니다"
		end
		if recipe.Weapon then
			player:SetAttribute("Has" .. recipe.Weapon, true)
			CombatService.GiveWeapon(player)
		end

		for item, amount in recipe.Cost do
			InventoryService.Remove(player, item, amount)
		end
		return true, recipe.Name .. " 완료!"
	end
end

return CraftingService

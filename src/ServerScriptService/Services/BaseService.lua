-- 안전가옥 위치와 바리케이드 관리. 바리케이드는 Workspace.Base.Barricades에 둔다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseService = {}

-- 지금 탐사 중인 세상(Workspace.Worlds/<ActiveWorld>). CompanyService가 workspace 속성 ActiveWorld를 정한다.
function BaseService.GetWorld()
	local worlds = workspace:FindFirstChild("Worlds")
	return worlds and worlds:FindFirstChild(workspace:GetAttribute("ActiveWorld") or "")
end

-- 안전가옥 중심 = 세상의 Spawn 파츠 위치(없으면 원점). 좀비 대체 스폰 반경의 기준.
function BaseService.GetCenter()
	local world = BaseService.GetWorld()
	local spawn = world and world:FindFirstChild("Spawn")
	return spawn and spawn.Position or Vector3.zero
end

local function getBarricadeFolder()
	local base = workspace:FindFirstChild("Base")
	if not base then
		base = Instance.new("Folder")
		base.Name = "Base"
		base.Parent = workspace
	end
	local folder = base:FindFirstChild("Barricades")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Barricades"
		folder.Parent = base
	end
	return folder
end

function BaseService.PlaceBarricade(cframe, recipe, healthBonus)
	local place = recipe.Place
	local part = Instance.new("Part")
	part.Name = "Barricade"
	part.Anchored = true
	part.Size = place.Size
	part.CFrame = cframe
	part.Color = place.Color
	part.Material = place.Material
	local maxHealth = place.Health * (1 + healthBonus)
	part:SetAttribute("Recipe", recipe.Id)
	part:SetAttribute("MaxHealth", maxHealth)
	part:SetAttribute("Health", maxHealth)
	part.Parent = getBarricadeFolder()
	CollectionService:AddTag(part, "Barricade")
	return part
end

-- position에서 표면까지 range 안에 있는 바리케이드 하나.
function BaseService.FindBarricadeNear(position, range)
	for _, part in CollectionService:GetTagged("Barricade") do
		local offset = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		local closest = Vector3.new(
			math.clamp(offset.X, -half.X, half.X),
			math.clamp(offset.Y, -half.Y, half.Y),
			math.clamp(offset.Z, -half.Z, half.Z)
		)
		if (offset - closest).Magnitude <= range then
			return part
		end
	end
	return nil
end

-- 부서질수록 흐려지고, 0이 되면 사라진다.
function BaseService.DamageBarricade(part, amount)
	local health = (part:GetAttribute("Health") or 0) - amount
	if health <= 0 then
		part:Destroy()
		return
	end
	part:SetAttribute("Health", health)
	part.Transparency = 0.5 * (1 - health / part:GetAttribute("MaxHealth"))
end

-- 이어하기용. DataStore에 넣을 수 있게 숫자·문자열만 쓴다.
function BaseService.Export()
	local walls = {}
	for _, part in getBarricadeFolder():GetChildren() do
		table.insert(walls, {
			Recipe = part:GetAttribute("Recipe"),
			CFrame = { part.CFrame:GetComponents() },
			Health = part:GetAttribute("Health"),
			MaxHealth = part:GetAttribute("MaxHealth"),
		})
	end
	return { Barricades = walls }
end

function BaseService.Import(data)
	for _, wall in data.Barricades or {} do
		for _, recipe in Config.Crafting do
			if recipe.Id == wall.Recipe and recipe.Place then
				local part = BaseService.PlaceBarricade(CFrame.new(table.unpack(wall.CFrame)), recipe, 0)
				part:SetAttribute("MaxHealth", wall.MaxHealth)
				part:SetAttribute("Health", wall.Health)
				BaseService.DamageBarricade(part, 0) -- 손상 정도만큼 흐리게
			end
		end
	end
end

function BaseService.Reset()
	getBarricadeFolder():ClearAllChildren()
end

return BaseService

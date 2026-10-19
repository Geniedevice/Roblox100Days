-- 기지 코어와 바리케이드 관리. Workspace.Base.Core가 없으면 원점에 임시 코어를 만든다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseService = {}
local core

function BaseService.GetCore()
	if core and core.Parent then
		return core
	end

	local base = workspace:FindFirstChild("Base")
	if not base then
		base = Instance.new("Folder")
		base.Name = "Base"
		base.Parent = workspace
	end

	core = base:FindFirstChild("Core")
	if not core then
		local part = Instance.new("Part")
		part.Name = "Core"
		part.Size = Vector3.new(6, 6, 6)
		part.Position = Vector3.new(0, 3, 0)
		part.Anchored = true
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(80, 170, 255)
		part.Parent = base
		core = part
	end

	if core:GetAttribute("Health") == nil then
		core:SetAttribute("MaxHealth", Config.Core.MaxHealth)
		core:SetAttribute("Health", Config.Core.MaxHealth)
	end
	return core
end

function BaseService.GetCorePosition()
	return BaseService.GetCore():GetPivot().Position
end

function BaseService.Damage(amount)
	local c = BaseService.GetCore()
	local health = math.max(0, (c:GetAttribute("Health") or 0) - amount)
	c:SetAttribute("Health", health)
	if health <= 0 and c:IsA("BasePart") then
		c.Color = Color3.fromRGB(40, 40, 40)
	end
end

function BaseService.IsDestroyed()
	return (BaseService.GetCore():GetAttribute("Health") or 0) <= 0
end

-- 다 찼거나 이미 부서졌으면 false.
function BaseService.Repair(amount)
	local c = BaseService.GetCore()
	local max, health = c:GetAttribute("MaxHealth"), c:GetAttribute("Health")
	if health >= max or health <= 0 then
		return false
	end
	c:SetAttribute("Health", math.min(max, health + amount))
	return true
end

function BaseService.Upgrade(amount)
	local c = BaseService.GetCore()
	c:SetAttribute("MaxHealth", c:GetAttribute("MaxHealth") + amount)
	c:SetAttribute("Health", c:GetAttribute("Health") + amount)
end

local function getBarricadeFolder()
	local base = BaseService.GetCore().Parent
	local folder = base:FindFirstChild("Barricades")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Barricades"
		folder.Parent = base
	end
	return folder
end

function BaseService.PlaceBarricade(cframe, place, healthBonus)
	local part = Instance.new("Part")
	part.Name = "Barricade"
	part.Anchored = true
	part.Size = place.Size
	part.CFrame = cframe
	part.Color = place.Color
	part.Material = place.Material
	local maxHealth = place.Health * (1 + healthBonus)
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

function BaseService.Reset()
	local c = BaseService.GetCore()
	c:SetAttribute("MaxHealth", Config.Core.MaxHealth)
	c:SetAttribute("Health", Config.Core.MaxHealth)
	if c:IsA("BasePart") then
		c.Color = Color3.fromRGB(80, 170, 255)
	end
	getBarricadeFolder():ClearAllChildren()
end

return BaseService

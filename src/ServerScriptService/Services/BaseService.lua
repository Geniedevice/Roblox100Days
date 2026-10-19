-- 기지 코어 관리. Workspace.Base.Core가 없으면 원점에 임시 코어를 만든다.
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

function BaseService.Reset()
	local c = BaseService.GetCore()
	c:SetAttribute("MaxHealth", Config.Core.MaxHealth)
	c:SetAttribute("Health", Config.Core.MaxHealth)
	if c:IsA("BasePart") then
		c.Color = Color3.fromRGB(80, 170, 255)
	end
end

return BaseService

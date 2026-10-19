-- 근접 무기(야구방망이) 지급, 서버 판정 공격, 좀비 처치 시 증강 효과 처리.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = {}
local lastSwing = {}

local WEAPON_NAME = "야구방망이"

local function createBat()
	local tool = Instance.new("Tool")
	tool.Name = WEAPON_NAME
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0, 1.2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 3.5)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(150, 105, 60)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

local function onKilled(zombie, player)
	if not player then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

	local heal = player:GetAttribute("LifeOnKill") or 0
	if heal > 0 and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
	end

	local food = player:GetAttribute("FoodOnKill") or 0
	if food > 0 then
		local max = Config.Survival.Max
		player:SetAttribute("Hunger", math.min(max, (player:GetAttribute("Hunger") or max) + food))
		player:SetAttribute("Thirst", math.min(max, (player:GetAttribute("Thirst") or max) + food))
	end

	if player:GetAttribute("ExplodeOnKill") then
		local root = zombie:FindFirstChild("HumanoidRootPart")
		if root then
			local position = root.Position
			local explosion = Instance.new("Explosion")
			explosion.Position = position
			explosion.BlastRadius = 10
			explosion.BlastPressure = 0
			explosion.DestroyJointRadiusPercent = 0
			explosion.Parent = workspace

			task.defer(function()
				for _, other in CollectionService:GetTagged("Zombie") do
					local otherRoot = other:FindFirstChild("HumanoidRootPart")
					if otherRoot and (otherRoot.Position - position).Magnitude <= 10 then
						CombatService.DamageZombie(other, 50, player)
					end
				end
			end)
		end
	end
end

function CombatService.DamageZombie(zombie, amount, player)
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
	if humanoid.Health <= 0 and not zombie:GetAttribute("Dead") then
		zombie:SetAttribute("Dead", true)
		onKilled(zombie, player)
	end
end

function CombatService.Swing(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local cooldown = Config.Weapon.Cooldown / (1 + (player:GetAttribute("AttackSpeedBonus") or 0))
	local now = os.clock()
	if now - (lastSwing[player] or 0) < cooldown then
		return
	end
	lastSwing[player] = now

	local damage = Config.Weapon.Damage * (1 + (player:GetAttribute("DamageBonus") or 0))
	for _, zombie in CollectionService:GetTagged("Zombie") do
		local zombieRoot = zombie:FindFirstChild("HumanoidRootPart")
		if zombieRoot then
			local offset = zombieRoot.Position - root.Position
			local range = Config.Weapon.Range + (zombie:GetAttribute("Scale") or 1) * 1.5
			if offset.Magnitude <= range and root.CFrame.LookVector:Dot(offset.Unit) > 0.3 then
				CombatService.DamageZombie(zombie, damage, player)
			end
		end
	end
end

function CombatService.GiveWeapon(player)
	local backpack = player:WaitForChild("Backpack")
	local character = player.Character
	if backpack:FindFirstChild(WEAPON_NAME) or (character and character:FindFirstChild(WEAPON_NAME)) then
		return
	end
	local tool = createBat()
	tool.Activated:Connect(function()
		CombatService.Swing(player)
	end)
	tool.Parent = backpack
end

function CombatService.ForgetPlayer(player)
	lastSwing[player] = nil
end

return CombatService

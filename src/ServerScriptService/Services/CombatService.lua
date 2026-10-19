-- 무기(야구방망이, 석궁) 지급, 서버 판정 공격, 좀비 처치 시 증강 효과 처리.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = {}
local lastSwing = {}
local lastShot = {}

local WEAPON_NAME = "야구방망이"
local CROSSBOW_NAME = "석궁"

local function createTool(name, size, color)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0, 1.2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Material = Enum.Material.Wood
	handle.Color = color
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

-- 석궁: 클라이언트가 조준점을 보내면 서버가 쿨다운·장착을 확인하고 레이캐스트로 판정한다.
local function shoot(player, target)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if typeof(target) ~= "Vector3" or not root or not humanoid or humanoid.Health <= 0
		or not character:FindFirstChild(CROSSBOW_NAME) then
		return
	end

	local cooldown = Config.Ranged.Cooldown / (1 + (player:GetAttribute("AttackSpeedBonus") or 0))
	local now = os.clock()
	if now - (lastShot[player] or 0) < cooldown then
		return
	end
	lastShot[player] = now

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - origin
	if offset.Magnitude < 0.1 then
		return
	end
	local direction = offset.Unit * Config.Ranged.Range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(origin, direction, params)
	local hitPosition = hit and hit.Position or origin + direction

	local length = (hitPosition - origin).Magnitude
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(255, 220, 120)
	bolt.Size = Vector3.new(0.15, 0.15, length)
	bolt.CFrame = CFrame.lookAt(origin, hitPosition) * CFrame.new(0, 0, -length / 2)
	bolt.Parent = workspace
	Debris:AddItem(bolt, 0.15)

	local zombie = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	if zombie and CollectionService:HasTag(zombie, "Zombie") then
		local damage = Config.Ranged.Damage * (1 + (player:GetAttribute("DamageBonus") or 0))
		CombatService.DamageZombie(zombie, damage, player)
	end
end

local function hasTool(player, backpack, name)
	local character = player.Character
	return backpack:FindFirstChild(name) or (character and character:FindFirstChild(name))
end

-- 캐릭터가 생길 때마다 부른다. 석궁은 HasCrossbow면 같이 준다.
function CombatService.GiveWeapon(player)
	local backpack = player:WaitForChild("Backpack")
	if not hasTool(player, backpack, WEAPON_NAME) then
		local bat = createTool(WEAPON_NAME, Vector3.new(0.4, 0.4, 3.5), Color3.fromRGB(150, 105, 60))
		bat.Activated:Connect(function()
			CombatService.Swing(player)
		end)
		bat.Parent = backpack
	end
	if player:GetAttribute("HasCrossbow") and not hasTool(player, backpack, CROSSBOW_NAME) then
		local crossbow = createTool(CROSSBOW_NAME, Vector3.new(0.5, 0.5, 2.5), Color3.fromRGB(70, 50, 35))
		crossbow:SetAttribute("Ranged", true) -- 클라이언트가 이 표시로 조준 입력을 붙인다
		crossbow.Parent = backpack
	end
end

function CombatService.ForgetPlayer(player)
	lastSwing[player] = nil
	lastShot[player] = nil
end

function CombatService.Start()
	Remotes.Shoot.OnServerEvent:Connect(shoot)
end

return CombatService

-- 밤마다 일차에 맞춰 좀비를 스폰한다.
-- ServerStorage.ZombieModels에 Normal/Runner/Tank/Boss 모델이 있으면 그걸 쓰고, 없으면 초록색 기본 좀비를 만든다.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BaseService = require(script.Parent.BaseService)

local WaveManager = {}
local defaultTemplate
local spawnToken = 0

local walkAnimation = Instance.new("Animation")
walkAnimation.AnimationId = Config.ZombieAI.WalkAnimation
local walkAnimationR6 = Instance.new("Animation")
walkAnimationR6.AnimationId = Config.ZombieAI.WalkAnimationR6

-- 서버에서 도는 Animate 스크립트가 없는 모델에 걷기 애니메이션을 붙인다.
-- 기본 좀비에 딸려 오는 Animate는 LocalScript라 서버 소유 NPC에서는 실행되지 않는다.
local function addWalkAnimation(zombie, humanoid)
	local animate = zombie:FindFirstChild("Animate")
	if animate and animate.ClassName == "Script" then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	local walk = animator:LoadAnimation(isR6 and walkAnimationR6 or walkAnimation)
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play()
			end
		elseif walk.IsPlaying then
			walk:Stop()
		end
	end)
end

local function getFolder()
	local folder = workspace:FindFirstChild("Zombies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Zombies"
		folder.Parent = workspace
	end
	return folder
end

local function getDefaultTemplate()
	if defaultTemplate then
		return defaultTemplate
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(90, 140, 70)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = Color3.fromRGB(60, 50, 40)
	description.RightLegColor = Color3.fromRGB(60, 50, 40)
	description.TorsoColor = Color3.fromRGB(70, 60, 50)

	defaultTemplate = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	defaultTemplate.Name = "Zombie"
	return defaultTemplate
end

local function getModel(typeName)
	local models = ServerStorage:FindFirstChild("ZombieModels")
	local custom = models and (models:FindFirstChild(typeName) or models:FindFirstChild("Normal"))
	if custom then
		return custom:Clone()
	end
	return getDefaultTemplate():Clone()
end

local function pickType(day)
	local total = 0
	local candidates = {}
	for name, stats in Config.Zombies do
		if stats.MinDay and day >= stats.MinDay then
			total += stats.Weight
			table.insert(candidates, { Name = name, Weight = stats.Weight })
		end
	end
	local roll = math.random() * total
	for _, candidate in candidates do
		roll -= candidate.Weight
		if roll <= 0 then
			return candidate.Name
		end
	end
	return "Normal"
end

local function randomSpawnPosition()
	local spawns = workspace:FindFirstChild("ZombieSpawns")
	local parts = {}
	if spawns then
		for _, child in spawns:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
	end

	if #parts > 0 then
		local part = parts[math.random(#parts)]
		return part.Position + Vector3.new(math.random(-5, 5), 3, math.random(-5, 5))
	end

	local angle = math.random() * math.pi * 2
	local radius = Config.Wave.FallbackRadius
	return BaseService.GetCorePosition() + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
end

local function spawnZombie(typeName, day)
	local stats = Config.Zombies[typeName]
	local zombie = getModel(typeName)
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("좀비 모델에 Humanoid가 없습니다:", typeName)
		zombie:Destroy()
		return
	end

	humanoid.MaxHealth = stats.Health * (1 + day * Config.Wave.HealthScalePerDay)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = stats.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if stats.Scale ~= 1 then
		zombie:ScaleTo(stats.Scale)
	end
	if stats.Tint then
		local colors = zombie:FindFirstChildOfClass("BodyColors")
		if colors then
			for _, limb in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				colors[limb .. "Color3"] = stats.Tint
			end
		else
			for _, part in zombie:GetDescendants() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = stats.Tint
				end
			end
		end
	end
	zombie:SetAttribute("Type", typeName)
	zombie:SetAttribute("Damage", stats.Damage)
	zombie:SetAttribute("Scale", stats.Scale)

	zombie:PivotTo(CFrame.new(randomSpawnPosition()))
	zombie.Parent = getFolder()

	local root = zombie:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(root.SetNetworkOwner, root, nil)
	end
	addWalkAnimation(zombie, humanoid)

	CollectionService:AddTag(zombie, "Zombie")
	humanoid.Died:Connect(function()
		CollectionService:RemoveTag(zombie, "Zombie")
		Debris:AddItem(zombie, 3)
	end)
end

function WaveManager.Spawn(day)
	spawnToken += 1
	local token = spawnToken

	if day % Config.Wave.BossEvery == 0 then
		spawnZombie("Boss", day)
		-- 밤 시작 문구가 먼저 보이도록 조금 늦게 띄운다
		task.delay(2, function()
			Remotes.GameMessage:FireAllClients("보스 좀비가 나타났다!")
		end)
	end

	local count = math.floor(Config.Wave.BaseCount + day * Config.Wave.CountPerDay)
	for _ = 1, count do
		while #CollectionService:GetTagged("Zombie") >= Config.Wave.MaxAlive do
			task.wait(0.5)
			if token ~= spawnToken then
				return
			end
		end
		if token ~= spawnToken then
			return
		end
		spawnZombie(pickType(day), day)
		task.wait(Config.Wave.SpawnInterval)
	end
end

function WaveManager.Stop()
	spawnToken += 1
end

-- 아침이 되면 남은 좀비를 모두 치운다.
function WaveManager.Clear()
	WaveManager.Stop()
	for _, zombie in getFolder():GetChildren() do
		zombie:Destroy()
	end
end

return WaveManager

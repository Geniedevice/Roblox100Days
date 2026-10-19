-- 낮(배회)과 밤(무리)마다 일차에 맞춰 좀비를 스폰한다.
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

local ANIMATIONS = {}
for rig, set in Config.ZombieAI.Animations do
	ANIMATIONS[rig] = {}
	for name, id in set do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		ANIMATIONS[rig][name] = animation
	end
end
local attackTracks = setmetatable({}, { __mode = "k" })

-- 서버에서 도는 Animate 스크립트가 없는 모델에 애니메이션을 붙인다(걷기, 팔 뻗기, 공격).
-- 기본 좀비에 딸려 오는 Animate는 LocalScript라 서버 소유 NPC에서는 실행되지 않는다.
local function addAnimations(zombie, humanoid)
	local animate = zombie:FindFirstChild("Animate")
	if animate and animate.ClassName == "Script" then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local set = ANIMATIONS[humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"]
	if set.Arms then
		local arms = animator:LoadAnimation(set.Arms)
		arms.Looped = true
		arms.Priority = Enum.AnimationPriority.Action
		arms:Play()
	end
	if set.Attack then
		local attack = animator:LoadAnimation(set.Attack)
		attack.Priority = Enum.AnimationPriority.Action2
		attackTracks[zombie] = attack
	end
	local walk = animator:LoadAnimation(set.Walk)
	walk.Looped = true -- R6 걷기 에셋은 반복 설정이 꺼져 있다
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

local function nearPlayer(position)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude < Config.Wave.MinPlayerDistance then
			return true
		end
	end
	return false
end

-- 탐사 중인 세상의 배율(Config.Worlds의 ZombieMultiplier)
local function worldMultiplier()
	local id = workspace:GetAttribute("ActiveWorld")
	for _, world in Config.Worlds do
		if world.Id == id then
			return world.ZombieMultiplier
		end
	end
	return 1
end

-- 탐사 중인 세상의 ZombieSpawns 중 플레이어와 떨어진 곳에서 고른다(모두 가까우면 아무 곳이나).
local function randomSpawnPosition()
	local world = BaseService.GetWorld()
	local spawns = world and world:FindFirstChild("ZombieSpawns")
	local far, all = {}, {}
	if spawns then
		for _, child in spawns:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(all, child)
				if not nearPlayer(child.Position) then
					table.insert(far, child)
				end
			end
		end
	end

	local pool = #far > 0 and far or all
	if #pool > 0 then
		local part = pool[math.random(#pool)]
		return part.Position + Vector3.new(math.random(-5, 5), 3, math.random(-5, 5))
	end

	local angle = math.random() * math.pi * 2
	local radius = Config.Wave.FallbackRadius
	return BaseService.GetCenter() + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
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

	humanoid.MaxHealth = stats.Health * (1 + day * Config.Wave.HealthScalePerDay) * worldMultiplier()
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

	for _, part in zombie:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Zombies" -- 플레이어와는 서로 통과(PlayerService에서 설정)
		end
	end
	zombie:PivotTo(CFrame.new(randomSpawnPosition()))
	zombie.Parent = getFolder()

	local root = zombie:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(root.SetNetworkOwner, root, nil)
	end
	addAnimations(zombie, humanoid)

	CollectionService:AddTag(zombie, "Zombie")
	humanoid.Died:Connect(function()
		CollectionService:RemoveTag(zombie, "Zombie")
		Debris:AddItem(zombie, 3)
	end)
end

-- 낮: 도시를 배회할 좀비, 밤: 몰려오는 무리(+10일마다 보스). 이미 돌던 스폰은 멈추고 새로 시작한다.
function WaveManager.Spawn(day, isNight)
	spawnToken += 1
	local token = spawnToken

	if isNight and day % Config.Wave.BossEvery == 0 then
		spawnZombie("Boss", day)
		-- 밤 시작 문구가 먼저 보이도록 조금 늦게 띄운다
		task.delay(2, function()
			Remotes.GameMessage:FireAllClients("보스 좀비가 나타났다!")
		end)
	end

	local wave = Config.Wave
	local count = math.floor((isNight and wave.BaseCount + day * wave.CountPerDay or wave.DayBase + day * wave.DayPerDay)
		* worldMultiplier())
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

function WaveManager.PlayAttack(zombie)
	local track = attackTracks[zombie]
	if track then
		track:Play()
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

-- 모든 좀비를 한 루프에서 갱신한다. 가까운 플레이어를 쫓고, 없으면 기지 코어로 간다.
-- 직선 이동(MoveTo)하고 나무·바위에 걸려 멈추면 점프한다. 길찾기(PathfindingService)를 쓰지 않는 건
-- 좀비가 바리케이드를 돌아가지 않고 부수게 하려는 것. 맵에 벽·건물이 생기면 그때 길찾기를 검토한다.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerService = require(script.Parent.PlayerService)
local BaseService = require(script.Parent.BaseService)

local ZombieAI = {}
local lastAttack = setmetatable({}, { __mode = "k" })
local lastPosition = setmetatable({}, { __mode = "k" })
local lastSlam = setmetatable({}, { __mode = "k" })

local function moveToward(zombie, humanoid, root, goal, distance, reach)
	humanoid:MoveTo(goal)
	local previous = lastPosition[zombie]
	lastPosition[zombie] = root.Position
	if distance > reach and previous and (root.Position - previous).Magnitude < 0.2 then
		humanoid.Jump = true
	end
end

-- 보스 내려찍기: 반경 안 모든 플레이어에게 피해 + 바닥에 붉은 원
local function slam(zombie, humanoid, root, targets, now)
	lastSlam[zombie] = now
	local radius = Config.Boss.SlamRadius
	for _, target in targets do
		if (target.Root.Position - root.Position).Magnitude <= radius then
			PlayerService.Damage(target.Player, Config.Boss.SlamDamage)
		end
	end

	local groundY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 70, 50)
	ring.Transparency = 0.5
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(root.Position.X, groundY + 0.2, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	Debris:AddItem(ring, 0.4)
end

local function update(zombie, targets, corePosition, now)
	local root = zombie:FindFirstChild("HumanoidRootPart")
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local bestPlayer, bestPosition = nil, nil
	local bestDistance = Config.ZombieAI.AggroRange
	for _, target in targets do
		local distance = (target.Root.Position - root.Position).Magnitude
		if distance < bestDistance then
			bestPlayer, bestPosition, bestDistance = target.Player, target.Root.Position, distance
		end
	end

	local scale = zombie:GetAttribute("Scale") or 1
	local reach = Config.ZombieAI.AttackRange * scale
	local damage = zombie:GetAttribute("Damage") or 10
	local canAttack = now - (lastAttack[zombie] or 0) >= Config.ZombieAI.AttackCooldown

	if zombie:GetAttribute("Type") == "Boss" and bestPlayer and bestDistance <= Config.Boss.SlamRadius
		and now - (lastSlam[zombie] or 0) >= Config.Boss.SlamCooldown then
		slam(zombie, humanoid, root, targets, now)
	end

	-- 바리케이드에 붙으면 먼저 부순다.
	local wall = BaseService.FindBarricadeNear(root.Position, reach)
	if wall then
		if canAttack then
			lastAttack[zombie] = now
			BaseService.DamageBarricade(wall, damage)
		end
		return
	end

	if bestPlayer then
		moveToward(zombie, humanoid, root, bestPosition, bestDistance, reach)
		if bestDistance <= reach and canAttack then
			lastAttack[zombie] = now
			PlayerService.Damage(bestPlayer, damage)
		end
	else
		local coreDistance = (corePosition - root.Position).Magnitude
		moveToward(zombie, humanoid, root, corePosition, coreDistance, reach + 4)
		if coreDistance <= reach + 4 and canAttack then
			lastAttack[zombie] = now
			BaseService.Damage(damage)
		end
	end
end

function ZombieAI.Start()
	task.spawn(function()
		while true do
			task.wait(Config.ZombieAI.TickRate)
			local targets = PlayerService.GetAliveCharacters()
			local corePosition = BaseService.GetCorePosition()
			local now = os.clock()
			for _, zombie in CollectionService:GetTagged("Zombie") do
				update(zombie, targets, corePosition, now)
			end
		end
	end)
end

return ZombieAI

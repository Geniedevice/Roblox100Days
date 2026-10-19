-- 모든 좀비를 한 루프에서 갱신한다.
-- 쫓기: 낮에는 AggroRange, 밤에는 NightAggroRange 안의 가장 가까운 플레이어. 없으면 근처를 배회한다.
-- 이동: 목표까지 Workspace.City(건물)에 막히지 않으면 직선(MoveTo), 막히면 PathfindingService로 돌아간다.
-- 바리케이드는 City가 아니라서 직선으로 들이받고 부순다.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerService = require(script.Parent.PlayerService)
local BaseService = require(script.Parent.BaseService)
local DayManager = require(script.Parent.DayManager)
local WaveManager = require(script.Parent.WaveManager)

local ZombieAI = {}
local lastAttack = setmetatable({}, { __mode = "k" })
local lastPosition = setmetatable({}, { __mode = "k" })
local lastSlam = setmetatable({}, { __mode = "k" })
local wanderGoal = setmetatable({}, { __mode = "k" })
local paths = setmetatable({}, { __mode = "k" }) -- [zombie] = { Waypoints, Index, Goal, Time, Computing }

local FLAT = Vector3.new(1, 0, 1)

local function isBlocked(from, to)
	local city = workspace:FindFirstChild("City")
	if not city then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { city }
	return workspace:Raycast(from, to - from, params) ~= nil
end

local function requestPath(zombie, root, goal, now)
	local entry = paths[zombie]
	if entry and (entry.Computing or now - entry.Time < Config.ZombieAI.RepathTime) then
		return
	end
	entry = entry or {}
	entry.Computing, entry.Time, entry.Goal = true, now, goal
	paths[zombie] = entry
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok = pcall(path.ComputeAsync, path, root.Position, goal)
		entry.Computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			entry.Waypoints, entry.Index = path:GetWaypoints(), 2
		else
			entry.Waypoints = nil
		end
	end)
end

-- 길을 따라가면 true, 쓸 길이 없으면 false(직선으로 간다).
local function followPath(zombie, humanoid, root, goal, now)
	requestPath(zombie, root, goal, now)
	local entry = paths[zombie]
	local waypoints = entry and entry.Waypoints
	if not waypoints then
		return false
	end
	local waypoint = waypoints[entry.Index]
	while waypoint and ((waypoint.Position - root.Position) * FLAT).Magnitude < 3 do
		entry.Index += 1
		waypoint = waypoints[entry.Index]
	end
	if not waypoint then
		return false
	end
	humanoid:MoveTo(waypoint.Position)
	if waypoint.Action == Enum.PathWaypointAction.Jump then
		humanoid.Jump = true
	end
	return true
end

local function moveToward(zombie, humanoid, root, goal, distance, reach, now)
	if isBlocked(root.Position, goal) and followPath(zombie, humanoid, root, goal, now) then
		return
	end
	humanoid:MoveTo(goal)
	local previous = lastPosition[zombie]
	lastPosition[zombie] = root.Position
	if distance > reach and previous and (root.Position - previous).Magnitude < 0.2 then
		humanoid.Jump = true
	end
end

-- 목표가 없으면 근처를 어슬렁거린다. 도착했거나 걸려서 멈추면 새 지점을 고른다.
local function wander(zombie, humanoid, root)
	local goal = wanderGoal[zombie]
	local previous = lastPosition[zombie]
	lastPosition[zombie] = root.Position
	local stuck = previous and (root.Position - previous).Magnitude < 0.2
	if not goal or stuck or ((goal - root.Position) * FLAT).Magnitude < 4 then
		local angle = math.random() * math.pi * 2
		local radius = math.random(8, Config.ZombieAI.WanderRadius)
		goal = root.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		wanderGoal[zombie] = goal
	end
	humanoid:MoveTo(goal)
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

local function update(zombie, targets, aggroRange, now)
	local root = zombie:FindFirstChild("HumanoidRootPart")
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local bestPlayer, bestPosition = nil, nil
	local bestDistance = aggroRange
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
			WaveManager.PlayAttack(zombie)
		end
		return
	end

	if not bestPlayer then
		wander(zombie, humanoid, root)
		return
	end
	wanderGoal[zombie] = nil
	moveToward(zombie, humanoid, root, bestPosition, bestDistance, reach, now)
	if bestDistance <= reach and canAttack then
		lastAttack[zombie] = now
		PlayerService.Damage(bestPlayer, damage)
		WaveManager.PlayAttack(zombie)
	end
end

function ZombieAI.Start()
	task.spawn(function()
		while true do
			task.wait(Config.ZombieAI.TickRate)
			local targets = PlayerService.GetAliveCharacters()
			local aggroRange = DayManager.IsNight and Config.ZombieAI.NightAggroRange or Config.ZombieAI.AggroRange
			local now = os.clock()
			for _, zombie in CollectionService:GetTagged("Zombie") do
				update(zombie, targets, aggroRange, now)
			end
		end
	end)
end

return ZombieAI

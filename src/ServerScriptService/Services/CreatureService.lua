-- 섬 생물: 섬 바이옴(시드로 정한 컨셉)의 생물 표(Shared/Loot)에서 COUNT마리를 뽑아 숲(물가 생물은 낚시터 물가)에 풀어 놓는다.
-- 서버가 집(처음 자리) 둘레를 걷기·깡총·날기로 돌아다니게 하고(앵커한 Root를 트윈, 나머지는 용접), 누르면 쓰다듬기:
-- 하트·깡총 연출과 함께 도감 "생물"에 남는다. 다치게 할 방법은 없다(힐링 게임).
-- ponytail: 서버 트윈 = 복제 주기만큼 끊겨 보일 수 있다. 끊김이 거슬리면 목표 지점만 속성으로 보내고 클라이언트가 트윈한다.
-- 명세: design/gdd/creatures.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Models = require(ReplicatedStorage.Shared.Models)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DexService = require(script.Parent.DexService)
local IslandGen = require(script.Parent.IslandGen)
local IslandService = require(script.Parent.IslandService)

local COUNT = 8 -- 섬마다 생물 수
local ROAM = 18 -- 집에서 이 거리(스터드) 안을 돌아다닌다
local REST = { 2, 6 } -- 움직임 사이 쉬는 초
local FLY_HEIGHT = 4 -- 나는 생물이 땅 위에 뜨는 높이
local PET_REACH = 14
local PET_GAP = 1.2 -- 같은 생물을 다시 쓰다듬을 수 있는 간격(초)
local HABITAT_ZONES = { Ground = { Wild = true, House = true }, Water = { Fishing = true, Wild = true } }

local CreatureService = {}
local herds = {} -- [player] = { Island, Folder, List = { { Model, Root, Id, Home, NextAt, Busy, PetAt } } }
local rng = Random.new()

-- 서식지 구역의 청크에서 땅 자리(물가 생물은 물 가까이)
local function findHome(island, def)
	local zones = HABITAT_ZONES[def.Habitat]
	local chunks = {}
	for _, c in island.Gen.Chunks do
		if zones[c.Zone] and (def.Habitat ~= "Water" or c.Zone == "Fishing") then
			table.insert(chunks, c)
		end
	end
	if #chunks == 0 then
		for _, c in island.Gen.Chunks do
			if c.Zone == "Wild" then
				table.insert(chunks, c)
			end
		end
	end
	local size = IslandGen.CHUNK * IslandGen.CELL
	for _ = 1, 20 do
		local c = chunks[rng:NextInteger(1, #chunks)]
		local point = island.Origin + Vector3.new((c.X + rng:NextNumber(0.1, 0.9)) * size, island.YardY, (c.Z + rng:NextNumber(0.1, 0.9)) * size)
		local ground = IslandService.Ground(island, point)
		if ground then
			return ground
		end
	end
	return nil
end

local function place(entry, ground, look)
	local def = Creatures[entry.Id]
	local y = if def.Move == "Fly" then FLY_HEIGHT else 0
	local position = ground + Vector3.new(0, y, 0)
	return CFrame.lookAt(position, Vector3.new(look.X, position.Y, look.Z))
end

-- 앵커한 root를 goal까지 옮긴다(끝날 때까지 기다린다). 길을 3스터드 칸으로 나눠 Hop은 칸마다 한 번 뛰고, 나머지는 돌아선 뒤
-- speed(기본 def.Speed)로 걷는다. 칸마다 island 땅 높이를 다시 재어 언덕·골짜기를 따라간다(땅이 없는 칸 = 물·다리 위는 직선 높이).
-- 도우미 동물(PetService)도 쓴다
function CreatureService.Travel(root, def, goal, island, speed)
	local start = root.CFrame
	local distance = (goal.Position - start.Position).Magnitude
	local steps = math.max(1, math.ceil(distance / 3))
	local lift = if def.Move == "Fly" then FLY_HEIGHT else 0
	local function at(t) -- 길 위 t(0..1) 자리. 끝은 goal 그대로
		local c = start:Lerp(goal, t)
		local ground = t < 1 and IslandService.Ground(island, c.Position, c.Position.Y + 10)
		return if ground then c + Vector3.new(0, ground.Y + lift - c.Position.Y, 0) else c
	end
	if def.Move == "Hop" then
		for i = 1, steps do
			local up = TweenService:Create(root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = at((i - 0.5) / steps) + Vector3.new(0, 1.6, 0) })
			up:Play()
			up.Completed:Wait()
			local down = TweenService:Create(root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = at(i / steps) })
			down:Play()
			down.Completed:Wait()
			task.wait(0.12)
		end
	else
		local turn = TweenService:Create(root, TweenInfo.new(0.3), { CFrame = CFrame.lookAt(start.Position, start.Position + goal.LookVector) })
		turn:Play()
		turn.Completed:Wait()
		start = root.CFrame -- 돌아선 방향에서 걷기 시작
		local each = TweenInfo.new(distance / steps / (speed or def.Speed), Enum.EasingStyle.Linear)
		for i = 1, steps do
			local walk = TweenService:Create(root, each, { CFrame = at(i / steps) })
			walk:Play()
			walk.Completed:Wait()
		end
	end
end

-- 한 번 움직이기(끝날 때까지 기다린다)
local function move(entry, island)
	local root = entry.Root
	local angle = rng:NextNumber(0, 2 * math.pi)
	local target = IslandService.Ground(island, entry.Home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(4, ROAM))
	if not target or not root.Parent then
		return
	end
	CreatureService.Travel(root, Creatures[entry.Id], place(entry, target, target + (target - root.Position) * Vector3.new(1, 0, 1)
		+ Vector3.new(0.01, 0, 0)), island)
end

function CreatureService.Load(player, island)
	CreatureService.Unload(player)
	local loot = island.Gen.Loot
	local folder = Instance.new("Folder")
	folder.Name = "Creatures"
	folder.Parent = island.Model
	local herd = { Island = island, Folder = folder, List = {} }
	herds[player] = herd
	if #loot.Creatures == 0 then
		return
	end
	for _ = 1, COUNT do
		local id = Loot.Pick(loot.Creatures, loot.CreatureTotal, rng:NextNumber())
		local def = Creatures[id]
		local home = findHome(island, def)
		if home then
			local model = Models.Creature(id)
			local root = model.PrimaryPart
			root.Anchored = true
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanQuery = p ~= root -- 몸을 누르면 쓰다듬기(Root는 투명해서 빼고)
				end
			end
			model:SetAttribute("Owner", player.UserId)
			model:SetAttribute("Creature", id)
			CollectionService:AddTag(model, "Creature")
			local entry = { Model = model, Root = root, Id = id, Home = home, NextAt = os.clock() + rng:NextNumber(0, 3), PetAt = 0 }
			model:PivotTo(place(entry, home, home + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))))
			model.Parent = folder
			table.insert(herd.List, entry)
		end
	end
end

function CreatureService.Unload(player)
	local herd = herds[player]
	herds[player] = nil
	if herd then
		herd.Folder:Destroy()
	end
end

local function onPet(player, model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, herd in herds do -- 친구 섬 생물도 쓰다듬을 수 있다(도감은 쓰다듬은 사람 것)
		for _, entry in herd.List do
			if entry.Model == model and (root.Position - entry.Root.Position).Magnitude <= PET_REACH and os.clock() - entry.PetAt > PET_GAP then
				entry.PetAt = os.clock()
				local def = Creatures[entry.Id]
				local extents = model:GetExtentsSize()
				Remotes.Feedback:FireAllClients("Pet", { Player = player, Model = model, Item = entry.Id, Monster = def.Monster == true,
					Position = entry.Root.Position + Vector3.new(0, extents.Y + 0.5, 0), Text = def.Name .. " ♥" })
				DexService.Record(player, "Creatures", entry.Id)
				entry.NextAt = os.clock() + 2.5 -- 쓰다듬는 동안은 가만히
				return
			end
		end
	end
end

function CreatureService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target)
		if kind == "Pet" and typeof(target) == "Instance" and target:IsA("Model") then
			onPet(player, target)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, herd in herds do
				for _, entry in herd.List do
					if not entry.Busy and now >= entry.NextAt then
						entry.Busy = true
						task.spawn(function()
							move(entry, herd.Island)
							entry.Busy = false
							entry.NextAt = os.clock() + rng:NextNumber(REST[1], REST[2])
						end)
					end
				end
			end
		end
	end)
end

return CreatureService

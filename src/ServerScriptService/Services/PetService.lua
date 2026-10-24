-- 도우미 동물(명세: design/gdd/pets.md): 보관함에 "Pet_<Id>"가 있으면 주인 섬에 그 동물이 나온다. 할 일이 있으면 그 농지 옆으로 가서
-- 한 번 해 주고(FarmService.FindJob → Help), 없으면 주인 곁을 따라다닌다(주인이 남의 섬에 가 있으면 첫 밭 옆에서 기다린다).
-- 주인이 접속해 섬이 있는 동안만 일한다. 이동은 섬 생물처럼 앵커한 Root를 서버에서 트윈한다(CreatureService.Travel).
-- 누르면(쓰다듬기) 하트와 말풍선: 내 동물은 "개굴개굴! 물 준 칸 12"처럼 이번 접속에 한 일, 남의 동물은 울음소리만.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Crops = require(ReplicatedStorage.Shared.Crops)
local Lines = require(ReplicatedStorage.Shared.Lines)
local Models = require(ReplicatedStorage.Shared.Models)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CreatureService = require(script.Parent.CreatureService)
local FarmService = require(script.Parent.FarmService)
local Inventory = require(script.Parent.Inventory)
local IslandService = require(script.Parent.IslandService)

local SPEED = 9 -- 걷는 도우미(닭)의 걸음(스터드/초). 깡총 뛰는 도우미는 생물과 같은 깡총 속도
local REST = 1 -- 일 하나를 끝내고 쉬는 초
local IDLE = 1.5 -- 할 일이 없을 때 다시 찾는 간격
local FOLLOW = 7 -- 주인과 이보다 멀면 따라간다
local WARP = 60 -- 이보다 멀면 주인 곁으로 바로 옮긴다
local BESIDE = 2.4 -- 일할 때 농지 가운데에서 떨어져 서는 거리
local FLY_HEIGHT = 4
local PET_REACH, PET_GAP = 14, 1 -- 쓰다듬기 거리, 같은 동물 다시 쓰다듬는 간격(초)
local SIDES = { Frog = -3, Rabbit = 3, Chicken = 0 } -- 따라갈 때 주인 뒤 옆 자리(겹치지 않게)

local PetService = {}
local teams = {} -- [player] = { Island, Folder, List = { [Id] = { Id, Def, Jobs, Model, Root, Thread, Done } } }
local pettedAt = setmetatable({}, { __mode = "k" }) -- [모델] = os.clock()

-- 심을 씨앗: 가장 많이 가진 씨앗(같으면 앞 순서). 하나도 없으면 nil
local function seedFor(owner)
	local best, most = nil, 0
	for id, crop in Crops do
		local count = Inventory.Count(owner, "Seed_" .. id)
		if count > most or (count == most and count > 0 and crop.Order < Crops[best].Order) then
			best, most = id, count
		end
	end
	return best
end

-- ground(발밑)에 서서 look 쪽을 본다
local function standAt(pet, ground, look)
	local position = ground + Vector3.new(0, if pet.Def.Move == "Fly" then FLY_HEIGHT else 0, 0)
	local facing = Vector3.new(look.X, position.Y, look.Z)
	return if (facing - position).Magnitude > 0.1 then CFrame.lookAt(position, facing) else CFrame.new(position)
end

local function go(pet, island, ground, look)
	CreatureService.Travel(pet.Root, pet.Def, standAt(pet, ground, look), island, SPEED)
end

-- 일하는 몸짓: 고개를 숙였다 든다
local function peck(pet)
	local base = pet.Root.CFrame
	local down = TweenService:Create(pet.Root, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { CFrame = base * CFrame.Angles(math.rad(-25), 0, 0) })
	down:Play()
	down.Completed:Wait()
	local up = TweenService:Create(pet.Root, TweenInfo.new(0.15, Enum.EasingStyle.Back), { CFrame = base })
	up:Play()
	up.Completed:Wait()
end

-- 주인 곁 땅 자리 → 발밑 위치, 바라볼 곳. 주인 뒤가 땅이 아니면(절벽 끝·물) 주인 발밑 땅, 그것도 없으면(다리·부두 위)
-- 주인이 딛고 선 높이. 주인이 공중(점프·낙하)이면 nil = 움직이지 않는다. 주인이 내 섬에 없으면 첫 밭 옆
local function homeSpot(owner, team, pet)
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and owner:GetAttribute("Visiting") == nil then
		if humanoid.FloorMaterial == Enum.Material.Air then
			return nil
		end
		local top = root.Position.Y + 1
		local behind = root.Position - root.CFrame.LookVector * 4 + root.CFrame.RightVector * (SIDES[pet.Id] or 0)
		local ground = IslandService.Ground(team.Island, behind, top) or IslandService.Ground(team.Island, root.Position, top)
		return ground or root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0), root.Position
	end
	local field = team.Island.Gen.Fields[1]
	local spot = IslandService.YardPoint(team.Island, field.X - 1, field.Y + 1.5 + (SIDES[pet.Id] or 0) / 3)
	return spot, spot + Vector3.new(1, 0, 0)
end

local function run(owner, team, pet)
	while true do
		local seed = pet.Jobs.Plant and seedFor(owner)
		local jobs = if pet.Jobs.Plant and not seed then { Till = pet.Jobs.Till } else pet.Jobs -- 씨앗이 없으면 갈기만
		local tile, job = FarmService.FindJob(owner, jobs, pet.Root.Position)
		if tile then
			local away = (pet.Root.Position - tile.Position) * Vector3.new(1, 0, 1)
			local side = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			go(pet, team.Island, Vector3.new(tile.Position.X, tile.Position.Y + 0.2, tile.Position.Z) + side * BESIDE, tile.Position)
			peck(pet)
			if FarmService.Help(owner, tile, job, seed) then
				pet.Done += 1
			end
			task.wait(REST)
		else
			local spot, look = homeSpot(owner, team, pet)
			local distance = spot and ((spot - pet.Root.Position) * Vector3.new(1, 0, 1)).Magnitude or 0
			if distance > WARP then
				pet.Root.CFrame = standAt(pet, spot, look)
			elseif distance > FOLLOW then
				go(pet, team.Island, spot, look)
			end
			task.wait(IDLE)
		end
	end
end

local function add(owner, team, id, arrived)
	local def = Pets[id]
	local model = Models.Creature(def.Creature)
	model.Name = id
	local root = model.PrimaryPart
	root.Anchored = true
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanTouch = false, false -- 길을 막지 않는다
			p.CanQuery = p ~= root -- 몸을 누르면 쓰다듬기(Root는 투명해서 빼고)
		end
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 26)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.MaxDistance = 50
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Text = def.Name
	label.TextColor3 = Color3.fromRGB(255, 250, 235)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(110, 78, 52)
	label.Parent = tag
	tag.Parent = root
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("Pet", id)
	CollectionService:AddTag(model, "Pet")

	local pet = { Id = id, Def = Creatures[def.Creature], Jobs = def.Jobs, Model = model, Root = root, Done = 0 }
	local spot, look = homeSpot(owner, team, pet)
	if not spot then -- 주인이 공중: 스폰 자리에
		spot, look = team.Island.Spawn.Position - Vector3.new(0, 3, 0), team.Island.Spawn.Position
	end
	model:PivotTo(standAt(pet, spot, look))
	model.Parent = team.Folder
	team.List[id] = pet
	pet.Thread = task.spawn(run, owner, team, pet)
	if arrived then -- 새로 왔다: 주인 곁에서 하트
		Remotes.Feedback:FireAllClients("Pet", { Player = owner, Model = model, Item = def.Creature, Text = def.Name .. " ♥",
			Position = root.Position + Vector3.new(0, model:GetExtentsSize().Y + 0.5, 0) })
		Remotes.Feedback:FireClient(owner, "Toast", { Text = Lines.Josa(def.Name, "이", "가") .. " 섬에 왔어요! " .. def.Desc })
	end
end

-- 섬을 (다시) 지은 뒤: 가진 도우미 동물을 모두 내보낸다
function PetService.Load(player, island)
	PetService.Unload(player)
	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = island.Model
	local team = { Island = island, Folder = folder, List = {} }
	teams[player] = team
	for id in Pets do
		if Inventory.Count(player, "Pet_" .. id) > 0 then
			add(player, team, id, false)
		end
	end
end

function PetService.Unload(player)
	local team = teams[player]
	teams[player] = nil
	if team then
		for _, pet in team.List do
			task.cancel(pet.Thread)
		end
		team.Folder:Destroy()
	end
end

-- 쓰다듬기: 하트·폴짝(클라이언트 연출)과 말풍선
local function love(player, model)
	local id = model:GetAttribute("Pet")
	local def = id and Pets[id]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	if not def or not root or (root.Position - model:GetPivot().Position).Magnitude > PET_REACH or now - (pettedAt[model] or 0) < PET_GAP then
		return
	end
	pettedAt[model] = now
	local text = def.Voice
	local mine = teams[player] and teams[player].List[id]
	if mine and mine.Model == model then
		text = string.format("%s %s %d", def.Voice, def.Done, mine.Done)
	end
	Remotes.Feedback:FireAllClients("PetLove", { Player = player, Model = model, Text = text,
		Position = model:GetPivot().Position + Vector3.new(0, model:GetExtentsSize().Y + 0.5, 0) })
end

function PetService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target)
		if kind == "Pet" and typeof(target) == "Instance" and CollectionService:HasTag(target, "Pet") then
			love(player, target)
		end
	end)
	-- 모모에게서 사면 보관함 속성(Item_Pet_<Id>)이 생긴다: 그때 바로 내보낸다
	local function watch(player)
		player.AttributeChanged:Connect(function(name)
			local id = name:match("^Item_Pet_(.+)$")
			local team = teams[player]
			if id and Pets[id] and team and not team.List[id] and Inventory.Count(player, "Pet_" .. id) > 0 then
				add(player, team, id, true)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return PetService

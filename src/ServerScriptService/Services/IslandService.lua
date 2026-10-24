-- 플레이어마다 시드 하늘섬(복셀 블록, 4×4 청크 + 산 땅)을 서버 슬롯에 지어 주고, 그 섬에서 (다시) 태어나게 한다. 나가면 섬을 지운다.
-- 블록은 IslandGen이 시드·산 땅으로 정하고 IslandBuilder가 Part로 짓는다(Workspace.Islands/Island_<UserId>/Terrain).
-- 땅을 사면 AddChunk가 그 청크 하나만 만들어 지형에 더 짓는다(섬 전체를 다시 짓지 않는다). 자리는 섬에 붙은 빈 자리 중
-- 무작위(미리 골라 반투명 구름 판과 가격 팻말로 보인다), 바이옴은 살 때 무작위로 정해 저장한다. 섬에서 떨어지면 스폰으로.
-- 남의 섬에 놀러 가면(MoveTo) 그 섬이 "지금 있는 섬"이 되고 Visiting 속성(주인 UserId)이 붙는다. 떨어지면 그 섬 스폰으로,
-- 다시 태어나면 내 섬으로. 주인이 나가 섬이 지워지면 거기 있던 사람은 집으로 간다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local IslandBuilder = require(script.Parent.IslandBuilder)
local IslandGen = require(script.Parent.IslandGen)

local CELL = IslandGen.CELL
local CHUNK_STUDS = IslandGen.CHUNK * CELL
local SLOT_SPACING = 1200 -- 슬롯 간격(스터드). 6×6청크로 넓힌 섬 + 떠 있는 작은 섬이 지름 약 450
local FALL_DEPTH = 40 -- 섬 밑면보다 이만큼 떨어지면 스폰으로
local RESPAWN_DELAY = 3
local CHUNK_BASE, CHUNK_STEP = 200, 150 -- 땅 값 = 200 + 150 × 이미 산 땅 수
local FILL_Y = IslandGen.YARD - 2 -- 이 높이에 블록이 있으면 그 칸은 이미 땅(산 청크가 깎인 해안 틈만 메울 때)

local IslandService = {}
IslandService.Rebuilt = Instance.new("BindableEvent") -- (player, record) 산 청크를 지은 뒤(밭 자리·구역이 늘었다)
local islands = {} -- [player] = 섬 정보(Spawn이 돌려주는 record)
local here = {} -- [player] = 지금 있는 섬 record(내 섬 또는 놀러 간 섬)
local slots = {} -- [slot] = 그 슬롯에 지은 섬 수(연합이면 여러 개)
local hooked = setmetatable({}, { __mode = "k" }) -- CharacterAdded를 연결한 플레이어
local folder
local rng = Random.new()

function IslandService.ChunkPrice(profile)
	return CHUNK_BASE + CHUNK_STEP * #profile.Chunks
end

-- 다음 땅 자리 위 구름 판(누르기·충돌 없음)
local function ghost(record, profile)
	if record.Ghost then
		record.Ghost:Destroy()
		record.Ghost = nil
	end
	local spot = record.NextSpot
	if not spot then
		return
	end
	local plate = Instance.new("Part")
	plate.Name = "NextChunk"
	plate.Anchored, plate.CanCollide, plate.CanQuery, plate.CanTouch, plate.CastShadow = true, false, false, false, false
	plate.Size = Vector3.new(CHUNK_STUDS - 2, 1, CHUNK_STUDS - 2)
	plate.Position = record.Origin + Vector3.new((spot.X + 0.5) * CHUNK_STUDS, record.YardY - CELL - 0.5, (spot.Z + 0.5) * CHUNK_STUDS)
	plate.Color = Color3.fromRGB(235, 245, 255)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Transparency = 0.75
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(260, 60)
	tag.StudsOffset = Vector3.new(0, 8, 0)
	tag.MaxDistance = 220
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 250, 235)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(80, 110, 160)
	label.Text = string.format("다음 땅 · %d코인\n안내인 루미에게서 살 수 있어요", IslandService.ChunkPrice(profile))
	label.Parent = tag
	tag.Parent = plate
	plate.Parent = record.Model
	record.Ghost = plate
end

-- 다음 땅 자리를 미리 고른다(섬에 붙은 빈 자리 중 무작위, 다 찼으면 nil)
local function rollNext(record, profile)
	local spots = IslandGen.Candidates(profile.Chunks)
	record.NextSpot = if #spots > 0 then spots[rng:NextInteger(1, #spots)] else nil
end

-- 시작 섬 + 산 청크를 합친 섬 정보(record.Gen): 청크 목록·구역(ZoneAt)·밭 자리(시작 → 산 순서)·나머지는 시작 섬 것
-- (NPC 자리 Npc·스폰·획득물 표 Loot). 클라이언트 구역 판정용 Chunks 속성, 떨어짐 높이도 여기서 맞춘다
local function refreshGen(record, profile)
	local chunks = IslandGen.Chunks(profile.Chunks)
	local zones = {}
	for _, c in chunks do
		zones[c.X .. "," .. c.Z] = c.Zone
	end
	local fields = table.clone(record.Base.Fields)
	local minY = record.Base.Min.Y
	for _, gen in record.Gens do
		if gen ~= record.Base then
			table.move(gen.Fields, 1, #gen.Fields, #fields + 1, fields)
			minY = math.min(minY, gen.Min.Y)
		end
	end
	local chunk = IslandGen.CHUNK
	record.Gen = setmetatable({
		Chunks = chunks,
		Fields = fields,
		ZoneAt = function(x, z)
			return zones[x // chunk .. "," .. z // chunk]
		end,
	}, { __index = record.Base })
	record.Model:SetAttribute("Chunks", HttpService:JSONEncode(chunks)) -- 클라이언트 구역 판정(핫바·구역 칩)
	record.FallY = record.Origin.Y + minY * CELL - FALL_DEPTH
end

-- 새 청크 자리에 걸친 지형 Part(시작 섬의 떠 있는 작은 섬·폭포 등)를 치운다
local function clearArea(record, c)
	local low = record.Origin + Vector3.new(c.X, 0, c.Z) * CHUNK_STUDS
	for _, part in record.Terrain:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			if part.Position.X + half.X > low.X + 0.1 and part.Position.X - half.X < low.X + CHUNK_STUDS - 0.1
				and part.Position.Z + half.Z > low.Z + 0.1 and part.Position.Z - half.Z < low.Z + CHUNK_STUDS - 0.1 then
				part:Destroy()
			end
		end
	end
end

-- 산 땅 목록의 i번째까지 보고 그 청크 하나만 만들어 지형에 더 짓는다(산 순서가 같으면 늘 같은 모양). 잘못된 칸이면 nil
local function buildChunk(record, profile, i)
	local extra = table.move(profile.Chunks, 1, i, 1, {})
	local before = #IslandGen.Chunks(table.move(profile.Chunks, 1, i - 1, 1, {}))
	local list = IslandGen.Chunks(extra)
	if #list == before then
		return nil -- 겹치거나 잘못 저장된 칸
	end
	local c = list[#list]
	local gens = record.Gens
	local gen = IslandGen.GenerateChunk(profile.Seed, extra, c, record.Base.Concept, function(x, z)
		for _, g in gens do
			if g.Get(x, FILL_Y, z) ~= 0 then
				return true
			end
		end
		return false
	end)
	clearArea(record, c)
	IslandBuilder.Build(gen, record.Origin, record.Terrain)
	table.insert(gens, gen)
	return c
end

-- 처음 지을 때: 시작 섬(시드)을 짓고, 산 청크를 산 순서대로 하나씩 더 짓는다
local function build(record, profile)
	local base = IslandGen.Generate(profile.Seed)
	local terrain = IslandBuilder.Build(base, record.Origin)
	terrain.Parent = record.Model
	record.Terrain = terrain
	record.Blocks = terrain.Blocks -- 땅 블록(레이캐스트로 지면을 찾을 때)
	record.Plants = terrain.Plants -- 나무·버섯·선인장 블록
	record.Water = terrain.Water
	record.Base, record.Gens = base, { base }
	for i = 1, #profile.Chunks do
		buildChunk(record, profile, i)
	end
	refreshGen(record, profile)
	record.Concept = base.Concept
	local spawn = record.Origin + base.Spawn * CELL + Vector3.new(0, 3, 0)
	record.Spawn = CFrame.lookAt(spawn, spawn - Vector3.zAxis) -- 북쪽(안내인·노점 거리)을 바라본다
	rollNext(record, profile)
	ghost(record, profile)
end

-- profile.Seed가 없으면(새 플레이어) 새 시드를 준다. DataService가 profile을 저장하니 다음 접속에도 같은 섬이다.
-- place = { Origin, Slot }이면 그 자리에 짓는다(연합 이웃 자리, UnionService). 없으면 빈 슬롯의 원점.
-- 섬 정보를 돌려준다. 캐릭터는 다른 서비스가 섬을 채운 뒤 Main이 낸다.
function IslandService.Spawn(player, profile, place)
	profile.Seed = profile.Seed or Random.new():NextInteger(1, 2147483646)

	local slot = place and place.Slot
	if not slot then
		slot = 1
		while slots[slot] do
			slot += 1
		end
	end
	slots[slot] = (slots[slot] or 0) + 1 -- 연합은 슬롯 하나에 섬 여러 개
	local origin = if place then place.Origin else Vector3.new(slot * SLOT_SPACING, 0, 0)

	local model = Instance.new("Model")
	model.Name = "Island_" .. player.UserId
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Seed", profile.Seed)
	model:SetAttribute("Origin", origin)
	local record = {
		Slot = slot,
		Model = model,
		Origin = origin,
		YardY = origin.Y + IslandGen.YARD * CELL, -- 마당 윗면(스터드)
	}
	build(record, profile)
	model:SetAttribute("Concept", record.Concept)
	model.Parent = folder
	islands[player] = record
	player:SetAttribute("IslandSeed", profile.Seed)
	player:SetAttribute("IslandConcept", record.Concept)
	player:SetAttribute("IslandChunks", #record.Gen.Chunks)

	if not hooked[player] then -- 섬을 옮겨 다시 지어도 한 번만
		hooked[player] = true
		player.CharacterAdded:Connect(function(character)
			local home = islands[player]
			if home then
				here[player] = home
				player:SetAttribute("Visiting", nil)
				task.defer(character.PivotTo, character, home.Spawn) -- 기본 스폰 배치가 끝난 뒤에 옮긴다
			end
			character:WaitForChild("Humanoid").Died:Connect(function()
				task.wait(RESPAWN_DELAY)
				if islands[player] then
					player:LoadCharacter()
				end
			end)
		end)
	end
	return record
end

-- 본섬(청크) 가장자리까지 거리(스터드), axis = ±X 또는 ±Z 단위 벡터. 연합 구름다리가 쓴다
function IslandService.Extent(record, axis)
	local far = -math.huge
	for _, c in record.Gen.Chunks do
		local low, high = Vector3.new(c.X, 0, c.Z) * CHUNK_STUDS, Vector3.new(c.X + 1, 0, c.Z + 1) * CHUNK_STUDS
		far = math.max(far, low:Dot(axis), high:Dot(axis))
	end
	return far
end

-- position의 (x, z) 위 땅 윗면 위치. 땅 블록이 아니면(물·나무·허공) nil. 생물·도우미 동물·연합 다리가 쓴다
-- fromY = 이 높이부터 아래로 찾는다(기본은 섬 위 하늘: 지붕 위가 잡힐 수 있다. 사람 곁이면 그 사람 높이를 준다)
function IslandService.Ground(record, position, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { record.Blocks, record.Plants, record.Water }
	local top = fromY or record.Origin.Y + 200
	local hit = workspace:Raycast(Vector3.new(position.X, top, position.Z), Vector3.new(0, record.Origin.Y - 200 - top, 0), params) -- 섬 아래 200까지
	return if hit and hit.Instance.Parent == record.Blocks and hit.Normal.Y > 0.75 then hit.Position else nil
end

-- 땅 사기: 미리 고른 자리(구름 판)에 zone 청크 하나를 붙이고 그 청크만 짓는다. 바이옴은 무작위로 정해 저장한다.
-- 반환: 섬 record, 붙인 청크 { X, Z, Zone, Biome } (자리가 없으면 nil)
function IslandService.AddChunk(player, profile, zone)
	local record = islands[player]
	local spot = record and record.NextSpot
	if not spot or not table.find(IslandGen.BuyZones, zone) then
		return nil
	end
	local biomes = IslandGen.Biomes()
	table.insert(profile.Chunks, { X = spot.X, Z = spot.Z, Zone = zone, Biome = biomes[rng:NextInteger(1, #biomes)] })
	local chunk = buildChunk(record, profile, #profile.Chunks)
	refreshGen(record, profile)
	rollNext(record, profile)
	ghost(record, profile)
	player:SetAttribute("IslandChunks", #record.Gen.Chunks)
	IslandService.Rebuilt:Fire(player, record)
	return record, chunk
end

-- 더 살 수 있는 땅 자리가 남았나
function IslandService.CanExpand(player)
	local record = islands[player]
	return record ~= nil and record.NextSpot ~= nil
end

function IslandService.Get(player)
	return islands[player]
end

-- 섬 안의 Instance → 그 섬 record, 주인 Player(섬 밖이거나 주인이 없으면 nil)
function IslandService.Find(instance)
	local model = instance
	while model and model.Parent ~= folder do
		model = model.Parent
	end
	local owner = model and Players:GetPlayerByUserId(model:GetAttribute("Owner") or 0)
	local record = owner and islands[owner]
	if record and record.Model == model then
		return record, owner
	end
	return nil
end

-- record 섬 스폰으로 옮긴다(내 섬이면 Visiting을 지운다)
function IslandService.MoveTo(player, record)
	here[player] = record
	player:SetAttribute("Visiting", if record == islands[player] then nil else record.Model:GetAttribute("Owner"))
	if player.Character then
		player.Character:PivotTo(record.Spawn)
	end
end

-- 블록 칸 좌표(x, z, 소수 가능) → 마당 윗면 위의 월드 위치
function IslandService.YardPoint(island, x, z)
	return Vector3.new(island.Origin.X + x * CELL, island.YardY, island.Origin.Z + z * CELL)
end

-- 월드 위치 → 그 칸의 구역 Id(섬 밖이면 nil)
function IslandService.ZoneAt(island, position)
	local relative = position - island.Origin
	return island.Gen.ZoneAt(math.floor(relative.X / CELL), math.floor(relative.Z / CELL))
end

function IslandService.Remove(player)
	here[player] = nil
	local island = islands[player]
	if not island then
		return
	end
	islands[player] = nil
	slots[island.Slot] = if slots[island.Slot] > 1 then slots[island.Slot] - 1 else nil
	for visitor, record in here do
		if record == island and islands[visitor] then
			IslandService.MoveTo(visitor, islands[visitor])
		end
	end
	island.Model:Destroy()
end

function IslandService.Start()
	folder = workspace:FindFirstChild("Islands") or Instance.new("Folder")
	folder.Name = "Islands"
	folder.Parent = workspace
	Players.CharacterAutoLoads = false -- 섬이 지어진 뒤에 캐릭터를 낸다

	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, island in here do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < island.FallY then
					root.AssemblyLinearVelocity = Vector3.zero
					player.Character:PivotTo(island.Spawn)
				end
			end
		end
	end)
end

return IslandService

-- 하우스키핑(꾸미기): 보관함의 가구를 섬에 놓고 거두고, 기능성 가구(앉기·불빛)를 붙이고, 아늑함 점수를 낸다.
-- 저장: profile.Placed = { { Id, P = { x, y, z }(섬 원점 기준, 슬롯이 바뀌어도 같은 자리), R = 0|90|180|270 } },
-- 보관함 = profile.Items[가구 Id]. 배치 검사(자기 섬·집터 구역·지면 위·300개)는 전부 서버가 한다.
-- 명세: design/gdd/housekeeping.md
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.Inventory)
local IslandGen = require(script.Parent.IslandGen)

local MAX_PLACED = 300
local REACH = 60 -- 캐릭터에서 이 거리 안에만 놓을 수 있다
local SAME_ID_LIMIT = 3 -- 같은 가구는 3개까지만 점수에 센다(같은 물건 도배로 점수 올리기 방지)
local SET_BONUS, BASICS_BONUS, TIDY_BONUS = 15, 10, 10
local GRADES = { { 110, "S" }, { 75, "A" }, { 45, "B" }, { 15, "C" }, { 0, "D" } }
local ROTATIONS = { 0, 90, 180, 270 }
local CELL = IslandGen.CELL

local DecorService = {}
local decor = {} -- [player] = { Island, Folder, Models = { [모델] = 저장 레코드 } }

-- 섬 원점 기준 위치가 집터 구역인가
local function inHouse(island, relative)
	return island.Gen.ZoneAt(math.floor(relative.X / CELL), math.floor(relative.Z / CELL)) == "House"
end

local function toast(player, text)
	Remotes.Feedback:FireClient(player, "Toast", { Text = text })
end

local function prompt(parent, actionText, onTriggered)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Triggered:Connect(onTriggered)
	p.Parent = parent
	return p
end

local function invisiblePart(model, cframe)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.Transparency = true, false, false, 1
	part.Size = Vector3.one
	part.CFrame = cframe
	part.Parent = model
	return part
end

-- 기능성 가구: 의자·벤치는 앉기, 등불은 켜고 끄기
local function addFunctions(model, data)
	local pivot = model:GetPivot()
	if data.Seat then
		local seat = Instance.new("Seat")
		seat.Anchored, seat.Transparency, seat.CanCollide = true, 1, false
		seat.Size = Vector3.new(1.8, 0.2, 1.8)
		seat.CFrame = pivot * CFrame.new(data.Seat)
		seat.Parent = model
		prompt(seat, "앉기", function(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and not seat.Occupant then
				seat:Sit(humanoid)
			end
		end)
	end
	if data.Light then
		local holder = invisiblePart(model, pivot * CFrame.new(data.Light))
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 16, 1.2, Color3.fromRGB(255, 210, 150)
		light.Parent = holder
		local p
		p = prompt(holder, "끄기", function()
			light.Enabled = not light.Enabled
			p.ActionText = if light.Enabled then "끄기" else "켜기"
		end)
	end
end

local function spawnFurniture(player, record)
	local entry = decor[player]
	local data = Furniture.Items[record.Id]
	local model = Furniture.Build(record.Id)
	model:PivotTo(CFrame.new(entry.Island.Origin + Vector3.new(record.P[1], record.P[2], record.P[3])) * CFrame.Angles(0, math.rad(record.R), 0))
	model:SetAttribute("Owner", player.UserId)
	addFunctions(model, data)
	CollectionService:AddTag(model, "Placed")
	model.Parent = entry.Folder
	entry.Models[model] = record
	return model
end

-- 놓을 수 있는 자리면 섬 원점 기준 위치(1스터드 격자), 아니면 nil과 이유
local function validSpot(entry, position)
	local island = entry.Island
	local relative = position - island.Origin
	relative = Vector3.new(math.round(relative.X), math.round(relative.Y * 10) / 10, math.round(relative.Z))
	if not inHouse(island, relative) then
		return nil, "가구는 집터 구역에 놓아 주세요"
	end
	-- 지면 위인지: 바로 아래 4스터드 안에 땅(섬 블록이나 다른 가구)이 있어야 한다
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { island.Blocks, entry.Folder }
	local world = island.Origin + relative
	if not workspace:Raycast(world + Vector3.new(0, 1, 0), Vector3.new(0, -5, 0), params) then
		return nil, "땅 위에 놓아 주세요"
	end
	return relative
end

local function onPlace(player, request)
	local entry = decor[player]
	local profile = DataService.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not entry or not profile or not root or type(request) ~= "table" then
		return
	end
	local id, position, rotation = request.Id, request.Position, request.Rotation
	if type(id) ~= "string" or not Furniture.Items[id] or typeof(position) ~= "Vector3" or not table.find(ROTATIONS, rotation)
		or (root.Position - position).Magnitude > REACH then
		return
	end
	if #profile.Placed >= MAX_PLACED then
		return toast(player, "섬에 더 놓을 자리가 없어요(" .. MAX_PLACED .. "개)")
	end
	local relative, reason = validSpot(entry, position)
	if not relative then
		return toast(player, reason)
	end
	if not Inventory.Add(player, id, -1) then
		return toast(player, "보관함에 없어요")
	end
	local record = { Id = id, P = { relative.X, relative.Y, relative.Z }, R = rotation }
	table.insert(profile.Placed, record)
	local model = spawnFurniture(player, record)
	Remotes.Feedback:FireAllClients("Place", { Player = player, Model = model, Position = model:GetPivot().Position + Vector3.new(0, 1, 0) })
	DecorService.UpdateCozy(player)
end

local function onPickup(player, model)
	local entry = decor[player]
	local profile = DataService.Get(player)
	local record = entry and entry.Models[model]
	if not record or not profile then
		return -- 내 섬 가구만
	end
	entry.Models[model] = nil
	local index = table.find(profile.Placed, record)
	if index then
		table.remove(profile.Placed, index)
	end
	local position = model:GetPivot().Position
	model:Destroy()
	Inventory.Add(player, record.Id, 1)
	Remotes.Feedback:FireAllClients("Pickup", { Player = player, Position = position + Vector3.new(0, 1, 0) })
	DecorService.UpdateCozy(player)
end

-- 아늑함 = Σ 가구 점수(같은 가구 3개까지) + 완성 세트 × 15 + 필수 3종(앉기·탁자·불빛) 10 + 집안일 0개 10
function DecorService.UpdateCozy(player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local counts, kinds = {}, {}
	for _, record in profile.Placed do
		counts[record.Id] = (counts[record.Id] or 0) + 1
	end
	local score = 0
	local sets = {} -- [세트] = 모두 놓였는가
	for id, data in Furniture.Items do
		local n = counts[id] or 0
		score += data.Cozy * math.min(n, SAME_ID_LIMIT)
		if n > 0 and data.Kind then
			kinds[data.Kind] = true
		end
		if data.Set then
			sets[data.Set] = (sets[data.Set] ~= false) and n > 0
		end
	end
	for _, complete in sets do
		score += if complete then SET_BONUS else 0
	end
	score += if kinds.Seat and kinds.Table and kinds.Light then BASICS_BONUS else 0
	score += if (profile.Chores or 0) == 0 then TIDY_BONUS else 0
	local grade = "D"
	for _, step in GRADES do
		if score >= step[1] then
			grade = step[2]
			break
		end
	end
	player:SetAttribute("Cozy", score)
	player:SetAttribute("CozyGrade", grade)
	return score, grade
end

function DecorService.Load(player, island)
	local profile = DataService.Get(player)
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = island.Model
	decor[player] = { Island = island, Folder = folder, Models = {} }
	local kept = {}
	for _, record in profile.Placed do
		if not Furniture.Items[record.Id] then
			warn("[DecorService] 데이터에 없는 가구를 건너뜁니다:", record.Id)
		elseif not inHouse(island, Vector3.new(record.P[1], record.P[2], record.P[3])) then
			Inventory.Add(player, record.Id, 1) -- 섬 구역 규칙이 바뀌어 집터 밖에 있게 된 가구는 보관함으로
		else
			table.insert(kept, record)
			spawnFurniture(player, record)
		end
	end
	profile.Placed = kept
end

function DecorService.Unload(player)
	decor[player] = nil
end

function DecorService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target, arg)
		if kind == "Place" then
			onPlace(player, arg)
		elseif kind == "Pickup" and typeof(target) == "Instance" then
			onPickup(player, target)
		end
	end)
end

return DecorService

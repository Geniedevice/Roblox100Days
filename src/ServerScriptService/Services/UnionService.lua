-- 섬 연합(같은 서버): 파티원끼리 섬을 잇는다. 받아들인 사람 섬이 가운데 섬 옆(동 → 남 → 서 → 북, SIDE스터드)으로 옮겨지고
-- 구름다리로 이어진다. 저장은 각자 profile.Union = { Id }뿐이고, 누가 어느 자리인지는 서버 메모리(unions)에만 둔다.
-- 연합 멤버는 파티원과 같은 권한(PartyService.Same이 UnionId 속성을 본다), 이웃 섬 1개당 성장 +5%(UnionBonus 속성, FarmService).
-- 섬을 옮기는 일(서비스 내리기 → 다시 짓기 → 채우기)은 Main이 Start에 넘긴다. 명세: design/gdd/island-union.md
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local IslandGen = require(script.Parent.IslandGen)
local IslandService = require(script.Parent.IslandService)
local PartyService = require(script.Parent.PartyService)

local UnionService = {}
UnionService.SIDE = 360 -- 이웃 섬 원점 거리(스터드). 6×6청크 섬(288) 끝 사이 72
UnionService.MAX = 4 -- 연합 섬 수(가운데 포함)
UnionService.BONUS, UnionService.BONUS_MAX = 0.05, 0.15 -- 이웃 섬 1개당 성장 배수 +, 최대

local INVITE_TTL = 30
local INVITE_COOLDOWN = 3
local BRIDGE_WIDTH = 8
local INSET = 6 -- 다리 끝이 본섬 가장자리 안쪽으로 들어오는 거리(스터드)
local SCAN = 50 -- 다리 줄을 찾을 때 가운데에서 양옆으로 볼 칸 수
local SPOTS = { Vector3.zero, Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.zAxis } -- 가운데, 동, 남, 서, 북(-Z)

local unions = {} -- [Id] = { Id, Slot, Origin(가운데 원점), Spots = { [자리] = player }, Bridges }
local invites = {} -- [받는 사람] = { From, At }
local lastInvite = {} -- [보낸 사람] = os.clock()
local move -- (player, place) → 새 섬 record. Main이 준다

local function toast(player, text)
	Remotes.Feedback:FireClient(player, "Toast", { Text = text })
end

local function unionOf(player)
	local profile = DataService.Get(player)
	return profile and profile.Union and unions[profile.Union.Id]
end

local function spotOf(union, player)
	for spot, member in union.Spots do
		if member == player then
			return spot
		end
	end
	return nil
end

local function count(union)
	local n = 0
	for _ in union.Spots do
		n += 1
	end
	return n
end

-- 빈 자리(가운데 먼저, 그다음 동 → 남 → 서 → 북). 꽉 찼으면 nil
local function freeSpot(union)
	if count(union) >= UnionService.MAX then
		return nil
	end
	for spot = 1, #SPOTS do
		if not union.Spots[spot] then
			return spot
		end
	end
	return nil
end

local function placeOf(union, spot)
	return { Slot = union.Slot, Origin = union.Origin + SPOTS[spot] * UnionService.SIDE }
end

local function deck(parent, from, to)
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, -0.5, 0)
	local part = Instance.new("Part")
	part.Name = "Bridge"
	part.Anchored = true
	part.Size = Vector3.new(BRIDGE_WIDTH, 1, length)
	part.CFrame = cframe
	part.Color = Color3.fromRGB(250, 252, 255)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	local i = 0
	for t = 4, length - 4, 7 do -- 양옆 구름 뭉치(누르기·충돌 없음)
		for _, side in { -1, 1 } do
			i += 1
			local puff = Instance.new("Part")
			puff.Shape = Enum.PartType.Ball
			puff.Anchored, puff.CanCollide, puff.CanQuery, puff.CanTouch, puff.CastShadow = true, false, false, false, false
			puff.Size = Vector3.one * (3 + i % 3)
			puff.CFrame = cframe * CFrame.new(side * BRIDGE_WIDTH / 2, -0.3, length / 2 - t)
			puff.Color = Color3.fromRGB(255, 255, 255)
			puff.Material = Enum.Material.SmoothPlastic
			puff.Transparency = 0.1
			puff.Parent = parent
		end
	end
end

-- 가운데 섬 → 이웃 섬(d 방향) 다리. 가운데 줄부터 양옆으로 한 칸씩 보며 양 끝이 다 땅인 줄에 놓는다
local function bridge(parent, center, neighbor, d)
	local side = Vector3.new(d.Z, 0, d.X)
	local a = center.Origin + d * (IslandService.Extent(center, d) - INSET)
	local b = neighbor.Origin - d * (IslandService.Extent(neighbor, -d) - INSET)
	for i = 0, SCAN * 2 do
		local offset = side * IslandGen.CELL * (if i % 2 == 0 then i / 2 else -(i + 1) / 2)
		local from, to = IslandService.Ground(center, a + offset), IslandService.Ground(neighbor, b + offset)
		if from and to then
			return deck(parent, from, to)
		end
	end
	deck(parent, Vector3.new(a.X, center.YardY, a.Z), Vector3.new(b.X, neighbor.YardY, b.Z)) -- 못 찾으면 마당 높이로
end

-- 다리를 새로 놓고 보너스를 맞춘다(멤버가 바뀌거나 땅을 산 뒤)
local function refresh(union)
	if union.Bridges then
		union.Bridges:Destroy()
		union.Bridges = nil
	end
	local bonus = math.min(UnionService.BONUS_MAX, UnionService.BONUS * (count(union) - 1))
	for _, member in union.Spots do
		member:SetAttribute("UnionBonus", if bonus > 0 then bonus else nil)
	end
	local center = union.Spots[1] and IslandService.Get(union.Spots[1])
	if not center then
		return -- 가운데가 비면 다리도 없다
	end
	local folder = Instance.new("Folder")
	folder.Name = "UnionBridges"
	for spot = 2, #SPOTS do
		local neighbor = union.Spots[spot] and IslandService.Get(union.Spots[spot])
		if neighbor then
			bridge(folder, center, neighbor, SPOTS[spot])
		end
	end
	folder.Parent = center.Model -- 가운데 섬이 지워지면 같이 사라진다
	union.Bridges = folder
end

-- 자리에 붙인다: 서로의 섬을 도감에 남기고 다리를 놓는다
local function attach(union, spot, player)
	union.Spots[spot] = player
	local mine = IslandService.Get(player)
	for _, other in union.Spots do
		local theirs = other ~= player and IslandService.Get(other)
		if theirs and mine then
			DexService.Record(player, "Islands", theirs.Concept)
			DexService.Record(other, "Islands", mine.Concept)
		end
	end
	refresh(union)
end

-- 자리에서 뗀다(연합은 남는다). 아무도 없으면 서버 기록만 지운다
local function detach(union, player)
	local spot = spotOf(union, player)
	if not spot then
		return false
	end
	union.Spots[spot] = nil
	player:SetAttribute("UnionBonus", nil)
	if next(union.Spots) then
		refresh(union)
	else
		unions[union.Id] = nil
	end
	return true
end

-- 접속할 때 IslandService.Spawn 대신 부른다: 같은 연합 멤버 섬이 서버에 있으면 그 옆 빈 자리에, 없으면 내 슬롯 가운데에 짓는다
function UnionService.Spawn(player, profile)
	local id = type(profile.Union) == "table" and profile.Union.Id
	if type(id) ~= "string" then
		profile.Union = nil
		return IslandService.Spawn(player, profile)
	end
	player:SetAttribute("UnionId", id)
	local union = unions[id]
	local spot = if union then freeSpot(union) else 1
	if not spot then
		return IslandService.Spawn(player, profile) -- 꽉 찼다: 내 슬롯에 따로 선다(권한은 연합 그대로)
	end
	local record = IslandService.Spawn(player, profile, union and placeOf(union, spot))
	if not union then
		union = { Id = id, Slot = record.Slot, Origin = record.Origin, Spots = {} }
		unions[id] = union
	end
	attach(union, spot, player)
	return record
end

local function unite(player, target)
	local mine, theirs = DataService.Get(player), DataService.Get(target)
	local now = os.clock()
	if target == player or not mine or not theirs or now - (lastInvite[player] or 0) < INVITE_COOLDOWN then
		return
	end
	lastInvite[player] = now
	local union = unionOf(player)
	if theirs.Union then
		return toast(player, if mine.Union and mine.Union.Id == theirs.Union.Id then "이미 같은 연합이에요"
			else target.DisplayName .. "님은 다른 연합에 있어요")
	elseif not PartyService.Same(player, target) then
		return toast(player, "파티원끼리만 섬을 이을 수 있어요")
	elseif union and not freeSpot(union) then
		return toast(player, "연합이 가득 찼어요(" .. UnionService.MAX .. "섬)")
	end
	invites[target] = { From = player, At = now }
	Remotes.Feedback:FireClient(target, "Unite", { From = player, Ttl = INVITE_TTL })
	toast(player, target.DisplayName .. "님에게 섬 잇기를 보냈어요")
end

local function answer(player, from, accept)
	local pending = invites[player]
	if not pending or pending.From ~= from then
		return
	end
	invites[player] = nil
	if not accept then
		return toast(from, player.DisplayName .. "님이 섬 잇기를 거절했어요")
	end
	local mine, theirs = DataService.Get(player), DataService.Get(from)
	local home = IslandService.Get(from)
	if os.clock() - pending.At > INVITE_TTL + 2 or not mine or not theirs or not home or mine.Union or not PartyService.Same(player, from) then
		return toast(player, "섬을 이을 수 없어요")
	end
	local id = theirs.Union and theirs.Union.Id or HttpService:GenerateGUID(false)
	local union = unions[id]
	if not union then -- 초대한 사람 섬이 가운데가 된다
		theirs.Union = { Id = id }
		from:SetAttribute("UnionId", id)
		union = { Id = id, Slot = home.Slot, Origin = home.Origin, Spots = {} }
		unions[id] = union
		attach(union, 1, from)
	end
	local spot = freeSpot(union)
	if not spot then
		return toast(player, "연합이 가득 찼어요(" .. UnionService.MAX .. "섬)")
	end
	mine.Union = { Id = id }
	player:SetAttribute("UnionId", id)
	union.Spots[spot] = player -- 옮기는 동안 자리를 잡아 둔다
	local record = move(player, placeOf(union, spot))
	if union.Spots[spot] ~= player or player.Parent ~= Players then
		return -- 옮기는 사이 나갔거나 끊었다
	end
	attach(union, spot, player)
	for _, member in union.Spots do
		Remotes.Feedback:FireClient(member, "Expand", { Player = member, Small = true, Text = "섬이 이어졌어요!",
			Sub = string.format("%s님 섬 · 연합 %d섬", player.DisplayName, count(union)), Position = record.Spawn.Position })
	end
end

local function leave(player)
	local profile = DataService.Get(player)
	if not profile or not profile.Union then
		return
	end
	local union = unionOf(player)
	profile.Union = nil
	player:SetAttribute("UnionId", nil)
	local others = union and count(union) > 1
	if union and detach(union, player) and others then
		move(player, nil) -- 남은 섬 사이에서 빠져 새 슬롯으로(혼자 남았으면 그 자리에 그대로)
	end
	toast(player, "연합을 끊었어요")
end

function UnionService.Unload(player)
	invites[player] = nil
	lastInvite[player] = nil
	local union = unionOf(player)
	if union then
		detach(union, player)
	end
end

function UnionService.Start(mover)
	move = mover
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target, arg)
		if kind == "LeaveUnion" then
			leave(player)
		elseif typeof(target) ~= "Instance" or not target:IsA("Player") then
			return
		elseif kind == "Unite" then
			unite(player, target)
		elseif kind == "UniteAnswer" then
			answer(player, target, arg == true)
		end
	end)
	IslandService.Rebuilt.Event:Connect(function(player) -- 땅을 사면 가장자리·땅 높이가 바뀐다
		local union = unionOf(player)
		if union and spotOf(union, player) then
			refresh(union)
		end
	end)
end

return UnionService

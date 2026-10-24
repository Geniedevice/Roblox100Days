-- 플레이어 데이터 저장(DataStore). 접속 때 불러오고, AUTOSAVE초마다·퇴장·서버 종료 때 저장한다.
-- 세션 잠금: 한 키는 한 서버만 쓴다(텔레포트·재접속 경합 때 덮어쓰기 방지). 저장 레코드 = { Data, Lock }.
-- 불러오기에 실패하면 기본값으로 덮어쓰지 않도록 내보낸다(kick).
-- publish 전(PlaceId 0)이거나 Studio API 접근이 꺼져 있으면 저장 없이 메모리로만 돈다.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = "SkyIslandPlayers"
local AUTOSAVE = 120 -- 초
local LOCK_TTL = 300 -- 초. 자동 저장이 갱신하므로, 이보다 오래된 잠금은 죽은 서버 것으로 보고 가져온다
-- 스키마가 바뀌면 Version을 올리고 Load에서 옛 데이터를 고친다. 새 칸은 reconcile이 채운다.
-- 위치는 슬롯마다 섬 원점이 달라지므로 늘 섬 원점 기준 숫자로 둔다(Vector3·CFrame은 저장 불가).
local DEFAULT = {
	Version = 1,
	Coins = 30,
	Items = {}, -- [아이템 Id] = 개수 (씨앗 "Seed_<작물>", 수확물 "<작물>", 가구 "<가구 Id>", "Fish_<물고기>", "Ore_<광석>", 도우미 동물 "Pet_<Id>")
	Tiles = {}, -- [농지 번호 문자열] = { Tilled, Crop, PlantedAt, WateredAt } (밭 k의 칸 = 9k−8 .. 9k)
	Fields = 1, -- 연 밭 수(밭 하나 = 3×3 농지, 안내인에게서 더 산다)
	Chunks = {}, -- 산 땅 { { X, Z, Zone } } (시작 섬 16청크 밖, 산 순서). 섬 모양 = 시드 + 이 목록
	Mined = {}, -- [광석 블록 "x,y,z"] = 캔 시각(os.time). 광석마다 Respawn초 뒤 다시 차오른다
	Settings = {}, -- 클라이언트 설정(움직임 줄이기 등)
	Dex = {}, -- [분류][Id] = { Count, First }
	Placed = {}, -- { { Id, P = { x, y, z }, R } }
	Npc = {}, -- [NPC Id] = 대화 변수(Met 등)
	Chores = 0, -- 섬에 남아 있는 집안일 개수(자리는 매번 새로 고른다)
	LastSeen = 0, -- 마지막 저장 시각(os.time)
	-- Union = { Id }: 섬 연합(UnionService). 기본값 없음 = 혼자
}

-- 옛 데이터에 없는 칸을 기본값으로 채운다(표는 복사해서 플레이어끼리 공유되지 않게).
local function reconcile(data)
	for key, value in DEFAULT do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		end
	end
	return data
end

local DataService = {}
local store
local profiles = {} -- [player] = Data. 살아 있는 테이블이라 다른 서비스가 직접 고치고, 저장 때 그대로 쓴다

local function keyFor(player)
	return "player_" .. player.UserId
end

local function isMine(lock)
	return lock == nil or lock.JobId == game.JobId
end

-- 잠금을 잡으며 불러온다. 다른 서버가 잡고 있으면 기다렸다 다시 시도하고, LOCK_TTL이 지난 잠금은 가져온다.
local function acquire(key)
	for attempt = 1, 5 do
		local busy = false
		local ok, record = pcall(store.UpdateAsync, store, key, function(old)
			old = old or { Data = {} }
			busy = not isMine(old.Lock) and os.time() - old.Lock.Time < LOCK_TTL
			if busy then
				return nil -- 쓰지 않는다
			end
			old.Lock = { JobId = game.JobId, Time = os.time() }
			return old
		end)
		if ok and not busy then
			return record.Data
		elseif not ok then
			warn("[DataService] 불러오기 실패:", record)
		end
		task.wait(attempt * 2)
	end
	return nil
end

-- release = 잠금도 푼다(퇴장·종료). 세션을 다른 서버가 가져갔으면 쓰지 않는다.
local function save(player, release)
	local data = profiles[player]
	if not store or not data then
		return
	end
	data.LastSeen = os.time()
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function(old)
		if old and not isMine(old.Lock) then
			return nil
		end
		return { Data = data, Lock = if release then nil else { JobId = game.JobId, Time = os.time() } }
	end)
	if not ok then
		warn("[DataService] 저장 실패:", err)
	end
end

-- 플레이어 데이터(살아 있는 테이블)를 돌려준다. 실패하면 플레이어를 내보내고 nil.
function DataService.Load(player)
	local data
	if store then
		data = acquire(keyFor(player))
		if not data then
			player:Kick("데이터를 불러오지 못했어요. 잠시 후 다시 들어와 주세요.")
			return nil
		end
	else
		data = {}
	end
	profiles[player] = reconcile(data)
	if not player.Parent then -- 불러오는 사이에 나갔다
		DataService.Release(player)
		return nil
	end
	return data
end

-- 불러온 플레이어의 데이터(없으면 nil)
function DataService.Get(player)
	return profiles[player]
end

-- 마지막 저장 + 잠금 해제. 퇴장할 때 부른다.
function DataService.Release(player)
	save(player, true)
	profiles[player] = nil
end

function DataService.Start()
	if game.PlaceId ~= 0 then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
		store = ok and result or nil
	end
	if store and RunService:IsStudio() and not pcall(store.GetAsync, store, "studio_probe") then
		store = nil -- Studio API 접근이 꺼져 있다
	end
	if not store then
		warn("[DataService] DataStore를 쓸 수 없어 이번 세션은 저장하지 않습니다")
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)
	-- 서버가 닫힐 때 남은 플레이어를 모두 저장하고, 끝날 때까지 기다린다.
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return DataService

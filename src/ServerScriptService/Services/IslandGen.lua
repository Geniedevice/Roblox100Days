-- 시드 하나로 마인크래프트식 복셀 하늘섬을 만든다. 같은 시드 + 같은 산 땅 목록 = 같은 섬이라 저장은 그 둘뿐이다.
-- 섬은 16×16블록 청크로 되어 있고 시작 섬은 4×4 = 16청크다. 청크마다 구역이 있다(명세: design/gdd/island-zones.md):
--   상점 거리 Plaza(스폰·노점 NPC·안내인), 농장 Farm(3×3 밭 자리 4개), 낚시터 Fishing(호수·부두), 집터 House(오두막·가구),
--   숲 Wild(컨셉 지형 그대로, 광석 바위가 솟는 곳 — MineService). 광산 구역은 2026-10-24에 없앴다(저장된 Mine은 숲으로 읽는다).
-- 땅을 사면(안내인) 섬에 붙은 빈 자리 하나(무작위)에 청크가 붙고, 그 청크만 따로 만든다(GenerateChunk). 바이옴(컨셉)은
-- 살 때 무작위로 정해 저장한다(Biome). 시작 섬은 시드 컨셉, 산 청크는 저마다의 바이옴 표면·나무·땅 장식·색을 쓴다.
-- 마인크래프트 1.18+ 월드 생성 순서를 하늘섬에 옮겼다(명세: design/gdd/island-generation.md):
--  1. 기후 → 컨셉: 시드에서 T·H·E·W를 뽑아 가장 가까운 기후점의 컨셉(다중 노이즈 바이옴 소스)
--  2. 지형 밀도: density = base3D + 4 × quarterNegative(depth × 0.5). 숲은 offset 스플라인(침식·봉우리 PV)·뾰족함,
--     다른 구역은 마당 높이로 평평하게(광산은 그 위 계단식 언덕) 섞는다. 해안선은 청크 경계를 노이즈로 깎는다
--  3. 동굴: 치즈(큰 방)·스파게티(두 노이즈 교차)·누들(가는 굴), 컨셉 특수 지형(아치·정동)
--  4. 대수층: 낚시터 청크를 채우는 호수, 섬 끝으로 흐르는 물길과 폭포
--  5. 표면 규칙 시퀀스(구역·컨셉별), 심층암 경계, 광맥(능선 노이즈 띠), 광산 광석
--  6. 구조물(노점·오두막·부두·밭 길) → 나무·특수 장식(숲) → 땅 장식(들꽃·낙엽 더미 등)
-- 무작위: 순서가 고정된 것(컨셉·모양·위성 섬)만 Random.new(seed), 자리마다 정하는 것은 좌표 해시(시드 섞음)라
-- 땅을 넓혀도 원래 있던 나무·광석·장식이 그대로다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blocks = require(ReplicatedStorage.Shared.Blocks)
local Concepts = require(ReplicatedStorage.Shared.IslandConcepts)
local Loot = require(ReplicatedStorage.Shared.Loot)

local IslandGen = {}

IslandGen.CELL = 3 -- 블록 한 변(스터드). 캐릭터 ≈ 1.7블록, 2블록 높이까지 점프로 오른다
IslandGen.CHUNK = 16 -- 청크 한 변(블록)
local CHUNK = IslandGen.CHUNK
local YARD = 2 -- 평평한 구역의 윗면 높이(블록 좌표 평면). 땅 윗면 블록은 y = YARD − 1
IslandGen.YARD = YARD

IslandGen.Zones = {
	Plaza = { Name = "상점 거리" },
	Farm = { Name = "농장" },
	Fishing = { Name = "낚시터" },
	House = { Name = "집터" },
	Wild = { Name = "숲" },
}
IslandGen.BuyZones = { "Farm", "House", "Wild" } -- 안내인에게서 살 수 있는 땅 종류(대화 선택지 순서)
IslandGen.MAX_CHUNKS = 36 -- 시작 16 + 산 땅 20
local BOUND = 4 -- 청크 좌표 −4..3(8×8) 안에서만 넓힌다(슬롯 간격·연합 자리 안)
local APRON = 3 -- 산 청크는 옆 청크 해안이 깎인 틈(0~3블록)까지 메운다

-- 시작 섬(줄 = cz −2..1 북→남, 칸 = cx −2..1 서→동)
local START = {
	{ "Wild", "Wild", "Wild", "Wild" },
	{ "Wild", "Farm", "Plaza", "Fishing" },
	{ "Wild", "Farm", "Plaza", "Fishing" },
	{ "Wild", "Wild", "House", "House" },
}
IslandGen.Start = {}
for row, zones in START do
	for col, zone in zones do
		table.insert(IslandGen.Start, { X = col - 3, Z = row - 3, Zone = zone })
	end
end

-- 상점 거리 배치(블록 좌표). Spawn은 길 가운데(x = 8은 길 블록 7·8 사이), NPC는 Face 쪽을 본다
local SPAWN = Vector3.new(8, YARD, 8)
local NPC_SPOTS = {
	Guide = { Position = Vector2.new(10.5, 4.5), Face = Vector2.new(8, 8) },
	Gardener = { Position = Vector2.new(3.5, -4.5), Face = Vector2.new(8, -4.5) },
	Carpenter = { Position = Vector2.new(12.5, 10.5), Face = Vector2.new(8, 10.5) },
}
local FIELD_OFFSETS = { { 3, 3 }, { 10, 3 }, { 3, 10 }, { 10, 10 } } -- 농장 청크 안 3×3 밭 자리(왼쪽 위 칸)

local ID = Blocks.Id
local AIR = 0

local HILL_FREQ = 0.06
local BASE3D_FREQ = Vector3.new(0.11, 0.16, 0.11)
local CAVE = { Cheese = 0.055, Spaghetti = 0.085, Noodle = 0.16 }
local BLEND = 3 -- 구역 경계에서 높이를 섞는 폭(블록)
local FALL = 10 -- 해안에서 이만큼 안쪽까지 숲 언덕이 낮아진다
local DEEP = 18 -- 해안에서 이만큼 안쪽까지 밑면이 깊어진다
local DEPTH_SCALE = 18 -- 컨셉 Shape.Depth × 이 값 = 가운데 밑면 깊이(블록)
local UNDER = 4 -- 밑면 계단 칸 크기(블록)

local MINE_SURFACE = {
	{ Floor = 0, Noise = 0.4, Block = "Gravel" },
	{ Floor = 0, Noise = 0.15, Block = "CoarseDirt" },
	{ Below = -6, Block = "Deepslate" },
	{ Block = "Stone" },
}

-- 마인크래프트 밀도 함수의 두 연산
local function quarterNegative(v)
	return if v < 0 then v / 4 else v
end
local function halfNegative(v)
	return if v < 0 then v / 2 else v
end
local function smooth(t)
	return t * t * (3 - 2 * t)
end

-- 점 목록 { { t, v }, … }을 잇는 꺾은선(마인크래프트 terrain spline의 간단한 형태)
local function spline(points, t)
	if t <= points[1][1] then
		return points[1][2]
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if t <= b[1] then
			return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
		end
	end
	return points[#points][2]
end

-- 침식(평평함) → 언덕 배율, 봉우리(PV) → 더해지는 높이 비율
local EROSION_SPLINE = { { 0, 1.6 }, { 0.35, 1.1 }, { 0.7, 0.6 }, { 1, 0.35 } }
local PV_SPLINE = { { -1, -0.3 }, { 0, 0 }, { 0.6, 0.4 }, { 1, 1 } }

-- 좌표 해시(0..1): 블록마다 정해진 무작위
local function hash(x, y, z, salt)
	local h = bit32.bxor(x * 73856093, y * 19349663, z * 83492791, salt)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 1274126177) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / 4294967296
end
IslandGen.Hash = hash

local function fbm2(x, z, o, octaves)
	local total, amp, norm = 0, 1, 0
	for _ = 1, octaves do
		total += amp * math.noise(x + o.X, z + o.Y, o.Z)
		norm += amp
		amp *= 0.5
		x, z = x * 2, z * 2
	end
	return math.clamp(total / norm * 2, -1, 1) -- math.noise는 대략 -0.5..0.5
end

local function noise3(x, y, z, o)
	return math.clamp(math.noise(x + o.X, y + o.Y, z + o.Z) * 2, -1, 1)
end

local function chunkKey(cx, cz)
	return (cx + 64) * 128 + (cz + 64)
end

-- 시작 섬 + 산 땅(저장 목록, 잘못된 칸은 건너뛴다) → 청크 목록 { X, Z, Zone, Biome? }, [chunkKey] = 구역
function IslandGen.Chunks(extra)
	local list, map = {}, {}
	local function add(c, zone)
		local key = chunkKey(c.X, c.Z)
		if not map[key] then
			map[key] = zone
			table.insert(list, { X = c.X, Z = c.Z, Zone = zone, Biome = if Concepts[c.Biome or ""] then c.Biome else nil })
		end
	end
	for _, c in IslandGen.Start do
		add(c, c.Zone)
	end
	for _, c in extra or {} do
		local zone = type(c) == "table" and (if c.Zone == "Mine" then "Wild" else c.Zone)
		if zone and table.find(IslandGen.BuyZones, zone) and type(c.X) == "number" and type(c.Z) == "number" then
			add(c, zone)
		end
	end
	return list, map
end

-- 섬에 붙은(상하좌우) 빈 청크 자리 목록 { { X, Z } } — 땅을 살 때 여기서 하나를 무작위로 고른다. 다 찼으면 빈 목록
function IslandGen.Candidates(extra)
	local list, map = IslandGen.Chunks(extra)
	local spots = {}
	if #list >= IslandGen.MAX_CHUNKS then
		return spots
	end
	local seen = {}
	for _, c in list do
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local x, z = c.X + d[1], c.Z + d[2]
			local key = chunkKey(x, z)
			if not map[key] and not seen[key] and x >= -BOUND and x < BOUND and z >= -BOUND and z < BOUND then
				seen[key] = true
				table.insert(spots, { X = x, Z = z })
			end
		end
	end
	table.sort(spots, function(a, b) -- 순서를 고정한다(무작위 고르기가 재현되게)
		return if a.X ~= b.X then a.X < b.X else a.Z < b.Z
	end)
	return spots
end

-- 바이옴(컨셉) Id 목록(이름 순, 무작위로 하나 고를 때)
function IslandGen.Biomes()
	local ids = {}
	for id in Concepts do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- 기후에 가장 가까운 컨셉(마인크래프트 다중 노이즈: 매개변수 공간의 최근접점)
function IslandGen.PickConcept(climate)
	local best, bestDistance = nil, math.huge
	for id, concept in Concepts do
		local c = concept.Climate
		local d = (c.T - climate.T) ^ 2 + (c.H - climate.H) ^ 2 + (c.E - climate.E) ^ 2 + (c.W - climate.W) ^ 2
		if d < bestDistance then
			best, bestDistance = id, d
		end
	end
	return best
end

-- 반환: { Seed, Concept, Climate, Min, Size(블록), Data(buffer), Get, Decor = { { Kind, Position(블록), Rotation, Length, Text } },
--   Waterfalls = { { Position(블록), Direction } }, YardY(블록), Spawn(블록), Npc = { [Id] = { Position, Face } },
--   Fields = { Vector2(3×3 밭 왼쪽 위 칸) } 순서 고정, Chunks = 청크 목록, ZoneAt(x, z) → 구역 Id 또는 nil }
-- extra = profile.Chunks(산 땅), forceConcept = 미리보기·시험용 컨셉 고정
-- only = 산 청크 하나만 만든다(GenerateChunk): 그 청크 + 둘레 APRON블록(옆 땅이 없는 칸만, filled(x, z)가 false)
function IslandGen.Generate(seed, extra, forceConcept, only, filled)
	local rng = Random.new(seed)
	local salt = seed % 1000003 * 37
	local function r(x, y, z, k) -- 자리마다 정해진 0..1(시드마다 다르다)
		return hash(x, y, z, salt + k)
	end
	local function offset()
		return Vector3.new(rng:NextNumber(-1e4, 1e4), rng:NextNumber(-1e4, 1e4), rng:NextNumber(-1e4, 1e4))
	end
	local function range(v)
		return rng:NextNumber(v[1], v[2])
	end

	-- 1. 기후 → 컨셉, 모양 값(이 순서로만 rng를 쓴다)
	local climate = { T = rng:NextNumber(), H = rng:NextNumber(), E = rng:NextNumber(), W = rng:NextNumber() }
	local conceptId = forceConcept or IslandGen.PickConcept(climate)
	local concept = Concepts[conceptId]
	local shape = concept.Shape
	local features = concept.Features
	local main = {
		Coast = range(shape.Coast), Hill = range(shape.Hill), Depth = range(shape.Depth) * DEPTH_SCALE,
		O2 = offset(), O3 = offset(), O4 = offset(), O5 = offset(),
	}
	local noise = { Base = offset(), Cheese = offset(), SpagA = offset(), SpagB = offset(), NoodA = offset(), NoodB = offset(),
		Patch = offset(), Band = offset(), Ore = offset(), Vein = offset(), Coast = offset(), Mine = offset(), Lake = offset() }
	local caves = {
		Cheese = rng:NextNumber() < (concept.Caves.Cheese or 0),
		Spaghetti = concept.Caves.Spaghetti == true,
		Noodle = concept.Caves.Noodle == true,
	}
	local hasWaterfall = rng:NextNumber() < (concept.Waterfall or 0) and not only

	-- 청크와 구역
	local chunks, owned = IslandGen.Chunks(extra)
	local function zoneAt(x, z)
		return owned[chunkKey(x // CHUNK, z // CHUNK)]
	end
	local cx0, cx1, cz0, cz1 = math.huge, -math.huge, math.huge, -math.huge
	for _, c in chunks do
		cx0, cx1, cz0, cz1 = math.min(cx0, c.X), math.max(cx1, c.X), math.min(cz0, c.Z), math.max(cz1, c.Z)
	end
	local bx0, bx1, bz0, bz1 = cx0 * CHUNK, cx1 * CHUNK + CHUNK - 1, cz0 * CHUNK, cz1 * CHUNK + CHUNK - 1
	local building = chunks -- 이번에 만드는 청크(구조물·밭·숲 장식을 놓는 곳)
	if only then
		building = { only }
		bx0, bx1 = only.X * CHUNK - APRON, only.X * CHUNK + CHUNK - 1 + APRON
		bz0, bz1 = only.Z * CHUNK - APRON, only.Z * CHUNK + CHUNK - 1 + APRON
	end
	local function inOnly(x, z)
		return x // CHUNK == only.X and z // CHUNK == only.Z
	end

	-- (x, z) 칸 가운데에서 pred(구역)가 참인 가장 가까운 청크까지 거리(블록, ±2청크 안, 없으면 2청크)
	local function chunkDistance(x, z, pred)
		local px, pz = x + 0.5, z + 0.5
		local ccx, ccz = x // CHUNK, z // CHUNK
		local best = 2 * CHUNK
		for dx = -2, 2 do
			for dz = -2, 2 do
				local zx, zz = ccx + dx, ccz + dz
				if pred(owned[chunkKey(zx, zz)]) then
					local x0, z0 = zx * CHUNK, zz * CHUNK
					local ex = math.max(x0 - px, 0, px - x0 - CHUNK)
					local ez = math.max(z0 - pz, 0, pz - z0 - CHUNK)
					best = math.min(best, math.sqrt(ex * ex + ez * ez))
				end
			end
		end
		return best
	end
	local function unowned(zone)
		return zone == nil
	end
	local function otherOwned(zone) -- 광산 언덕은 섬 안쪽 다른 구역에서 멀수록 높다(바깥 가장자리는 절벽)
		return zone ~= nil and zone ~= "Mine"
	end
	local function notFishing(zone)
		return zone ~= "Fishing"
	end

	-- 떠 있는 작은 섬: 섬 상자 가장자리 밖(넓히면 같이 밀려난다)
	local function makeShape(x, z, y, radius, coast, hill, depth)
		return {
			X = x, Z = z, Y = y, R = radius, Coast = coast, Lobes = rng:NextNumber(1.2, 2.6),
			Hill = hill, Depth = depth * radius, Spikes = shape.Spikes,
			O1 = offset(), O2 = offset(), O3 = offset(),
		}
	end
	local midX, midZ = (bx0 + bx1 + 1) / 2, (bz0 + bz1 + 1) / 2
	local halfW, halfD = (bx1 - bx0 + 1) / 2, (bz1 - bz0 + 1) / 2
	local satellites = {}
	for _ = 1, if only then 0 else rng:NextInteger(concept.Satellites[1], concept.Satellites[2]) do
		local radius = rng:NextNumber(3, 6)
		local angle = rng:NextNumber(0, 2 * math.pi)
		local c, s = math.cos(angle), math.sin(angle)
		local toEdge = math.min(halfW / math.max(math.abs(c), 1e-3), halfD / math.max(math.abs(s), 1e-3))
		local dist = toEdge + radius * 1.3 + rng:NextNumber(3, 9)
		table.insert(satellites, makeShape(midX + c * dist, midZ + s * dist, YARD + rng:NextInteger(-8, 6), radius, 0.2,
			rng:NextNumber(0.5, 2), rng:NextNumber(1, 1.6)))
	end
	local function satelliteColumn(s, x, z)
		local dx, dz = x - s.X, z - s.Z
		local angle = math.atan2(dz, dx)
		local edge = s.R * (1 + s.Coast * fbm2(math.cos(angle) * s.Lobes, math.sin(angle) * s.Lobes, s.O1, 2))
		local f = 1 - math.sqrt(dx * dx + dz * dz) / edge
		if f <= 0 then
			return nil
		end
		local hill = fbm2(x * HILL_FREQ, z * HILL_FREQ, s.O2, 3) * 0.5 + 0.5
		local top = s.Y + 1 + math.min(1, f * 3) * s.Hill * hill
		local spike = math.max(0, fbm2(x * 0.2, z * 0.2, s.O3, 2)) * s.Spikes
		return top, s.Y - s.Depth * f ^ 0.85 * (0.75 + 0.6 * spike)
	end

	-- 폭포 물길: 섬 가장자리에 닿은 낚시터 청크의 바깥 방향(가운데 줄 한 칸 폭)
	local channel
	if hasWaterfall then
		for _, c in chunks do
			if c.Zone == "Fishing" and not channel then
				for _, dir in { { 1, 0 }, { 0, 1 }, { 0, -1 }, { -1, 0 } } do
					if not owned[chunkKey(c.X + dir[1], c.Z + dir[2])] then
						channel = { X = c.X, Z = c.Z, DX = dir[1], DZ = dir[2], LineX = c.X * CHUNK + 8, LineZ = c.Z * CHUNK + 8 }
						break
					end
				end
			end
		end
	end
	local function onChannel(x, z)
		if not channel or x // CHUNK ~= channel.X or z // CHUNK ~= channel.Z then
			return false
		end
		if channel.DX ~= 0 then
			return z == channel.LineZ and (x - channel.LineX) * channel.DX >= 0
		end
		return x == channel.LineX and (z - channel.LineZ) * channel.DZ >= 0
	end

	-- 2. 기둥: 구역 높이(경계 BLEND블록 섞기), 숲 지형, 광산 언덕, 호수, 밑면
	local W, D = bx1 - bx0 + 1, bz1 - bz0 + 1
	local function gi(x, z)
		return (x - bx0) * D + (z - bz0)
	end
	local flatRaw, mineRaw = {}, {}
	for x = bx0, bx1 do
		for z = bz0, bz1 do
			local zone = zoneAt(x, z)
			if zone then
				flatRaw[gi(x, z)] = if zone == "Wild" then 0 else 1
				mineRaw[gi(x, z)] = if zone == "Mine" then 1 else 0
			end
		end
	end
	local function blur(src) -- 땅 칸끼리만 평균(가로 → 세로)
		local pass, out = {}, {}
		for step = 1, 2 do
			local from, to = if step == 1 then src else pass, if step == 1 then pass else out
			for x = bx0, bx1 do
				for z = bz0, bz1 do
					local i = gi(x, z)
					if from[i] then
						local sum, n = 0, 0
						for d = -BLEND, BLEND do
							local xx, zz = if step == 1 then x + d else x, if step == 1 then z else z + d
							if xx >= bx0 and xx <= bx1 and zz >= bz0 and zz <= bz1 then
								local v = from[gi(xx, zz)]
								if v then
									sum += v
									n += 1
								end
							end
						end
						to[i] = sum / n
					end
				end
			end
		end
		return out
	end
	local flatW, mineW = blur(flatRaw), blur(mineRaw)

	local function mainColumn(x, z, zone)
		local dEdge = chunkDistance(x, z, unowned)
		local cut = main.Coast * 10 * (fbm2(x * 0.13, z * 0.13, noise.Coast, 2) * 0.5 + 0.5) -- 해안을 0..3블록 깎는다
		if dEdge <= cut then
			return nil
		end
		local i = gi(x, z)
		local f = math.clamp((dEdge - cut) / FALL, 0, 1)
		-- 숲(컨셉) 지형: 침식 스플라인 × 언덕 + PV 스플라인, 능선 뾰족함, 계단
		local erosion = math.clamp(concept.Climate.E + 0.35 * fbm2(x * 0.04, z * 0.04, main.O4, 2), 0, 1)
		local weird = fbm2(x * 0.05, z * 0.05, main.O5, 2)
		local pv = 1 - math.abs(3 * math.abs(weird) - 2) -- 마인크래프트 peaks & valleys = 1 − |3|W| − 2|
		local hill = fbm2(x * HILL_FREQ, z * HILL_FREQ, main.O2, 3) * 0.5 + 0.5
		local natural = YARD + math.min(1, f * 3) * main.Hill * (hill * spline(EROSION_SPLINE, erosion) + spline(PV_SPLINE, pv))
		if shape.Jagged > 0 then
			local ridge = 1 - math.abs(fbm2(x * 0.09, z * 0.09, main.O3, 3))
			natural += shape.Jagged * halfNegative(ridge * 2 - 1) * math.clamp((f - 0.25) / 0.5, 0, 1)
		end
		if shape.Terrace > 0 then
			natural = math.floor(natural / shape.Terrace + 0.5) * shape.Terrace
		end
		local flat = smooth(flatW[i])
		local top = natural + (YARD - natural) * flat
		if mineW[i] > 0 then
			local inward = chunkDistance(x, z, otherOwned)
			local rise = 3 + 9 * smooth(math.clamp(inward / 14, 0, 1)) + 2.5 * fbm2(x * 0.08, z * 0.08, noise.Mine, 2)
			top += math.max(0, math.floor(rise / 2 + 0.5) * 2) * smooth(mineW[i]) -- 2블록 계단
		end
		local water
		if zone == "Fishing" then
			local inLake = chunkDistance(x, z, notFishing) - 3.5 + 1.2 * fbm2(x * 0.15, z * 0.15, noise.Lake, 2)
			if inLake > 0 then
				top, water = YARD - 1 - math.min(3, math.floor(inLake * 0.7)), YARD
			elseif onChannel(x, z) then
				top, water = YARD - 1, YARD
			end
		end
		-- 밑면은 4×4블록 칸마다 한 깊이(계단식 종유석). 층마다 합친 Part가 칸 경계에 맞아 몇 개로 끝난다
		local mx, mz = x // UNDER * UNDER + UNDER // 2, z // UNDER * UNDER + UNDER // 2
		local g = math.clamp((chunkDistance(mx, mz, unowned) - main.Coast * 5) / DEEP, 0, 1)
		local spike = math.max(0, fbm2(mx * 0.2, mz * 0.2, main.O3, 2)) * shape.Spikes
		local bottom = YARD - 2 - main.Depth * g ^ 0.85 * (0.75 + 0.6 * spike)
		return top, bottom, water, flat, dEdge - cut
	end

	-- 버퍼 크기
	local minX, maxX, minZ, maxZ = bx0, bx1, bz0, bz1
	local minY = YARD - 2 - main.Depth * 1.4
	for _, s in satellites do
		minX, maxX = math.min(minX, s.X - s.R * 1.3), math.max(maxX, s.X + s.R * 1.3)
		minZ, maxZ = math.min(minZ, s.Z - s.R * 1.3), math.max(maxZ, s.Z + s.R * 1.3)
		minY = math.min(minY, s.Y - s.Depth * 1.4)
	end
	minX, maxX, minZ, maxZ = math.floor(minX) - 2, math.ceil(maxX) + 2, math.floor(minZ) - 2, math.ceil(maxZ) + 2
	minY = math.floor(minY) - 3
	local maxY = YARD + math.max(math.ceil(main.Hill * 2.7 + shape.Jagged) + 2, 16) + 18 -- 위로 나무·얼음 가시 자리
	local nx, ny, nz = maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1
	local data = buffer.create(nx * ny * nz)
	local function inside(x, y, z)
		return x >= minX and x <= maxX and z >= minZ and z <= maxZ and y >= minY and y <= maxY
	end
	local function get(x, y, z)
		return if inside(x, y, z) then buffer.readu8(data, ((x - minX) * ny + (y - minY)) * nz + (z - minZ)) else AIR
	end
	local function set(x, y, z, id)
		if inside(x, y, z) then
			buffer.writeu8(data, ((x - minX) * ny + (y - minY)) * nz + (z - minZ), id)
		end
	end
	local function setIfAir(x, y, z, id)
		if get(x, y, z) == AIR then
			set(x, y, z, id)
		end
	end

	-- 3. 지형 밀도 + 동굴. 임시로 Stone을 채우고 표면 규칙에서 바꾼다
	local STONE, WATER = ID.Stone, ID.Water
	-- 땅이 있는 기둥. 반복은 늘 이 배열 순서로 돈다(해시 테이블 순회 순서에 기대지 않는다)
	local columns = {}
	local tops, waters, zones, flats, edges = {}, {}, {}, {}, {} -- [x * 1000 + z]
	for x = minX, maxX do
		for z = minZ, maxZ do
			local zone = if x >= bx0 and x <= bx1 and z >= bz0 and z <= bz1 then zoneAt(x, z) else nil
			if zone and only and not inOnly(x, z) and filled(x, z) then
				zone = nil -- 옆 청크에 이미 땅이 있는 칸(깎인 해안 틈만 메운다)
			end
			local top, bottom, water, flat, edge
			if zone then
				top, bottom, water, flat, edge = mainColumn(x, z, zone)
			end
			if not top then
				zone = nil
				for _, s in satellites do
					top, bottom = satelliteColumn(s, x + 0.5, z + 0.5)
					if top then
						break
					end
				end
			end
			if top then
				local key = x * 1000 + z
				table.insert(columns, { X = x, Z = z, Key = key, Zone = zone })
				tops[key], waters[key], zones[key], flats[key], edges[key] = top, water, zone, flat or 0, edge or 0
				-- 3D 노이즈 세기: 평평한 구역·호수는 0(돌출이 마당·물을 메우지 않게), 작은 섬은 절반
				local amp = if water then 0 elseif zone then shape.Overhang * (1 - flat) else shape.Overhang * 0.5
				for y = math.floor(bottom) - 2, math.ceil(top) + 2 do
					local cy = y + 0.5
					local depth = math.min(top - cy, cy - bottom)
					-- 3D 노이즈는 윗면 쪽 절반에만(돌출·처마). 밑면 계단은 깔끔하게 둔다
					local base = if amp > 0 and top - cy < cy - bottom then amp * noise3(x * BASE3D_FREQ.X, y * BASE3D_FREQ.Y, z * BASE3D_FREQ.Z, noise.Base) else 0
					if base + 4 * quarterNegative(depth * 0.5) > 0 then
						local carve = false
						-- 동굴은 숲·광산 아래만(평평한 구역 아래 동굴은 보이지 않고 Part만 늘린다)
						if (zone == "Wild" or zone == "Mine") and top - cy > 3 and cy - bottom > 2 then
							if caves.Cheese then
								carve = noise3(x * CAVE.Cheese, y * CAVE.Cheese * 1.5, z * CAVE.Cheese, noise.Cheese) > 0.55
							end
							if not carve and caves.Spaghetti then
								carve = math.abs(noise3(x * CAVE.Spaghetti, y * CAVE.Spaghetti * 1.4, z * CAVE.Spaghetti, noise.SpagA)) < 0.09
									and math.abs(noise3(x * CAVE.Spaghetti, y * CAVE.Spaghetti * 1.4, z * CAVE.Spaghetti, noise.SpagB)) < 0.09
							end
							if not carve and caves.Noodle then
								carve = math.abs(noise3(x * CAVE.Noodle, y * CAVE.Noodle, z * CAVE.Noodle, noise.NoodA)) < 0.05
									and math.abs(noise3(x * CAVE.Noodle, y * CAVE.Noodle, z * CAVE.Noodle, noise.NoodB)) < 0.05
							end
						end
						if not carve then
							set(x, y, z, STONE)
						end
					end
				end
				if water then
					for y = math.ceil(top - 0.5), water - 1 do
						if get(x, y, z) == AIR then
							set(x, y, z, WATER)
						end
					end
				end
			end
		end
	end

	-- 특수 지형: 아치(섬을 동서로 관통하는 굴, 윗면 3블록은 다리로 남긴다). 시작 섬 북쪽 줄 아래
	if features.Arch then
		local az, cy = -2 * CHUNK + 8, YARD - 8
		for x = minX, maxX do
			for y = cy - 3, cy + 3 do
				for z = az - 3, az + 3 do
					local key = x * 1000 + z
					if (y - cy) ^ 2 + (z - az) ^ 2 <= 9.5 and tops[key] and tops[key] - (y + 0.5) > 3 then
						set(x, y, z, AIR)
					end
				end
			end
		end
	end

	-- 4. 표면 규칙(위에서부터 첫 번째로 맞는 규칙). 기둥의 윗면·밑면·가파름을 먼저 잰다
	local columnTop, columnBottom = {}, {}
	for _, c in columns do
		local x, z, key = c.X, c.Z, c.Key
		for y = maxY, minY, -1 do
			local id = get(x, y, z)
			if id ~= AIR and id ~= WATER then
				columnTop[key] = y
				break
			end
		end
		for y = minY, maxY do
			local id = get(x, y, z)
			if id ~= AIR and id ~= WATER then
				columnBottom[key] = y
				break
			end
		end
	end
	local function steep(x, z)
		local t = columnTop[x * 1000 + z]
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local n = columnTop[(x + d[1]) * 1000 + z + d[2]]
			if not n or math.abs(n - t) >= 3 then
				return true
			end
		end
		return false
	end
	local function decide(rules, x, y, z, key, isFlat)
		local floorDepth = columnTop[key] - y
		local ceilingDepth = y - columnBottom[key]
		for _, rule in rules do
			local ok = (rule.Floor == nil or floorDepth <= rule.Floor)
				and (rule.Ceiling == nil or ceilingDepth <= rule.Ceiling)
				and (rule.Above == nil or y >= rule.Above)
				and (rule.Below == nil or y < rule.Below + (if hash(x, y, z, 7) < 0.5 then 1 else 0))
				and (rule.Steep == nil or (not isFlat and steep(x, z)))
				and (rule.Noise == nil or (not isFlat and fbm2(x * 0.15, z * 0.15, noise.Patch, 2) > rule.Noise))
			if ok then
				if rule.Bands then
					local shift = math.floor(fbm2(x * 0.03, z * 0.03, noise.Band, 1) * 2)
					return ID[rule.Bands[(y + shift) % #rule.Bands + 1]]
				end
				return ID[rule.Block]
			end
		end
		return STONE
	end
	local function nearWater(x, z, radius)
		for dx = -radius, radius do
			for dz = -radius, radius do
				if waters[(x + dx) * 1000 + z + dz] then
					return true
				end
			end
		end
		return false
	end
	local yardBlock = ID[concept.Yard or "Grass"]
	local mineRules = concept.MineSurface or MINE_SURFACE
	for _, c in columns do
		local x, z, key, zone = c.X, c.Z, c.Key, c.Zone
		local isFlat = zone ~= nil and zone ~= "Wild" and zone ~= "Mine" and flats[key] > 0.5
		local rules = if zone == "Mine" then mineRules else concept.Surface
		local top, bottom = columnTop[key], columnBottom[key]
		local topBlock = yardBlock
		if waters[key] then
			topBlock = if hash(x, 0, z, 17) < 0.6 then ID.Sand else ID.Gravel -- 호수 바닥
		elseif zone == "Fishing" and nearWater(x, z, 1) then
			topBlock = ID.Sand -- 물가 모래
		end
		if top then
			for y = bottom, top do
				if get(x, y, z) == STONE then
					-- 광석은 지형에 박지 않는다(숲 빈 땅에 솟는 광석 바위, MineService)
					set(x, y, z, if isFlat and y == top then topBlock else decide(rules, x, y, z, key, isFlat))
				end
			end
		end
	end

	local loot = Loot.ForIsland(seed, conceptId) -- 바이옴마다 물고기·광석 비율이 다르다(광석 바위는 그 땅 바이옴 표)

	-- 5. 구조물(블록) — 자리를 쓴 칸은 reserved에 적어 장식이 올라오지 않게 한다
	local decor, waterfalls, reserved = {}, {}, {}
	local function reserve(x, z)
		reserved[x * 1000 + z] = true
	end
	local function addDecor(kind, x, y, z, length, rotation, text)
		table.insert(decor, { Kind = kind, Position = Vector3.new(x + 0.5, y, z + 0.5), Rotation = rotation or r(x, y, z, 70) * 360,
			Length = length, Text = text })
	end
	local function surfaceAt(x, z)
		local top = columnTop[x * 1000 + z]
		return top and get(x, top + 1, z) == AIR and top or nil
	end
	local function flatGround(x, z) -- 평평한 마당 높이의 땅 칸(물 아님)
		local key = x * 1000 + z
		return zones[key] ~= nil and not waters[key] and columnTop[key] == YARD - 1
	end
	local function faceYaw(x, z, tx, tz) -- (x, z)에서 (tx, tz)를 바라보는 Rotation(도)
		return math.deg(math.atan2(-(tx - x), -(tz - z)))
	end

	-- 상점 거리: 십자 길(가로 z 0·1, 세로 x 7·8), 노점 두 개, 길모퉁이 등불, 안내도
	if not only and owned[chunkKey(0, 0)] == "Plaza" then
		for x = bx0, bx1 do
			for z = bz0, bz1 do
				local cross = (z == 0 or z == 1) and x >= -16 and x <= 17 or (x == 7 or x == 8) and z >= -15 and z <= 19
				local zone = zoneAt(x, z)
				if cross and (zone == "Plaza" or zone == "Farm" or zone == "House" or zone == "Fishing") and flatGround(x, z) then
					set(x, YARD - 1, z, ID.Path)
					reserve(x, z)
				end
			end
		end
		-- 노점: 가운데 칸(cx, cz)에 NPC, dir 쪽(±x)이 앞 계산대. 기둥 4개, 줄무늬 천막, 뒤에 상자
		local function stall(cx, cz, dir, wool, crate)
			for d = -1, 1 do
				for w = -2, 2 do
					local x, z = cx + d * dir, cz + w
					reserve(x, z)
					if math.abs(w) == 2 and d ~= 0 then
						for y = YARD, YARD + 2 do
							set(x, y, z, ID.OakLog)
						end
					elseif d == 1 and math.abs(w) < 2 then
						set(x, YARD, z, ID.OakPlanks)
					elseif d == -1 and math.abs(w) == 1 then
						set(x, YARD, z, crate)
					end
				end
			end
			for d = -2, 2 do
				for w = -2, 2 do
					set(cx + d * dir, YARD + 3, cz + w, if (cz + w) % 2 == 0 then wool else ID.WoolWhite)
				end
			end
		end
		stall(3, -5, 1, ID.WoolGreen, ID.HayBale)
		stall(12, 10, -1, ID.WoolRed, ID.OakPlanks)
		for _, spot in { { 6, -1 }, { 9, -1 }, { 6, 2 }, { 9, 2 }, { 6, -10 }, { 9, -10 }, { 6, 13 }, { 9, 13 } } do
			addDecor("Lantern", spot[1], YARD, spot[2])
			reserve(spot[1], spot[2])
		end
		local guide = NPC_SPOTS.Guide.Position
		reserve(math.floor(guide.X), math.floor(guide.Y))
		addDecor("Board", 12, YARD, 3, nil, faceYaw(12.5, 3.5, SPAWN.X, SPAWN.Z), "하늘섬 안내도")
		reserve(12, 3)
		for dx = -1, 0 do
			for dz = -1, 1 do
				reserve(SPAWN.X + dx, SPAWN.Z + dz)
			end
		end
	end

	-- 농장: 청크마다 3×3 밭 자리 4개(둘레 길), 가운데 허수아비. 순서 = 시작 청크(스폰에서 가까운 밭부터) → 산 순서
	local fields = {}
	for index, c in building do
		if c.Zone == "Farm" then
			local mine = {}
			for _, o in FIELD_OFFSETS do
				local fx, fz = c.X * CHUNK + o[1], c.Z * CHUNK + o[2]
				for x = fx - 1, fx + 3 do
					for z = fz - 1, fz + 3 do
						reserve(x, z)
						local ring = x == fx - 1 or x == fx + 3 or z == fz - 1 or z == fz + 3
						if ring and flatGround(x, z) then
							set(x, YARD - 1, z, ID.Path)
						end
					end
				end
				table.insert(mine, Vector2.new(fx, fz))
			end
			table.sort(mine, function(a, b)
				local da = (a.X + 1.5 - SPAWN.X) ^ 2 + (a.Y + 1.5 - SPAWN.Z) ^ 2
				local db = (b.X + 1.5 - SPAWN.X) ^ 2 + (b.Y + 1.5 - SPAWN.Z) ^ 2
				return da < db
			end)
			for _, field in mine do
				table.insert(fields, { Field = field, Start = not only and index <= #IslandGen.Start, Distance = (field - Vector2.new(SPAWN.X, SPAWN.Z)).Magnitude })
			end
			local sx, sz = c.X * CHUNK + 7, c.Z * CHUNK + 7
			if surfaceAt(sx, sz) then
				addDecor("Scarecrow", sx, surfaceAt(sx, sz) + 1, sz)
			end
			reserve(sx, sz)
			for _, o in { { 14, 1 }, { 1, 14 } } do
				local hx, hz = c.X * CHUNK + o[1], c.Z * CHUNK + o[2]
				if flatGround(hx, hz) then
					set(hx, YARD, hz, ID.HayBale)
					reserve(hx, hz)
				end
			end
		end
	end
	-- 시작 밭끼리는 가까운 순, 산 땅의 밭은 산 순서 그대로 뒤에(저장된 밭 번호가 바뀌지 않게)
	local startFields, laterFields = {}, {}
	for _, f in fields do
		table.insert(if f.Start then startFields else laterFields, f)
	end
	table.sort(startFields, function(a, b)
		return a.Distance < b.Distance
	end)
	local fieldList = {}
	for _, f in startFields do
		table.insert(fieldList, f.Field)
	end
	for _, f in laterFields do
		table.insert(fieldList, f.Field)
	end

	-- 낚시터 부두: 가로 길(z 0·1)이 서쪽 물가에서 호수로 6칸 뻗는다(물 위 판자 + 끝 기둥)
	if not only and owned[chunkKey(1, 0)] == "Fishing" then
		for z = 0, 1 do
			local placed = 0
			for x = CHUNK, 2 * CHUNK - 1 do
				local key = x * 1000 + z
				if waters[key] then
					if placed >= 6 then
						break
					end
					set(x, YARD - 1, z, ID.OakPlanks)
					placed += 1
					if placed == 6 or placed == 1 then
						for y = YARD - 2, YARD - 5, -1 do
							if get(x, y, z) == WATER then
								set(x, y, z, ID.OakLog)
							end
						end
					end
				elseif flatGround(x, z) and placed == 0 then
					set(x, YARD - 1, z, ID.Path)
				end
				reserve(x, z)
			end
		end
	end

	-- 집터: 첫 집터 청크에 9×9 오두막(문은 스폰 쪽). 바닥 판자·조약돌 테두리, 통나무 모서리, 유리창, 계단식 지붕
	for _, c in if only then {} else chunks do -- 오두막은 시작 섬 첫 집터에만(산 집터는 가구 마당)
		if c.Zone == "House" then
			local x0, z0 = c.X * CHUNK + 4, c.Z * CHUNK + 4
			local dx, dz = SPAWN.X - (x0 + 4.5), SPAWN.Z - (z0 + 4.5)
			local function world(u, v) -- 오두막 칸(u 문 벽 따라, v 문에서 안쪽) → 블록 좌표
				if math.abs(dz) >= math.abs(dx) then
					return if dz < 0 then x0 + u else x0 + 8 - u, if dz < 0 then z0 + v else z0 + 8 - v
				end
				return if dx < 0 then x0 + v else x0 + 8 - v, if dx < 0 then z0 + 8 - u else z0 + u
			end
			for u = -1, 9 do
				for v = -1, 9 do
					local x, z = world(u, v)
					reserve(x, z)
					local inner = u >= 0 and u <= 8 and v >= 0 and v <= 8
					if inner then
						local wall = u == 0 or u == 8 or v == 0 or v == 8
						set(x, YARD - 1, z, if wall then ID.Cobblestone else ID.OakPlanks)
						for y = YARD, YARD + 2 do
							local id = AIR
							if wall then
								local corner = (u == 0 or u == 8) and (v == 0 or v == 8)
								local door = v == 0 and u >= 3 and u <= 5 and y <= YARD + 1
								local window = y == YARD + 1
									and ((v == 8 and (u == 2 or u == 6)) or ((u == 0 or u == 8) and (v == 2 or v == 6)) or (v == 0 and (u == 1 or u == 7)))
								id = if corner then ID.OakLog elseif door then AIR elseif window then ID.Glass else ID.OakPlanks
							end
							set(x, y, z, id)
						end
					end
				end
			end
			for k = 0, 5 do
				for u = k - 1, 9 - k do
					for v = k - 1, 9 - k do
						local x, z = world(u, v)
						set(x, YARD + 3 + k, z, ID.SprucePlanks)
					end
				end
			end
			for _, u in { 2, 6 } do
				local x, z = world(u, -1)
				local ax, az = world(4, -5)
				addDecor("Lantern", x, YARD, z, nil, faceYaw(x, z, ax, az))
			end
			break
		end
	end

	-- 구역 팻말: 시작 구역마다 하나(스폰을 본다)
	for _, sign in if only then {} else { { "Farm", -2, 3 }, { "Fishing", 16, 3 }, { "House", 6, 16 } } do
		local x, z = sign[2], sign[3]
		local top = surfaceAt(x, z)
		if top and zoneAt(x, z) == sign[1] then
			addDecor("Sign", x, top + 1, z, nil, faceYaw(x + 0.5, z + 0.5, SPAWN.X, SPAWN.Z), IslandGen.Zones[sign[1]].Name)
			reserve(x, z)
		end
	end

	-- 6. 장식(블록): 나무·특수 지형은 숲 구역에만
	local GROUNDS = { [ID.Grass] = true, [ID.Moss] = true, [ID.Podzol] = true, [ID.PaleMoss] = true, [ID.Mycelium] = true,
		[ID.Snow] = true, [ID.RedSand] = true, [ID.CoarseDirt] = true, [ID.Sand] = true, [ID.Dirt] = true }
	local function freeGround(x, z, wild)
		local key = x * 1000 + z
		local top = surfaceAt(x, z)
		if not top or not zones[key] or waters[key] or reserved[key] or not GROUNDS[get(x, top, z)] then
			return nil
		end
		if wild and (zones[key] ~= "Wild" or flats[key] > 0.05 or edges[key] < 3 or nearWater(x, z, 2)) then
			return nil -- 나무는 숲 안쪽(구역 경계·해안·물가에서 떨어져)
		end
		if wild and only and (not inOnly(x, z) or x % CHUNK < 2 or x % CHUNK > CHUNK - 3 or z % CHUNK < 2 or z % CHUNK > CHUNK - 3) then
			return nil -- 산 청크 나무는 그 청크 안쪽에만(옆 땅 나무와 겹치지 않게)
		end
		return top
	end

	local function leafBlob(cx, cy, cz, radius, leaf, squash)
		for x = -radius, radius do
			for y = -radius, radius do
				for z = -radius, radius do
					local d = x * x + (y * (squash or 1)) ^ 2 + z * z
					if d <= radius * radius + 0.5 and (d < radius * radius - 1 or hash(cx + x, cy + y, cz + z, 11) < 0.6) then
						setIfAir(cx + x, cy + y, cz + z, leaf)
					end
				end
			end
		end
	end
	local function trunk(x, y, z, height, log)
		for i = 1, height do
			set(x, y + i, z, log)
		end
	end
	local TREES = {
		Oak = function(x, y, z, t)
			local h = t:NextInteger(4, 6)
			trunk(x, y, z, h, ID.OakLog)
			leafBlob(x, y + h - 1, z, 2, ID.OakLeaves, 1.4)
			setIfAir(x, y + h + 1, z, ID.OakLeaves)
		end,
		Birch = function(x, y, z, t)
			local h = t:NextInteger(5, 7)
			trunk(x, y, z, h, ID.BirchLog)
			leafBlob(x, y + h - 1, z, 2, ID.BirchLeaves, 1.5)
			setIfAir(x, y + h + 1, z, ID.BirchLeaves)
		end,
		Spruce = function(x, y, z, t)
			local h = t:NextInteger(6, 9)
			trunk(x, y, z, h, ID.SpruceLog)
			-- 꼭대기부터 반지름 0, 1, 2, 1, 3, 1, 3 … 으로 번갈아 넓어지는 원뿔
			for k = 0, h - 2 do
				local radius = if k == 0 then 0 elseif k % 2 == 1 then 1 else math.min(3, k // 2 + 1)
				for dx = -radius, radius do
					for dz = -radius, radius do
						if math.abs(dx) + math.abs(dz) <= radius + 1 then
							setIfAir(x + dx, y + h + 1 - k, z + dz, ID.SpruceLeaves)
						end
					end
				end
			end
		end,
		Cherry = function(x, y, z, t)
			local h = t:NextInteger(4, 6)
			trunk(x, y, z, h, ID.CherryLog)
			-- 갈라진 가지 두 개 끝에 넓적한 꽃 덮개
			for _, dir in { { 1, 0 }, { -1, 0 } } do
				local bx, bz = x + dir[1] * 2, z + dir[2] * t:NextInteger(-1, 1)
				set(bx - dir[1], y + h, z, ID.CherryLog)
				set(bx, y + h + 1, bz, ID.CherryLog)
				leafBlob(bx, y + h + 2, bz, 3, ID.CherryLeaves, 2)
			end
		end,
		PaleOak = function(x, y, z, t)
			local h = t:NextInteger(6, 8)
			for dx = 0, 1 do
				for dz = 0, 1 do
					trunk(x + dx, y, z + dz, h, ID.PaleOakLog)
				end
			end
			leafBlob(x, y + h, z, 3, ID.PaleOakLeaves, 1.8)
		end,
		Jungle = function(x, y, z, t)
			local h = t:NextInteger(8, 12)
			trunk(x, y, z, h, ID.JungleLog)
			leafBlob(x, y + h, z, 3, ID.JungleLeaves, 1.7)
			leafBlob(x, y + h - 4, z, 2, ID.JungleLeaves, 2)
		end,
		Azalea = function(x, y, z, t)
			local h = t:NextInteger(2, 3)
			trunk(x, y, z, h, ID.OakLog)
			for dx = -2, 2 do
				for dy = 0, 2 do
					for dz = -2, 2 do
						if math.abs(dx) + math.abs(dz) + dy <= 4 then
							setIfAir(x + dx, y + h + dy, z + dz, if hash(x + dx, y + dy, z + dz, 5) < 0.3 then ID.FloweringAzalea else ID.AzaleaLeaves)
						end
					end
				end
			end
		end,
		Cactus = function(x, y, z, t)
			trunk(x, y, z, t:NextInteger(2, 4), ID.Cactus)
		end,
		HugeRedMushroom = function(x, y, z, t)
			local h = t:NextInteger(4, 6)
			trunk(x, y, z, h, ID.MushroomStem)
			for dx = -2, 2 do
				for dz = -2, 2 do
					for dy = 0, 2 do
						local edge = math.max(math.abs(dx), math.abs(dz))
						if (dy == 2 and edge <= 1) or (dy < 2 and edge == 2 and not (math.abs(dx) == 2 and math.abs(dz) == 2)) then
							setIfAir(x + dx, y + h + dy - 1, z + dz, ID.RedMushroom)
						end
					end
				end
			end
		end,
		HugeBrownMushroom = function(x, y, z, t)
			local h = t:NextInteger(4, 6)
			trunk(x, y, z, h, ID.MushroomStem)
			for dx = -3, 3 do
				for dz = -3, 3 do
					if not (math.abs(dx) == 3 and math.abs(dz) == 3) then
						setIfAir(x + dx, y + h + 1, z + dz, ID.BrownMushroom)
					end
				end
			end
		end,
	}

	-- 나무: 절대 좌표 격자(흔들림은 해시)라 땅을 넓혀도 원래 나무는 그 자리에 있다
	local weightTotal = 0
	for _, entry in concept.Trees do
		weightTotal += entry[2]
	end
	local gap = concept.TreeGap
	for gx = bx0 // gap, bx1 // gap do
		for gz = bz0 // gap, bz1 // gap do
			local x = gx * gap + math.floor(r(gx, 0, gz, 1) * gap)
			local z = gz * gap + math.floor(r(gx, 0, gz, 2) * gap)
			local top = freeGround(x, z, true)
			if top then
				local roll = r(gx, 0, gz, 3) * weightTotal
				for _, entry in concept.Trees do
					roll -= entry[2]
					if roll <= 0 then
						TREES[entry[1]](x, top, z, Random.new(math.floor(r(gx, 0, gz, 4) * 2147483646)))
						break
					end
				end
			end
		end
	end

	-- 얼음 가시, 쓰러진 통나무(1.21.5), 바위: 숲 청크마다 개수/5 확률로 하나씩(자리는 청크 안 해시)
	local function perWildChunk(count, salt, place)
		for _, c in building do
			if c.Zone == "Wild" then
				for k = 1, math.ceil(count / 5) do
					if r(c.X, k, c.Z, salt) < count / 5 then
						local x = c.X * CHUNK + 2 + math.floor(r(c.X, k, c.Z, salt + 1) * 12)
						local z = c.Z * CHUNK + 2 + math.floor(r(c.X, k, c.Z, salt + 2) * 12)
						local top = freeGround(x, z, true)
						if top then
							place(x, top, z, Random.new(math.floor(r(c.X, k, c.Z, salt + 3) * 2147483646)))
						end
					end
				end
			end
		end
	end
	perWildChunk(features.IceSpikes or 0, 100, function(x, top, z, t)
		local h = t:NextInteger(6, 11)
		for i = 1, h do
			local radius = if i < h * 0.4 then 1 else 0
			for dx = -radius, radius do
				for dz = -radius, radius do
					if math.abs(dx) + math.abs(dz) <= radius then
						setIfAir(x + dx, top + i, z + dz, ID.PackedIce)
					end
				end
			end
		end
	end)
	perWildChunk(features.FallenLogs or 0, 110, function(x, top, z, t)
		local alongX = t:NextNumber() < 0.5
		for i = 0, t:NextInteger(3, 5) - 1 do
			local lx, lz = x + (if alongX then i else 0), z + (if alongX then 0 else i)
			if surfaceAt(lx, lz) == top then
				setIfAir(lx, top + 1, lz, ID.BirchLog)
			end
		end
	end)
	perWildChunk(features.Boulders or 0, 120, function(x, top, z, t)
		leafBlob(x, top + 1, z, t:NextInteger(1, 2), ID.MossyStone, 1.3)
	end)

	-- 자수정 정동: 시작 광산 북서쪽 청크 언덕 속 껍질(심층암 → 방해석 → 자수정)과 스폰 쪽으로 뚫린 굴
	if features.Geode and not only and owned[chunkKey(-2, -2)] == "Wild" then
		local gx, gz = -2 * CHUNK + 8, -2 * CHUNK + 8
		local gy = YARD + 4
		local R = 5
		for x = -R, R do
			for y = -R, R do
				for z = -R, R do
					local d = math.sqrt(x * x + y * y + z * z)
					local id = if d > R then nil elseif d > R - 1 then ID.Deepslate elseif d > R - 2 then ID.Calcite
						elseif d > R - 3 then ID.Amethyst else AIR
					if id and get(gx + x, gy + y, gz + z) ~= AIR then
						set(gx + x, gy + y, gz + z, id)
					end
				end
			end
		end
		local dir = Vector2.new(SPAWN.X - gx, SPAWN.Z - gz).Unit
		local outside = 0
		for t = R - 3, 40 do
			local open = true
			for h = -1, 1 do
				for w = 0, 1 do
					local x = math.floor(gx + dir.X * t - dir.Y * w + 0.5)
					local z = math.floor(gz + dir.Y * t + dir.X * w + 0.5)
					open = open and get(x, gy + h, z) == AIR
					set(x, gy + h, z, AIR)
				end
			end
			outside = if open then outside + 1 else 0
			if outside >= 2 then
				break -- 언덕 밖으로 나왔다
			end
		end
		for x = -R, R do
			for y = -R, R do
				for z = -R, R do
					if get(gx + x, gy + y, gz + z) == ID.Amethyst and get(gx + x, gy + y + 1, gz + z) == AIR and hash(x, y, z, 3) < 0.5 then
						addDecor("AmethystCluster", gx + x, gy + y + 1, gz + z)
					end
				end
			end
		end
	end

	-- 징검다리(아치 군도): 섬 가장자리에서 첫 작은 섬까지 2×2 발판, 한 번에 1블록 이하로 오르내린다
	if features.Stepping and satellites[1] then -- (산 청크 만들 때는 작은 섬이 없다)
		local target = satellites[1]
		local ty = math.floor((satelliteColumn(target, target.X, target.Z)))
		local dir = Vector2.new(target.X - midX, target.Z - midZ).Unit
		local startDist = 0
		while zoneAt(math.floor(midX + dir.X * (startDist + 1)), math.floor(midZ + dir.Y * (startDist + 1))) do
			startDist += 1
		end
		local endDist = Vector2.new(target.X - midX, target.Z - midZ).Magnitude - target.R * 0.6
		local steps = math.max(1, math.floor((endDist - startDist) / 3))
		for i = 1, steps do
			local t = startDist + (endDist - startDist) * i / (steps + 1)
			local x, z = math.floor(midX + dir.X * t), math.floor(midZ + dir.Y * t)
			local y = math.floor(YARD + (ty - YARD) * i / (steps + 1)) - 1
			for dx = 0, 1 do
				for dz = 0, 1 do
					setIfAir(x + dx, y, z + dz, ID.Grass)
					setIfAir(x + dx, y - 1, z + dz, ID.Dirt)
				end
			end
		end
	end

	-- 폭포: 물길이 섬 밖으로 나가는 첫 빈 칸
	if channel then
		for t = 0, 2 * CHUNK do
			local x, z = channel.LineX + channel.DX * t, channel.LineZ + channel.DZ * t
			if not tops[x * 1000 + z] then
				table.insert(waterfalls, { Position = Vector3.new(x + 0.5, YARD, z + 0.5), Direction = Vector3.new(channel.DX, 0, channel.DZ) })
				break
			end
		end
	end

	-- 7. 땅 장식(Part로 그리는 작은 것): 윗면 블록마다 컨셉 확률 × 구역 배수로 하나
	local COVER_SCALE = { Wild = 1, House = 0.35, Fishing = 0.4, Farm = 0.15, Plaza = 0.15 }
	local cover = {}
	for kind, chance in concept.Cover do
		table.insert(cover, { kind, chance })
	end
	table.sort(cover, function(a, b)
		return a[1] < b[1] -- 순서가 시드마다 같도록
	end)
	for _, c in columns do
		local x, z = c.X, c.Z
		local top = freeGround(x, z, false)
		local scale = if c.Zone then COVER_SCALE[c.Zone] else 0.6
		if top and scale > 0 then
			for k, entry in cover do
				local kind, chance = entry[1], entry[2] * scale
				if kind == "FireflyBush" and nearWater(x, z, 3) then
					chance *= 6 -- 반딧불 덤불은 물가에
				end
				if r(x, k, z, 60) < chance then
					addDecor(kind, x, top + 1, z)
					break
				end
			end
		end
	end

	-- 매달린 것: 잎 아래 덩굴·창백한 이끼, 섬 밑면 빛나는 열매
	local hanging = features.Hanging
	if hanging then
		for _, c in columns do
			local x, z, key = c.X, c.Z, c.Key
			if hanging == "GlowBerries" then
				local bottom = columnBottom[key]
				if bottom and get(x, bottom - 1, z) == AIR and hash(x, bottom, z, 9) < 0.06 then
					addDecor("GlowBerries", x, bottom, z, 2 + math.floor(r(x, bottom, z, 80) * 4))
				end
			else
				local leaf = if hanging == "Vines" then ID.JungleLeaves else ID.PaleOakLeaves
				for y = minY, maxY do
					if get(x, y, z) == leaf and get(x, y - 1, z) == AIR and hash(x, y, z, 13) < 0.25 then
						addDecor(if hanging == "Vines" then "Vines" else "PaleHangingMoss", x, y, z, 1 + math.floor(r(x, y, z, 81) * 3))
					end
				end
			end
		end
	end

	return {
		Seed = seed,
		Concept = conceptId,
		Climate = climate,
		Min = Vector3.new(minX, minY, minZ),
		Size = Vector3.new(nx, ny, nz),
		Data = data,
		Get = get,
		Decor = decor,
		Waterfalls = waterfalls,
		YardY = YARD,
		Spawn = SPAWN,
		Npc = NPC_SPOTS,
		Fields = fieldList,
		Chunks = chunks,
		ZoneAt = zoneAt,
		Loot = loot,
	}
end

-- 산 청크 하나: chunk = { X, Z, Zone, Biome }, extra = 그 청크까지 넣은 산 땅 목록(해안을 어디서 깎을지),
-- filled(x, z) = 그 칸에 이미 땅이 있나(시작 섬·먼저 산 청크). 시드가 같아 노이즈(언덕·동굴)는 옆 땅과 이어진다
function IslandGen.GenerateChunk(seed, extra, chunk, baseConcept, filled)
	return IslandGen.Generate(seed, extra, chunk.Biome or baseConcept, chunk, filled)
end

return IslandGen

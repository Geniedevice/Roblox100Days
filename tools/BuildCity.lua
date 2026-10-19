-- 도시 맵 생성기. Studio 편집 모드에서 실행(execute_luau 또는 Command Bar). 다시 실행하면 City를 새로 만든다.
-- 만드는 것: Workspace.City(도로·인도·건물·가로등·공원), Workspace.LootSpots(파밍 상자 위치, 속성 Container),
-- Workspace.ZombieSpawns(좀비 스폰 위치), SpawnLocation(중앙 안전가옥)
-- 건물: ServerStorage.CityKit.Buildings의 Modern City 템플릿(Roblox 공식 Modular Building Kit, 1층 출입구를 연 것)을
-- 놓고, 안에 1~3층 바닥·계단·실내 벽·조명·파밍 상자를 만든다. 4층 위는 막혀 있다.
-- 공원 나무는 ServerStorage.CityKit.Tree를 쓴다.
local ServerStorage = game:GetService("ServerStorage")

local SEED = 100
local GRID = 2 -- 블록 인덱스 -GRID..GRID (5x5)
local PITCH = 96 -- 블록 중심 간격
local ROAD = 24
local BLOCK = PITCH - ROAD -- 72
local GROUND = 2 -- 지형 윗면
local WALK = GROUND + 0.6 -- 인도 윗면
local STOREY = 15 -- Modular Building Kit 한 층 높이
local FLOORS = 3 -- 들어갈 수 있는 층 수
local INSET = 3.6 -- 외벽 모듈 안쪽(가장 두꺼운 문 모듈 3.5)
local STAIR_W, STAIR_RUN = 5, 1.5 -- 계단 폭, 한 칸 길이(한 칸 높이 1)

local kit = ServerStorage:FindFirstChild("CityKit")
assert(kit and kit:FindFirstChild("Buildings"), "ServerStorage.CityKit.Buildings가 필요합니다")
local templates = {}
for _, t in kit.Buildings:GetChildren() do
	templates[t.Name] = t
end
local trees = kit:FindFirstChild("Tree")

local rng = Random.new(SEED)

for _, name in { "City", "LootSpots", "ZombieSpawns" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local city = folder("City", workspace)
local lootSpots = folder("LootSpots", workspace)
local zombieSpawns = folder("ZombieSpawns", workspace)

local function part(parent, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function marker(parent, name, cframe, attribute)
	local p = part(parent, Vector3.new(2, 0.2, 2), cframe, Color3.new(1, 0, 0), Enum.Material.SmoothPlastic, {
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	p.Name = name
	if attribute then
		p:SetAttribute("Container", attribute)
	end
	return p
end

local function pickLoot()
	local r = rng:NextNumber()
	if r < 0.45 then
		return "Crate"
	elseif r < 0.8 then
		return "Fridge"
	end
	return "Medical"
end

-- 맵 안쪽의 언덕을 걷어 낸다(지면 위만)
local extent = (GRID + 0.5) * PITCH + ROAD / 2
workspace.Terrain:FillBlock(CFrame.new(0, GROUND + 32, 0), Vector3.new(extent * 2 + 40, 60, extent * 2 + 40), Enum.Material.Air)

-- 도로(전체 아스팔트 한 장)
part(city, Vector3.new(extent * 2, 1, extent * 2), CFrame.new(0, GROUND - 0.3, 0), Color3.fromRGB(45, 45, 50), Enum.Material.Asphalt).Name = "Road"

-- 차선(블록 사이 도로 가운데 점선)
local lanes = folder("Lanes", city)
for i = -GRID - 1, GRID do
	local roadCenter = (i + 0.5) * PITCH
	for j = -GRID, GRID do
		local along = j * PITCH
		for _, offset in { -24, -8, 8, 24 } do
			part(lanes, Vector3.new(0.6, 0.05, 8), CFrame.new(roadCenter, GROUND + 0.22, along + offset), Color3.fromRGB(220, 190, 60), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
			part(lanes, Vector3.new(8, 0.05, 0.6), CFrame.new(along + offset, GROUND + 0.22, roadCenter), Color3.fromRGB(220, 190, 60), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
		end
	end
end

local WALL_COLOR = Color3.fromRGB(200, 195, 185)
local FLOOR_COLOR = Color3.fromRGB(110, 95, 80)

-- 건물 로컬 좌표(피벗 = 1층 바닥 중앙)로 파츠를 만든다.
local function localPart(parent, origin, size, offset, color, material)
	return part(parent, size, origin * CFrame.new(offset), color, material)
end

-- x축 범위 [a, b], z축 범위 [c, d]를 덮는 바닥판(윗면 y)
local function slab(parent, origin, a, b, c, d, y)
	if b - a > 0.1 and d - c > 0.1 then
		localPart(parent, origin, Vector3.new(b - a, 1, d - c), Vector3.new((a + b) / 2, y - 0.5, (c + d) / 2), FLOOR_COLOR, Enum.Material.WoodPlanks)
	end
end

-- 한쪽 벽을 따라 놓는 실내 벽. gaps = { {from, to} } 는 비워 둘 구간(벽 방향 좌표)
local function liner(parent, origin, axis, fixed, from, to, y0, height, gaps)
	table.sort(gaps, function(g1, g2) return g1[1] < g2[1] end)
	local segments, cursor = {}, from
	for _, g in gaps do
		if g[1] > cursor then
			table.insert(segments, { cursor, math.min(g[1], to) })
		end
		cursor = math.max(cursor, g[2])
	end
	if cursor < to then
		table.insert(segments, { cursor, to })
	end
	for _, s in segments do
		local length, mid = s[2] - s[1], (s[1] + s[2]) / 2
		if length > 0.2 then
			local size = axis == "z" and Vector3.new(0.6, height, length) or Vector3.new(length, height, 0.6)
			local offset = axis == "z" and Vector3.new(fixed, y0 + height / 2, mid) or Vector3.new(mid, y0 + height / 2, fixed)
			localPart(parent, origin, size, offset, WALL_COLOR, Enum.Material.Plaster)
		end
	end
end

-- Modern City 템플릿 하나를 놓고 내부를 만든다. center = 1층 바닥 중앙(월드), yaw = 0/90/180/270도
local function building(parent, template, center, yaw)
	local model = template:Clone()
	model.Name = "Building"
	local origin = CFrame.new(center) * CFrame.Angles(0, math.rad(yaw), 0)
	model:PivotTo(origin)
	model.Parent = parent

	local hx, hz = template:GetAttribute("ShellX") / 2, template:GetAttribute("ShellZ") / 2
	local x0, x1, z0, z1 = -hx + INSET, hx - INSET, -hz + INSET, hz - INSET
	local interior = folder("Interior", model)

	-- 1층 출입구 위치(로컬): 실내 벽에서 비워 둘 구간
	local gaps = { xMin = {}, xMax = {}, zMin = {}, zMax = {} }
	for _, module in model.Bldg_Bottom:GetChildren() do
		if module:GetAttribute("Doorway") then
			local lp = origin:PointToObjectSpace(module:GetBoundingBox().Position)
			if math.abs(lp.X) / hx > math.abs(lp.Z) / hz then
				table.insert(lp.X < 0 and gaps.xMin or gaps.xMax, { lp.Z - 8.5, lp.Z + 8.5 })
			else
				table.insert(lp.Z < 0 and gaps.zMin or gaps.zMax, { lp.X - 8.5, lp.X + 8.5 })
			end
		end
	end

	-- 계단: k층→k+1층, 짝수층은 -x 벽, 홀수층은 +x 벽을 따라 z 방향으로 오른다
	local stairLength = STOREY * STAIR_RUN
	local sz0 = z0 + 6 -- 모서리 외벽 모듈(8.3x8.3) 충돌 상자가 실내로 약 4.7 들어와 있어서 비켜 시작한다
	local function stairX(k)
		return k % 2 == 0 and { x0, x0 + STAIR_W } or { x1 - STAIR_W, x1 }
	end

	for level = 0, FLOORS - 1 do
		local y = level * STOREY
		-- 바닥(1층은 실내 바닥판, 위층은 아래 계단 자리를 뚫은 바닥)
		if level == 0 then
			slab(interior, origin, x0, x1, z0, z1, 0.2)
		else
			local hole = stairX(level - 1)
			slab(interior, origin, x0, hole[1], z0, z1, y)
			slab(interior, origin, hole[2], x1, z0, z1, y)
			slab(interior, origin, hole[1], hole[2], z0, sz0, y)
			slab(interior, origin, hole[1], hole[2], sz0 + stairLength, z1, y)
		end
		-- 실내 벽(1층만 출입구 자리를 비움)
		local isGround = level == 0
		liner(interior, origin, "z", x0 - 0.3, z0, z1, y, STOREY, isGround and gaps.xMin or {})
		liner(interior, origin, "z", x1 + 0.3, z0, z1, y, STOREY, isGround and gaps.xMax or {})
		liner(interior, origin, "x", z0 - 0.3, x0, x1, y, STOREY, isGround and gaps.zMin or {})
		liner(interior, origin, "x", z1 + 0.3, x0, x1, y, STOREY, isGround and gaps.zMax or {})
		-- 계단(마지막 층 제외)
		if level < FLOORS - 1 then
			local sx = stairX(level)
			for step = 1, STOREY do
				localPart(interior, origin, Vector3.new(STAIR_W, 1, STAIR_RUN),
					Vector3.new((sx[1] + sx[2]) / 2, y + step - 0.5, sz0 + (step - 0.5) * STAIR_RUN),
					Color3.fromRGB(130, 125, 120), Enum.Material.Concrete)
			end
		end
		-- 조명
		local lamp = localPart(interior, origin, Vector3.new(2, 0.3, 2), Vector3.new(0, y + STOREY - 1.2, 0), Color3.fromRGB(255, 230, 180), Enum.Material.Neon)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = math.max(x1 - x0, z1 - z0) * 0.8
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 220, 170)
		light.Parent = lamp
		-- 파밍 상자: 계단 줄을 피한 가운데 영역에 1~2개
		for _ = 1, rng:NextInteger(1, 2) do
			local lx = rng:NextNumber(x0 + STAIR_W + 3, x1 - STAIR_W - 3)
			local lz = rng:NextNumber(z0 + 3, z1 - 3)
			local spotY = (level == 0 and 0.2 or y)
			marker(lootSpots, "Spot", origin * CFrame.new(lx, spotY, lz) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 90), 0), pickLoot())
		end
	end
	-- 4층 위를 막는 천장
	slab(interior, origin, x0, x1, z0, z1, FLOORS * STOREY)
	return model
end

local PARK = Vector2.new(1, -1)
local PAIR = { "A", "B" } -- 좁은 건물 둘을 나란히
local SINGLE = "F" -- 넓은 건물 하나

for bx = -GRID, GRID do
	for bz = -GRID, GRID do
		local cx, cz = bx * PITCH, bz * PITCH
		local blockFolder = folder(("Block_%d_%d"):format(bx, bz), city)
		-- 인도(블록 바닥)
		part(blockFolder, Vector3.new(BLOCK, 1, BLOCK), CFrame.new(cx, WALK - 0.5, cz), Color3.fromRGB(150, 150, 150), Enum.Material.Concrete).Name = "Sidewalk"
		local floor = Vector3.new(cx, WALK, cz)

		if bx == 0 and bz == 0 then
			-- 안전가옥: 낮은 담장(앞쪽 트임) + 스폰 + 상자 1개
			local wallColor, h = Color3.fromRGB(120, 110, 100), 4
			part(blockFolder, Vector3.new(40, h, 1), CFrame.new(cx, WALK + h / 2, cz - 20), wallColor, Enum.Material.Brick)
			for _, sx in { -1, 1 } do
				part(blockFolder, Vector3.new(1, h, 40), CFrame.new(cx + sx * 20, WALK + h / 2, cz), wallColor, Enum.Material.Brick)
				part(blockFolder, Vector3.new(12, h, 1), CFrame.new(cx + sx * 14, WALK + h / 2, cz + 20), wallColor, Enum.Material.Brick)
			end
			marker(lootSpots, "Spot", CFrame.new(cx - 15, WALK + 0.2, cz - 15), "Crate")
			local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
			if spawn then
				spawn.Position = Vector3.new(cx, WALK + spawn.Size.Y / 2, cz)
			end
		elseif bx == PARK.X and bz == PARK.Y then
			-- 공원: 잔디 + 나무 + 상자
			part(blockFolder, Vector3.new(BLOCK - 6, 0.2, BLOCK - 6), CFrame.new(cx, WALK + 0.1, cz), Color3.fromRGB(80, 130, 60), Enum.Material.Grass)
			if trees then
				for _ = 1, 7 do
					local t = trees:Clone()
					t:PivotTo(CFrame.new(cx + rng:NextNumber(-28, 28), WALK + 0.2, cz + rng:NextNumber(-28, 28)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
					t.Parent = blockFolder
				end
			end
			marker(lootSpots, "Spot", CFrame.new(cx, WALK + 0.4, cz), "Crate")
		elseif rng:NextNumber() < 0.5 then
			building(blockFolder, templates[SINGLE], floor, rng:NextInteger(0, 3) * 90)
		else
			-- 좁은 건물 둘(좌우), 앞뒤 방향만 무작위
			for i, sx in { -1, 1 } do
				local template = templates[PAIR[i]]
				local offset = sx * (template:GetAttribute("ShellX") / 2 + 1.5)
				building(blockFolder, template, floor + Vector3.new(offset, 0, 0), rng:NextInteger(0, 1) * 180)
			end
		end
	end
end

-- 교차로: 가로등, 도로 중간: 버려진 차와 좀비 스폰
local lamps = folder("StreetLights", city)
for i = -GRID - 1, GRID do
	for j = -GRID - 1, GRID do
		local x, z = (i + 0.5) * PITCH, (j + 0.5) * PITCH
		local corner = Vector3.new(x + ROAD / 2 - 1, GROUND + 0.2, z + ROAD / 2 - 1)
		part(lamps, Vector3.new(0.6, 14, 0.6), CFrame.new(corner + Vector3.new(0, 7, 0)), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		local bulb = part(lamps, Vector3.new(1.6, 0.6, 1.6), CFrame.new(corner + Vector3.new(0, 14, 0)), Color3.fromRGB(255, 220, 150), Enum.Material.Neon, { CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 210, 150)
		light.Parent = bulb
	end
end

for i = -GRID - 1, GRID do
	for j = -GRID, GRID do
		local roadCenter, along = (i + 0.5) * PITCH, j * PITCH
		for _, horizontal in { false, true } do
			local x = horizontal and along or roadCenter
			local z = horizontal and roadCenter or along
			local position = Vector3.new(x, GROUND + 0.2, z)
			if position.Magnitude > 100 then
				marker(zombieSpawns, "Spawn", CFrame.new(position))
			end
			if rng:NextNumber() < 0.35 then
				local lane = rng:NextInteger(0, 1) * 2 - 1
				local offset = horizontal and Vector3.new(rng:NextNumber(-20, 20), 0, lane * 6) or Vector3.new(lane * 6, 0, rng:NextNumber(-20, 20))
				local yaw = (horizontal and math.rad(90) or 0) + math.rad(rng:NextNumber(-25, 25))
				marker(lootSpots, "Spot", CFrame.new(position + offset) * CFrame.Angles(0, yaw, 0), "Car")
			end
		end
	end
end

local counts = {}
for _, spot in lootSpots:GetChildren() do
	local kind = spot:GetAttribute("Container")
	counts[kind] = (counts[kind] or 0) + 1
end
local summary = {}
for kind, n in counts do
	table.insert(summary, kind .. "=" .. n)
end
local partCount = 0
for _, d in city:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
return ("city parts=%d, loot %s, zombie spawns=%d"):format(partCount, table.concat(summary, " "), #zombieSpawns:GetChildren())

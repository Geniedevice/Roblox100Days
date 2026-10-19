-- 도시 맵 생성기. Studio 편집 모드에서 실행(execute_luau 또는 Command Bar). 다시 실행하면 City를 새로 만든다.
-- 만드는 것: Workspace.City(도로·인도·건물·가로등·공원), Workspace.LootSpots(파밍 상자 위치, 속성 Container),
-- Workspace.ZombieSpawns(좀비 스폰 위치), SpawnLocation(중앙 안전가옥)
-- 건물은 1층만 들어갈 수 있고(문 하나, 안에 상자), 위층은 창문 띠가 있는 외벽이다.
local ServerStorage = game:GetService("ServerStorage")

local SEED = 100
local GRID = 2 -- 블록 인덱스 -GRID..GRID (5x5)
local PITCH = 96 -- 블록 중심 간격
local ROAD = 24
local BLOCK = PITCH - ROAD -- 72
local GROUND = 2 -- 지형 윗면
local WALK = GROUND + 0.6 -- 인도 윗면
local FLOOR_H = 12

local rng = Random.new(SEED)

for _, name in { "City", "LootSpots", "ZombieSpawns" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local base = workspace:FindFirstChild("Base")
if base and base:FindFirstChild("Core") then
	base.Core:Destroy()
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

local function marker(parent, name, position, attribute)
	local p = part(parent, Vector3.new(2, 0.2, 2), CFrame.new(position), Color3.new(1, 0, 0), Enum.Material.SmoothPlastic, {
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

local BUILDING_COLORS = {
	Color3.fromRGB(150, 140, 130), Color3.fromRGB(120, 110, 105), Color3.fromRGB(170, 150, 120),
	Color3.fromRGB(110, 120, 130), Color3.fromRGB(140, 90, 80), Color3.fromRGB(95, 95, 100),
}

-- 건물: 1층 껍데기(문 하나) + 위층 덩어리 + 창문 띠. center는 바닥 중앙(인도 윗면 높이).
local function building(parent, center, width, depth, floors, doorSide)
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent
	local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
	local wall, h = 1, FLOOR_H
	local y = center.Y + h / 2
	local door = 8

	local function wallX(z, isDoor) -- x방향으로 뻗은 벽(앞/뒤)
		if not isDoor then
			part(model, Vector3.new(width, h, wall), CFrame.new(center.X, y, z), color, Enum.Material.Concrete)
			return
		end
		local side = (width - door) / 2
		part(model, Vector3.new(side, h, wall), CFrame.new(center.X - (door + side) / 2, y, z), color, Enum.Material.Concrete)
		part(model, Vector3.new(side, h, wall), CFrame.new(center.X + (door + side) / 2, y, z), color, Enum.Material.Concrete)
		part(model, Vector3.new(door, h - 9, wall), CFrame.new(center.X, center.Y + 9 + (h - 9) / 2, z), color, Enum.Material.Concrete)
	end
	wallX(center.Z - depth / 2 + wall / 2, doorSide == -1)
	wallX(center.Z + depth / 2 - wall / 2, doorSide == 1)
	for _, sx in { -1, 1 } do
		part(model, Vector3.new(wall, h, depth - wall * 2), CFrame.new(center.X + sx * (width / 2 - wall / 2), y, center.Z), color, Enum.Material.Concrete)
	end
	-- 실내 바닥과 천장
	part(model, Vector3.new(width - wall * 2, 0.2, depth - wall * 2), CFrame.new(center.X, center.Y + 0.1, center.Z), Color3.fromRGB(90, 80, 70), Enum.Material.WoodPlanks)
	part(model, Vector3.new(width, 1, depth), CFrame.new(center.X, center.Y + h + 0.5, center.Z), color, Enum.Material.Concrete)

	-- 위층(속이 찬 덩어리) + 층마다 창문 띠
	if floors > 0 then
		local upper = floors * FLOOR_H
		local upperY = center.Y + h + 1 + upper / 2
		part(model, Vector3.new(width, upper, depth), CFrame.new(center.X, upperY, center.Z), color, Enum.Material.Concrete)
		for f = 0, floors - 1 do
			local wy = center.Y + h + 1 + f * FLOOR_H + FLOOR_H / 2
			local glass = { Color = Color3.fromRGB(40, 55, 70), Material = Enum.Material.Glass }
			part(model, Vector3.new(width - 4, 4, 0.2), CFrame.new(center.X, wy, center.Z - depth / 2 - 0.1), glass.Color, glass.Material, { CanCollide = false })
			part(model, Vector3.new(width - 4, 4, 0.2), CFrame.new(center.X, wy, center.Z + depth / 2 + 0.1), glass.Color, glass.Material, { CanCollide = false })
			part(model, Vector3.new(0.2, 4, depth - 4), CFrame.new(center.X - width / 2 - 0.1, wy, center.Z), glass.Color, glass.Material, { CanCollide = false })
			part(model, Vector3.new(0.2, 4, depth - 4), CFrame.new(center.X + width / 2 + 0.1, wy, center.Z), glass.Color, glass.Material, { CanCollide = false })
		end
	end

	-- 실내 조명(밤에 안이 보이게)
	local lamp = part(model, Vector3.new(2, 0.3, 2), CFrame.new(center.X, center.Y + h - 0.2, center.Z), Color3.fromRGB(255, 230, 180), Enum.Material.Neon, { CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = math.max(width, depth) * 0.7
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Parent = lamp

	-- 상자: 벽 쪽에 1~3개
	local count = rng:NextInteger(1, 3)
	for i = 1, count do
		local sx = (i % 2 == 0) and 1 or -1
		local px = center.X + sx * (width / 2 - 3.5)
		local pz = center.Z + rng:NextNumber(-depth / 2 + 4, depth / 2 - 4)
		marker(lootSpots, "Spot", Vector3.new(px, center.Y + 0.2, pz), pickLoot())
	end
end

local trees = ServerStorage:FindFirstChild("ResourceModels") and ServerStorage.ResourceModels:FindFirstChild("Tree")
local PARK = Vector2.new(1, -1)

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
			marker(lootSpots, "Spot", Vector3.new(cx - 15, WALK + 0.2, cz - 15), "Crate")
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
			marker(lootSpots, "Spot", Vector3.new(cx, WALK + 0.4, cz), "Crate")
		elseif rng:NextNumber() < 0.5 then
			-- 큰 건물 하나
			local w, d = rng:NextInteger(32, 46), rng:NextInteger(32, 46)
			building(blockFolder, floor, w, d, rng:NextInteger(1, 4), rng:NextInteger(0, 1) * 2 - 1)
		else
			-- 작은 건물 둘(좌우), 문은 앞이나 뒤
			for _, sx in { -1, 1 } do
				local w, d = rng:NextInteger(22, 28), rng:NextInteger(26, 44)
				building(blockFolder, floor + Vector3.new(sx * 18, 0, 0), w, d, rng:NextInteger(0, 3), rng:NextInteger(0, 1) * 2 - 1)
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
				marker(zombieSpawns, "Spawn", position)
			end
			if rng:NextNumber() < 0.35 then
				local lane = rng:NextInteger(0, 1) * 2 - 1
				local offset = horizontal and Vector3.new(rng:NextNumber(-20, 20), 0, lane * 6) or Vector3.new(lane * 6, 0, rng:NextNumber(-20, 20))
				local spot = marker(lootSpots, "Spot", position + offset, "Car")
				local yaw = (horizontal and math.rad(90) or 0) + math.rad(rng:NextNumber(-25, 25))
				spot.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, yaw, 0)
			end
		end
	end
end

-- 자연 자원 모델은 이제 쓰지 않는다(나무는 공원에 복사해 둠)
local resourceModels = ServerStorage:FindFirstChild("ResourceModels")
if resourceModels then
	resourceModels:Destroy()
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

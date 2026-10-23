-- IslandGen 결과(블록 버퍼)를 Part로 짓는다. 보이는 블록(옆에 공기나 비치는 블록이 있는 것)만 만든다.
--  - 윗면 근처(기둥 윗면에서 1블록 안, 위가 빈 블록)·나무·비치는 블록: 블록마다 Part, 밝기를 좌표 해시로 흔들어 격자가 보인다
--  - 그보다 깊은 절벽·섬 밑면, 물: 층마다 같은 블록끼리 직사각형으로 합친다(greedy meshing). 안 보이는 속 블록은 아무 쪽에나
--    끼워 넣을 수 있어 층 하나가 몇 개의 큰 Part가 된다. 64×64 섬 기준 Part 수가 절반 아래로 준다
--  - 캘 수 있는 광석 블록 Part에는 Ore·Key 속성(MineService가 찾는다)
-- 물·장식은 따로 폴더에, 폭포는 떨어지는 물 Part로.
-- ponytail: 서버가 Part를 만들어 복제한다(섬당 수천 개). 서버 인원이 늘면 시드만 보내고 클라이언트가 같은 IslandGen으로
-- 짓는 방식으로 바꾼다(충돌은 캐릭터를 가진 클라이언트가 계산하므로 가능).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blocks = require(ReplicatedStorage.Shared.Blocks)
local Concepts = require(ReplicatedStorage.Shared.IslandConcepts)
local IslandGen = require(script.Parent.IslandGen)

local B = IslandGen.CELL
local NEIGHBORS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
local DETAIL_DEPTH = 1 -- 기둥 윗면에서 이 깊이까지는 블록마다 Part(2블록 계단 옆면까지)
local HIDDEN = -1 -- 합치기 격자: 안 보이는 불투명 블록(어느 직사각형에나 들어갈 수 있다)
local TOP_WATER = 256 -- 합치기 격자: 위가 빈 물(높이 0.85)은 Id + 256
local M = Enum.Material

local IslandBuilder = {}

local function shade(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + amount), 0, 1))
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- 장식 조각: 충돌·쿼리·그림자 없음(누르기는 아래 블록이 받는다)
local function piece(parent, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Parent = parent
	return p
end

-- 마인크래프트 풀처럼 엇갈린 두 판
local function cross(parent, base, height, width, color, material)
	for _, yaw in { 45, 135 } do
		piece(parent, Vector3.new(width, height, 0.05), base * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, height / 2, 0), color, material or M.Grass)
	end
end

local function flats(parent, base, count, color, size, seed)
	for i = 1, count do
		local ox = (IslandGen.Hash(seed, i, 1, 21) - 0.5) * B * 0.7
		local oz = (IslandGen.Hash(seed, i, 2, 21) - 0.5) * B * 0.7
		piece(parent, Vector3.new(0.06, size, size), base * CFrame.new(ox, 0.04, oz) * CFrame.Angles(0, 0, math.rad(90)), color,
			M.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

local function light(parent, color, range)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, 0.8, false
	l.Parent = parent
end

local FLOWER_COLORS = { Color3.fromRGB(220, 50, 45), Color3.fromRGB(250, 215, 50), Color3.fromRGB(90, 130, 230),
	Color3.fromRGB(190, 120, 220), Color3.fromRGB(245, 245, 240) }

local WOOD = Color3.fromRGB(150, 110, 70)

-- 판자 앞면(-Z, lookVector 쪽)에 글자
local function signText(board, text, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 248, 230)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(70, 45, 25)
	label.TextScaled = true
	label.Text = text
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = textSize
	limit.Parent = label
	label.Parent = gui
	gui.Parent = board
end

-- 장식 종류 → 만들기(base = 블록 윗면 가운데, 매달린 것은 블록 밑면 가운데). item = IslandGen Decor 항목(Text 등)
local DECOR = {
	-- 구역 구조물 장식: 등불·구역 팻말·안내도·허수아비
	Lantern = function(f, base)
		piece(f, Vector3.new(0.35, B * 1.1, 0.35), base * CFrame.new(0, B * 0.55, 0), Color3.fromRGB(70, 55, 40), M.Wood)
		local lamp = piece(f, Vector3.one * 0.9, base * CFrame.new(0, B * 1.1 + 0.45, 0), Color3.fromRGB(255, 205, 110), M.Neon)
		piece(f, Vector3.new(1.1, 0.2, 1.1), base * CFrame.new(0, B * 1.1 + 1, 0), Color3.fromRGB(50, 45, 40), M.Metal)
		light(lamp, Color3.fromRGB(255, 200, 130), 14)
	end,
	Sign = function(f, base, _, _, _, item)
		piece(f, Vector3.new(0.35, B * 1.2, 0.35), base * CFrame.new(0, B * 0.6, 0), WOOD, M.Wood)
		local board = piece(f, Vector3.new(B * 1.3, B * 0.55, 0.25), base * CFrame.new(0, B * 1.05, -0.2), Color3.fromRGB(175, 130, 80), M.WoodPlanks)
		signText(board, item.Text or "", 60)
	end,
	Board = function(f, base, _, _, _, item)
		for _, ox in { -B * 0.8, B * 0.8 } do
			piece(f, Vector3.new(0.4, B * 1.6, 0.4), base * CFrame.new(ox, B * 0.8, 0), WOOD, M.Wood)
		end
		local board = piece(f, Vector3.new(B * 2, B * 1.1, 0.3), base * CFrame.new(0, B * 1.15, -0.25), Color3.fromRGB(185, 140, 90), M.WoodPlanks)
		signText(board, (item.Text or "") .. "\n농장 · 낚시터 · 집터 · 광산\n안내인 루미에게 물어보세요", 48)
	end,
	Scarecrow = function(f, base)
		piece(f, Vector3.new(0.35, B * 1.4, 0.35), base * CFrame.new(0, B * 0.7, 0), WOOD, M.Wood)
		piece(f, Vector3.new(B * 1.1, 0.3, 0.3), base * CFrame.new(0, B * 1.05, 0), WOOD, M.Wood)
		piece(f, Vector3.new(B * 0.6, B * 0.5, B * 0.35), base * CFrame.new(0, B * 0.95, 0), Color3.fromRGB(120, 150, 200), M.Fabric)
		piece(f, Vector3.one * B * 0.45, base * CFrame.new(0, B * 1.45, 0), Color3.fromRGB(225, 190, 110), M.Fabric, Enum.PartType.Ball)
		piece(f, Vector3.new(B * 0.75, 0.2, B * 0.75), base * CFrame.new(0, B * 1.62, 0), Color3.fromRGB(185, 150, 70), M.Fabric)
		piece(f, Vector3.new(B * 0.35, B * 0.25, B * 0.35), base * CFrame.new(0, B * 1.75, 0), Color3.fromRGB(185, 150, 70), M.Fabric)
	end,
	ShortGrass = function(f, base, tint)
		cross(f, base, B * 0.55, B * 0.7, tint.Grass)
	end,
	Fern = function(f, base, tint)
		cross(f, base, B * 0.75, B * 0.8, shade(tint.Foliage, -0.15))
	end,
	DryGrass = function(f, base)
		cross(f, base, B * 0.5, B * 0.7, Color3.fromRGB(200, 175, 110))
	end,
	DeadBush = function(f, base)
		cross(f, base, B * 0.6, B * 0.6, Color3.fromRGB(120, 85, 50), M.Wood)
	end,
	Flowers = function(f, base, _, seed)
		piece(f, Vector3.new(0.1, B * 0.45, 0.1), base * CFrame.new(0, B * 0.22, 0), Color3.fromRGB(70, 130, 50))
		piece(f, Vector3.one * B * 0.3, base * CFrame.new(0, B * 0.5, 0), FLOWER_COLORS[seed % #FLOWER_COLORS + 1], M.SmoothPlastic, Enum.PartType.Ball)
	end,
	Wildflowers = function(f, base, _, seed) -- 1.21.5 들꽃: 땅에 깔린 작은 꽃송이
		flats(f, base, 4, if seed % 2 == 0 then Color3.fromRGB(250, 225, 80) else Color3.fromRGB(245, 245, 235), B * 0.22, seed)
	end,
	PinkPetals = function(f, base, _, seed) -- 1.20 분홍 꽃잎
		flats(f, base, 5, Color3.fromRGB(250, 175, 205), B * 0.3, seed)
	end,
	LeafLitter = function(f, base, _, seed) -- 1.21.5 낙엽 더미
		flats(f, base, 4, if seed % 2 == 0 then Color3.fromRGB(190, 120, 55) else Color3.fromRGB(150, 95, 50), B * 0.3, seed)
	end,
	SmallMushroom = function(f, base)
		piece(f, Vector3.new(0.15, B * 0.25, 0.15), base * CFrame.new(0, B * 0.12, 0), Color3.fromRGB(220, 215, 200))
		piece(f, Vector3.new(B * 0.12, B * 0.35, B * 0.35), base * CFrame.new(0, B * 0.27, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(200, 45, 40), M.SmoothPlastic, Enum.PartType.Cylinder)
	end,
	FireflyBush = function(f, base, tint) -- 1.21.5 반딧불 덤불: 저녁에 빛 알갱이
		local bush = piece(f, Vector3.one * B * 0.7, base * CFrame.new(0, B * 0.3, 0), shade(tint.Foliage, -0.25), M.LeafyGrass, Enum.PartType.Ball)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120))
		e.LightEmission, e.Rate = 1, 1.5
		e.Size = NumberSequence.new(0.18, 0)
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(0.3, 0.8)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = bush
	end,
	Eyeblossom = function(f, base, _, seed) -- 1.21.4 창백한 정원의 눈꽃
		piece(f, Vector3.new(0.1, B * 0.4, 0.1), base * CFrame.new(0, B * 0.2, 0), Color3.fromRGB(110, 110, 100))
		local head = piece(f, Vector3.one * B * 0.25, base * CFrame.new(0, B * 0.45, 0), Color3.fromRGB(255, 150, 60), M.Neon, Enum.PartType.Ball)
		if seed % 2 == 0 then
			light(head, Color3.fromRGB(255, 160, 80), 6)
		end
	end,
	AmethystCluster = function(f, base, _, seed)
		local spike
		for i = 1, 3 do
			local tilt = CFrame.Angles(math.rad((i - 2) * 20), math.rad(i * 120), 0)
			spike = piece(f, Vector3.new(0.25, B * 0.5, 0.25), base * tilt * CFrame.new(0, B * 0.22, 0), Color3.fromRGB(190, 140, 255), M.Glass)
		end
		if seed % 2 == 0 then
			light(spike, Color3.fromRGB(190, 130, 255), 6)
		end
	end,
	Vines = function(f, base, tint, _, length)
		piece(f, Vector3.new(B * 0.9, B * length, 0.05), base * CFrame.new(0, -B * length / 2, B * 0.45), tint.Foliage, M.LeafyGrass)
	end,
	PaleHangingMoss = function(f, base, _, _, length)
		for _, ox in { -0.2, 0.25 } do
			piece(f, Vector3.new(0.12, B * length, 0.12), base * CFrame.new(B * ox, -B * length / 2, 0), Color3.fromRGB(150, 155, 140), M.Fabric)
		end
	end,
	GlowBerries = function(f, base, _, seed, length) -- 무성한 동굴의 빛나는 열매 덩굴(섬 밑에 늘어진다)
		piece(f, Vector3.new(0.1, B * length, 0.1), base * CFrame.new(0, -B * length / 2, 0), Color3.fromRGB(80, 120, 50), M.Grass)
		for i = 1, length do
			local berry = piece(f, Vector3.one * 0.45, base * CFrame.new(0.2, -B * (i - 0.3), 0), Color3.fromRGB(255, 170, 60), M.Neon, Enum.PartType.Ball)
			if i == length and seed % 2 == 0 then
				light(berry, Color3.fromRGB(255, 180, 90), 7)
			end
		end
	end,
}

local function waterfall(parent, origin, fall, bottomY)
	local top = origin + fall.Position * B
	local length = top.Y - bottomY
	local cframe = CFrame.lookAt(top, top + fall.Direction) * CFrame.new(0, -length / 2, 0)
	local sheet = piece(parent, Vector3.new(B * 0.9, length, B * 0.35), cframe, Color3.fromRGB(110, 170, 240), M.Glass)
	sheet.Transparency = 0.35
	local streaks = Instance.new("ParticleEmitter")
	streaks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streaks.Color = ColorSequence.new(Color3.new(1, 1, 1))
	streaks.Size = NumberSequence.new(0.6, 0.2)
	streaks.Transparency = NumberSequence.new(0.3, 1)
	streaks.Lifetime = NumberRange.new(1, 1.5)
	streaks.Speed = NumberRange.new(0, 0)
	streaks.Acceleration = Vector3.new(0, -30, 0)
	streaks.Rate = 25
	streaks.Parent = sheet
	local mist = piece(parent, Vector3.one, CFrame.new(top.X, bottomY, top.Z), Color3.new(1, 1, 1))
	mist.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255))
	e.Size = NumberSequence.new(3, 6)
	e.Transparency = NumberSequence.new(0.6, 1)
	e.Lifetime = NumberRange.new(2, 3)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Rate = 6
	e.Parent = mist
end

-- 반환: Folder "Terrain"(아래에 Blocks 땅·Plants 나무·Water 물·Decor 장식). 아직 workspace에 붙이지 않는다
function IslandBuilder.Build(island, origin)
	local concept = Concepts[island.Concept]
	local tint = concept.Tint
	local data = island.Data
	local terrain = Instance.new("Folder")
	terrain.Name = "Terrain"
	local solids, plants = folder("Blocks", terrain), folder("Plants", terrain)
	local water, decor = folder("Water", terrain), folder("Decor", terrain)
	local min, size = island.Min, island.Size
	local nx, ny, nz = size.X, size.Y, size.Z
	local readu8 = buffer.readu8
	local List = Blocks.List
	local function at(ix, iy, iz)
		if ix < 0 or ix >= nx or iy < 0 or iy >= ny or iz < 0 or iz >= nz then
			return 0
		end
		return readu8(data, (ix * ny + iy) * nz + iz)
	end
	local function colorOf(block, x, y, z)
		local color = if block.Tint then tint[block.Tint] else block.Color
		return shade(color, (IslandGen.Hash(x, y, z, 1) - 0.5) * 2 * block.Jitter)
	end

	-- 기둥 윗면(물 제외 가장 높은 블록)
	local columnTop = {}
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			for iy = ny - 1, 0, -1 do
				local id = readu8(data, (ix * ny + iy) * nz + iz)
				if id ~= 0 and not List[id].Liquid then
					columnTop[ix * nz + iz] = iy
					break
				end
			end
		end
	end

	local count = 0
	local layers = {} -- [iy] = { [ix * nz + iz] = 합치기 종류 }
	for ix = 0, nx - 1 do
		for iy = 0, ny - 1 do
			for iz = 0, nz - 1 do
				local id = readu8(data, (ix * ny + iy) * nz + iz)
				if id ~= 0 then
					local block = List[id]
					local visible = false
					for _, d in NEIGHBORS do
						local n = at(ix + d[1], iy + d[2], iz + d[3])
						if n == 0 or (n ~= id and List[n].See) then
							visible = true
							break
						end
					end
					local x, y, z = min.X + ix, min.Y + iy, min.Z + iz
					if not visible then
						if not block.Plant and not block.See then
							layers[iy] = layers[iy] or {}
							layers[iy][ix * nz + iz] = HIDDEN
						end
					elseif block.Liquid then
						layers[iy] = layers[iy] or {}
						layers[iy][ix * nz + iz] = if at(ix, iy + 1, iz) == 0 then id + TOP_WATER else id
					elseif block.Plant or block.See or iy >= (columnTop[ix * nz + iz] or 0) - DETAIL_DEPTH or at(ix, iy + 1, iz) == 0 then
						local part = Instance.new("Part")
						part.Anchored = true
						part.Size = Vector3.one * B
						part.CFrame = CFrame.new(origin + Vector3.new((x + 0.5) * B, (y + 0.5) * B, (z + 0.5) * B))
						part.Material = block.Material
						part.Color = colorOf(block, x, y, z)
						if block.Transparency then
							part.Transparency, part.CastShadow = block.Transparency, false
						end
						if block.Ore then
							part:SetAttribute("Ore", block.Ore)
							part:SetAttribute("Key", x .. "," .. y .. "," .. z)
						end
						part.Parent = if block.Plant then plants else solids
						count += 1
					else
						layers[iy] = layers[iy] or {}
						layers[iy][ix * nz + iz] = id
					end
				end
			end
		end
	end

	-- 층마다 같은 종류끼리 직사각형으로 합친다(속 블록 HIDDEN은 불투명 종류 어디에나 끼운다, 물은 물끼리만)
	for iy, grid in layers do
		local done = {}
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				local i = ix * nz + iz
				local kind = grid[i]
				if kind and kind > 0 and not done[i] then
					local liquid = kind > TOP_WATER or List[kind].Liquid
					local function fits(jx, jz)
						local j = jx * nz + jz
						local v = grid[j]
						return v ~= nil and ((v == kind and not done[j]) or (v == HIDDEN and not liquid))
					end
					local depth = 1
					while iz + depth < nz and fits(ix, iz + depth) do
						depth += 1
					end
					local width = 1
					while ix + width < nx do
						local ok = true
						for k = 0, depth - 1 do
							if not fits(ix + width, iz + k) then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
						width += 1
					end
					for jx = ix, ix + width - 1 do
						for jz = iz, iz + depth - 1 do
							if grid[jx * nz + jz] == kind then
								done[jx * nz + jz] = true
							end
						end
					end
					local id = if kind > TOP_WATER then kind - TOP_WATER else kind
					local block = List[id]
					local x, y, z = min.X + ix, min.Y + iy, min.Z + iz
					local height = if kind > TOP_WATER then B * 0.85 else B -- 물 윗면은 조금 낮다
					local part = Instance.new("Part")
					part.Anchored = true
					part.Size = Vector3.new(width * B, height, depth * B)
					part.CFrame = CFrame.new(origin + Vector3.new((x + width / 2) * B, y * B + height / 2, (z + depth / 2) * B))
					part.Material = block.Material
					part.Color = colorOf(block, x, y, z)
					if block.Liquid then
						part.Transparency, part.CanCollide, part.CanTouch, part.CastShadow = 0.35, false, false, false
						part.Parent = water
					else
						part.Parent = solids
					end
					count += 1
				end
			end
		end
	end

	for i, item in island.Decor do
		local base = CFrame.new(origin + item.Position * B) * CFrame.Angles(0, math.rad(item.Rotation), 0)
		DECOR[item.Kind](decor, base, tint, i, item.Length, item)
	end
	local bottomY = origin.Y + (min.Y - 6) * B
	for _, fall in island.Waterfalls do
		waterfall(decor, origin, fall, bottomY)
	end
	terrain:SetAttribute("BlockParts", count)
	return terrain
end

return IslandBuilder

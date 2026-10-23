-- 블록 종류(마인크래프트식 복셀). Id 1..N은 1바이트로 섬 버퍼에 저장한다(0 = 공기).
-- Color = 기본 색, Material = Part 재질, Jitter = 블록마다 밝기 흔들기(격자가 보이게), Tint = 섬 컨셉 색으로 칠할 종류
-- (Grass·Foliage: 마인크래프트 바이옴 색표처럼 컨셉마다 풀·잎 색이 다르다), See = 뒤가 비치는 블록(물·잎: 옆 블록을 가리지 않는다)
-- Liquid = 물(충돌 없음), Plant = 나무·버섯·선인장(땅이 아니다: 땅을 찾는 레이캐스트가 거른다)
-- Ore = 캘 수 있는 광석(Shared/Ores의 Id), Transparency = 비치는 정도(유리)
local M = Enum.Material

local LIST = {
	{ "Grass", Color3.fromRGB(110, 170, 80), M.Grass, 0.06, Tint = "Grass" },
	{ "Dirt", Color3.fromRGB(134, 96, 67), M.Ground, 0.06 },
	{ "CoarseDirt", Color3.fromRGB(120, 85, 60), M.Ground, 0.08 },
	{ "Podzol", Color3.fromRGB(95, 65, 35), M.Ground, 0.06 },
	{ "Stone", Color3.fromRGB(125, 125, 125), M.Slate, 0.05 },
	{ "Deepslate", Color3.fromRGB(77, 77, 82), M.Basalt, 0.05 },
	{ "Calcite", Color3.fromRGB(225, 225, 220), M.Limestone, 0.03 },
	{ "Gravel", Color3.fromRGB(135, 128, 125), M.Pebble, 0.06 },
	{ "Sand", Color3.fromRGB(220, 207, 160), M.Sand, 0.04 },
	{ "Sandstone", Color3.fromRGB(215, 200, 150), M.Sandstone, 0.03 },
	{ "RedSand", Color3.fromRGB(190, 105, 45), M.Sand, 0.04 },
	{ "Terracotta", Color3.fromRGB(152, 94, 68), M.Concrete, 0.02 },
	{ "TerracottaOrange", Color3.fromRGB(162, 84, 38), M.Concrete, 0.02 },
	{ "TerracottaYellow", Color3.fromRGB(186, 133, 35), M.Concrete, 0.02 },
	{ "TerracottaWhite", Color3.fromRGB(210, 178, 161), M.Concrete, 0.02 },
	{ "TerracottaBrown", Color3.fromRGB(77, 51, 36), M.Concrete, 0.02 },
	{ "TerracottaRed", Color3.fromRGB(143, 61, 47), M.Concrete, 0.02 },
	{ "TerracottaLight", Color3.fromRGB(135, 107, 98), M.Concrete, 0.02 },
	{ "Snow", Color3.fromRGB(245, 250, 255), M.Snow, 0.02 },
	{ "PackedIce", Color3.fromRGB(160, 190, 240), M.Glacier, 0.03 },
	{ "Ice", Color3.fromRGB(145, 185, 250), M.Ice, 0.02, See = true },
	{ "Mycelium", Color3.fromRGB(111, 99, 107), M.Grass, 0.06 },
	{ "Moss", Color3.fromRGB(90, 110, 45), M.LeafyGrass, 0.06 },
	{ "PaleMoss", Color3.fromRGB(105, 115, 95), M.LeafyGrass, 0.05 },
	{ "Mud", Color3.fromRGB(60, 55, 60), M.Mud, 0.04 },
	{ "Water", Color3.fromRGB(60, 120, 220), M.Glass, 0, See = true, Liquid = true },
	{ "CoalOre", Color3.fromRGB(70, 70, 70), M.Slate, 0.08, Ore = "Coal" },
	{ "IronOre", Color3.fromRGB(175, 140, 120), M.Slate, 0.06, Ore = "Iron" },
	{ "CopperOre", Color3.fromRGB(150, 110, 80), M.Slate, 0.06, Ore = "Copper" },
	{ "Amethyst", Color3.fromRGB(150, 100, 210), M.Glass, 0.05, Ore = "Amethyst" },
	{ "OakLog", Color3.fromRGB(110, 85, 50), M.Wood, 0.04, Plant = true },
	{ "BirchLog", Color3.fromRGB(215, 210, 200), M.Wood, 0.03, Plant = true },
	{ "SpruceLog", Color3.fromRGB(60, 42, 25), M.Wood, 0.04, Plant = true },
	{ "CherryLog", Color3.fromRGB(55, 30, 35), M.Wood, 0.04, Plant = true },
	{ "PaleOakLog", Color3.fromRGB(110, 100, 95), M.Wood, 0.04, Plant = true },
	{ "JungleLog", Color3.fromRGB(95, 75, 40), M.Wood, 0.04, Plant = true },
	{ "MushroomStem", Color3.fromRGB(205, 200, 185), M.SmoothPlastic, 0.02, Plant = true },
	{ "OakLeaves", Color3.fromRGB(70, 140, 50), M.LeafyGrass, 0.08, Tint = "Foliage", See = true, Plant = true },
	{ "BirchLeaves", Color3.fromRGB(120, 160, 80), M.LeafyGrass, 0.07, See = true, Plant = true },
	{ "SpruceLeaves", Color3.fromRGB(60, 95, 60), M.LeafyGrass, 0.06, See = true, Plant = true },
	{ "CherryLeaves", Color3.fromRGB(240, 170, 205), M.LeafyGrass, 0.06, See = true, Plant = true },
	{ "PaleOakLeaves", Color3.fromRGB(160, 165, 150), M.LeafyGrass, 0.05, See = true, Plant = true },
	{ "JungleLeaves", Color3.fromRGB(50, 150, 40), M.LeafyGrass, 0.08, Tint = "Foliage", See = true, Plant = true },
	{ "AzaleaLeaves", Color3.fromRGB(95, 130, 45), M.LeafyGrass, 0.06, See = true, Plant = true },
	{ "FloweringAzalea", Color3.fromRGB(150, 110, 150), M.LeafyGrass, 0.08, See = true, Plant = true },
	{ "RedMushroom", Color3.fromRGB(200, 45, 40), M.SmoothPlastic, 0.04, Plant = true },
	{ "BrownMushroom", Color3.fromRGB(150, 110, 80), M.SmoothPlastic, 0.04, Plant = true },
	{ "Cactus", Color3.fromRGB(80, 130, 50), M.LeafyGrass, 0.04, Plant = true },
	{ "MossyStone", Color3.fromRGB(110, 125, 100), M.Cobblestone, 0.06 },
	-- 광산 광석과 구역 구조물(광장 노점·오두막·부두·길)
	{ "GoldOre", Color3.fromRGB(215, 180, 70), M.Slate, 0.06, Ore = "Gold" },
	{ "DiamondOre", Color3.fromRGB(110, 215, 210), M.Slate, 0.05, Ore = "Diamond" },
	{ "OakPlanks", Color3.fromRGB(165, 130, 80), M.WoodPlanks, 0.05 },
	{ "SprucePlanks", Color3.fromRGB(105, 75, 45), M.WoodPlanks, 0.05 },
	{ "Cobblestone", Color3.fromRGB(120, 120, 118), M.Cobblestone, 0.06 },
	{ "Glass", Color3.fromRGB(200, 230, 245), M.Glass, 0, See = true, Transparency = 0.6 },
	{ "Path", Color3.fromRGB(160, 130, 80), M.Ground, 0.05 },
	{ "HayBale", Color3.fromRGB(215, 175, 60), M.Fabric, 0.05 },
	{ "WoolWhite", Color3.fromRGB(240, 238, 230), M.Fabric, 0.02 },
	{ "WoolRed", Color3.fromRGB(205, 70, 60), M.Fabric, 0.03 },
	{ "WoolGreen", Color3.fromRGB(110, 165, 70), M.Fabric, 0.03 },
	{ "WoolBlue", Color3.fromRGB(80, 130, 210), M.Fabric, 0.03 },
}

local Blocks = { List = {}, Id = {} }
for id, entry in LIST do
	local block = { Id = id, Name = entry[1], Color = entry[2], Material = entry[3], Jitter = entry[4] }
	for key, value in entry do
		if type(key) == "string" then
			block[key] = value
		end
	end
	Blocks.List[id] = block
	Blocks.Id[block.Name] = id
end

return Blocks

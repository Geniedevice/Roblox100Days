-- Play 스모크(서버): Play 중에만 ServerScriptService에 Script로 넣어 돌린다. execute_luau의 require는 게임과 다른 모듈
-- 인스턴스라서, 게임 안 Script로 넣어야 실제 섬·데이터를 만진다. 데이터를 바꾸므로(코인·씨앗·도우미 동물·밭·땅) Studio에서만 돈다.
-- 실행: Play → execute_luau(Server): local s = Instance.new("Script"); s.Name = "PlaySmoke"; s.Source = <이 파일>; s.Parent = game.ServerScriptService
-- 약 95초 뒤 game.ServerScriptService.PlaySmoke:GetAttribute("Result")를 읽는다("PASS n" 또는 "FAIL k/n" + 줄마다 결과).
local Players = game:GetService("Players")
if not game:GetService("RunService"):IsStudio() then
	return
end
local Services = game.ServerScriptService.Services
local DataService = require(Services.DataService)
local FarmService = require(Services.FarmService)
local IslandService = require(Services.IslandService)
local Inventory = require(Services.Inventory)

local lines, failed, total = {}, 0, 0
local function check(ok, what)
	total += 1
	failed += if ok then 0 else 1
	table.insert(lines, (if ok then "ok   " else "FAIL ") .. what)
end
local function finish()
	script:SetAttribute("Result", (if failed == 0 then "PASS " .. total else string.format("FAIL %d/%d", failed, total))
		.. "\n" .. table.concat(lines, "\n"))
end

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local island
for _ = 1, 60 do
	island = IslandService.Get(player)
	if island and player.Character then
		break
	end
	task.wait(0.5)
end
local profile = DataService.Get(player)
check(island ~= nil and profile ~= nil and player.Character ~= nil, "섬·데이터·캐릭터")
if not island then
	return finish()
end
local function tiles() -- 밭을 열면 Farm 폴더가 새로 지어지니 매번 다시 찾는다
	local list = {}
	local farmFolder = island.Model:FindFirstChild("Farm")
	for _, t in farmFolder and farmFolder:GetChildren() or {} do
		if t.Name == "Tile" then
			table.insert(list, t)
		end
	end
	return list
end
local function count(attr)
	local n = 0
	for _, t in tiles() do
		n += if t:GetAttribute(attr) then 1 else 0
	end
	return n
end

-- 1. 기본: 농지 9, NPC 3, 생물이 돌아다닌다(CreatureService.Travel)
local npcs = 0
for _, m in island.Model:GetChildren() do
	npcs += if m:GetAttribute("NpcId") then 1 else 0
end
check(#tiles() == 9 and npcs == 3, string.format("농지 %d · NPC %d", #tiles(), npcs))
local herd = island.Model:FindFirstChild("Creatures")
local before = {}
for _, m in herd and herd:GetChildren() or {} do
	before[m] = m:GetPivot().Position
end
task.wait(9)
local moved = 0
for m, p in before do
	moved += if m.Parent and (m:GetPivot().Position - p).Magnitude > 0.5 then 1 else 0
end
check(moved > 0, string.format("생물 %d마리 중 %d마리가 움직였다", herd and #herd:GetChildren() or 0, moved))

-- 2. 땅 찾기: 스폰 아래는 마당 높이, 하늘에서 찾든 사람 높이에서 찾든 같다
local ground = IslandService.Ground(island, island.Spawn.Position)
local low = IslandService.Ground(island, island.Spawn.Position, island.Spawn.Position.Y)
check(ground and low and math.abs(ground.Y - island.YardY) < 1.5 and math.abs(low.Y - ground.Y) < 0.01,
	string.format("Ground 스폰 아래 %.1f / 마당 %.1f", ground and ground.Y or -1, island.YardY))

-- 3. 농사 한 바퀴(누르기와 같은 길 FarmService.Help): 갈기 → 심기 → 물주기 → (다 자람) → 수확
Inventory.Add(player, "Seed_Turnip", 4)
local from = island.Spawn.Position
local tile, job = FarmService.FindJob(player, { Till = true }, from)
check(tile ~= nil and job == "Till" and FarmService.Help(player, tile, "Till") and tile:GetAttribute("Tilled"), "갈기")
check(FarmService.Help(player, tile, "Plant", "Turnip") and tile:GetAttribute("Crop") == "Turnip", "심기(씨앗 4 → 3)")
check(not FarmService.Help(player, tile, "Plant", "Turnip"), "이미 심은 칸에 다시 심기 거절")
check(FarmService.Help(player, tile, "Water") and tile:GetAttribute("Watered"), "물주기")
local state = profile.Tiles[tostring(tile:GetAttribute("Index"))]
state.PlantedAt -= 1000
local turnips = Inventory.Count(player, "Turnip")
check(FarmService.Help(player, tile, "Harvest") and Inventory.Count(player, "Turnip") == turnips + 1, "수확 → 순무 +1")
check(Inventory.Count(player, "Seed_Turnip") == 3, "씨앗이 하나만 줄었다")

-- 4. 도우미 동물: 셋을 주면 섬에 나오고, 밭을 갈고 심고 물을 준다
Inventory.Add(player, "Seed_Turnip", 20)
for _, id in { "Pet_Frog", "Pet_Rabbit", "Pet_Chicken" } do
	Inventory.Add(player, id, 1)
end
task.wait(1)
local pets = island.Model:FindFirstChild("Pets")
check(pets and #pets:GetChildren() == 3, "도우미 동물 셋이 나왔다")
task.wait(35) -- pets.md: 9칸 약 20초 + 이동, 2026-10-24 Play 30초에 8칸
check(count("Tilled") == 9 and count("Crop") >= 8, string.format("35초 뒤 갈림 %d · 심김 %d / 9", count("Tilled"), count("Crop")))
check(count("Watered") >= 5, string.format("물 준 칸 %d", count("Watered")))

-- 5. 일하는 중에 밭을 늘린다(농지가 새로 지어진다): 동물이 새 농지로 옮겨 간다
Inventory.AddCoins(player, 1000)
check(FarmService.BuyField(player) == nil and #tiles() == 18, "밭 열기 → 농지 18")
task.wait(20)
check(count("Tilled") >= 13, string.format("밭을 연 뒤 20초에 갈림 %d / 18", count("Tilled")))

-- 6. 땅 사기: 섬에 붙은 빈 자리 하나만 짓는다(지형 폴더·기존 Part는 그대로, 새 Part만 는다). 바이옴은 무작위로 저장
local fields = #island.Gen.Fields
local terrain, keep = island.Terrain, island.Blocks:GetChildren()[1]
local before = #terrain:GetDescendants()
local t0 = os.clock()
local _, chunk = IslandService.AddChunk(player, profile, "Farm")
local took = (os.clock() - t0) * 1000
task.wait(1)
local adjacent = false
for _, c in island.Gen.Chunks do
	adjacent = adjacent or (chunk and math.abs(c.X - chunk.X) + math.abs(c.Z - chunk.Z) == 1)
end
check(chunk ~= nil and chunk.Biome ~= nil and adjacent and island.Terrain == terrain and keep.Parent == island.Blocks,
	string.format("땅 사기 %.0fms · 새 Part %d개만 · 바이옴 %s · 옆에 붙음 %s", took, #terrain:GetDescendants() - before,
		tostring(chunk and chunk.Biome), tostring(adjacent)))
check(#island.Gen.Fields == fields + 4 and #pets:GetChildren() == 3 and #tiles() == 18,
	string.format("밭 자리 %d → %d, 동물 %d, 농지 %d", fields, #island.Gen.Fields, #pets:GetChildren(), #tiles()))
local center = chunk and IslandService.YardPoint(island, (chunk.X + 0.5) * 16, (chunk.Z + 0.5) * 16)
check(center ~= nil and IslandService.Ground(island, center) ~= nil, "새 청크 가운데에 땅이 있다")
local _, wild = IslandService.AddChunk(player, profile, "Wild")
check(wild ~= nil and wild.Zone == "Wild" and #profile.Chunks == 2 and profile.Chunks[2].Biome == wild.Biome,
	"숲 땅도 산다(바이옴 " .. tostring(wild and wild.Biome) .. ", 저장 목록에 바이옴)")

-- 7. 광석 바위: 숲 땅 위에 솟아 있고(태그 Ore), 섬 최대 수를 넘지 않는다
local MineService = require(Services.MineService)
local rocks = island.Model:FindFirstChild("Ores")
local onWild = 0
for _, rock in rocks and rocks:GetChildren() or {} do
	onWild += if IslandService.ZoneAt(island, rock.Position) == "Wild" and rock:HasTag("Ore") then 1 else 0
end
local count = rocks and #rocks:GetChildren() or 0
check(count >= 1 and onWild == count and count <= MineService.Max(island),
	string.format("광석 바위 %d개(숲 위 %d, 최대 %d)", count, onWild, MineService.Max(island)))
finish()

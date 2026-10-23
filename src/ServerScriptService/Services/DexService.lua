-- 도감: 처음 만난 작물(수확)·물고기(낚음)·광석(캠)·생물(쓰다듬음)·가구(획득)·섬 컨셉(그 섬에 섬)을 기록한다.
-- 첫 기록 +10코인과 "새 도감!" 알림,
-- 분류를 다 채우면 +100코인(한 번). 칸 목록은 데이터 모듈(Crops·Fish·Ores·Creatures·Furniture·IslandConcepts)에서 만든다.
-- 저장: profile.Dex[분류][Id] = { Count, First }, 완성 보상을 받은 분류는 profile.Dex._Done[분류] = true
-- 명세: design/gdd/collection-dex.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Creatures = require(Shared.Creatures)
local Crops = require(Shared.Crops)
local Fish = require(Shared.Fish)
local Furniture = require(Shared.Furniture)
local IslandConcepts = require(Shared.IslandConcepts)
local Ores = require(Shared.Ores)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.Inventory)

local FIRST_REWARD = 10
local COMPLETE_REWARD = 100

-- 도감 분류(순서대로 탭). Hint = 아직 못 만난 칸에 보이는 글
local CATEGORIES = {
	{ Id = "Crops", Name = "작물", Source = Crops, Color = "Fruit", Hint = "정원사 모모에게 씨앗을 사서 키워 거둬 보세요" },
	{ Id = "Fish", Name = "물고기", Source = Fish, Color = "Color", Hint = "낚시터에서 낚아 보세요. 어떤 물고기는 특정 섬에만 살아요" },
	{ Id = "Ores", Name = "광석", Source = Ores, Color = "Color", Hint = "광산의 광석 블록을 두드려 캐 보세요. 섬마다 잘 나는 광석이 달라요" },
	{ Id = "Creatures", Name = "생물", Source = Creatures, Color = "Color", Hint = "섬을 돌아다니는 생물을 쓰다듬어 보세요. 바이옴마다 사는 생물이 달라요" },
	{ Id = "Furniture", Name = "가구", Source = Furniture.Items, Color = nil, Hint = "목수 버니의 상점에서 만날 수 있어요" },
	{ Id = "Islands", Name = "섬", Source = IslandConcepts, Color = "Color", Hint = "이런 하늘섬에 서 보세요. 친구 섬일 수도 있어요" },
}
local byId = {}
for _, category in CATEGORIES do
	byId[category.Id] = category
end

local DexService = {}

local function complete(records, category)
	for id in category.Source do
		if not records[id] then
			return false
		end
	end
	return true
end

-- 기록한다. 처음이면 보상과 알림, 분류가 다 차면 완성 보상(한 번).
function DexService.Record(player, categoryId, id)
	local profile = DataService.Get(player)
	local category = byId[categoryId]
	local entry = category and category.Source[id]
	if not profile or not entry then
		return
	end
	profile.Dex[categoryId] = profile.Dex[categoryId] or {}
	local records = profile.Dex[categoryId]
	if records[id] then
		records[id].Count += 1
		return
	end
	records[id] = { Count = 1, First = os.time() }
	Inventory.AddCoins(player, FIRST_REWARD)
	Remotes.Feedback:FireClient(player, "DexNew", { Category = categoryId, Item = id,
		Text = string.format("%s · %s  +%d 코인", category.Name, entry.Name, FIRST_REWARD) })

	profile.Dex._Done = profile.Dex._Done or {}
	if not profile.Dex._Done[categoryId] and complete(records, category) then
		profile.Dex._Done[categoryId] = true
		Inventory.AddCoins(player, COMPLETE_REWARD)
		Remotes.Feedback:FireClient(player, "DexNew", { Category = categoryId, Complete = true,
			Text = string.format("%s 도감 완성!  +%d 코인", category.Name, COMPLETE_REWARD) })
	end
	player:SetAttribute("DexVersion", (player:GetAttribute("DexVersion") or 0) + 1) -- 열린 도감 창이 다시 그린다
end

-- 도감 창에 보낼 내용: 자기 기록만. 못 만난 칸은 이름·설명 대신 힌트만 보낸다(미리 알려 주지 않는다)
local function view(player)
	local profile = DataService.Get(player)
	local result = {}
	for _, category in CATEGORIES do
		local records = profile and profile.Dex[category.Id] or {}
		local entries, found = {}, 0
		for id, data in category.Source do
			local record = records[id]
			found += if record then 1 else 0
			table.insert(entries, {
				Id = id, -- 아이콘(못 찾은 칸은 실루엣)용
				Order = data.Order,
				Found = record ~= nil,
				Name = if record then data.Name else "???",
				Desc = if record then data.Desc else category.Hint,
				Color = if record then (category.Color and data[category.Color] or data.Parts[1].Color) else nil,
				Count = record and record.Count or 0,
			})
		end
		table.sort(entries, function(a, b)
			return a.Order < b.Order
		end)
		table.insert(result, { Id = category.Id, Name = category.Name, Found = found, Total = #entries, Entries = entries })
	end
	return result
end

function DexService.Start()
	Remotes.Dex.OnServerInvoke = view
end

return DexService

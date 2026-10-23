-- 섬 시드 → 그 섬의 획득물 표(서버·클라이언트 공용). 같은 시드면 늘 같은 표라 저장하지 않는다.
--  물고기: 기본 Weight × 시드 배수(0.5..1.8), 컨셉 전용(Only)은 그 컨셉 섬에서만, 명물 물고기 1종 ×3
--  광석: 기본 Weight × 컨셉 Bonus × 시드 배수(0.6..1.6), 명물 광석 1종 ×2.5 (광산 광석 배치와 캐는 표가 같다)
--  작물: 명물 작물 1종은 거둘 때 25% 확률로 하나 더
--  생물: 그 바이옴(컨셉)에 사는 종 × 시드 배수(0.5..1.6), 시드 40%로 다른 바이옴·떠돌이 종 하나가 드물게(12%) 들른다
-- 한 번 던지기·캐기의 결과는 매번 무작위지만, 무엇이 얼마나 잘 나오는지는 섬(시드)마다 다르다 → 친구 섬을 찾아갈 이유.
-- 명세: design/gdd/island-zones.md "시드 획득물"
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Crops = require(ReplicatedStorage.Shared.Crops)
local Fish = require(ReplicatedStorage.Shared.Fish)
local Ores = require(ReplicatedStorage.Shared.Ores)

local SPECIAL_FISH, SPECIAL_ORE = 3, 2.5
local Loot = {}
Loot.SPECIAL_CROP_CHANCE = 0.25

local function sortedIds(source)
	local ids = {}
	for id in source do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return source[a].Order < source[b].Order
	end)
	return ids
end
local FISH_IDS, ORE_IDS, CROP_IDS, CREATURE_IDS = sortedIds(Fish), sortedIds(Ores), sortedIds(Crops), sortedIds(Creatures)

-- 반환: { Fish = { { Id, Weight } }, FishTotal, Ores = { { Id, Weight } }, OreTotal, SpecialFish, SpecialOre, SpecialCrop,
--   Creatures = { { Id, Weight } }, CreatureTotal, Visitor(떠돌이 종 Id 또는 nil) }
function Loot.ForIsland(seed, conceptId)
	local rng = Random.new(bit32.bxor(seed, 0x5F3759DF)) -- 섬 모양 rng와 따로(서로 순서를 흔들지 않게)
	local result = { Fish = {}, FishTotal = 0, Ores = {}, OreTotal = 0 }

	local commons = {}
	for _, id in FISH_IDS do
		local fish = Fish[id]
		local scale = rng:NextNumber(0.5, 1.8) -- 순서대로 늘 뽑는다(컨셉과 상관없이 같은 횟수)
		if not fish.Only or fish.Only == conceptId then
			table.insert(result.Fish, { Id = id, Weight = fish.Weight * scale })
			if not fish.Only and fish.Price > 1 and fish.Weight >= 5 then
				table.insert(commons, #result.Fish)
			end
		end
	end
	local special = result.Fish[commons[rng:NextInteger(1, #commons)]]
	special.Weight *= SPECIAL_FISH
	result.SpecialFish = special.Id

	for _, id in ORE_IDS do
		local ore = Ores[id]
		local weight = ore.Weight * (ore.Bonus and ore.Bonus[conceptId] or 1) * rng:NextNumber(0.6, 1.6)
		table.insert(result.Ores, { Id = id, Weight = weight })
	end
	local specialOre = result.Ores[rng:NextInteger(2, #result.Ores - 1)] -- 석탄·다이아몬드는 명물이 되지 않는다
	specialOre.Weight *= SPECIAL_ORE
	result.SpecialOre = specialOre.Id
	result.SpecialCrop = CROP_IDS[rng:NextInteger(1, #CROP_IDS)]

	-- 생물: 이 컨셉에 사는 종 × 시드 배수, 시드 40%로 다른 바이옴·떠돌이 종 하나가 드물게 들른다
	result.Creatures, result.CreatureTotal = {}, 0
	local visitors = {}
	for _, id in CREATURE_IDS do
		local scale = rng:NextNumber(0.5, 1.6)
		if table.find(Creatures[id].Concepts, conceptId) then
			table.insert(result.Creatures, { Id = id, Weight = scale })
			result.CreatureTotal += scale
		else
			table.insert(visitors, id)
		end
	end
	if rng:NextNumber() < 0.4 then
		result.Visitor = visitors[rng:NextInteger(1, #visitors)]
		local weight = result.CreatureTotal * 0.12
		table.insert(result.Creatures, { Id = result.Visitor, Weight = weight })
		result.CreatureTotal += weight
	end

	for _, entry in result.Fish do
		result.FishTotal += entry.Weight
	end
	for _, entry in result.Ores do
		result.OreTotal += entry.Weight
	end
	return result
end

-- 표 { { Id, Weight } }에서 roll(0..1)로 하나
function Loot.Pick(entries, total, roll)
	local left = roll * total
	for _, entry in entries do
		left -= entry.Weight
		if left <= 0 then
			return entry.Id
		end
	end
	return entries[#entries].Id
end

return Loot

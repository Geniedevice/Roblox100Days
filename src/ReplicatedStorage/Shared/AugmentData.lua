-- 증강 정의. Apply는 플레이어 Attribute만 바꾸고, 실제 효과는 각 시스템이 Attribute를 읽어 적용한다.
-- 성장: 같은 증강을 다시 고르면 레벨이 오르고 Description만큼 효과가 한 번 더 쌓인다(MaxStack = 최대 레벨).
local function add(player, attribute, amount)
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + amount)
end

local AugmentData = {
	SharpBlade = {
		Name = "날 선 칼날", Rarity = "Silver", Category = "전투", MaxStack = 3,
		Description = "피해 +10%",
		Apply = function(player) add(player, "DamageBonus", 0.1) end,
	},
	IronStomach = {
		Name = "튼튼한 위장", Rarity = "Silver", Category = "생존", MaxStack = 3,
		Description = "배고픔 감소 속도 -20%",
		Apply = function(player) add(player, "HungerReduction", 0.2) end,
	},
	Hydrated = {
		Name = "수분 보충", Rarity = "Silver", Category = "생존", MaxStack = 3,
		Description = "갈증 감소 속도 -20%",
		Apply = function(player) add(player, "ThirstReduction", 0.2) end,
	},
	Nimble = {
		Name = "날렵한 발", Rarity = "Silver", Category = "유틸", MaxStack = 3,
		Description = "이동 속도 +2",
		Apply = function(player) add(player, "SpeedBonus", 2) end,
	},
	ToughSkin = {
		Name = "강철 피부", Rarity = "Silver", Category = "생존", MaxStack = 3,
		Description = "받는 피해 -10%",
		Apply = function(player) add(player, "DamageReduction", 0.1) end,
	},
	Carpenter = {
		Name = "목수의 손", Rarity = "Gold", Category = "기지", MaxStack = 3,
		Description = "새로 짓는 바리케이드 체력 +30%",
		Apply = function(player) add(player, "BarricadeBonus", 0.3) end,
	},
	Vampire = {
		Name = "흡혈", Rarity = "Gold", Category = "전투", MaxStack = 3,
		Description = "좀비 처치 시 체력 5 회복",
		Apply = function(player) add(player, "LifeOnKill", 5) end,
	},
	Frenzy = {
		Name = "광전사", Rarity = "Gold", Category = "전투", MaxStack = 3,
		Description = "공격 속도 +25%",
		Apply = function(player) add(player, "AttackSpeedBonus", 0.25) end,
	},
	Vitality = {
		Name = "강인한 체력", Rarity = "Gold", Category = "생존", MaxStack = 3,
		Description = "최대 체력 +25",
		Apply = function(player) add(player, "MaxHealthBonus", 25) end,
	},
	ExplosiveCorpse = {
		Name = "폭발 시체", Rarity = "Prism", Category = "전투", MaxStack = 2,
		Description = "처치한 좀비가 폭발해 주변 좀비에게 50 피해",
		Apply = function(player) add(player, "ExplodeDamage", 50) end,
	},
	Undying = {
		Name = "불굴", Rarity = "Prism", Category = "생존", MaxStack = 2,
		Description = "판당 1회 더, 죽을 때 체력 30%로 버팀",
		Apply = function(player) add(player, "UndyingCharges", 1) end,
	},
	Scavenger = {
		Name = "청소부", Rarity = "Prism", Category = "생존", MaxStack = 2,
		Description = "좀비 처치 시 배고픔·갈증 +4",
		Apply = function(player) add(player, "FoodOnKill", 4) end,
	},
}

for id, data in AugmentData do
	data.Id = id
end

return AugmentData

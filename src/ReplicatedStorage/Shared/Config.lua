-- 모든 밸런스 수치. 테스트할 때는 DAY_LENGTH / NIGHT_LENGTH / Company.LobbyTime을 줄이면 빠르다.
-- 게임: 컴퍼니 소속 생존자들이 여러 세상(탐사지)을 돌며 100일을 버틴다. 한 생존 기간(PeriodDays일)마다
-- 세상에서 파밍하며 살아남고, 컴퍼니로 돌아와 고물을 팔아 생존비를 내고, 남은 크레딧으로 장비·증강을 산다.
local Config = {}

Config.TOTAL_DAYS = 100
Config.DAY_LENGTH = 45 -- 초 (시간이 빨리 간다)
Config.NIGHT_LENGTH = 30 -- 초

-- 컴퍼니: 기간 n이 끝나면 생존비 = FirstQuota + QuotaStep x (n - 1)을 내야 한다(못 내면 해고 = 처음부터)
Config.Company = {
	PeriodDays = 5,
	StartCredits = 60,
	ScrapValue = 10, -- 고물 1개 판매가
	FirstQuota = 120,
	QuotaStep = 60,
	LobbyTime = 90, -- 컴퍼니에서 출발까지 최대 대기(초). 누군가 출발 레버를 당기면 바로 출발
	Origin = Vector3.new(0, 0, -2500), -- 컴퍼니 위치(tools/BuildCompany.lua)
	Atmosphere = { Density = 0.25, Color = Color3.fromRGB(200, 210, 220), Haze = 0 },
}

-- 탐사할 세상. Id는 Workspace.Worlds 아래 폴더 이름(tools/BuildCity.lua로 생성), 첫 번째가 기본.
-- TravelCost = 출발할 때 내는 크레딧, ZombieMultiplier = 좀비 수·체력 배율, ScrapMultiplier = 고물 배율
Config.Worlds = {
	{
		Id = "Ruins", Name = "폐허 도시", Origin = Vector3.new(0, 0, 0), Seed = 100,
		TravelCost = 0, ZombieMultiplier = 1, ScrapMultiplier = 1,
		Atmosphere = { Density = 0.3, Color = Color3.fromRGB(199, 199, 199), Haze = 0 },
	},
	{
		Id = "Ashen", Name = "잿빛 구역", Origin = Vector3.new(3000, 0, 0), Seed = 777,
		TravelCost = 40, ZombieMultiplier = 1.5, ScrapMultiplier = 1.8,
		Atmosphere = { Density = 0.55, Color = Color3.fromRGB(150, 120, 110), Haze = 2.5 },
	},
}

-- 컴퍼니 상점. 장비는 산 사람이 받고, 증강은 플레이어마다 AugmentOffers개를 제시한다. 크레딧은 팀 공용.
Config.Shop = {
	Equipment = {
		{ Id = "Crossbow", Name = "석궁", Price = 60, Weapon = "Crossbow" },
		{ Id = "Rifle", Name = "소총", Price = 150, Weapon = "Rifle" },
		{ Id = "Ammo", Name = "탄약 30발", Price = 30, Items = { Ammo = 30 } },
		{ Id = "Medkit", Name = "구급상자 2개", Price = 25, Items = { Medkit = 2 } },
		{ Id = "Supplies", Name = "통조림·생수 3개씩", Price = 20, Items = { Food = 3, Water = 3 } },
		{ Id = "Materials", Name = "목재·고철 10개씩", Price = 35, Items = { Wood = 10, Stone = 10 } },
	},
	AugmentPrice = { Silver = 40, Gold = 90, Prism = 160 },
	AugmentOffers = 4,
	RerollPrice = 15,
}

-- 마릿수 = Base + 일차 x PerDay. 낮에는 도시를 배회하고, 밤에는 무리로 플레이어를 쫓는다.
Config.Wave = {
	DayBase = 4,
	DayPerDay = 0.5,
	BaseCount = 5, -- 밤
	CountPerDay = 1.5, -- 밤
	HealthScalePerDay = 0.03,
	BossEvery = 10,
	MaxAlive = 60,
	SpawnInterval = 0.5,
	MinPlayerDistance = 40, -- 플레이어 바로 옆 스폰 지점은 피한다
	FallbackRadius = 100, -- Workspace.ZombieSpawns가 없을 때 안전가옥 주변 스폰 반경
}

Config.Zombies = {
	Normal = { MinDay = 1, Weight = 10, Health = 100, Speed = 10, Damage = 10, Scale = 1 },
	-- Tint: 같은 모델을 쓸 때 종류를 구분하는 몸 색
	Runner = { MinDay = 10, Weight = 5, Health = 60, Speed = 18, Damage = 6, Scale = 0.9, Tint = Color3.fromRGB(190, 180, 80) },
	Tank = { MinDay = 25, Weight = 2, Health = 400, Speed = 7, Damage = 25, Scale = 1.4, Tint = Color3.fromRGB(80, 85, 95) },
	Boss = { Health = 2000, Speed = 9, Damage = 40, Scale = 2, Tint = Color3.fromRGB(140, 30, 30) },
}

Config.ZombieAI = {
	TickRate = 0.3,
	AggroRange = 60, -- 낮: 이 거리 안의 플레이어만 쫓고, 아니면 배회
	NightAggroRange = 300, -- 밤: 사실상 맵 전체에서 쫓아온다
	WanderRadius = 30,
	RepathTime = 2, -- 건물에 막혔을 때 길찾기를 다시 계산하는 간격(초)
	AttackRange = 5,
	AttackCooldown = 1,
	-- Roblox 공식 애니메이션. R6 = Drooling Zombie(Roblox) 세트, R15(모델이 없을 때의 기본 좀비) = 기본 걷기
	Animations = {
		R6 = { Walk = "rbxassetid://125749145", Arms = "rbxassetid://183294396", Attack = "rbxassetid://180416148" },
		R15 = { Walk = "rbxassetid://507777826" },
	},
}

-- 보스 내려찍기: 쿨다운마다 반경 안 플레이어에게 피해
Config.Boss = { SlamCooldown = 6, SlamRadius = 14, SlamDamage = 30 }

Config.Weapon = { Damage = 25, Range = 7, Cooldown = 0.5, SwingTime = 0.45 } -- 야구방망이(SwingTime = 크게 휘두르는 동작 길이)
Config.Ranged = { Damage = 35, Range = 90, Cooldown = 1.2 } -- 석궁
Config.Gun = { Damage = 30, Range = 150, Cooldown = 0.2, ClipSize = 12, ReloadTime = 2 } -- 소총(탄약 1발씩)
Config.PvP = { Enabled = true, DamageScale = 1 } -- 플레이어끼리 주는 피해 배율

-- 무기 애니메이션·소리(Roblox 공식 Endorsed Weapons Kit). 재생 확인한 것만 쓴다.
Config.WeaponAnimations = {
	RifleHold = "rbxassetid://3972164452", -- 소총을 든 동안 반복
	RifleAim = "rbxassetid://3972157449", -- 우클릭 조준(줌) 동안
	RifleReload = "rbxassetid://3972131105",
}
Config.WeaponSounds = { Hit = "rbxassetid://1489924400" } -- 명중음(사격·재장전음은 소총 모델 안의 Sound)

-- 조준(우클릭/모바일 버튼): 시야각과 마우스 감도
Config.Aim = { FieldOfView = { ["소총"] = 40, ["석궁"] = 50 }, Sensitivity = 0.6 }

-- 증강으로 켜지는 능력의 수치(레벨당)
Config.Abilities = {
	ChainRange = 12, ChainDamage = 20, -- 연쇄 번개: 맞은 좀비 주변으로 Lv+1마리
	ExplosionRadius = 8, ExplosionDamage = 40, -- 폭발탄
	KnockbackSpeed = 35, -- 넉백
	WhirlwindRange = 10, -- 회전 베기 반경
	DroneInterval = 2, DroneRange = 45, DroneDamage = 15, -- 수호 드론
	AuraInterval = 5, AuraRadius = 15, AuraHeal = 5, -- 치유 오라
}

Config.Survival = {
	Max = 100,
	HungerDecay = 0.2, -- 초당
	ThirstDecay = 0.3,
	StarveDamage = 2,
	RespawnMin = 50, -- 부활할 때 배고픔·갈증이 이 값보다 낮으면 여기까지 채운다
}

-- 인벤토리 아이템. Hunger/Thirst/Heal이 있으면 사용할 수 있다.
Config.Items = {
	Wood = { Name = "목재" },
	Stone = { Name = "고철" },
	Food = { Name = "통조림", Hunger = 30 },
	Water = { Name = "생수", Thirst = 35 },
	Medkit = { Name = "구급상자", Heal = 40 },
	Ammo = { Name = "탄약" }, -- 소총 재장전에 쓴다
	Scrap = { Name = "고물" }, -- 컴퍼니로 돌아가면 크레딧으로 팔린다
}

-- 파밍 상자. 각 세상의 LootSpots 파츠(속성 Container = 아래 이름)마다 놓인다.
-- 뒤지면 Drops마다 Min~Max개(0이면 안 나옴)를 얻고, Respawn초 뒤 다시 채워진다. 고물은 세상의 ScrapMultiplier만큼 늘어난다.
-- 출발할 때마다 모든 상자가 다시 채워진다.
Config.Loot = {
	Crate = {
		Label = "나무 상자", HoldTime = 1.5, Respawn = 90,
		Drops = { { Item = "Wood", Min = 2, Max = 4 }, { Item = "Stone", Min = 0, Max = 2 }, { Item = "Ammo", Min = 0, Max = 3 }, { Item = "Scrap", Min = 0, Max = 2 } },
	},
	Fridge = {
		Label = "냉장고", HoldTime = 1, Respawn = 120,
		Drops = { { Item = "Food", Min = 1, Max = 2 }, { Item = "Water", Min = 1, Max = 2 }, { Item = "Scrap", Min = 0, Max = 1 } },
	},
	Medical = {
		Label = "구급함", HoldTime = 1, Respawn = 180,
		Drops = { { Item = "Medkit", Min = 1, Max = 1 }, { Item = "Water", Min = 0, Max = 1 }, { Item = "Scrap", Min = 0, Max = 1 } },
	},
	Car = {
		Label = "버려진 차", HoldTime = 2.5, Respawn = 150,
		Drops = { { Item = "Scrap", Min = 1, Max = 3 }, { Item = "Stone", Min = 2, Max = 4 }, { Item = "Food", Min = 0, Max = 1 }, { Item = "Medkit", Min = 0, Max = 1 }, { Item = "Ammo", Min = 0, Max = 6 } },
	},
}

-- 제작 목록. 이 순서대로 제작 창에 나온다.
-- Place: 플레이어 앞에 설치하는 구조물(Health는 목수의 손 증강만큼 늘어남), Weapon: 무기 지급(플레이어 Attribute "Has<Weapon>").
Config.Crafting = {
	{
		Id = "WoodBarricade", Name = "나무 바리케이드", Cost = { Wood = 6 },
		Place = { Health = 200, Size = Vector3.new(8, 5, 1.2), Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks },
	},
	{
		Id = "StoneWall", Name = "고철 벽", Cost = { Stone = 6, Wood = 2 },
		Place = { Health = 500, Size = Vector3.new(8, 6, 1.6), Color = Color3.fromRGB(110, 110, 118), Material = Enum.Material.CorrodedMetal },
	},
	{ Id = "Crossbow", Name = "석궁", Cost = { Wood = 8, Stone = 4 }, Weapon = "Crossbow" }, -- 한 판에 한 번, 죽어도 유지
	{ Id = "Rifle", Name = "소총", Cost = { Stone = 14, Wood = 4 }, Weapon = "Rifle" }, -- 탄약은 파밍(차·나무 상자)
}

Config.Barricade = { PlaceDistance = 6 } -- 플레이어 앞 몇 스터드에 설치할지

-- 저장. 구조를 바꾸면 StoreName 버전을 올린다.
Config.Data = { StoreName = "ZombieSurvival100_v1" }

-- 증강은 컴퍼니 상점에서 산다. 아래는 제시 확률과, 판 중간에 들어온 플레이어가 놓친 기간만큼 무료로 고르는 수(EveryDays일마다 1개).
Config.Augment = {
	EveryDays = 5,
	PickTime = 30,
	Rerolls = 1,
	Odds = { Silver = 0.6, Gold = 0.3, Prism = 0.1 },
	LateOdds = { Silver = 0.4, Gold = 0.4, Prism = 0.2 }, -- 50일 이후, 보스 날
}

return Config

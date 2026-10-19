-- 모든 밸런스 수치. 테스트할 때는 DAY_LENGTH / NIGHT_LENGTH / Augment.EveryDays를 줄이면 빠르다.
local Config = {}

Config.TOTAL_DAYS = 100
Config.DAY_LENGTH = 240 -- 초
Config.NIGHT_LENGTH = 180 -- 초

Config.Wave = {
	BaseCount = 5,
	CountPerDay = 1.5,
	HealthScalePerDay = 0.03,
	BossEvery = 10,
	MaxAlive = 60,
	SpawnInterval = 0.5,
	FallbackRadius = 100, -- Workspace.ZombieSpawns가 없을 때 코어 주변 스폰 반경
}

Config.Zombies = {
	Normal = { MinDay = 1, Weight = 10, Health = 100, Speed = 10, Damage = 10, Scale = 1 },
	Runner = { MinDay = 10, Weight = 5, Health = 60, Speed = 18, Damage = 6, Scale = 0.9 },
	Tank = { MinDay = 25, Weight = 2, Health = 400, Speed = 7, Damage = 25, Scale = 1.4 },
	Boss = { Health = 2000, Speed = 9, Damage = 40, Scale = 2 },
}

Config.ZombieAI = {
	TickRate = 0.3,
	AggroRange = 120,
	AttackRange = 5,
	AttackCooldown = 1,
	WalkAnimation = "rbxassetid://507777826", -- Roblox 기본 R15 걷기
}

-- 보스 내려찍기: 쿨다운마다 반경 안 플레이어에게 피해
Config.Boss = { SlamCooldown = 6, SlamRadius = 14, SlamDamage = 30 }

Config.Core = { MaxHealth = 1000 }

Config.Weapon = { Damage = 25, Range = 7, Cooldown = 0.5 }
Config.Ranged = { Damage = 35, Range = 90, Cooldown = 1.2 } -- 석궁

Config.Survival = {
	Max = 100,
	HungerDecay = 0.2, -- 초당
	ThirstDecay = 0.3,
	StarveDamage = 2,
	RespawnMin = 50, -- 부활할 때 배고픔·갈증이 이 값보다 낮으면 여기까지 채운다
}

-- 인벤토리 아이템. Hunger/Thirst가 있으면 먹고 마실 수 있다.
Config.Items = {
	Wood = { Name = "나무" },
	Stone = { Name = "돌" },
	Food = { Name = "열매", Hunger = 30 },
	Water = { Name = "물", Thirst = 35 },
}

-- 자원 노드. 코어에서 MinRadius~MaxRadius 사이에 Count개씩 놓이고, 채집하면 Respawn초 뒤 다시 생긴다.
Config.Resources = {
	MinRadius = 25,
	MaxRadius = 140,
	Nodes = {
		Tree = { Label = "나무", Item = "Wood", Amount = 3, HoldTime = 1.5, Respawn = 60, Count = 12 },
		Rock = { Label = "바위", Item = "Stone", Amount = 2, HoldTime = 2, Respawn = 90, Count = 8 },
		Bush = { Label = "열매 덤불", Item = "Food", Amount = 2, HoldTime = 1, Respawn = 45, Count = 10 },
		Pond = { Label = "웅덩이", Item = "Water", Amount = 2, HoldTime = 1, Respawn = 45, Count = 5 },
	},
}

-- 제작 목록. 이 순서대로 제작 창에 나온다.
-- Place: 플레이어 앞에 설치하는 구조물(Health는 목수의 손 증강만큼 늘어남), Repair: 코어 회복, MaxHealth: 코어 최대 체력 증가,
-- Weapon: 무기 지급(플레이어 Attribute "Has<Weapon>").
Config.Crafting = {
	{
		Id = "WoodBarricade", Name = "나무 바리케이드", Cost = { Wood = 6 },
		Place = { Health = 200, Size = Vector3.new(8, 5, 1.2), Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks },
	},
	{
		Id = "StoneWall", Name = "돌벽", Cost = { Stone = 6, Wood = 2 },
		Place = { Health = 500, Size = Vector3.new(8, 6, 1.6), Color = Color3.fromRGB(125, 125, 130), Material = Enum.Material.Cobblestone },
	},
	{ Id = "CoreRepair", Name = "코어 수리", Cost = { Wood = 3, Stone = 3 }, Repair = 150 },
	{ Id = "CoreUpgrade", Name = "코어 강화", Cost = { Wood = 10, Stone = 10 }, MaxHealth = 250 },
	{ Id = "Crossbow", Name = "석궁", Cost = { Wood = 8, Stone = 4 }, Weapon = "Crossbow" }, -- 한 판에 한 번, 죽어도 유지
}

Config.Barricade = { PlaceDistance = 6 } -- 플레이어 앞 몇 스터드에 설치할지

Config.Augment = {
	EveryDays = 5,
	PickTime = 30,
	Rerolls = 1,
	Odds = { Silver = 0.6, Gold = 0.3, Prism = 0.1 },
	LateOdds = { Silver = 0.4, Gold = 0.4, Prism = 0.2 }, -- 50일 이후, 보스 날
}

return Config

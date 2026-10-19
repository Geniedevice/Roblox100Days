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
}

Config.Core = { MaxHealth = 1000 }

Config.Weapon = { Damage = 25, Range = 7, Cooldown = 0.5 }

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

Config.Augment = {
	EveryDays = 5,
	PickTime = 30,
	Rerolls = 1,
	Odds = { Silver = 0.6, Gold = 0.3, Prism = 0.1 },
	LateOdds = { Silver = 0.4, Gold = 0.4, Prism = 0.2 }, -- 50일 이후, 보스 날
}

return Config

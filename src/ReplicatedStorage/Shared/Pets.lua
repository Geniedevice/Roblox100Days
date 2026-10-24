-- 도우미 동물(서버·클라이언트 공용): 정원사 모모에게 사면 주인 섬에서 따라다니다가 밭일을 하나씩 대신 해 준다.
-- 아이템 Id = "Pet_" .. Id(보관함 1개 = 함께함). 모양은 섬 생물(Shared/Creatures)을 그대로 쓴다.
-- Jobs = 하는 일(FarmService 일 이름: Till·Plant·Water·Harvest). 명세: design/gdd/pets.md
return {
	Frog = {
		Name = "개굴이", Creature = "Frog", Order = 1, Price = 300, Jobs = { Water = true },
		Desc = "목마른 작물에 물을 줘요",
	},
	Rabbit = {
		Name = "깡총이", Creature = "Rabbit", Order = 2, Price = 500, Jobs = { Harvest = true },
		Desc = "다 자란 작물을 거둬 보관함에 넣어요",
	},
	Chicken = {
		Name = "꼬꼬", Creature = "Chicken", Order = 3, Price = 700, Jobs = { Till = true, Plant = true },
		Desc = "빈 밭을 갈고, 가장 많이 가진 씨앗을 심어요",
	},
}

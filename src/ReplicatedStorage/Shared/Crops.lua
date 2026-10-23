-- 작물 데이터(서버·클라이언트 공용). 씨앗 아이템 Id = "Seed_" .. 작물 Id, 수확물 아이템 Id = 작물 Id.
-- Grow = 다 자라는 데 걸리는 실제 초, Regrow = 수확 뒤 다시 열리는 데 걸리는 초(없으면 한 번 수확).
-- 모양: Shape = "Root"(땅에 반쯤 묻힌 뿌리), "Carrot"(주황 원뿔), "Bush"(덤불 + 열매 알)
return {
	Turnip = {
		Name = "순무", Order = 1, Grow = 300, SeedPrice = 5, SellPrice = 12,
		Shape = "Root", Leaf = Color3.fromRGB(110, 180, 90), Fruit = Color3.fromRGB(235, 225, 240),
		Desc = "구름 그늘에서도 잘 자라는 동그란 순무. 처음 농사짓는 섬 주인의 친구.",
	},
	Carrot = {
		Name = "당근", Order = 2, Grow = 900, SeedPrice = 15, SellPrice = 40,
		Shape = "Carrot", Leaf = Color3.fromRGB(90, 170, 70), Fruit = Color3.fromRGB(245, 140, 50),
		Desc = "하늘섬 바람을 맞고 자라 단맛이 진하다. 잎이 흔들리면 다 자랐다는 뜻.",
	},
	Strawberry = {
		Name = "딸기", Order = 3, Grow = 3600, Regrow = 1800, SeedPrice = 40, SellPrice = 120,
		Shape = "Bush", Leaf = Color3.fromRGB(70, 150, 70), Fruit = Color3.fromRGB(230, 60, 80),
		Desc = "한 번 심으면 거둘 때마다 다시 열린다. 정원사 모모가 제일 좋아하는 열매.",
	},
}

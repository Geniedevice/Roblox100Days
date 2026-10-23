-- 물고기 데이터(서버·클라이언트 공용). 낚은 물고기 아이템 Id = "Fish_" .. Id.
-- Weight = 낚일 비율, Only = 이 섬 컨셉 낚시터에서만(친구 섬을 찾아갈 이유), Size = 아이콘·날아오는 모형 크기(스터드)
return {
	Minnow = {
		Name = "구름 송사리", Order = 1, Color = Color3.fromRGB(200, 215, 235), Price = 3, Weight = 40, Size = 0.8,
		Desc = "구름 그림자를 따라 몰려다니는 작은 물고기.",
	},
	Carp = {
		Name = "하늘 붕어", Order = 2, Color = Color3.fromRGB(150, 160, 110), Price = 6, Weight = 30, Size = 1.2,
		Desc = "어느 하늘섬 연못에나 사는 느긋한 붕어.",
	},
	Trout = {
		Name = "무지개 송어", Order = 3, Color = Color3.fromRGB(235, 140, 160), Price = 15, Weight = 12, Size = 1.4,
		Desc = "비 갠 뒤에 잘 잡힌다. 옆구리에 무지개 띠가 있다.",
	},
	Catfish = {
		Name = "별빛 메기", Order = 4, Color = Color3.fromRGB(70, 75, 110), Price = 20, Weight = 8, Size = 1.7,
		Desc = "수염 끝이 별처럼 반짝이는 깊은 물의 메기.",
	},
	Koi = {
		Name = "벚꽃 잉어", Order = 5, Color = Color3.fromRGB(255, 175, 200), Price = 30, Weight = 14, Size = 1.6, Only = "CherryTerraces",
		Desc = "꽃잎이 떨어지는 연못에서만 산다. 벚꽃 계단섬의 자랑.",
	},
	Smelt = {
		Name = "얼음 빙어", Order = 6, Color = Color3.fromRGB(190, 225, 255), Price = 25, Weight = 14, Size = 0.9, Only = "FrozenPeaks",
		Desc = "몸이 투명해서 얼음 조각처럼 보인다. 눈꽃 봉우리섬에서만.",
	},
	Arowana = {
		Name = "정글 아로와나", Order = 7, Color = Color3.fromRGB(110, 190, 90), Price = 35, Weight = 14, Size = 1.9, Only = "JungleFalls",
		Desc = "폭포 아래에서 뛰어오르는 초록 비늘 물고기.",
	},
	Crayfish = {
		Name = "자수정 가재", Order = 8, Color = Color3.fromRGB(170, 110, 230), Price = 30, Weight = 14, Size = 1, Only = "Geode",
		Desc = "자수정 부스러기를 먹고 껍데기가 보랏빛이 됐다.",
	},
	GoldenKoi = {
		Name = "황금 비늘 잉어", Order = 9, Color = Color3.fromRGB(255, 205, 50), Price = 100, Weight = 1.5, Size = 1.8,
		Desc = "백 번 던지면 한 번쯤 만나는 행운의 잉어.",
	},
	Boot = {
		Name = "낡은 장화", Order = 10, Color = Color3.fromRGB(110, 85, 60), Price = 1, Weight = 6, Size = 1,
		Desc = "누가 하늘에서 떨어뜨렸을까. 그래도 도감에는 남는다.",
	},
}

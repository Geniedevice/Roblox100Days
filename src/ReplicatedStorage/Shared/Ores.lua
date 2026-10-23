-- 광석 데이터(서버·클라이언트 공용). 캔 광석 아이템 Id = "Ore_" .. Id. 블록 = Shared/Blocks에서 Ore = Id인 블록.
-- Hits = 부수는 데 필요한 타격 수, Respawn = 캔 뒤 다시 차오르는 실제 초, Weight = 광산 구역에 박히는 비율,
-- Bonus = { [섬 컨셉] = Weight 배수 } (메사의 금, 자수정 동굴섬의 자수정처럼 섬마다 나는 광석이 다르다)
return {
	Coal = {
		Name = "석탄", Order = 1, Color = Color3.fromRGB(60, 60, 64), Price = 4, Hits = 2, Respawn = 180, Weight = 50,
		Desc = "하늘섬 바위 틈에 흔한 검은 돌. 따뜻한 불씨가 숨어 있다.",
	},
	Copper = {
		Name = "구리", Order = 2, Color = Color3.fromRGB(215, 120, 70), Price = 8, Hits = 3, Respawn = 300, Weight = 30,
		Desc = "구름비를 맞으면 초록으로 녹스는 붉은 광석.",
	},
	Iron = {
		Name = "철", Order = 3, Color = Color3.fromRGB(215, 190, 170), Price = 15, Hits = 4, Respawn = 480, Weight = 18,
		Bonus = { FrozenPeaks = 1.5 },
		Desc = "섬을 단단히 붙잡아 주는 뼈대 같은 광석.",
	},
	Gold = {
		Name = "금", Order = 4, Color = Color3.fromRGB(250, 210, 60), Price = 30, Hits = 4, Respawn = 900, Weight = 4,
		Bonus = { Mesa = 5 },
		Desc = "붉은 메사섬 지층에 유난히 많은 반짝이는 광석.",
	},
	Amethyst = {
		Name = "자수정", Order = 5, Color = Color3.fromRGB(175, 120, 240), Price = 25, Hits = 3, Respawn = 600, Weight = 3,
		Bonus = { Geode = 8, MushroomIsle = 2 },
		Desc = "정동 속에서 자라는 보랏빛 결정. 두드리면 맑은 소리가 난다.",
	},
	Diamond = {
		Name = "다이아몬드", Order = 6, Color = Color3.fromRGB(110, 230, 225), Price = 120, Hits = 6, Respawn = 1800, Weight = 1,
		Desc = "광산 가장 깊은 곳에서 아주 가끔 보이는 하늘색 보석.",
	},
}

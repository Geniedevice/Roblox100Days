-- NPC 대화 그래프(데이터). 실행은 NpcService가 한다.
-- 노드: Line(대사 ID, 문장은 Shared/Lines) + 다음 중 하나: Choices / Next(자동 "계속") / End.
-- Set = 들어올 때 이 NPC 대화 변수에 쓴다, Action = 들어올 때(노드) 또는 고를 때(선택지) 실행할 일.
-- 선택지 If는 대화 변수 v를 받는 함수(문자열 식을 해석하지 않는다). v = 저장된 변수 + CropCount, Sold
-- 다시 올 수 있는 노드에는 Set·Action을 두지 않는다(두 번 적용되므로). 시작할 때 NpcService가 그래프를 검사한다.
local function expandChoices()
	local list = {}
	for _, zone in { "Farm", "House", "Mine", "Wild" } do
		table.insert(list, { Text = "OPT_ZONE_" .. string.upper(zone), Action = "BuyChunk_" .. zone, To = "result" })
	end
	table.insert(list, { Text = "OPT_BACK", To = "hello" })
	return list
end

return {
	Guide = {
		Start = function(v)
			return if v.Met then "hello" else "intro"
		end,
		Nodes = {
			intro = { Line = "GUIDE_INTRO", Next = "intro2" },
			intro2 = { Line = "GUIDE_INTRO2", Next = "intro3" },
			intro3 = { Line = "GUIDE_INTRO3", Set = { Met = true }, Next = "hello" },
			hello = {
				Line = "GUIDE_HELLO",
				Choices = {
					{ Text = "OPT_SELL_GOODS", Action = "SellGoods", To = "sold", If = function(v)
						return v.GoodsCount > 0
					end },
					{ Text = "OPT_BUY_FIELD", Action = "BuyField", To = "result", If = function(v)
						return v.Home and v.FieldsLeft > 0
					end },
					{ Text = "OPT_EXPAND", To = "expand", If = function(v)
						return v.Home and v.ChunksLeft > 0
					end },
					{ Text = "OPT_ISLAND_INFO", To = "info" },
					{ Text = "OPT_ZONES", To = "zones" },
					{ Text = "OPT_BYE", To = "bye" },
				},
			},
			sold = { Line = "GUIDE_SOLD", Next = "hello" },
			result = { Line = "GUIDE_RESULT", Next = "hello" },
			expand = { Line = "GUIDE_EXPAND", Choices = expandChoices() },
			info = { Line = "GUIDE_INFO", Next = "info2" },
			info2 = { Line = "GUIDE_INFO2", Next = "hello" },
			zones = { Line = "GUIDE_ZONES", Next = "zones2" },
			zones2 = { Line = "GUIDE_ZONES2", Next = "hello" },
			bye = { End = true },
		},
	},
	Gardener = {
		Start = function(v)
			return if v.Met then "hello" else "intro"
		end,
		Nodes = {
			intro = { Line = "MOMO_INTRO", Next = "intro2" },
			intro2 = { Line = "MOMO_INTRO2", Next = "intro3" },
			intro3 = { Line = "MOMO_INTRO3", Set = { Met = true }, Action = "GiftSeeds", Next = "hello" },
			hello = {
				Line = "MOMO_HELLO",
				Choices = {
					{ Text = "OPT_BUY_SEEDS", Action = "OpenShop", To = "bye" },
					{ Text = "OPT_SELL", To = "sold", Action = "SellCrops", If = function(v)
						return v.CropCount > 0
					end },
					{ Text = "OPT_HOWTO", To = "howto" },
					{ Text = "OPT_BYE", To = "bye" },
				},
			},
			sold = { Line = "MOMO_SOLD", Next = "hello" },
			howto = { Line = "MOMO_HOWTO", Next = "howto2" },
			howto2 = { Line = "MOMO_HOWTO2", Next = "hello" },
			bye = { End = true },
		},
	},
	Carpenter = {
		Start = function(v)
			return if v.Met then "hello" else "intro"
		end,
		Nodes = {
			intro = { Line = "BUNNY_INTRO", Next = "intro2" },
			intro2 = { Line = "BUNNY_INTRO2", Set = { Met = true }, Next = "hello" },
			hello = {
				Line = "BUNNY_HELLO",
				Choices = {
					{ Text = "OPT_BUY_FURNITURE", Action = "OpenShop", To = "bye" },
					{ Text = "OPT_DECOR_TIP", To = "tip" },
					{ Text = "OPT_BYE", To = "bye" },
				},
			},
			tip = { Line = "BUNNY_TIP", Next = "tip2" },
			tip2 = { Line = "BUNNY_TIP2", Next = "hello" },
			bye = { End = true },
		},
	},
}

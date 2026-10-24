-- 대사 문자열 표(대사 ID → 문장). 대화 데이터는 ID만 쓰고, 언어를 늘리면 표를 하나 더 둔다.
-- {이름}은 대화 변수로 바뀐다. 없는 ID는 <MISSING:ID>로 보여 QA에서 바로 보인다.
local Lines = {}

Lines.ko = {
	OPT_NEXT = "계속",
	OPT_BYE = "다음에 봐",

	MOMO_INTRO = "어머, 새 섬 주인이구나! 나는 정원사 모모야. 이 섬 흙, 아주 포근해 보여.",
	MOMO_INTRO2 = "농지를 누르면 흙을 갈고, 씨앗을 고른 채 누르면 심어져. 물을 주면 더 빨리 자란단다.",
	MOMO_INTRO3 = "첫 선물로 순무 씨앗을 줄게. 천천히 해도 돼, 작물은 시들지 않거든.",
	MOMO_HELLO = "오늘도 좋은 바람이야. 뭘 도와줄까?",
	MOMO_SOLD = "{Sold}코인이야! 정성껏 키웠구나.",
	MOMO_HOWTO = "작물은 네가 섬을 비운 동안에도 자라. 물을 주면 한동안 1.5배 빨리 크고.",
	MOMO_HOWTO2 = "다 자란 작물은 반짝반짝 빛나. 눌러서 거두고 나한테 가져오면 사 줄게.",
	OPT_BUY_SEEDS = "씨앗 사기",
	OPT_PETS = "도우미 동물 보기",
	OPT_SELL = "작물 팔기",
	OPT_HOWTO = "농사 요령",

	BUNNY_INTRO = "안녕! 나는 목수 버니야. 이 섬, 꾸밀 자리가 아주 많아 보이네.",
	BUNNY_INTRO2 = "가구를 사면 보관함에 넣어 둘게. '꾸미기'를 누르고 원하는 자리에 놓아 봐.",
	BUNNY_HELLO = "오늘은 뭘 만들어 볼까?",
	BUNNY_TIP = "같은 세트를 다 모아 놓으면 섬이 훨씬 아늑해져. 의자, 탁자, 불빛도 하나씩 있으면 좋고.",
	BUNNY_TIP2 = "잡초나 낙엽이 보이면 눌러서 치워 줘. 깔끔한 섬은 아늑함이 조금 더 올라가.",
	OPT_BUY_FURNITURE = "가구 사기",
	OPT_DECOR_TIP = "꾸미기 요령",

	GUIDE_INTRO = "어서 와! 나는 하늘섬 안내인 루미야. 이 섬은 땅 조각(청크) 16개로 되어 있어.",
	GUIDE_INTRO2 = "여기 상점 거리를 가운데로 서쪽은 농장, 동쪽은 낚시터, 남쪽은 집터, 북서쪽은 광산이야.",
	GUIDE_INTRO3 = "낚은 물고기와 캔 광석은 내가 사 줄게. 코인을 모으면 나한테서 밭을 열고 섬도 넓힐 수 있어!",
	GUIDE_HELLO = "오늘은 섬을 어떻게 가꿔 볼까?",
	GUIDE_SOLD = "{Sold}코인이야! 이 섬 물고기랑 광석은 질이 좋다니까.",
	GUIDE_RESULT = "{Result}",
	GUIDE_FIELD_DONE = "밭이 하나 늘었어! 농장으로 가 봐.",
	GUIDE_LAND_DONE = "새 땅이 붙었어! 섬 가장자리를 봐.",
	GUIDE_NO_COINS = "코인이 조금 모자라. 물고기나 광석을 더 모아 와!",
	GUIDE_NO_LAND = "더 붙일 땅이 없어. 이 섬은 이제 아주 넓어!",
	GUIDE_EXPAND = "{ChunkPrice}코인이면 섬 가장자리에 땅 하나를 붙일 수 있어. 어떤 땅으로 만들까?",
	GUIDE_INFO = "여기는 {Island}이야. 섬마다 시드가 달라서 나는 것도 달라.",
	GUIDE_INFO2 = "이 섬 명물은 물고기 {SpecialFish}, 광석 {SpecialOre}, 작물 {SpecialCrop}! 친구 섬에는 또 다른 게 있을 거야.",
	GUIDE_ZONES = "농장 밭에서 씨앗을 키우고, 낚시터에서는 물을 눌러 낚싯대를 던져. 찌에 '!'가 뜨면 바로 다시 눌러!",
	GUIDE_ZONES2 = "광산에서는 반짝이는 광석 블록을 여러 번 두드려 캐. 집터 오두막은 버니 가구로 꾸미면 돼.",
	OPT_SELL_GOODS = "물고기·광석 팔기",
	OPT_BUY_FIELD = "밭 열기 ({FieldPrice}코인)",
	OPT_EXPAND = "섬 넓히기 ({ChunkPrice}코인)",
	OPT_ISLAND_INFO = "이 섬의 명물",
	OPT_ZONES = "구역 안내",
	OPT_BACK = "다시 생각해 볼게",
	OPT_ZONE_FARM = "농장 땅 (밭 자리 4개)",
	OPT_ZONE_HOUSE = "집터 땅 (꾸미기)",
	OPT_ZONE_MINE = "광산 땅 (광석 바위산)",
	OPT_ZONE_WILD = "숲 땅 (나무·생물)",

	-- NPC끼리 잡담(말풍선)
	CHAT_MOMO_1 = "버니, 오늘 바람 냄새가 달콤하지 않아?",
	CHAT_BUNNY_1 = "응, 나무 말리기 딱 좋은 날이야.",
	CHAT_MOMO_2 = "주인이 심은 새싹이 쑥쑥 크고 있어.",
	CHAT_BUNNY_2 = "그럼 밭 옆에 벤치 하나 놓아 주고 싶다.",
	CHAT_MOMO_3 = "구름 아래로 떨어진 씨앗은 어디로 갈까?",
	CHAT_BUNNY_3 = "아마 다른 하늘섬에서 꽃이 되겠지.",
}

-- 잡담 순서 { 말하는 NPC Id, 대사 ID }
Lines.Chatter = {
	{ "Gardener", "CHAT_MOMO_1" }, { "Carpenter", "CHAT_BUNNY_1" },
	{ "Gardener", "CHAT_MOMO_2" }, { "Carpenter", "CHAT_BUNNY_2" },
	{ "Gardener", "CHAT_MOMO_3" }, { "Carpenter", "CHAT_BUNNY_3" },
}

-- 한국어 조사: 마지막 글자에 받침이 있으면 withFinal, 없으면 withoutFinal (Josa("당근", "이", "가") → "당근이")
function Lines.Josa(word, withFinal, withoutFinal)
	local last = utf8.codepoint(word, utf8.offset(word, -1))
	local hasFinal = last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 ~= 0
	return word .. (if hasFinal then withFinal else withoutFinal)
end

function Lines.Get(id, vars, locale)
	local text = (Lines[locale or "ko"] or Lines.ko)[id] or Lines.ko[id] or ("<MISSING:" .. id .. ">")
	return (text:gsub("{(%w+)}", function(name)
		return vars and vars[name] ~= nil and tostring(vars[name]) or "{" .. name .. "}"
	end))
end

return Lines

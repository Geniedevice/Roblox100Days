-- UnionService 규칙 검사(가짜 플레이어 6명). MCP 2인 플레이를 띄울 수 없어서 자리·보너스·다리·끊기·재접속 규칙만 따로 돌린다.
-- 실행: src/를 Studio에 동기화한 뒤, MCP execute_luau(Edit)에 이 파일 내용을 그대로 넣는다. 끝까지 가면 "PASS n"을 돌려준다.
-- 플레이스의 UnionService 소스를 읽어 의존 모듈만 가짜로 바꿔 끼운다. 못 찾으면 "NOT RUN"으로 멈춘다.
local source = game.ServerScriptService.Services.UnionService.Source
local swaps = {
	{ "require%(ReplicatedStorage%.Shared%.Remotes%)", "_G.UnionTest.Remotes" },
	{ "require%(script%.Parent%.DataService%)", "_G.UnionTest.DataService" },
	{ "require%(script%.Parent%.DexService%)", "_G.UnionTest.DexService" },
	{ "require%(script%.Parent%.IslandGen%)", "_G.UnionTest.IslandGen" },
	{ "require%(script%.Parent%.IslandService%)", "_G.UnionTest.IslandService" },
	{ "require%(script%.Parent%.PartyService%)", "_G.UnionTest.PartyService" },
	{ 'typeof%(target%) ~= "Instance" or not target:IsA%("Player"%)', 'type(target) ~= "table"' },
	{ "game:GetService%(\"Players\"%)", "_G.UnionTest.Players" },
	{ "local INVITE_COOLDOWN = 3", "local INVITE_COOLDOWN = 0" }, -- 검사는 연달아 보낸다
}
for _, swap in swaps do
	local count
	source, count = source:gsub(swap[1], swap[2])
	if count ~= 1 then
		return "NOT RUN — UnionService에서 '" .. swap[1] .. "'를 " .. count .. "번 찾음(1번이어야 한다)"
	end
end

-- 가짜 세계 -----------------------------------------------------------------------------------
local PlayersStub = {}
local log = {} -- { Who, Kind, Text }
local dex = {} -- [이름] = { 컨셉 }
local moves = {} -- [이름] = 옮긴 횟수
local profiles, records, party = {}, {}, {}
local nextSlot = 0

local function fakePlayer(name, id)
	local attrs = {}
	local p = { Name = name, DisplayName = name, UserId = id, Parent = PlayersStub }
	function p:SetAttribute(key, value)
		attrs[key] = value
	end
	function p:GetAttribute(key)
		return attrs[key]
	end
	profiles[p] = { Settings = {} }
	return p
end
local A, B, C, D, F, G = fakePlayer("A", 1), fakePlayer("B", 2), fakePlayer("C", 3), fakePlayer("D", 4), fakePlayer("F", 5), fakePlayer("G", 6)
for _, p in { A, B, C, D, F } do
	party[p] = 1 -- G만 파티 밖
end

local IslandStub = {
	Spawn = function(p, _, place)
		local slot = place and place.Slot
		if not slot then
			nextSlot += 1
			slot = nextSlot
		end
		local origin = if place then place.Origin else Vector3.new(slot * 1200, 0, 0)
		records[p] = { Slot = slot, Origin = origin, Model = Instance.new("Folder"), Concept = p.Name .. "Concept", YardY = 6,
			Spawn = CFrame.new(origin) }
		return records[p]
	end,
	Get = function(p)
		return records[p]
	end,
	Extent = function()
		return 144
	end,
	Ground = function()
		return nil -- 가짜 섬에는 땅이 없다: 다리는 마당 높이로
	end,
	Rebuilt = { Event = { Connect = function() end } },
}

local handler
_G.UnionTest = {
	Players = PlayersStub,
	Remotes = {
		Feedback = { FireClient = function(_, who, kind, info)
			table.insert(log, { Who = who, Kind = kind, Text = info.Text })
		end },
		Interact = { OnServerEvent = { Connect = function(_, fn)
			handler = fn
		end } },
	},
	DataService = { Get = function(p)
		return profiles[p]
	end },
	DexService = { Record = function(p, category, id)
		dex[p.Name] = dex[p.Name] or {}
		table.insert(dex[p.Name], category .. ":" .. id)
	end },
	IslandGen = { CELL = 3 },
	IslandService = IslandStub,
	PartyService = { Same = function(a, b)
		return a == b or (party[a] ~= nil and party[a] == party[b])
	end },
}

local module = Instance.new("ModuleScript")
module.Source = source
local ok, UnionService = pcall(require, module)
module:Destroy()
if not ok then
	return "NOT RUN — require 실패: " .. tostring(UnionService)
end
UnionService.Start(function(p, place) -- Main.moveIsland 대신: 옛 섬을 지우고 그 자리에 다시 짓는다
	records[p].Model:Destroy()
	moves[p.Name] = (moves[p.Name] or 0) + 1
	return IslandStub.Spawn(p, profiles[p], place)
end)
for _, p in { A, B, C, D, F, G } do
	UnionService.Spawn(p, profiles[p]) -- 연합 없음: 각자 슬롯
end

local passed = 0
local function check(condition, what)
	assert(condition, "FAIL: " .. what)
	passed += 1
end
local function lastToast(who)
	for i = #log, 1, -1 do
		if log[i].Who == who and log[i].Kind == "Toast" then
			return log[i].Text
		end
	end
	return ""
end
local function bridges(center)
	local folder = records[center].Model:FindFirstChild("UnionBridges")
	local n = 0
	for _, part in folder and folder:GetChildren() or {} do
		n += if part.Name == "Bridge" then 1 else 0
	end
	return n
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end
local function unite(from, to)
	handler(from, "Unite", to)
	handler(to, "UniteAnswer", from, true)
end

-- 1. A가 B에게 섬 잇기 → B 섬이 A 동쪽 360, 같은 슬롯, 다리 1개, 보너스 0.05, 서로 도감
local slotA, originA = records[A].Slot, records[A].Origin
handler(A, "Unite", B)
check(log[#log - 1] and log[#log - 1].Who == B and log[#log - 1].Kind == "Unite", "B가 섬 잇기 카드를 받는다")
handler(B, "UniteAnswer", A, true)
check(records[B].Origin == originA + Vector3.new(360, 0, 0) and records[B].Slot == slotA, "B 섬이 A 동쪽 360, A 슬롯")
check(records[A].Origin == originA and (moves.A or 0) == 0, "A 섬은 그대로")
check(A:GetAttribute("UnionId") ~= nil and A:GetAttribute("UnionId") == B:GetAttribute("UnionId"), "A·B 같은 UnionId")
check(profiles[A].Union.Id == A:GetAttribute("UnionId") and profiles[B].Union.Id == A:GetAttribute("UnionId"), "둘 다 profile.Union 저장")
check(near(A:GetAttribute("UnionBonus"), 0.05) and near(B:GetAttribute("UnionBonus"), 0.05), "보너스 0.05")
check(bridges(A) == 1, "다리 1개(가운데 섬 안)")
check(table.find(dex.B, "Islands:AConcept") and table.find(dex.A, "Islands:BConcept"), "서로 섬 도감")

-- 2. 셋째는 남쪽, 보너스 0.10
unite(A, C)
check(records[C].Origin == originA + Vector3.new(0, 0, 360), "C는 남쪽(+Z)")
check(near(A:GetAttribute("UnionBonus"), 0.10) and near(C:GetAttribute("UnionBonus"), 0.10), "3섬 보너스 0.10")
check(bridges(A) == 2, "다리 2개")

-- 3. 거절 · 파티 밖 · 이미 같은 연합
handler(A, "Unite", D)
handler(D, "UniteAnswer", A, false)
check(D:GetAttribute("UnionId") == nil and lastToast(A):find("거절"), "거절하면 그대로, 보낸 사람에게 토스트")
handler(A, "Unite", G)
check(lastToast(A):find("파티원"), "파티 밖 G에게는 못 보낸다")
handler(A, "Unite", B)
check(lastToast(A):find("이미 같은 연합"), "이미 같은 연합")

-- 4. B가 끊으면 새 슬롯으로, A·C 보너스 0.05, 다리 1개
handler(B, "LeaveUnion")
check(B:GetAttribute("UnionId") == nil and profiles[B].Union == nil and B:GetAttribute("UnionBonus") == nil, "B 연합·보너스 지움")
check(records[B].Slot ~= slotA and moves.B == 2, "B 섬은 새 슬롯으로")
check(near(A:GetAttribute("UnionBonus"), 0.05) and bridges(A) == 1, "남은 A·C 보너스 0.05, 다리 1개")

-- 5. 빈 동쪽 자리는 다음 사람이, 그다음은 서쪽. 4섬이면 가득
unite(A, D)
check(records[D].Origin == originA + Vector3.new(360, 0, 0), "D는 비어 있던 동쪽")
unite(C, F) -- 이웃(C)이 보내도 같은 연합의 빈 자리로
check(records[F].Origin == originA + Vector3.new(-360, 0, 0) and F:GetAttribute("UnionId") == A:GetAttribute("UnionId"), "F는 서쪽")
check(near(A:GetAttribute("UnionBonus"), 0.15) and bridges(A) == 3, "4섬: 보너스 0.15(최대), 다리 3개")
handler(A, "Unite", B)
check(lastToast(A):find("가득"), "4섬이면 더 못 보낸다")

-- 6. 가운데 A가 나가면 다리가 사라지고 이웃은 그대로. 다시 들어오면 가운데로
UnionService.Unload(A)
records[A].Model:Destroy()
records[A] = nil
check(records[D].Origin == originA + Vector3.new(360, 0, 0), "이웃 섬은 그대로")
check(near(D:GetAttribute("UnionBonus"), 0.10), "남은 3섬 보너스 0.10")
UnionService.Spawn(A, profiles[A])
check(records[A].Origin == originA and records[A].Slot == slotA, "A가 다시 들어오면 가운데로")
check(bridges(A) == 3 and near(A:GetAttribute("UnionBonus"), 0.15), "다리 3개 다시, 보너스 0.15")

-- 7. 가득 찬 연합에 멤버가 다시 들어오면 내 슬롯에 따로(권한용 UnionId는 유지, 보너스 없음)
profiles[G].Union = { Id = A:GetAttribute("UnionId") }
records[G].Model:Destroy()
UnionService.Spawn(G, profiles[G])
check(records[G].Slot ~= slotA and G:GetAttribute("UnionId") == A:GetAttribute("UnionId") and G:GetAttribute("UnionBonus") == nil,
	"가득 차면 따로 서고 UnionId만")

-- 8. 혼자 남은 멤버가 끊으면 섬을 옮기지 않는다
for _, p in { A, C, D, F } do
	if p ~= D then
		UnionService.Unload(p)
	end
end
local before = moves.D or 0
handler(D, "LeaveUnion")
check((moves.D or 0) == before and D:GetAttribute("UnionId") == nil, "혼자면 그 자리에서 끊기만")

_G.UnionTest = nil
return "PASS " .. passed

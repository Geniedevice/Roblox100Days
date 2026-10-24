-- PartyPlayService 규칙 검사(가짜 플레이어 3명, 가짜 시계). MCP로 2인 플레이를 띄울 수 없어서 규칙만 따로 돌린다.
-- 실행: src/를 Studio에 동기화한 뒤 MCP execute_luau(Edit)에 이 파일 내용. 끝까지 가면 "PASS n", 아니면 "FAIL k/n" + 줄마다 결과.
-- 플레이스의 PartyPlayService 소스를 읽어 의존(Remotes·DataService·Inventory·PartyService·Players·시계)만 가짜로 바꿔 끼운다.
-- 바꿔 끼울 줄을 못 찾으면 "NOT RUN"(검사가 안 돌았는데 통과처럼 보이지 않게).
local HttpService = game:GetService("HttpService")
local source = game.ServerScriptService.Services.PartyPlayService.Source
local swaps = {
	{ "require%(ReplicatedStorage%.Shared%.Remotes%)", "_G.PPTest.Remotes", 1 },
	{ "require%(script%.Parent%.DataService%)", "_G.PPTest.DataService", 1 },
	{ "require%(script%.Parent%.Inventory%)", "_G.PPTest.Inventory", 1 },
	{ "require%(script%.Parent%.PartyService%)", "_G.PPTest.PartyService", 1 },
	{ 'game:GetService%("Players"%)', "_G.PPTest.Players", 1 },
	{ "workspace:GetServerTimeNow%(%)", "_G.PPTest.Now()", 1 },
	{ "os%.clock%(%)", "_G.PPTest.Now()", 3 }, -- 주석 2곳 포함
	{ 'typeof%(target%) == "Instance" and target:IsA%("Player"%)', 'type(target) == "table"', 1 },
	{ "task%.wait%(1%)", "do return end", 1 }, -- Start의 1초 반복은 돌리지 않고 _tick을 직접 부른다
}
for _, swap in swaps do
	local count
	source, count = source:gsub(swap[1], swap[2])
	if count ~= swap[3] then
		return "NOT RUN — PartyPlayService에서 '" .. swap[1] .. "'를 " .. count .. "번 찾음(" .. swap[3] .. "번이어야 한다)"
	end
end

-- 가짜 세계 -----------------------------------------------------------------------------------
local clock = 1000
local log = {} -- { Who, Kind, Info }
local coins = {}
local parties = {} -- [player] = members
local players = {}

local function fakePlayer(name, id, x)
	local attrs = {}
	local root = { Position = Vector3.new(x, 0, 0) }
	local character = { FindFirstChild = function(_, n)
		return if n == "HumanoidRootPart" then root else nil
	end }
	local p = { Name = name, DisplayName = name, UserId = id, Character = character, Root = root }
	function p:SetAttribute(key, value)
		attrs[key] = value
	end
	function p:GetAttribute(key)
		return attrs[key]
	end
	coins[p] = 0
	table.insert(players, p)
	return p
end
local A, B, C = fakePlayer("A", 1, 0), fakePlayer("B", 2, 5), fakePlayer("C", 3, 10)

local handler
_G.PPTest = {
	Now = function()
		return clock
	end,
	Players = { GetPlayers = function()
		return players
	end },
	Remotes = {
		Feedback = {
			FireClient = function(_, who, kind, info)
				table.insert(log, { Who = who, Kind = kind, Info = info })
			end,
			FireAllClients = function(_, kind, info)
				table.insert(log, { Who = "all", Kind = kind, Info = info })
			end,
		},
		Interact = { OnServerEvent = { Connect = function(_, fn)
			handler = fn
		end } },
	},
	DataService = { Get = function()
		return {}
	end },
	Inventory = { AddCoins = function(p, n)
		coins[p] += n
		return true
	end },
	PartyService = { Members = function(p)
		return parties[p]
	end },
}
local fn, err = loadstring(source)
if not fn then
	return "NOT RUN — " .. tostring(err)
end
local Play = fn()
Play.Start()

local function party(...)
	local members = { ... }
	for _, p in players do
		parties[p] = nil
		p:SetAttribute("PartyId", nil)
	end
	for _, p in members do
		parties[p] = members
		p:SetAttribute("PartyId", "P" .. members[1].Name)
	end
end
local function quest(p)
	local raw = p:GetAttribute("PartyQuest")
	return raw and HttpService:JSONDecode(raw)
end
local function contest(p)
	local raw = p:GetAttribute("PartyContest")
	return raw and HttpService:JSONDecode(raw)
end
local function find(who, kind, from)
	for i = from or 1, #log do
		if log[i].Kind == kind and (who == nil or log[i].Who == who) then
			return log[i]
		end
	end
	return nil
end

local lines, failed, total = {}, 0, 0
local function check(ok, what)
	total += 1
	failed += if ok then 0 else 1
	table.insert(lines, (if ok then "ok   " else "FAIL ") .. what)
end

-- 1. 혼자면 의뢰가 없고 셈은 무시된다
Play._tick()
Play.Count(A, "Fish")
check(quest(A) == nil and contest(A) == nil, "혼자: 의뢰 없음")

-- 2. A·B 파티: 의뢰가 생기고 목표 = Per × 2, 둘이 함께 채운다
party(A, B)
Play._tick()
local q = quest(A)
check(q ~= nil and quest(B) ~= nil and q.Need % 2 == 0 and q.Have == 0, "파티 2명: 둘 다 의뢰 " .. (q and q.Label .. " 0/" .. q.Need or "없음"))
local other = if q.Kind == "Fish" then "Ore" else "Fish"
Play.Count(A, other)
check(quest(A).Have == 0, "다른 종류는 세지 않는다")
Play.Count(A, q.Kind)
check(quest(B).Have == 1, "A가 한 일이 B 카드에도 오른다")
for i = 2, q.Need do
	Play.Count(if i % 2 == 0 then B else A, q.Kind)
end
q = quest(A)
check(q.RestUntil ~= nil and coins[A] == 40 and coins[B] == 40 and find(A, "Banner") and find(B, "Banner"),
	string.format("다 채움 → 둘 다 +40(%d/%d), 배너, 쉬는 중", coins[A], coins[B]))
Play.Count(A, q.Kind)
check(quest(A).Have == q.Have and coins[A] == 40, "쉬는 중 셈은 무시")
clock += 46
Play._tick()
local q2 = quest(A)
check(q2.RestUntil == nil and q2.Have == 0 and q2.Kind ~= q.Kind, "45초 뒤 다른 종류 새 의뢰 " .. q2.Label)

-- 3. 인원이 늘면 목표도 는다
party(A, B, C)
Play._tick()
check(quest(C) ~= nil and quest(C).Need == quest(A).Need and quest(A).Need == q2.Need / 2 * 3, "3명이 되면 목표 ×3/2 = " .. quest(A).Need)
party(A, B)
Play._tick()
check(quest(C) == nil and quest(A).Need == q2.Need, "C가 나가면 C 카드가 사라지고 목표가 돌아간다")

-- 4. 대회: 파티장만, 준비 3초는 안 세고, 종류가 맞아야 하고, 1등 50·참가 15, 끝난 뒤 60초 쉼
local mark = #log + 1
handler(B, "Contest", nil, "Fish")
check(contest(A) == nil and find(B, "Toast", mark) and find(B, "Toast", mark).Info.Text:find("파티장"), "파티장이 아니면 못 연다")
handler(A, "Contest", nil, "Nope")
check(contest(A) == nil, "없는 대회 종류는 무시")
handler(A, "Contest", nil, "Fish")
local c = contest(B)
check(c ~= nil and c.Label == "낚시 대회" and find(B, "Banner", mark) ~= nil, "A가 낚시 대회를 열면 B도 배너·카드")
Play.Count(A, "Fish")
check(contest(A).Scores["1"] == nil, "준비 3초 동안은 세지 않는다")
clock += 4
local before = { A = coins[A], B = coins[B] }
Play.Count(A, "Fish")
Play.Count(A, "Fish")
Play.Count(B, "Fish")
Play.Count(A, "Harvest")
c = contest(A)
check(c.Scores["1"] == 2 and c.Scores["2"] == 1, string.format("점수 A %s · B %s(수확은 안 셈)", tostring(c.Scores["1"]), tostring(c.Scores["2"])))
handler(A, "Contest", nil, "Ore")
check(contest(A).Kind == "Fish", "대회 중에 또 열 수 없다")
clock += 120
Play._tick()
check(contest(A) == nil and coins[A] - before.A == 50 and coins[B] - before.B == 15,
	string.format("끝: A +%d(1등 50) · B +%d(참가 15)", coins[A] - before.A, coins[B] - before.B))
mark = #log + 1
handler(A, "Contest", nil, "Harvest")
check(contest(A) == nil and find(A, "Toast", mark) and find(A, "Toast", mark).Info.Text:find("초 뒤"), "끝난 뒤 60초 안에는 못 연다")
clock += 61
handler(A, "Contest", nil, "Harvest")
check(contest(A) ~= nil and contest(A).Kind == "Harvest", "60초 뒤에는 연다")
clock += 124
Play._tick()
local tieA, tieB = coins[A], coins[B]
check(contest(A) == nil, "아무도 안 하면 그냥 끝(보상 없음)")
check(coins[A] == tieA and coins[B] == tieB, "기록 0이면 코인 없음")

-- 5. 하이파이브: A→B, 5초 안에 B→A. 같은 두 사람 120초에 한 번 코인
mark = #log + 1
local cA, cB = coins[A], coins[B]
handler(A, "Greet", B)
check(find("all", "Greet", mark) ~= nil and find("all", "HighFive", mark) == nil, "A→B 인사")
clock += 1
handler(B, "Greet", A)
local five = find("all", "HighFive", mark)
check(five ~= nil and five.Info.Coins == 5 and coins[A] == cA + 5 and coins[B] == cB + 5, "5초 안에 B→A → 하이파이브 +5씩")
clock += 3
mark = #log + 1
handler(A, "Greet", B)
clock += 1
handler(B, "Greet", A)
five = find("all", "HighFive", mark)
check(five ~= nil and five.Info.Coins == nil and coins[A] == cA + 5, "120초 안 두 번째 하이파이브는 연출만")
clock += 3
mark = #log + 1
handler(A, "Greet", B)
clock += 6
handler(B, "Greet", A)
check(find("all", "HighFive", mark) == nil, "5초가 지나면 그냥 인사")
mark = #log + 1
C.Root.Position = Vector3.new(100, 0, 0)
handler(A, "Greet", C)
check(find("all", "Greet", mark) == nil, "24스터드 밖은 인사 안 됨")

-- 6. 파티가 사라지면 카드도 사라진다
party()
Play._tick()
check(quest(A) == nil and quest(B) == nil and contest(A) == nil, "파티가 끝나면 의뢰·대회 속성이 지워진다")

_G.PPTest = nil
return (if failed == 0 then "PASS " .. total else string.format("FAIL %d/%d", failed, total)) .. "\n" .. table.concat(lines, "\n")

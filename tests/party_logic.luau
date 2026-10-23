-- PartyService 규칙 검사(가짜 플레이어 3명). MCP 2인 플레이를 띄울 수 없어서 규칙만 따로 돌린다.
-- 실행: src/를 Studio에 동기화한 뒤, MCP execute_luau(Edit)에 이 파일 내용을 그대로 넣는다. 끝까지 가면 "PASS n"을 돌려준다.
-- 플레이스의 PartyService 소스를 읽어 의존 모듈(DataService·DexService·IslandService·Remotes)만 가짜로 바꿔 끼운다.
-- 바꿔 끼울 줄을 못 찾으면 "NOT RUN"으로 멈춘다(검사가 안 돌았는데 통과처럼 보이지 않게).
local source = game.ServerScriptService.Services.PartyService.Source
local swaps = {
	{ "require%(ReplicatedStorage%.Shared%.Remotes%)", "_G.PartyTest.Remotes" },
	{ "require%(script%.Parent%.DataService%)", "_G.PartyTest.DataService" },
	{ "require%(script%.Parent%.DexService%)", "_G.PartyTest.DexService" },
	{ "require%(script%.Parent%.IslandService%)", "_G.PartyTest.IslandService" },
	{ 'typeof%(target%) ~= "Instance" or not target:IsA%("Player"%)', 'type(target) ~= "table"' },
	{ "game:GetService%(\"Players\"%)", "_G.PartyTest.Players" },
}
for _, swap in swaps do
	local count
	source, count = source:gsub(swap[1], swap[2])
	if count ~= 1 then
		return "NOT RUN — PartyService에서 '" .. swap[1] .. "'를 " .. count .. "번 찾음(1번이어야 한다)"
	end
end

-- 가짜 세계 -----------------------------------------------------------------------------------
local PlayersStub = {}
local log = {} -- { Who, Kind, Text }
local moved = {} -- [이름] = 섬 주인 이름
local dex = {} -- [이름] = { 컨셉 }
local profiles, records = {}, {}

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
	records[p] = { Concept = name .. "Concept", Owner = p }
	return p
end
local A, B, C = fakePlayer("A", 1), fakePlayer("B", 2), fakePlayer("C", 3)

local handler
_G.PartyTest = {
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
	IslandService = {
		Get = function(p)
			return records[p]
		end,
		MoveTo = function(p, record)
			moved[p.Name] = record.Owner.Name
		end,
	},
}

local module = Instance.new("ModuleScript")
module.Source = source
local ok, PartyService = pcall(require, module)
module:Destroy()
if not ok then
	return "NOT RUN — require 실패: " .. tostring(PartyService)
end
PartyService.Start()

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
	return nil
end

-- 1. 초대 → 수락: 같은 파티, 초대한 사람이 파티장
handler(A, "Invite", B)
check(log[1] and log[1].Who == B and log[1].Kind == "Invite", "B가 초대 카드를 받는다")
handler(B, "Answer", A, true)
check(A:GetAttribute("PartyId") ~= nil and A:GetAttribute("PartyId") == B:GetAttribute("PartyId"), "A·B 같은 PartyId")
check(A:GetAttribute("PartyLeader") == true and B:GetAttribute("PartyLeader") == false, "A가 파티장")
check(PartyService.Same(A, B) and not PartyService.Same(A, C), "Same: A·B 예, A·C 아니오")

-- 2. 수확 허락은 주인 설정
check(not PartyService.CanHarvest(B, A), "파티원 수확 기본 꺼짐")
profiles[A].Settings.HarvestParty = true
check(PartyService.CanHarvest(B, A) and not PartyService.CanHarvest(C, A), "켜면 파티원만 수확")

-- 3. 방문: 파티원만 설정이면 파티 아닌 C는 막히고, 파티원 B는 된다. 방문하면 섬 도감 기록
profiles[A].Settings.VisitParty = true
handler(C, "Visit", A)
check(moved.C == nil and lastToast(C) ~= nil, "파티원만 섬에 C 방문 거절")
handler(B, "Visit", A)
check(moved.B == "A" and dex.B and dex.B[1] == "Islands:AConcept", "B는 A 섬으로 가고 섬 도감 기록")
handler(B, "Home")
check(moved.B == "B", "집으로")

-- 4. 이미 파티에 있는 사람은 초대 못 함, 연타는 무시
local before = #log
handler(A, "Invite", B)
check(#log == before, "3초 안 두 번째 초대는 무시")

-- 5. 파티장이 나가면 남은 한 명뿐이라 파티가 사라진다
handler(A, "LeaveParty")
check(A:GetAttribute("PartyId") == nil and B:GetAttribute("PartyId") == nil, "2명 파티에서 한 명이 나가면 파티 끝")

-- 6. 거절
handler(C, "Invite", A)
handler(A, "Answer", C, false)
check(A:GetAttribute("PartyId") == nil and lastToast(C) ~= nil, "거절하면 파티 없음, 초대한 사람에게 토스트")

_G.PartyTest = nil
return "PASS " .. passed

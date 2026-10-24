-- 파티 놀거리(명세: design/gdd/party-play.md). 같은 파티(2명 이상)일 때:
--  파티 의뢰: 파티원 모두가 함께 채우는 목표(작물 거두기·물고기 낚기·광석 캐기·친구 밭 물주기·섬 이벤트). 다 채우면 모두 코인
--  파티 대회: 파티장이 친구 창에서 연다. 2분 동안 낚시·수확·채굴 중 하나를 누가 많이 하나. 1등 50, 한 번이라도 한 사람 15코인
--  인사·하이파이브: 다른 플레이어를 누르면 손 인사. 둘이 5초 안에 서로 인사하면 하이파이브(파티가 아니어도 된다)
-- 셈은 각 서비스가 PartyPlayService.Count(누른 사람, 종류)로 알린다(도우미 동물이 한 일은 부르지 않는다).
-- 상태는 서버 메모리뿐이고 파티원 속성 PartyQuest·PartyContest(JSON)로 보인다(SocialClient가 왼쪽 파티 카드로 그린다).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Inventory = require(script.Parent.Inventory)
local PartyService = require(script.Parent.PartyService)

local QUESTS = {
	Harvest = { Label = "작물 거두기", Per = 6 },
	Fish = { Label = "물고기 낚기", Per = 3 },
	Ore = { Label = "광석 캐기", Per = 4 },
	HelpWater = { Label = "친구 밭에 물 주기", Per = 3 },
	Event = { Label = "섬 이벤트 찾기", Per = 1 },
}
local QUEST_KINDS = { "Harvest", "Fish", "Ore", "HelpWater", "Event" }
local QUEST_COINS, QUEST_COINS_PER = 20, 10 -- 의뢰 보상(1명) = 20 + 10 × 인원
local QUEST_REST = 45 -- 의뢰를 마치고 다음 의뢰까지(초)
local CONTESTS = { Fish = { Label = "낚시 대회", Unit = "마리" }, Harvest = { Label = "수확 대회", Unit = "칸" },
	Ore = { Label = "채굴 대회", Unit = "개" } }
local CONTEST_READY, CONTEST_TIME, CONTEST_REST = 3, 120, 60 -- 준비·길이·끝난 뒤 다시 열 때까지(초)
local WIN_COINS, JOIN_COINS = 50, 15
local GREET_REACH, GREET_GAP = 24, 2 -- 인사 거리(스터드)·간격(초)
local HIGH_FIVE_WINDOW, HIGH_FIVE_REST, HIGH_FIVE_COINS = 5, 120, 5

local PartyPlayService = {}
local quests = {} -- [파티 Id] = { Kind, Have, RestUntil? }
local contests = {} -- [파티 Id] = { Kind, Starts, Ends, Scores = { ["UserId"] = n } }
local contestRest = {} -- [파티 Id] = 다시 열 수 있는 서버 시각
local lastGreet = {} -- [보낸 사람] = os.clock()
local greeted = {} -- [보낸 사람] = { To, At }
local highFived = {} -- ["작은Id:큰Id"] = os.clock()
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function toast(player, text)
	Remotes.Feedback:FireClient(player, "Toast", { Text = text })
end

local function banner(members, title, sub)
	for _, member in members do
		Remotes.Feedback:FireClient(member, "Banner", { Title = title, Sub = sub, IconKind = "Friends" })
	end
end

local function partyOf(player)
	local members = PartyService.Members(player)
	local id = player:GetAttribute("PartyId")
	if members and id and #members >= 2 then
		return id, members
	end
	return nil
end

local function newQuest(last)
	local kind
	repeat
		kind = QUEST_KINDS[rng:NextInteger(1, #QUEST_KINDS)]
	until kind ~= last
	return { Kind = kind, Have = 0 }
end

local function need(quest, members)
	return QUESTS[quest.Kind].Per * #members
end

-- 파티원 속성을 지금 상태로 맞춘다(같은 값이면 건드리지 않는다)
local function publish(id, members)
	local quest, contest = quests[id], contests[id]
	local questJson = quest and HttpService:JSONEncode({ Kind = quest.Kind, Label = QUESTS[quest.Kind].Label, Have = quest.Have,
		Need = need(quest, members), RestUntil = quest.RestUntil })
	local contestJson = contest and HttpService:JSONEncode({ Kind = contest.Kind, Label = CONTESTS[contest.Kind].Label,
		Unit = CONTESTS[contest.Kind].Unit, Starts = contest.Starts, Ends = contest.Ends, Scores = contest.Scores })
	for _, member in members do
		if member:GetAttribute("PartyQuest") ~= questJson then
			member:SetAttribute("PartyQuest", questJson)
		end
		if member:GetAttribute("PartyContest") ~= contestJson then
			member:SetAttribute("PartyContest", contestJson)
		end
	end
end

local function finishQuest(id, members, quest)
	local coins = QUEST_COINS + QUEST_COINS_PER * #members
	for _, member in members do
		Inventory.AddCoins(member, coins)
	end
	banner(members, "파티 의뢰 완료!", string.format("%s %d · 모두 +%d 코인", QUESTS[quest.Kind].Label, quest.Have, coins))
	quest.RestUntil = now() + QUEST_REST
end

local function finishContest(id, members, contest)
	contests[id] = nil
	contestRest[id] = now() + CONTEST_REST
	local def = CONTESTS[contest.Kind]
	local top, leader = 0, nil
	for _, member in members do
		local score = contest.Scores[tostring(member.UserId)] or 0
		if score > top then
			top, leader = score, member
		end
	end
	for _, member in members do
		local score = contest.Scores[tostring(member.UserId)] or 0
		local prize = if top > 0 and score == top then WIN_COINS elseif score > 0 then JOIN_COINS else 0
		if prize > 0 then
			Inventory.AddCoins(member, prize)
		end
		local sub = if top == 0 then "아무도 기록이 없어요"
			else string.format("1등 %s · %d%s / 나 %d%s%s", if score == top then "나!" else leader.DisplayName, top, def.Unit, score, def.Unit,
				if prize > 0 then " · +" .. prize .. " 코인" else "")
		Remotes.Feedback:FireClient(member, "Banner", { Title = def.Label .. " 끝!", Sub = sub, IconKind = "Friends" })
	end
end

-- 누른 사람이 한 일 하나(종류: Harvest·Fish·Ore·HelpWater·Event)
function PartyPlayService.Count(player, kind, amount)
	local id, members = partyOf(player)
	if not id then
		return
	end
	amount = amount or 1
	local quest = quests[id]
	if quest and quest.Kind == kind and not quest.RestUntil then
		quest.Have += amount
		if quest.Have >= need(quest, members) then
			finishQuest(id, members, quest)
		end
	end
	local contest, t = contests[id], now()
	if contest and contest.Kind == kind and t >= contest.Starts and t < contest.Ends then
		local key = tostring(player.UserId)
		contest.Scores[key] = (contest.Scores[key] or 0) + amount
	end
	publish(id, members)
end

local function startContest(player, kind)
	local id, members = partyOf(player)
	local t = now()
	if not id or not CONTESTS[kind] then
		return
	elseif members[1] ~= player then
		return toast(player, "파티장만 대회를 열 수 있어요")
	elseif contests[id] then
		return toast(player, "이미 대회 중이에요")
	elseif t < (contestRest[id] or 0) then
		return toast(player, string.format("다음 대회는 %d초 뒤에 열 수 있어요", math.ceil(contestRest[id] - t)))
	end
	contests[id] = { Kind = kind, Starts = t + CONTEST_READY, Ends = t + CONTEST_READY + CONTEST_TIME, Scores = {} }
	banner(members, CONTESTS[kind].Label .. "!", string.format("%d초 뒤 시작 · %d분 동안 가장 많이 하면 1등", CONTEST_READY, CONTEST_TIME / 60))
	publish(id, members)
end

local function greet(player, target)
	local from = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local to = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local clock = os.clock()
	if target == player or not from or not to or (from.Position - to.Position).Magnitude > GREET_REACH
		or clock - (lastGreet[player] or 0) < GREET_GAP then
		return
	end
	lastGreet[player] = clock
	local back = greeted[target]
	if back and back.To == player and clock - back.At <= HIGH_FIVE_WINDOW then
		greeted[target] = nil
		local key = string.format("%d:%d", math.min(player.UserId, target.UserId), math.max(player.UserId, target.UserId))
		local paid = clock - (highFived[key] or -math.huge) >= HIGH_FIVE_REST and DataService.Get(player) ~= nil and DataService.Get(target) ~= nil
		if paid then
			highFived[key] = clock
			Inventory.AddCoins(player, HIGH_FIVE_COINS)
			Inventory.AddCoins(target, HIGH_FIVE_COINS)
		end
		Remotes.Feedback:FireAllClients("HighFive", { Player = player, Target = target, Coins = if paid then HIGH_FIVE_COINS else nil,
			Text = "하이파이브!" .. (if paid then " +" .. HIGH_FIVE_COINS else ""), Position = (from.Position + to.Position) / 2 + Vector3.new(0, 2, 0) })
		return
	end
	greeted[player] = { To = target, At = clock }
	Remotes.Feedback:FireAllClients("Greet", { Player = player, Target = target, Text = "안녕!", Position = from.Position + Vector3.new(0, 3.5, 0) })
	toast(target, player.DisplayName .. "님이 손을 흔들었어요 · 마주 인사하면 하이파이브!")
end

function PartyPlayService.Unload(player)
	lastGreet[player] = nil
	greeted[player] = nil
end

-- 1초마다: 파티 구성에 맞춰 의뢰를 만들고·쉬는 의뢰를 새로 하고·끝난 대회를 정리하고, 파티 밖 사람의 속성을 지운다
local function tick()
	local t = now()
	local seen = {}
	for _, player in Players:GetPlayers() do
		local id, members = partyOf(player)
		if not id then
			player:SetAttribute("PartyQuest", nil)
			player:SetAttribute("PartyContest", nil)
		elseif not seen[id] then
			seen[id] = true
			local quest = quests[id]
			if not quest or (quest.RestUntil and t >= quest.RestUntil) then
				quests[id] = newQuest(quest and quest.Kind)
			end
			local contest = contests[id]
			if contest and t >= contest.Ends then
				finishContest(id, members, contest)
			end
			publish(id, members)
		end
	end
	for id in quests do
		if not seen[id] then
			quests[id], contests[id], contestRest[id] = nil, nil, nil -- 파티가 사라졌다(대회 보상 없음)
		end
	end
end

function PartyPlayService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target, arg)
		if kind == "Contest" then
			startContest(player, arg)
		elseif kind == "Greet" and typeof(target) == "Instance" and target:IsA("Player") then
			greet(player, target)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

PartyPlayService._tick = tick -- 검사용(tests/party_play_logic.luau)

return PartyPlayService

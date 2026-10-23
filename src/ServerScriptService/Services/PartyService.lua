-- 파티·섬 방문(같은 서버). 파티는 서버 메모리에만 두고 PartyId·PartyLeader 속성으로 모두에게 보인다(1번 = 파티장).
-- 방문: 주인 설정 VisitParty가 켜져 있으면 같은 파티만. 처음 간 섬의 컨셉은 방문자 도감 "섬"에 남는다.
-- 남의 밭 권한(Same·CanHarvest)은 FarmService가 부른다. 표는 design/gdd/party-visiting.md.
-- ponytail: 다른 서버 친구 초대(SocialService:PromptGameInvite + TeleportService + ReserveServer)는 publish 뒤에 붙인다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local IslandService = require(script.Parent.IslandService)

local MAX = 6 -- 파티 인원(서버 최대 인원과 맞춘다)
local INVITE_TTL = 30 -- 초대 카드가 떠 있는 초
local INVITE_COOLDOWN = 3 -- 초대 연타 막기(초)

local PartyService = {}
local partyOf = {} -- [player] = { Id, Members = { player … } }(들어온 순서)
local invites = {} -- [받는 사람] = { From, At }
local lastInvite = {} -- [보낸 사람] = os.clock()

local function toast(player, text)
	Remotes.Feedback:FireClient(player, "Toast", { Text = text })
end

local function setting(owner, key)
	local profile = DataService.Get(owner)
	return profile ~= nil and profile.Settings[key] == true
end

local function publish(party)
	for i, member in party.Members do
		member:SetAttribute("PartyId", party.Id)
		member:SetAttribute("PartyLeader", i == 1)
	end
end

local function drop(player)
	partyOf[player] = nil
	player:SetAttribute("PartyId", nil)
	player:SetAttribute("PartyLeader", nil)
end

function PartyService.Same(a, b)
	return a == b or (partyOf[a] ~= nil and partyOf[a] == partyOf[b])
end

-- 남의 밭 수확: 같은 파티이고 주인이 "파티원 수확"을 켰을 때
function PartyService.CanHarvest(player, owner)
	return player == owner or (PartyService.Same(player, owner) and setting(owner, "HarvestParty"))
end

local function leave(player)
	local party = partyOf[player]
	if not party then
		return
	end
	drop(player)
	table.remove(party.Members, table.find(party.Members, player))
	if #party.Members == 1 then
		drop(party.Members[1])
		toast(party.Members[1], "파티가 끝났어요")
		return
	end
	publish(party) -- 파티장이 나갔으면 가장 먼저 들어온 사람이 1번이 된다
	for _, member in party.Members do
		toast(member, player.DisplayName .. "님이 파티를 나갔어요")
	end
end

local function visit(player, owner)
	local record = owner.Parent == Players and IslandService.Get(owner)
	if not DataService.Get(player) then
		return
	elseif not record then
		return toast(player, "섬을 준비하는 중이에요")
	elseif owner == player then
		return IslandService.MoveTo(player, record)
	elseif setting(owner, "VisitParty") and not PartyService.Same(player, owner) then
		return toast(player, owner.DisplayName .. "님 섬은 파티원만 놀러 갈 수 있어요")
	end
	IslandService.MoveTo(player, record)
	DexService.Record(player, "Islands", record.Concept)
	toast(owner, player.DisplayName .. "님이 놀러 왔어요")
end

local function invite(player, target)
	local now = os.clock()
	if target == player or not DataService.Get(target) or now - (lastInvite[player] or 0) < INVITE_COOLDOWN then
		return
	end
	lastInvite[player] = now
	local party = partyOf[player]
	if partyOf[target] then
		return toast(player, if partyOf[target] == party then "이미 같은 파티예요" else target.DisplayName .. "님은 다른 파티에 있어요")
	elseif party and #party.Members >= MAX then
		return toast(player, "파티가 가득 찼어요(" .. MAX .. "명)")
	end
	invites[target] = { From = player, At = now }
	Remotes.Feedback:FireClient(target, "Invite", { From = player, Ttl = INVITE_TTL })
	toast(player, target.DisplayName .. "님에게 초대를 보냈어요")
end

local function answer(player, from, accept)
	local pending = invites[player]
	if not pending or pending.From ~= from then
		return
	end
	invites[player] = nil
	if not accept then
		toast(from, player.DisplayName .. "님이 초대를 거절했어요")
		return
	end
	local party = partyOf[from]
	if os.clock() - pending.At > INVITE_TTL + 2 or from.Parent ~= Players or partyOf[player] or (party and #party.Members >= MAX) then
		return toast(player, "파티에 들어갈 수 없어요")
	end
	if not party then
		party = { Id = HttpService:GenerateGUID(false), Members = { from } }
		partyOf[from] = party
	end
	table.insert(party.Members, player)
	partyOf[player] = party
	publish(party)
	for _, member in party.Members do
		toast(member, player.DisplayName .. "님이 파티에 들어왔어요")
	end
end

function PartyService.Unload(player)
	leave(player)
	invites[player] = nil
	lastInvite[player] = nil
end

function PartyService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target, arg)
		if kind == "Home" then
			visit(player, player)
		elseif kind == "LeaveParty" then
			leave(player)
		elseif typeof(target) ~= "Instance" or not target:IsA("Player") then
			return
		elseif kind == "Visit" then
			visit(player, target)
		elseif kind == "Invite" then
			invite(player, target)
		elseif kind == "Answer" then
			answer(player, target, arg == true)
		end
	end)
end

return PartyService

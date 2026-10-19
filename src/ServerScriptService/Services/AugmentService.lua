-- 증강 추첨, 제시, 선택 검증, 적용. 플레이어마다 개인 선택.
-- 레벨은 플레이어 Attribute "Aug_<id>"로도 내보내 HUD가 읽는다. 중간에 들어온 플레이어는 놓친 선택을 몰아서 받는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AugmentData = require(ReplicatedStorage.Shared.AugmentData)
local PlayerService = require(script.Parent.PlayerService)

local AugmentService = {}
local offers = {} -- [player] = { Ids = {...}, Day = number }
local owned = {} -- [player] = { [id] = stack }
local rerolls = {} -- [player] = 남은 새로고침 횟수
local catchUp = {} -- [player] = { Left = 이번 것 다음에 더 받을 수, Day = number }
local present

local function rollRarity(odds)
	local r = math.random()
	if r < odds.Prism then
		return "Prism"
	elseif r < odds.Prism + odds.Gold then
		return "Gold"
	end
	return "Silver"
end

local function available(player, rarity, used)
	local pool = {}
	local mine = owned[player]
	for id, data in AugmentData do
		local stack = mine[id] or 0
		if (rarity == nil or data.Rarity == rarity) and stack < data.MaxStack and not used[id] then
			table.insert(pool, id)
		end
	end
	return pool
end

local function rollOffer(player, day)
	local late = day >= 50 or day % Config.Wave.BossEvery == 0
	local odds = late and Config.Augment.LateOdds or Config.Augment.Odds
	local picks, used = {}, {}
	for _ = 1, 3 do
		local pool = available(player, rollRarity(odds), used)
		if #pool == 0 then
			pool = available(player, nil, used)
		end
		if #pool == 0 then
			break
		end
		local id = pool[math.random(#pool)]
		used[id] = true
		table.insert(picks, id)
	end
	return picks
end

local function grant(player, id)
	offers[player] = nil
	owned[player][id] = (owned[player][id] or 0) + 1
	player:SetAttribute("Aug_" .. id, owned[player][id])
	AugmentData[id].Apply(player)
	PlayerService.ApplyCharacterStats(player)
	Remotes.AugmentClosed:FireClient(player, id)

	local pending = catchUp[player]
	if pending and pending.Left > 0 then
		pending.Left -= 1
		task.delay(1, present, player, pending.Day)
	else
		catchUp[player] = nil
	end
end

local function prepare(player)
	owned[player] = owned[player] or {}
	if rerolls[player] == nil then
		rerolls[player] = Config.Augment.Rerolls
	end
end

function present(player, day)
	if not player.Parent then
		return
	end
	local picks = rollOffer(player, day)
	if #picks == 0 then
		return
	end
	local offer = { Ids = picks, Day = day }
	offers[player] = offer
	Remotes.AugmentOffer:FireClient(player, picks, Config.Augment.PickTime, rerolls[player])

	-- 시간 초과 시 무작위 선택
	task.delay(Config.Augment.PickTime, function()
		if offers[player] == offer and player.Parent then
			grant(player, picks[math.random(#picks)])
		end
	end)
end

function AugmentService.Offer(day)
	for _, player in Players:GetPlayers() do
		prepare(player)
		present(player, day)
	end
end

-- day에 판에 들어온 플레이어에게 그 전까지 지나간 증강 선택 횟수만큼 차례로 고르게 한다. 놓친 횟수를 돌려준다.
function AugmentService.CatchUp(player, day)
	local missed = (day - 1) // Config.Augment.EveryDays
	if missed <= 0 then
		return 0
	end
	prepare(player)
	catchUp[player] = { Left = missed - 1, Day = day }
	present(player, day)
	return missed
end

function AugmentService.Reset()
	table.clear(offers)
	table.clear(owned)
	table.clear(rerolls)
	table.clear(catchUp)
end

-- 이어하기용: 가진 증강(중첩 수)과 남은 새로고침 횟수
function AugmentService.Export(player)
	return { Owned = owned[player] or {}, Rerolls = rerolls[player] }
end

function AugmentService.Import(player, data)
	owned[player] = {}
	for id, stack in data.Owned or {} do
		local augment = AugmentData[id]
		if augment then
			for _ = 1, stack do
				augment.Apply(player)
			end
			owned[player][id] = stack
			player:SetAttribute("Aug_" .. id, stack)
		end
	end
	rerolls[player] = data.Rerolls
	PlayerService.ApplyCharacterStats(player)
end

function AugmentService.Start()
	Remotes.ChooseAugment.OnServerInvoke = function(player, id)
		local offer = offers[player]
		if typeof(id) ~= "string" or not offer or not table.find(offer.Ids, id) then
			return false
		end
		grant(player, id)
		return true
	end

	Remotes.RerollAugment.OnServerInvoke = function(player)
		local offer = offers[player]
		if not offer or (rerolls[player] or 0) <= 0 then
			return false
		end
		rerolls[player] -= 1
		present(player, offer.Day)
		return true
	end

	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
		owned[player] = nil
		rerolls[player] = nil
		catchUp[player] = nil
	end)
end

return AugmentService

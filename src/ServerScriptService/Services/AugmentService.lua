-- 증강 추첨, 제시, 선택 검증, 적용. 플레이어마다 개인 선택.
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
	AugmentData[id].Apply(player)
	PlayerService.ApplyCharacterStats(player)
	Remotes.AugmentClosed:FireClient(player, id)
end

local function present(player, day)
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
		owned[player] = owned[player] or {}
		if rerolls[player] == nil then
			rerolls[player] = Config.Augment.Rerolls
		end
		present(player, day)
	end
end

function AugmentService.Reset()
	table.clear(offers)
	table.clear(owned)
	table.clear(rerolls)
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
	end)
end

return AugmentService

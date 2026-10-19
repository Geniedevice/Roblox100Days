-- 이어하기. 매일 아침 판 전체를 방장 키로 저장하고, 같은 방장이 다시 시작하면 그날부터 이어 한다.
-- 방장 = 비공개 서버 주인, 없으면 판을 시작할 때 가장 먼저 들어와 있던 플레이어.
-- 지거나 100일을 깨면 저장을 지운다. 자원 노드와 좀비는 저장하지 않는다(아침이면 어차피 새로 깔린다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AugmentService = require(script.Parent.AugmentService)
local BaseService = require(script.Parent.BaseService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local DayManager = require(script.Parent.DayManager)

local RunSaveService = {}
local hostKey
local pendingPlayers = {} -- [UserId 문자열] = 아직 접속하지 않은 플레이어의 저장 데이터

local function exportPlayer(player)
	local items = {}
	for item in Config.Items do
		items[item] = player:GetAttribute(item) or 0
	end
	return {
		Items = items,
		Hunger = player:GetAttribute("Hunger"),
		Thirst = player:GetAttribute("Thirst"),
		HasCrossbow = player:GetAttribute("HasCrossbow") == true,
		Augments = AugmentService.Export(player),
	}
end

local function importPlayer(player, data)
	for item, count in data.Items or {} do
		if Config.Items[item] then
			player:SetAttribute(item, count)
		end
	end
	player:SetAttribute("Hunger", data.Hunger)
	player:SetAttribute("Thirst", data.Thirst)
	player:SetAttribute("HasCrossbow", data.HasCrossbow or nil)
	AugmentService.Import(player, data.Augments or {})
	if player.Character then
		CombatService.GiveWeapon(player)
	end
end

-- 판 도중 합류: 저장된 데이터가 있으면 복원, 없으면 놓친 증강 선택을 몰아서 준다.
local function join(player, day)
	local key = tostring(player.UserId)
	local data = pendingPlayers[key]
	if data then
		pendingPlayers[key] = nil
		importPlayer(player, data)
		return
	end
	local missed = AugmentService.CatchUp(player, day)
	if missed > 0 then
		Remotes.GameMessage:FireClient(player, string.format("%d일차 합류! 놓친 증강 %d개를 고르세요", day, missed))
	end
end

-- 저장될 표(숫자·문자열 키만). 테스트에서도 직접 부른다.
function RunSaveService.Snapshot(day)
	local snapshot = { Day = day, Base = BaseService.Export(), Players = {} }
	for _, player in Players:GetPlayers() do
		snapshot.Players[tostring(player.UserId)] = exportPlayer(player)
	end
	return snapshot
end

-- 코어·바리케이드를 되돌리고, 지금 있는 플레이어는 바로, 나중에 들어오는 플레이어는 접속할 때 복원한다.
function RunSaveService.Apply(snapshot)
	BaseService.Import(snapshot.Base)
	table.clear(pendingPlayers)
	for userId, data in snapshot.Players do
		pendingPlayers[userId] = data
	end
	for _, player in Players:GetPlayers() do
		join(player, snapshot.Day)
	end
end

-- 판을 시작할 때 부른다. 저장이 있으면 복원하고 시작 일차를, 없으면 1을 돌려준다.
function RunSaveService.Begin()
	local first = Players:GetPlayers()[1]
	local hostId = game.PrivateServerOwnerId ~= 0 and game.PrivateServerOwnerId or (first and first.UserId)
	hostKey = hostId and ("run_" .. hostId)
	table.clear(pendingPlayers)

	local store = DataService.GetStore()
	if not store or not hostKey then
		return 1
	end
	local ok, snapshot = pcall(store.GetAsync, store, hostKey)
	if not ok then
		warn("[RunSaveService] 불러오기 실패:", snapshot)
		return 1
	end
	if not snapshot then
		return 1
	end
	RunSaveService.Apply(snapshot)
	Remotes.GameMessage:FireAllClients(string.format("%d일차부터 이어서 시작합니다", snapshot.Day))
	return snapshot.Day
end

-- 매일 아침 부른다. 저장은 뒤에서 하고 바로 돌아온다.
function RunSaveService.Save(day)
	local store = DataService.GetStore()
	if not store or not hostKey then
		return
	end
	local snapshot = RunSaveService.Snapshot(day)
	local key = hostKey
	task.spawn(function()
		local ok, err = pcall(store.SetAsync, store, key, snapshot)
		if not ok then
			warn("[RunSaveService] 저장 실패:", err)
		end
	end)
end

-- 판이 끝나면(승리·패배) 저장을 지운다.
function RunSaveService.Clear()
	local store = DataService.GetStore()
	if not store or not hostKey then
		return
	end
	local ok, err = pcall(store.RemoveAsync, store, hostKey)
	if not ok then
		warn("[RunSaveService] 삭제 실패:", err)
	end
end

function RunSaveService.Start()
	Players.PlayerAdded:Connect(function(player)
		if DayManager.Day > 0 then
			Remotes.GameMessage:FireAllClients(player.DisplayName .. "님이 합류했습니다")
			join(player, DayManager.Day)
		end
	end)
end

return RunSaveService

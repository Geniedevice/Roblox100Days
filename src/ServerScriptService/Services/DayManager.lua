-- 일차와 낮/밤 상태를 관리하고 클라이언트에 알린다. 시간 흐름(대기)은 GameLoop가 담당한다.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DayManager = {
	Day = 0,
	IsNight = false,
	PhaseEndsAt = 0,
}

local function setPhase(isNight, length)
	DayManager.IsNight = isNight
	DayManager.PhaseEndsAt = workspace:GetServerTimeNow() + length
	Lighting.ClockTime = isNight and 0 or 14
	Lighting.Brightness = isNight and 0.5 or 2
	Remotes.DayChanged:FireAllClients(DayManager.Day, isNight, DayManager.PhaseEndsAt)
end

function DayManager.StartDay(day)
	DayManager.Day = day
	setPhase(false, Config.DAY_LENGTH)
end

function DayManager.StartNight()
	setPhase(true, Config.NIGHT_LENGTH)
end

function DayManager.Reset()
	DayManager.Day = 0
	DayManager.IsNight = false
	DayManager.PhaseEndsAt = 0
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
end

-- 중간에 들어온 플레이어에게 현재 상태를 보낸다.
function DayManager.SyncPlayer(player)
	if DayManager.Day > 0 then
		Remotes.DayChanged:FireClient(player, DayManager.Day, DayManager.IsNight, DayManager.PhaseEndsAt)
	end
end

return DayManager

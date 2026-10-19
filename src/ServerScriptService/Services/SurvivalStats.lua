-- 배고픔/갈증을 플레이어 Attribute로 관리한다. 0이 되면 체력이 깎인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerService = require(script.Parent.PlayerService)

local SurvivalStats = {}

local function tick(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local s = Config.Survival
	local hungerRate = s.HungerDecay * (1 - math.min(player:GetAttribute("HungerReduction") or 0, 0.8))
	local thirstRate = s.ThirstDecay * (1 - math.min(player:GetAttribute("ThirstReduction") or 0, 0.8))

	local hunger = math.max(0, (player:GetAttribute("Hunger") or s.Max) - hungerRate)
	local thirst = math.max(0, (player:GetAttribute("Thirst") or s.Max) - thirstRate)
	player:SetAttribute("Hunger", hunger)
	player:SetAttribute("Thirst", thirst)

	if hunger <= 0 or thirst <= 0 then
		PlayerService.Damage(player, s.StarveDamage)
	end
end

function SurvivalStats.Add(player, hunger, thirst)
	local max = Config.Survival.Max
	player:SetAttribute("Hunger", math.min(max, (player:GetAttribute("Hunger") or max) + hunger))
	player:SetAttribute("Thirst", math.min(max, (player:GetAttribute("Thirst") or max) + thirst))
end

function SurvivalStats.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
end

return SurvivalStats

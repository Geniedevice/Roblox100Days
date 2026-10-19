-- 모든 좀비를 한 루프에서 갱신한다. 가까운 플레이어를 쫓고, 없으면 기지 코어로 간다.
-- MVP는 직선 이동(MoveTo). 장애물이 많아지면 PathfindingService로 바꾼다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerService = require(script.Parent.PlayerService)
local BaseService = require(script.Parent.BaseService)

local ZombieAI = {}
local lastAttack = setmetatable({}, { __mode = "k" })

local function update(zombie, targets, corePosition, now)
	local root = zombie:FindFirstChild("HumanoidRootPart")
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local bestPlayer, bestPosition = nil, nil
	local bestDistance = Config.ZombieAI.AggroRange
	for _, target in targets do
		local distance = (target.Root.Position - root.Position).Magnitude
		if distance < bestDistance then
			bestPlayer, bestPosition, bestDistance = target.Player, target.Root.Position, distance
		end
	end

	local scale = zombie:GetAttribute("Scale") or 1
	local reach = Config.ZombieAI.AttackRange * scale
	local damage = zombie:GetAttribute("Damage") or 10
	local canAttack = now - (lastAttack[zombie] or 0) >= Config.ZombieAI.AttackCooldown

	if bestPlayer then
		humanoid:MoveTo(bestPosition)
		if bestDistance <= reach and canAttack then
			lastAttack[zombie] = now
			PlayerService.Damage(bestPlayer, damage)
		end
	else
		humanoid:MoveTo(corePosition)
		if (corePosition - root.Position).Magnitude <= reach + 4 and canAttack then
			lastAttack[zombie] = now
			BaseService.Damage(damage)
		end
	end
end

function ZombieAI.Start()
	task.spawn(function()
		while true do
			task.wait(Config.ZombieAI.TickRate)
			local targets = PlayerService.GetAliveCharacters()
			local corePosition = BaseService.GetCorePosition()
			local now = os.clock()
			for _, zombie in CollectionService:GetTagged("Zombie") do
				update(zombie, targets, corePosition, now)
			end
		end
	end)
end

return ZombieAI

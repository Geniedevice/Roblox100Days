-- 증강으로 켜지는 지속 능력.
-- 수호 드론(DroneLevel): 어깨 위에 떠서 DroneInterval마다 가까운 좀비를 쏜다.
-- 치유 오라(HealAura): AuraInterval마다 주변 아군(나 포함)의 체력을 채운다.
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CombatService = require(script.Parent.CombatService)

local Abilities = Config.Abilities
local AbilityService = {}
local drones = {} -- [player] = Part
local lastDrone, lastAura = {}, {}

local function alive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil
end

local function getDrone(player, root)
	local drone = drones[player]
	if drone and drone.Parent == root.Parent then
		return drone
	end
	if drone then
		drone:Destroy()
	end
	drone = Instance.new("Part")
	drone.Name = "Drone"
	drone.Shape = Enum.PartType.Ball
	drone.Size = Vector3.new(0.9, 0.9, 0.9)
	drone.Material = Enum.Material.Neon
	drone.Color = Color3.fromRGB(90, 200, 255)
	drone.CanCollide = false
	drone.CanQuery = false
	drone.CanTouch = false
	drone.Massless = true
	drone.CFrame = root.CFrame * CFrame.new(1.8, 2.6, 0.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = drone
	weld.Parent = drone
	drone.Parent = root.Parent
	drones[player] = drone
	return drone
end

local function removeDrone(player)
	if drones[player] then
		drones[player]:Destroy()
		drones[player] = nil
	end
end

local function droneShoot(player, drone, level)
	local best, bestDistance = nil, Abilities.DroneRange
	for _, zombie in CollectionService:GetTagged("Zombie") do
		local root = zombie:FindFirstChild("HumanoidRootPart")
		local distance = root and (root.Position - drone.Position).Magnitude
		if distance and distance < bestDistance then
			best, bestDistance = zombie, distance
		end
	end
	if best then
		CombatService.Tracer(drone.Position, best.HumanoidRootPart.Position, Color3.fromRGB(90, 200, 255), 0.12, 0.1)
		CombatService.DamageZombie(best, Abilities.DroneDamage * level, player)
	end
end

local function healAround(player, root, level)
	for _, other in Players:GetPlayers() do
		local humanoid, otherRoot = alive(other)
		if humanoid and (otherRoot.Position - root.Position).Magnitude <= Abilities.AuraRadius then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Abilities.AuraHeal * level)
		end
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(110, 255, 140)
	ring.Transparency = 0.6
	ring.Size = Vector3.new(0.2, Abilities.AuraRadius * 2, Abilities.AuraRadius * 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	Debris:AddItem(ring, 0.4)
end

local function update(now)
	for _, player in Players:GetPlayers() do
		local humanoid, root = alive(player)
		local droneLevel = player:GetAttribute("DroneLevel") or 0
		if humanoid and droneLevel > 0 then
			local drone = getDrone(player, root)
			if now - (lastDrone[player] or 0) >= Abilities.DroneInterval then
				lastDrone[player] = now
				droneShoot(player, drone, droneLevel)
			end
		else
			removeDrone(player)
		end

		local aura = player:GetAttribute("HealAura") or 0
		if humanoid and aura > 0 and now - (lastAura[player] or 0) >= Abilities.AuraInterval then
			lastAura[player] = now
			healAround(player, root, aura)
		end
	end
end

function AbilityService.Start()
	Players.PlayerRemoving:Connect(function(player)
		removeDrone(player)
		lastDrone[player], lastAura[player] = nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			update(os.clock())
		end
	end)
end

return AbilityService

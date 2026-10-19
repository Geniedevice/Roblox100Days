-- 플레이어 스폰, 증강 스탯 적용, 피해 처리. 죽으면 다음 날 아침에 부활한다.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AugmentData = require(ReplicatedStorage.Shared.AugmentData)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(script.Parent.CombatService)

local PlayerService = {}

local AUGMENT_ATTRIBUTES = {
	"DamageBonus", "HungerReduction", "ThirstReduction", "SpeedBonus", "DamageReduction",
	"BarricadeBonus", "LifeOnKill", "AttackSpeedBonus", "MaxHealthBonus", "ExplodeDamage",
	"UndyingCharges", "FoodOnKill", "GunDamageBonus", "ClipBonus", "ReloadReduction", "AmmoSaveChance", "Pierce",
	"ExplosiveRounds", "Whirlwind", "Knockback", "ChainLightning", "DroneLevel", "HealAura", "LootBonus",
}

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function PlayerService.ResetAttributes(player)
	for _, attribute in AUGMENT_ATTRIBUTES do
		player:SetAttribute(attribute, nil)
	end
	for id in AugmentData do
		player:SetAttribute("Aug_" .. id, nil) -- 증강 레벨(HUD 표시용)
	end
	for item in Config.Items do
		player:SetAttribute(item, nil)
	end
	for _, attribute in { "HasCrossbow", "HasRifle", "GunClip", "Reloading" } do
		player:SetAttribute(attribute, nil)
	end
	player:SetAttribute("Hunger", Config.Survival.Max)
	player:SetAttribute("Thirst", Config.Survival.Max)
end

function PlayerService.ApplyCharacterStats(player)
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.WalkSpeed = 16 + (player:GetAttribute("SpeedBonus") or 0)

	local maxHealth = 100 + (player:GetAttribute("MaxHealthBonus") or 0)
	local ratio = humanoid.Health / humanoid.MaxHealth
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth * ratio
end

function PlayerService.Damage(player, amount)
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local reduction = math.min(player:GetAttribute("DamageReduction") or 0, 0.6)
	amount *= (1 - reduction)

	if humanoid.Health - amount <= 0 then
		local charges = player:GetAttribute("UndyingCharges") or 0
		if charges > 0 then
			player:SetAttribute("UndyingCharges", charges - 1)
			humanoid.Health = humanoid.MaxHealth * 0.3
			Remotes.GameMessage:FireClient(player, "불굴 발동!")
			return
		end
	end

	humanoid:TakeDamage(amount)
end

-- 아직 캐릭터가 없는 플레이어(스폰 중)는 살아 있는 것으로 본다.
function PlayerService.AnyAlive()
	for _, player in Players:GetPlayers() do
		if not player.Character then
			return true
		end
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.Health > 0 then
			return true
		end
	end
	return false
end

function PlayerService.GetAliveCharacters()
	local result = {}
	for _, player in Players:GetPlayers() do
		local humanoid = getHumanoid(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			table.insert(result, { Player = player, Root = root })
		end
	end
	return result
end

function PlayerService.ReviveAll()
	for _, player in Players:GetPlayers() do
		local humanoid = getHumanoid(player)
		if not humanoid or humanoid.Health <= 0 then
			task.spawn(player.LoadCharacter, player)
		end
	end
end

function PlayerService.ResetAll()
	for _, player in Players:GetPlayers() do
		PlayerService.ResetAttributes(player)
		task.spawn(player.LoadCharacter, player)
	end
end

-- 캐릭터 파츠를 "Players" 충돌 그룹에 넣는다(좀비 무리에 밀려 날아가지 않게, WaveManager가 좀비를 "Zombies"로).
local function setPlayerGroup(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = "Players"
	end
end

local function onCharacterAdded(player, character)
	character:WaitForChild("Humanoid")
	for _, part in character:GetDescendants() do
		setPlayerGroup(part)
	end
	character.DescendantAdded:Connect(setPlayerGroup)
	local min = Config.Survival.RespawnMin
	player:SetAttribute("Hunger", math.max(min, player:GetAttribute("Hunger") or min))
	player:SetAttribute("Thirst", math.max(min, player:GetAttribute("Thirst") or min))
	PlayerService.ApplyCharacterStats(player)
	CombatService.GiveWeapon(player)
end

local function onPlayerAdded(player)
	PlayerService.ResetAttributes(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacter()
end

function PlayerService.Start()
	for _, group in { "Players", "Zombies" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Players", "Zombies", false)
	CombatService.DamagePlayer = PlayerService.Damage -- PvP 피해도 증강(피해 감소·불굴)을 거친다

	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(CombatService.ForgetPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService

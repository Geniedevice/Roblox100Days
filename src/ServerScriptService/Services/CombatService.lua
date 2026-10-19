-- 무기(야구방망이, 석궁, 소총) 지급, 서버 판정 공격(좀비 + PvP), 처치·명중 시 증강 효과 처리.
-- 원거리: 클라이언트가 조준점을 보내면 서버가 장착·쿨다운·탄을 확인하고 레이캐스트로 판정한다.
-- 소총은 탄창(속성 GunClip)을 쓰고, 비면 인벤토리 탄약(Ammo)으로 재장전한다(속성 Reloading 동안).
-- 연출(총구 화염·소리·탄 궤적·피격 불꽃)은 서버가 만들어 모두에게 보이고, 명중 표시는 쏜 사람에게만 보낸다.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CombatService = {}
local lastSwing = {}
local lastShot = {}

local WEAPON_NAME = "야구방망이"
local CROSSBOW_NAME = "석궁"
local RIFLE_NAME = "소총"
local Abilities = Config.Abilities

-- 원거리 무기 이름 → 설정
local RANGED = {
	[CROSSBOW_NAME] = { Stats = Config.Ranged, Color = Color3.fromRGB(255, 220, 120), Width = 0.15 },
	[RIFLE_NAME] = { Stats = Config.Gun, Color = Color3.fromRGB(255, 245, 200), Width = 0.08, UsesAmmo = true, Automatic = true },
}

-- 손에 쥐는 자세. 손잡이 파트는 z축이 긴 막대이고, 메시는 Offset으로 그 축에 맞춰 붙인다.
local GRIPS = {
	-- 클래식 검처럼 세워 쥔다: 손잡이 +z가 위, 손은 가는 쪽 끝(-z), 굵은 쪽(+z)이 위
	[WEAPON_NAME] = { Pos = Vector3.new(0, 0, -1.3), Forward = Vector3.new(0, -1, 0), Right = Vector3.new(1, 0, 0), Up = Vector3.new(0, 0, 1) },
	-- 총처럼 앞으로 겨눈다: 손잡이 -z(활대 쪽)가 정면, 손은 활대 뒤 방아쇠 자리
	[CROSSBOW_NAME] = { Pos = Vector3.new(0, -0.1, 0.5), Forward = Vector3.new(0, 0, -1), Right = Vector3.new(1, 0, 0), Up = Vector3.new(0, 1, 0) },
	-- 키트 AR은 총구(TipAttachment)가 손잡이 +z 쪽이라 180도 돌려 쥔다
	[RIFLE_NAME] = { Pos = Vector3.new(0, 0, 0), Forward = Vector3.new(0, 0, 1), Right = Vector3.new(-1, 0, 0), Up = Vector3.new(0, 1, 0) },
}

-- ServerStorage.WeaponModels/<이름>: 파트 하나(MeshPart) 또는 파트 여러 개가 든 Model.
-- 각 파트의 Offset 속성 = 손잡이 기준 CFrame. 손잡이는 숨기고 이 파트들을 붙인다.
local function attachVisual(tool, handle, template)
	local sources = template:IsA("BasePart") and { template } or template:GetChildren()
	for _, source in sources do
		if source:IsA("BasePart") then
			local visual = source:Clone()
			visual.CFrame = handle.CFrame * (source:GetAttribute("Offset") or CFrame.new())
			visual.Anchored = false
			visual.CanCollide = false
			visual.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = visual
			weld.Parent = visual
			visual.Parent = tool
		end
	end
	handle.Transparency = 1
end

local function createTool(name, size, color)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	local grip = GRIPS[name]
	tool.GripForward = grip.Forward
	tool.GripRight = grip.Right
	tool.GripUp = grip.Up
	tool.GripPos = grip.Pos

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Material = Enum.Material.Wood
	handle.Color = color
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local models = ServerStorage:FindFirstChild("WeaponModels")
	local template = models and models:FindFirstChild(name)
	if template then
		attachVisual(tool, handle, template)
	end
	local ranged = RANGED[name]
	if ranged then
		tool:SetAttribute("Ranged", true) -- 클라이언트가 이 표시로 조준·사격 입력을 붙인다
		tool:SetAttribute("Automatic", ranged.Automatic or nil) -- 누르고 있으면 연사(WeaponFx)
	end
	return tool
end

-- 연출 --------------------------------------------------------------------

-- 두 점 사이 빛줄기(탄 궤적, 번개, 드론 사격)
function CombatService.Tracer(from, to, color, width, life)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local line = Instance.new("Part")
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.Material = Enum.Material.Neon
	line.Color = color
	line.Size = Vector3.new(width, width, length)
	line.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	line.Parent = workspace
	Debris:AddItem(line, life)
end

-- 피격 지점 불꽃
local function burst(position, color)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.25, 0)
	emitter.Lifetime = NumberRange.new(0.15, 0.3)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.6
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(10)
	Debris:AddItem(attachment, 0.6)
end

local function playToolSound(tool, name)
	local sound = tool and tool:FindFirstChild(name, true)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

-- 총구 화염(키트 모델의 MuzzleFlash Beam)을 잠깐 켠다
local function flash(tool)
	local beam = tool:FindFirstChild("MuzzleFlash", true)
	if beam and beam:IsA("Beam") then
		beam.Enabled = true
		task.delay(0.05, function()
			beam.Enabled = false
		end)
	end
end

-- 피해 ----------------------------------------------------------------------

local function explodeAt(position, radius, damage, player)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	task.defer(function()
		for _, zombie in CollectionService:GetTagged("Zombie") do
			local root = zombie:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - position).Magnitude <= radius then
				CombatService.DamageZombie(zombie, damage, player)
			end
		end
	end)
end

local function onKilled(zombie, player)
	if not player then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

	local heal = player:GetAttribute("LifeOnKill") or 0
	if heal > 0 and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
	end

	local food = player:GetAttribute("FoodOnKill") or 0
	if food > 0 then
		local max = Config.Survival.Max
		player:SetAttribute("Hunger", math.min(max, (player:GetAttribute("Hunger") or max) + food))
		player:SetAttribute("Thirst", math.min(max, (player:GetAttribute("Thirst") or max) + food))
	end

	local explodeDamage = player:GetAttribute("ExplodeDamage") or 0
	local root = zombie:FindFirstChild("HumanoidRootPart")
	if explodeDamage > 0 and root then
		explodeAt(root.Position, 10, explodeDamage, player)
	end
end

function CombatService.DamageZombie(zombie, amount, player)
	local humanoid = zombie:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
	if humanoid.Health <= 0 and not zombie:GetAttribute("Dead") then
		zombie:SetAttribute("Dead", true)
		onKilled(zombie, player)
	end
end

-- 연쇄 번개 증강: 직접 맞힌 좀비에서 주변 좀비로 튄다(번개·폭발 피해에서는 다시 튀지 않음)
local function chainLightning(zombie, player)
	local level = player:GetAttribute("ChainLightning") or 0
	local root = zombie:FindFirstChild("HumanoidRootPart")
	if level <= 0 or not root then
		return
	end
	local jumps = 0
	for _, other in CollectionService:GetTagged("Zombie") do
		if jumps >= level + 1 then
			break
		end
		local otherRoot = other ~= zombie and other:FindFirstChild("HumanoidRootPart")
		if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Abilities.ChainRange then
			jumps += 1
			CombatService.Tracer(root.Position, otherRoot.Position, Color3.fromRGB(140, 200, 255), 0.2, 0.15)
			CombatService.DamageZombie(other, Abilities.ChainDamage, player)
		end
	end
end

-- PvP. 상대의 증강(피해 감소·불굴)이 적용되도록 PlayerService.Start가 PlayerService.Damage를 넣어 준다.
CombatService.DamagePlayer = nil

local function hitPlayer(attacker, victim, amount)
	if not Config.PvP.Enabled or victim == attacker or not CombatService.DamagePlayer then
		return false
	end
	local humanoid = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	CombatService.DamagePlayer(victim, amount * Config.PvP.DamageScale)
	if humanoid.Health <= 0 then
		Remotes.GameMessage:FireAllClients(string.format("%s님이 %s님을 쓰러뜨렸습니다", attacker.DisplayName, victim.DisplayName))
	end
	return true
end

-- 근접 ----------------------------------------------------------------------

function CombatService.Swing(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local cooldown = Config.Weapon.Cooldown / (1 + (player:GetAttribute("AttackSpeedBonus") or 0))
	local now = os.clock()
	if now - (lastSwing[player] or 0) < cooldown then
		return
	end
	lastSwing[player] = now

	-- R15는 모든 클라이언트가 크게 휘두르는 동작을 그리고(WeaponFx), R6는 기본 Animate의 베기("toolanim")를 쓴다
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		Remotes.SwingFx:FireAllClients(character)
	else
		local bat = character:FindFirstChild(WEAPON_NAME)
		if bat then
			local anim = Instance.new("StringValue")
			anim.Name = "toolanim"
			anim.Value = "Slash"
			anim.Parent = bat
		end
	end

	local damage = Config.Weapon.Damage * (1 + (player:GetAttribute("DamageBonus") or 0))
	local whirlwind = player:GetAttribute("Whirlwind")
	local knockback = player:GetAttribute("Knockback") or 0
	-- 회전 베기 증강이면 방향과 상관없이 반경 안 전부
	local function inReach(target, range)
		local offset = target.Position - root.Position
		if whirlwind then
			return offset.Magnitude <= math.max(range, Abilities.WhirlwindRange)
		end
		return offset.Magnitude <= range and root.CFrame.LookVector:Dot(offset.Unit) > 0.3
	end

	local hitAny = false
	for _, zombie in CollectionService:GetTagged("Zombie") do
		local zombieRoot = zombie:FindFirstChild("HumanoidRootPart")
		if zombieRoot and inReach(zombieRoot, Config.Weapon.Range + (zombie:GetAttribute("Scale") or 1) * 1.5) then
			hitAny = true
			CombatService.DamageZombie(zombie, damage, player)
			chainLightning(zombie, player)
			if knockback > 0 then
				-- 걷기 제어가 속도를 바로 덮어쓰지 않게 잠깐 PlatformStand로 날린다
				local zombieHumanoid = zombie:FindFirstChildOfClass("Humanoid")
				local away = (zombieRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				zombieHumanoid.PlatformStand = true
				zombieRoot.AssemblyLinearVelocity = away.Unit * Abilities.KnockbackSpeed * knockback + Vector3.new(0, 15, 0)
				task.delay(0.6, function()
					if zombieHumanoid.Parent then
						zombieHumanoid.PlatformStand = false
					end
				end)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and inReach(otherRoot, Config.Weapon.Range + 1.5) then
			hitAny = hitPlayer(player, other, damage) or hitAny
		end
	end
	if hitAny then
		Remotes.HitMarker:FireClient(player)
	end
end

-- 원거리 ----------------------------------------------------------------------

function CombatService.ClipSize(player)
	return Config.Gun.ClipSize + (player:GetAttribute("ClipBonus") or 0)
end

-- 소총 재장전: 탄창이 덜 찼고 탄약이 있으면 재장전 시간 뒤에 채운다.
local function reload(player)
	local clip = player:GetAttribute("GunClip") or 0
	local ammo = player:GetAttribute("Ammo") or 0
	if player:GetAttribute("Reloading") or clip >= CombatService.ClipSize(player) or ammo <= 0 then
		return
	end
	player:SetAttribute("Reloading", true)
	playToolSound(player.Character and player.Character:FindFirstChild(RIFLE_NAME), "Reload")
	local duration = Config.Gun.ReloadTime * (1 - math.min(player:GetAttribute("ReloadReduction") or 0, 0.75))
	task.delay(duration, function()
		if not player.Parent then
			return
		end
		local current = player:GetAttribute("GunClip") or 0
		local take = math.min(CombatService.ClipSize(player) - current, player:GetAttribute("Ammo") or 0)
		player:SetAttribute("Ammo", (player:GetAttribute("Ammo") or 0) - take)
		player:SetAttribute("GunClip", current + take)
		player:SetAttribute("Reloading", nil)
	end)
end

local function shoot(player, target)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and character:FindFirstChildOfClass("Tool")
	local weapon = tool and RANGED[tool.Name]
	if typeof(target) ~= "Vector3" or not root or not humanoid or humanoid.Health <= 0 or not weapon then
		return
	end
	local stats = weapon.Stats

	local cooldown = stats.Cooldown / (1 + (player:GetAttribute("AttackSpeedBonus") or 0))
	local now = os.clock()
	if now - (lastShot[player] or 0) < cooldown then
		return
	end
	if weapon.UsesAmmo then
		local clip = player:GetAttribute("GunClip") or 0
		if player:GetAttribute("Reloading") then
			return
		end
		if clip <= 0 then
			reload(player)
			return
		end
		-- 탄약 절약 증강: 확률로 탄을 쓰지 않는다
		if math.random() >= (player:GetAttribute("AmmoSaveChance") or 0) then
			clip -= 1
			player:SetAttribute("GunClip", clip)
		end
		if clip <= 0 then
			reload(player)
		end
	end
	lastShot[player] = now

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - origin
	if offset.Magnitude < 0.1 then
		return
	end
	local direction = offset.Unit * stats.Range
	local damage = stats.Damage * (1 + (player:GetAttribute("DamageBonus") or 0) + (player:GetAttribute("GunDamageBonus") or 0))
	local pierceLeft = player:GetAttribute("Pierce") or 0

	-- 관통탄 증강이면 맞힌 좀비를 빼고 다시 쏜다
	local exclude = { character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local endPosition, hitAny, hitSomething = origin + direction, false, false
	while true do
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			break
		end
		endPosition, hitSomething = hit.Position, true
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model)
		if model and CollectionService:HasTag(model, "Zombie") then
			hitAny = true
			burst(hit.Position, Color3.fromRGB(150, 20, 20))
			CombatService.DamageZombie(model, damage, player)
			chainLightning(model, player)
			if pierceLeft > 0 then
				pierceLeft -= 1
				table.insert(exclude, model)
				continue
			end
		elseif victim then
			burst(hit.Position, Color3.fromRGB(150, 20, 20))
			hitAny = hitPlayer(player, victim, damage) or hitAny
		else
			burst(hit.Position, Color3.fromRGB(200, 190, 160))
		end
		break
	end

	local explosive = player:GetAttribute("ExplosiveRounds") or 0
	if explosive > 0 and hitSomething then
		explodeAt(endPosition, Abilities.ExplosionRadius, Abilities.ExplosionDamage * explosive, player)
	end

	local muzzle = tool:FindFirstChild("TipAttachment", true)
	CombatService.Tracer(muzzle and muzzle.WorldPosition or origin, endPosition, weapon.Color, weapon.Width, 0.08)
	flash(tool)
	playToolSound(tool, "Fired")
	if hitAny then
		Remotes.HitMarker:FireClient(player)
	end
end

local function hasTool(player, backpack, name)
	local character = player.Character
	return backpack:FindFirstChild(name) or (character and character:FindFirstChild(name))
end

-- 캐릭터가 생길 때마다 부른다. 제작한 무기(Has<Weapon> 속성)는 죽어도 다시 준다.
function CombatService.GiveWeapon(player)
	local backpack = player:WaitForChild("Backpack")
	if not hasTool(player, backpack, WEAPON_NAME) then
		local bat = createTool(WEAPON_NAME, Vector3.new(0.4, 0.4, 3.5), Color3.fromRGB(150, 105, 60))
		bat.Activated:Connect(function()
			CombatService.Swing(player)
		end)
		bat.Parent = backpack
	end
	if player:GetAttribute("HasCrossbow") and not hasTool(player, backpack, CROSSBOW_NAME) then
		createTool(CROSSBOW_NAME, Vector3.new(0.5, 0.5, 2.5), Color3.fromRGB(70, 50, 35)).Parent = backpack
	end
	if player:GetAttribute("HasRifle") and not hasTool(player, backpack, RIFLE_NAME) then
		createTool(RIFLE_NAME, Vector3.new(0.5, 1, 3), Color3.fromRGB(40, 40, 45)).Parent = backpack
	end
end

function CombatService.ForgetPlayer(player)
	lastSwing[player] = nil
	lastShot[player] = nil
end

function CombatService.Start()
	Remotes.Shoot.OnServerEvent:Connect(shoot)
	Remotes.Reload.OnServerEvent:Connect(reload)
end

return CombatService

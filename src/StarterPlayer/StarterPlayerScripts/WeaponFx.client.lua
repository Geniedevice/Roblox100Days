-- 무기 조작과 연출(클라이언트).
-- 근접: 서버가 SwingFx로 알려 주면 그 캐릭터의 오른쪽 어깨를 직접 돌려 크게 휘두른다(Roblox에 큰 휘두르기 공식 애니메이션이 없어서).
-- 원거리(Ranged 표시가 있는 Tool): 클릭/터치 지점으로 사격, Automatic이면 누르고 있는 동안 연사, 쏠 때마다 화면 반동.
-- 조준(우클릭 또는 모바일 "조준" 버튼): 시야 확대, 감도 낮춤, 캐릭터가 카메라 방향을 봄, 소총은 정조준 애니메이션.
-- 소총: 들고 있으면 조준 자세, 재장전 중 재장전 애니메이션(Roblox Endorsed Weapons Kit), R 키/버튼 재장전, 탄 표시.
-- 조준점 커서, 명중 표시와 명중음.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local RIFLE_NAME = "소총"
local DEFAULT_FOV = 70
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- 근접: 크게 휘두르기 ----------------------------------------------------------

-- 휘두르기 자세(어깨 기준, 도): 팔을 앞으로 든 자세 → 머리 위 뒤로 크게 당김 → 몸 앞 대각선 아래로 내려침 → 복귀
local SWING_KEYS = {
	{ T = 0, Pitch = 90, Yaw = 0 },
	{ T = 0.35, Pitch = 165, Yaw = -35 },
	{ T = 0.6, Pitch = 25, Yaw = 30 },
	{ T = 1, Pitch = 90, Yaw = 0 },
}

local function swingPose(t)
	for i = 1, #SWING_KEYS - 1 do
		local a, b = SWING_KEYS[i], SWING_KEYS[i + 1]
		if t <= b.T then
			local u = (t - a.T) / (b.T - a.T)
			u = u * u * (3 - 2 * u) -- 부드럽게
			local pitch = a.Pitch + (b.Pitch - a.Pitch) * u
			local yaw = a.Yaw + (b.Yaw - a.Yaw) * u
			return CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)
		end
	end
	return CFrame.Angles(math.rad(90), 0, 0)
end

Remotes.SwingFx.OnClientEvent:Connect(function(character)
	local arm = character and character:FindFirstChild("RightUpperArm")
	local shoulder = arm and arm:FindFirstChild("RightShoulder")
	if not shoulder then
		return
	end
	local start = os.clock()
	local connection
	-- 애니메이션이 Transform을 쓴 뒤(PreSimulation)에 덮어써야 이 프레임에 적용된다
	connection = RunService.PreSimulation:Connect(function()
		local t = (os.clock() - start) / Config.Weapon.SwingTime
		if t >= 1 or not shoulder.Parent then
			connection:Disconnect()
			return
		end
		shoulder.Transform = swingPose(t)
	end)
end)

-- 상태 ----------------------------------------------------------------------------

local function equippedRanged()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("Ranged") and tool or nil
end

local aiming = false
local recoil = 0 -- 남은 화면 반동(도)

-- 소총 애니메이션
local function animation(id)
	local a = Instance.new("Animation")
	a.AnimationId = id
	return a
end
local animations = {
	Hold = animation(Config.WeaponAnimations.RifleHold),
	Aim = animation(Config.WeaponAnimations.RifleAim),
	Reload = animation(Config.WeaponAnimations.RifleReload),
}
local tracks = {}

local function rifleEquipped()
	local tool = equippedRanged()
	return tool and tool.Name == RIFLE_NAME
end

-- 소총 자세: 조준 중이면 정조준, 아니면 들고 있는 자세
local function updateRiflePose()
	if not tracks.Hold then
		return
	end
	local rifle = rifleEquipped()
	if rifle and aiming then
		tracks.Hold:Stop(0.1)
		if not tracks.Aim.IsPlaying then
			tracks.Aim:Play(0.1)
		end
	elseif rifle then
		tracks.Aim:Stop(0.1)
		if not tracks.Hold.IsPlaying then
			tracks.Hold:Play(0.15)
		end
	else
		tracks.Hold:Stop(0.15)
		tracks.Aim:Stop(0.15)
		tracks.Reload:Stop(0.1)
	end
end

local function setAiming(on)
	local tool = equippedRanged()
	on = on and tool ~= nil
	if on == aiming then
		return
	end
	aiming = on
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = not on
	end
	local fov = on and (Config.Aim.FieldOfView[tool.Name] or 50) or DEFAULT_FOV
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = fov }):Play()
	UserInputService.MouseDeltaSensitivity = on and Config.Aim.Sensitivity or 1
	updateRiflePose()
end

-- 사격 ----------------------------------------------------------------------------

local function fireOnce(tool)
	if tool.Name == RIFLE_NAME and player:GetAttribute("Reloading") then
		return
	end
	Remotes.Shoot:FireServer(mouse.Hit.Position)
	if tool.Name ~= RIFLE_NAME or (player:GetAttribute("GunClip") or 0) > 0 then
		recoil += aiming and 0.35 or 0.8
	end
end

local hooked = setmetatable({}, { __mode = "k" })
local firing = false

local function hookTool(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("Ranged") or hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		if not tool:GetAttribute("Automatic") then
			fireOnce(tool)
			return
		end
		firing = true
		while firing and tool.Parent == player.Character do
			fireOnce(tool)
			task.wait(Config.Gun.Cooldown)
		end
	end)
	tool.Deactivated:Connect(function()
		firing = false
	end)
	tool.Unequipped:Connect(function()
		firing = false
		setAiming(false)
	end)
end

local function onCharacter(character)
	aiming = false
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	for name, a in animations do
		tracks[name] = animator:LoadAnimation(a)
	end
	tracks.Hold.Looped, tracks.Aim.Looped = true, true
	tracks.Hold.Priority, tracks.Aim.Priority = Enum.AnimationPriority.Action, Enum.AnimationPriority.Action
	tracks.Reload.Priority = Enum.AnimationPriority.Action2

	for _, container in { character, player:WaitForChild("Backpack") } do
		container.ChildAdded:Connect(hookTool)
		for _, child in container:GetChildren() do
			hookTool(child)
		end
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			updateRiflePose()
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			updateRiflePose()
		end
	end)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

player:GetAttributeChangedSignal("Reloading"):Connect(function()
	if player:GetAttribute("Reloading") and rifleEquipped() and tracks.Reload then
		tracks.Reload:Play(0.1)
	end
end)

-- 입력: 우클릭 조준, R 재장전 ---------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAiming(true)
	elseif not processed and input.KeyCode == Enum.KeyCode.R and rifleEquipped() then
		Remotes.Reload:FireServer()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		setAiming(false)
	end
end)

-- 화면: 탄 표시, 명중 표시, 모바일 버튼 --------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	for key, value in props do
		l[key] = value
	end
	l.Parent = gui
	return l
end

local ammoLabel = label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.new(0, 260, 0, 30),
	BackgroundColor3 = Color3.fromRGB(20, 20, 26), BackgroundTransparency = 0.3, TextSize = 16, Visible = false,
})
Instance.new("UICorner").Parent = ammoLabel

local hitMarker = label({
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 30, 0, 30), Text = "✕",
	TextColor3 = Color3.fromRGB(255, 80, 80), TextSize = 26, Visible = false,
})

local hitSound = Instance.new("Sound")
hitSound.SoundId = Config.WeaponSounds.Hit
hitSound.Volume = 0.5
hitSound.Parent = SoundService

local markerToken = 0
Remotes.HitMarker.OnClientEvent:Connect(function()
	markerToken += 1
	local token = markerToken
	hitMarker.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	hitMarker.Visible = true
	SoundService:PlayLocalSound(hitSound)
	task.delay(0.12, function()
		if token == markerToken then
			hitMarker.Visible = false
		end
	end)
end)

-- 모바일: 조준(켜고 끄기), 재장전 버튼
local function button(text, position, onPress)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = position
	b.Size = UDim2.new(0, 70, 0, 70)
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	b.BackgroundTransparency = 0.3
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.Text = text
	b.Visible = false
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	b.Activated:Connect(onPress)
	return b
end
local aimButton = button("조준", UDim2.new(1, -110, 1, -170), function()
	setAiming(not aiming)
end)
local reloadButton = button("재장전", UDim2.new(1, -190, 1, -110), function()
	Remotes.Reload:FireServer()
end)

-- 매 프레임: 반동, 조준 중 방향, 커서, 탄 표시 -----------------------------------------------

-- 기본 카메라가 자리를 잡은 뒤에 반동만큼 위로 들어 올린다(줄어들며 원래대로 돌아온다)
RunService:BindToRenderStep("WeaponRecoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if recoil > 0.01 then
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoil), 0, 0)
		recoil *= math.exp(-dt * 14)
	else
		recoil = 0
	end
	-- 조준 중에는 캐릭터가 카메라가 보는 방향을 본다
	local root = aiming and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	local tool = equippedRanged()
	local reloading = player:GetAttribute("Reloading")
	mouse.Icon = tool and (reloading and "rbxasset://textures/GunWaitCursor.png" or "rbxasset://textures/GunCursor.png") or ""
	if aiming and not tool then
		setAiming(false)
	end

	local rifle = tool and tool.Name == RIFLE_NAME
	ammoLabel.Visible = rifle
	if rifle then
		local clipSize = Config.Gun.ClipSize + (player:GetAttribute("ClipBonus") or 0)
		ammoLabel.Text = reloading and "재장전 중..."
			or string.format("소총 %d / %d  ·  탄약 %d  (R 재장전)", player:GetAttribute("GunClip") or 0,
				clipSize, player:GetAttribute("Ammo") or 0)
	end
	aimButton.Visible = touch and tool ~= nil
	aimButton.BackgroundColor3 = aiming and Color3.fromRGB(200, 120, 50) or Color3.fromRGB(20, 20, 26)
	reloadButton.Visible = touch and rifle
end)

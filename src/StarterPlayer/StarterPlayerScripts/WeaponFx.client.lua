-- 무기 연출(클라이언트).
-- 근접: 서버가 SwingFx로 알려 주면 그 캐릭터의 오른쪽 어깨를 직접 돌려 크게 휘두른다(Roblox에 큰 휘두르기 공식 애니메이션이 없어서).
-- 소총: 들고 있는 동안 조준 자세, 재장전(속성 Reloading) 중에는 재장전 애니메이션(Roblox Endorsed Weapons Kit), R 키 재장전, 탄 표시.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local RIFLE_NAME = "소총"

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

local function swing(character)
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
end

Remotes.SwingFx.OnClientEvent:Connect(swing)

-- 소총 애니메이션
local function animation(id)
	local a = Instance.new("Animation")
	a.AnimationId = id
	return a
end
local holdAnimation = animation(Config.WeaponAnimations.RifleHold)
local reloadAnimation = animation(Config.WeaponAnimations.RifleReload)
local holdTrack, reloadTrack

local function loadTracks(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	holdTrack = animator:LoadAnimation(holdAnimation)
	holdTrack.Looped = true
	holdTrack.Priority = Enum.AnimationPriority.Action
	reloadTrack = animator:LoadAnimation(reloadAnimation)
	reloadTrack.Priority = Enum.AnimationPriority.Action2

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == RIFLE_NAME then
			holdTrack:Play(0.15)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child.Name == RIFLE_NAME then
			holdTrack:Stop(0.15)
			reloadTrack:Stop(0.1)
		end
	end)
end

player.CharacterAdded:Connect(loadTracks)
if player.Character then
	task.spawn(loadTracks, player.Character)
end

local function rifleEquipped()
	return player.Character and player.Character:FindFirstChild(RIFLE_NAME) ~= nil
end

player:GetAttributeChangedSignal("Reloading"):Connect(function()
	if player:GetAttribute("Reloading") and rifleEquipped() and reloadTrack then
		reloadTrack:Play(0.1)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.R and rifleEquipped() then
		Remotes.Reload:FireServer()
	end
end)

-- 탄 표시(소총을 든 동안만)
local gui = Instance.new("ScreenGui")
gui.Name = "WeaponHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local ammoLabel = Instance.new("TextLabel")
ammoLabel.AnchorPoint = Vector2.new(0.5, 1)
ammoLabel.Position = UDim2.new(0.5, 0, 1, -80)
ammoLabel.Size = UDim2.new(0, 220, 0, 30)
ammoLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
ammoLabel.BackgroundTransparency = 0.3
ammoLabel.TextColor3 = Color3.new(1, 1, 1)
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 16
ammoLabel.Visible = false
ammoLabel.Parent = gui
Instance.new("UICorner").Parent = ammoLabel

RunService.Heartbeat:Connect(function()
	local equipped = rifleEquipped()
	ammoLabel.Visible = equipped
	if equipped then
		ammoLabel.Text = player:GetAttribute("Reloading") and "재장전 중..."
			or string.format("소총 %d / %d  ·  탄약 %d  (R 재장전)", player:GetAttribute("GunClip") or 0,
				Config.Gun.ClipSize, player:GetAttribute("Ammo") or 0)
	end
end)

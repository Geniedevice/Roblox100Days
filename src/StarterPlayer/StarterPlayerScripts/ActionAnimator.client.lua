-- 행동 애니메이션: 서버 Feedback 신호(Till·Plant·Water·Harvest·Clean·Place·Pickup·MineHit·MineBreak·Cast·Catch·Pet)를 받아 그 플레이어
-- 캐릭터의 관절을 트윈으로 움직이고, 손에 도구를 잠깐 쥐여 준다. 애니메이션 에셋이 필요 없다.
-- 관절 변경은 복제되지 않으므로 모든 클라이언트가 같은 신호로 각자 그린다. 대화가 시작되면 NPC가 손을 흔든다.
-- R15만 움직인다(Motor6D와 새 AnimationConstraint 둘 다, R6은 관절 이름·축이 달라 건너뛴다). 명세: design/gdd/action-animation.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Models = require(ReplicatedStorage.Shared:WaitForChild("Models"))

local player = Players.LocalPlayer
local RANGE = 100 -- 이보다 먼 캐릭터의 동작은 그리지 않는다
local RETURN = 0.15 -- 원래 자세로 돌아가는 시간

-- 단계 = { 초, { 관절 = 회전(도, X 앞뒤 · Z 옆) } }. 팔은 X가 +면 앞으로 들리고, 허리는 X가 -면 앞으로 숙인다.
-- 접촉 단계(도구가 닿는 순간) 다음의 같은 자세 단계 = 히트 스톱(그만큼 멈춘다). 접촉 시각은 FeedbackFx CONTACT와 같다
local WAVE = { 0.2, { Shoulder = Vector3.new(165, 0, -25) } }
local TILL_HIT = { Shoulder = Vector3.new(25, 0, 0), Waist = Vector3.new(-25, 0, 0) }
local PLANT_HIT = { Shoulder = Vector3.new(45, 0, 0), Waist = Vector3.new(-40, 0, 0) }
local HARVEST_HIT = { Shoulder = Vector3.new(125, 0, 0), Waist = Vector3.new(5, 0, 0) }
local PLACE_HIT = { Shoulder = Vector3.new(80, 0, 0), LeftShoulder = Vector3.new(80, 0, 0) }
local MINE_HIT = { Shoulder = Vector3.new(15, 0, 0), Waist = Vector3.new(-20, 0, 0) }
local REEL_HIT = { Shoulder = Vector3.new(150, 0, 10), Waist = Vector3.new(12, 0, 0) }
local ACTIONS = {
	Till = { Tool = "Hoe", Steps = {
		{ 0.2, { Shoulder = Vector3.new(160, 0, 0), Waist = Vector3.new(8, 0, 0) } },
		{ 0.12, TILL_HIT }, { 0.07, TILL_HIT },
	} },
	Plant = { Steps = {
		{ 0.2, PLANT_HIT }, { 0.04, PLANT_HIT }, { 0.15, { Shoulder = Vector3.new(55, 0, 0), Waist = Vector3.new(-40, 0, 0) } },
	} },
	Water = { Tool = "Can", Steps = {
		{ 0.2, { Shoulder = Vector3.new(80, 0, 0) } },
		{ 0.3, { Shoulder = Vector3.new(65, 0, 25) } },
	} },
	Harvest = { Steps = {
		{ 0.18, { Shoulder = Vector3.new(40, 0, 0), Waist = Vector3.new(-35, 0, 0) } },
		{ 0.15, HARVEST_HIT }, { 0.09, HARVEST_HIT },
	} },
	Place = { Steps = { { 0.18, PLACE_HIT }, { 0.06, PLACE_HIT } } },
	-- 광석 치기: 들기 180ms + 내리치기 100ms(접촉 280ms) + 멈춤
	MineHit = { Tool = "Pickaxe", Steps = {
		{ 0.18, { Shoulder = Vector3.new(170, 0, 0), Waist = Vector3.new(10, 0, 0) } },
		{ 0.1, MINE_HIT }, { 0.05, MINE_HIT },
	} },
	MineBreak = { Tool = "Pickaxe", Steps = {
		{ 0.18, { Shoulder = Vector3.new(175, 0, 0), Waist = Vector3.new(12, 0, 0) } },
		{ 0.1, MINE_HIT }, { 0.1, MINE_HIT },
	} },
	-- 던지기: 감기 250ms + 던지기 150ms(낚싯대는 ActivityClient가 쥐여 준다)
	Cast = { Steps = {
		{ 0.25, { Shoulder = Vector3.new(170, 0, -10), Waist = Vector3.new(10, 0, 0) } },
		{ 0.15, { Shoulder = Vector3.new(70, 0, 0), Waist = Vector3.new(-12, 0, 0) } },
	} },
	-- 당기기: 150ms 들어 올림 + 100ms 멈춤(물고기가 물 위로 나온 순간)
	Catch = { Steps = { { 0.15, REEL_HIT }, { 0.1, REEL_HIT } } },
	-- 쓰다듬기: 손을 뻗어 두 번 토닥
	Pet = { Steps = {
		{ 0.2, { Shoulder = Vector3.new(70, 0, 0), Waist = Vector3.new(-20, 0, 0) } },
		{ 0.12, { Shoulder = Vector3.new(55, 0, 0), Waist = Vector3.new(-22, 0, 0) } },
		{ 0.12, { Shoulder = Vector3.new(70, 0, 0), Waist = Vector3.new(-20, 0, 0) } },
		{ 0.12, { Shoulder = Vector3.new(55, 0, 0), Waist = Vector3.new(-22, 0, 0) } },
	} },
	Wave = { Steps = { WAVE, { 0.2, { Shoulder = Vector3.new(165, 0, 15) } }, WAVE } },
}
ACTIONS.Clean = { Steps = { ACTIONS.Harvest.Steps[1], ACTIONS.Harvest.Steps[2], { 0.07, HARVEST_HIT } } }
ACTIONS.Pickup = { Steps = { { 0.18, PLACE_HIT }, { 0.04, PLACE_HIT } } }

local originals = setmetatable({}, { __mode = "k" }) -- [관절] = 처음 C0·CFrame
local playing = setmetatable({}, { __mode = "k" }) -- [캐릭터] = 지금 동작 번호(새 동작이 오면 앞의 것을 끊는다)

local function motors(character)
	-- 움직일 것: Motor6D면 그 자신(C0), 새 아바타 관절 AnimationConstraint면 몸통 쪽 Attachment0(CFrame)
	-- (실측: 2026-10 기본 아바타는 Waist·Shoulder가 모두 AnimationConstraint)
	local function find(partName, motorName)
		local part = character:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(motorName)
		if joint and joint:IsA("Motor6D") then
			return joint
		end
		return joint and joint:IsA("AnimationConstraint") and joint.Attachment0 or nil
	end
	return {
		Shoulder = find("RightUpperArm", "RightShoulder"),
		LeftShoulder = find("LeftUpperArm", "LeftShoulder"),
		Waist = find("UpperTorso", "Waist"),
	}
end

-- 오른손에 잠깐 쥐는 도구(Shared/Models.Tool, 충돌·질량 없음)
local function attachTool(character, kind)
	local hand = character:FindFirstChild("RightHand")
	if not hand then
		return nil
	end
	local model = Models.Tool(kind)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		end
	end
	model:PivotTo(hand.CFrame * CFrame.new(0, -0.3, -0.2))
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hand, model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Name = "ActionTool"
	model.Parent = character
	return model
end

local function play(character, kind)
	local action = ACTIONS[kind]
	local joints = motors(character)
	if not action or not joints.Shoulder then
		return
	end
	local token = (playing[character] or 0) + 1
	playing[character] = token
	local tool = action.Tool and attachTool(character, action.Tool)

	local function poseTo(pose, duration)
		for name, joint in joints do
			local key = if joint:IsA("Motor6D") then "C0" else "CFrame"
			originals[joint] = originals[joint] or joint[key]
			local angles = pose[name] or Vector3.zero
			local goal = originals[joint] * CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
			TweenService:Create(joint, TweenInfo.new(duration, Enum.EasingStyle.Quad), { [key] = goal }):Play()
		end
		task.wait(duration)
		return playing[character] == token and character.Parent ~= nil
	end

	local finished = true
	for _, step in action.Steps do
		if not poseTo(step[2], step[1]) then
			finished = false
			break
		end
	end
	if finished then
		poseTo({}, RETURN)
	end
	if tool then
		tool:Destroy()
	end
end

local function near(position)
	local camera = workspace.CurrentCamera
	return camera and (camera.CFrame.Position - position).Magnitude <= RANGE
end

Remotes.Feedback.OnClientEvent:Connect(function(kind, info)
	local actor = info and info.Player
	local character = actor and actor.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not ACTIONS[kind] or not root or not near(root.Position) then
		return
	end
	-- 내 캐릭터는 대상 쪽으로 돌려세운다(내 캐릭터 위치는 서버로 복제된다)
	if actor == player and info.Position then
		local look = Vector3.new(info.Position.X, root.Position.Y, info.Position.Z)
		if (look - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end
	task.spawn(play, character, kind)
end)

-- 대화가 새로 시작되면(앞 대사가 없을 때) NPC가 손을 흔든다
local talking
Remotes.Dialogue.OnClientEvent:Connect(function(message)
	if message.Close then
		talking = nil
	elseif message.Npc and message.Speaker and talking ~= message.Npc then
		talking = message.Npc
		task.spawn(play, message.Npc, "Wave")
	end
end)

-- 손맛 연출 공용(클라이언트): '7 HIT COMBO' 일곱 요소의 도구 상자. 수치는 design/ux/interaction-patterns.md 표 A·B.
--  1 번쩍임 Flash(월드 Highlight)·Screen(화면 덮개)   2 히트 스톱 = 호출하는 쪽이 접촉 프레임에 멈춤을 넣는다(Hold)
--  3 찌그러짐 Squash(Part)·ScaleModel(Model)·Punch(GUI)   4 카메라 흔들림 Shake·Fov(내 행동에만, 합계 0.8° 이하)
--  5 지연 막대 = Hud(지연 카운터·고스트 막대)   6 타격 이펙트 Burst(입자)·Ring(퍼지는 원판)·Chunks(파편)·Fly(아이콘이 HUD로)
--  7 사운드 Sound(내장 소리, 음높이 ±4%, 40ms 안 같은 소리 막기, 여러 겹은 delay로)
-- "움직임 줄이기"(Setting_ReduceMotion)를 켜면 흔들림·FOV·번쩍임·펀치·날아가기는 0, 입자는 절반. 소리·글자는 그대로.
-- 모듈 하나를 여러 LocalScript가 같이 쓴다: Targets(HUD 도착 칸), Bus(창 열기 신호), State(열린 패널 수)
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local Icons = require(script.Parent:WaitForChild("Icons"))

local player = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local MAX_SHAKE = math.rad(0.8)
local BASE_FOV = 70
local HEAR = 60

local Juice = {
	SPARKLE = SPARKLE,
	SMOKE = SMOKE,
	Targets = {}, -- [이름] = GuiObject, Targets.Item = function(itemId) → GuiObject?
	Bus = {
		ToggleDex = Instance.new("BindableEvent"),
		ToggleDecor = Instance.new("BindableEvent"),
		Combo = Instance.new("BindableEvent"), -- (횟수)
		Banner = Instance.new("BindableEvent"), -- (정보) 확장·새 도감 배너
		Panels = Instance.new("BindableEvent"), -- (열린 패널 수) 대화·상점·도감·설정
		CoinArrive = Instance.new("BindableEvent"), -- 날아간 코인이 코인 알약에 닿았다(숫자를 굴리기 시작)
	},
	State = { Panels = 0, Open = {}, CoinHoldUntil = 0 }, -- 패널이 열려 있으면 흔들지 않는다
}

-- 패널 열림 알리기(name마다 한 번만 센다)
function Juice.SetPanel(name, open)
	Juice.State.Open[name] = if open then true else nil
	local count = 0
	for _ in Juice.State.Open do
		count += 1
	end
	if count ~= Juice.State.Panels then
		Juice.State.Panels = count
		Juice.Bus.Panels:Fire(count)
	end
end

function Juice.Reduced()
	return player:GetAttribute("Setting_ReduceMotion") == true
end

local function tween(object, time, goal, style, direction)
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
Juice.Tween = tween

-- 4 카메라 흔들림: A(t) = A0 · (1 − t/D)² · noise(f·t + seed), 렌더에만(카메라 스크립트 다음)
local shakes = {}
function Juice.Shake(degrees, frequency, duration)
	if Juice.Reduced() or Juice.State.Panels > 0 then
		return
	end
	table.insert(shakes, { A = math.rad(degrees), F = frequency, D = duration, T0 = os.clock(), S = math.random() * 50 + 0.37 })
end
RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 1, function()
	if #shakes == 0 then
		return
	end
	local now = os.clock()
	local pitch, yaw, roll = 0, 0, 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local t = now - s.T0
		if t >= s.D then
			table.remove(shakes, i)
		else
			local a = s.A * (1 - t / s.D) ^ 2
			pitch += a * math.noise(s.F * t, s.S, 0.5) * 2
			yaw += a * math.noise(s.S, s.F * t, 1.5) * 2
			roll += a * math.noise(2.5, s.S, s.F * t)
		end
	end
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles(math.clamp(pitch, -MAX_SHAKE, MAX_SHAKE), math.clamp(yaw, -MAX_SHAKE, MAX_SHAKE), math.clamp(roll, -MAX_SHAKE, MAX_SHAKE))
end)

-- FOV 킥 70 → 70 − k → 70
function Juice.Fov(kick, duration)
	if Juice.Reduced() or Juice.State.Panels > 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local inTween = tween(camera, duration * 0.3, { FieldOfView = BASE_FOV - kick })
	inTween.Completed:Once(function()
		tween(camera, duration * 0.7, { FieldOfView = BASE_FOV }, Enum.EasingStyle.Sine)
	end)
end

-- 1 번쩍임(월드): Highlight 풀 3개의 채움을 start → 1로
local pool, poolIndex = {}, 0
for i = 1, 3 do
	pool[i] = Ui.make("Highlight", workspace, { Name = "JuiceFlash", FillTransparency = 1, OutlineTransparency = 1,
		DepthMode = Enum.HighlightDepthMode.Occluded })
end
function Juice.Flash(adornee, color, start, duration, outlineOnly)
	if Juice.Reduced() or not adornee or not adornee.Parent then
		return
	end
	poolIndex = poolIndex % #pool + 1
	local h = pool[poolIndex]
	h.Adornee = adornee
	h.FillColor, h.OutlineColor = color, color
	h.FillTransparency = if outlineOnly then 1 else start
	h.OutlineTransparency = if outlineOnly then start else 1
	tween(h, duration, { FillTransparency = 1, OutlineTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- 1 번쩍임(화면): 초당 1번 이하, 불투명도 35% 이하
local flashGui = Ui.make("ScreenGui", nil, { Name = "JuiceScreen", IgnoreGuiInset = true, DisplayOrder = 30, ResetOnSpawn = false })
local flashFrame = Ui.make("Frame", flashGui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 })
local lastScreen = 0
function Juice.Screen(color, start, duration)
	if Juice.Reduced() or os.clock() - lastScreen < 1 then
		return
	end
	lastScreen = os.clock()
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = math.max(start, 0.65)
	tween(flashFrame, duration, { BackgroundTransparency = 1 })
end

-- 3 펀치(GUI): 1 → peak → 1
function Juice.Punch(object, peak, duration)
	if Juice.Reduced() or not object then
		return
	end
	local scale = Ui.scale(object)
	scale.Scale = peak
	tween(scale, duration or 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- 3 찌그러짐(Part): 원래 크기 × factor로 갔다가 Back Out으로 돌아온다(바닥은 그대로)
function Juice.Squash(part, factor, inTime, outTime)
	if Juice.Reduced() or not part or not part:IsA("BasePart") then
		return
	end
	local size = part:GetAttribute("JuiceSize") or part.Size
	local cframe = part:GetAttribute("JuiceCFrame") or part.CFrame
	part:SetAttribute("JuiceSize", size)
	part:SetAttribute("JuiceCFrame", cframe)
	local squashed = size * factor
	local down = tween(part, inTime or 0.05, { Size = squashed, CFrame = cframe * CFrame.new(0, (squashed.Y - size.Y) / 2, 0) })
	down.Completed:Once(function()
		local back = tween(part, outTime or 0.12, { Size = size, CFrame = cframe }, Enum.EasingStyle.Back)
		back.Completed:Once(function()
			part:SetAttribute("JuiceSize", nil)
			part:SetAttribute("JuiceCFrame", nil)
		end)
	end)
end

-- 3 크기(Model): 1 → peak → 1 (ScaleTo를 NumberValue 트윈으로)
function Juice.ScaleModel(model, sequence)
	if Juice.Reduced() or not model or not model.Parent then
		return
	end
	local value = Instance.new("NumberValue")
	value.Value = model:GetScale()
	value.Changed:Connect(function(s)
		if model.Parent then
			model:ScaleTo(math.max(s, 0.01))
		end
	end)
	task.spawn(function()
		for _, step in sequence do -- { { 목표 배율, 초, 이징 } }
			local t = tween(value, step[2], { Value = step[1] }, step[3] or Enum.EasingStyle.Quad)
			t.Completed:Wait()
		end
		value:Destroy()
	end)
end

local function anchor(position)
	return Ui.make("Part", workspace, { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.one * 0.2, Position = position })
end
Juice.Anchor = anchor

local function particleScale()
	return if Juice.Reduced() then 0.5 else 1
end

-- 6 입자 한 번: Color(또는 { 색, 색 }), Count, Size, Speed, Life, Gravity, Texture, Glow, Spread
function Juice.Burst(position, spec)
	local part = anchor(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Texture = spec.Texture or SPARKLE
	emitter.Color = if typeof(spec.Color) == "table" then ColorSequence.new(spec.Color[1], spec.Color[2]) else ColorSequence.new(spec.Color)
	emitter.Size = NumberSequence.new(spec.Size or 0.5, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new((spec.Life or 0.7) * 0.7, spec.Life or 0.7)
	emitter.Speed = NumberRange.new((spec.Speed or 8) * 0.6, spec.Speed or 8)
	emitter.SpreadAngle = Vector2.new(spec.Spread or 60, spec.Spread or 60)
	emitter.Acceleration = Vector3.new(0, -(spec.Gravity or 10), 0)
	emitter.LightEmission = spec.Glow or 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = part
	emitter:Emit(math.max(1, math.floor((spec.Count or 10) * particleScale())))
	Debris:AddItem(part, (spec.Life or 0.7) + 0.5)
end

-- 6 퍼지는 원판(충격파): 지름 from → to 스터드, 투명도 0.3 → 1
function Juice.Ring(position, color, from, to, duration)
	local disc = Ui.make("Part", workspace, {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = color, Transparency = 0.3,
		Size = Vector3.new(0.12, from, from), CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tween(disc, duration, { Size = Vector3.new(0.12, to, to), Transparency = 1 })
	Debris:AddItem(disc, duration + 0.1)
end

-- 6 파편: 작은 블록이 튀었다가 사라진다
function Juice.Chunks(position, colors, count, speed, size)
	for i = 1, math.floor(count * particleScale()) do
		local chunk = Ui.make("Part", workspace, {
			Size = Vector3.one * (size or 0.5), CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Color = colors[(i - 1) % #colors + 1], Material = Enum.Material.SmoothPlastic, CanCollide = true, CanTouch = false,
			CanQuery = false, CastShadow = false, Massless = true,
		})
		local dir = Vector3.new(math.random() - 0.5, 0.8 + math.random() * 0.6, math.random() - 0.5).Unit
		chunk.AssemblyLinearVelocity = dir * (speed or 14)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
		tween(chunk, 1.1, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(chunk, 1.2)
	end
end

-- 7 사운드: name은 rbxasset://sounds/ 파일 이름. speed ±4% 무작위, 같은 소리는 40ms 안에 다시 내지 않는다
local lastSound = {}
function Juice.Sound(name, speed, volume, delay, position)
	local function play()
		local now = os.clock()
		if lastSound[name] and now - lastSound[name] < 0.04 then
			return
		end
		lastSound[name] = now
		local s = Instance.new("Sound")
		s.SoundId = "rbxasset://sounds/" .. name
		s.PlaybackSpeed = (speed or 1) * (1 + (math.random() - 0.5) * 0.08)
		s.Volume = (volume or 0.5) * (player:GetAttribute("Setting_Volume") or 1)
		s.RollOffMinDistance, s.RollOffMaxDistance = 10, HEAR
		local holder = if position then anchor(position) else nil
		s.Parent = holder or SoundService
		s:Play()
		Debris:AddItem(holder or s, 3)
	end
	if delay and delay > 0 then
		task.delay(delay, play)
	else
		play()
	end
end

-- 떠오르는 글자(설정으로 끌 수 있다)
function Juice.Float(position, text, color)
	if player:GetAttribute("Setting_FloatText") == false then
		return
	end
	local part = anchor(position)
	local gui = Ui.make("BillboardGui", part, { Size = UDim2.fromOffset(260, 44), AlwaysOnTop = true, LightInfluence = 0 })
	local label = Ui.make("TextLabel", gui, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = Ui.FONT_HEAVY,
		TextSize = 26, TextColor3 = color or Color3.fromRGB(255, 250, 230), Text = text })
	local stroke = Ui.stroke(label, 2.5, Ui.COCOA, true)
	local scale = Ui.make("UIScale", label, { Scale = if Juice.Reduced() then 1 else 0.4 })
	tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8), { Transparency = 1 }):Play()
	Debris:AddItem(part, 1.3)
end

-- 6 아이템이 HUD 칸으로 날아간다: 2차 베지어, 400~650ms Quad In, 1.3 → 0.7배, 180° 회전, 동시에 16개까지
local flyGui = Ui.make("ScreenGui", nil, { Name = "FlyLayer", IgnoreGuiInset = true, DisplayOrder = 20, ResetOnSpawn = false })
local flying = 0
local function targetCenter(target)
	local inset = GuiService:GetGuiInset()
	return target.AbsolutePosition + target.AbsoluteSize / 2 + Vector2.new(0, inset.Y)
end
function Juice.Fly(worldPosition, kind, id, target, onArrive, delay)
	local function arrive()
		if target and target.Parent then
			Juice.Punch(target, 1.2, 0.18)
		end
		if onArrive then
			onArrive()
		end
	end
	if Juice.Reduced() or not target or not target.Parent or flying >= 16 then
		task.delay(0.15, arrive)
		return
	end
	task.delay(delay or 0, function()
		local camera = workspace.CurrentCamera
		local screen, onScreen = camera:WorldToViewportPoint(worldPosition)
		local from = Vector2.new(screen.X, screen.Y)
		if screen.Z < 0 then
			from = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
		elseif not onScreen then
			from = Vector2.new(math.clamp(from.X, 0, camera.ViewportSize.X), math.clamp(from.Y, 0, camera.ViewportSize.Y))
		end
		local to = targetCenter(target)
		local mid = (from + to) / 2
		local normal = Vector2.new(-(to - from).Y, (to - from).X).Unit
		local control = mid + normal * (60 + math.random() * 60) * (if math.random() < 0.5 then -1 else 1) + Vector2.new(0, -80)
		local duration = math.clamp(0.4 + 0.00015 * (to - from).Magnitude, 0.4, 0.65)
		local icon = Icons.View(kind, id, { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y) })
		icon.Parent = flyGui
		flying += 1
		local progress = Instance.new("NumberValue")
		progress.Changed:Connect(function(t)
			local a, b = from:Lerp(control, t), control:Lerp(to, t)
			local p = a:Lerp(b, t)
			icon.Position = UDim2.fromOffset(p.X, p.Y)
			icon.Size = UDim2.fromOffset(48 * (1.3 - 0.6 * t), 48 * (1.3 - 0.6 * t))
			icon.Rotation = 180 * t
		end)
		local t = tween(progress, duration, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Once(function()
			flying -= 1
			icon:Destroy()
			progress:Destroy()
			arrive()
		end)
	end)
end

-- 콤보: 내 행동이 3초 안에 이어지면 +1 (보상 없음, 연출만). Hud가 Bus.Combo로 그린다
local combo, lastAction = 0, 0
function Juice.Combo()
	local now = os.clock()
	combo = if now - lastAction <= 3 then combo + 1 else 1
	lastAction = now
	Juice.Bus.Combo:Fire(combo)
	return combo
end
function Juice.ComboCount()
	return if os.clock() - lastAction <= 3 then combo else 0
end

flashGui.Parent = player:WaitForChild("PlayerGui")
flyGui.Parent = player.PlayerGui

return Juice

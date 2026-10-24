-- 클라이언트 UI 공용: 팔레트·글꼴과 작은 생성 도우미(HUD·도감·꾸미기·대화 창이 같이 쓴다).
-- 스타일: design/ux/ui-research.md §4 — Cream 알약 + Cocoa 테두리, 숫자는 FredokaOne, 한글은 Builder Sans Bold, 글자 14px 이상.
-- 버튼은 누르면 0.9배로 눌렸다가 1.06배로 튀어 돌아온다(interaction-patterns.md "UI 버튼 누르기").
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local Ui = {
	CREAM = rgb(255, 248, 235),
	PARCHMENT = rgb(250, 240, 222),
	PARCHMENT_DEEP = rgb(236, 222, 196),
	COCOA = rgb(110, 78, 52),
	INK = rgb(80, 60, 45),
	MUTED = rgb(115, 95, 78),
	LEAF = rgb(120, 180, 95),
	LEAF_DEEP = rgb(76, 153, 60),
	LEAF_INK = rgb(35, 85, 30),
	SUN = rgb(255, 200, 60),
	GOLD_DEEP = rgb(200, 140, 30),
	BANNER = rgb(255, 230, 150),
	BERRY = rgb(255, 140, 170),
	SKY = rgb(120, 190, 255),
	MINT = rgb(150, 215, 180),
	CORAL = rgb(235, 110, 95),
	GHOST_GAIN = rgb(255, 235, 150),
	GHOST_LOSS = rgb(255, 170, 170),
	WARM = rgb(255, 245, 210),
}
Ui.FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Ui.FONT_HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
Ui.NUM = Font.fromEnum(Enum.Font.FredokaOne)

function Ui.make(className, parent, props)
	local object = Instance.new(className)
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- radius: 픽셀 수, 또는 "pill"(완전히 둥글게)
function Ui.corner(parent, radius)
	return Ui.make("UICorner", parent, { CornerRadius = if radius == "pill" then UDim.new(0.5, 0) else UDim.new(0, radius or 14) })
end

function Ui.stroke(parent, thickness, color, contextual)
	return Ui.make("UIStroke", parent, {
		Thickness = thickness or 3, Color = color or Ui.COCOA, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
	})
end

function Ui.text(parent, text, size, props)
	local label = Ui.make("TextLabel", parent, {
		BackgroundTransparency = 1, Text = text, TextSize = math.max(size, 14), TextColor3 = Ui.INK,
		FontFace = Ui.FONT, TextWrapped = true, Size = UDim2.fromScale(1, 1),
	})
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

-- 크기 펀치용 UIScale(없으면 만든다)
function Ui.scale(object)
	return object:FindFirstChild("JuiceScale") or Ui.make("UIScale", object, { Name = "JuiceScale" })
end

local function pressJuice(button)
	local scale = Ui.scale(button)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 }):Play()
	end)
	local function release()
		local up = TweenService:Create(scale, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 })
		up.Completed:Once(function()
			TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
		end)
		up:Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(function()
		if scale.Scale < 1 then
			release()
		end
	end)
end

-- primary = 주 버튼(Leaf Deep + 흰 글자 + Leaf Ink 글자 테두리), 아니면 Parchment + Ink 글자
function Ui.button(parent, text, props, primary)
	local button = Ui.make("TextButton", parent, {
		BackgroundColor3 = if primary then Ui.LEAF_DEEP else Ui.PARCHMENT, Text = text, TextSize = 16,
		TextColor3 = if primary then Color3.new(1, 1, 1) else Ui.INK, FontFace = Ui.FONT, TextWrapped = true,
		AutoButtonColor = false,
	})
	Ui.corner(button, 16)
	Ui.stroke(button, 3, if primary then Ui.LEAF_INK else Ui.COCOA)
	if primary then
		Ui.make("UIStroke", button, { Thickness = 2, Color = Ui.LEAF_INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
		Ui.make("UIGradient", button, { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.86, 0.86, 0.86)) })
	end
	for key, value in props or {} do
		button[key] = value
	end
	pressJuice(button)
	return button
end

-- 알약(코인·아늑함·도감·토스트): Cream + Cocoa 테두리, 완전히 둥근 모서리
function Ui.pill(parent, props)
	local frame = Ui.make("Frame", parent, { BackgroundColor3 = Ui.CREAM, BackgroundTransparency = 0.03 })
	Ui.corner(frame, "pill")
	Ui.stroke(frame, 3)
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

-- 패널: Cream, 22px 모서리, Cocoa 테두리, 안쪽 여백
function Ui.panel(parent, props)
	local frame = Ui.make("Frame", parent, { BackgroundColor3 = Ui.CREAM })
	Ui.corner(frame, 22)
	Ui.stroke(frame, 3)
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

-- 열기 180ms(페이드 인 + 0.96 → 1, Quint Out) / 닫기 100ms(페이드 아웃 + 1 → 0.97, Quad Out). flat = 크기는 그대로(어두운 막).
-- 페이드는 자손의 투명도 속성을 기억해 두고 섞는다(CanvasGroup은 바깥 UIStroke 테두리를 잘라서 쓰지 않는다).
-- 움직임 줄이기를 켜면 크기는 바꾸지 않고 페이드만 한다. 열고 닫는 도중에 반대로 부르면 그 자리에서 되돌아간다.
local FADE = {
	{ "GuiObject", "BackgroundTransparency" }, { "TextLabel", "TextTransparency" }, { "TextLabel", "TextStrokeTransparency" },
	{ "TextButton", "TextTransparency" }, { "TextButton", "TextStrokeTransparency" }, { "TextBox", "TextTransparency" },
	{ "ImageLabel", "ImageTransparency" }, { "ImageButton", "ImageTransparency" }, { "ViewportFrame", "ImageTransparency" },
	{ "UIStroke", "Transparency" },
}
local motion = setmetatable({}, { __mode = "k" }) -- [frame] = { Value(0 보임 ~ 1 안 보임), Base, Tweens, Closing }

local function snapshot(frame)
	local base = {}
	local function add(object)
		for _, entry in FADE do
			if object:IsA(entry[1]) then
				table.insert(base, { object, entry[2], object[entry[2]] })
			end
		end
	end
	add(frame)
	for _, object in frame:GetDescendants() do
		add(object)
	end
	return base
end

local function animate(frame, show, flat)
	local state = motion[frame]
	if not state then
		state = { Value = Instance.new("NumberValue") }
		state.Value.Changed:Connect(function(t)
			for _, e in state.Base or {} do
				e[1][e[2]] = e[3] + (1 - e[3]) * t
			end
		end)
		motion[frame] = state
	end
	if state.Tweens and state.Closing == not show then
		return -- 이미 그쪽으로 가는 중
	elseif state.Tweens then -- 반대로 가는 도중: 기억한 원래 값에서 이어 간다
		for _, tween in state.Tweens do
			tween:Cancel()
		end
	elseif show and frame.Visible then
		return -- 이미 열려 있다
	elseif not show and not frame.Visible then
		return
	else
		state.Base = snapshot(frame)
		state.Value.Value = if show then 1 else 0
	end
	state.Closing = not show
	local still = flat or player:GetAttribute("Setting_ReduceMotion") == true
	local scale = not flat and Ui.scale(frame)
	if show and scale and not state.Tweens then
		scale.Scale = if still then 1 else 0.96
	end
	frame.Visible = true
	local info = if show then TweenInfo.new(0.18, Enum.EasingStyle.Quint) else TweenInfo.new(0.1, Enum.EasingStyle.Quad)
	local tweens = { TweenService:Create(state.Value, info, { Value = if show then 0 else 1 }) }
	if scale then
		table.insert(tweens, TweenService:Create(scale, info, { Scale = if show or still then 1 else 0.97 }))
	end
	state.Tweens = tweens
	tweens[1].Completed:Once(function(status)
		if status ~= Enum.PlaybackState.Completed then
			return
		end
		state.Tweens = nil
		if not show then
			frame.Visible = false
			state.Value.Value = 0 -- 원래 값으로 돌려놓고 숨긴다(다음에 열 때 기억할 값)
			if scale then
				scale.Scale = 1
			end
		end
	end)
	for _, tween in tweens do
		tween:Play()
	end
end

function Ui.open(frame, flat)
	animate(frame, true, flat)
end
function Ui.close(frame, flat)
	animate(frame, false, flat)
end
-- 열려 있거나 열리는 중(닫히는 중이면 false)
function Ui.IsOpen(frame)
	local state = motion[frame]
	return frame.Visible and not (state and state.Closing and state.Tweens)
end

return Ui

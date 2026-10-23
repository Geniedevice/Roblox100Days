-- 클라이언트 UI 공용: 팔레트·글꼴과 작은 생성 도우미(HUD·도감·꾸미기·대화 창이 같이 쓴다).
-- 스타일: design/ux/ui-research.md §4 — Cream 알약 + Cocoa 테두리, 숫자는 FredokaOne, 한글은 Builder Sans Bold, 글자 14px 이상.
-- 버튼은 누르면 0.9배로 눌렸다가 1.06배로 튀어 돌아온다(interaction-patterns.md "UI 버튼 누르기").
local TweenService = game:GetService("TweenService")

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

-- 열기(0.9 → 1.03 → 1, 220ms Back Out) / 닫기(150ms Quad In)
function Ui.open(frame)
	local scale = Ui.scale(frame)
	scale.Scale = 0.9
	frame.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
function Ui.close(frame)
	local scale = Ui.scale(frame)
	local tween = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
	tween.Completed:Once(function()
		if scale.Scale <= 0.86 then
			frame.Visible = false
			scale.Scale = 1
		end
	end)
	tween:Play()
end

return Ui

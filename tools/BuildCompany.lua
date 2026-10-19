-- 로비 컴퍼니 생성기. Studio 편집 모드에서 실행: loadstring(src)(Config.Company.Origin). 다시 실행하면 새로 만든다.
-- 만드는 것: Workspace.Company(격납고 바닥·벽·지붕·조명, Terminal = 상점 단말기, Lever = 출발 레버, 회사 간판),
-- SpawnLocation을 격납고 가운데로 옮긴다. 프롬프트는 CompanyService가 단다.
local ORIGIN = ... or Vector3.new(0, 0, -2500)
local W, D, H = 90, 70, 26 -- 격납고 폭(X), 깊이(Z), 높이

local old = workspace:FindFirstChild("Company")
if old then
	old:Destroy()
end
local company = Instance.new("Model")
company.Name = "Company"
company.WorldPivot = CFrame.new()
company.Parent = workspace

local function part(size, position, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		p[key] = value
	end
	p.Parent = company
	return p
end

local STEEL = Color3.fromRGB(70, 75, 82)
local TRIM = Color3.fromRGB(230, 170, 40)

-- 바닥, 벽(앞쪽은 큰 출입문 모양으로 트임), 지붕
part(Vector3.new(W, 2, D), Vector3.new(0, -1, 0), Color3.fromRGB(95, 98, 104), Enum.Material.DiamondPlate).Name = "Floor"
part(Vector3.new(W, H, 2), Vector3.new(0, H / 2, -D / 2), STEEL, Enum.Material.CorrodedMetal)
for _, sx in { -1, 1 } do
	part(Vector3.new(2, H, D), Vector3.new(sx * W / 2, H / 2, 0), STEEL, Enum.Material.CorrodedMetal)
	part(Vector3.new(W / 2 - 15, H, 2), Vector3.new(sx * (W / 4 + 7.5), H / 2, D / 2), STEEL, Enum.Material.CorrodedMetal)
end
part(Vector3.new(30, H - 18, 2), Vector3.new(0, 18 + (H - 18) / 2, D / 2), STEEL, Enum.Material.CorrodedMetal)
part(Vector3.new(30, 18, 1), Vector3.new(0, 9, D / 2 + 0.6), Color3.fromRGB(40, 40, 44), Enum.Material.Metal) -- 닫힌 셔터
part(Vector3.new(W, 1, D), Vector3.new(0, H + 0.5, 0), Color3.fromRGB(55, 58, 64), Enum.Material.Metal)

-- 노란 안전선과 천장 조명
for _, sz in { -1, 1 } do
	part(Vector3.new(W - 6, 0.05, 0.8), Vector3.new(0, 0.03, sz * (D / 2 - 6)), TRIM, Enum.Material.SmoothPlastic, { CanCollide = false })
end
for _, x in { -25, 0, 25 } do
	for _, z in { -18, 18 } do
		local lamp = part(Vector3.new(6, 0.4, 2), Vector3.new(x, H - 0.3, z), Color3.fromRGB(255, 245, 220), Enum.Material.Neon, { CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.5
		light.Parent = lamp
	end
end

-- 간판
local sign = part(Vector3.new(40, 6, 1), Vector3.new(0, H - 6, -D / 2 + 1.5), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 30
gui.Parent = sign
local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.TextColor3 = TRIM
text.Font = Enum.Font.GothamBlack
text.TextScaled = true
text.Text = "로비 컴퍼니 — 100일 생존 탐사"
text.Parent = gui

-- 상점 단말기(왼쪽 벽 앞)
local terminal = part(Vector3.new(4, 5, 2), Vector3.new(-20, 2.5, -D / 2 + 4), Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
terminal.Name = "Terminal"
part(Vector3.new(3.2, 2.2, 0.2), Vector3.new(-20, 3.6, -D / 2 + 5.05), Color3.fromRGB(60, 200, 120), Enum.Material.Neon, { CanCollide = false })

-- 출발 레버(오른쪽 벽 앞)
part(Vector3.new(3, 4, 3), Vector3.new(20, 2, -D / 2 + 4), Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
local lever = part(Vector3.new(0.6, 3, 0.6), Vector3.new(20, 5.5, -D / 2 + 4), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic)
lever.Name = "Lever"

company:PivotTo(CFrame.new(ORIGIN))

local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	spawn.CFrame = CFrame.new(ORIGIN + Vector3.new(0, spawn.Size.Y / 2, 10))
end
return "company built at " .. tostring(ORIGIN)

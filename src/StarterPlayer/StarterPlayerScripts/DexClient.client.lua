-- 도감 창: HUD 오른쪽 기둥 "도감"(또는 B) → 분류 탭 6개(작물·물고기·광석·생물·가구·섬)와 3D 아이콘 카드 격자.
-- 내용은 서버가 보낸다(Remotes.Dex). 못 만난 칸은 검은 실루엣 + "?" + 힌트. 새로 기록되면(DexVersion) 열린 창을 다시 그리고,
-- 처음 연 새 카드는 한 바퀴 돈다. 명세: design/gdd/collection-dex.md, design/ux/interaction-patterns.md "Grid Item"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Juice = require(script.Parent:WaitForChild("Juice"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer
local KIND = { Crops = "Crop", Fish = "Fish", Ores = "Ore", Creatures = "Creature", Furniture = "Furniture", Islands = "Island" }

local gui = Ui.make("ScreenGui", nil, { Name = "Dex", ResetOnSpawn = false, DisplayOrder = 6 })
local dim = Ui.make("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.65,
	Visible = false, BorderSizePixel = 0 })
local panel = Ui.panel(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.94, 0.84),
	Visible = false })
Ui.make("UISizeConstraint", panel, { MaxSize = Vector2.new(760, 520) })
local bookIcon = Icons.View("Book", nil, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(14, 6) })
bookIcon.Parent = panel
local title = Ui.text(panel, "도감", 22, { FontFace = Ui.FONT_HEAVY, Position = UDim2.fromOffset(60, 10), Size = UDim2.new(1, -130, 0, 32),
	TextXAlignment = Enum.TextXAlignment.Left })
local closeButton = Ui.button(panel, "×", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(44, 44), TextSize = 24 })

local tabs = Ui.make("ScrollingFrame", panel, { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 50), BackgroundTransparency = 1,
	ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X })
Ui.make("UIListLayout", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center })
Ui.make("UIPadding", tabs, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) })

local grid = Ui.make("ScrollingFrame", panel, { Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 1, -124), BackgroundTransparency = 1,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
Ui.make("UIGridLayout", grid, { CellSize = UDim2.fromOffset(134, 178), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center })
Ui.make("UIPadding", grid, { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) })

local current = "Crops"
local data = {}
local seen = {} -- [분류.Id] = 이미 본 칸(새 카드만 돈다)

local function clear(container)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function render()
	clear(tabs)
	clear(grid)
	local found, total = 0, 0
	for i, category in data do
		found += category.Found
		total += category.Total
		local selected = category.Id == current
		local tab = Ui.button(tabs, string.format("%s %d/%d", category.Name, category.Found, category.Total), {
			LayoutOrder = i, Size = UDim2.fromOffset(128, 40), TextSize = 15,
			BackgroundColor3 = if selected then Ui.LEAF_DEEP else Ui.PARCHMENT, TextColor3 = if selected then Color3.new(1, 1, 1) else Ui.INK,
		})
		if selected then
			Ui.make("UIStroke", tab, { Thickness = 2, Color = Ui.LEAF_INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
		end
		tab.Activated:Connect(function()
			current = category.Id
			render()
		end)
		if selected then
			for order, entry in category.Entries do
				local card = Ui.make("Frame", grid, { LayoutOrder = order, BackgroundColor3 = if entry.Found then Ui.PARCHMENT else Ui.PARCHMENT_DEEP })
				Ui.corner(card, 14)
				Ui.stroke(card, 2.5)
				local icon = Icons.View(KIND[category.Id], entry.Id, { Size = UDim2.fromOffset(78, 78), AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 6), Silhouette = not entry.Found })
				icon.Parent = card
				if not entry.Found then
					local q = Ui.make("Frame", card, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, 40, 0, 56), Size = UDim2.fromOffset(28, 28),
						BackgroundColor3 = Ui.CREAM })
					Ui.corner(q, "pill")
					Ui.stroke(q, 2)
					Ui.text(q, "?", 18, { FontFace = Ui.NUM })
				end
				Ui.text(card, entry.Name, 15, { Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, -8, 0, 20), TextWrapped = false,
					TextTruncate = Enum.TextTruncate.AtEnd })
				if entry.Found then
					Ui.text(card, "×" .. entry.Count, 14, { FontFace = Ui.NUM, Position = UDim2.fromOffset(4, 106), Size = UDim2.new(1, -8, 0, 16),
						TextColor3 = Ui.MUTED })
				end
				Ui.text(card, entry.Desc, 14, { Position = UDim2.fromOffset(6, 124), Size = UDim2.new(1, -12, 1, -128), TextColor3 = Ui.MUTED,
					TextYAlignment = Enum.TextYAlignment.Top, TextScaled = true })
				local key = category.Id .. "." .. entry.Id
				if entry.Found and seen[key] == false then
					-- 새로 찾은 카드: 한 바퀴 돌며 등장
					local scale = Ui.scale(card)
					scale.Scale = 0.6
					Juice.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
					card.Rotation = -12
					Juice.Tween(card, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)
				end
				seen[key] = entry.Found
			end
		end
	end
	title.Text = string.format("도감  %d / %d", found, total)
end

local function refresh()
	local ok, result = pcall(Remotes.Dex.InvokeServer, Remotes.Dex)
	if ok and type(result) == "table" then
		data = result
		render()
	end
end

local function setOpen(open)
	if open then
		Ui.open(dim, true)
		Ui.open(panel)
		refresh()
	else
		Ui.close(dim, true)
		Ui.close(panel)
	end
	Juice.SetPanel("Dex", open)
end

Juice.Bus.ToggleDex.Event:Connect(function()
	setOpen(not Ui.IsOpen(panel))
end)
closeButton.Activated:Connect(function()
	setOpen(false)
end)
player:GetAttributeChangedSignal("DexVersion"):Connect(function()
	if panel.Visible then
		refresh()
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")

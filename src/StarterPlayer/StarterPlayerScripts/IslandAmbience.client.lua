-- 섬 분위기: 카메라에서 가장 가까운 섬의 컨셉(Ambience)으로 하늘 안개와 색감을 천천히 바꾼다(이 화면에서만).
-- 창백한 정원은 잿빛 안개와 낮은 채도, 메사는 노을빛, 눈꽃 봉우리는 푸른빛처럼 시드마다 섬의 공기가 다르다.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Concepts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IslandConcepts"))

local FADE = TweenInfo.new(3, Enum.EasingStyle.Sine)

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "IslandAmbience"
grade.Parent = Lighting

local current
while true do
	local islands = workspace:FindFirstChild("Islands")
	local camera = workspace.CurrentCamera
	local nearest, best = nil, math.huge
	for _, island in if islands then islands:GetChildren() else {} do
		local origin = island:GetAttribute("Origin")
		local distance = origin and (camera.CFrame.Position - origin).Magnitude
		if distance and distance < best then
			nearest, best = island, distance
		end
	end
	local concept = nearest and Concepts[nearest:GetAttribute("Concept")]
	if concept and concept ~= current then
		current = concept
		local a = concept.Ambience
		TweenService:Create(atmosphere, FADE, { Color = a.Color, Decay = a.Decay, Density = a.Density, Haze = a.Haze }):Play()
		TweenService:Create(grade, FADE, { TintColor = a.Tint, Saturation = a.Saturation }):Play()
	end
	task.wait(0.5)
end

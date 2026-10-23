-- 가구 데이터(공용)와 모양 만들기. 서버는 배치할 때, 클라이언트는 미리보기에 같은 Build를 쓴다.
-- Price = 목수 버니 상점 가격, Cozy = 아늑함 점수, Set = 세트(세트를 다 놓으면 보너스), Kind = 필수 가구 판정용
-- Seat = 앉는 자리(가구 바닥 기준), Light = 불빛. 부품 Offset은 가구 바닥 가운데 기준.
-- 수치 근거: design/gdd/housekeeping.md
local WOOD = Color3.fromRGB(160, 115, 70)
local DARK_WOOD = Color3.fromRGB(120, 85, 55)
local WHITE = Color3.fromRGB(245, 242, 235)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥(축 X)을 세운다

local function legs(spread, height, size)
	local list = {}
	for _, x in { -spread, spread } do
		for _, z in { -spread, spread } do
			table.insert(list, { Size = Vector3.new(size, height, size), Offset = CFrame.new(x, height / 2, z), Color = DARK_WOOD, Material = Enum.Material.Wood })
		end
	end
	return list
end

local function with(list, ...)
	for _, part in { ... } do
		table.insert(list, part)
	end
	return list
end

local Items = {
	LogChair = {
		Name = "통나무 의자", Order = 1, Price = 30, Cozy = 5, Set = "Log", Kind = "Seat", Seat = Vector3.new(0, 1.8, 0),
		Desc = "앉으면 섬 바람이 등을 받쳐 준다.",
		Parts = with(legs(0.75, 1.4, 0.3),
			{ Size = Vector3.new(2, 0.4, 2), Offset = CFrame.new(0, 1.6, 0), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(2, 1.8, 0.3), Offset = CFrame.new(0, 2.7, 0.85), Color = WOOD, Material = Enum.Material.Wood }),
	},
	LogTable = {
		Name = "통나무 탁자", Order = 2, Price = 45, Cozy = 6, Set = "Log", Kind = "Table",
		Desc = "차 한 잔과 씨앗 봉투를 올려 두기 좋은 높이.",
		Parts = with(legs(1.4, 2.4, 0.4),
			{ Size = Vector3.new(3.6, 0.4, 3.6), Offset = CFrame.new(0, 2.6, 0), Color = WOOD, Material = Enum.Material.Wood }),
	},
	LogBench = {
		Name = "통나무 벤치", Order = 3, Price = 40, Cozy = 6, Set = "Log", Kind = "Seat", Seat = Vector3.new(0, 1.7, 0),
		Desc = "둘이 앉아 구름 구경하기 좋은 벤치.",
		Parts = {
			{ Size = Vector3.new(4.6, 0.4, 1.6), Offset = CFrame.new(0, 1.5, 0), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(0.5, 1.3, 1.4), Offset = CFrame.new(-1.8, 0.65, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(0.5, 1.3, 1.4), Offset = CFrame.new(1.8, 0.65, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
		},
	},
	FlowerPot = {
		Name = "꽃 화분", Order = 4, Price = 15, Cozy = 4, Set = "Garden",
		Desc = "물을 주지 않아도 시들지 않는 하늘섬 꽃.",
		Parts = {
			{ Size = Vector3.new(1.3, 1.4, 1.4), Offset = CFrame.new(0, 0.65, 0) * VERTICAL, Color = Color3.fromRGB(200, 110, 75), Shape = Enum.PartType.Cylinder },
			{ Size = Vector3.new(0.8, 0.8, 0.8), Offset = CFrame.new(0, 1.7, 0), Color = Color3.fromRGB(255, 150, 190), Shape = Enum.PartType.Ball },
			{ Size = Vector3.new(0.7, 0.7, 0.7), Offset = CFrame.new(0.45, 1.5, 0.2), Color = Color3.fromRGB(255, 220, 90), Shape = Enum.PartType.Ball },
			{ Size = Vector3.new(0.7, 0.7, 0.7), Offset = CFrame.new(-0.4, 1.5, -0.25), Color = Color3.fromRGB(170, 140, 255), Shape = Enum.PartType.Ball },
		},
	},
	Fence = {
		Name = "하얀 울타리", Order = 5, Price = 10, Cozy = 2, Set = "Garden",
		Desc = "섬 가장자리에 두면 마음이 놓인다.",
		Parts = {
			{ Size = Vector3.new(0.35, 2.2, 0.35), Offset = CFrame.new(-1.8, 1.1, 0), Color = WHITE },
			{ Size = Vector3.new(0.35, 2.2, 0.35), Offset = CFrame.new(0, 1.1, 0), Color = WHITE },
			{ Size = Vector3.new(0.35, 2.2, 0.35), Offset = CFrame.new(1.8, 1.1, 0), Color = WHITE },
			{ Size = Vector3.new(4, 0.25, 0.2), Offset = CFrame.new(0, 1.6, 0), Color = WHITE },
			{ Size = Vector3.new(4, 0.25, 0.2), Offset = CFrame.new(0, 0.8, 0), Color = WHITE },
		},
	},
	Scarecrow = {
		Name = "허수아비", Order = 6, Price = 60, Cozy = 8, Set = "Garden",
		Desc = "새를 쫓기보다 새와 친구가 되어 버린 허수아비.",
		Parts = {
			{ Size = Vector3.new(0.4, 5, 0.4), Offset = CFrame.new(0, 2.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(3.4, 0.3, 0.3), Offset = CFrame.new(0, 3.6, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = Vector3.new(1.6, 1.6, 0.8), Offset = CFrame.new(0, 3.3, 0), Color = Color3.fromRGB(110, 150, 200), Material = Enum.Material.Fabric },
			{ Size = Vector3.new(1.3, 1.3, 1.3), Offset = CFrame.new(0, 5.1, 0), Color = Color3.fromRGB(235, 205, 130), Material = Enum.Material.Fabric, Shape = Enum.PartType.Ball },
			{ Size = Vector3.new(0.5, 2, 2), Offset = CFrame.new(0, 5.8, 0) * VERTICAL, Color = Color3.fromRGB(190, 150, 80), Material = Enum.Material.Fabric, Shape = Enum.PartType.Cylinder },
		},
	},
	Lantern = {
		Name = "등불", Order = 7, Price = 35, Cozy = 5, Kind = "Light", Light = Vector3.new(0, 3.4, 0),
		Desc = "밤에도 섬을 찾아올 수 있게 켜 두는 불빛.",
		Parts = {
			{ Size = Vector3.new(0.3, 3, 0.3), Offset = CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Metal },
			{ Size = Vector3.new(0.8, 0.9, 0.8), Offset = CFrame.new(0, 3.4, 0), Color = Color3.fromRGB(255, 210, 130), Material = Enum.Material.Neon },
		},
	},
	Rug = {
		Name = "동그란 러그", Order = 8, Price = 25, Cozy = 4,
		Desc = "맨발로 밟으면 구름 같은 촉감.",
		Parts = {
			{ Size = Vector3.new(0.12, 6, 6), Offset = CFrame.new(0, 0.06, 0) * VERTICAL, Color = Color3.fromRGB(240, 180, 175), Material = Enum.Material.Fabric, Shape = Enum.PartType.Cylinder },
		},
	},
}

local Furniture = { Items = Items }

-- 바닥 가운데가 pivot인 모델(부품은 Anchored). 놓은 모델·미리보기 모두 이걸로 만든다.
function Furniture.Build(id)
	local data = Items[id]
	local model = Instance.new("Model")
	model.Name = id
	for _, spec in data.Parts do
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = spec.Size
		part.CFrame = spec.Offset
		part.Color = spec.Color
		part.Material = spec.Material or Enum.Material.SmoothPlastic
		part.Shape = spec.Shape or Enum.PartType.Block
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model
end

return Furniture

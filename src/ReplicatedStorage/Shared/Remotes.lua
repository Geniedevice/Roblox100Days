-- 서버가 처음 require할 때 Remote를 만들고, 클라이언트는 기다렸다가 가져간다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFINITIONS = {
	DayChanged = "RemoteEvent",
	GameMessage = "RemoteEvent",
	AugmentOffer = "RemoteEvent",
	AugmentClosed = "RemoteEvent",
	ChooseAugment = "RemoteFunction",
	RerollAugment = "RemoteFunction",
	UseItem = "RemoteFunction",
	RequestCraft = "RemoteFunction",
	Shoot = "RemoteEvent",
	Reload = "RemoteEvent",
	SwingFx = "RemoteEvent", -- 서버 → 모든 클라이언트: 이 캐릭터가 근접 무기를 휘두른다
	HitMarker = "RemoteEvent", -- 서버 → 쏜 사람: 맞혔다
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for name in DEFINITIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes

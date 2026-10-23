-- 서버가 처음 require할 때 Remote를 만들고, 클라이언트는 기다렸다가 가져간다.
-- 클라이언트가 보내는 것은 전부 "요청"이고, 서버가 검사해서 적용한다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFINITIONS = {
	Interact = "RemoteEvent", -- 클라 → 서버: (종류, 대상 Instance, 인자) 농지·잡초 등을 눌렀다
	Feedback = "RemoteEvent", -- 서버 → 클라: (종류, 정보) 동작 애니메이션·VFX·알림의 신호
	Dialogue = "RemoteEvent", -- 서버 → 클라: 대사·상점·닫기 / 클라 → 서버: 고른 선택지 번호(0 = 닫기)
	Shop = "RemoteFunction", -- 클라 → 서버: (상점 Id, 상품 Id) → 성공, 문구
	Dex = "RemoteFunction", -- 클라 → 서버: () → 내 도감(분류·칸 목록)
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

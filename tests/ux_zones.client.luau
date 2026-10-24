-- UX 점검(클라이언트): "어디에 가면 무엇을 할 수 있는지 화면이 알려 주는가". 내 섬 구역마다 캐릭터를 옮겨(클라이언트 PivotTo)
-- 8방향으로 돌아보며 적는다: 구역 칩 글, 뜬 행동 프롬프트(밭·낚시·광산·생물·집안일), 가까운 NPC 프롬프트, 보이는 신호
-- (반짝이는 광석·다 자란 작물·NPC 이름표·생물·집안일·다음 땅 팻말·닫힌 밭 팻말). 판정: 구역마다 프롬프트나 신호가 하나 이상.
-- 실행: Play → MCP execute_luau(Client)에 이 파일 내용. 약 20초. "PASS n" 또는 "FAIL k/n" + 구역별 줄을 돌려준다.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local island = workspace:FindFirstChild("Islands") and workspace.Islands:FindFirstChild("Island_" .. player.UserId)
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not island or not root then
	return "NOT RUN — 섬이나 캐릭터가 없다"
end
local CHUNK = 48
local origin = island:GetAttribute("Origin")
local chunks = HttpService:JSONDecode(island:GetAttribute("Chunks"))
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { player.Character }

local function down(point)
	local hit = workspace:Raycast(Vector3.new(point.X, origin.Y + 150, point.Z), Vector3.new(0, -300, 0), params)
	return hit and hit.Position, hit and hit.Instance.Parent and hit.Instance.Parent.Name == "Water"
end

-- 구역의 서 있을 자리: 낚시터는 물에 가장 가까운 땅, 광산은 광석에 가장 가까운 땅, 농장은 첫 농지 앞, 나머지는 청크 가운데
local function spotFor(zone)
	if zone == "Farm" then
		for _, tile in CollectionService:GetTagged("FarmTile") do
			if tile:GetAttribute("Owner") == player.UserId then
				return tile.Position + Vector3.new(0, 0, 5)
			end
		end
	end
	local best, bestScore
	for _, c in chunks do
		if c.Zone == zone then
			local grounds, waters = {}, {}
			for i = 1, 11 do
				for j = 1, 11 do
					local p, wet = down(origin + Vector3.new((c.X + i / 12) * CHUNK, 0, (c.Z + j / 12) * CHUNK))
					if p then
						table.insert(if wet then waters else grounds, p)
					end
				end
			end
			for _, g in grounds do
				local score = if zone == "Fishing" then math.huge elseif zone == "Wild" then math.huge else
					((g - origin) - Vector3.new((c.X + 0.5) * CHUNK, g.Y - origin.Y, (c.Z + 0.5) * CHUNK)).Magnitude
				if zone == "Fishing" then
					for _, w in waters do
						score = math.min(score, (w - g).Magnitude)
					end
				elseif zone == "Wild" then -- 숲은 광석 바위 곁(광산 구역은 2026-10-24에 없앴다)
					for _, ore in CollectionService:GetTagged("Ore") do
						if ore:IsDescendantOf(island) and not ore:GetAttribute("Depleted") then
							score = math.min(score, (ore.Position - g).Magnitude)
						end
					end
				end
				if not bestScore or score < bestScore then
					best, bestScore = g, score
				end
			end
		end
	end
	return best
end

local function promptsShown(found)
	for _, name in { "TilePrompt", "ActivityPrompt" } do
		local anchor = workspace:FindFirstChild(name)
		local p = anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
		if p and p.Enabled then
			found[p.ActionText .. (if p.ObjectText ~= "" then " · " .. p.ObjectText else "")] = true
		end
	end
	for _, npc in CollectionService:GetTagged("Npc") do
		local p = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if p and (npc:GetPivot().Position - root.Position).Magnitude <= p.MaxActivationDistance then
			found[p.ActionText .. " · " .. p.ObjectText] = true
		end
	end
end

local function cues()
	local list = {}
	local function count(label, n)
		if n > 0 then
			table.insert(list, label .. " " .. n)
		end
	end
	local function near(position, range)
		return (position - root.Position).Magnitude <= range
	end
	local n = 0
	for _, ore in CollectionService:GetTagged("Ore") do
		local sparkle = ore:FindFirstChild("OreSparkle")
		n += if sparkle and sparkle.Enabled and near(ore.Position, 25) then 1 else 0
	end
	count("반짝이는 광석", n)
	n = 0
	for _, crop in CollectionService:GetTagged("Crop") do
		n += if crop:GetAttribute("Stage") == 3 and near(crop:GetPivot().Position, 25) then 1 else 0
	end
	count("다 자란 작물", n)
	n = 0
	for _, npc in CollectionService:GetTagged("Npc") do
		n += if npc:FindFirstChild("RoleTag", true) and near(npc:GetPivot().Position, 40) then 1 else 0
	end
	count("NPC 이름표", n)
	n = 0
	for _, model in CollectionService:GetTagged("Creature") do
		n += if near(model:GetPivot().Position, 25) then 1 else 0
	end
	count("생물", n)
	n = 0
	for _, model in CollectionService:GetTagged("Chore") do
		n += if model:GetAttribute("Owner") == player.UserId and near(model:GetPivot().Position, 25) then 1 else 0
	end
	count("집안일", n)
	local ghost = island:FindFirstChild("NextChunk")
	count("다음 땅 팻말", if ghost and near(ghost.Position, 80) then 1 else 0)
	n = 0
	local farm = island:FindFirstChild("Farm")
	for _, plate in farm and farm:GetChildren() or {} do
		n += if plate.Name == "LockedField" and plate:FindFirstChildOfClass("BillboardGui") and near(plate.Position, 40) then 1 else 0
	end
	count("밭 자리 팻말", n)
	return list
end

local chip = player.PlayerGui:FindFirstChild("Hud") and player.PlayerGui.Hud:FindFirstChild("ZoneChip")
local lines, failed, total = {}, 0, 0
for _, zone in { "Plaza", "Farm", "Fishing", "House", "Wild" } do
	local ground = spotFor(zone)
	if ground then
		root.AssemblyLinearVelocity = Vector3.zero
		player.Character:PivotTo(CFrame.new(ground + Vector3.new(0, 3.2, 0)))
		task.wait(0.8)
		local chipText = chip and chip.Visible and chip:FindFirstChildOfClass("TextLabel") and chip:FindFirstChildOfClass("TextLabel").Text or "(칩 없음)"
		local found = {}
		for k = 0, 7 do
			local angle = k * math.pi / 4
			player.Character:PivotTo(CFrame.lookAt(root.Position, root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle))))
			task.wait(0.22)
			promptsShown(found)
		end
		local shown = {}
		for text in found do
			table.insert(shown, text)
		end
		table.sort(shown)
		local signs = cues()
		total += 1
		local ok = #shown > 0 or #signs > 0
		failed += if ok then 0 else 1
		table.insert(lines, string.format("%s %s | 칩: %s | 프롬프트: %s | 신호: %s", if ok then "ok  " else "FAIL", zone, chipText,
			if #shown > 0 then table.concat(shown, ", ") else "없음", if #signs > 0 then table.concat(signs, ", ") else "없음"))
	else
		table.insert(lines, "--   " .. zone .. " | 이 섬에 없음")
	end
end
return (if failed == 0 then "PASS " .. total else string.format("FAIL %d/%d", failed, total)) .. "\n" .. table.concat(lines, "\n")

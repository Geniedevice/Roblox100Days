-- 광석 바위 점검(클라이언트, Play): 내 섬 숲 위 광석 바위 앞에 서면(클라이언트 PivotTo) "캐기" 프롬프트가 뜨고,
-- Hits번 치면 바위가 사라지고 광석이 1 는다. 실행: Play → MCP execute_luau(Client)에 이 파일 내용. 약 5초.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ores = require(ReplicatedStorage.Shared.Ores)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local island = workspace.Islands:FindFirstChild("Island_" .. player.UserId)
local folder = island and island:FindFirstChild("Ores")
local rock = folder and folder:GetChildren()[1]
if not rock then
	return "NOT RUN — 광석 바위가 없다"
end
local lines, failed, total = {}, 0, 0
local function check(ok, what)
	total += 1
	failed += if ok then 0 else 1
	table.insert(lines, (if ok then "ok   " else "FAIL ") .. what)
end

local id = rock:GetAttribute("Ore")
check(rock:FindFirstChild("OreSparkle") ~= nil, "바위에 광석 색 반짝이(" .. tostring(id) .. ")")
player.Character:PivotTo(CFrame.lookAt(rock.Position + Vector3.new(5, 1, 0), rock.Position))
task.wait(0.6)
local anchor = workspace:FindFirstChild("ActivityPrompt")
local prompt = anchor and anchor:FindFirstChildWhichIsA("ProximityPrompt")
check(prompt ~= nil and prompt.Enabled and prompt.ActionText == "캐기" and prompt.ObjectText:find(Ores[id].Name) ~= nil,
	"프롬프트 " .. (if prompt then prompt.ActionText .. " · " .. prompt.ObjectText else "없음"))
local before = player:GetAttribute("Item_Ore_" .. id) or 0
for _ = 1, Ores[id].Hits do
	Remotes.Interact:FireServer("Mine", rock)
	task.wait(0.3)
end
task.wait(0.6)
check(rock.Parent == nil, "Hits " .. Ores[id].Hits .. "번 뒤 바위가 사라졌다")
check((player:GetAttribute("Item_Ore_" .. id) or 0) == before + 1, "광석 +1(" .. before .. " → " .. tostring(player:GetAttribute("Item_Ore_" .. id)) .. ")")
return (if failed == 0 then "PASS " .. total else string.format("FAIL %d/%d", failed, total)) .. "\n" .. table.concat(lines, "\n")

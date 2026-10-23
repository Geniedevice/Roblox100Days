-- 낚시: 섬 물(낚시터 호수, 친구 섬 물도)을 누르면 찌를 던지고(Cast), 2.5~6.5초 뒤 입질(Bite) "!"가 뜬다.
-- 입질 뒤 BITE_WINDOW초 안에 다시 누르면(Reel) 낚인다. 너무 일찍 누르거나 늦으면 놓친다(벌칙 없음, 다시 던지면 된다).
-- 무엇이 낚이는지는 섬 시드의 획득물 표(Shared/Loot: 시드 배수·컨셉 전용·명물 물고기)가 정한다. 판정은 전부 서버.
-- 명세: design/gdd/fishing.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fish = require(ReplicatedStorage.Shared.Fish)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local Inventory = require(script.Parent.Inventory)
local IslandService = require(script.Parent.IslandService)

local REACH = 45 -- 캐릭터에서 찌까지(스터드)
local WAIT_MIN, WAIT_MAX = 2.5, 6.5 -- 입질까지 기다리는 초
local BITE_WINDOW = 1.2 -- 입질 뒤 당길 수 있는 초
local LATENCY = 0.25 -- 신호가 오가는 시간 여유

local FishService = {}
local sessions = {} -- [player] = { Position, State = "Wait" | "Bite", BiteAt, Token, Island }
local rng = Random.new()
local token = 0

local function send(kind, player, session, info)
	info = info or {}
	info.Player = player
	info.Position = session.Position
	Remotes.Feedback:FireAllClients(kind, info)
end

-- 친구 섬 물에서도 던질 수 있다. 무엇이 낚이는지는 그 섬(시드) 표다
local function cast(player, water, position)
	local island = IslandService.Find(water)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not island or not root or not water:IsDescendantOf(island.Water) or typeof(position) ~= "Vector3" then
		return
	end
	local surface = water.Position.Y + water.Size.Y / 2
	local bobber = Vector3.new(position.X, surface, position.Z)
	local half = water.Size / 2 + Vector3.one * 0.5
	local offset = water.CFrame:PointToObjectSpace(bobber)
	if math.abs(offset.X) > half.X or math.abs(offset.Z) > half.Z or (root.Position - bobber).Magnitude > REACH then
		return
	end
	token += 1
	local session = { Position = bobber, State = "Wait", Token = token, Island = island }
	sessions[player] = session
	send("Cast", player, session)
	task.delay(rng:NextNumber(WAIT_MIN, WAIT_MAX), function()
		if sessions[player] ~= session then
			return
		end
		session.State, session.BiteAt = "Bite", os.clock()
		send("Bite", player, session, { Window = BITE_WINDOW })
		task.delay(BITE_WINDOW + LATENCY, function()
			if sessions[player] == session then
				sessions[player] = nil
				send("Miss", player, session, { Text = "놓쳤어요… 다시!" })
			end
		end)
	end)
end

local function reel(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.State ~= "Bite" or os.clock() - session.BiteAt > BITE_WINDOW + LATENCY then
		return send("Miss", player, session, { Early = true, Text = "너무 일렀어요! '!'를 기다려요" })
	end
	local loot = session.Island.Gen.Loot
	if not DataService.Get(player) then
		return
	end
	local id = Loot.Pick(loot.Fish, loot.FishTotal, rng:NextNumber())
	local fish = Fish[id]
	Inventory.Add(player, "Fish_" .. id, 1)
	local special = loot.SpecialFish == id
	send("Catch", player, session, {
		Item = id, Rare = fish.Weight <= 2 or fish.Price >= 30, Special = special,
		Text = "+1 " .. fish.Name .. (if special then " · 섬 명물!" else ""),
	})
	DexService.Record(player, "Fish", id)
end

function FishService.Unload(player)
	sessions[player] = nil
end

function FishService.Start()
	Remotes.Interact.OnServerEvent:Connect(function(player, kind, target, arg)
		if kind == "Cast" and typeof(target) == "Instance" and target:IsA("BasePart") then
			if sessions[player] then
				reel(player) -- 찌가 떠 있을 때 물을 다시 누르면 당기기
			else
				cast(player, target, arg)
			end
		elseif kind == "Reel" then
			reel(player)
		end
	end)
end

return FishService

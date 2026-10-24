-- 화면에서 누른 곳(마우스 클릭·터치 탭)이나 마우스가 가리키는 곳 아래의 월드 대상을 알려 준다.
-- UI 위를 누른 것과 자기 캐릭터는 무시한다. 농사·꾸미기·하이라이트가 같이 쓴다.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local RANGE = 300

local WorldPointer = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function cast(ray, ignore)
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character, ignore }
	return workspace:Raycast(ray.Origin, ray.Direction * RANGE, params)
end

-- screenPosition = InputObject.Position 같은 화면 좌표(상단 바 제외)
function WorldPointer.Cast(screenPosition, ignore)
	return cast(workspace.CurrentCamera:ScreenPointToRay(screenPosition.X, screenPosition.Y), ignore)
end

-- 지금 마우스가 가리키는 곳(터치 기기에서는 의미 없음)
function WorldPointer.CastMouse(ignore)
	local location = UserInputService:GetMouseLocation()
	return cast(workspace.CurrentCamera:ViewportPointToRay(location.X, location.Y), ignore)
end

-- 행동 프롬프트 하나(E · 게임패드 X · 모바일 버튼, 이 클라이언트에만 있다). 돌려준 show(위치, 행동 글, 대상 글)로 옮겨 띄우고
-- show(nil)로 숨긴다. 대상이 다시 지어져도 프롬프트가 같이 지워지지 않게 투명한 앵커 Part에 단다. 밭(Hud)·낚시·광산(ActivityClient)
function WorldPointer.Prompt(name, onTriggered)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Enabled = false
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = anchor
	return function(position, action, object)
		if position then
			anchor.CFrame = CFrame.new(position)
			prompt.ActionText, prompt.ObjectText = action, object or ""
		end
		prompt.Enabled = position ~= nil
	end
end

-- 누를 때마다 callback(RaycastResult)
function WorldPointer.OnTap(callback)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local result = WorldPointer.Cast(input.Position)
			if result then
				callback(result)
			end
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			local result = WorldPointer.Cast(position)
			if result then
				callback(result)
			end
		end
	end)
end

return WorldPointer

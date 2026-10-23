-- src/ → 열린 Studio 플레이스 동기화 모듈. Studio에는 ServerStorage.StudioSync(ModuleScript)로 한 번 설치하고,
-- Roblox_Studio MCP execute_luau(Edit)에서 `return require(game.ServerStorage.StudioSync:Clone())()` 한 줄로 부른다.
-- 먼저 `py tools/studio_sync_server.py`를 켜 둔다(127.0.0.1:34999, /tool이 이 파일을 내보낸다 → 설치·갱신에 쓴다).
-- 파일 이름 = 인스턴스 이름: X.server.lua → Script, X.client.lua → LocalScript, X.lua → ModuleScript,
-- 첫 폴더 = 서비스(ReplicatedStorage, ServerScriptService, StarterPlayer …), 사이 폴더는 Folder로 만든다.
-- 관리 영역(ReplicatedStorage·ServerScriptService·StarterPlayer)에서 src에 없는 스크립트는 지운다.
-- 게임의 HTTP 허용(HttpEnabled)은 이 실행 동안만 켜고 원래대로 돌린다(게임은 HTTP를 쓰지 않는다).
local BASE = "http://127.0.0.1:34999/"

return function()
	local http = game:GetService("HttpService")
	local was = http.HttpEnabled
	http.HttpEnabled = true
	local ok, result = pcall(function()
		local files = http:JSONDecode(http:GetAsync(BASE .. "manifest", true))
		local seen, changed = {}, {}
		for _, path in files do
			local parts = string.split(path, "/")
			local file = table.remove(parts)
			local name, kind = file:match("^(.-)%.(%a+)%.lua$")
			local class = if kind == "server" then "Script" elseif kind == "client" then "LocalScript" else nil
			if not class then
				name, class = file:match("^(.-)%.lua$"), "ModuleScript"
			end
			local parent = game:GetService(table.remove(parts, 1))
			for _, folderName in parts do
				local child = parent:FindFirstChild(folderName)
				if not child then
					child = Instance.new("Folder")
					child.Name = folderName
					child.Parent = parent
				end
				parent = child
			end
			local source = http:GetAsync(BASE .. path, true)
			local script = parent:FindFirstChild(name)
			if script and script.ClassName ~= class then
				script:Destroy()
				script = nil
			end
			if not script then
				script = Instance.new(class)
				script.Name = name
				script.Parent = parent
			end
			if script.Source ~= source then
				script.Source = source
				table.insert(changed, path)
			end
			seen[script] = true
		end
		local removed = {}
		for _, root in { game:GetService("ReplicatedStorage"), game:GetService("ServerScriptService"), game:GetService("StarterPlayer") } do
			for _, object in root:GetDescendants() do
				if object:IsA("LuaSourceContainer") and not seen[object] then
					table.insert(removed, object:GetFullName())
					object:Destroy()
				end
			end
		end
		return string.format("%d files, changed %d: %s | removed %d: %s", #files, #changed, table.concat(changed, ", "),
			#removed, table.concat(removed, ", "))
	end)
	http.HttpEnabled = was
	return if ok then result else "sync failed: " .. tostring(result)
end

if not getgenv().TRonVoid then error("[TRon Void] Config nao encontrada!") return end

local Config = getgenv().TRonVoid

Config["Team"]             = Config["Team"]             or "Pirates"
Config["Mode"]             = Config["Mode"]             or "Normal"
Config["Fix Lag"]          = Config["Fix Lag"]          ~= nil and Config["Fix Lag"] or true
Config["Auto Hop After"]   = Config["Auto Hop After"]   or 300
Config["Safe Mode"]        = Config["Safe Mode"]        ~= nil and Config["Safe Mode"] or true
Config["Run Away HP"]      = Config["Run Away HP"]      or 2000
Config["Return HP"]        = Config["Return HP"]        or 5000
Config["Level Difference"] = Config["Level Difference"] or 999
Config["Auto Race V3"]     = Config["Auto Race V3"]     or false
Config["Auto Race V4"]     = Config["Auto Race V4"]     or false
Config["Skills Melee"]     = Config["Skills Melee"]     or {["Z"]=true,  ["X"]=true,  ["C"]=false}
Config["Skills Fruit"]     = Config["Skills Fruit"]     or {["Z"]=true,  ["X"]=true,  ["C"]=false, ["V"]=false, ["F"]=true}
Config["Skills Sword"]     = Config["Skills Sword"]     or {["Z"]=true,  ["X"]=false}
Config["Skills Gun"]       = Config["Skills Gun"]       or {["Z"]=true,  ["X"]=true}

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")

local LP = Players.LocalPlayer

local PURPLE       = Color3.fromRGB(148, 0, 211)
local PURPLE_DARK  = Color3.fromRGB(80,  0, 140)
local PURPLE_LIGHT = Color3.fromRGB(190, 80, 255)
local PURPLE_MID   = Color3.fromRGB(120, 0, 180)

local State = {
	running       = true,
	currentTarget = nil,
	targetName    = "None",
	status        = "Iniciando...",
	hopTimer      = 0,
	retreating    = false,
	kobyLoaded    = false,
	gunNetReady   = false,
}

local function SafeCall(fn, ...)
	local ok, err = pcall(fn, ...)
end

local function GetMyChar()
	return LP.Character
end

local function GetMyHRP()
	local char = GetMyChar()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetMyHumanoid()
	local char = GetMyChar()
	return char and char:FindFirstChild("Humanoid")
end

local function GetMyHP()
	local hum = GetMyHumanoid()
	return hum and hum.Health or 0
end

local function IsCharAlive(char)
	if not char then return false end
	local hum = char:FindFirstChild("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function GetPlayerLevel(player)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local lv = ls:FindFirstChild("Level") or ls:FindFirstChild("Lv") or ls:FindFirstChild("level")
		if lv then return tonumber(lv.Value) or 0 end
	end
	return 0
end

local SAFE_ZONES = {
	{pos = Vector3.new(-800,   100, -1500), range = 350},
	{pos = Vector3.new( 1000,  100,  1000), range = 450},
	{pos = Vector3.new(-3000,  100,     0), range = 350},
	{pos = Vector3.new(-3000,  200, -3000), range = 550},
	{pos = Vector3.new( 1000,  200, -1000), range = 400},
	{pos = Vector3.new(  200,   80,   200), range = 300},
	{pos = Vector3.new( -270,   80,   650), range = 280},
	{pos = Vector3.new( 5000,  300,  5000), range = 650},
	{pos = Vector3.new(-5000,  300,  1000), range = 500},
	{pos = Vector3.new( 9000,  300,  9000), range = 450},
	{pos = Vector3.new( 2000,  150,  3000), range = 400},
	{pos = Vector3.new(-7500,  400,  3500), range = 500},
	{pos = Vector3.new( 4500,  250, -1000), range = 400},
	{pos = Vector3.new(-13000, 100, -3000), range = 500},
	{pos = Vector3.new(-12000, 200,  1000), range = 400},
	{pos = Vector3.new(-11000, 300, -2000), range = 450},
	{pos = Vector3.new(-15000, 100,   500), range = 500},
	{pos = Vector3.new(-16500, 100,  2500), range = 350},
}

local function IsInSafeZone(pos)
	for _, zone in ipairs(SAFE_ZONES) do
		if (pos - zone.pos).Magnitude < zone.range then return true end
	end
	return false
end

local RAID_ZONES = {
	{pos = Vector3.new(  500, 200,  1800), range = 500},
	{pos = Vector3.new( -500, 200,  1800), range = 500},
	{pos = Vector3.new( 6000, 300,  6000), range = 600},
	{pos = Vector3.new(-6000, 300, -6000), range = 600},
	{pos = Vector3.new(    0, 500,     0), range = 700},
}

local function IsPlayerInRestrictedZone(pos)
	for _, zone in ipairs(RAID_ZONES) do
		if (pos - zone.pos).Magnitude < zone.range then return true end
	end
	return false
end

local function PlayerHasPvP(player)
	SafeCall(function()
		local myTeam    = LP.Team
		local theirTeam = player.Team
		if myTeam and theirTeam then
			if myTeam ~= theirTeam then return end
		end
	end)

	local pvpOn = true

	SafeCall(function()
		for _, guiChild in ipairs(LP.PlayerGui:GetChildren()) do
			for _, desc in ipairs(guiChild:GetDescendants()) do
				if desc:IsA("TextLabel") then
					local txt = desc.Text or ""
					if txt == player.DisplayName or txt == player.Name or txt == "@"..player.Name then
						for _, sib in ipairs(desc.Parent:GetChildren()) do
							local nm = sib.Name:upper()
							if sib:IsA("ImageLabel") and (string.find(nm,"PVP") or string.find(nm,"PVPICON")) then
								if not sib.Visible or sib.ImageTransparency > 0.5 then
									pvpOn = false
								end
							end
						end
					end
				end
			end
		end
	end)

	return pvpOn
end

local function IsValidTarget(player)
	if not player or player == LP then return false end
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	if not IsCharAlive(char) then return false end
	if not PlayerHasPvP(player) then return false end
	if IsInSafeZone(hrp.Position) then return false end
	if IsPlayerInRestrictedZone(hrp.Position) then return false end
	local myLv = GetPlayerLevel(LP)
	local tgLv = GetPlayerLevel(player)
	if math.abs(myLv - tgLv) > Config["Level Difference"] then return false end
	return true
end

local function GetValidTargets()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if IsValidTarget(p) then table.insert(list, p) end
	end
	return list
end

local function GetNearestTarget(targets)
	local myHRP = GetMyHRP()
	if not myHRP then return nil end
	local best, bestDist = nil, math.huge
	for _, p in ipairs(targets) do
		local char = p.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (myHRP.Position - hrp.Position).Magnitude
				if d < bestDist then bestDist = d best = p end
			end
		end
	end
	return best
end

local function TweenTo(targetPos)
	local myHRP = GetMyHRP()
	if not myHRP then return end
	local tw = TweenService:Create(myHRP, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
	})
	tw:Play()
	tw.Completed:Wait()
end

local function TeleportToPlayer(player)
	local char = player and player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local myHRP = GetMyHRP()
	if not myHRP then return end
	if (myHRP.Position - hrp.Position).Magnitude > 200 then
		SafeCall(function() myHRP.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 6, 0)) end)
		task.wait(0.08)
	end
	TweenTo(hrp.Position)
end

local function InstantTeleportToPlayer(player)
	local char = player and player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local myHRP = GetMyHRP()
	if not myHRP then return end
	SafeCall(function() myHRP.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 4, 0)) end)
end

local function CheckSafeMode()
	if not Config["Safe Mode"] then return false end
	local hp = GetMyHP()
	if not State.retreating and hp > 0 and hp <= Config["Run Away HP"] then
		State.retreating = true
		State.status = "SAFE MODE: HP baixo! Recuando... (" .. math.floor(hp) .. " HP)"
		local myHRP = GetMyHRP()
		if myHRP then
			SafeCall(function()
				myHRP.CFrame = CFrame.new(
					myHRP.Position.X + math.random(-800, 800),
					myHRP.Position.Y + 60,
					myHRP.Position.Z + math.random(-800, 800)
				)
			end)
		end
		return true
	end
	if State.retreating then
		if hp >= Config["Return HP"] then
			State.retreating = false
			State.status = "HP recuperado! Voltando ao combate..."
			return false
		end
		State.status = "Recuperando HP: " .. math.floor(hp) .. " / " .. Config["Return HP"]
		return true
	end
	return false
end

local heartConn = nil

local function StartFastAttackHeart()
	if heartConn then return end
	heartConn = RunService.Heartbeat:Connect(function()
		SafeCall(function()
			local v = require(ReplicatedStorage.Util.CombatFramework).GetActiveController()
			if v then
				v.timeToNextAttack = -(math.huge ^ math.huge ^ math.huge)
				v.hitboxMagnitude  = 120
				v:attack()
			end
		end)
	end)
end

local function LoadKobyAttack()
	if State.kobyLoaded then return end
	State.kobyLoaded = true
	State.status = "Carregando Fast Attack Koby..."
	SafeCall(function()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/AnhDangNhoEm/TuanAnhIOS/refs/heads/main/koby"))()
	end)
end

local gunNetModule = nil

local function SetupGunNet()
	if State.gunNetReady then return end
	SafeCall(function()
		local folders = {
			ReplicatedStorage:FindFirstChild("Util"),
			ReplicatedStorage:FindFirstChild("Common"),
			ReplicatedStorage:FindFirstChild("Remotes"),
			ReplicatedStorage:FindFirstChild("Assets"),
			ReplicatedStorage:FindFirstChild("FX"),
		}
		for _, folder in ipairs(folders) do
			if folder then
				folder.ChildAdded:Connect(function(n)
					if n:IsA("RemoteEvent") and n:GetAttribute("Id") then end
				end)
			end
		end
		gunNetModule = ReplicatedStorage:FindFirstChild("Modules") and
		               ReplicatedStorage.Modules:FindFirstChild("Net")
		State.gunNetReady = true
	end)
end

local function GetNearestGunTarget()
	local myHRP = GetMyHRP()
	if not myHRP then return nil end
	local best, bestDist = nil, math.huge
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, mob in ipairs(enemiesFolder:GetChildren()) do
			local hrp = mob:FindFirstChild("HumanoidRootPart")
			if hrp and IsCharAlive(mob) then
				local d = (myHRP.Position - hrp.Position).Magnitude
				if d < bestDist then bestDist = d best = hrp end
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character and IsValidTarget(p) then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and IsCharAlive(p.Character) then
				local d = (myHRP.Position - hrp.Position).Magnitude
				if d < bestDist then bestDist = d best = hrp end
			end
		end
	end
	return best
end

local function FireGunShot(targetHRP)
	if not targetHRP then return end
	local char = GetMyChar()
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then return end
	SafeCall(function()
		if gunNetModule then
			local shootEvent = gunNetModule:FindFirstChild("RE/ShootGunEvent")
			if shootEvent then shootEvent:FireServer(targetHRP.Position, {targetHRP}) end
		end
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)
end

local function PressKey(keyCode)
	SafeCall(function()
		VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
		task.wait(0.08)
		VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
	end)
end

local function UseSkills()
	local mode = Config["Mode"]
	if mode == "Normal" then
		if Config["Skills Melee"]["Z"] then PressKey(Enum.KeyCode.Z) end
		if Config["Skills Melee"]["X"] then PressKey(Enum.KeyCode.X) end
		if Config["Skills Melee"]["C"] then PressKey(Enum.KeyCode.C) end
		if Config["Skills Fruit"]["Z"]  then PressKey(Enum.KeyCode.Z) end
		if Config["Skills Fruit"]["X"]  then PressKey(Enum.KeyCode.X) end
		if Config["Skills Fruit"]["C"]  then PressKey(Enum.KeyCode.C) end
		if Config["Skills Fruit"]["V"]  then PressKey(Enum.KeyCode.V) end
		if Config["Skills Fruit"]["F"]  then PressKey(Enum.KeyCode.F) end
	elseif mode == "Sword" then
		if Config["Skills Sword"]["Z"] then PressKey(Enum.KeyCode.Z) end
		if Config["Skills Sword"]["X"] then PressKey(Enum.KeyCode.X) end
	elseif mode == "Gun" then
		if Config["Skills Gun"]["Z"] then PressKey(Enum.KeyCode.Z) end
		if Config["Skills Gun"]["X"] then PressKey(Enum.KeyCode.X) end
	end
end

local function EquipWeapon(weaponType)
	SafeCall(function()
		local char = GetMyChar()
		if not char then return end
		local hum = char:FindFirstChild("Humanoid")
		if not hum then return end
		local current = char:FindFirstChildOfClass("Tool")
		if current and current:GetAttribute("WeaponType") == weaponType then return end
		for _, tool in ipairs(LP.Backpack:GetChildren()) do
			if tool:IsA("Tool") and tool:GetAttribute("WeaponType") == weaponType then
				hum:EquipTool(tool)
				task.wait(0.3)
				return
			end
		end
	end)
end

local function JoinTeam(teamName)
	State.status = "Entrando no time: " .. teamName

	local teamLower = teamName:lower()
	local clicked   = false

	local function TryClickTeamButton()
		for _, gui in ipairs(LP.PlayerGui:GetChildren()) do
			for _, obj in ipairs(gui:GetDescendants()) do
				if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
					local nm  = obj.Name:lower()
					local txt = (obj:IsA("TextButton") and obj.Text or ""):lower()
					if string.find(nm, teamLower) or string.find(txt, teamLower)
					or (teamLower == "pirates"  and (string.find(nm,"pirate")  or string.find(txt,"pirate")))
					or (teamLower == "marines"  and (string.find(nm,"marine")  or string.find(txt,"marine"))) then
						SafeCall(function()
							obj.MouseButton1Click:Fire()
							fireproximityprompt = fireproximityprompt
						end)
						SafeCall(function() obj:activate() end)
						clicked = true
						return
					end
				end
			end
		end
	end

	for i = 1, 6 do
		TryClickTeamButton()
		if clicked then break end
		task.wait(1)
	end

	if not clicked then
		SafeCall(function()
			local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
			if remotesFolder then
				for _, r in ipairs(remotesFolder:GetChildren()) do
					if r:IsA("RemoteEvent") then
						local nm = r.Name:lower()
						if string.find(nm,"team") or string.find(nm,"chooseside") or string.find(nm,"selectside") then
							r:FireServer(teamName)
							task.wait(0.3)
						end
					end
				end
			end
		end)
	end

	task.wait(1.5)
end

local function ApplyFixLag()
	if not Config["Fix Lag"] then return end
	State.status = "Aplicando Fix Lag..."
	SafeCall(function() settings().Rendering.QualityLevel = 1 end)
	Lighting.GlobalShadows = false
	Lighting.FogEnd        = 9e9
	SafeCall(function()
		for _, v in ipairs(Workspace:GetDescendants()) do
			SafeCall(function()
				if v:IsA("BasePart") or v:IsA("UnionOperation") or v:IsA("PartOperation") then
					v.Material   = Enum.Material.SmoothPlastic
					v.CastShadow = false
				elseif v:IsA("Decal") or v:IsA("Texture") then
					v.Transparency = 1
				elseif v:IsA("SpecialMesh") then
					v.TextureId = ""
				elseif v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail")
				    or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
					v.Enabled = false
				elseif v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
					v.Enabled = false
				end
			end)
		end
	end)
	Workspace.DescendantAdded:Connect(function(v)
		SafeCall(function()
			if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail")
			    or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
				v.Enabled = false
			elseif v:IsA("PointLight") or v:IsA("SpotLight") then
				v.Enabled = false
			end
		end)
	end)
end

local function ActivateRace()
	SafeCall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if not remotes then return end
		if Config["Auto Race V4"] then
			local r = remotes:FindFirstChild("ActivateRaceV4") or remotes:FindFirstChild("RaceV4") or remotes:FindFirstChild("Race_V4")
			if r then r:FireServer() end
		elseif Config["Auto Race V3"] then
			local r = remotes:FindFirstChild("ActivateRaceV3") or remotes:FindFirstChild("RaceTransformation") or remotes:FindFirstChild("Race_V3")
			if r then r:FireServer() end
		end
	end)
end

local function HopServer()
	State.status = "Sem alvos. Trocando servidor em 5s..."
	task.wait(5)
	SafeCall(function() TeleportService:Teleport(game.PlaceId) end)
end

local function BuildUI()
	SafeCall(function()
		for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
			if g.Name == "TRonVoidMainCard" or g.Name == "TRonVoidStatusBar" or g.Name == "TRonVoidToggleBtn" then
				g:Destroy()
			end
		end
	end)

	local blurFx  = Instance.new("BlurEffect")
	blurFx.Size   = 0
	blurFx.Parent = Lighting

	local CardGui        = Instance.new("ScreenGui")
	CardGui.Name         = "TRonVoidMainCard"
	CardGui.Parent       = game:GetService("CoreGui")
	CardGui.ResetOnSpawn = false
	CardGui.DisplayOrder = 20
	CardGui.Enabled      = false

	local ShadowHolder              = Instance.new("Frame")
	ShadowHolder.Parent             = CardGui
	ShadowHolder.AnchorPoint        = Vector2.new(0.5, 0.5)
	ShadowHolder.BackgroundTransparency = 1
	ShadowHolder.Position           = UDim2.new(0.5, 0, 0.5, 0)
	ShadowHolder.Size               = UDim2.new(0, 640, 0, 440)

	local DropShadow             = Instance.new("ImageLabel")
	DropShadow.Parent            = ShadowHolder
	DropShadow.AnchorPoint       = Vector2.new(0.5, 0.5)
	DropShadow.BackgroundTransparency = 1
	DropShadow.Position          = UDim2.new(0.5, 0, 0.5, 0)
	DropShadow.Size              = UDim2.new(1, 60, 1, 60)
	DropShadow.ZIndex            = 0
	DropShadow.Image             = "rbxassetid://6015897843"
	DropShadow.ImageColor3       = Color3.fromRGB(80, 0, 130)
	DropShadow.ImageTransparency = 0.2
	DropShadow.ScaleType         = Enum.ScaleType.Slice
	DropShadow.SliceCenter       = Rect.new(49, 49, 450, 450)

	local Main                  = Instance.new("Frame")
	Main.Name                   = "Main"
	Main.Parent                 = ShadowHolder
	Main.AnchorPoint            = Vector2.new(0.5, 0.5)
	Main.BackgroundColor3       = Color3.fromRGB(12, 0, 25)
	Main.BackgroundTransparency = 0.05
	Main.Position               = UDim2.new(0.5, 0, 0.5, 0)
	Main.Size                   = UDim2.new(1, -47, 1, -47)
	Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

	local Stroke     = Instance.new("UIStroke")
	Stroke.Color     = PURPLE
	Stroke.Thickness = 2.5
	Stroke.Parent    = Main

	local TitleLbl              = Instance.new("TextLabel")
	TitleLbl.Name               = "TitleLabel"
	TitleLbl.Parent             = Main
	TitleLbl.AnchorPoint        = Vector2.new(0.5, 0)
	TitleLbl.BackgroundTransparency = 1
	TitleLbl.Position           = UDim2.new(0.5, 0, 0.03, 0)
	TitleLbl.Size               = UDim2.new(0.92, 0, 0, 32)
	TitleLbl.FontFace           = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	TitleLbl.Text               = "TRon Void Hub Ez Bounty"
	TitleLbl.TextColor3         = PURPLE_LIGHT
	TitleLbl.TextSize           = 22
	TitleLbl.TextWrapped        = true

	local TitleGrad = Instance.new("UIGradient")
	TitleGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(210, 100, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 255)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(210, 100, 255)),
	}
	TitleGrad.Parent = TitleLbl

	local Div1            = Instance.new("Frame")
	Div1.BackgroundColor3 = PURPLE_MID
	Div1.BorderSizePixel  = 0
	Div1.Parent           = Main
	Div1.Position         = UDim2.new(0.04, 0, 0.18, 0)
	Div1.Size             = UDim2.new(0.92, 0, 0, 1)

	local ModeLbl               = Instance.new("TextLabel")
	ModeLbl.Name                = "ModeLabel"
	ModeLbl.Parent              = Main
	ModeLbl.BackgroundTransparency = 1
	ModeLbl.Position            = UDim2.new(0.04, 0, 0.21, 0)
	ModeLbl.Size                = UDim2.new(0.92, 0, 0, 22)
	ModeLbl.FontFace            = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	ModeLbl.Text                = "Mode: " .. Config["Mode"] .. "   |   Team: " .. Config["Team"]
	ModeLbl.TextColor3          = Color3.fromRGB(220, 170, 255)
	ModeLbl.TextSize            = 14
	ModeLbl.TextXAlignment      = Enum.TextXAlignment.Left

	local TargetLbl               = Instance.new("TextLabel")
	TargetLbl.Name                = "TargetLabel"
	TargetLbl.Parent              = Main
	TargetLbl.BackgroundTransparency = 1
	TargetLbl.Position            = UDim2.new(0.04, 0, 0.30, 0)
	TargetLbl.Size                = UDim2.new(0.92, 0, 0, 22)
	TargetLbl.FontFace            = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	TargetLbl.Text                = "Alvo Atual: Nenhum"
	TargetLbl.TextColor3          = Color3.fromRGB(255, 210, 80)
	TargetLbl.TextSize            = 14
	TargetLbl.TextXAlignment      = Enum.TextXAlignment.Left

	local StatusLbl               = Instance.new("TextLabel")
	StatusLbl.Name                = "StatusLabel"
	StatusLbl.Parent              = Main
	StatusLbl.BackgroundTransparency = 1
	StatusLbl.Position            = UDim2.new(0.04, 0, 0.39, 0)
	StatusLbl.Size                = UDim2.new(0.92, 0, 0, 22)
	StatusLbl.FontFace            = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	StatusLbl.Text                = "Status: Iniciando..."
	StatusLbl.TextColor3          = Color3.fromRGB(100, 255, 160)
	StatusLbl.TextSize            = 14
	StatusLbl.TextXAlignment      = Enum.TextXAlignment.Left
	StatusLbl.TextWrapped         = true

	local Div2            = Instance.new("Frame")
	Div2.BackgroundColor3 = PURPLE_MID
	Div2.BorderSizePixel  = 0
	Div2.Parent           = Main
	Div2.Position         = UDim2.new(0.04, 0, 0.49, 0)
	Div2.Size             = UDim2.new(0.92, 0, 0, 1)

	local ListHeader              = Instance.new("TextLabel")
	ListHeader.Parent             = Main
	ListHeader.BackgroundTransparency = 1
	ListHeader.Position           = UDim2.new(0.04, 0, 0.52, 0)
	ListHeader.Size               = UDim2.new(0.92, 0, 0, 18)
	ListHeader.FontFace           = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	ListHeader.Text               = "Jogadores com PvP Ativo (Fora da Safe Zone):"
	ListHeader.TextColor3         = PURPLE_LIGHT
	ListHeader.TextSize           = 13
	ListHeader.TextXAlignment     = Enum.TextXAlignment.Left

	local PlayerScroll                  = Instance.new("ScrollingFrame")
	PlayerScroll.Name                   = "PlayerScroll"
	PlayerScroll.Parent                 = Main
	PlayerScroll.BackgroundTransparency = 1
	PlayerScroll.Position               = UDim2.new(0.04, 0, 0.62, 0)
	PlayerScroll.Size                   = UDim2.new(0.92, 0, 0.32, 0)
	PlayerScroll.ScrollBarThickness     = 4
	PlayerScroll.ScrollBarImageColor3   = PURPLE
	PlayerScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
	PlayerScroll.BorderSizePixel        = 0

	local ListLayout     = Instance.new("UIListLayout")
	ListLayout.Parent    = PlayerScroll
	ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ListLayout.Padding   = UDim.new(0, 3)

	local StatusGui        = Instance.new("ScreenGui")
	StatusGui.Name         = "TRonVoidStatusBar"
	StatusGui.Parent       = game:GetService("CoreGui")
	StatusGui.ResetOnSpawn = false
	StatusGui.DisplayOrder = 10

	local SBarHolder                = Instance.new("Frame")
	SBarHolder.Parent               = StatusGui
	SBarHolder.AnchorPoint          = Vector2.new(0.5, 0)
	SBarHolder.BackgroundTransparency = 1
	SBarHolder.Position             = UDim2.new(0.5, 0, 0.03, 0)
	SBarHolder.Size                 = UDim2.new(0, 380, 0, 74)

	local SBarShadow             = Instance.new("ImageLabel")
	SBarShadow.Parent            = SBarHolder
	SBarShadow.AnchorPoint       = Vector2.new(0.5, 0.5)
	SBarShadow.BackgroundTransparency = 1
	SBarShadow.Position          = UDim2.new(0.5, 0, 0.5, 0)
	SBarShadow.Size              = UDim2.new(1, 47, 1, 47)
	SBarShadow.ZIndex            = 0
	SBarShadow.Image             = "rbxassetid://6015897843"
	SBarShadow.ImageColor3       = Color3.fromRGB(50, 0, 100)
	SBarShadow.ImageTransparency = 0.4
	SBarShadow.ScaleType         = Enum.ScaleType.Slice
	SBarShadow.SliceCenter       = Rect.new(49, 49, 450, 450)

	local SBarMain              = Instance.new("Frame")
	SBarMain.Parent             = SBarShadow
	SBarMain.AnchorPoint        = Vector2.new(0.5, 0.5)
	SBarMain.BackgroundColor3   = Color3.fromRGB(12, 0, 25)
	SBarMain.BackgroundTransparency = 0.05
	SBarMain.Position           = UDim2.new(0.5, 0, 0.5, 0)
	SBarMain.Size               = UDim2.new(1, -52, 1, -55)
	Instance.new("UICorner", SBarMain).CornerRadius = UDim.new(0, 8)

	local SBarStroke     = Instance.new("UIStroke")
	SBarStroke.Color     = PURPLE
	SBarStroke.Thickness = 2
	SBarStroke.Parent    = SBarMain

	local SBarTitle               = Instance.new("TextLabel")
	SBarTitle.Parent              = SBarMain
	SBarTitle.AnchorPoint         = Vector2.new(0.5, 0)
	SBarTitle.BackgroundTransparency = 1
	SBarTitle.Position            = UDim2.new(0.5, 0, 0, 5)
	SBarTitle.Size                = UDim2.new(0.96, 0, 0, 18)
	SBarTitle.FontFace            = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	SBarTitle.Text                = "TRon Void Hub Ez Bounty  |  Mode: " .. Config["Mode"]
	SBarTitle.TextColor3          = PURPLE_LIGHT
	SBarTitle.TextSize            = 14
	SBarTitle.TextWrapped         = true

	local SBarFarm               = Instance.new("TextLabel")
	SBarFarm.Name                = "SBarFarm"
	SBarFarm.Parent              = SBarMain
	SBarFarm.AnchorPoint         = Vector2.new(0.5, 0)
	SBarFarm.BackgroundTransparency = 1
	SBarFarm.Position            = UDim2.new(0.5, 0, 0, 26)
	SBarFarm.Size                = UDim2.new(0.96, 0, 0, 18)
	SBarFarm.FontFace            = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	SBarFarm.Text                = "Iniciando..."
	SBarFarm.TextColor3          = Color3.fromRGB(220, 180, 255)
	SBarFarm.TextSize            = 13
	SBarFarm.TextWrapped         = true

	local BtnGui          = Instance.new("ScreenGui")
	BtnGui.Name           = "TRonVoidToggleBtn"
	BtnGui.Parent         = game:GetService("CoreGui")
	BtnGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	BtnGui.DisplayOrder   = 30

	local BtnFrame            = Instance.new("Frame")
	BtnFrame.Parent           = BtnGui
	BtnFrame.AnchorPoint      = Vector2.new(0, 0)
	BtnFrame.BackgroundColor3 = PURPLE_DARK
	BtnFrame.Position         = UDim2.new(0, 18, 0.08, 0)
	BtnFrame.Size             = UDim2.new(0, 52, 0, 52)
	BtnFrame.Active           = true
	BtnFrame.Draggable        = true
	Instance.new("UICorner", BtnFrame).CornerRadius = UDim.new(1, 0)

	local BtnStroke     = Instance.new("UIStroke")
	BtnStroke.Color     = PURPLE_LIGHT
	BtnStroke.Thickness = 2.5
	BtnStroke.Parent    = BtnFrame

	local BtnImg              = Instance.new("ImageLabel")
	BtnImg.Parent             = BtnFrame
	BtnImg.AnchorPoint        = Vector2.new(0.5, 0.5)
	BtnImg.BackgroundTransparency = 1
	BtnImg.Position           = UDim2.new(0.5, 0, 0.5, 0)
	BtnImg.Size               = UDim2.new(0, 36, 0, 36)
	BtnImg.Image              = "rbxassetid://112485471724320"

	local BtnBtn              = Instance.new("TextButton")
	BtnBtn.Parent             = BtnFrame
	BtnBtn.BackgroundTransparency = 1
	BtnBtn.Size               = UDim2.new(1, 0, 1, 0)
	BtnBtn.Font               = Enum.Font.SourceSans
	BtnBtn.Text               = ""

	local TwI = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	BtnBtn.MouseButton1Click:Connect(function()
		CardGui.Enabled = not CardGui.Enabled
		blurFx.Size = CardGui.Enabled and 18 or 0
		TweenService:Create(BtnFrame, TwI, {
			BackgroundColor3 = CardGui.Enabled and PURPLE or PURPLE_DARK
		}):Play()
	end)

	task.spawn(function()
		while State.running do
			task.wait(1)
			SafeCall(function()
				StatusLbl.Text = "Status: " .. State.status
				SBarFarm.Text  = State.status
				TargetLbl.Text = "Alvo Atual: " .. State.targetName

				for _, c in ipairs(PlayerScroll:GetChildren()) do
					if c:IsA("TextLabel") then c:Destroy() end
				end

				local validList = GetValidTargets()
				for i, p in ipairs(validList) do
					local lv  = GetPlayerLevel(p)
					local row = Instance.new("TextLabel")
					row.Parent              = PlayerScroll
					row.BackgroundTransparency = 1
					row.Size                = UDim2.new(1, -6, 0, 17)
					row.LayoutOrder         = i
					row.FontFace            = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
					row.TextColor3          = (p == State.currentTarget) and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(200, 150, 255)
					row.TextSize            = 12
					row.TextXAlignment      = Enum.TextXAlignment.Left
					row.Text                = "  " .. p.DisplayName .. " (@" .. p.Name .. ")  Lv." .. lv .. (p == State.currentTarget and "  << ALVO" or "")
				end

				PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, #validList * 20)
			end)
		end
	end)
end

local function RunNormalMode()
	State.status = "Modo Normal ativo"

	while State.running do
		task.wait(0.12)
		if CheckSafeMode() then task.wait(0.5) continue end

		local targets = GetValidTargets()
		if #targets == 0 then
			State.currentTarget = nil
			State.targetName    = "Nenhum"
			State.status        = "Nenhum alvo valido no servidor"
			HopServer()
			continue
		end

		local target = GetNearestTarget(targets)
		if not target then continue end

		State.currentTarget = target
		State.targetName    = target.DisplayName .. " (@" .. target.Name .. ")"
		State.status        = "Indo ate: " .. State.targetName

		TeleportToPlayer(target)

		if not IsValidTarget(target) then
			State.status = "Alvo perdido, buscando proximo..."
			continue
		end

		State.status = "Atacando: " .. State.targetName

		while IsValidTarget(target) and State.running do
			task.wait(0.06)
			if CheckSafeMode() then break end

			local tchar = target.Character
			if not tchar then break end
			local thrp = tchar:FindFirstChild("HumanoidRootPart")
			if not thrp then break end
			local myHRP = GetMyHRP()
			if not myHRP then break end

			if (myHRP.Position - thrp.Position).Magnitude > 14 then
				TweenTo(thrp.Position)
			end

			UseSkills()

			State.hopTimer = State.hopTimer + 0.06
			if State.hopTimer >= Config["Auto Hop After"] then
				State.hopTimer = 0
				HopServer()
				break
			end
		end

		State.status = "Alvo perdido, buscando proximo..."
		task.wait(0.15)
	end
end

local function RunSwordMode()
	State.status = "Modo Sword - Carregando Koby Fast Attack..."
	LoadKobyAttack()
	StartFastAttackHeart()
	task.wait(2)

	State.status = "Modo Sword - Equipando espada..."
	EquipWeapon("Sword")
	task.wait(0.8)

	while State.running do
		task.wait(0.1)
		if CheckSafeMode() then task.wait(0.5) continue end

		local targets = GetValidTargets()
		if #targets == 0 then
			State.currentTarget = nil
			State.targetName    = "Nenhum"
			State.status        = "Nenhum alvo no servidor"
			HopServer()
			continue
		end

		State.status = "Modo Sword - Teleportando para todos os alvos..."

		for _, target in ipairs(targets) do
			if not State.running or CheckSafeMode() then break end
			if not IsValidTarget(target) then continue end

			State.currentTarget = target
			State.targetName    = target.DisplayName .. " (@" .. target.Name .. ")"
			State.status        = "Sword -> " .. State.targetName

			InstantTeleportToPlayer(target)
			task.wait(0.04)
			UseSkills()
			task.wait(0.04)
		end

		State.status = "Aguardando 6s para re-entrar no time..."
		local waitStart = tick()
		while tick() - waitStart < 6 do
			task.wait(0.3)
			if CheckSafeMode() then break end
		end

		JoinTeam(Config["Team"])
		EquipWeapon("Sword")

		State.hopTimer = State.hopTimer + 6
		if State.hopTimer >= Config["Auto Hop After"] then
			State.hopTimer = 0
			HopServer()
		end
	end
end

local function RunGunMode()
	State.status = "Modo Gun - Configurando Fast Shot Gun..."
	SetupGunNet()
	task.wait(1)

	State.status = "Modo Gun - Equipando arma..."
	EquipWeapon("Gun")
	task.wait(0.8)

	local gunLoopActive = true
	task.spawn(function()
		while gunLoopActive and State.running do
			task.wait(0.05)
			if State.retreating then continue end
			local char = GetMyChar()
			if not char then continue end
			local tool = char:FindFirstChildOfClass("Tool")
			if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then continue end
			local tgt = GetNearestGunTarget()
			if tgt then FireGunShot(tgt) end
		end
	end)

	while State.running do
		task.wait(0.12)
		if CheckSafeMode() then task.wait(0.5) continue end

		local targets = GetValidTargets()
		if #targets == 0 then
			State.currentTarget = nil
			State.targetName    = "Nenhum"
			State.status        = "Nenhum alvo no servidor"
			gunLoopActive       = false
			HopServer()
			continue
		end

		local target = GetNearestTarget(targets)
		if not target then continue end

		State.currentTarget = target
		State.targetName    = target.DisplayName .. " (@" .. target.Name .. ")"
		State.status        = "Gun Mode - Indo ate: " .. State.targetName

		TeleportToPlayer(target)

		if not IsValidTarget(target) then
			State.status = "Alvo perdido, buscando proximo..."
			continue
		end

		EquipWeapon("Gun")
		State.status = "Atirando em: " .. State.targetName

		while IsValidTarget(target) and State.running do
			task.wait(0.06)
			if CheckSafeMode() then break end

			local tchar = target.Character
			if not tchar then break end
			local thrp = tchar:FindFirstChild("HumanoidRootPart")
			if not thrp then break end
			local myHRP = GetMyHRP()
			if not myHRP then break end

			if (myHRP.Position - thrp.Position).Magnitude > 35 then
				TweenTo(thrp.Position)
			end

			UseSkills()

			State.hopTimer = State.hopTimer + 0.06
			if State.hopTimer >= Config["Auto Hop After"] then
				State.hopTimer  = 0
				gunLoopActive   = false
				HopServer()
				break
			end
		end

		State.status = "Alvo perdido, buscando proximo..."
		task.wait(0.15)
	end

	gunLoopActive = false
end

task.spawn(function()
	repeat task.wait(0.1) until game:IsLoaded()
	repeat task.wait(0.1) until LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")

	State.status = "Iniciando TRon Void Hub Ez Bounty..."
	task.wait(1.5)

	JoinTeam(Config["Team"])

	State.status = "Carregando Interface..."
	BuildUI()
	task.wait(0.5)

	if Config["Fix Lag"] then
		ApplyFixLag()
		task.wait(0.5)
	end

	if Config["Auto Race V3"] or Config["Auto Race V4"] then
		State.status = "Ativando Raca..."
		ActivateRace()
		task.wait(0.5)
	end

	State.status = "Carregando dados dos jogadores do servidor..."
	task.wait(1)

	State.status = "Pronto! Iniciando Modo: " .. Config["Mode"]
	task.wait(0.5)

	if Config["Mode"] == "Normal" then
		RunNormalMode()
	elseif Config["Mode"] == "Sword" then
		RunSwordMode()
	elseif Config["Mode"] == "Gun" then
		RunGunMode()
	else
		State.status = "Modo invalido na config: " .. tostring(Config["Mode"])
	end
end)

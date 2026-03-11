repeat wait() until game:IsLoaded() and game.Players.LocalPlayer:FindFirstChild("DataLoaded")
if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)") then
    repeat
        wait()
        game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("SetTeam", getgenv().team)
        task.wait(3)
    until not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)")
end
repeat task.wait() until game.Players.LocalPlayer.PlayerGui:FindFirstChild("Main")

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleSvc      = game:GetService("TeleportService")
local HttpSvc      = game:GetService("HttpService")
local UserInput    = game:GetService("UserInputService")
local lp           = Players.LocalPlayer
local ch           = function() return lp.Character end

local HOP_INTERVAL = 300
local RAID_DIST    = 300
local ServerBlacklist = {}

local ST = {
    bountyEarned = 0,
    lastBounty   = 0,
    targIdx      = 1,
    hopTimer     = 0,
    escapingZone = false,
}

local function getCurrentBounty()
    local ok, v = pcall(function() return lp.Data.Bounty.Value end)
    return ok and v or 0
end

local function getTeamName()
    return lp.Team and lp.Team.Name or "None"
end

local function getPVPCount()
    local n = 0
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if p.Character:FindFirstChild("PVP") or
                       (p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("PVP")) then
                        n += 1
                    end
                end
            end
        end
    end)
    return n
end

local function inSafe(hrp)
    local r = false
    pcall(function()
        local wo = workspace["_WorldOrigin"]
        if wo and wo:FindFirstChild("SafeZones") then
            for _, v in pairs(wo.SafeZones:GetChildren()) do
                if v:IsA("BasePart") and (v.Position - hrp.Position).Magnitude <= 450 then r = true return end
            end
        end
        if r then return end
        local g = lp.PlayerGui:FindFirstChild("Main") if not g then return end
        for _, n in ipairs({"SafeZone","[OLD]SafeZone"}) do
            local f = g:FindFirstChild(n)
            if f and f.Visible then r = true return end
        end
    end)
    return r
end

local function checkRaid(plr)
    local r = false
    pcall(function()
        local wo = workspace["_WorldOrigin"] if not wo then return end
        local locs = wo:FindFirstChild("Locations") if not locs then return end
        local isl  = locs:FindFirstChild("Island 1") if not isl then return end
        local hrp  = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - isl.Position).Magnitude < RAID_DIST then r = true end
    end)
    return r
end

local function hopServer()
    local ok = pcall(function()
        table.insert(ServerBlacklist, game.JobId)
        local data = HttpSvc:JSONDecode(game:HttpGet(
            ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(game.PlaceId)))
        local Z
        local function notBL(id)
            for _, b in ipairs(ServerBlacklist) do if b == id then return false end end
            return true
        end
        for _, s in ipairs(data.data) do
            if s.playing and s.maxPlayers and s.playing > 5 and s.playing < s.maxPlayers - 2 and notBL(s.id) then
                Z = s break
            end
        end
        if not Z then
            for _, s in ipairs(data.data) do
                if s.playing and s.maxPlayers and s.playing > 10 and s.playing < s.maxPlayers and notBL(s.id) then
                    Z = s break
                end
            end
        end
        if not Z and #data.data > 0 then
            for _, s in ipairs(data.data) do if notBL(s.id) then Z = s break end end
        end
        if not Z and #data.data > 0 then Z = data.data[1] end
        if Z and Z.id then TeleSvc:TeleportToPlaceInstance(game.PlaceId, Z.id)
        else TeleSvc:Teleport(game.PlaceId) end
    end)
    if not ok then TeleSvc:Teleport(game.PlaceId) end
end

local function onKick()
    task.spawn(function()
        local ok = pcall(hopServer)
        if not ok then pcall(function() TeleSvc:Teleport(game.PlaceId) end) end
    end)
end

lp.AncestryChanged:Connect(function(_, p) if not p then onKick() end end)
Players.PlayerRemoving:Connect(function(p) if p == lp then onKick() end end)
lp.OnTeleport:Connect(function(s) if s == Enum.TeleportState.Failed then onKick() end end)
game:BindToClose(onKick)

pcall(function()
    local oldClose = game.Close
    game.Close = function(...)
        onKick()
        return oldClose(...)
    end
end)

task.spawn(function()
    local wasConnected = true
    while true do
        task.wait(2)
        local ok = pcall(function() Players:GetPlayers() end)
        if not ok and wasConnected then
            wasConnected = false
            onKick()
        elseif ok then
            wasConnected = true
        end
    end
end)

local statusTxt

local function escapeAndTeleport(targ)
    if ST.escapingZone then return end
    local myC = ch()
    local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    ST.escapingZone = true
    local hum = myC:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true hum.AutoRotate = false end
    local startY = myHRP.Position.Y
    local targetY = startY + 2500
    local t0 = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local c2 = ch()
        local hrp = c2 and c2:FindFirstChild("HumanoidRootPart")
        if not hrp then conn:Disconnect() ST.escapingZone = false return end
        local a = math.min((tick() - t0) / 1.4, 1)
        hrp.CFrame = CFrame.new(hrp.Position.X, startY + (targetY - startY) * (1-(1-a)^3), hrp.Position.Z)
        if a >= 1 then
            conn:Disconnect()
            local h2 = c2:FindFirstChild("Humanoid")
            if h2 then h2.PlatformStand = false h2.AutoRotate = true end
            local thrp = targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart")
            if thrp then pcall(function() hrp.CFrame = thrp.CFrame * CFrame.new(0,2,3) getgenv().targ = targ end) end
            ST.escapingZone = false
        end
    end)
    task.spawn(function()
        task.wait(0.5)
        if not ST.escapingZone then return end
        local thrp = targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart")
        local hrp2 = ch() and ch():FindFirstChild("HumanoidRootPart")
        if thrp and hrp2 and not inSafe(thrp) then
            conn:Disconnect()
            local h3 = ch() and ch():FindFirstChild("Humanoid")
            if h3 then h3.PlatformStand = false h3.AutoRotate = true end
            pcall(function() hrp2.CFrame = thrp.CFrame * CFrame.new(0,2,3) end)
            getgenv().targ = targ
            ST.escapingZone = false
        end
    end)
end

task.spawn(function()
    repeat task.wait() until game:IsLoaded() and lp.Character
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/AnhDangNhoEm/TuanAnhIOS/refs/heads/main/koby"))()
    end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local c = ch() if not c then return end
            local hum = c:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local cf = game.ReplicatedStorage:FindFirstChild("Remotes") and
                       game.ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if not cf then return end
            cf:InvokeServer("BusoHaki", true)
            cf:InvokeServer("KenbunHaki", true)
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            local c = ch() if not c then return end
            local tool = c:FindFirstChildOfClass("Tool")
            if tool and tool.ToolTip == "Blox Fruit" then return end
            local bp = lp:FindFirstChild("Backpack") if not bp then return end
            for _, item in ipairs(bp:GetChildren()) do
                if item:IsA("Tool") and item.ToolTip == "Blox Fruit" then
                    c:FindFirstChildOfClass("Humanoid"):EquipTool(item) return
                end
            end
        end)
    end
end)

local lockConn, charConn, searching = nil, nil, false

local function showNotif(name)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "⚡ TRon Void  |  Alvo",
            Text  = "Atacando: " .. name,
            Duration = 4,
        })
    end)
end

local function getValidTargets()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 and not inSafe(hrp) and not checkRaid(p) then
                table.insert(list, p)
            end
        end
    end
    return list
end

local lockOnTarget
lockOnTarget = function(targ)
    if not targ or not targ.Character then return end
    local thrp = targ.Character:FindFirstChild("HumanoidRootPart") if not thrp then return end
    local myC = ch()
    local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")
    if myHRP then pcall(function() myHRP.CFrame = thrp.CFrame * CFrame.new(0,2,3) end) end
    getgenv().targ = targ
    showNotif(targ.Name)
    local function onDeath()
        if lockConn then lockConn:Disconnect() lockConn = nil end
        if charConn then charConn:Disconnect() charConn = nil end
        task.wait(0.2)
        getgenv().targ = nil
        ST.targIdx += 1
        task.spawn(function()
            local list = getValidTargets()
            if #list == 0 then searching = true repeat task.wait(1) list = getValidTargets() until #list > 0 searching = false end
            lockOnTarget(list[(ST.targIdx - 1) % #list + 1])
        end)
    end
    local hum = targ.Character:FindFirstChild("Humanoid")
    if hum then lockConn = hum.Died:Connect(onDeath) end
    charConn = targ.CharacterRemoving:Connect(function()
        if getgenv().targ == targ then onDeath() end
    end)
end

task.spawn(function()
    repeat task.wait() until game:IsLoaded() and lp.Character
    task.wait(3)
    local list = getValidTargets()
    if #list == 0 then searching = true repeat task.wait(1) list = getValidTargets() until #list > 0 searching = false end
    lockOnTarget(list[1])
end)

task.spawn(function()
    while true do
        task.wait(1)
        local targ = getgenv().targ
        if not targ or not targ.Character then continue end
        local myC = ch()
        local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")
        local thrp = targ.Character:FindFirstChild("HumanoidRootPart")
        local hum  = targ.Character:FindFirstChild("Humanoid")

        local myHRP_safe = myHRP and inSafe(myHRP)
        if myHRP_safe and not ST.escapingZone then
            local list = getValidTargets()
            task.spawn(function() escapeAndTeleport(#list > 0 and list[1] or nil) end)
        elseif myHRP and thrp and hum and hum.Health > 0 then
            pcall(function() myHRP.CFrame = thrp.CFrame * CFrame.new(0,2,3) end)
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local targ = getgenv().targ
    if not targ or not targ.Character then return end
    local c = ch() if not c then return end
    local tool = c:FindFirstChildOfClass("Tool")
    if not tool or tool.ToolTip ~= "Blox Fruit" then return end
    local th = targ.Character:FindFirstChild("HumanoidRootPart") if not th then return end
    if inSafe(th) or checkRaid(targ) then return end
    local lcr = tool:FindFirstChild("LeftClickRemote") if not lcr then return end
    lcr:FireServer(Vector3.new(0.01,-500,0.01), 1, true)
    lcr:FireServer(false)
end)

task.spawn(function()
    while true do
        task.wait(1)
        ST.hopTimer += 1
        if ST.hopTimer >= HOP_INTERVAL then
            ST.hopTimer = 0
            task.spawn(hopServer)
        end
        local cur = getCurrentBounty()
        local d = cur - ST.lastBounty
        if d > 0 then ST.bountyEarned += d end
        ST.lastBounty = cur
    end
end)

local guiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local sg = Instance.new("ScreenGui")
sg.Name = "AutoBountyUI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = guiParent

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 300, 0, 270)
main.Position = UDim2.new(0.5, -150, 0.5, -135)
main.BackgroundColor3 = Color3.fromRGB(8, 4, 18)
main.BorderSizePixel = 0
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local ms = Instance.new("UIStroke", main)
ms.Color = Color3.fromRGB(90, 0, 160)
ms.Thickness = 2

local dragging, dragStart, startPos = false, nil, nil
main.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true dragStart=i.Position startPos=main.Position end end)
main.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end end)
UserInput.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)

local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1,0,0,40)
titleBar.BackgroundColor3 = Color3.fromRGB(18,0,40)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,12)
local tcFix = Instance.new("Frame", titleBar)
tcFix.Size = UDim2.new(1,0,0.5,0) tcFix.Position = UDim2.new(0,0,0.5,0)
tcFix.BackgroundColor3 = Color3.fromRGB(18,0,40) tcFix.BorderSizePixel = 0

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(0.72,0,1,0) titleLbl.Position = UDim2.new(0,14,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "⚡ AUTO BOUNTY M1  |  TRon Void"
titleLbl.TextColor3 = Color3.fromRGB(190,90,255) titleLbl.TextSize = 12
titleLbl.Font = Enum.Font.GothamBold titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local sPill = Instance.new("Frame", titleBar)
sPill.Size = UDim2.new(0,66,0,18) sPill.Position = UDim2.new(1,-74,0.5,-9)
sPill.BackgroundColor3 = Color3.fromRGB(50,0,100) sPill.BorderSizePixel = 0
Instance.new("UICorner", sPill).CornerRadius = UDim.new(1,0)
statusTxt = Instance.new("TextLabel", sPill)
statusTxt.Size = UDim2.new(1,0,1,0) statusTxt.BackgroundTransparency = 1
statusTxt.Text = "● ATIVO" statusTxt.TextColor3 = Color3.fromRGB(185,80,255)
statusTxt.TextSize = 10 statusTxt.Font = Enum.Font.GothamBold
TweenService:Create(sPill, TweenInfo.new(1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
    {BackgroundColor3 = Color3.fromRGB(85,0,165)}):Play()

local infoFrame = Instance.new("Frame", main)
infoFrame.Size = UDim2.new(1,-18,0,170)
infoFrame.Position = UDim2.new(0,9,0,50)
infoFrame.BackgroundColor3 = Color3.fromRGB(13,4,28)
infoFrame.BorderSizePixel = 0
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0,10)
local ifs = Instance.new("UIStroke", infoFrame)
ifs.Color = Color3.fromRGB(50,0,100) ifs.Thickness = 1

local function makeRow(y, icon, label)
    local row = Instance.new("Frame", infoFrame)
    row.Size = UDim2.new(1,-16,0,28) row.Position = UDim2.new(0,8,0,y)
    row.BackgroundTransparency = 1
    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1,0,0,1) sep.Position = UDim2.new(0,0,1,-1)
    sep.BackgroundColor3 = Color3.fromRGB(35,0,70) sep.BorderSizePixel = 0
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.56,0,1,0) lbl.BackgroundTransparency = 1
    lbl.Text = icon.." "..label lbl.TextColor3 = Color3.fromRGB(135,65,185)
    lbl.TextSize = 11 lbl.Font = Enum.Font.GothamSemibold lbl.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", row)
    val.Size = UDim2.new(0.44,0,1,0) val.Position = UDim2.new(0.56,0,0,0)
    val.BackgroundTransparency = 1 val.Text = "—"
    val.TextColor3 = Color3.fromRGB(220,165,255) val.TextSize = 11
    val.Font = Enum.Font.GothamBold val.TextXAlignment = Enum.TextXAlignment.Right
    return val
end

local valBounty = makeRow(6,   "💰", "Bounty Atual")
local valTeam   = makeRow(38,  "🏴", "Team")
local valPVP    = makeRow(70,  "⚔",  "PVP Fora Zona")
local valEarned = makeRow(102, "📈", "Bounty Farmado")
local valTimer  = makeRow(134, "⏱",  "Próx. Hop")

local resetBtn = Instance.new("TextButton", main)
resetBtn.Size = UDim2.new(1,-18,0,34)
resetBtn.Position = UDim2.new(0,9,0,230)
resetBtn.BackgroundColor3 = Color3.fromRGB(18,0,40)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "🔄  Reset Bounty Earned"
resetBtn.TextColor3 = Color3.fromRGB(175,85,255)
resetBtn.TextSize = 12 resetBtn.Font = Enum.Font.GothamSemibold
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0,10)
local rbs = Instance.new("UIStroke", resetBtn)
rbs.Color = Color3.fromRGB(90,0,160) rbs.Thickness = 1
resetBtn.MouseButton1Click:Connect(function()
    ST.bountyEarned = 0
    TweenService:Create(resetBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(55,0,115)}):Play()
    task.wait(0.12)
    TweenService:Create(resetBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(18,0,40)}):Play()
end)

RunService.Heartbeat:Connect(function()
    valBounty.Text = tostring(getCurrentBounty())
    valTeam.Text   = getTeamName()
    valPVP.Text    = tostring(getPVPCount())
    valEarned.Text = tostring(ST.bountyEarned)
    local rem = HOP_INTERVAL - ST.hopTimer
    valTimer.Text  = ("%d:%02d"):format(math.floor(rem/60), rem%60)
    statusTxt.Text = ST.escapingZone and "🟡 SAINDO ZONA" or "● ATIVO"
end)

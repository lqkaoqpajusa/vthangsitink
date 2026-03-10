repeat wait() until game:IsLoaded() and game.Players.LocalPlayer:FindFirstChild("DataLoaded")
if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)") then
    repeat
        wait()
        local l_Remotes_0 = game.ReplicatedStorage:WaitForChild("Remotes")
        l_Remotes_0.CommF_:InvokeServer("SetTeam", getgenv().team)
        task.wait(3)
    until not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)")
end
repeat task.wait() until game.Players.LocalPlayer.PlayerGui:FindFirstChild("Main")

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleSvc      = game:GetService("TeleportService")
local HttpSvc      = game:GetService("HttpService")
local lp           = Players.LocalPlayer
local char         = function() return lp.Character end

local CFG = {
    TELEPORT_INTERVAL = 5,
    HOP_INTERVAL      = 300,
    RAID_DIST         = 300,
}

local ST = {
    farmOn       = false,
    hopOn        = false,
    bountyEarned = 0,
    lastBounty   = 0,
    targIdx      = 1,
    hopTimer     = 0,
    wasKicked    = false,
}

local ServerBlacklist = {}

local function getInitialBounty()
    local ok, val = pcall(function()
        return lp:WaitForChild("Data"):WaitForChild("Bounty").Value
    end)
    return ok and val or 0
end

ST.lastBounty = getInitialBounty()

local function getCurrentBounty()
    local ok, val = pcall(function()
        return lp.Data.Bounty.Value
    end)
    return ok and val or 0
end

local function getTeamName()
    return lp.Team and lp.Team.Name or "None"
end

local function getPVPCount()
    local count = 0
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local pvpTag = p.Character:FindFirstChild("PVP") or
                                   (p.PlayerGui:FindFirstChild("Main") and
                                    p.PlayerGui.Main:FindFirstChild("PVP"))
                    if pvpTag then count = count + 1 end
                end
            end
        end
    end)
    return count
end

local function inSafe(hrp)
    local r = false
    pcall(function()
        local wo = workspace["_WorldOrigin"]
        if wo and wo:FindFirstChild("SafeZones") then
            for _, v in pairs(wo.SafeZones:GetChildren()) do
                if v:IsA("BasePart") and (v.Position - hrp.Position).Magnitude <= 450 then
                    r = true; return
                end
            end
        end
        if r then return end
        local main = lp.PlayerGui:FindFirstChild("Main"); if not main then return end
        for _, n in ipairs({"SafeZone", "[OLD]SafeZone"}) do
            local f = main:FindFirstChild(n)
            if f and f.Visible then r = true; return end
        end
    end)
    return r
end

local function checkRaid(plr)
    local r = false
    pcall(function()
        local wo   = workspace["_WorldOrigin"]; if not wo then return end
        local locs = wo:FindFirstChild("Locations"); if not locs then return end
        local isl  = locs:FindFirstChild("Island 1"); if not isl then return end
        local hrp  = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - isl.Position).Magnitude < CFG.RAID_DIST then r = true end
    end)
    return r
end

local function hopServer()
    local T, U = pcall(function()
        local jobId  = game.JobId
        table.insert(ServerBlacklist, jobId)
        local url  = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)
        local data = HttpSvc:JSONDecode(game:HttpGet(url))
        local Z    = nil
        for _, s in ipairs(data.data) do
            if s.playing and s.maxPlayers and s.playing > 5 and s.playing < s.maxPlayers - 2 then
                local bad = false
                for _, bl in ipairs(ServerBlacklist) do if bl == s.id then bad = true; break end end
                if not bad then Z = s; break end
            end
        end
        if not Z then
            for _, s in ipairs(data.data) do
                if s.playing and s.maxPlayers and s.playing > 10 and s.playing < s.maxPlayers then
                    local bad = false
                    for _, bl in ipairs(ServerBlacklist) do if bl == s.id then bad = true; break end end
                    if not bad then Z = s; break end
                end
            end
        end
        if not Z and #data.data > 0 then
            for _, s in ipairs(data.data) do
                local bad = false
                for _, bl in ipairs(ServerBlacklist) do if bl == s.id then bad = true; break end end
                if not bad then Z = s; break end
            end
        end
        if not Z and #data.data > 0 then Z = data.data[1] end
        if Z and Z.id then
            TeleSvc:TeleportToPlaceInstance(game.PlaceId, Z.id)
        else
            TeleSvc:Teleport(game.PlaceId)
        end
    end)
    if not T or U then TeleSvc:Teleport(game.PlaceId) end
end

TeleSvc.LocalPlayerArrivedFromTeleport:Connect(function()
    ST.wasKicked = false
end)

game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then
        if ST.hopOn then task.spawn(hopServer) end
    end
end)

pcall(function()
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        if ST.hopOn then task.spawn(hopServer) end
    end)
end)

task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    repeat task.wait() until lp and lp.Character
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/AnhDangNhoEm/TuanAnhIOS/refs/heads/main/koby"))()
    end)
    if not ok then warn("Fast Attack load failed:", err) end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if ST.farmOn then
            local c = char()
            if c then
                pcall(function()
                    local hum = c:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        local busoPart = c:FindFirstChild("BusoHaki") or c:FindFirstChild("Buso")
                        if not busoPart then
                            local remote = game.ReplicatedStorage:FindFirstChild("Remotes")
                            if remote then
                                local cf = remote:FindFirstChild("CommF_")
                                if cf then
                                    cf:InvokeServer("BusoHaki", true)
                                end
                            end
                        end
                        local kenPart = c:FindFirstChild("KenbunHaki") or c:FindFirstChild("Ken")
                        if not kenPart then
                            local remote = game.ReplicatedStorage:FindFirstChild("Remotes")
                            if remote then
                                local cf = remote:FindFirstChild("CommF_")
                                if cf then
                                    cf:InvokeServer("KenbunHaki", true)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(CFG.TELEPORT_INTERVAL)
        if not ST.farmOn then continue end
        local plrList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and not inSafe(hrp) and not checkRaid(p) then
                    table.insert(plrList, p)
                end
            end
        end
        if #plrList == 0 then continue end
        ST.targIdx = (ST.targIdx % #plrList) + 1
        local targ = plrList[ST.targIdx]
        if targ and targ.Character then
            local thrp = targ.Character:FindFirstChild("HumanoidRootPart")
            local myC  = char()
            local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")
            if thrp and myHRP then
                pcall(function()
                    myHRP.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 3, 0))
                end)
                getgenv().targ = targ
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not ST.farmOn then return end
    pcall(function()
        local targ = getgenv().targ
        if not targ or not targ.Character then return end
        local c    = char(); if not c then return end
        local tool = c:FindFirstChildOfClass("Tool")
        if not tool or tool.ToolTip ~= "Blox Fruit" then return end
        local th   = targ.Character:FindFirstChild("HumanoidRootPart"); if not th then return end
        if inSafe(th) or checkRaid(targ) then return end
        local lcr  = tool:FindFirstChild("LeftClickRemote"); if not lcr then return end
        lcr:FireServer(Vector3.new(0.01, -500, 0.01), 1, true)
        lcr:FireServer(false)
    end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        if ST.farmOn then
            ST.hopTimer = ST.hopTimer + 1
            if ST.hopTimer >= CFG.HOP_INTERVAL then
                ST.hopTimer = 0
                task.spawn(hopServer)
            end
        end
        local cur   = getCurrentBounty()
        local delta = cur - ST.lastBounty
        if delta > 0 then
            ST.bountyEarned = ST.bountyEarned + delta
        end
        ST.lastBounty = cur
    end
end)

local sg   = Instance.new("ScreenGui")
sg.Name    = "AutoBountyUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent  = lp.PlayerGui

local main = Instance.new("Frame")
main.Size  = UDim2.new(0, 320, 0, 400)
main.Position = UDim2.new(0.5, -160, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(8, 4, 18)
main.BorderSizePixel  = 0
main.Active = true
main.Draggable = true
main.Parent   = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main

local border = Instance.new("UIStroke")
border.Color     = Color3.fromRGB(90, 0, 160)
border.Thickness = 2
border.Parent    = main

local glow = Instance.new("ImageLabel")
glow.Size  = UDim2.new(1.3, 0, 1.3, 0)
glow.Position = UDim2.new(-0.15, 0, -0.15, 0)
glow.BackgroundTransparency = 1
glow.Image  = "rbxassetid://5028857084"
glow.ImageColor3 = Color3.fromRGB(90, 0, 160)
glow.ImageTransparency = 0.7
glow.ZIndex = 0
glow.Parent = main

local titleBar = Instance.new("Frame")
titleBar.Size  = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
titleBar.BorderSizePixel  = 0
titleBar.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleFix = Instance.new("Frame")
titleFix.Size  = UDim2.new(1, 0, 0.5, 0)
titleFix.Position = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
titleFix.BorderSizePixel  = 0
titleFix.Parent = titleBar

local titleLbl = Instance.new("TextLabel")
titleLbl.Size  = UDim2.new(1, -10, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text  = "⚡ AUTO BOUNTY M1  |  TRon Void"
titleLbl.TextColor3 = Color3.fromRGB(200, 100, 255)
titleLbl.TextSize   = 13
titleLbl.Font       = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = titleBar

local infoFrame = Instance.new("Frame")
infoFrame.Size  = UDim2.new(1, -20, 0, 160)
infoFrame.Position = UDim2.new(0, 10, 0, 48)
infoFrame.BackgroundColor3 = Color3.fromRGB(14, 5, 30)
infoFrame.BorderSizePixel  = 0
infoFrame.Parent = main

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoFrame

local infoStroke = Instance.new("UIStroke")
infoStroke.Color     = Color3.fromRGB(60, 0, 110)
infoStroke.Thickness = 1
infoStroke.Parent    = infoFrame

local function makeInfoLabel(yPos, labelText)
    local row = Instance.new("Frame")
    row.Size  = UDim2.new(1, -16, 0, 32)
    row.Position = UDim2.new(0, 8, 0, yPos)
    row.BackgroundTransparency = 1
    row.Parent = infoFrame

    local lbl = Instance.new("TextLabel")
    lbl.Size  = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text  = labelText
    lbl.TextColor3 = Color3.fromRGB(150, 80, 200)
    lbl.TextSize   = 11
    lbl.Font       = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.Size  = UDim2.new(0.5, 0, 1, 0)
    val.Position = UDim2.new(0.5, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text  = "—"
    val.TextColor3 = Color3.fromRGB(230, 180, 255)
    val.TextSize   = 11
    val.Font       = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = row

    return val
end

local valBounty  = makeInfoLabel(4,  "💰 Bounty Atual")
local valTeam    = makeInfoLabel(36, "🏴 Team")
local valPVP     = makeInfoLabel(68, "⚔ PVP Fora Zona")
local valEarned  = makeInfoLabel(100, "📈 Bounty Farmado")
local valTimer   = makeInfoLabel(132, "⏱ Próx. Hop")

local function makeToggle(yPos, label, callback)
    local frame = Instance.new("Frame")
    frame.Size  = UDim2.new(1, -20, 0, 44)
    frame.Position = UDim2.new(0, 10, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(14, 5, 30)
    frame.BorderSizePixel  = 0
    frame.Parent = main

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 8)
    fc.Parent = frame

    local fs = Instance.new("UIStroke")
    fs.Color     = Color3.fromRGB(60, 0, 110)
    fs.Thickness = 1
    fs.Parent    = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size  = UDim2.new(0.65, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text  = label
    lbl.TextColor3 = Color3.fromRGB(200, 140, 255)
    lbl.TextSize   = 11
    lbl.Font       = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local pill = Instance.new("Frame")
    pill.Size  = UDim2.new(0, 46, 0, 22)
    pill.Position = UDim2.new(1, -56, 0.5, -11)
    pill.BackgroundColor3 = Color3.fromRGB(40, 10, 70)
    pill.BorderSizePixel  = 0
    pill.Parent = frame

    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(1, 0)
    pc.Parent = pill

    local knob = Instance.new("Frame")
    knob.Size  = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
    knob.BorderSizePixel  = 0
    knob.Parent = pill

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local state = false

    local function setVisual(on)
        local target = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local col    = on and Color3.fromRGB(140, 0, 255) or Color3.fromRGB(90, 0, 160)
        local pillC  = on and Color3.fromRGB(60, 0, 120) or Color3.fromRGB(40, 10, 70)
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = target, BackgroundColor3 = col}):Play()
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = pillC}):Play()
    end

    frame.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            setVisual(state)
            callback(state)
        end
    end)

    return frame, function() return state end
end

local mainToggle, getMainState = makeToggle(222, "🎯 Auto Farm Bounty", function(on)
    ST.farmOn   = on
    ST.hopTimer = 0
end)

local hopToggle, getHopState = makeToggle(274, "🌐 Hop Server (11/12)", function(on)
    ST.hopOn = on
end)

local resetBtn = Instance.new("TextButton")
resetBtn.Size  = UDim2.new(1, -20, 0, 36)
resetBtn.Position = UDim2.new(0, 10, 0, 326)
resetBtn.BackgroundColor3 = Color3.fromRGB(20, 0, 45)
resetBtn.BorderSizePixel  = 0
resetBtn.Text  = "🔄 Reset Bounty Earned"
resetBtn.TextColor3 = Color3.fromRGB(180, 90, 255)
resetBtn.TextSize   = 12
resetBtn.Font       = Enum.Font.GothamSemibold
resetBtn.Parent = main

local rbc = Instance.new("UICorner")
rbc.CornerRadius = UDim.new(0, 8)
rbc.Parent = resetBtn

local rbs = Instance.new("UIStroke")
rbs.Color     = Color3.fromRGB(90, 0, 160)
rbs.Thickness = 1
rbs.Parent    = resetBtn

resetBtn.MouseButton1Click:Connect(function()
    ST.bountyEarned = 0
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(60, 0, 120)}):Play()
    task.wait(0.15)
    TweenService:Create(resetBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 0, 45)}):Play()
end)

local statusDot = Instance.new("Frame")
statusDot.Size  = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 10, 0, 378)
statusDot.BackgroundColor3 = Color3.fromRGB(90, 0, 160)
statusDot.BorderSizePixel  = 0
statusDot.Parent = main
local sdc = Instance.new("UICorner"); sdc.CornerRadius = UDim.new(1,0); sdc.Parent = statusDot

local statusLbl = Instance.new("TextLabel")
statusLbl.Size  = UDim2.new(1, -26, 0, 16)
statusLbl.Position = UDim2.new(0, 24, 0, 374)
statusLbl.BackgroundTransparency = 1
statusLbl.Text  = "Aguardando..."
statusLbl.TextColor3 = Color3.fromRGB(120, 60, 180)
statusLbl.TextSize   = 10
statusLbl.Font       = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = main

local dotTween = TweenService:Create(statusDot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {BackgroundColor3 = Color3.fromRGB(180, 0, 255)})
dotTween:Play()

RunService.Heartbeat:Connect(function()
    local cur = getCurrentBounty()
    valBounty.Text   = tostring(cur)
    valTeam.Text     = getTeamName()
    valPVP.Text      = tostring(getPVPCount())
    valEarned.Text   = tostring(ST.bountyEarned)
    local remaining  = CFG.HOP_INTERVAL - ST.hopTimer
    valTimer.Text    = string.format("%d:%02d", math.floor(remaining/60), remaining%60)
    if ST.farmOn then
        statusLbl.Text = "🟣 Farmando..."
        statusDot.BackgroundColor3 = Color3.fromRGB(140, 0, 255)
    else
        statusLbl.Text = "⚫ Parado"
        statusDot.BackgroundColor3 = Color3.fromRGB(60, 0, 90)
    end
end)

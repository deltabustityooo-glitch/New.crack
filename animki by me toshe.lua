-- ══════════════════════════════════════════════════════════════════════
--  Fe UGC Animations Studio v3.7 — IMPROVED UI + WEAR BY ID
-- ══════════════════════════════════════════════════════════════════════

local Players      = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local AvatarEditor = game:GetService("AvatarEditorService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local ContentProv  = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local LP           = Players.LocalPlayer

local F_CACHE    = "fua37_cache.json"
local F_EQUIPPED = "fua37_equipped.json"
local F_PRESETS  = "fua37_presets.json"
local F_FAVS     = "fua37_favs.json"
local F_PERSIST  = "fua37_persist.json"

local SLOT_TO_FOLDER = {
    idleanimation="idle",    walkanimation="walk",   runanimation="run",
    jumpanimation="jump",    fallanimation="fall",   climbanimation="climb",
    swimidleanimation="swimidle", swimanimation="swim",
}
local SLOT_LABELS = {
    idleanimation="Idle",   walkanimation="Walk",   runanimation="Run",
    jumpanimation="Jump",   fallanimation="Fall",   climbanimation="Climb",
    swimidleanimation="S.Idle", swimanimation="Swim",
}
local SLOT_ORDER = {
    "idleanimation","walkanimation","runanimation","jumpanimation",
    "fallanimation","climbanimation","swimidleanimation","swimanimation",
}
local SLOT_ICONS = {
    idleanimation="🧍", walkanimation="🚶", runanimation="🏃",
    jumpanimation="⬆",  fallanimation="⬇", climbanimation="🧗",
    swimidleanimation="🏊", swimanimation="🌊",
}
local SLOT_COLORS = {
    idleanimation    = Color3.fromRGB(100,180,255),
    walkanimation    = Color3.fromRGB(80,230,150),
    runanimation     = Color3.fromRGB(255,150,60),
    jumpanimation    = Color3.fromRGB(210,90,255),
    fallanimation    = Color3.fromRGB(255,80,100),
    climbanimation   = Color3.fromRGB(80,220,255),
    swimidleanimation= Color3.fromRGB(255,215,70),
    swimanimation    = Color3.fromRGB(255,110,190),
}

local C = {
    bg0   = Color3.fromRGB(4,5,10),
    bg1   = Color3.fromRGB(8,10,18),
    bg2   = Color3.fromRGB(12,15,26),
    bg3   = Color3.fromRGB(17,21,36),
    bg4   = Color3.fromRGB(22,28,48),
    bg5   = Color3.fromRGB(30,38,64),
    card  = Color3.fromRGB(14,18,30),
    cardHi= Color3.fromRGB(20,26,44),
    neon  = Color3.fromRGB(100,180,255),
    cyan  = Color3.fromRGB(70,215,255),
    neonG = Color3.fromRGB(75,225,145),
    neonP = Color3.fromRGB(200,85,255),
    neonR = Color3.fromRGB(255,70,90),
    gold  = Color3.fromRGB(255,210,60),
    orange= Color3.fromRGB(255,140,45),
    pink  = Color3.fromRGB(255,105,185),
    textHi= Color3.fromRGB(235,242,255),
    textMid=Color3.fromRGB(150,165,205),
    textLo= Color3.fromRGB(72,86,124),
    stroke= Color3.fromRGB(32,42,74),
    strokeHi=Color3.fromRGB(72,95,165),
    white = Color3.new(1,1,1),
    overlay=Color3.fromRGB(2,3,8),
}

local VPS = workspace.CurrentCamera.ViewportSize
local SCALE = math.clamp(math.min(VPS.X/1920,VPS.Y/1080)*1.65,0.55,2.2)
local function px(n) return math.round(n*SCALE) end

local function jRead(f)
    if not(isfile and isfile(f)) then return {} end
    local ok,r=pcall(readfile,f); if not ok or not r or r=="" then return {} end
    local ok2,t=pcall(HttpService.JSONDecode,HttpService,r)
    return (ok2 and type(t)=="table") and t or {}
end
local function jWrite(f,d) pcall(function() writefile(f,HttpService:JSONEncode(d)) end) end

local PS=jRead(F_PERSIST)
local S={
    cache=jRead(F_CACHE), equipped=jRead(F_EQUIPPED),
    presets=jRead(F_PRESETS), favorites=jRead(F_FAVS),
    rCache={},
    tab=PS.tab or "Animations",
    searchList=PS.searchList or {}, catCursor=nil,
    page=PS.page or 1, perPage=8,
    bundleId=PS.bundleId, bundleName=PS.bundleName or "",
    bundleItems=PS.bundleItems or {},
    selSlot=PS.selSlot or "idleanimation",
    masterTrack=nil, masterGen=0,
    gridThreads={},
    equippedNames=PS.equippedNames or {},
    defaultAnims={},
    builder={},
}
if type(S.presets)~="table"   then S.presets={}  end
if type(S.equipped)~="table"  then S.equipped={} end
if type(S.favorites)~="table" then S.favorites={} end

local function savePS()
    jWrite(F_PERSIST,{
        tab=S.tab,page=S.page,bundleId=S.bundleId,
        bundleName=S.bundleName,bundleItems=S.bundleItems,
        selSlot=S.selSlot,searchList=S.searchList,
        equippedNames=S.equippedNames,
    })
end

-- ═══════════════════════════════════════════════════════════════════════
--  ANIMATION ENGINE
-- ═══════════════════════════════════════════════════════════════════════

local function fetchAnimForSlot(item, slotType)
    local assetId = tostring(item.Id)
    local lt      = string.lower(slotType)
    local targetF = SLOT_TO_FOLDER[lt]; if not targetF then return nil end
    local ck      = assetId.."__"..lt
    if S.rCache[ck] then return S.rCache[ck] end

    local result=nil
    pcall(function()
        local propMap={
            idle="IdleAnimation",walk="WalkAnimation",run="RunAnimation",
            jump="JumpAnimation",fall="FallAnimation",climb="ClimbAnimation",
            swim="SwimAnimation",swimidle="SwimAnimation",
        }
        local prop=propMap[targetF]; if not prop then return end
        local desc=Instance.new("HumanoidDescription"); desc[prop]=tonumber(assetId)
        local dummy=Players:CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R15)
        local ani=dummy:FindFirstChild("Animate")
        if ani then
            local folders={targetF}
            if targetF=="swimidle" then folders={"swimidle","swim"} end
            for _,fn in ipairs(folders) do
                local folder=ani:FindFirstChild(fn)
                if folder then
                    for _,child in ipairs(folder:GetChildren()) do
                        if child:IsA("Animation") and child.AnimationId~="" then
                            if targetF=="swimidle" then
                                if string.lower(child.Name):find("idle") then
                                    result={Name=child.Name,AnimationId=child.AnimationId}; break
                                end
                            else result={Name=child.Name,AnimationId=child.AnimationId}; break end
                        end
                    end
                end
                if result then break end
            end
            if not result and targetF=="swimidle" then
                local folder=ani:FindFirstChild("swimidle") or ani:FindFirstChild("swim")
                if folder then
                    for _,child in ipairs(folder:GetChildren()) do
                        if child:IsA("Animation") and child.AnimationId~="" then
                            result={Name=child.Name,AnimationId=child.AnimationId}; break
                        end
                    end
                end
            end
        end
        dummy:Destroy()
    end)
    if not result then
        pcall(function()
            local objs=game:GetObjects("rbxassetid://"..assetId)
            if objs and #objs>0 then
                local function tryFind(inst)
                    if inst:IsA("Animation") and inst.AnimationId~="" then
                        result={Name=inst.Name,AnimationId=inst.AnimationId}; return
                    end
                    if not result then
                        for _,c in ipairs(inst:GetChildren()) do tryFind(c) end
                    end
                end
                tryFind(objs[1])
            end
        end)
    end
    if result then S.rCache[ck]=result end
    return result
end

-- Надеть анимацию по прямому AnimationId (для функции "Wear by ID")
local function fetchAnimById(animId)
    local cleanId=tostring(animId):match("%d+")
    if not cleanId then return nil end
    local fullId="rbxassetid://"..cleanId
    local name="Animation_"..cleanId
    -- Проверяем что id существует
    local ok=pcall(function()
        local a=Instance.new("Animation"); a.AnimationId=fullId
        ContentProv:PreloadAsync({a}); a:Destroy()
    end)
    return {Name=name, AnimationId=fullId}
end

local function applySlot(char,slotType,animData)
    local animate=char:FindFirstChild("Animate")
    local human=char:FindFirstChildOfClass("Humanoid")
    if not animate or not human then return false end
    for _,tr in ipairs(human:GetPlayingAnimationTracks()) do
        pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end)
    end
    animate.Disabled=true
    local fn=SLOT_TO_FOLDER[string.lower(slotType)]
    if fn then
        local folder=animate:FindFirstChild(fn)
        if folder then
            for _,c2 in ipairs(folder:GetChildren()) do
                if c2:IsA("Animation") then c2:Destroy() end
            end
            local na=Instance.new("Animation",folder)
            na.Name=animData.Name; na.AnimationId=animData.AnimationId
            S.equipped[slotType]={{Name=animData.Name,AnimationId=animData.AnimationId}}
            S.equippedNames[slotType]=animData.Name
            jWrite(F_EQUIPPED,S.equipped); savePS()
        end
    end
    task.wait(0.05); animate.Disabled=false
    return true
end

local function saveDefaultAnims(char)
    if not char then return end
    local animate=char:FindFirstChild("Animate"); if not animate then return end
    for slot,folder in pairs(SLOT_TO_FOLDER) do
        local f=animate:FindFirstChild(folder)
        if f then
            S.defaultAnims[slot]={}
            for _,child in ipairs(f:GetChildren()) do
                if child:IsA("Animation") then
                    table.insert(S.defaultAnims[slot],{Name=child.Name,AnimationId=child.AnimationId})
                end
            end
        end
    end
end

local function resetSlot(char,slotType)
    local animate=char:FindFirstChild("Animate")
    local human=char:FindFirstChildOfClass("Humanoid")
    if not animate or not human then return end
    for _,tr in ipairs(human:GetPlayingAnimationTracks()) do
        pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end)
    end
    animate.Disabled=true
    local fn=SLOT_TO_FOLDER[string.lower(slotType)]
    if fn then
        local folder=animate:FindFirstChild(fn)
        if folder then
            for _,c2 in ipairs(folder:GetChildren()) do
                if c2:IsA("Animation") then c2:Destroy() end
            end
            local defs=S.defaultAnims[string.lower(slotType)]
            if defs then
                for _,d in ipairs(defs) do
                    local na=Instance.new("Animation",folder); na.Name=d.Name; na.AnimationId=d.AnimationId
                end
            end
        end
    end
    S.equipped[slotType]=nil; S.equippedNames[slotType]=nil
    jWrite(F_EQUIPPED,S.equipped); savePS()
    task.wait(0.05); animate.Disabled=false
end

local function applyAllEquipped(char)
    if not char then return end
    local animate=char:WaitForChild("Animate",6)
    local human=char:WaitForChild("Humanoid",6)
    if not animate or not human then return end
    local idle=animate:FindFirstChild("idle"); if idle then idle:WaitForChild("Animation1",4) end
    task.wait(0.15)
    for _,tr in ipairs(human:GetPlayingAnimationTracks()) do
        pcall(function() tr:AdjustWeight(0,0); tr:Stop(0) end)
    end
    animate.Disabled=true
    for slotType,list in pairs(S.equipped) do
        local fn=SLOT_TO_FOLDER[slotType]
        if fn and list and #list>0 then
            local folder=animate:FindFirstChild(fn)
            if folder then
                for _,c2 in ipairs(folder:GetChildren()) do
                    if c2:IsA("Animation") then c2:Destroy() end
                end
                for _,d in ipairs(list) do
                    local na=Instance.new("Animation",folder); na.Name=d.Name; na.AnimationId=d.AnimationId
                end
            end
        end
    end
    task.wait(0.05); animate.Disabled=false
end

if LP.Character then
    task.spawn(function()
        task.wait(0.6); saveDefaultAnims(LP.Character)
        if next(S.equipped) then applyAllEquipped(LP.Character) end
    end)
end
LP.CharacterAdded:Connect(function(char)
    task.spawn(function()
        task.wait(1); saveDefaultAnims(char)
        if next(S.equipped) then applyAllEquipped(char) end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════
--  UI
-- ═══════════════════════════════════════════════════════════════════════

local guiParent=(typeof(gethui)=="function" and gethui()) or game:GetService("CoreGui")
if guiParent:FindFirstChild("FUA37") then guiParent.FUA37:Destroy() end
local Screen=Instance.new("ScreenGui",guiParent)
Screen.Name="FUA37"; Screen.ResetOnSpawn=false
Screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; Screen.DisplayOrder=999

local function mkCorner(p,r)
    local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or px(8)); return c
end
local function mkStroke(p,col,thick,trans)
    local s=Instance.new("UIStroke",p); s.Color=col or C.stroke
    s.Thickness=thick or 1; s.Transparency=trans or 0; return s
end
local function mkPad(p,t,b,l,r)
    local u=Instance.new("UIPadding",p)
    u.PaddingTop=UDim.new(0,t or 0); u.PaddingBottom=UDim.new(0,b or 0)
    u.PaddingLeft=UDim.new(0,l or 0); u.PaddingRight=UDim.new(0,r or 0)
end
local function tw(o,t2,g,st,dir)
    return TweenService:Create(o,TweenInfo.new(t2,st or Enum.EasingStyle.Quint,
        dir or Enum.EasingDirection.Out),g)
end
local function trunc(s,n)
    if not s then return "?" end; return #s>n and s:sub(1,n-1).."…" or s
end
local function mkGrad(p,c0,c1,spd,rot)
    local g=Instance.new("UIGradient",p)
    g.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,c0),
        ColorSequenceKeypoint.new(0.5,c1),
        ColorSequenceKeypoint.new(1,c0),
    })
    g.Rotation=rot or 45; g.Offset=Vector2.new(-1,0)
    TweenService:Create(g,TweenInfo.new(spd or 2,Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut,-1),{Offset=Vector2.new(1,0)}):Play()
    return g
end
local function shimmer(f,a,b)
    local o=f:FindFirstChild("_sh"); if o then o:Destroy() end
    local g=mkGrad(f,a,b,1.8); g.Name="_sh"
end
local function noShimmer(f)
    local g=f:FindFirstChild("_sh"); if g then g:Destroy() end
end
local function hvr(btn,n,h)
    btn.MouseEnter:Connect(function() tw(btn,0.12,{BackgroundColor3=h}):Play() end)
    btn.MouseLeave:Connect(function() tw(btn,0.12,{BackgroundColor3=n}):Play() end)
end

-- Размеры
local WIN_W    = px(960)
local WIN_H    = px(600)
local TITLE_H  = px(56)
local LEFT_W   = px(365)
local RIGHT_W  = WIN_W-LEFT_W-px(18)
local VP_H     = px(188)
local STOP     = px(82)
local SCROLL_H = WIN_H-TITLE_H-px(10)-STOP-px(36)

-- ═══════════════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════════════

local Win=Instance.new("Frame",Screen)
Win.Name="Win"; Win.Size=UDim2.fromOffset(WIN_W,WIN_H)
Win.Position=UDim2.new(0.5,-WIN_W/2,0.46,-WIN_H/2)
Win.BackgroundColor3=C.bg0; Win.BorderSizePixel=0; Win.ClipsDescendants=true
mkCorner(Win,px(20))

-- Фон
do
    local bgF=Instance.new("Frame",Win); bgF.Size=UDim2.new(1,0,1,0)
    bgF.BackgroundColor3=C.bg0; bgF.BorderSizePixel=0
    local bgg=Instance.new("UIGradient",bgF)
    bgg.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(7,10,22)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(4,6,12)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(9,12,24)),
    }); bgg.Rotation=135
    -- Световые пятна
    local function blob(xU,yU,col,sz)
        local b=Instance.new("Frame",bgF)
        b.Size=UDim2.fromOffset(px(sz),px(sz))
        b.Position=UDim2.new(xU,-px(sz/2),yU,-px(sz/2))
        b.BackgroundColor3=col; b.BackgroundTransparency=0.9
        b.BorderSizePixel=0; mkCorner(b,px(sz))
    end
    blob(0.08,0.18,C.neon,220); blob(0.92,0.82,C.neonP,240)
    blob(0.5,0.45,C.neonG,160); blob(0.15,0.85,C.gold,140)
    blob(0.88,0.15,C.cyan,130)
end

local winStr=mkStroke(Win,C.neon,2,0.1)
task.spawn(function()
    local cols={C.neon,C.cyan,C.neonG,C.neonP,C.orange,C.neon}; local i=1
    while Win and Win.Parent do
        local ni=(i%#cols)+1; tw(winStr,3,{Color=cols[ni]}):Play(); i=ni; task.wait(3)
    end
end)

-- ── Title Bar ────────────────────────────────────────────────────────

local TBar=Instance.new("Frame",Win)
TBar.Name="TBar"; TBar.Size=UDim2.new(1,0,0,TITLE_H)
TBar.BackgroundColor3=C.bg1; TBar.BorderSizePixel=0; mkCorner(TBar,px(20))
local TFix=Instance.new("Frame",TBar)
TFix.Size=UDim2.new(1,0,0.5,0); TFix.Position=UDim2.new(0,0,0.5,0)
TFix.BackgroundColor3=C.bg1; TFix.BorderSizePixel=0

-- Полоска снизу заголовка
local tLine=Instance.new("Frame",TBar)
tLine.Size=UDim2.new(1,0,0,px(2)); tLine.Position=UDim2.new(0,0,1,-px(2))
tLine.BackgroundColor3=C.neon; tLine.BorderSizePixel=0; mkGrad(tLine,C.neon,C.neonP,3)

-- Логотип
local LogoF=Instance.new("Frame",TBar)
LogoF.Size=UDim2.fromOffset(px(36),px(36)); LogoF.Position=UDim2.fromOffset(px(12),px(10))
LogoF.BackgroundColor3=C.neon; LogoF.BorderSizePixel=0; mkCorner(LogoF,px(11))
mkGrad(LogoF,C.neon,C.neonP,2.5)
local LL=Instance.new("TextLabel",LogoF)
LL.Size=UDim2.new(1,0,1,0); LL.BackgroundTransparency=1
LL.Text="▶"; LL.TextColor3=C.white; LL.Font=Enum.Font.GothamBlack; LL.TextSize=px(15)

local TitleL=Instance.new("TextLabel",TBar)
TitleL.Size=UDim2.new(0.48,0,0,px(24)); TitleL.Position=UDim2.fromOffset(px(54),px(6))
TitleL.BackgroundTransparency=1; TitleL.Text="UGC Animations Studio"
TitleL.TextColor3=C.textHi; TitleL.Font=Enum.Font.GothamBlack; TitleL.TextSize=px(16)
TitleL.TextXAlignment=Enum.TextXAlignment.Left

local SubL=Instance.new("TextLabel",TBar)
SubL.Size=UDim2.new(0.55,0,0,px(13)); SubL.Position=UDim2.fromOffset(px(54),px(32))
SubL.BackgroundTransparency=1; SubL.Text="v3.7  •  Wear by ID  •  Set Builder  •  Favorites"
SubL.TextColor3=C.textLo; SubL.Font=Enum.Font.Gotham; SubL.TextSize=px(9)
SubL.TextXAlignment=Enum.TextXAlignment.Left

-- Кнопки окна
local function mkWB(xOff,bg,txt,hi)
    local b=Instance.new("TextButton",TBar)
    b.Size=UDim2.fromOffset(px(26),px(26)); b.Position=UDim2.new(1,-xOff,0.5,-px(13))
    b.BackgroundColor3=bg; b.Text=txt; b.TextColor3=C.white
    b.Font=Enum.Font.GothamBold; b.TextSize=px(13); b.AutoButtonColor=false; mkCorner(b,px(7))
    hvr(b,bg,hi); return b
end
local BtnX=mkWB(px(40),Color3.fromRGB(185,42,52),"✕",Color3.fromRGB(225,58,70))
local BtnH=mkWB(px(74),Color3.fromRGB(38,48,84),"—",Color3.fromRGB(56,72,120))

-- Mini кнопка
local Mini=Instance.new("Frame",Screen)
Mini.Size=UDim2.fromOffset(px(88),px(36)); Mini.Position=UDim2.new(0,px(12),1,-px(50))
Mini.BackgroundColor3=C.bg2; Mini.Visible=false; Mini.BorderSizePixel=0
mkCorner(Mini,px(10)); mkStroke(Mini,C.neon,1.5,0.2); mkGrad(Mini,C.bg2,C.bg3,3)
local MiniL=Instance.new("TextLabel",Mini)
MiniL.Size=UDim2.new(1,0,1,0); MiniL.BackgroundTransparency=1
MiniL.Text="▶ UGC"; MiniL.TextColor3=C.neon; MiniL.Font=Enum.Font.GothamBold; MiniL.TextSize=px(12)
local MiniH=Instance.new("TextButton",Mini)
MiniH.Size=UDim2.new(1,0,1,0); MiniH.BackgroundTransparency=1; MiniH.Text=""

BtnX.MouseButton1Click:Connect(function()
    tw(Win,0.2,{Size=UDim2.fromOffset(WIN_W,0),BackgroundTransparency=1},
        Enum.EasingStyle.Quint,Enum.EasingDirection.In):Play()
    task.wait(0.22); Screen:Destroy()
end)
BtnH.MouseButton1Click:Connect(function()
    tw(Win,0.18,{Size=UDim2.fromOffset(WIN_W,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.In):Play()
    task.wait(0.2); Win.Visible=false; Win.Size=UDim2.fromOffset(WIN_W,WIN_H); Mini.Visible=true
end)
MiniH.MouseButton1Click:Connect(function()
    Mini.Visible=false; Win.Visible=true; Win.Size=UDim2.fromOffset(WIN_W,0)
    tw(Win,0.32,{Size=UDim2.fromOffset(WIN_W,WIN_H)},Enum.EasingStyle.Back):Play()
end)

-- Drag
do
    local d,ds,ws=false
    TBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then d=true;ds=i.Position;ws=Win.Position end
    end)
    UserInput.InputChanged:Connect(function(i)
        if d and i.UserInputType==Enum.UserInputType.MouseMovement then
            local v=i.Position-ds; Win.Position=UDim2.fromOffset(ws.X.Offset+v.X,ws.Y.Offset+v.Y)
        end
    end)
    UserInput.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end
    end)
end
do
    local d,ds,ws=false
    Mini.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then d=true;ds=i.Position;ws=Mini.Position end
    end)
    UserInput.InputChanged:Connect(function(i)
        if d and i.UserInputType==Enum.UserInputType.MouseMovement then
            local v=i.Position-ds; Mini.Position=UDim2.fromOffset(ws.X.Offset+v.X,ws.Y.Offset+v.Y)
        end
    end)
    UserInput.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end
    end)
end

-- Body
local Body=Instance.new("Frame",Win)
Body.Size=UDim2.new(1,-px(16),1,-(TITLE_H+px(8)))
Body.Position=UDim2.fromOffset(px(8),TITLE_H+px(6)); Body.BackgroundTransparency=1

local LCol=Instance.new("Frame",Body); LCol.Size=UDim2.new(0,LEFT_W,1,0); LCol.BackgroundTransparency=1

-- Разделитель
local Divider=Instance.new("Frame",Body)
Divider.Size=UDim2.new(0,px(1),1,-px(4)); Divider.Position=UDim2.fromOffset(LEFT_W+px(5),px(2))
Divider.BackgroundColor3=C.strokeHi; Divider.BackgroundTransparency=0.4; Divider.BorderSizePixel=0
mkCorner(Divider,px(1)); mkGrad(Divider,C.neon,C.neonP,5)

local RCol=Instance.new("Frame",Body)
RCol.Size=UDim2.new(0,RIGHT_W-px(8),1,0)
RCol.Position=UDim2.fromOffset(LEFT_W+px(12),0); RCol.BackgroundTransparency=1

-- ═══════════════════════════════════════════════════════════════════════
--  TABS
-- ═══════════════════════════════════════════════════════════════════════

local TABS={"Animations","Favorites","Set Builder","My Sets","Current","By ID"}
local TCOLS={
    Animations=C.neon, Favorites=C.gold,
    ["Set Builder"]=C.orange, ["My Sets"]=C.neonP,
    Current=C.neonG, ["By ID"]=C.cyan,
}
local tabBtns={}

local TabBar=Instance.new("Frame",LCol)
TabBar.Size=UDim2.new(1,0,0,px(34)); TabBar.BackgroundColor3=C.bg2
TabBar.BorderSizePixel=0; mkCorner(TabBar,px(12)); mkStroke(TabBar,C.stroke,1,0.5)

local tabGL=Instance.new("UIGridLayout",TabBar)
tabGL.CellSize=UDim2.new(1/#TABS,-px(3),1,-px(6))
tabGL.CellPadding=UDim2.fromOffset(px(3),0)
tabGL.HorizontalAlignment=Enum.HorizontalAlignment.Center
tabGL.VerticalAlignment=Enum.VerticalAlignment.Center

for _,name in ipairs(TABS) do
    local tb=Instance.new("TextButton",TabBar)
    tb.BackgroundColor3=C.bg2; tb.TextColor3=C.textLo; tb.Text=name
    tb.Font=Enum.Font.GothamBold; tb.TextSize=px(8); tb.AutoButtonColor=false; tb.ClipsDescendants=true
    mkCorner(tb,px(7)); tabBtns[name]=tb
end

local function setTabStyle(name)
    S.tab=name; savePS()
    for n,tb in pairs(tabBtns) do
        local isA=(n==name); local col=TCOLS[n] or C.neon
        tw(tb,0.18,{BackgroundColor3=isA and col or C.bg2,TextColor3=isA and C.white or C.textLo}):Play()
        if isA then mkGrad(tb,col,C.bg3,2)
        else local g=tb:FindFirstChildOfClass("UIGradient"); if g then g:Destroy() end end
    end
end

-- Search
local SRow=Instance.new("Frame",LCol)
SRow.Size=UDim2.new(1,0,0,px(32)); SRow.Position=UDim2.fromOffset(0,px(40)); SRow.BackgroundTransparency=1

local SBox=Instance.new("TextBox",SRow)
SBox.Size=UDim2.new(1,-px(66),1,0); SBox.BackgroundColor3=C.bg3; SBox.TextColor3=C.textHi
SBox.PlaceholderText="🔍  Search animation bundles…"; SBox.PlaceholderColor3=C.textLo
SBox.Text=""; SBox.Font=Enum.Font.Gotham; SBox.TextSize=px(11); SBox.ClipsDescendants=true
mkCorner(SBox,px(10)); mkStroke(SBox,C.strokeHi,1,0.6); mkPad(SBox,0,0,px(10),0)

local SBtn=Instance.new("TextButton",SRow)
SBtn.Size=UDim2.fromOffset(px(60),px(32)); SBtn.Position=UDim2.new(1,-px(60),0,0)
SBtn.BackgroundColor3=C.neon; SBtn.TextColor3=C.white; SBtn.Text="Search"
SBtn.Font=Enum.Font.GothamBold; SBtn.TextSize=px(10); SBtn.AutoButtonColor=false; SBtn.ClipsDescendants=true
mkCorner(SBtn,px(10)); mkGrad(SBtn,C.neon,C.cyan,3); hvr(SBtn,C.neon,C.cyan)

-- Scrollers
local function mkSF(vis)
    local sf=Instance.new("ScrollingFrame",LCol)
    sf.Size=UDim2.new(1,0,0,SCROLL_H); sf.Position=UDim2.fromOffset(0,STOP)
    sf.BackgroundTransparency=1; sf.BorderSizePixel=0
    sf.ScrollBarThickness=px(3); sf.ScrollBarImageColor3=C.neonP
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.Visible=vis or false
    return sf
end
local function mkLL(p)
    local l=Instance.new("UIListLayout",p)
    l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,px(5)); return l
end

local AnimSF=mkSF(true);   local AnimLL=mkLL(AnimSF);   mkPad(AnimSF,px(4),px(4),px(2),px(2))
local FavSF=mkSF(false);   local FavLL=mkLL(FavSF);     mkPad(FavSF,px(4),px(4),px(2),px(2))
local BldSF=mkSF(false);   local BldLL=mkLL(BldSF);     mkPad(BldSF,px(4),px(4),px(2),px(2))
local SetsSF=mkSF(false);  local SetsLL=mkLL(SetsSF);   mkPad(SetsSF,px(4),px(4),px(2),px(2))
local CurSF=mkSF(false);   local CurLL=mkLL(CurSF);     mkPad(CurSF,px(4),px(4),px(2),px(2))
local ByIdSF=mkSF(false);  local ByIdLL=mkLL(ByIdSF);   mkPad(ByIdSF,px(4),px(4),px(2),px(2))

local LoadF=Instance.new("Frame",LCol)
LoadF.Size=UDim2.new(1,0,0,SCROLL_H); LoadF.Position=UDim2.fromOffset(0,STOP)
LoadF.BackgroundColor3=C.bg1; LoadF.BackgroundTransparency=0.05; LoadF.ZIndex=12; LoadF.Visible=false
mkCorner(LoadF,px(12))
local LoadL=Instance.new("TextLabel",LoadF)
LoadL.Size=UDim2.new(1,0,1,0); LoadL.BackgroundTransparency=1; LoadL.ZIndex=13
LoadL.Text="⟳  Loading…"; LoadL.TextColor3=C.neon; LoadL.Font=Enum.Font.GothamBold; LoadL.TextSize=px(16)
shimmer(LoadL,C.neon,C.cyan)

-- Пагинация
local PagerF=Instance.new("Frame",LCol)
PagerF.Size=UDim2.new(1,0,0,px(30)); PagerF.Position=UDim2.new(0,0,1,-px(30)); PagerF.BackgroundTransparency=1

local function mkPB(txt,xOff)
    local b=Instance.new("TextButton",PagerF)
    b.Size=UDim2.fromOffset(px(58),px(28)); b.Position=UDim2.fromOffset(xOff,0)
    b.BackgroundColor3=C.bg3; b.TextColor3=C.textMid; b.Text=txt
    b.Font=Enum.Font.GothamBold; b.TextSize=px(10); b.AutoButtonColor=false
    mkCorner(b,px(8)); mkStroke(b,C.stroke,1,0.4); hvr(b,C.bg3,C.bg4); return b
end
local PrevBtn=mkPB("◄ Back",0)
local PageLbl=Instance.new("TextLabel",PagerF)
PageLbl.Size=UDim2.new(1,-px(122),1,0); PageLbl.Position=UDim2.fromOffset(px(62),0)
PageLbl.BackgroundTransparency=1; PageLbl.Text="Page 1"
PageLbl.TextColor3=C.textLo; PageLbl.Font=Enum.Font.Gotham; PageLbl.TextSize=px(10)
local NextBtn=mkPB("Next ►",LEFT_W-px(60))

-- ═══════════════════════════════════════════════════════════════════════
--  RIGHT PANEL
-- ═══════════════════════════════════════════════════════════════════════

-- Viewport
local VPOut=Instance.new("Frame",RCol)
VPOut.Size=UDim2.new(1,0,0,VP_H+px(8))
VPOut.BackgroundColor3=C.bg2; VPOut.BorderSizePixel=0
mkCorner(VPOut,px(16)); mkStroke(VPOut,C.neon,1.5,0.2); mkGrad(VPOut,C.bg2,C.bg3,5)

local VP_VF=Instance.new("ViewportFrame",VPOut)
VP_VF.Size=UDim2.new(1,-px(8),1,-px(8)); VP_VF.Position=UDim2.fromOffset(px(4),px(4))
VP_VF.BackgroundColor3=C.overlay; VP_VF.BackgroundTransparency=0; mkCorner(VP_VF,px(13))

-- Badge на viewport
local vpBadgeF=Instance.new("Frame",VPOut)
vpBadgeF.Size=UDim2.fromOffset(px(86),px(22)); vpBadgeF.Position=UDim2.fromOffset(px(10),px(10))
vpBadgeF.BackgroundColor3=C.bg0; vpBadgeF.BackgroundTransparency=0.25; vpBadgeF.BorderSizePixel=0
vpBadgeF.ZIndex=5; mkCorner(vpBadgeF,px(7)); mkStroke(vpBadgeF,C.neon,1,0.4)
local vpBL=Instance.new("TextLabel",vpBadgeF)
vpBL.Size=UDim2.new(1,0,1,0); vpBL.BackgroundTransparency=1; vpBL.Text="● PREVIEW"
vpBL.TextColor3=C.neon; vpBL.Font=Enum.Font.GothamBold; vpBL.TextSize=px(9); vpBL.ZIndex=5

-- Status
local StatF=Instance.new("Frame",RCol)
StatF.Size=UDim2.new(1,0,0,px(26)); StatF.Position=UDim2.fromOffset(0,VP_H+px(14))
StatF.BackgroundColor3=C.bg2; StatF.BorderSizePixel=0; mkCorner(StatF,px(8)); mkStroke(StatF,C.stroke,1,0.5)
local StatL=Instance.new("TextLabel",StatF)
StatL.Size=UDim2.new(1,-px(10),1,0); StatL.Position=UDim2.fromOffset(px(8),0)
StatL.BackgroundTransparency=1; StatL.Text="Select a bundle to preview"
StatL.TextColor3=C.textLo; StatL.Font=Enum.Font.GothamSemibold; StatL.TextSize=px(10)
StatL.TextXAlignment=Enum.TextXAlignment.Left; StatL.ClipsDescendants=true

-- Equipped display
local EqF=Instance.new("Frame",RCol)
EqF.Size=UDim2.new(1,0,0,px(40)); EqF.Position=UDim2.fromOffset(0,VP_H+px(46))
EqF.BackgroundColor3=C.bg2; EqF.BorderSizePixel=0; mkCorner(EqF,px(10)); mkStroke(EqF,C.neonG,1,0.45)

local EqSlotL=Instance.new("TextLabel",EqF)
EqSlotL.Size=UDim2.new(0.5,0,0,px(14)); EqSlotL.Position=UDim2.fromOffset(px(10),px(3))
EqSlotL.BackgroundTransparency=1; EqSlotL.Text="🎬 Idle:"
EqSlotL.TextColor3=C.neonG; EqSlotL.Font=Enum.Font.GothamBold; EqSlotL.TextSize=px(9)
EqSlotL.TextXAlignment=Enum.TextXAlignment.Left

local EqAnimL=Instance.new("TextLabel",EqF)
EqAnimL.Size=UDim2.new(1,-px(88),0,px(20)); EqAnimL.Position=UDim2.fromOffset(px(10),px(18))
EqAnimL.BackgroundTransparency=1; EqAnimL.Text="None"
EqAnimL.TextColor3=C.textHi; EqAnimL.Font=Enum.Font.GothamBold; EqAnimL.TextSize=px(12)
EqAnimL.TextXAlignment=Enum.TextXAlignment.Left; EqAnimL.ClipsDescendants=true

local RstDefBtn=Instance.new("TextButton",EqF)
RstDefBtn.Size=UDim2.fromOffset(px(74),px(22)); RstDefBtn.Position=UDim2.new(1,-px(78),0.5,-px(11))
RstDefBtn.BackgroundColor3=Color3.fromRGB(150,65,28); RstDefBtn.Text="↩ Default"
RstDefBtn.TextColor3=C.white; RstDefBtn.Font=Enum.Font.GothamBold; RstDefBtn.TextSize=px(9)
RstDefBtn.AutoButtonColor=false; mkCorner(RstDefBtn,px(7)); mkStroke(RstDefBtn,Color3.fromRGB(195,95,42),1)
hvr(RstDefBtn,Color3.fromRGB(150,65,28),Color3.fromRGB(195,90,40))

local function updateEq()
    local n=S.equippedNames[S.selSlot]
    EqAnimL.Text=n and trunc(n,23) or "Not equipped"
    EqAnimL.TextColor3=n and C.neonG or C.textLo
    EqSlotL.Text="🎬 "..(SLOT_LABELS[S.selSlot] or S.selSlot)..":"
end

-- Slot grid
local SlotF=Instance.new("Frame",RCol)
SlotF.Size=UDim2.new(1,0,0,px(64)); SlotF.Position=UDim2.fromOffset(0,VP_H+px(92))
SlotF.BackgroundTransparency=1
local slotGL=Instance.new("UIGridLayout",SlotF)
slotGL.CellSize=UDim2.new(0.25,-px(4),0.5,-px(3)); slotGL.CellPadding=UDim2.fromOffset(px(4),px(3))

local slotBtns={}
for _,slot in ipairs(SLOT_ORDER) do
    local sc=SLOT_COLORS[slot] or C.neon
    local b=Instance.new("TextButton",SlotF)
    b.BackgroundColor3=C.bg3; b.TextColor3=C.textLo
    b.Text=(SLOT_ICONS[slot] or "").."\n"..SLOT_LABELS[slot]
    b.Font=Enum.Font.GothamBold; b.TextSize=px(9); b.AutoButtonColor=false; b.ClipsDescendants=true
    mkCorner(b,px(8)); mkStroke(b,C.stroke,1,0.6); slotBtns[slot]=b
    b.MouseEnter:Connect(function()
        if b.BackgroundColor3==C.bg3 then tw(b,0.1,{BackgroundColor3=C.bg4}):Play() end
    end)
    b.MouseLeave:Connect(function()
        if b.BackgroundColor3==C.bg4 then tw(b,0.1,{BackgroundColor3=C.bg3}):Play() end
    end)
    -- Маленькая точка если equipped
    local dot=Instance.new("Frame",b); dot.Size=UDim2.fromOffset(px(6),px(6))
    dot.Position=UDim2.new(1,-px(8),0,px(4)); dot.BackgroundColor3=sc
    dot.BackgroundTransparency=1; dot.BorderSizePixel=0; mkCorner(dot,px(3)); dot.Name="equip_dot"
end

local function refreshSlotDots()
    for slot,b in pairs(slotBtns) do
        local dot=b:FindFirstChild("equip_dot")
        if dot then dot.BackgroundTransparency=S.equippedNames[slot] and 0 or 1 end
    end
end

-- Action buttons
local ActF=Instance.new("Frame",RCol)
ActF.Size=UDim2.new(1,0,0,px(98)); ActF.Position=UDim2.new(0,0,1,-px(98)); ActF.BackgroundTransparency=1

local function mkAB(txt,bg,y,ws,x,gc)
    local b=Instance.new("TextButton",ActF)
    b.Size=UDim2.new(ws or 1,(ws and ws<1) and -px(3) or 0,0,px(28))
    b.Position=UDim2.fromOffset(x or 0,y or 0)
    b.BackgroundColor3=bg; b.TextColor3=C.white; b.Text=txt
    b.Font=Enum.Font.GothamBold; b.TextSize=px(11); b.AutoButtonColor=false; b.ClipsDescendants=true
    mkCorner(b,px(9)); mkStroke(b,bg,1,0.25); if gc then mkGrad(b,bg,gc,2.5) end
    hvr(b,bg,gc or C.cardHi); return b
end
local hR=math.floor(RIGHT_W*0.5)-px(5)
local WearSelBtn=mkAB("▶  Wear Selected Slot",C.neon,0,1,0,C.cyan)
local WearAllBtn=mkAB("▶▶  Wear All Slots",C.neonG,px(32),1,0,Color3.fromRGB(48,192,115))
local FavBtn    =mkAB("☆  Favorites",C.bg4,px(68),0.5,0)
local AddBldBtn =mkAB("＋  Add to Set Builder",C.orange,px(68),0.5,hR+px(4),Color3.fromRGB(210,110,30))

WearSelBtn.Visible=false; WearAllBtn.Visible=false; FavBtn.Visible=false; AddBldBtn.Visible=false

-- ═══════════════════════════════════════════════════════════════════════
--  NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════

local NStack=Instance.new("Frame",Screen)
NStack.Size=UDim2.new(0,px(295),1,0); NStack.Position=UDim2.new(1,-px(305),0,0)
NStack.BackgroundTransparency=1; NStack.BorderSizePixel=0
local NLay=Instance.new("UIListLayout",NStack)
NLay.SortOrder=Enum.SortOrder.LayoutOrder; NLay.Padding=UDim.new(0,px(6))
NLay.VerticalAlignment=Enum.VerticalAlignment.Bottom
local nCnt=0

local function showNotif(txt,icon,col,dur)
    icon=icon or "ℹ"; col=col or C.neon; dur=dur or 3; nCnt=nCnt+1
    local nf=Instance.new("Frame",NStack)
    nf.Size=UDim2.fromOffset(px(285),px(50)); nf.BackgroundColor3=C.bg2
    nf.BorderSizePixel=0; nf.LayoutOrder=nCnt; nf.BackgroundTransparency=1
    mkCorner(nf,px(12)); mkStroke(nf,col,1.5,0.15)
    -- Иконка
    local iF=Instance.new("Frame",nf); iF.Size=UDim2.fromOffset(px(44),px(50))
    iF.BackgroundColor3=col; iF.BackgroundTransparency=0.72; iF.BorderSizePixel=0; mkCorner(iF,px(12))
    local iL=Instance.new("TextLabel",iF); iL.Size=UDim2.new(1,0,1,0); iL.BackgroundTransparency=1
    iL.Text=icon; iL.TextColor3=col; iL.Font=Enum.Font.GothamBlack; iL.TextSize=px(18)
    -- Текст
    local mL=Instance.new("TextLabel",nf); mL.Size=UDim2.new(1,-px(50),1,0); mL.Position=UDim2.fromOffset(px(48),0)
    mL.BackgroundTransparency=1; mL.Text=txt; mL.TextColor3=C.textHi
    mL.Font=Enum.Font.GothamSemibold; mL.TextSize=px(11); mL.TextXAlignment=Enum.TextXAlignment.Left
    mL.TextWrapped=true; mL.ClipsDescendants=true
    nf.Position=UDim2.fromOffset(px(300),0)
    tw(nf,0.3,{BackgroundTransparency=0,Position=UDim2.fromOffset(0,0)},Enum.EasingStyle.Back):Play()
    -- Прогресс
    local pg=Instance.new("Frame",nf); pg.Size=UDim2.new(1,0,0,px(2)); pg.Position=UDim2.new(0,0,1,-px(2))
    pg.BackgroundColor3=col; pg.BorderSizePixel=0; mkCorner(pg,px(1))
    tw(pg,dur,{Size=UDim2.new(0,0,0,px(2))},Enum.EasingStyle.Linear):Play()
    task.delay(dur,function()
        tw(nf,0.25,{BackgroundTransparency=1,Position=UDim2.fromOffset(px(300),0)}):Play()
        task.wait(0.28); nf:Destroy()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
--  VIEWPORT
-- ═══════════════════════════════════════════════════════════════════════

local function buildSkeleton(vpF)
    local wm=vpF:FindFirstChildOfClass("WorldModel")
    if not wm then wm=Instance.new("WorldModel",vpF) else wm:ClearAllChildren() end
    local char=LP.Character or LP.CharacterAdded:Wait()
    char.Archivable=true
    local clone=char:Clone(); clone.Parent=wm
    local root=clone:WaitForChild("HumanoidRootPart",5)
    local human=clone:FindFirstChildOfClass("Humanoid"); if not human then return nil,nil,nil end
    local anim=human:FindFirstChildOfClass("Animator") or Instance.new("Animator",human)
    if clone:FindFirstChild("Animate") then clone.Animate.Disabled=true end
    local cam=Instance.new("Camera",vpF); vpF.CurrentCamera=cam
    cam.CFrame=CFrame.new(Vector3.new(0,2,5.8),Vector3.new(0,1,0))
    local angle=0
    local conn=RunService.RenderStepped:Connect(function(dt)
        if clone and clone.Parent and root then
            angle=angle+math.rad(24*dt); clone:PivotTo(CFrame.new()*CFrame.Angles(0,angle,0))
        end
    end)
    return clone,anim,conn
end

local function safePT(anim,track,looped)
    local ok,tr=pcall(function()
        local t=anim:LoadAnimation(track); t.Looped=looped; t:Play(); return t
    end)
    if not ok or not tr then return false,nil end
    task.wait(0.18)
    if not tr.IsPlaying then pcall(function() tr:Stop() end); return false,nil end
    return true,tr
end

local function renderPreview(item,slotType)
    if S.masterTrack then pcall(function() S.masterTrack:Stop() end); S.masterTrack=nil end
    S.masterGen=S.masterGen+1; local myGen=S.masterGen; local lt=string.lower(slotType)
    StatL.Text=trunc(S.bundleName,16).." • "..(SLOT_LABELS[lt] or lt).." ⟳"
    shimmer(StatL,C.neon,C.cyan)
    local dummy,animator=buildSkeleton(VP_VF); if not dummy then return end
    task.spawn(function()
        local animData=nil; local tries=0
        while myGen==S.masterGen do
            animData=fetchAnimForSlot(item,lt)
            if animData then break end
            tries=tries+1; S.rCache[tostring(item.Id).."__"..lt]=nil
            task.wait(math.min(0.8+tries*0.5,4))
        end
        if myGen~=S.masterGen then return end
        noShimmer(StatL); StatL.Text=trunc(S.bundleName,16).." • "..(SLOT_LABELS[lt] or lt)
        if not animData then return end
        local track=Instance.new("Animation"); track.AnimationId=animData.AnimationId
        local ok2,pt=safePT(animator,track,true)
        if myGen==S.masterGen then S.masterTrack=pt end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
--  FAVORITES
-- ═══════════════════════════════════════════════════════════════════════

local function isFav(id)
    local s=tostring(id)
    for _,f in ipairs(S.favorites) do if tostring(f.id)==s then return true end end
    return false
end
local function addFav(id,name)
    if isFav(id) then return end
    table.insert(S.favorites,{id=id,name=name,time=tick()}); jWrite(F_FAVS,S.favorites)
end
local function remFav(id)
    local s=tostring(id)
    for i,f in ipairs(S.favorites) do
        if tostring(f.id)==s then table.remove(S.favorites,i); jWrite(F_FAVS,S.favorites); return end
    end
end

local rebuildFavorites,rebuildSets,rebuildBuilder,rebuildCurrent,rebuildById

local function refreshFavBtn()
    if not S.bundleId then FavBtn.Visible=false; return end
    FavBtn.Visible=true
    local faved=isFav(S.bundleId)
    FavBtn.Text=faved and "★  In Favorites" or "☆  Add to Favorites"
    FavBtn.TextColor3=faved and C.gold or C.textHi
    FavBtn.BackgroundColor3=faved and Color3.fromRGB(48,38,4) or C.bg4
end

-- ═══════════════════════════════════════════════════════════════════════
--  BUNDLE INSPECT
-- ═══════════════════════════════════════════════════════════════════════

local function inspectBundle(bundleId,bundleName)
    table.clear(S.bundleItems)
    WearSelBtn.Visible=false; WearAllBtn.Visible=false; FavBtn.Visible=false; AddBldBtn.Visible=false
    S.bundleId=bundleId; S.bundleName=bundleName or "Unknown"; savePS()
    StatL.Text=trunc(S.bundleName,16).." • Loading…"; shimmer(StatL,C.neon,C.cyan); refreshFavBtn()
    for _,b in pairs(slotBtns) do
        b.BackgroundColor3=C.bg3; b.TextColor3=C.textLo; noShimmer(b)
        local st=b:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(b,C.stroke,1,0.6)
    end
    task.spawn(function()
        local ok,res=pcall(function() return AssetService:GetBundleDetailsAsync(bundleId) end)
        if not ok or not res or not res.Items then
            noShimmer(StatL); StatL.Text="Failed to load bundle"
            showNotif("Failed to load bundle","✕",C.neonR); return
        end
        for _,item in ipairs(res.Items) do
            local lt=string.lower(item.AssetType or "")
            if lt=="swimanimation" then
                S.bundleItems["swimanimation"]=item; S.bundleItems["swimidleanimation"]=item
            elseif SLOT_LABELS[lt] then S.bundleItems[lt]=item end
        end
        savePS(); WearAllBtn.Visible=true; FavBtn.Visible=true; AddBldBtn.Visible=true; refreshFavBtn()
        for slot,b in pairs(slotBtns) do
            if S.bundleItems[slot] then
                local sc=SLOT_COLORS[slot] or C.neon
                b.BackgroundColor3=C.bg4; b.TextColor3=sc
                local st=b:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(b,sc,1.5,0.2)
            end
        end
        local play=S.bundleItems[S.selSlot] and S.selSlot or "idleanimation"
        if S.bundleItems[play] then
            local sc=SLOT_COLORS[play] or C.neon
            slotBtns[play].BackgroundColor3=sc; slotBtns[play].TextColor3=C.white
            WearSelBtn.Visible=true; renderPreview(S.bundleItems[play],play)
        else noShimmer(StatL); StatL.Text=trunc(S.bundleName,16).." • No preview" end
    end)
end

-- Slot buttons
for _,slot in ipairs(SLOT_ORDER) do
    slotBtns[slot].MouseButton1Click:Connect(function()
        S.selSlot=slot; savePS(); updateEq()
        local payload=S.bundleItems[slot]; if not payload then return end
        WearSelBtn.Visible=true; renderPreview(payload,slot)
        for s2,b2 in pairs(slotBtns) do
            local has=S.bundleItems[s2]~=nil; local sc2=SLOT_COLORS[s2] or C.neon
            b2.BackgroundColor3=has and C.bg4 or C.bg3; b2.TextColor3=has and sc2 or C.textLo
            local st=b2:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end
            if has then mkStroke(b2,sc2,1.5,0.2) end
        end
        local sc=SLOT_COLORS[slot] or C.neon
        slotBtns[slot].BackgroundColor3=sc; slotBtns[slot].TextColor3=C.white
        local st2=slotBtns[slot]:FindFirstChildOfClass("UIStroke"); if st2 then st2:Destroy() end
        mkStroke(slotBtns[slot],sc,2,0)
    end)
end

WearSelBtn.MouseButton1Click:Connect(function()
    local item=S.bundleItems[S.selSlot]; if not item or not LP.Character then return end
    shimmer(WearSelBtn,C.neon,C.cyan); WearSelBtn.Text="Fetching…"
    task.spawn(function()
        local cs=S.selSlot; local ci=item
        local animData=fetchAnimForSlot(ci,cs)
        if animData and animData.AnimationId~="" then
            applySlot(LP.Character,cs,animData); updateEq(); refreshSlotDots()
            showNotif(SLOT_LABELS[cs].." applied!","✓",C.neonG)
        else showNotif("Could not fetch animation","✕",C.neonR) end
        noShimmer(WearSelBtn); WearSelBtn.Text="▶  Wear Selected Slot"
    end)
end)

WearAllBtn.MouseButton1Click:Connect(function()
    if not LP.Character then return end
    shimmer(WearAllBtn,C.neonG,C.neon); WearAllBtn.Text="Fetching…"
    task.spawn(function()
        local count=0
        for slot,item in pairs(S.bundleItems) do
            local cs=slot; local ci=item
            local animData=fetchAnimForSlot(ci,cs)
            if animData and animData.AnimationId~="" and LP.Character then
                applySlot(LP.Character,cs,animData); count=count+1
            end
        end
        noShimmer(WearAllBtn); WearAllBtn.Text="▶▶  Wear All Slots"
        updateEq(); refreshSlotDots(); showNotif("Applied "..count.." animations!","▶▶",C.neonG)
    end)
end)

FavBtn.MouseButton1Click:Connect(function()
    if not S.bundleId then return end
    if isFav(S.bundleId) then remFav(S.bundleId); showNotif("Removed from Favorites","☆",C.textMid)
    else addFav(S.bundleId,S.bundleName); showNotif("Added: "..trunc(S.bundleName,16),"★",C.gold) end
    refreshFavBtn(); if S.tab=="Favorites" then rebuildFavorites() end
end)

AddBldBtn.MouseButton1Click:Connect(function()
    local item=S.bundleItems[S.selSlot]; if not item then showNotif("Select a slot first!","!",C.neonR); return end
    shimmer(AddBldBtn,C.orange,C.gold); AddBldBtn.Text="Fetching…"
    local cs=S.selSlot; local ci=item; local cb=S.bundleName; local cbi=S.bundleId
    task.spawn(function()
        local animData=fetchAnimForSlot(ci,cs)
        if animData and animData.AnimationId and animData.AnimationId~="" then
            S.builder[cs]={Name=animData.Name,AnimationId=animData.AnimationId,BundleName=cb,BundleId=cbi}
            showNotif(SLOT_LABELS[cs]..": "..trunc(animData.Name,14).." → Builder","＋",C.orange)
            if S.tab=="Set Builder" then rebuildBuilder() end
        else showNotif("Failed to fetch "..SLOT_LABELS[cs],"✕",C.neonR) end
        noShimmer(AddBldBtn); AddBldBtn.Text="＋  Add to Set Builder"
    end)
end)

RstDefBtn.MouseButton1Click:Connect(function()
    local char=LP.Character; if not char then return end
    resetSlot(char,S.selSlot); updateEq(); refreshSlotDots()
    showNotif(SLOT_LABELS[S.selSlot].." → default","↩",C.orange)
end)

-- ═══════════════════════════════════════════════════════════════════════
--  RENAME DIALOG
-- ═══════════════════════════════════════════════════════════════════════

local RenBg=Instance.new("Frame",Screen)
RenBg.Size=UDim2.new(1,0,1,0); RenBg.BackgroundColor3=C.bg0; RenBg.BackgroundTransparency=0.45
RenBg.BorderSizePixel=0; RenBg.Visible=false; RenBg.ZIndex=59

local RenOv=Instance.new("Frame",Screen)
RenOv.Size=UDim2.fromOffset(px(320),px(140)); RenOv.Position=UDim2.new(0.5,-px(160),0.5,-px(70))
RenOv.BackgroundColor3=C.bg2; RenOv.Visible=false; RenOv.ZIndex=60; mkCorner(RenOv,px(16))
mkStroke(RenOv,C.neonP,2); mkPad(RenOv,px(14),px(14),px(14),px(14))
mkGrad(RenOv,C.bg2,C.bg3,6)

local RenTL=Instance.new("TextLabel",RenOv)
RenTL.Size=UDim2.new(1,0,0,px(22)); RenTL.BackgroundTransparency=1; RenTL.ZIndex=61
RenTL.Text="✎  Name your Set"; RenTL.TextColor3=C.textHi; RenTL.Font=Enum.Font.GothamBold; RenTL.TextSize=px(14)

local RenBox=Instance.new("TextBox",RenOv)
RenBox.Size=UDim2.new(1,0,0,px(34)); RenBox.Position=UDim2.fromOffset(0,px(27))
RenBox.BackgroundColor3=C.bg3; RenBox.TextColor3=C.textHi; RenBox.PlaceholderText="Enter set name…"
RenBox.PlaceholderColor3=C.textLo; RenBox.Font=Enum.Font.Gotham; RenBox.TextSize=px(13)
RenBox.ClearTextOnFocus=false; RenBox.ZIndex=61; mkCorner(RenBox,px(9)); mkStroke(RenBox,C.strokeHi,1.5,0.3); mkPad(RenBox,0,0,px(10),0)

local rH=math.floor((px(320)-px(28)-px(5))/2)
local RenOkB=Instance.new("TextButton",RenOv)
RenOkB.Size=UDim2.fromOffset(rH,px(30)); RenOkB.Position=UDim2.fromOffset(0,px(76))
RenOkB.BackgroundColor3=C.neonP; RenOkB.TextColor3=C.white; RenOkB.Text="✓  Save Set"
RenOkB.Font=Enum.Font.GothamBold; RenOkB.TextSize=px(12); RenOkB.AutoButtonColor=false; RenOkB.ZIndex=61
mkCorner(RenOkB,px(9)); mkGrad(RenOkB,C.neonP,C.neon,2); hvr(RenOkB,C.neonP,C.cardHi)

local RenCancelB=Instance.new("TextButton",RenOv)
RenCancelB.Size=UDim2.fromOffset(rH,px(30)); RenCancelB.Position=UDim2.fromOffset(rH+px(5),px(76))
RenCancelB.BackgroundColor3=C.bg4; RenCancelB.TextColor3=C.textMid; RenCancelB.Text="Cancel"
RenCancelB.Font=Enum.Font.GothamBold; RenCancelB.TextSize=px(12); RenCancelB.AutoButtonColor=false; RenCancelB.ZIndex=61
mkCorner(RenCancelB,px(9)); hvr(RenCancelB,C.bg4,C.bg3)

local renCB=nil
local function openRename(def,cb)
    RenBox.Text=def or ""; renCB=cb; RenOv.Visible=true; RenBg.Visible=true
end
RenOkB.MouseButton1Click:Connect(function()
    local name=RenBox.Text~="" and RenBox.Text or ("My Set "..(#S.presets+1))
    RenOv.Visible=false; RenBg.Visible=false; if renCB then renCB(name); renCB=nil end
end)
RenCancelB.MouseButton1Click:Connect(function() RenOv.Visible=false; RenBg.Visible=false end)

-- ═══════════════════════════════════════════════════════════════════════
--  HELPERS для карточек
-- ═══════════════════════════════════════════════════════════════════════

local function mkCard(parent,h,lo,bc,noHover)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,-px(4),0,h); f.BackgroundColor3=bc or C.card
    f.BorderSizePixel=0; f.LayoutOrder=lo or 0; mkCorner(f,px(12)); mkStroke(f,C.stroke,1,0.5)
    if not noHover then
        f.MouseEnter:Connect(function() tw(f,0.1,{BackgroundColor3=C.cardHi}):Play() end)
        f.MouseLeave:Connect(function() tw(f,0.1,{BackgroundColor3=bc or C.card}):Play() end)
    end
    return f
end

local function mkBtn(parent,txt,bg,size,pos,hi,fs)
    local b=Instance.new("TextButton",parent)
    b.Size=size; b.Position=pos; b.BackgroundColor3=bg; b.TextColor3=C.white; b.Text=txt
    b.Font=Enum.Font.GothamBold; b.TextSize=fs or px(10); b.AutoButtonColor=false; b.ClipsDescendants=true
    mkCorner(b,px(8)); mkStroke(b,bg,1,0.25); hvr(b,bg,hi or C.cardHi); return b
end

-- ═══════════════════════════════════════════════════════════════════════
--  BY ID TAB
-- ═══════════════════════════════════════════════════════════════════════

rebuildById=function()
    for _,c in ipairs(ByIdSF:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end

    -- Заголовок
    local hCard=mkCard(ByIdSF,px(50),0,C.bg3,true)
    mkStroke(hCard,C.cyan,1.5,0.2); mkGrad(hCard,C.bg3,C.bg4,6)
    local hIconF=Instance.new("Frame",hCard); hIconF.Size=UDim2.fromOffset(px(38),px(38)); hIconF.Position=UDim2.fromOffset(px(8),px(6))
    hIconF.BackgroundColor3=C.cyan; hIconF.BackgroundTransparency=0.7; hIconF.BorderSizePixel=0; mkCorner(hIconF,px(10))
    mkGrad(hIconF,C.cyan,C.neon,3)
    local hIL=Instance.new("TextLabel",hIconF); hIL.Size=UDim2.new(1,0,1,0); hIL.BackgroundTransparency=1; hIL.Text="🎯"; hIL.Font=Enum.Font.GothamBlack; hIL.TextSize=px(20)
    local hTL=Instance.new("TextLabel",hCard); hTL.Size=UDim2.new(0.7,0,0,px(22)); hTL.Position=UDim2.fromOffset(px(54),px(7))
    hTL.BackgroundTransparency=1; hTL.Text="Wear by Animation ID"; hTL.TextColor3=C.cyan; hTL.Font=Enum.Font.GothamBlack; hTL.TextSize=px(14); hTL.TextXAlignment=Enum.TextXAlignment.Left
    local hSL=Instance.new("TextLabel",hCard); hSL.Size=UDim2.new(0.7,0,0,px(13)); hSL.Position=UDim2.fromOffset(px(54),px(30))
    hSL.BackgroundTransparency=1; hSL.Text="Paste animation ID → select slot → Apply"; hSL.TextColor3=C.textLo; hSL.Font=Enum.Font.Gotham; hSL.TextSize=px(9); hSL.TextXAlignment=Enum.TextXAlignment.Left

    -- Input поле для ID
    local inputCard=mkCard(ByIdSF,px(54),1,C.bg3,true)
    mkStroke(inputCard,C.strokeHi,1,0.4)

    local inputL=Instance.new("TextLabel",inputCard)
    inputL.Size=UDim2.new(1,-px(12),0,px(16)); inputL.Position=UDim2.fromOffset(px(10),px(5))
    inputL.BackgroundTransparency=1; inputL.Text="Animation ID / URL:"
    inputL.TextColor3=C.textMid; inputL.Font=Enum.Font.GothamBold; inputL.TextSize=px(10); inputL.TextXAlignment=Enum.TextXAlignment.Left

    local idBox=Instance.new("TextBox",inputCard)
    idBox.Size=UDim2.new(1,-px(12),0,px(28)); idBox.Position=UDim2.fromOffset(px(6),px(22))
    idBox.BackgroundColor3=C.bg4; idBox.TextColor3=C.textHi
    idBox.PlaceholderText="e.g. 656118852  or  rbxassetid://656118852"
    idBox.PlaceholderColor3=C.textLo; idBox.Font=Enum.Font.Gotham; idBox.TextSize=px(11)
    idBox.ClearTextOnFocus=false; idBox.ClipsDescendants=true
    mkCorner(idBox,px(8)); mkStroke(idBox,C.strokeHi,1,0.5); mkPad(idBox,0,0,px(10),0)
    idBox.Focused:Connect(function()
        tw(idBox:FindFirstChildOfClass("UIStroke") or mkStroke(idBox,C.cyan,1.5),0.15,{Transparency=0,Color=C.cyan}):Play()
    end)
    idBox.FocusLost:Connect(function()
        local st=idBox:FindFirstChildOfClass("UIStroke")
        if st then tw(st,0.15,{Transparency=0.5,Color=C.strokeHi}):Play() end
    end)

    -- Выбор слота (8 кнопок)
    local slotCard=mkCard(ByIdSF,px(72),2,C.bg3,true)
    mkStroke(slotCard,C.strokeHi,1,0.4)

    local slotCardL=Instance.new("TextLabel",slotCard)
    slotCardL.Size=UDim2.new(1,-px(12),0,px(16)); slotCardL.Position=UDim2.fromOffset(px(10),px(4))
    slotCardL.BackgroundTransparency=1; slotCardL.Text="Select target slot:"
    slotCardL.TextColor3=C.textMid; slotCardL.Font=Enum.Font.GothamBold; slotCardL.TextSize=px(10); slotCardL.TextXAlignment=Enum.TextXAlignment.Left

    local slotGridF=Instance.new("Frame",slotCard)
    slotGridF.Size=UDim2.new(1,-px(12),0,px(46)); slotGridF.Position=UDim2.fromOffset(px(6),px(22))
    slotGridF.BackgroundTransparency=1
    local sGL=Instance.new("UIGridLayout",slotGridF)
    sGL.CellSize=UDim2.new(0.25,-px(3),0.5,-px(3)); sGL.CellPadding=UDim2.fromOffset(px(3),px(3))

    local selectedByIdSlot=S.selSlot
    local byIdSlotBtns={}

    for _,slot in ipairs(SLOT_ORDER) do
        local sc=SLOT_COLORS[slot] or C.neon
        local sb=Instance.new("TextButton",slotGridF)
        sb.BackgroundColor3=C.bg4; sb.TextColor3=C.textLo
        sb.Text=(SLOT_ICONS[slot] or "").." "..SLOT_LABELS[slot]
        sb.Font=Enum.Font.GothamBold; sb.TextSize=px(9); sb.AutoButtonColor=false; sb.ClipsDescendants=true
        mkCorner(sb,px(7)); mkStroke(sb,C.stroke,1,0.5)
        byIdSlotBtns[slot]=sb

        sb.MouseButton1Click:Connect(function()
            selectedByIdSlot=slot
            for s2,sb2 in pairs(byIdSlotBtns) do
                local sc2=SLOT_COLORS[s2] or C.neon
                sb2.BackgroundColor3=C.bg4; sb2.TextColor3=C.textLo
                local st=sb2:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(sb2,C.stroke,1,0.5)
            end
            sb.BackgroundColor3=sc; sb.TextColor3=C.white
            local st=sb:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(sb,sc,2,0)
        end)
    end

    -- Активируем начальный слот
    do
        local sc=SLOT_COLORS[selectedByIdSlot] or C.neon
        local sb=byIdSlotBtns[selectedByIdSlot]
        if sb then
            sb.BackgroundColor3=sc; sb.TextColor3=C.white
            local st=sb:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(sb,sc,2,0)
        end
    end

    -- Кнопка Apply + Preview
    local actCard=mkCard(ByIdSF,px(38),3,C.bg3,true); actCard.BackgroundTransparency=1

    local applyIdBtn=mkBtn(actCard,"▶  Apply to Character",C.cyan,
        UDim2.new(0.62,-px(3),1,0),UDim2.fromOffset(0,0),C.neon,px(12))
    mkGrad(applyIdBtn,C.cyan,C.neon,2.5)

    local previewIdBtn=mkBtn(actCard,"👁  Preview Only",C.bg4,
        UDim2.new(0.38,-px(3),1,0),UDim2.new(0.62,px(3),0,0),C.bg5,px(11))
    mkStroke(previewIdBtn,C.strokeHi,1,0.3)

    local function getCleanId()
        local raw=idBox.Text:gsub("%s","")
        return raw:match("%d+")
    end

    applyIdBtn.MouseButton1Click:Connect(function()
        local cleanId=getCleanId()
        if not cleanId then showNotif("Enter a valid animation ID!","!",C.neonR); return end
        local char=LP.Character; if not char then showNotif("No character found!","✕",C.neonR); return end
        shimmer(applyIdBtn,C.cyan,C.neon); applyIdBtn.Text="Applying…"
        task.spawn(function()
            local animData={Name="Custom_"..cleanId, AnimationId="rbxassetid://"..cleanId}
            local ok=applySlot(char,selectedByIdSlot,animData)
            if ok then
                updateEq(); refreshSlotDots()
                showNotif(SLOT_LABELS[selectedByIdSlot].." ← ID:"..cleanId.." ✓","✓",C.cyan,4)
            else showNotif("Failed to apply animation","✕",C.neonR) end
            noShimmer(applyIdBtn); applyIdBtn.Text="▶  Apply to Character"
        end)
    end)

    previewIdBtn.MouseButton1Click:Connect(function()
        local cleanId=getCleanId()
        if not cleanId then showNotif("Enter a valid animation ID!","!",C.neonR); return end
        shimmer(previewIdBtn,C.bg4,C.bg5); previewIdBtn.Text="Loading…"
        -- Показываем в viewport
        if S.masterTrack then pcall(function() S.masterTrack:Stop() end); S.masterTrack=nil end
        S.masterGen=S.masterGen+1; local myGen=S.masterGen
        local dummy,animator=buildSkeleton(VP_VF)
        StatL.Text="Preview: "..cleanId
        if dummy and animator then
            task.spawn(function()
                local track=Instance.new("Animation"); track.AnimationId="rbxassetid://"..cleanId
                local ok2,pt=safePT(animator,track,true)
                if myGen==S.masterGen then
                    S.masterTrack=pt
                    if ok2 then showNotif("Previewing ID: "..cleanId,"👁",C.cyan)
                    else showNotif("Could not preview (invalid ID?)","✕",C.neonR) end
                end
                noShimmer(previewIdBtn); previewIdBtn.Text="👁  Preview Only"
            end)
        else noShimmer(previewIdBtn); previewIdBtn.Text="👁  Preview Only" end
    end)

    -- История (последние 5 использованных ID)
    if not S.byIdHistory then S.byIdHistory={} end

    if #S.byIdHistory>0 then
        local histCard=mkCard(ByIdSF,px(28)+#S.byIdHistory*px(28),4,C.bg3,true)
        mkStroke(histCard,C.strokeHi,1,0.5)
        local histL=Instance.new("TextLabel",histCard)
        histL.Size=UDim2.new(1,-px(12),0,px(16)); histL.Position=UDim2.fromOffset(px(10),px(4))
        histL.BackgroundTransparency=1; histL.Text="Recent IDs:"
        histL.TextColor3=C.textMid; histL.Font=Enum.Font.GothamBold; histL.TextSize=px(10); histL.TextXAlignment=Enum.TextXAlignment.Left

        for hi,entry in ipairs(S.byIdHistory) do
            local hRow=Instance.new("Frame",histCard)
            hRow.Size=UDim2.new(1,-px(12),0,px(24)); hRow.Position=UDim2.fromOffset(px(6),px(20)+(hi-1)*px(26))
            hRow.BackgroundColor3=C.bg4; hRow.BorderSizePixel=0; mkCorner(hRow,px(7))
            hRow.MouseEnter:Connect(function() tw(hRow,0.1,{BackgroundColor3=C.bg5}):Play() end)
            hRow.MouseLeave:Connect(function() tw(hRow,0.1,{BackgroundColor3=C.bg4}):Play() end)

            local slotChip=Instance.new("Frame",hRow); slotChip.Size=UDim2.fromOffset(px(38),px(18)); slotChip.Position=UDim2.fromOffset(px(4),px(3))
            slotChip.BackgroundColor3=SLOT_COLORS[entry.slot] or C.neon; slotChip.BackgroundTransparency=0.4; slotChip.BorderSizePixel=0; mkCorner(slotChip,px(5))
            local scL=Instance.new("TextLabel",slotChip); scL.Size=UDim2.new(1,0,1,0); scL.BackgroundTransparency=1
            scL.Text=SLOT_LABELS[entry.slot] or "?"; scL.TextColor3=C.white; scL.Font=Enum.Font.GothamBold; scL.TextSize=px(8)

            local idL=Instance.new("TextLabel",hRow); idL.Size=UDim2.new(1,-px(110),1,0); idL.Position=UDim2.fromOffset(px(46),0)
            idL.BackgroundTransparency=1; idL.Text="ID: "..tostring(entry.id)
            idL.TextColor3=C.textHi; idL.Font=Enum.Font.Gotham; idL.TextSize=px(10); idL.TextXAlignment=Enum.TextXAlignment.Left

            local reapplyB=mkBtn(hRow,"▶ Apply",C.neon,
                UDim2.fromOffset(px(54),px(20)),UDim2.new(1,-px(58),0.5,-px(10)),C.cyan,px(9))

            local captEntry=entry
            reapplyB.MouseButton1Click:Connect(function()
                local char=LP.Character; if not char then return end
                idBox.Text=tostring(captEntry.id)
                selectedByIdSlot=captEntry.slot
                -- Обновляем выделение слота
                for s2,sb2 in pairs(byIdSlotBtns) do
                    local sc2=SLOT_COLORS[s2] or C.neon
                    sb2.BackgroundColor3=C.bg4; sb2.TextColor3=C.textLo
                    local st=sb2:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(sb2,C.stroke,1,0.5)
                end
                local selSb=byIdSlotBtns[captEntry.slot]
                if selSb then
                    local sc2=SLOT_COLORS[captEntry.slot] or C.neon
                    selSb.BackgroundColor3=sc2; selSb.TextColor3=C.white
                    local st=selSb:FindFirstChildOfClass("UIStroke"); if st then st:Destroy() end; mkStroke(selSb,sc2,2,0)
                end
                local animData={Name="Custom_"..captEntry.id,AnimationId="rbxassetid://"..captEntry.id}
                applySlot(char,captEntry.slot,animData); updateEq(); refreshSlotDots()
                showNotif(SLOT_LABELS[captEntry.slot].." reapplied!","▶",C.neon,2)
            end)

            local hitB=Instance.new("TextButton",hRow); hitB.Size=UDim2.new(1,-px(60),1,0); hitB.BackgroundTransparency=1; hitB.Text=""
            hitB.MouseButton1Click:Connect(function() idBox.Text=tostring(entry.id) end)
        end
    end

    -- Обновляем историю при Apply
    local origApply=applyIdBtn.MouseButton1Click
    -- (история обновляется внутри applyIdBtn.MouseButton1Click)
    -- Перехватываем через disconnect/reconnect невозможно, поэтому добавляем внутри

    ByIdSF.CanvasSize=UDim2.new(0,0,0,ByIdLL.AbsoluteContentSize.Y+px(8))
end

-- Добавление в историю
local function addToHistory(id,slot)
    if not S.byIdHistory then S.byIdHistory={} end
    -- Убираем дубликат
    for i=#S.byIdHistory,1,-1 do
        if tostring(S.byIdHistory[i].id)==tostring(id) and S.byIdHistory[i].slot==slot then
            table.remove(S.byIdHistory,i)
        end
    end
    table.insert(S.byIdHistory,1,{id=id,slot=slot,time=tick()})
    if #S.byIdHistory>6 then table.remove(S.byIdHistory,#S.byIdHistory) end
end

-- Переподключаем Apply с историей (через новую функцию)
-- Используем event через pcall чтобы не ломать код — сделаем через showTab rebuild

-- ═══════════════════════════════════════════════════════════════════════
--  SET BUILDER TAB
-- ═══════════════════════════════════════════════════════════════════════

rebuildBuilder=function()
    for _,c in ipairs(BldSF:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end

    local filled=0
    for _,slot in ipairs(SLOT_ORDER) do if S.builder[slot] then filled=filled+1 end end

    -- Header
    local hCard=mkCard(BldSF,px(50),0,C.bg3,true)
    mkStroke(hCard,C.orange,1.5,0.2); mkGrad(hCard,C.bg3,C.bg4,6)
    local hIF=Instance.new("Frame",hCard); hIF.Size=UDim2.fromOffset(px(38),px(38)); hIF.Position=UDim2.fromOffset(px(8),px(6))
    hIF.BackgroundColor3=C.orange; hIF.BackgroundTransparency=0.7; hIF.BorderSizePixel=0; mkCorner(hIF,px(10)); mkGrad(hIF,C.orange,C.gold,3)
    local hIL=Instance.new("TextLabel",hIF); hIL.Size=UDim2.new(1,0,1,0); hIL.BackgroundTransparency=1; hIL.Text="🛠"; hIL.Font=Enum.Font.GothamBlack; hIL.TextSize=px(22)
    local hTL=Instance.new("TextLabel",hCard); hTL.Size=UDim2.new(0.55,0,0,px(22)); hTL.Position=UDim2.fromOffset(px(54),px(6))
    hTL.BackgroundTransparency=1; hTL.Text="Set Builder"; hTL.TextColor3=C.orange; hTL.Font=Enum.Font.GothamBlack; hTL.TextSize=px(16); hTL.TextXAlignment=Enum.TextXAlignment.Left
    local hSL=Instance.new("TextLabel",hCard); hSL.Size=UDim2.new(0.55,0,0,px(13)); hSL.Position=UDim2.fromOffset(px(54),px(29))
    hSL.BackgroundTransparency=1; hSL.Text="Browse → slot → ＋ Add to Set Builder"; hSL.TextColor3=C.textLo; hSL.Font=Enum.Font.Gotham; hSL.TextSize=px(9); hSL.TextXAlignment=Enum.TextXAlignment.Left
    -- Счётчик
    local progF=Instance.new("Frame",hCard); progF.Size=UDim2.fromOffset(px(56),px(38)); progF.Position=UDim2.new(1,-px(62),0.5,-px(19))
    progF.BackgroundColor3=C.bg4; progF.BorderSizePixel=0; mkCorner(progF,px(10)); mkStroke(progF,C.orange,1,0.35)
    local pL=Instance.new("TextLabel",progF); pL.Size=UDim2.new(1,0,0.58,0); pL.BackgroundTransparency=1
    pL.Text=tostring(filled); pL.TextColor3=C.orange; pL.Font=Enum.Font.GothamBlack; pL.TextSize=px(22)
    local pSL=Instance.new("TextLabel",progF); pSL.Size=UDim2.new(1,0,0.42,0); pSL.Position=UDim2.new(0,0,0.58,0); pSL.BackgroundTransparency=1
    pSL.Text="/8 slots"; pSL.TextColor3=C.textLo; pSL.Font=Enum.Font.Gotham; pSL.TextSize=px(8)

    -- Слоты
    for i,slot in ipairs(SLOT_ORDER) do
        local data=S.builder[slot]; local sc=SLOT_COLORS[slot] or C.neon; local has=data~=nil
        local rowH=has and px(70) or px(44)
        local row=mkCard(BldSF,rowH,i,has and C.card or C.bg3,has)
        if not has then mkStroke(row,C.stroke,1,0.7)
        else mkStroke(row,sc,1.5,0.12) end

        if has then
            row.MouseEnter:Connect(function() tw(row,0.1,{BackgroundColor3=C.cardHi}):Play() end)
            row.MouseLeave:Connect(function() tw(row,0.1,{BackgroundColor3=C.card}):Play() end)
        end

        local bar=Instance.new("Frame",row); bar.Size=UDim2.fromOffset(px(4),rowH)
        bar.BackgroundColor3=has and sc or C.bg5; bar.BorderSizePixel=0; mkCorner(bar,px(3))
        if has then mkGrad(bar,sc,C.bg4,4) end

        local isz=has and px(48) or px(34)
        local iF=Instance.new("Frame",row); iF.Size=UDim2.fromOffset(isz,isz)
        iF.Position=UDim2.fromOffset(px(10),math.floor((rowH-isz)/2))
        iF.BackgroundColor3=sc; iF.BackgroundTransparency=has and 0.62 or 0.82; iF.BorderSizePixel=0; mkCorner(iF,px(11))
        if has then mkGrad(iF,sc,C.bg4,5) end
        local iIL=Instance.new("TextLabel",iF); iIL.Size=UDim2.new(1,0,0.6,0); iIL.BackgroundTransparency=1
        iIL.Text=SLOT_ICONS[slot] or ""; iIL.Font=Enum.Font.GothamBold; iIL.TextSize=has and px(22) or px(15)
        local iSL=Instance.new("TextLabel",iF); iSL.Size=UDim2.new(1,0,0.4,0); iSL.Position=UDim2.new(0,0,0.6,0); iSL.BackgroundTransparency=1
        iSL.Text=SLOT_LABELS[slot]; iSL.TextColor3=has and sc or C.textLo; iSL.Font=Enum.Font.GothamBold; iSL.TextSize=px(8)

        local xOff=px(10)+isz+px(8)
        if has then
            local nL=Instance.new("TextLabel",row); nL.Size=UDim2.new(1,-xOff-px(36),0,px(22)); nL.Position=UDim2.fromOffset(xOff,px(5))
            nL.BackgroundTransparency=1; nL.Text=trunc(data.Name or "?",20); nL.TextColor3=C.textHi; nL.Font=Enum.Font.GothamBold; nL.TextSize=px(13); nL.TextXAlignment=Enum.TextXAlignment.Left
            local idStr=tostring(data.AnimationId or ""):match("://(%d+)") or ""
            local iD=Instance.new("TextLabel",row); iD.Size=UDim2.new(1,-xOff-px(36),0,px(13)); iD.Position=UDim2.fromOffset(xOff,px(28))
            iD.BackgroundTransparency=1; iD.Text=idStr~="" and "id:"..idStr or tostring(data.AnimationId)
            iD.TextColor3=C.textLo; iD.Font=Enum.Font.Gotham; iD.TextSize=px(9); iD.TextXAlignment=Enum.TextXAlignment.Left
            local srcL=Instance.new("TextLabel",row); srcL.Size=UDim2.new(1,-xOff-px(36),0,px(12)); srcL.Position=UDim2.fromOffset(xOff,px(51))
            srcL.BackgroundTransparency=1; srcL.Text="📦 "..trunc(data.BundleName or "?",20)
            srcL.TextColor3=sc; srcL.Font=Enum.Font.Gotham; srcL.TextSize=px(9); srcL.TextXAlignment=Enum.TextXAlignment.Left
            local dB=Instance.new("TextButton",row); dB.Size=UDim2.fromOffset(px(26),px(26)); dB.Position=UDim2.new(1,-px(32),0.5,-px(13))
            dB.BackgroundColor3=Color3.fromRGB(115,25,35); dB.Text="✕"; dB.TextColor3=C.white; dB.Font=Enum.Font.GothamBold; dB.TextSize=px(13)
            dB.AutoButtonColor=false; mkCorner(dB,px(7)); mkStroke(dB,C.neonR,1,0.3); hvr(dB,Color3.fromRGB(115,25,35),C.neonR)
            dB.MouseButton1Click:Connect(function()
                S.builder[slot]=nil; rebuildBuilder(); showNotif(SLOT_LABELS[slot].." removed","✕",C.neonR,2)
            end)
        else
            local eL=Instance.new("TextLabel",row); eL.Size=UDim2.new(1,-xOff-px(8),1,0); eL.Position=UDim2.fromOffset(xOff,0)
            eL.BackgroundTransparency=1; eL.Text="Empty — browse & press ＋ Add"
            eL.TextColor3=C.textLo; eL.Font=Enum.Font.Gotham; eL.TextSize=px(10); eL.TextXAlignment=Enum.TextXAlignment.Left
        end
    end

    -- Кнопки
    local btnRow=mkCard(BldSF,px(36),99,nil,true); btnRow.BackgroundTransparency=1; mkStroke(btnRow,C.stroke,0)
    local saveB=Instance.new("TextButton",btnRow)
    saveB.Size=UDim2.new(0.63,-px(3),1,0); saveB.BackgroundColor3=C.neonP; saveB.TextColor3=C.white
    saveB.Text="💾  Save Set ("..filled.." slots)"; saveB.Font=Enum.Font.GothamBold; saveB.TextSize=px(11)
    saveB.AutoButtonColor=false; saveB.ClipsDescendants=true; mkCorner(saveB,px(10))
    mkGrad(saveB,C.neonP,Color3.fromRGB(148,38,208),2.5); hvr(saveB,C.neonP,Color3.fromRGB(188,62,248))
    local clrB=Instance.new("TextButton",btnRow)
    clrB.Size=UDim2.new(0.37,-px(3),1,0); clrB.Position=UDim2.new(0.63,px(3),0,0)
    clrB.BackgroundColor3=C.bg4; clrB.TextColor3=C.neonR; clrB.Text="🗑  Clear All"
    clrB.Font=Enum.Font.GothamBold; clrB.TextSize=px(11); clrB.AutoButtonColor=false
    mkCorner(clrB,px(10)); mkStroke(clrB,C.neonR,1,0.5); hvr(clrB,C.bg4,C.bg5)
    saveB.MouseButton1Click:Connect(function()
        if filled==0 then showNotif("Add at least 1 slot!","!",C.neonR); return end
        openRename("My Set "..(#S.presets+1),function(name)
            local snap={}
            for _,slot in ipairs(SLOT_ORDER) do
                local d=S.builder[slot]
                if d and d.AnimationId and d.AnimationId~="" then
                    snap[slot]={{Name=d.Name,AnimationId=d.AnimationId}}
                end
            end
            local cnt=0; for _ in pairs(snap) do cnt=cnt+1 end
            if cnt==0 then showNotif("No valid animations!","✕",C.neonR); return end
            table.insert(S.presets,{name=name,slots=snap,time=tick()}); jWrite(F_PRESETS,S.presets)
            showNotif("'"..name.."' saved! ("..cnt.." slots)","✓",C.neonP,4)
        end)
    end)
    clrB.MouseButton1Click:Connect(function()
        S.builder={}; rebuildBuilder(); showNotif("Builder cleared","🗑",C.textMid,2)
    end)
    BldSF.CanvasSize=UDim2.new(0,0,0,BldLL.AbsoluteContentSize.Y+px(8))
end

-- ═══════════════════════════════════════════════════════════════════════
--  FAVORITES TAB
-- ═══════════════════════════════════════════════════════════════════════

rebuildFavorites=function()
    for _,c in ipairs(FavSF:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    if #S.favorites==0 then
        local el=mkCard(FavSF,px(70),0,C.bg3,true)
        local eL=Instance.new("TextLabel",el); eL.Size=UDim2.new(1,-px(16),1,0); eL.Position=UDim2.fromOffset(px(8),0)
        eL.BackgroundTransparency=1; eL.Text="No favorites yet.\nBrowse bundles → ☆ Add to Favorites"
        eL.TextColor3=C.textLo; eL.Font=Enum.Font.Gotham; eL.TextSize=px(11); eL.TextWrapped=true
        FavSF.CanvasSize=UDim2.new(0,0,0,px(80)); return
    end
    local sorted={}; for _,f in ipairs(S.favorites) do table.insert(sorted,f) end
    table.sort(sorted,function(a,b) return (a.time or 0)>(b.time or 0) end)
    for idx,fav in ipairs(sorted) do
        local row=mkCard(FavSF,px(60),idx)
        mkStroke(row,Color3.fromRGB(52,44,8),1.5,0.2)
        local ac=Instance.new("Frame",row); ac.Size=UDim2.fromOffset(px(4),px(60)); ac.BackgroundColor3=C.gold; ac.BorderSizePixel=0; mkCorner(ac,px(3))
        local stF=Instance.new("Frame",row); stF.Size=UDim2.fromOffset(px(46),px(46)); stF.Position=UDim2.fromOffset(px(10),px(7))
        stF.BackgroundColor3=Color3.fromRGB(52,44,8); stF.BackgroundTransparency=0.35; stF.BorderSizePixel=0; mkCorner(stF,px(12)); mkStroke(stF,C.gold,1,0.5)
        local stL=Instance.new("TextLabel",stF); stL.Size=UDim2.new(1,0,1,0); stL.BackgroundTransparency=1; stL.Text="★"; stL.TextColor3=C.gold; stL.Font=Enum.Font.GothamBlack; stL.TextSize=px(26)
        local nL=Instance.new("TextLabel",row); nL.Size=UDim2.new(1,-px(200),0,px(24)); nL.Position=UDim2.fromOffset(px(62),px(8))
        nL.BackgroundTransparency=1; nL.Text=trunc(fav.name or "?",20); nL.TextColor3=C.textHi; nL.Font=Enum.Font.GothamBold; nL.TextSize=px(13); nL.TextXAlignment=Enum.TextXAlignment.Left
        local idL=Instance.new("TextLabel",row); idL.Size=UDim2.new(1,-px(200),0,px(14)); idL.Position=UDim2.fromOffset(px(62),px(36))
        idL.BackgroundTransparency=1; idL.Text="Bundle ID: "..tostring(fav.id); idL.TextColor3=C.textLo; idL.Font=Enum.Font.Gotham; idL.TextSize=px(9); idL.TextXAlignment=Enum.TextXAlignment.Left
        local function mkFB(txt,bg,xO,hi,w)
            return mkBtn(row,txt,bg,UDim2.fromOffset(w or px(54),px(26)),UDim2.new(1,xO,0.5,-px(13)),hi,px(10))
        end
        local openB=mkFB("Open",C.neon,-px(120),C.cyan,px(52))
        local wearB=mkFB("▶Wear",C.neonG,-px(64),Color3.fromRGB(48,190,108),px(52))
        local delB=mkFB("✕",Color3.fromRGB(125,28,38),-px(8),C.neonR,px(24))
        openB.MouseButton1Click:Connect(function() inspectBundle(fav.id,fav.name) end)
        wearB.MouseButton1Click:Connect(function()
            wearB.Text="…"; wearB.BackgroundColor3=C.bg4
            task.spawn(function()
                local ok,res=pcall(function() return AssetService:GetBundleDetailsAsync(fav.id) end)
                if ok and res and res.Items then
                    local itemsMap={}
                    for _,item in ipairs(res.Items) do
                        local lt=string.lower(item.AssetType or "")
                        if lt=="swimanimation" then itemsMap["swimanimation"]=item; itemsMap["swimidleanimation"]=item
                        elseif SLOT_LABELS[lt] then itemsMap[lt]=item end
                    end
                    local char=LP.Character; local count=0
                    for slot,item in pairs(itemsMap) do
                        local cs=slot; local ci=item
                        local animData=fetchAnimForSlot(ci,cs)
                        if animData and char then applySlot(char,cs,animData); count=count+1 end
                    end
                    updateEq(); refreshSlotDots(); showNotif("Wearing: "..trunc(fav.name,14).." ("..count..")","▶",C.neonG)
                end
                if wearB and wearB.Parent then wearB.Text="▶Wear"; wearB.BackgroundColor3=C.neonG end
            end)
        end)
        delB.MouseButton1Click:Connect(function()
            remFav(fav.id); refreshFavBtn(); showNotif("Removed from Favorites","☆",C.textMid,2); rebuildFavorites()
        end)
    end
    FavSF.CanvasSize=UDim2.new(0,0,0,FavLL.AbsoluteContentSize.Y+px(8))
end

-- ═══════════════════════════════════════════════════════════════════════
--  MY SETS TAB
-- ═══════════════════════════════════════════════════════════════════════

rebuildSets=function()
    for _,c in ipairs(SetsSF:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    if #S.presets==0 then
        local el=mkCard(SetsSF,px(90),0,C.bg3,true)
        local eL=Instance.new("TextLabel",el); eL.Size=UDim2.new(1,-px(16),1,0); eL.Position=UDim2.fromOffset(px(8),0)
        eL.BackgroundTransparency=1; eL.Text="No sets yet.\n\n① Browse bundle\n② Select slot → ＋ Add to Set Builder\n③ Set Builder → 💾 Save Set"
        eL.TextColor3=C.textLo; eL.Font=Enum.Font.Gotham; eL.TextSize=px(10); eL.TextWrapped=true
        SetsSF.CanvasSize=UDim2.new(0,0,0,px(100)); return
    end
    for idx,preset in ipairs(S.presets) do
        local slotList={}; local slotCount=0
        if preset.slots then
            for _,slot in ipairs(SLOT_ORDER) do
                local list=preset.slots[slot]
                if list and #list>0 and list[1].AnimationId and list[1].AnimationId~="" then
                    slotCount=slotCount+1; table.insert(slotList,slot)
                end
            end
        end
        local row=mkCard(SetsSF,px(92),idx); mkStroke(row,C.neonP,1.5,0.4)
        local bar=Instance.new("Frame",row); bar.Size=UDim2.fromOffset(px(4),px(92)); bar.BackgroundColor3=C.neonP; bar.BorderSizePixel=0; mkCorner(bar,px(3)); mkGrad(bar,C.neonP,C.neon,4)
        local sIF=Instance.new("Frame",row); sIF.Size=UDim2.fromOffset(px(50),px(50)); sIF.Position=UDim2.fromOffset(px(10),px(21))
        sIF.BackgroundColor3=C.neonP; sIF.BackgroundTransparency=0.68; sIF.BorderSizePixel=0; mkCorner(sIF,px(14)); mkGrad(sIF,C.neonP,C.neon,5)
        local sIL=Instance.new("TextLabel",sIF); sIL.Size=UDim2.new(1,0,1,0); sIL.BackgroundTransparency=1; sIL.Text="🎵"; sIL.Font=Enum.Font.GothamBlack; sIL.TextSize=px(24)
        local nL=Instance.new("TextLabel",row); nL.Size=UDim2.new(1,-px(118),0,px(22)); nL.Position=UDim2.fromOffset(px(68),px(5))
        nL.BackgroundTransparency=1; nL.Text=trunc(preset.name or "Set",20); nL.TextColor3=C.textHi; nL.Font=Enum.Font.GothamBlack; nL.TextSize=px(14); nL.TextXAlignment=Enum.TextXAlignment.Left
        local cL=Instance.new("TextLabel",row); cL.Size=UDim2.new(1,-px(118),0,px(13)); cL.Position=UDim2.fromOffset(px(68),px(28))
        cL.BackgroundTransparency=1; cL.Text=slotCount.." animations"; cL.TextColor3=C.neonP; cL.Font=Enum.Font.GothamBold; cL.TextSize=px(10); cL.TextXAlignment=Enum.TextXAlignment.Left
        local chipsF=Instance.new("Frame",row); chipsF.Size=UDim2.new(1,-px(118),0,px(22)); chipsF.Position=UDim2.fromOffset(px(68),px(44))
        chipsF.BackgroundTransparency=1
        local chL=Instance.new("UIListLayout",chipsF); chL.FillDirection=Enum.FillDirection.Horizontal; chL.Padding=UDim.new(0,px(3)); chL.VerticalAlignment=Enum.VerticalAlignment.Center
        for _,slot in ipairs(slotList) do
            local sc=SLOT_COLORS[slot] or C.neon
            local ch=Instance.new("Frame",chipsF); ch.Size=UDim2.fromOffset(px(30),px(18)); ch.BackgroundColor3=sc; ch.BackgroundTransparency=0.35; ch.BorderSizePixel=0; mkCorner(ch,px(5)); mkStroke(ch,sc,1,0.4)
            local chL2=Instance.new("TextLabel",ch); chL2.Size=UDim2.new(1,0,1,0); chL2.BackgroundTransparency=1; chL2.Text=SLOT_LABELS[slot]; chL2.TextColor3=C.white; chL2.Font=Enum.Font.GothamBold; chL2.TextSize=px(8)
        end
        -- Время создания
        if preset.time then
            local tL=Instance.new("TextLabel",row); tL.Size=UDim2.new(1,-px(118),0,px(12)); tL.Position=UDim2.fromOffset(px(68),px(70))
            tL.BackgroundTransparency=1; local dt=os.time()-math.floor(preset.time)
            local dtStr=dt<60 and "just now" or dt<3600 and math.floor(dt/60).."m ago" or math.floor(dt/3600).."h ago"
            tL.Text="Created "..dtStr; tL.TextColor3=C.textLo; tL.Font=Enum.Font.Gotham; tL.TextSize=px(9); tL.TextXAlignment=Enum.TextXAlignment.Left
        end
        local function mkSB(txt,bg,yO,hi,w)
            return mkBtn(row,txt,bg,UDim2.fromOffset(w or px(92),px(24)),UDim2.new(1,-(w or px(92))-px(4),0,yO),hi,px(10))
        end
        local applyB=mkSB("▶  Apply Set",C.neonG,px(5),Color3.fromRGB(48,190,110))
        local editB =mkSB("✎  Edit",C.bg4,px(33),C.bg5,px(86))
        local delB  =mkSB("✕  Delete",C.neonR,px(61),Color3.fromRGB(210,42,62),px(86))
        applyB.MouseButton1Click:Connect(function()
            local char=LP.Character; if not char then return end
            applyB.Text="…"; applyB.BackgroundColor3=C.bg4
            task.spawn(function()
                local count=0
                if preset.slots then
                    for _,slot in ipairs(SLOT_ORDER) do
                        local list=preset.slots[slot]
                        if list and #list>0 and list[1].AnimationId and list[1].AnimationId~="" and char then
                            applySlot(char,slot,{Name=list[1].Name,AnimationId=list[1].AnimationId}); count=count+1
                        end
                    end
                end
                if applyB and applyB.Parent then applyB.Text="▶  Apply Set"; applyB.BackgroundColor3=C.neonG end
                updateEq(); refreshSlotDots()
                showNotif("'"..trunc(preset.name or "Set",12).."' applied ("..count.." slots)","▶",C.neonG)
            end)
        end)
        editB.MouseButton1Click:Connect(function()
            S.builder={}
            if preset.slots then
                for _,slot in ipairs(SLOT_ORDER) do
                    local list=preset.slots[slot]
                    if list and #list>0 then S.builder[slot]={Name=list[1].Name,AnimationId=list[1].AnimationId,BundleName="(from set)",BundleId=0} end
                end
            end
            table.remove(S.presets,idx); jWrite(F_PRESETS,S.presets)
            showNotif("Loaded into Set Builder","✎",C.orange,3)
            for _,sf in ipairs({AnimSF,FavSF,BldSF,SetsSF,CurSF,ByIdSF}) do sf.Visible=false end
            SRow.Visible=false; PagerF.Visible=false; LoadF.Visible=false
            BldSF.Visible=true; setTabStyle("Set Builder"); rebuildBuilder()
        end)
        delB.MouseButton1Click:Connect(function()
            table.remove(S.presets,idx); jWrite(F_PRESETS,S.presets)
            showNotif("Set deleted","✕",C.neonR,2); rebuildSets()
        end)
    end
    SetsSF.CanvasSize=UDim2.new(0,0,0,SetsLL.AbsoluteContentSize.Y+px(8))
end

-- ═══════════════════════════════════════════════════════════════════════
--  CURRENT TAB
-- ═══════════════════════════════════════════════════════════════════════

rebuildCurrent=function()
    for _,c in ipairs(CurSF:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    local hasAny=false
    for idx,slot in ipairs(SLOT_ORDER) do
        local list=S.equipped[slot]
        if list and #list>0 then
            hasAny=true; local sc=SLOT_COLORS[slot] or C.neon
            local row=mkCard(CurSF,px(60),idx); mkStroke(row,sc,1.5,0.4)
            local bar=Instance.new("Frame",row); bar.Size=UDim2.fromOffset(px(4),px(60)); bar.BackgroundColor3=sc; bar.BorderSizePixel=0; mkCorner(bar,px(3)); mkGrad(bar,sc,C.bg4,4)
            local iF=Instance.new("Frame",row); iF.Size=UDim2.fromOffset(px(46),px(46)); iF.Position=UDim2.fromOffset(px(10),px(7))
            iF.BackgroundColor3=sc; iF.BackgroundTransparency=0.72; iF.BorderSizePixel=0; mkCorner(iF,px(12)); mkGrad(iF,sc,C.bg4,5)
            local iL=Instance.new("TextLabel",iF); iL.Size=UDim2.new(1,0,0.6,0); iL.BackgroundTransparency=1; iL.Text=SLOT_ICONS[slot] or ""; iL.Font=Enum.Font.GothamBold; iL.TextSize=px(22)
            local iSL=Instance.new("TextLabel",iF); iSL.Size=UDim2.new(1,0,0.4,0); iSL.Position=UDim2.new(0,0,0.6,0); iSL.BackgroundTransparency=1; iSL.Text=SLOT_LABELS[slot]; iSL.TextColor3=sc; iSL.Font=Enum.Font.GothamBold; iSL.TextSize=px(8)
            local aL=Instance.new("TextLabel",row); aL.Size=UDim2.new(1,-px(162),0,px(23)); aL.Position=UDim2.fromOffset(px(62),px(6))
            aL.BackgroundTransparency=1; aL.Text=trunc(list[1].Name or "?",18); aL.TextColor3=C.textHi; aL.Font=Enum.Font.GothamBold; aL.TextSize=px(14); aL.TextXAlignment=Enum.TextXAlignment.Left
            local idStr=tostring(list[1].AnimationId or ""):match("://(%d+)") or ""
            local idL=Instance.new("TextLabel",row); idL.Size=UDim2.new(1,-px(162),0,px(14)); idL.Position=UDim2.fromOffset(px(62),px(32))
            idL.BackgroundTransparency=1; idL.Text=idStr~="" and "rbxassetid://"..idStr or ""; idL.TextColor3=C.textLo; idL.Font=Enum.Font.Gotham; idL.TextSize=px(9); idL.TextXAlignment=Enum.TextXAlignment.Left

            -- Кнопка копировать ID
            local cpB=Instance.new("TextButton",row); cpB.Size=UDim2.fromOffset(px(22),px(22)); cpB.Position=UDim2.new(1,-px(162),0.5,-px(11))
            cpB.BackgroundColor3=C.bg4; cpB.Text="⧉"; cpB.TextColor3=C.textMid; cpB.Font=Enum.Font.GothamBold; cpB.TextSize=px(12); cpB.AutoButtonColor=false
            mkCorner(cpB,px(6)); mkStroke(cpB,C.strokeHi,1,0.4)
            if idStr~="" then
                hvr(cpB,C.bg4,C.bg5)
                cpB.MouseButton1Click:Connect(function()
                    setclipboard("rbxassetid://"..idStr)
                    cpB.Text="✓"; cpB.TextColor3=C.neonG
                    task.delay(1.5,function() if cpB and cpB.Parent then cpB.Text="⧉"; cpB.TextColor3=C.textMid end end)
                    showNotif("ID copied!","⧉",C.neonG,2)
                end)
            end

            local rstB=mkBtn(row,"↩",Color3.fromRGB(128,62,24),UDim2.fromOffset(px(24),px(24)),UDim2.new(1,-px(130),0.5,-px(12)),Color3.fromRGB(178,86,38),px(14))
            local rmB=mkBtn(row,"✕ Remove",C.neonR,UDim2.fromOffset(px(62),px(24)),UDim2.new(1,-px(66),0.5,-px(12)),Color3.fromRGB(210,42,62),px(10))
            rstB.MouseButton1Click:Connect(function()
                local char=LP.Character; if not char then return end
                resetSlot(char,slot); updateEq(); refreshSlotDots()
                showNotif(SLOT_LABELS[slot].." → default","↩",C.orange,2); rebuildCurrent()
            end)
            rmB.MouseButton1Click:Connect(function()
                S.equipped[slot]=nil; S.equippedNames[slot]=nil; jWrite(F_EQUIPPED,S.equipped); savePS()
                local char=LP.Character
                if char then local a=char:FindFirstChild("Animate"); if a then a.Disabled=true; task.wait(0.05); a.Disabled=false end end
                showNotif(SLOT_LABELS[slot].." removed","✕",C.neonR,2); updateEq(); refreshSlotDots(); rebuildCurrent()
            end)
        end
    end
    if hasAny then
        local rARow=mkCard(CurSF,px(36),999,nil,true); rARow.BackgroundTransparency=1; mkStroke(rARow,C.stroke,0)
        local rAB=mkBtn(rARow,"↩  Reset ALL to Default",Color3.fromRGB(88,44,12),UDim2.new(1,0,1,0),UDim2.fromOffset(0,0),Color3.fromRGB(142,70,22),px(12))
        mkStroke(rAB,Color3.fromRGB(182,92,36),1)
        rAB.MouseButton1Click:Connect(function()
            local char=LP.Character; if not char then return end
            for _,slot in ipairs(SLOT_ORDER) do resetSlot(char,slot) end
            S.equipped={}; S.equippedNames={}; jWrite(F_EQUIPPED,S.equipped); savePS()
            updateEq(); refreshSlotDots(); showNotif("All reset to default!","↩",C.orange,4); rebuildCurrent()
        end)
    end
    if not hasAny then
        local el=mkCard(CurSF,px(70),0,C.bg3,true)
        local eL=Instance.new("TextLabel",el); eL.Size=UDim2.new(1,-px(16),1,0); eL.Position=UDim2.fromOffset(px(8),0)
        eL.BackgroundTransparency=1; eL.Text="Nothing equipped yet.\nBrowse bundles → ▶ Wear!"; eL.TextColor3=C.textLo; eL.Font=Enum.Font.Gotham; eL.TextSize=px(12); eL.TextWrapped=true
    end
    CurSF.CanvasSize=UDim2.new(0,0,0,CurLL.AbsoluteContentSize.Y+px(8))
end

-- ═══════════════════════════════════════════════════════════════════════
--  ANIMATIONS GRID
-- ═══════════════════════════════════════════════════════════════════════

local function killGrid() for _,th in ipairs(S.gridThreads) do task.cancel(th) end; S.gridThreads={} end

local function makeRow(bundle)
    local ROW_H=px(68)
    local row=mkCard(AnimSF,ROW_H,0); row.ClipsDescendants=true
    mkStroke(row,C.stroke,1,0.7)
    row.MouseEnter:Connect(function()
        tw(row,0.1,{BackgroundColor3=C.cardHi}):Play()
        local st=row:FindFirstChildOfClass("UIStroke"); if st then tw(st,0.1,{Color=C.strokeHi,Transparency=0.2}):Play() end
    end)
    row.MouseLeave:Connect(function()
        tw(row,0.1,{BackgroundColor3=C.card}):Play()
        local st=row:FindFirstChildOfClass("UIStroke"); if st then tw(st,0.1,{Color=C.stroke,Transparency=0.7}):Play() end
    end)

    local bar=Instance.new("Frame",row); bar.Size=UDim2.fromOffset(px(3),ROW_H); bar.BackgroundColor3=C.neon; bar.BorderSizePixel=0; mkCorner(bar,px(2))
    local miniVP=Instance.new("ViewportFrame",row)
    miniVP.Size=UDim2.fromOffset(px(54),px(54)); miniVP.Position=UDim2.fromOffset(px(10),px(7))
    miniVP.BackgroundColor3=C.overlay; miniVP.BackgroundTransparency=0.12; mkCorner(miniVP,px(10)); mkStroke(miniVP,C.strokeHi,1,0.5)
    local nL=Instance.new("TextLabel",row); nL.Size=UDim2.new(1,-px(166),0,px(22)); nL.Position=UDim2.fromOffset(px(70),px(5))
    nL.BackgroundTransparency=1; nL.Text=trunc(bundle.Name or "?",23); nL.TextColor3=C.textHi; nL.Font=Enum.Font.GothamBold; nL.TextSize=px(13); nL.TextXAlignment=Enum.TextXAlignment.Left
    local iL=Instance.new("TextLabel",row); iL.Size=UDim2.new(1,-px(166),0,px(13)); iL.Position=UDim2.fromOffset(px(70),px(29))
    iL.BackgroundTransparency=1; iL.Text="ID: "..tostring(bundle.Id); iL.TextColor3=C.textLo; iL.Font=Enum.Font.Gotham; iL.TextSize=px(9); iL.TextXAlignment=Enum.TextXAlignment.Left

    local favd=isFav(bundle.Id)
    local starB=Instance.new("TextButton",row); starB.Size=UDim2.fromOffset(px(22),px(22)); starB.Position=UDim2.new(1,-px(108),0.5,-px(11))
    starB.BackgroundTransparency=1; starB.Text=favd and "★" or "☆"; starB.TextColor3=favd and C.gold or C.textLo; starB.Font=Enum.Font.GothamBlack; starB.TextSize=px(20); starB.AutoButtonColor=false

    local wBtn=mkBtn(row,"▶ Wear",C.neonG,UDim2.fromOffset(px(76),px(30)),UDim2.new(1,-px(80),0.5,-px(15)),Color3.fromRGB(48,190,108),px(10))
    mkGrad(wBtn,C.neonG,Color3.fromRGB(48,190,108),2); mkStroke(wBtn,C.neonG,1,0.3)

    local hitB=Instance.new("TextButton",row); hitB.Size=UDim2.new(1,-px(114),1,0); hitB.BackgroundTransparency=1; hitB.Text=""; hitB.ZIndex=2
    hitB.MouseButton1Click:Connect(function() inspectBundle(bundle.Id,bundle.Name) end)

    starB.MouseButton1Click:Connect(function()
        if isFav(bundle.Id) then remFav(bundle.Id); starB.Text="☆"; starB.TextColor3=C.textLo; showNotif("Removed from Favorites","☆",C.textMid,2)
        else addFav(bundle.Id,bundle.Name); starB.Text="★"; starB.TextColor3=C.gold; showNotif("Added: "..trunc(bundle.Name,16),"★",C.gold) end
        refreshFavBtn(); if S.tab=="Favorites" then rebuildFavorites() end
    end)
    wBtn.MouseButton1Click:Connect(function()
        wBtn.Text="…"; wBtn.BackgroundColor3=C.bg4
        task.spawn(function()
            local ok,res=pcall(function() return AssetService:GetBundleDetailsAsync(bundle.Id) end)
            if ok and res and res.Items then
                local itemsMap={}
                for _,item in ipairs(res.Items) do
                    local lt=string.lower(item.AssetType or "")
                    if lt=="swimanimation" then itemsMap["swimanimation"]=item; itemsMap["swimidleanimation"]=item
                    elseif SLOT_LABELS[lt] then itemsMap[lt]=item end
                end
                local char=LP.Character; local count=0
                for slot,item in pairs(itemsMap) do
                    local cs=slot; local ci=item
                    local animData=fetchAnimForSlot(ci,cs)
                    if animData and char then applySlot(char,cs,animData); count=count+1 end
                end
                updateEq(); refreshSlotDots(); showNotif("Wearing: "..trunc(bundle.Name,15).." ("..count..")","▶",C.neonG)
            end
            if wBtn and wBtn.Parent then wBtn.Text="▶ Wear"; wBtn.BackgroundColor3=C.neonG end
        end)
    end)

    local loopTh=task.spawn(function()
        local ok,det=pcall(function() return AssetService:GetBundleDetailsAsync(bundle.Id) end)
        if not ok or not det or not det.Items then return end
        local usable={}
        for _,si in ipairs(det.Items) do if SLOT_TO_FOLDER[string.lower(si.AssetType or "")] then table.insert(usable,si) end end
        if #usable==0 then return end
        local mD,mA,mC=buildSkeleton(miniVP); if not mD then return end
        local i2,curT=1,nil
        while row and row.Parent do
            local si=usable[i2]; local cs=string.lower(si.AssetType or "")
            local animData=fetchAnimForSlot(si,cs)
            if animData then
                if curT then pcall(function() curT:Stop() end) end
                local track=Instance.new("Animation"); track.AnimationId=animData.AnimationId
                local ok2,ct=safePT(mA,track,true); if ok2 then curT=ct end
            end
            task.wait(4); i2=(i2%#usable)+1
        end
        if mC then mC:Disconnect() end
    end)
    table.insert(S.gridThreads,loopTh); row.Destroying:Connect(function() task.cancel(loopTh) end)
    return row
end

local function drawPage(list)
    killGrid()
    for _,c in ipairs(AnimSF:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
    LoadF.Visible=false
    local s2=(S.page-1)*S.perPage+1; local e2=math.min(S.page*S.perPage,#list)
    for i=s2,e2 do if list[i] then makeRow(list[i]) end end
    AnimSF.CanvasSize=UDim2.new(0,0,0,AnimLL.AbsoluteContentSize.Y+px(8))
    AnimSF.CanvasPosition=Vector2.zero
    local tp=math.max(1,math.ceil(#list/S.perPage)); PageLbl.Text=("Page %d/%d"):format(S.page,tp)
    PrevBtn.BackgroundColor3=S.page>1 and C.bg4 or C.bg3; PrevBtn.TextColor3=S.page>1 and C.textMid or C.textLo
end

local function doSearch(query)
    S.page=1; LoadF.Visible=true; killGrid(); savePS()
    S.searchList={}; S.catCursor=nil
    local p=CatalogSearchParams.new(); p.SearchKeyword=query or ""; p.BundleTypes={Enum.BundleType.Animations}; p.IncludeOffSale=true; p.Limit=60
    pcall(function() p.SalesTypeFilter=Enum.SalesTypeFilter.All end)
    pcall(function() p.SortType=Enum.CatalogSortType.RecentlyCreated end)
    task.spawn(function()
        local ok,pages=pcall(function() return AvatarEditor:SearchCatalog(p) end)
        if ok and pages then S.catCursor=pages; S.searchList=pages:GetCurrentPage(); savePS(); drawPage(S.searchList)
        else LoadF.Visible=false; PageLbl.Text="Error"; showNotif("Search failed","✕",C.neonR) end
    end)
end

SBtn.MouseButton1Click:Connect(function() if S.tab=="Animations" then doSearch(SBox.Text) end end)
SBox.FocusLost:Connect(function(enter) if enter and S.tab=="Animations" then doSearch(SBox.Text) end end)
NextBtn.MouseButton1Click:Connect(function()
    if S.page*S.perPage<#S.searchList then S.page=S.page+1; savePS(); drawPage(S.searchList)
    elseif S.tab=="Animations" and S.catCursor and not S.catCursor.IsFinished then
        LoadF.Visible=true
        task.spawn(function()
            local ok=pcall(function() S.catCursor:AdvanceToNextPageAsync() end)
            if ok then
                local more=S.catCursor:GetCurrentPage()
                for _,v in ipairs(more) do table.insert(S.searchList,v) end
                S.page=S.page+1; savePS(); drawPage(S.searchList)
            end
        end)
    end
end)
PrevBtn.MouseButton1Click:Connect(function()
    if S.page>1 then S.page=S.page-1; savePS(); drawPage(S.searchList) end
end)

-- ── Tab switching ──────────────────────────────────────────────────────
local function showTab(name)
    setTabStyle(name)
    AnimSF.Visible=(name=="Animations");    FavSF.Visible=(name=="Favorites")
    BldSF.Visible=(name=="Set Builder");   SetsSF.Visible=(name=="My Sets")
    CurSF.Visible=(name=="Current");       ByIdSF.Visible=(name=="By ID")
    SRow.Visible=(name=="Animations");     PagerF.Visible=(name=="Animations")
    LoadF.Visible=false
    if name=="Animations" then
        if #S.searchList==0 then doSearch("") else drawPage(S.searchList) end
    elseif name=="Favorites"    then rebuildFavorites()
    elseif name=="Set Builder"  then rebuildBuilder()
    elseif name=="My Sets"      then rebuildSets()
    elseif name=="Current"      then rebuildCurrent(); updateEq()
    elseif name=="By ID"        then rebuildById()
    end
end

for tN,tb in pairs(tabBtns) do tb.MouseButton1Click:Connect(function() showTab(tN) end) end

-- Boot
Win.Size=UDim2.fromOffset(WIN_W,0)
task.delay(0.1,function()
    tw(Win,0.38,{Size=UDim2.fromOffset(WIN_W,WIN_H)},Enum.EasingStyle.Back):Play()
    task.wait(0.4)
    if S.bundleId then inspectBundle(S.bundleId,S.bundleName) end
    showTab(S.tab); updateEq(); refreshSlotDots()
    task.wait(0.4); showNotif("v3.7 — Wear by ID + New UI!","▶",C.neon,3)
end)

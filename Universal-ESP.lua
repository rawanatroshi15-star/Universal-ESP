--[[
============================================================
-- 🎯 UNIVERSAL ESP V24 — based on V23
-- ✍️ By Mr.One
-- ✅ السكيليتون: أبيض افتراضياً، لا يتأثر بـ Wall Check، وزر لتغيير لونه
-- ✅ المركبات: مطفية افتراضياً، بدون بوكس (اسم المركبة + المسافة فقط)
-- ✅ أسهم خارج الشاشة (Off-Screen Arrows)
-- ✅ كشف السلاح/الأداة التي يحملها اللاعب
-- ✅ حفظ الإعدادات تلقائياً (writefile / readfile + JSON)
-- ✅ اختصار كيبورد لإخفاء/إظهار القائمة (RightShift افتراضياً)
-- ✅ V23: كشف الغنائم (Loot ESP) + آثار الأقدام (Trails)
-- 🆕 V24 — تقسيم الواجهة إلى تبويبات (Tabs):
--    👁️ ESP       : الكشف الأساسي + العناصر المرئية + الألوان
--    🎯 Aim       : الأيم بوت (FOV + نعومة + Wall Check + تثبيت الهدف)
--    🌍 العالم     : المركبات + الغنائم + آثار الأقدام
--    ⚙️ الإعدادات  : الأداء + مسافة الكشف + مفتاح القائمة + إعادة الضبط
--    + مفاتيح تشغيل بشكل Switch + عناوين أقسام + تذكّر آخر تبويب
-- ============================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local AUTHOR_SIGNATURE = "Mr.One"

local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.UniversalESP_Kill then
    pcall(env.UniversalESP_Kill)
    env.UniversalESP_Kill = nil
end

-- ========================== الإعدادات ==========================
local DEFAULTS = {
    ESPEnabled = true, TeamCheck = true, Tracers = true, Box = true,
    Names = true, Health = true, ShowDistance = true, Highlight = false,
    WallCheck = true, ShowBots = false, Skeleton = false, PerfMode = false,
    Vehicles = false, Arrows = true, Weapons = true,
    LootESP = false, Trails = false,
    -- 🎯 الأيم بوت
    AimEnabled = false, AimFOVCircle = true, AimWallCheck = true,
    AimSticky = false, AimBots = false, AimFOV = 150, AimSmooth = 6,
    AimMousePct = 100, AimFaceChar = true,
    MaxDistance = 2000,
}
local PREF_DEFAULTS = {
    EnemyColorIdx = 1,
    SkeletonColorIdx = 1,        -- 1 = أبيض
    ToggleKey = "RightShift",
    LootFilter = 1,              -- 1 = الكل
    TrailColorIdx = 1,           -- 1 = سماوي
    AimPartIdx = 1,              -- 1 = الرأس
    AimKeyIdx = 1,               -- 1 = زر الماوس الأيمن
    AimMethodIdx = 1,            -- 1 = حركة الماوس (الأفضل)، 2 = الكاميرا مباشرة
    LastTab = 1,                 -- 🆕 V24: آخر تبويب مفتوح
}

local Config, Prefs = {}, {}
for k, v in pairs(DEFAULTS) do Config[k] = v end
for k, v in pairs(PREF_DEFAULTS) do Prefs[k] = v end

local SKELETON_MAX_DIST = 500

local ENEMY_PALETTE = {
    Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(255, 255, 0), Color3.fromRGB(170, 0, 255),
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 255, 255),
}
local SKELETON_PALETTE = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(255, 255, 0), Color3.fromRGB(0, 255, 255),
    Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 150, 0),
    Color3.fromRGB(0, 255, 0),
}
local TRAIL_PALETTE = {
    Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 150, 0),
    Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 60, 60),
    Color3.fromRGB(0, 255, 0),
}
local LOOT_FILTERS = {"الكل", "أسلحة/أدوات", "ذخيرة/علاج", "نقود", "صناديق/موارد"}
local TOGGLE_KEYS = {"RightShift", "Insert", "RightControl", "Home", "End", "Delete"}
local AIM_PARTS = {"الرأس", "الصدر", "الأقرب للمؤشر"}
local AIM_KEYS  = {"زر الماوس الأيمن", "زر الماوس الأيسر", "تلقائي (دائماً)", "زر على الشاشة"}
local AIM_METHODS = {"حركة الماوس", "الكاميرا"}
local HAS_MOUSEMOVE = typeof(mousemoverel) == "function"   -- غير موجودة عادة على الهاتف

-- 🆕 V24: تعريف التبويبات (لإضافة تبويب جديد أضف سطراً هنا فقط)
local TAB_DEFS = {
    { icon = "👁️", name = "ESP" },
    { icon = "🎯", name = "Aim" },
    { icon = "🌍", name = "العالم" },
    { icon = "⚙️", name = "إعدادات" },
}

local ENEMY_COLOR = ENEMY_PALETTE[1]
local SKELETON_COLOR = SKELETON_PALETTE[1]
local TRAIL_COLOR = TRAIL_PALETTE[1]
local TEAM_COLOR  = Color3.fromRGB(0, 140, 255)
local WALL_COLOR  = Color3.fromRGB(255, 0, 0)
local BOT_COLOR   = Color3.fromRGB(255, 150, 0)
local VEH_COLOR   = Color3.fromRGB(255, 215, 0)

local function applyPrefs()
    Prefs.EnemyColorIdx = math.clamp(math.floor(Prefs.EnemyColorIdx), 1, #ENEMY_PALETTE)
    Prefs.SkeletonColorIdx = math.clamp(math.floor(Prefs.SkeletonColorIdx), 1, #SKELETON_PALETTE)
    Prefs.TrailColorIdx = math.clamp(math.floor(Prefs.TrailColorIdx), 1, #TRAIL_PALETTE)
    Prefs.LootFilter = math.clamp(math.floor(Prefs.LootFilter), 1, #LOOT_FILTERS)
    Prefs.LastTab = math.clamp(math.floor(Prefs.LastTab), 1, #TAB_DEFS)
    Prefs.AimPartIdx = math.clamp(math.floor(Prefs.AimPartIdx), 1, #AIM_PARTS)
    Prefs.AimKeyIdx = math.clamp(math.floor(Prefs.AimKeyIdx), 1, #AIM_KEYS)
    Prefs.AimMethodIdx = math.clamp(math.floor(Prefs.AimMethodIdx), 1, #AIM_METHODS)
    local valid = false
    for _, k in ipairs(TOGGLE_KEYS) do
        if k == Prefs.ToggleKey then valid = true end
    end
    if not valid then Prefs.ToggleKey = PREF_DEFAULTS.ToggleKey end
    ENEMY_COLOR = ENEMY_PALETTE[Prefs.EnemyColorIdx]
    SKELETON_COLOR = SKELETON_PALETTE[Prefs.SkeletonColorIdx]
    TRAIL_COLOR = TRAIL_PALETTE[Prefs.TrailColorIdx]
end

-- ========================== حفظ الإعدادات ==========================
local CONFIG_FILE = "UniversalESP_" .. AUTHOR_SIGNATURE .. ".json"
local CAN_FILE = typeof(writefile) == "function" and typeof(readfile) == "function"

local function saveConfig()
    if not CAN_FILE then return end
    pcall(function()
        local data = { version = 24, config = Config, prefs = Prefs }
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    if not CAN_FILE then return false end
    if typeof(isfile) == "function" then
        local okf, exists = pcall(isfile, CONFIG_FILE)
        if not okf or exists ~= true then return false end
    end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or type(raw) ~= "string" or raw == "" then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return false end

    if type(data.config) == "table" then
        for k, def in pairs(DEFAULTS) do
            local val = data.config[k]
            if type(val) == type(def) then Config[k] = val end
        end
    end
    Config.MaxDistance = math.clamp(Config.MaxDistance, 100, 5000)
    Config.AimFOV = math.clamp(Config.AimFOV, 20, 600)
    Config.AimSmooth = math.clamp(Config.AimSmooth, 1, 20)
    Config.AimMousePct = math.clamp(Config.AimMousePct, 30, 300)

    if type(data.prefs) == "table" then
        for k, def in pairs(PREF_DEFAULTS) do
            local val = data.prefs[k]
            if type(val) == type(def) then Prefs[k] = val end
        end
    end
    applyPrefs()
    return true
end

local saveToken = 0
local Running = true
local function scheduleSave()
    saveToken = saveToken + 1
    local mine = saveToken
    task.delay(0.8, function()
        if mine == saveToken and Running then saveConfig() end
    end)
end

local loadedFromFile = loadConfig()
applyPrefs()

-- ========================== متغيرات عامة ==========================
local BIND_NAME = "UniversalESP_" .. AUTHOR_SIGNATURE
local entries, botCache, conns = {}, {}, {}
local vehicles, vehicleCount = {}, 0
local vehScanned = false
local Loot = { items = {}, count = 0, scanned = false }   -- تُملأ دوالّه لاحقاً

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function track(c) conns[#conns + 1] = c return c end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then Camera = workspace.CurrentCamera end
end))

-- ========================== أدوات ==========================
local function addCorner(p, r)
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p return c
end
local function addStroke(p, col, th)
    local s = Instance.new("UIStroke") s.Color = col s.Thickness = th s.Parent = p return s
end
local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch
end
-- لون نص مقروء فوق خلفية ملونة
local function textFor(c)
    local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
    if lum > 0.55 then return Color3.new(0, 0, 0) end
    return Color3.new(1, 1, 1)
end

-- ========================== الـ GUI ==========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UniversalESP_V24_" .. AUTHOR_SIGNATURE
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999

local parented = false
if typeof(gethui) == "function" then
    parented = pcall(function() screenGui.Parent = gethui() end)
else
    parented = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
end
if not parented then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local espContainer = Instance.new("Frame")
espContainer.Size = UDim2.new(1, 0, 1, 0)
espContainer.BackgroundTransparency = 1
espContainer.ZIndex = 5
espContainer.Parent = screenGui

-- ===== أدوات حدود الشاشة =====
local MARGIN = 6

local function viewport()
    local s = screenGui.AbsoluteSize
    if s.X < 100 or s.Y < 100 then
        local cam = workspace.CurrentCamera
        if cam then s = cam.ViewportSize end
    end
    if s.X < 100 or s.Y < 100 then s = Vector2.new(800, 400) end
    return s
end

local function topInset()
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    if ok and inset then return inset.Y end
    return 0
end

local function clampXY(x, y, w, h)
    local vp = viewport()
    local minY = topInset() + 2
    local maxX = math.max(2, vp.X - w - 2)
    local maxY = math.max(minY, vp.Y - h - 2)
    return math.clamp(x, 2, maxX), math.clamp(y, minY, maxY)
end

-- سحب سموث
local smoothTargets = {}
track(RunService.RenderStepped:Connect(function()
    if not Running then return end
    for frame, target in pairs(smoothTargets) do
        if frame and frame.Parent then
            frame.Position = frame.Position:Lerp(target, 0.45)
        else
            smoothTargets[frame] = nil
        end
    end
end))

-- ===== تنظيف الرسومات =====
local function destroyVisuals(v)
    if not v then return end
    for _, key in ipairs({"box", "tracer", "nameLbl", "infoLbl", "toolLbl", "hpBg", "hpFill",
        "arrow", "arrowTxt", "highlight"}) do
        if v[key] then
            pcall(function() v[key]:Destroy() end)
            v[key] = nil
        end
    end
    if v.bones then
        for _, b in ipairs(v.bones) do
            pcall(function() b.frame:Destroy() end)
        end
        v.bones = nil
    end
    if v.trail then
        for _, s in ipairs(v.trail.segs) do
            pcall(function() s.f:Destroy() end)
        end
        v.trail = nil
    end
end

local function destroyVehicle(e)
    if e and e.v then
        pcall(function() e.v.lbl:Destroy() end)
        e.v = nil
    end
end

local function killScript()
    if not Running then return end
    pcall(saveConfig)
    Running = false
    pcall(function() RunService:UnbindFromRenderStep(BIND_NAME) end)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    for _, e in pairs(entries) do destroyVisuals(e.visuals) end
    for _, e in pairs(botCache) do destroyVisuals(e.visuals) end
    for _, e in pairs(vehicles) do destroyVehicle(e) end
    if Loot.destroyAll then pcall(Loot.destroyAll) end
    if env.UniversalESP_AimCleanup then
        pcall(env.UniversalESP_AimCleanup)
        env.UniversalESP_AimCleanup = nil
    end
    entries, botCache, vehicles = {}, {}, {}
    pcall(function() screenGui:Destroy() end)
    if env.UniversalESP_Kill == killScript then env.UniversalESP_Kill = nil end
    print("🗑️ تم إغلاق Universal ESP نهائياً By " .. AUTHOR_SIGNATURE)
end
env.UniversalESP_Kill = killScript

-- ========================== القائمة ==========================
local menuW, menuH = 250, 565
local uiReady = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(menuW, menuH)
mainFrame.Position = UDim2.fromOffset(70, 40)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = false -- تظهر بعد شاشة التحميل
mainFrame.ZIndex = 50
mainFrame.Parent = screenGui
addCorner(mainFrame, 10)
addStroke(mainFrame, Color3.fromRGB(0, 190, 170), 1.5)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
topBar.BorderSizePixel = 0
topBar.ZIndex = 50
topBar.Parent = mainFrame
addCorner(topBar, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -85, 1, 0)
title.Position = UDim2.new(0, 8, 0, 0)
title.Text = "🎯 ESP V24 • " .. AUTHOR_SIGNATURE
title.TextColor3 = Color3.fromRGB(0, 255, 180)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextTruncate = Enum.TextTruncate.AtEnd
title.ZIndex = 50
title.Parent = topBar

-- عداد FPS / Ping
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -16, 0, 16)
fpsLabel.Position = UDim2.new(0, 8, 0, 38)
fpsLabel.BackgroundTransparency = 1
fpsLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 10
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.ZIndex = 50
fpsLabel.Text = "FPS: -- | Ping: --"
fpsLabel.Parent = mainFrame

local fpsAcc, fpsFrames = 0, 0
track(RunService.RenderStepped:Connect(function(dt)
    if not Running then return end
    fpsAcc = fpsAcc + dt
    fpsFrames = fpsFrames + 1
    if fpsAcc >= 0.5 then
        local fps = math.floor(fpsFrames / fpsAcc + 0.5)
        fpsAcc, fpsFrames = 0, 0
        local ping = "?"
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        fpsLabel.Text = "FPS: " .. fps .. " | Ping: " .. ping .. "ms"
        fpsLabel.TextColor3 = fps >= 40 and Color3.fromRGB(120, 255, 120)
            or (fps >= 20 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 80, 80))
    end
end))

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 24, 0, 22)
minimizeBtn.Position = UDim2.new(1, -56, 0, 7)
minimizeBtn.Text = "—"
minimizeBtn.BackgroundColor3 = Color3.fromRGB(230, 160, 30)
minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.ZIndex = 50
minimizeBtn.Parent = topBar
addCorner(minimizeBtn, 6)

local closeAllBtn = Instance.new("TextButton")
closeAllBtn.Size = UDim2.new(0, 24, 0, 22)
closeAllBtn.Position = UDim2.new(1, -28, 0, 7)
closeAllBtn.Text = "X"
closeAllBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeAllBtn.TextColor3 = Color3.new(1, 1, 1)
closeAllBtn.Font = Enum.Font.GothamBold
closeAllBtn.TextSize = 12
closeAllBtn.ZIndex = 50
closeAllBtn.Parent = topBar
addCorner(closeAllBtn, 6)

closeAllBtn.MouseButton1Click:Connect(killScript)
minimizeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

-- الزر المربع
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(42, 42)
toggleBtn.Position = UDim2.fromOffset(600, 200)
toggleBtn.Text = "🎯"
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 136)
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 18
toggleBtn.Visible = false -- يظهر بعد شاشة التحميل
toggleBtn.ZIndex = 100
toggleBtn.Parent = screenGui
addCorner(toggleBtn, 8)
addStroke(toggleBtn, Color3.new(1, 1, 1), 1.5)

-- ===== السحب (مع حبس داخل الشاشة) =====
local dragging, dragInput, dragStart, startPos
local function getDims(frame)
    if frame == mainFrame then return menuW, menuH end
    return frame.AbsoluteSize.X, frame.AbsoluteSize.Y
end

local function makeDraggable(dragFrame, moveFrame)
    dragFrame.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging, dragStart, startPos = moveFrame, input.Position, moveFrame.Position
        end
    end)
    dragFrame.InputChanged:Connect(function(input)
        if isMove(input) then dragInput = input end
    end)
end
track(UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput and isMove(input) then
        local delta = input.Position - dragStart
        local w, h = getDims(dragging)
        local nx, ny = clampXY(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y, w, h)
        smoothTargets[dragging] = UDim2.fromOffset(nx, ny)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if isPress(input) then dragging = nil end
end))

makeDraggable(topBar, mainFrame)
makeDraggable(toggleBtn, toggleBtn)

-- ===== ملاءمة القائمة لحجم الشاشة =====
local function applyLayout(initial)
    local vp = viewport()
    local inset = topInset()
    menuW = math.clamp(vp.X - MARGIN * 2, 180, 250)
    menuH = math.clamp(vp.Y - inset - MARGIN * 2 - 4, 150, 565)
    mainFrame.Size = UDim2.fromOffset(menuW, menuH)

    local px, py
    if initial then
        px, py = 70, inset + MARGIN
    else
        px, py = mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset
    end
    px, py = clampXY(px, py, menuW, menuH)
    local mpos = UDim2.fromOffset(px, py)
    mainFrame.Position = mpos
    smoothTargets[mainFrame] = mpos

    local tx, ty
    if initial then
        tx, ty = vp.X - 70, vp.Y * 0.7
    else
        tx, ty = toggleBtn.Position.X.Offset, toggleBtn.Position.Y.Offset
    end
    tx, ty = clampXY(tx, ty, 42, 42)
    local tpos = UDim2.fromOffset(tx, ty)
    toggleBtn.Position = tpos
    smoothTargets[toggleBtn] = tpos
end

applyLayout(true)
track(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if Running then applyLayout(false) end
end))
task.defer(function()
    if Running then applyLayout(true) end
end)

local toggleDown, toggleMoved = nil, false
toggleBtn.InputBegan:Connect(function(input)
    if isPress(input) then toggleDown, toggleMoved = input.Position, false end
end)
toggleBtn.InputEnded:Connect(function(input)
    if isPress(input) then
        if toggleDown and not toggleMoved and Running then
            mainFrame.Visible = not mainFrame.Visible
        end
        toggleDown = nil
    end
end)
track(UserInputService.InputChanged:Connect(function(input)
    if toggleDown and isMove(input) then
        if (input.Position - toggleDown).Magnitude > 10 then toggleMoved = true end
    end
end))

-- ===== اختصار الكيبورد لإخفاء/إظهار القائمة =====
track(UserInputService.InputBegan:Connect(function(input)
    if not Running or not uiReady then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode.Name == Prefs.ToggleKey then
        mainFrame.Visible = not mainFrame.Visible
    end
end))

-- ============================================================
-- 🆕 V24: نظام التبويبات (Tabs)
-- ============================================================
local ROW_BG    = Color3.fromRGB(32, 32, 32)
local ROW_BG_HI = Color3.fromRGB(46, 46, 46)
local ACCENT    = Color3.fromRGB(0, 190, 170)
local ACCENT_DK = Color3.fromRGB(0, 150, 136)
local ON_COLOR  = Color3.fromRGB(46, 204, 113)
local OFF_COLOR = Color3.fromRGB(78, 78, 78)
local TEXT_ON   = Color3.fromRGB(240, 240, 240)
local TEXT_OFF  = Color3.fromRGB(150, 150, 150)

local TAB_N = #TAB_DEFS
local TAB_BAR_Y, TAB_BAR_H = 58, 30
local PAGE_TOP = TAB_BAR_Y + TAB_BAR_H + 6        -- 94
local PAGE_BOTTOM = 30                            -- مساحة الفوتر

-- شريط التبويبات (Segmented Control)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -12, 0, TAB_BAR_H)
tabBar.Position = UDim2.new(0, 6, 0, TAB_BAR_Y)
tabBar.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 50
tabBar.Parent = mainFrame
addCorner(tabBar, 8)
addStroke(tabBar, Color3.fromRGB(45, 45, 45), 1)

local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(1 / TAB_N, -6, 1, -6)
tabIndicator.Position = UDim2.new(0, 3, 0, 3)
tabIndicator.BackgroundColor3 = ACCENT_DK
tabIndicator.BorderSizePixel = 0
tabIndicator.ZIndex = 50
tabIndicator.Parent = tabBar
addCorner(tabIndicator, 6)

-- حاوية الصفحات
local pageHolder = Instance.new("Frame")
pageHolder.Size = UDim2.new(1, -12, 1, -(PAGE_TOP + PAGE_BOTTOM))
pageHolder.Position = UDim2.new(0, 6, 0, PAGE_TOP)
pageHolder.BackgroundTransparency = 1
pageHolder.ClipsDescendants = true
pageHolder.ZIndex = 50
pageHolder.Parent = mainFrame

local function createPage()
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = ACCENT
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = false
    sf.ZIndex = 50
    sf.Parent = pageHolder

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 5)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = sf
    return sf
end

local tabButtons, pages = {}, {}
local currentTab = 0

local function selectTab(idx, instant)
    idx = math.clamp(idx, 1, TAB_N)
    currentTab = idx
    Prefs.LastTab = idx
    for i, pg in ipairs(pages) do pg.Visible = (i == idx) end
    for i, b in ipairs(tabButtons) do
        b.TextColor3 = (i == idx) and Color3.new(1, 1, 1) or TEXT_OFF
    end
    local pos = UDim2.new((idx - 1) / TAB_N, 3, 0, 3)
    if instant then
        tabIndicator.Position = pos
    else
        TweenService:Create(tabIndicator,
            TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { Position = pos }):Play()
    end
end

for i, def in ipairs(TAB_DEFS) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1 / TAB_N, 0, 1, 0)
    b.Position = UDim2.new((i - 1) / TAB_N, 0, 0, 0)
    b.BackgroundTransparency = 1
    b.AutoButtonColor = false
    b.Text = def.icon .. " " .. def.name
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextColor3 = TEXT_OFF
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.ZIndex = 52
    b.Parent = tabBar
    tabButtons[i] = b
    pages[i] = createPage()
    b.MouseButton1Click:Connect(function()
        if currentTab ~= i then
            selectTab(i)
            scheduleSave()
        end
    end)
end

local espPage, aimPage, worldPage, settingsPage = pages[1], pages[2], pages[3], pages[4]

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, 0, 0, 22)
footer.Position = UDim2.new(0, 0, 1, -24)
footer.BackgroundTransparency = 1
footer.Text = "By " .. AUTHOR_SIGNATURE .. (CAN_FILE and "  •  💾 حفظ تلقائي" or "  •  ⚠️ الحفظ غير مدعوم")
footer.TextColor3 = Color3.fromRGB(110, 110, 110)
footer.Font = Enum.Font.GothamBold
footer.TextSize = 10
footer.ZIndex = 50
footer.Parent = mainFrame

-- ===== مكوّنات الصفحات =====
local refreshers = {}
local orderOf = setmetatable({}, { __mode = "k" })
local function nextOrder(page)
    local n = (orderOf[page] or 0) + 1
    orderOf[page] = n
    return n
end

-- تأثير الضغط
local function attachFeedback(btn, normal, hi)
    btn.InputBegan:Connect(function(input)
        if isPress(input) then btn.BackgroundColor3 = hi end
    end)
    btn.InputEnded:Connect(function(input)
        if isPress(input) then btn.BackgroundColor3 = normal end
    end)
end

local function createRow(page, h)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -6, 0, h or 30)
    row.BackgroundColor3 = ROW_BG
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = nextOrder(page)
    row.ZIndex = 50
    row.Parent = page
    addCorner(row, 6)
    attachFeedback(row, ROW_BG, ROW_BG_HI)
    return row
end

local function createRowLabel(row, text, widthOffset)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, widthOffset, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = TEXT_ON
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 51
    lbl.Parent = row
    return lbl
end

-- عنوان قسم
local function createSection(page, text)
    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, -6, 0, 22)
    h.BackgroundTransparency = 1
    h.LayoutOrder = nextOrder(page)
    h.ZIndex = 50
    h.Parent = page

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 1, -4)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = ACCENT
    t.Font = Enum.Font.GothamBold
    t.TextSize = 10
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Bottom
    t.ZIndex = 51
    t.Parent = h

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    line.BorderSizePixel = 0
    line.ZIndex = 51
    line.Parent = h
end

-- مفتاح تشغيل (Switch)
local function createToggle(page, icon, text, key)
    local row = createRow(page, 30)
    local lbl = createRowLabel(row, icon .. " " .. text, -62)

    local trackF = Instance.new("Frame")
    trackF.AnchorPoint = Vector2.new(1, 0.5)
    trackF.Position = UDim2.new(1, -8, 0.5, 0)
    trackF.Size = UDim2.new(0, 34, 0, 16)
    trackF.BorderSizePixel = 0
    trackF.ZIndex = 51
    trackF.Parent = row
    addCorner(trackF, 8)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 52
    knob.Parent = trackF
    addCorner(knob, 6)

    local info = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local function refresh(instant)
        local on = Config[key] and true or false
        local tc = on and ON_COLOR or OFF_COLOR
        local kp = on and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        lbl.TextColor3 = on and TEXT_ON or TEXT_OFF
        if instant == true then
            trackF.BackgroundColor3 = tc
            knob.Position = kp
        else
            TweenService:Create(trackF, info, { BackgroundColor3 = tc }):Play()
            TweenService:Create(knob, info, { Position = kp }):Play()
        end
    end

    row.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        refresh()
        scheduleSave()
    end)
    refresh(true)
    refreshers[#refreshers + 1] = refresh
end

-- صف اختيار (يدور بين قيم) مع شارة تعرض القيمة/اللون
local function createChoice(page, label, getText, getColor, onClick)
    local row = createRow(page, 30)
    createRowLabel(row, label, -104)

    local chip = Instance.new("TextLabel")
    chip.AnchorPoint = Vector2.new(1, 0.5)
    chip.Position = UDim2.new(1, -6, 0.5, 0)
    chip.Size = UDim2.new(0, 0, 0, 20)
    chip.AutomaticSize = Enum.AutomaticSize.X
    chip.Font = Enum.Font.GothamBold
    chip.TextSize = 10
    chip.ZIndex = 51
    chip.Parent = row
    addCorner(chip, 5)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = chip

    local function refresh()
        chip.Text = getText()
        local c = getColor()
        chip.BackgroundColor3 = c
        chip.TextColor3 = textFor(c)
    end
    row.MouseButton1Click:Connect(function()
        onClick()
        refresh()
        scheduleSave()
    end)
    refresh()
    refreshers[#refreshers + 1] = refresh
    return row
end

-- ===== السلايدر (مسافة الكشف) =====
local sliderHeld = false

local function setPagesScrolling(enabled)
    for _, pg in ipairs(pages) do pg.ScrollingEnabled = enabled end
end

local function createDistanceSlider(page)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -6, 0, 48)
    holder.BackgroundColor3 = ROW_BG
    holder.BorderSizePixel = 0
    holder.Active = true
    holder.LayoutOrder = nextOrder(page)
    holder.ZIndex = 50
    holder.Parent = page
    addCorner(holder, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -90, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = "📏 مسافة الكشف"
    lbl.TextColor3 = TEXT_ON
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 51
    lbl.Parent = holder

    local valLbl = Instance.new("TextLabel")
    valLbl.AnchorPoint = Vector2.new(1, 0)
    valLbl.Position = UDim2.new(1, -10, 0, 5)
    valLbl.Size = UDim2.new(0, 70, 0, 20)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3 = ACCENT
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 51
    valLbl.Parent = holder

    local trackF = Instance.new("Frame")
    trackF.Position = UDim2.new(0, 12, 1, -16)
    trackF.Size = UDim2.new(1, -24, 0, 6)
    trackF.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
    trackF.BorderSizePixel = 0
    trackF.ZIndex = 51
    trackF.Parent = holder
    addCorner(trackF, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT_DK
    fill.BorderSizePixel = 0
    fill.ZIndex = 52
    fill.Parent = trackF
    addCorner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 53
    knob.Parent = trackF
    addCorner(knob, 7)

    local function updateSlider()
        local rel = math.clamp((Config.MaxDistance - 100) / 4900, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = Config.MaxDistance .. " m"
    end
    updateSlider()
    refreshers[#refreshers + 1] = updateSlider

    local function setFromX(x)
        local rel = math.clamp((x - trackF.AbsolutePosition.X)
            / math.max(1, trackF.AbsoluteSize.X), 0, 1)
        Config.MaxDistance = math.floor((100 + rel * 4900) / 10 + 0.5) * 10
        updateSlider()
        scheduleSave()
    end

    holder.InputBegan:Connect(function(input)
        if isPress(input) then
            sliderHeld = true
            setPagesScrolling(false)
            setFromX(input.Position.X)
        end
    end)
    track(UserInputService.InputEnded:Connect(function(input)
        if sliderHeld and isPress(input) then
            sliderHeld = false
            setPagesScrolling(true)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if sliderHeld and isMove(input) then setFromX(input.Position.X) end
    end))
end

-- سلايدر عام (أي قيمة رقمية في Config)
local function createValueSlider(page, label, key, minV, maxV, step, suffix)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -6, 0, 48)
    holder.BackgroundColor3 = ROW_BG
    holder.BorderSizePixel = 0
    holder.Active = true
    holder.LayoutOrder = nextOrder(page)
    holder.ZIndex = 50
    holder.Parent = page
    addCorner(holder, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -90, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = TEXT_ON
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 51
    lbl.Parent = holder

    local valLbl = Instance.new("TextLabel")
    valLbl.AnchorPoint = Vector2.new(1, 0)
    valLbl.Position = UDim2.new(1, -10, 0, 5)
    valLbl.Size = UDim2.new(0, 70, 0, 20)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3 = ACCENT
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 51
    valLbl.Parent = holder

    local trackF = Instance.new("Frame")
    trackF.Position = UDim2.new(0, 12, 1, -16)
    trackF.Size = UDim2.new(1, -24, 0, 6)
    trackF.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
    trackF.BorderSizePixel = 0
    trackF.ZIndex = 51
    trackF.Parent = holder
    addCorner(trackF, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT_DK
    fill.BorderSizePixel = 0
    fill.ZIndex = 52
    fill.Parent = trackF
    addCorner(fill, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 53
    knob.Parent = trackF
    addCorner(knob, 7)

    local function update()
        local rel = math.clamp((Config[key] - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = Config[key] .. (suffix or "")
    end
    update()
    refreshers[#refreshers + 1] = update

    local function setFromX(x)
        local rel = math.clamp((x - trackF.AbsolutePosition.X)
            / math.max(1, trackF.AbsoluteSize.X), 0, 1)
        Config[key] = math.floor((minV + rel * (maxV - minV)) / step + 0.5) * step
        update()
        scheduleSave()
    end

    local held = false
    holder.InputBegan:Connect(function(input)
        if isPress(input) then
            held = true
            setPagesScrolling(false)
            setFromX(input.Position.X)
        end
    end)
    track(UserInputService.InputEnded:Connect(function(input)
        if held and isPress(input) then
            held = false
            setPagesScrolling(true)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if held and isMove(input) then setFromX(input.Position.X) end
    end))
end

-- ============================================================
-- 🎯 تبويب ESP
-- ============================================================
createSection(espPage, "الكشف الأساسي")
createToggle(espPage, "⚡", "ESP الرئيسي",  "ESPEnabled")
createToggle(espPage, "👥", "Team Check",   "TeamCheck")
createToggle(espPage, "🧱", "Wall Check",   "WallCheck")
createToggle(espPage, "🤖", "البوتات",       "ShowBots")

createSection(espPage, "العناصر المرئية")
createToggle(espPage, "📦", "البوكس",           "Box")
createToggle(espPage, "🦴", "الهيكل العظمي",    "Skeleton")
createToggle(espPage, "📏", "الخط الرفيع",      "Tracers")
createToggle(espPage, "🏷️", "الأسماء",         "Names")
createToggle(espPage, "❤️", "الصحة",            "Health")
createToggle(espPage, "📐", "المسافة",          "ShowDistance")
createToggle(espPage, "🔫", "السلاح بيده",      "Weapons")
createToggle(espPage, "🧭", "أسهم خارج الشاشة", "Arrows")
createToggle(espPage, "🖌️", "الهايت لايت",     "Highlight")

createSection(espPage, "الألوان")
createChoice(espPage,
    "🔴 لون العدو",
    function() return "#" .. ENEMY_COLOR:ToHex():upper() end,
    function() return ENEMY_COLOR end,
    function()
        Prefs.EnemyColorIdx = (Prefs.EnemyColorIdx % #ENEMY_PALETTE) + 1
        applyPrefs()
    end)
createChoice(espPage,
    "🎨 لون الهيكل العظمي",
    function() return "#" .. SKELETON_COLOR:ToHex():upper() end,
    function() return SKELETON_COLOR end,
    function()
        Prefs.SkeletonColorIdx = (Prefs.SkeletonColorIdx % #SKELETON_PALETTE) + 1
        applyPrefs()
    end)

-- ============================================================
-- 🎯 تبويب Aim
-- ============================================================
createSection(aimPage, "الأيم بوت")
createToggle(aimPage, "🎯", "تفعيل الأيم بوت", "AimEnabled")
createChoice(aimPage,
    "🖱️ زر التفعيل",
    function() return AIM_KEYS[Prefs.AimKeyIdx] end,
    function() return Color3.fromRGB(70, 70, 110) end,
    function() Prefs.AimKeyIdx = (Prefs.AimKeyIdx % #AIM_KEYS) + 1 end)
createChoice(aimPage,
    "🎯 نقطة التصويب",
    function() return AIM_PARTS[Prefs.AimPartIdx] end,
    function() return Color3.fromRGB(110, 70, 70) end,
    function() Prefs.AimPartIdx = (Prefs.AimPartIdx % #AIM_PARTS) + 1 end)

createChoice(aimPage,
    "🧲 طريقة التصويب",
    function()
        if Prefs.AimMethodIdx == 1 and not HAS_MOUSEMOVE then return "الكاميرا (تلقائي)" end
        return AIM_METHODS[Prefs.AimMethodIdx]
    end,
    function() return Color3.fromRGB(70, 110, 80) end,
    function() Prefs.AimMethodIdx = (Prefs.AimMethodIdx % #AIM_METHODS) + 1 end)

createSection(aimPage, "الاستهداف")
createToggle(aimPage, "🧱", "Wall Check", "AimWallCheck")
createToggle(aimPage, "📌", "تثبيت الهدف", "AimSticky")
createToggle(aimPage, "🤖", "تصويب على البوتات", "AimBots")
createToggle(aimPage, "🧍", "الشخصية تواجه الهدف", "AimFaceChar")

createSection(aimPage, "FOV والنعومة")
createToggle(aimPage, "⭕", "إظهار دائرة FOV", "AimFOVCircle")
createValueSlider(aimPage, "⭕ حجم FOV", "AimFOV", 20, 600, 10, " px")
createValueSlider(aimPage, "🐢 النعومة (1 = فوري)", "AimSmooth", 1, 20, 1, "")
createValueSlider(aimPage, "🖱️ قوة حركة الماوس", "AimMousePct", 30, 300, 10, "%")

-- ============================================================
-- 🌍 تبويب العالم
-- ============================================================
createSection(worldPage, "المركبات")
createToggle(worldPage, "🚗", "كشف المركبات", "Vehicles")

createSection(worldPage, "الغنائم")
createToggle(worldPage, "💎", "كشف الغنائم", "LootESP")
createChoice(worldPage,
    "🎯 فلتر الغنائم",
    function() return LOOT_FILTERS[Prefs.LootFilter] end,
    function() return Color3.fromRGB(60, 95, 120) end,
    function()
        Prefs.LootFilter = (Prefs.LootFilter % #LOOT_FILTERS) + 1
        applyPrefs()
    end)

createSection(worldPage, "آثار الأقدام")
createToggle(worldPage, "👣", "آثار الأقدام", "Trails")
createChoice(worldPage,
    "🎨 لون الآثار",
    function() return "#" .. TRAIL_COLOR:ToHex():upper() end,
    function() return TRAIL_COLOR end,
    function()
        Prefs.TrailColorIdx = (Prefs.TrailColorIdx % #TRAIL_PALETTE) + 1
        applyPrefs()
    end)

-- ============================================================
-- ⚙️ تبويب الإعدادات
-- ============================================================
createSection(settingsPage, "الأداء والمسافة")
createToggle(settingsPage, "🚀", "وضع الأداء", "PerfMode")
createDistanceSlider(settingsPage)

createSection(settingsPage, "الواجهة")
createChoice(settingsPage,
    "⌨️ مفتاح القائمة",
    function() return Prefs.ToggleKey end,
    function() return Color3.fromRGB(70, 70, 110) end,
    function()
        local idx = 1
        for i, k in ipairs(TOGGLE_KEYS) do
            if k == Prefs.ToggleKey then idx = i end
        end
        Prefs.ToggleKey = TOGGLE_KEYS[(idx % #TOGGLE_KEYS) + 1]
    end)

createSection(settingsPage, "النظام")
do
    local RESET_TEXT = "♻️ إعادة الضبط الافتراضي"
    local RESET_BG, RESET_HI = Color3.fromRGB(120, 50, 50), Color3.fromRGB(150, 62, 62)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -6, 0, 30)
    resetBtn.BackgroundColor3 = RESET_BG
    resetBtn.AutoButtonColor = false
    resetBtn.TextColor3 = Color3.new(1, 1, 1)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 11
    resetBtn.Text = RESET_TEXT
    resetBtn.LayoutOrder = nextOrder(settingsPage)
    resetBtn.ZIndex = 50
    resetBtn.Parent = settingsPage
    addCorner(resetBtn, 6)
    attachFeedback(resetBtn, RESET_BG, RESET_HI)

    local armed = false
    resetBtn.MouseButton1Click:Connect(function()
        if not armed then
            armed = true
            resetBtn.Text = "⚠️ اضغط مرة ثانية للتأكيد"
            task.delay(2.5, function()
                if armed and Running then
                    armed = false
                    resetBtn.Text = RESET_TEXT
                end
            end)
            return
        end
        armed = false
        resetBtn.Text = RESET_TEXT
        local keepTab = Prefs.LastTab
        for k, v in pairs(DEFAULTS) do Config[k] = v end
        for k, v in pairs(PREF_DEFAULTS) do Prefs[k] = v end
        Prefs.LastTab = keepTab        -- نبقى في نفس التبويب
        applyPrefs()
        for _, fn in ipairs(refreshers) do fn() end
        scheduleSave()
    end)
end

-- فتح آخر تبويب محفوظ
selectTab(Prefs.LastTab, true)

-- ========================== شاشة Loading ==========================
local loadingCard = nil

local function runLoading()
    local vp = viewport()
    local cw = math.clamp(vp.X - 40, 200, 280)

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.fromOffset(cw, 118)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    card.BorderSizePixel = 0
    card.ZIndex = 300
    card.Parent = screenGui
    loadingCard = card
    addCorner(card, 12)
    local cardStroke = addStroke(card, Color3.fromRGB(0, 190, 170), 1.5)

    local lt = Instance.new("TextLabel")
    lt.BackgroundTransparency = 1
    lt.Size = UDim2.new(1, 0, 0, 24)
    lt.Position = UDim2.new(0, 0, 0, 12)
    lt.Text = "🎯 Universal ESP V24"
    lt.TextColor3 = Color3.fromRGB(0, 255, 180)
    lt.Font = Enum.Font.GothamBold
    lt.TextSize = 15
    lt.ZIndex = 301
    lt.Parent = card

    local ls = Instance.new("TextLabel")
    ls.BackgroundTransparency = 1
    ls.Size = UDim2.new(1, 0, 0, 18)
    ls.Position = UDim2.new(0, 0, 0, 42)
    ls.Text = "..."
    ls.TextColor3 = Color3.fromRGB(200, 200, 200)
    ls.Font = Enum.Font.GothamBold
    ls.TextSize = 11
    ls.ZIndex = 301
    ls.Parent = card

    local barBg = Instance.new("Frame")
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0, 72)
    barBg.Size = UDim2.new(1, -40, 0, 10)
    barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 301
    barBg.Parent = card
    addCorner(barBg, 5)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 170)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 302
    barFill.Parent = barBg
    addCorner(barFill, 5)

    local pctLbl = Instance.new("TextLabel")
    pctLbl.BackgroundTransparency = 1
    pctLbl.Size = UDim2.new(1, 0, 0, 16)
    pctLbl.Position = UDim2.new(0, 0, 0, 90)
    pctLbl.Text = "0%"
    pctLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
    pctLbl.Font = Enum.Font.GothamBold
    pctLbl.TextSize = 10
    pctLbl.ZIndex = 301
    pctLbl.Parent = card

    local steps = {
        { loadedFromFile and "تحميل الإعدادات المحفوظة..." or "تحميل الإعدادات...", 0.20 },
        { "تجهيز القائمة والتبويبات...", 0.40 },
        { "تهيئة نظام الرسم...", 0.60 },
        { "تجهيز الأسهم والأسلحة...", 0.78 },
        { "تجهيز الغنائم وآثار الأقدام...", 0.92 },
        { "جاهز ✅", 1.00 },
    }
    for _, s in ipairs(steps) do
        if not Running then return end
        ls.Text = s[1]
        pctLbl.Text = math.floor(s[2] * 100) .. "%"
        TweenService:Create(barFill,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.new(s[2], 0, 1, 0) }):Play()
        task.wait(0.35)
    end
    task.wait(0.15)

    local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(cardStroke, fade, { Transparency = 1 }):Play()
    TweenService:Create(barBg, fade, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(barFill, fade, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(lt, fade, { TextTransparency = 1 }):Play()
    TweenService:Create(ls, fade, { TextTransparency = 1 }):Play()
    TweenService:Create(pctLbl, fade, { TextTransparency = 1 }):Play()
    task.wait(0.32)
end

task.spawn(function()
    pcall(runLoading)
    if loadingCard then pcall(function() loadingCard:Destroy() end) loadingCard = nil end
    if Running then
        mainFrame.Visible = true
        toggleBtn.Visible = true
        uiReady = true
        applyLayout(false)
    end
end)

-- ========================== نظام الـ ESP ==========================
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChildWhichIsA("BasePart", true)
end

-- ===== Team Check للاعبين =====
local CUSTOM_TEAM_KEYS = {"Team", "TeamName", "team", "teamName"}

local function getCustomTeam(plr)
    for _, name in ipairs(CUSTOM_TEAM_KEYS) do
        local a = plr:GetAttribute(name)
        if a ~= nil then return a end
        local char = plr.Character
        if char then
            local ca = char:GetAttribute(name)
            if ca ~= nil then return ca end
        end
        local obj = plr:FindFirstChild(name)
        if obj and obj:IsA("ValueBase") then return obj.Value end
    end
    return nil
end

local function isSameTeam(plr)
    if plr == LocalPlayer then return false end
    local myTeam, theirTeam = LocalPlayer.Team, plr.Team
    if myTeam ~= nil and theirTeam ~= nil then
        return myTeam == theirTeam
    end
    if myTeam ~= nil or theirTeam ~= nil then return false end
    local myCustom = getCustomTeam(LocalPlayer)
    local theirCustom = getCustomTeam(plr)
    if myCustom ~= nil and theirCustom ~= nil then
        return myCustom == theirCustom
    end
    return false
end

-- ===== Team Check للبوتات =====
local BOT_TEAM_KEYS = {"Team", "TeamName", "team", "teamName", "TeamColor", "Side", "Faction"}

local function getBotTeamValue(model)
    local hum = model:FindFirstChildWhichIsA("Humanoid", true)
    for _, name in ipairs(BOT_TEAM_KEYS) do
        local a = model:GetAttribute(name)
        if a ~= nil then return a end
        if hum then
            local ha = hum:GetAttribute(name)
            if ha ~= nil then return ha end
        end
        local obj = model:FindFirstChild(name)
        if obj and obj:IsA("ValueBase") then return obj.Value end
        if hum then
            local hobj = hum:FindFirstChild(name)
            if hobj and hobj:IsA("ValueBase") then return hobj.Value end
        end
    end
    return nil
end

local function valueMatchesMyTeam(val)
    local myTeam = LocalPlayer.Team
    local t = typeof(val)
    if t == "Instance" then
        return myTeam ~= nil and val == myTeam
    elseif t == "BrickColor" then
        return myTeam ~= nil and val == myTeam.TeamColor
    elseif t == "Color3" then
        return myTeam ~= nil and val == myTeam.TeamColor.Color
    end
    local s = tostring(val):lower()
    if myTeam and s == myTeam.Name:lower() then return true end
    local mine = getCustomTeam(LocalPlayer)
    if mine ~= nil then return s == tostring(mine):lower() end
    return false
end

local function isBotSameTeam(model)
    local val = getBotTeamValue(model)
    if val ~= nil then return valueMatchesMyTeam(val) end
    local myTeam = LocalPlayer.Team
    local mine = getCustomTeam(LocalPlayer)
    local p = model.Parent
    while p and p ~= workspace and p ~= game do
        local n = p.Name:lower()
        if myTeam and n == myTeam.Name:lower() then return true end
        if mine ~= nil and n == tostring(mine):lower() then return true end
        p = p.Parent
    end
    return false
end

-- ===== مصدر الصحة (Humanoid أو قيم مخصصة للعبة) =====
local HP_KEYS    = {"Health", "health", "HP", "hp", "CurrentHealth", "currentHealth"}
local MAXHP_KEYS = {"MaxHealth", "maxHealth", "MaxHP", "maxHP", "maxHp"}

local function scanHolder(h, keys)
    if not h then return nil end
    for _, k in ipairs(keys) do
        if typeof(h:GetAttribute(k)) == "number" then
            return { h = h, k = k, attr = true }
        end
        local o = h:FindFirstChild(k)
        if o and (o:IsA("NumberValue") or o:IsA("IntValue")) then
            return { h = o }
        end
    end
    return nil
end

local function detectHealthSource(char, hum, plr)
    local hp = scanHolder(char, HP_KEYS) or scanHolder(hum, HP_KEYS) or scanHolder(plr, HP_KEYS)
    if not hp then return nil end
    local mx = scanHolder(char, MAXHP_KEYS) or scanHolder(hum, MAXHP_KEYS) or scanHolder(plr, MAXHP_KEYS)
    return { hp = hp, mx = mx }
end

local function readSrc(s)
    if not s then return nil end
    if s.attr then return s.h:GetAttribute(s.k) end
    return s.h.Value
end

-- ===== السلاح / الأداة التي بيد اللاعب =====
local WEAPON_KEYS = {"EquippedWeapon", "Weapon", "CurrentWeapon", "EquippedTool",
    "CurrentTool", "Equipped", "EquippedItem"}

local function scanWeapon(h)
    if not h then return nil end
    for _, k in ipairs(WEAPON_KEYS) do
        local a = h:GetAttribute(k)
        if type(a) == "string" and a ~= "" then return a end
        local o = h:FindFirstChild(k)
        if o then
            if o:IsA("StringValue") and o.Value ~= "" then return o.Value end
            if o:IsA("ObjectValue") and o.Value then return o.Value.Name end
        end
    end
    return nil
end

local function getHeldWeapon(char, plr)
    local tool = char:FindFirstChildOfClass("Tool")
    local name = tool and tool.Name or scanWeapon(char) or scanWeapon(plr)
    if name and #name > 22 then name = name:sub(1, 22) end
    return name
end

-- ========================== بناء الرسومات ==========================
local function buildVisuals()
    local v = {}
    v.box = Instance.new("Frame")
    v.box.BackgroundTransparency = 1
    v.box.BorderSizePixel = 0
    v.box.Visible = false
    v.box.ZIndex = 6
    v.box.Parent = espContainer
    v.boxStroke = addStroke(v.box, ENEMY_COLOR, 1.6)

    v.tracer = Instance.new("Frame")
    v.tracer.BorderSizePixel = 0
    v.tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    v.tracer.Size = UDim2.new(0, 2, 0, 2)
    v.tracer.Visible = false
    v.tracer.ZIndex = 6
    v.tracer.Parent = espContainer

    v.nameLbl = Instance.new("TextLabel")
    v.nameLbl.BackgroundTransparency = 1
    v.nameLbl.Font = Enum.Font.GothamBold
    v.nameLbl.TextSize = 12
    v.nameLbl.TextStrokeTransparency = 0.3
    v.nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    v.nameLbl.AnchorPoint = Vector2.new(0.5, 1)
    v.nameLbl.TextXAlignment = Enum.TextXAlignment.Center
    v.nameLbl.Size = UDim2.new(0, 160, 0, 14)
    v.nameLbl.Visible = false
    v.nameLbl.ZIndex = 6
    v.nameLbl.Parent = espContainer

    v.infoLbl = Instance.new("TextLabel")
    v.infoLbl.BackgroundTransparency = 1
    v.infoLbl.Font = Enum.Font.GothamBold
    v.infoLbl.TextSize = 11
    v.infoLbl.TextStrokeTransparency = 0.3
    v.infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    v.infoLbl.AnchorPoint = Vector2.new(0.5, 0)
    v.infoLbl.TextXAlignment = Enum.TextXAlignment.Center
    v.infoLbl.Size = UDim2.new(0, 160, 0, 14)
    v.infoLbl.Visible = false
    v.infoLbl.ZIndex = 6
    v.infoLbl.Parent = espContainer

    -- السلاح (تحت المعلومات)
    v.toolLbl = Instance.new("TextLabel")
    v.toolLbl.BackgroundTransparency = 1
    v.toolLbl.Font = Enum.Font.GothamBold
    v.toolLbl.TextSize = 11
    v.toolLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    v.toolLbl.TextStrokeTransparency = 0.3
    v.toolLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    v.toolLbl.AnchorPoint = Vector2.new(0.5, 0)
    v.toolLbl.TextXAlignment = Enum.TextXAlignment.Center
    v.toolLbl.Size = UDim2.new(0, 160, 0, 14)
    v.toolLbl.Visible = false
    v.toolLbl.ZIndex = 6
    v.toolLbl.Parent = espContainer

    -- شريط الصحة العمودي
    v.hpBg = Instance.new("Frame")
    v.hpBg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    v.hpBg.BorderSizePixel = 0
    v.hpBg.Visible = false
    v.hpBg.ZIndex = 6
    v.hpBg.Parent = espContainer
    addStroke(v.hpBg, Color3.fromRGB(70, 70, 70), 1)

    v.hpFill = Instance.new("Frame")
    v.hpFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    v.hpFill.BorderSizePixel = 0
    v.hpFill.AnchorPoint = Vector2.new(0, 1)
    v.hpFill.Position = UDim2.new(0, 0, 1, 0)
    v.hpFill.Visible = false
    v.hpFill.ZIndex = 7
    v.hpFill.Parent = v.hpBg

    -- سهم خارج الشاشة + مسافته
    v.arrow = Instance.new("TextLabel")
    v.arrow.BackgroundTransparency = 1
    v.arrow.Font = Enum.Font.GothamBold
    v.arrow.Text = "▲"
    v.arrow.TextSize = 22
    v.arrow.TextStrokeTransparency = 0.3
    v.arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
    v.arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    v.arrow.Size = UDim2.new(0, 26, 0, 26)
    v.arrow.Visible = false
    v.arrow.ZIndex = 8
    v.arrow.Parent = espContainer

    v.arrowTxt = Instance.new("TextLabel")
    v.arrowTxt.BackgroundTransparency = 1
    v.arrowTxt.Font = Enum.Font.GothamBold
    v.arrowTxt.TextSize = 10
    v.arrowTxt.TextStrokeTransparency = 0.3
    v.arrowTxt.TextStrokeColor3 = Color3.new(0, 0, 0)
    v.arrowTxt.AnchorPoint = Vector2.new(0.5, 0.5)
    v.arrowTxt.Size = UDim2.new(0, 50, 0, 12)
    v.arrowTxt.Visible = false
    v.arrowTxt.ZIndex = 8
    v.arrowTxt.Parent = espContainer

    -- عظام الهيكل: جداول عادية { frame = Frame, mx=, my=, len=, rot=, color= }
    v.bones = {}
    v.pts = {}

    v.trail = nil            -- يُنشأ عند الحاجة بواسطة Trail.update
    v.highlight = nil
    v.highlightChar = nil
    v.hum = nil
    v.humChar = nil
    v.hpSrc = nil
    v.hpT = 99
    v.hpPeak = nil
    v.weaponT = 99
    v.weapon = false
    v.lastWeapon = nil
    v.color = nil
    v.lastName = nil
    v.lastInfo = nil
    v.infoEmpty = true
    v.infoT = 0
    v.wallT = 0
    v.behindWall = false
    v._hidden = false
    return v
end

-- ========================== 👣 آثار الأقدام (Player Trails) ==========================
-- تُسجَّل نقاط موضع القدم كل فترة قصيرة، ثم تُرسم كخطوط على الشاشة
-- (تظهر من خلف الجدران) وتزداد شفافيتها مع الزمن حتى تختفي.
local Trail = { budget = 0, BUDGET = 600 }
do
    local LIFE, STEP = 4.0, 0.12            -- عمر الأثر (ثواني) / كل كم ثانية نسجّل نقطة
    local LIFE_PERF, STEP_PERF = 2.5, 0.2   -- نفس القيم في وضع الأداء
    local MIN_MOVE = 0.8                    -- أقل مسافة (studs) لتسجيل نقطة جديدة
    local TELEPORT = 40                     -- قفزة أكبر من هذا = قطع الخط (تيليبورت/إعادة ظهور)
    local MAX_POINTS = 60                   -- أقصى عدد نقاط لكل لاعب
    local MAX_DIST = 400                    -- لا نرسم آثار اللاعبين الأبعد من هذا
    local THICKNESS = 2

    local function getSeg(T, idx)
        local s = T.segs[idx]
        if not s then
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Visible = false
            f.ZIndex = 4
            f.Parent = espContainer
            s = { f = f }
            T.segs[idx] = s
        end
        return s
    end

    local function hideFrom(T, from)
        for i = from, T.shown do
            local s = T.segs[i]
            if s and s.f.Visible then s.f.Visible = false end
        end
    end

    function Trail.hide(v)
        local T = v.trail
        if not T then return end
        if T.shown > 0 then
            hideFrom(T, 1)
            T.shown = 0
        end
        if #T.pts > 0 then T.pts = {} end
        T.lastUpd = nil
        T.acc = 99
    end

    function Trail.update(v, footPos, dt, color, vpX, vpY, dist)
        if dist > MAX_DIST then Trail.hide(v) return end

        local T = v.trail
        if not T then
            T = { pts = {}, segs = {}, acc = 99, shown = 0 }
            v.trail = T
        end

        local now = os.clock()
        local perf = Config.PerfMode
        local life = perf and LIFE_PERF or LIFE
        local step = perf and STEP_PERF or STEP

        -- إذا توقف التحديث لفترة (اللاعب كان مخفياً) نقطع الخط عند أول نقطة جديدة
        if T.lastUpd and (now - T.lastUpd) > 0.5 then T.needBreak = true end
        T.lastUpd = now

        -- حذف النقاط المنتهية
        local pts = T.pts
        while #pts > 0 and (now - pts[1].t) > life do
            table.remove(pts, 1)
        end

        -- تسجيل نقطة جديدة
        T.acc = T.acc + dt
        if T.acc >= step then
            T.acc = 0
            local last = pts[#pts]
            local add = true
            local brk = (last == nil) or (T.needBreak == true)
            if last then
                local gap = (footPos - last.p).Magnitude
                if gap < MIN_MOVE then
                    add = false
                elseif gap > TELEPORT then
                    brk = true
                end
            end
            if add then
                pts[#pts + 1] = { p = footPos, t = now, brk = brk }
                T.needBreak = false
                if #pts > MAX_POINTS then table.remove(pts, 1) end
            end
        end

        local n = #pts
        if n == 0 then
            if T.shown > 0 then
                hideFrom(T, 1)
                T.shown = 0
            end
            return
        end

        -- الرسم: خطوط بين كل نقطتين متتاليتين + النقطة الحية (موضع القدم الآن)
        local used = 0
        local prevScr, prevP, prevT = nil, nil, nil
        for i = 1, n + 1 do
            local pt = pts[i]
            local p, t, brk
            if pt then
                p, t, brk = pt.p, pt.t, pt.brk
            else
                p, t, brk = footPos, now, false
                if prevP and (p - prevP).Magnitude > TELEPORT then brk = true end
            end

            local sp = Camera:WorldToViewportPoint(p)
            local scr = nil
            if sp.Z > 0 then scr = sp end

            if prevScr and scr and not brk then
                if Trail.budget <= 0 then break end
                local ax, ay, bx, by = prevScr.X, prevScr.Y, scr.X, scr.Y
                local offscreen = (ax < 0 and bx < 0) or (ax > vpX and bx > vpX)
                    or (ay < 0 and by < 0) or (ay > vpY and by > vpY)
                if not offscreen then
                    local dx, dy = bx - ax, by - ay
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 1 then
                        used = used + 1
                        Trail.budget = Trail.budget - 1
                        local seg = getSeg(T, used)
                        local f = seg.f

                        -- التلاشي: كلما كبر عمر النقطة زادت الشفافية
                        local age = ((now - t) + (now - prevT)) * 0.5
                        local fr = age / life
                        if fr < 0 then fr = 0 elseif fr > 1 then fr = 1 end
                        local tr = 0.15 + 0.85 * fr

                        if seg.color ~= color then
                            seg.color = color
                            f.BackgroundColor3 = color
                        end
                        if (not seg.tr) or math.abs(seg.tr - tr) > 0.02 then
                            seg.tr = tr
                            f.BackgroundTransparency = tr
                        end
                        local mx = math.floor((ax + bx) / 2)
                        local my = math.floor((ay + by) / 2)
                        local flen = math.floor(len)
                        local rot = math.deg(atan2(dy, dx))
                        if seg.mx ~= mx or seg.my ~= my then
                            seg.mx, seg.my = mx, my
                            f.Position = UDim2.new(0, mx, 0, my)
                        end
                        if seg.len ~= flen then
                            seg.len = flen
                            f.Size = UDim2.new(0, flen, 0, THICKNESS)
                        end
                        if seg.rot ~= rot then
                            seg.rot = rot
                            f.Rotation = rot
                        end
                        if not f.Visible then f.Visible = true end
                    end
                end
            end
            prevScr, prevP, prevT = scr, p, t
        end

        if used < T.shown then hideFrom(T, used + 1) end
        T.shown = used
    end
end

local function hideArrow(v)
    if v.arrow and v.arrow.Visible then v.arrow.Visible = false end
    if v.arrowTxt and v.arrowTxt.Visible then v.arrowTxt.Visible = false end
end

-- يخفي كل شيء ما عدا السهم
local function hideMain(v)
    if not v or v._hidden then return end
    v._hidden = true
    v.box.Visible = false
    v.tracer.Visible = false
    v.nameLbl.Visible = false
    v.infoLbl.Visible = false
    v.toolLbl.Visible = false
    v.hpBg.Visible = false
    v.hpFill.Visible = false
    if v.bones then
        for _, b in ipairs(v.bones) do b.frame.Visible = false end
    end
    if v.highlight then v.highlight.Enabled = false end
    v.lastName = nil
    v.lastInfo = nil
end

local function hideVisuals(v)
    if not v then return end
    hideArrow(v)
    hideMain(v)
    Trail.hide(v)
end

local function spawnEntry(tbl, ref)
    local e = tbl[ref]
    if e then return e end
    e = { visuals = nil }
    tbl[ref] = e
    return e
end

-- ماسح البوتات (كل 2.5 ثانية)
local MAX_BOTS = 80
local botScanT = 0
local sweeping = false

local function sweepBots()
    if sweeping then return end
    sweeping = true

    local total = 0
    for model, e in pairs(botCache) do
        if not model.Parent then
            destroyVisuals(e.visuals)
            botCache[model] = nil
        else
            total = total + 1
        end
    end

    if Config.ShowBots then
        local descendants = workspace:GetDescendants()
        for i, inst in ipairs(descendants) do
            if not Running or total >= MAX_BOTS then break end
            if i % 2500 == 0 then task.wait() end
            if inst:IsA("Model") and inst.Parent ~= nil and not botCache[inst] then
                local humanoid = inst:FindFirstChildWhichIsA("Humanoid", true)
                local root = humanoid and getRoot(inst)
                if root then
                    local hitPlayer = false
                    for _, plr in ipairs(Players:GetPlayers()) do
                        local pc = plr.Character
                        if pc and (pc == inst or inst:IsDescendantOf(pc)) then
                            hitPlayer = true
                            break
                        end
                    end
                    if not hitPlayer then
                        botCache[inst] = { visuals = nil }
                        total = total + 1
                    end
                end
            end
        end
    end
    sweeping = false
end

-- فحص الجدار
local function isBehindWall(char, root, camPos)
    local myChar = LocalPlayer.Character
    if not myChar or not root.Parent then return false end
    if (root.Position - camPos).Magnitude < 2 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar, char }
    local result = workspace:Raycast(camPos, root.Position - camPos, params)
    return result ~= nil and result.Instance ~= nil
end

-- ========================== الهيكل العظمي (مفاصل حقيقية) ==========================
local function pPart(char, name)
    local p = char:FindFirstChild(name)
    if p and p:IsA("BasePart") then return p.Position end
    return nil
end

-- نقطة نسبية داخل الجزء (ox/oy/oz من -1 إلى 1 بالنسبة لنصف الحجم)
local function pOff(char, name, ox, oy, oz)
    local p = char:FindFirstChild(name)
    if p and p:IsA("BasePart") then
        local s = p.Size
        return p.CFrame * Vector3.new(ox * s.X / 2, oy * s.Y / 2, oz * s.Z / 2)
    end
    return nil
end

-- موضع المفصل الحقيقي: Part0.CFrame * C0
local function pJoint(char, partName, motorName)
    local p = char:FindFirstChild(partName)
    if p then
        local m = p:FindFirstChild(motorName)
        if m and m:IsA("Motor6D") and m.Part0 then
            return (m.Part0.CFrame * m.C0).Position
        end
    end
    return nil
end

local R15_EDGES = {
    {"head", "neck"}, {"neck", "waist"}, {"waist", "pelvis"},
    {"neck", "rs"}, {"rs", "re"}, {"re", "rw"}, {"rw", "rhand"},
    {"neck", "ls"}, {"ls", "le"}, {"le", "lw"}, {"lw", "lhand"},
    {"pelvis", "rh"}, {"rh", "rk"}, {"rk", "ra"}, {"ra", "rfoot"},
    {"pelvis", "lh"}, {"lh", "lk"}, {"lk", "la"}, {"la", "lfoot"},
}
local R6_EDGES = {
    {"head", "neck"}, {"neck", "pelvis"},
    {"neck", "rs"}, {"rs", "rhand"},
    {"neck", "ls"}, {"ls", "lhand"},
    {"pelvis", "rh"}, {"rh", "rfoot"},
    {"pelvis", "lh"}, {"lh", "lfoot"},
}

local function fillPointsR15(char, pts)
    pts.head   = pPart(char, "Head")
    pts.neck   = pJoint(char, "Head", "Neck") or pOff(char, "UpperTorso", 0, 1, 0)
    pts.waist  = pJoint(char, "UpperTorso", "Waist") or pOff(char, "LowerTorso", 0, 1, 0)
    pts.pelvis = pPart(char, "LowerTorso")

    pts.rs    = pJoint(char, "RightUpperArm", "RightShoulder") or pOff(char, "RightUpperArm", 0, 1, 0)
    pts.re    = pJoint(char, "RightLowerArm", "RightElbow")    or pOff(char, "RightLowerArm", 0, 1, 0)
    pts.rw    = pJoint(char, "RightHand", "RightWrist")        or pOff(char, "RightHand", 0, 1, 0)
    pts.rhand = pPart(char, "RightHand")

    pts.ls    = pJoint(char, "LeftUpperArm", "LeftShoulder")   or pOff(char, "LeftUpperArm", 0, 1, 0)
    pts.le    = pJoint(char, "LeftLowerArm", "LeftElbow")      or pOff(char, "LeftLowerArm", 0, 1, 0)
    pts.lw    = pJoint(char, "LeftHand", "LeftWrist")          or pOff(char, "LeftHand", 0, 1, 0)
    pts.lhand = pPart(char, "LeftHand")

    pts.rh    = pJoint(char, "RightUpperLeg", "RightHip")      or pOff(char, "RightUpperLeg", 0, 1, 0)
    pts.rk    = pJoint(char, "RightLowerLeg", "RightKnee")     or pOff(char, "RightLowerLeg", 0, 1, 0)
    pts.ra    = pJoint(char, "RightFoot", "RightAnkle")        or pOff(char, "RightFoot", 0, 1, 0)
    pts.rfoot = pPart(char, "RightFoot")

    pts.lh    = pJoint(char, "LeftUpperLeg", "LeftHip")        or pOff(char, "LeftUpperLeg", 0, 1, 0)
    pts.lk    = pJoint(char, "LeftLowerLeg", "LeftKnee")       or pOff(char, "LeftLowerLeg", 0, 1, 0)
    pts.la    = pJoint(char, "LeftFoot", "LeftAnkle")          or pOff(char, "LeftFoot", 0, 1, 0)
    pts.lfoot = pPart(char, "LeftFoot")
end

local function fillPointsR6(char, pts)
    pts.head   = pPart(char, "Head")
    pts.neck   = pOff(char, "Torso", 0, 1, 0)
    pts.pelvis = pOff(char, "Torso", 0, -1, 0)
    pts.rs     = pOff(char, "Right Arm", 0, 1, 0)
    pts.rhand  = pOff(char, "Right Arm", 0, -1, 0)
    pts.ls     = pOff(char, "Left Arm", 0, 1, 0)
    pts.lhand  = pOff(char, "Left Arm", 0, -1, 0)
    pts.rh     = pOff(char, "Right Leg", 0, 1, 0)
    pts.rfoot  = pOff(char, "Right Leg", 0, -1, 0)
    pts.lh     = pOff(char, "Left Leg", 0, 1, 0)
    pts.lfoot  = pOff(char, "Left Leg", 0, -1, 0)
end

local function projectKey(pts, proj, key)
    local cached = proj[key]
    if cached ~= nil then return cached end
    local wp = pts[key]
    local r = false
    if wp then
        local s = Camera:WorldToViewportPoint(wp)
        if s.Z > 0 then r = s end
    end
    proj[key] = r
    return r
end

local function getBone(v, idx, color)
    local b = v.bones[idx]
    if not b then
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundColor3 = color
        f.Visible = false
        f.ZIndex = 6
        f.Parent = espContainer
        b = { frame = f, color = color }
        v.bones[idx] = b
    end
    return b
end

local function hideBones(v)
    if v.bones then
        for _, b in ipairs(v.bones) do
            if b.frame.Visible then b.frame.Visible = false end
        end
    end
end

local function drawBones(char, v, color, isR15)
    local pts = v.pts
    for k in pairs(pts) do pts[k] = nil end

    local edges
    if isR15 then
        fillPointsR15(char, pts)
        edges = R15_EDGES
    else
        fillPointsR6(char, pts)
        edges = R6_EDGES
    end

    local proj = {}
    local used = 0
    for _, ed in ipairs(edges) do
        local a = projectKey(pts, proj, ed[1])
        local b = projectKey(pts, proj, ed[2])
        if a and b then
            local dx, dy = b.X - a.X, b.Y - a.Y
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 1 then
                used = used + 1
                local bone = getBone(v, used, color)
                local f = bone.frame
                if bone.color ~= color then
                    bone.color = color
                    f.BackgroundColor3 = color
                end
                local mx = math.floor((a.X + b.X) / 2)
                local my = math.floor((a.Y + b.Y) / 2)
                local flen = math.floor(len)
                local rot = math.deg(atan2(dy, dx))
                if bone.mx ~= mx or bone.my ~= my then
                    bone.mx, bone.my = mx, my
                    f.Position = UDim2.new(0, mx, 0, my)
                end
                if bone.len ~= flen then
                    bone.len = flen
                    f.Size = UDim2.new(0, flen, 0, 2)
                end
                if bone.rot ~= rot then
                    bone.rot = rot
                    f.Rotation = rot
                end
                if not f.Visible then f.Visible = true end
            end
        end
    end
    for i = used + 1, #v.bones do
        local f = v.bones[i].frame
        if f.Visible then f.Visible = false end
    end
end

-- ========================== أسهم خارج الشاشة ==========================
local ARROW_MARGIN = 34

local function drawArrow(v, rp, color, dist, vpX, vpY)
    -- الاتجاه في فضاء الكاميرا (يعمل حتى لو الهدف خلفك)
    local rel = Camera.CFrame:PointToObjectSpace(rp)
    local dx, dy = rel.X, -rel.Y
    local mag = math.sqrt(dx * dx + dy * dy)
    if mag < 0.001 then dx, dy, mag = 0, 1, 1 end
    dx, dy = dx / mag, dy / mag

    -- إسقاط الاتجاه على حافة الشاشة
    local halfW = math.max(10, vpX / 2 - ARROW_MARGIN)
    local halfH = math.max(10, vpY / 2 - ARROW_MARGIN)
    local tx = math.abs(dx) > 1e-4 and (halfW / math.abs(dx)) or math.huge
    local ty = math.abs(dy) > 1e-4 and (halfH / math.abs(dy)) or math.huge
    local t = math.min(tx, ty)
    local px = math.floor(vpX / 2 + dx * t)
    local py = math.floor(vpY / 2 + dy * t)
    local rot = math.floor(math.deg(atan2(dx, -dy)))

    local a, tl = v.arrow, v.arrowTxt
    if v.arrowColor ~= color then
        v.arrowColor = color
        a.TextColor3 = color
        tl.TextColor3 = color
    end
    if v.apx ~= px or v.apy ~= py then
        v.apx, v.apy = px, py
        a.Position = UDim2.new(0, px, 0, py)
        tl.Position = UDim2.new(0, math.floor(px - dx * 24), 0, math.floor(py - dy * 24))
    end
    if v.arot ~= rot then
        v.arot = rot
        a.Rotation = rot
    end
    local d = math.floor(dist)
    if v.adist ~= d then
        v.adist = d
        tl.Text = d .. "m"
    end
    if not a.Visible then a.Visible = true end
    if not tl.Visible then tl.Visible = true end
end

-- ========================== رسم اللاعبين ==========================
local function drawESP(char, v, isBot, ref, camPos, bottomCenter, dt)
    if not char or not char.Parent then hideVisuals(v) return end

    local root = getRoot(char)
    if not root or not root.Parent then hideVisuals(v) return end

    -- Humanoid (يُعاد البحث فقط عند تغيّر الشخصية)
    local hum = v.hum
    if (not hum) or v.humChar ~= char or not hum:IsDescendantOf(char) then
        hum = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildWhichIsA("Humanoid", true)
        v.hum, v.humChar = hum, char
        v.hpSrc, v.hpT, v.hpPeak = nil, 99, nil
    end

    if not Config.ESPEnabled then hideVisuals(v) return end

    local rp = root.Position
    local dist = (rp - camPos).Magnitude
    if dist > Config.MaxDistance then hideVisuals(v) return end

    -- قراءة الصحة: قيمة مخصصة للعبة إن وُجدت، وإلا Humanoid
    v.hpT = v.hpT + dt
    if v.hpT >= 1 then
        v.hpT = 0
        v.hpSrc = detectHealthSource(char, hum, ref) or false
    end
    local curHp, maxHp
    local src = v.hpSrc
    if src then
        local val = readSrc(src.hp)
        if typeof(val) == "number" then
            curHp = val
            local mv = readSrc(src.mx)
            if typeof(mv) == "number" and mv > 0 then
                maxHp = mv
            else
                v.hpPeak = math.max(v.hpPeak or (hum and hum.MaxHealth) or 100, curHp)
                maxHp = v.hpPeak
            end
        end
    end
    if not curHp and hum then
        curHp, maxHp = hum.Health, hum.MaxHealth
    end
    if curHp and curHp <= 0 then hideVisuals(v) return end

    local isTeam
    if isBot then isTeam = isBotSameTeam(char)
    else isTeam = ref ~= nil and isSameTeam(ref) end
    if isTeam and Config.TeamCheck then hideVisuals(v) return end

    local behindWall = false
    if Config.WallCheck and not isBot then
        v.wallT = v.wallT + dt
        if v.wallT >= 0.2 then
            v.wallT = 0
            v.behindWall = isBehindWall(char, root, camPos)
        end
        behindWall = v.behindWall
    end

    local color
    if isTeam then color = TEAM_COLOR
    elseif isBot then color = BOT_COLOR
    elseif behindWall then color = WALL_COLOR
    else color = ENEMY_COLOR end
    if v.color ~= color then
        v.color = color
        v.boxStroke.Color = color
        v.tracer.BackgroundColor3 = color
        v.nameLbl.TextColor3 = color
        v.infoLbl.TextColor3 = color
        if v.highlight then
            v.highlight.FillColor = color
            v.highlight.OutlineColor = color
        end
    end

    -- الإسقاط: من أعلى الرأس إلى القدم، كل فريم
    local vpX, vpY = bottomCenter.X * 2, bottomCenter.Y

    local head = char:FindFirstChild("Head")
    local topPos
    if head and head:IsA("BasePart") then
        topPos = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.3, 0)
    else
        topPos = rp + Vector3.new(0, 2.8, 0)
    end

    local footDrop
    if hum and hum.RigType == Enum.HumanoidRigType.R15 then
        footDrop = hum.HipHeight + root.Size.Y / 2
    elseif hum then
        local leg = char:FindFirstChild("Left Leg")
        footDrop = root.Size.Y / 2 + ((leg and leg:IsA("BasePart")) and leg.Size.Y or 2) + hum.HipHeight
    else
        footDrop = 3
    end
    local botPos = rp - Vector3.new(0, footDrop + 0.2, 0)

    -- 👣 آثار الأقدام (تُرسم حتى لو كان اللاعب خلفك أو خارج الشاشة)
    if Config.Trails then
        local tcol = isTeam and TEAM_COLOR or TRAIL_COLOR
        Trail.update(v, botPos, dt, tcol, vpX, vpY, dist)
    else
        Trail.hide(v)
    end

    local top = Camera:WorldToViewportPoint(topPos)
    local bot = Camera:WorldToViewportPoint(botPos)

    -- خلف الكاميرا: نخفي الرسومات ونعرض سهماً فقط
    if top.Z <= 0 or bot.Z <= 0 then
        hideMain(v)
        if Config.Arrows then
            drawArrow(v, rp, color, dist, vpX, vpY)
        else
            hideArrow(v)
        end
        return
    end

    v._hidden = false

    local bh = math.floor(math.max(math.abs(bot.Y - top.Y), 8))
    local bw = math.floor(math.max(bh * 0.55, 6))
    local cx = (top.X + bot.X) * 0.5
    local cy = (top.Y + bot.Y) * 0.5
    local bx = math.floor(cx - bw / 2)
    local by = math.floor(math.min(top.Y, bot.Y))

    -- سهم إذا كان مركز اللاعب خارج حدود الشاشة (جانب/أعلى/أسفل)
    if Config.Arrows and (cx < 0 or cx > vpX or cy < 0 or cy > vpY) then
        drawArrow(v, rp, color, dist, vpX, vpY)
    else
        hideArrow(v)
    end

    if Config.Box then
        v.box.Position = UDim2.new(0, bx, 0, by)
        v.box.Size = UDim2.new(0, bw, 0, bh)
        v.box.Visible = true
    elseif v.box.Visible then
        v.box.Visible = false
    end

    -- الخط
    if Config.Tracers then
        local dx = bot.X - bottomCenter.X
        local dy = bot.Y - bottomCenter.Y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 4 then
            local rot = math.deg(atan2(dy, dx))
            local flen = math.floor(len)
            local mx = math.floor((bottomCenter.X + bot.X) / 2)
            local my = math.floor((bottomCenter.Y + bot.Y) / 2)
            if v.tx ~= mx or v.ty ~= my then
                v.tx, v.ty = mx, my
                v.tracer.Position = UDim2.new(0, mx, 0, my)
            end
            if v.tl ~= flen then
                v.tl = flen
                v.tracer.Size = UDim2.new(0, flen, 0, 2)
            end
            if v.tr ~= rot then
                v.tr = rot
                v.tracer.Rotation = rot
            end
            v.tracer.Visible = true
        elseif v.tracer.Visible then
            v.tracer.Visible = false
        end
    elseif v.tracer.Visible then
        v.tracer.Visible = false
    end

    -- الهيكل العظمي: لونه ثابت (SKELETON_COLOR) ولا يتأثر بـ Wall Check أو الفريق
    if Config.Skeleton and not Config.PerfMode and dist <= SKELETON_MAX_DIST then
        local isR15
        if hum then isR15 = hum.RigType == Enum.HumanoidRigType.R15
        else isR15 = char:FindFirstChild("LowerTorso") ~= nil end
        drawBones(char, v, SKELETON_COLOR, isR15)
    else
        hideBones(v)
    end

    -- الاسم
    if Config.Names then
        local nm = isBot and ("🤖 " .. char.Name) or ref.Name
        if v.lastName ~= nm then
            v.lastName = nm
            v.nameLbl.Text = nm
        end
        local nxi, ny = math.floor(cx), by - 4
        if v.nx ~= nxi or v.ny ~= ny then
            v.nx, v.ny = nxi, ny
            v.nameLbl.Position = UDim2.new(0, nxi, 0, ny)
        end
        v.nameLbl.Visible = true
    elseif v.nameLbl.Visible then
        v.nameLbl.Visible = false
    end

    -- شريط الصحة
    if Config.Health and curHp then
        local pct = math.clamp(curHp / math.max(maxHp or 100, 1), 0, 1)
        v.hpBg.Position = UDim2.new(0, bx - 5, 0, by)
        v.hpBg.Size = UDim2.new(0, 3, 0, bh)
        local fillH = math.floor(bh * pct)
        if v.hpfh ~= fillH then
            v.hpfh = fillH
            v.hpFill.Size = UDim2.new(1, 0, 0, fillH)
        end
        local hcol = pct > 0.5 and Color3.fromRGB(46, 204, 113)
            or (pct > 0.25 and Color3.fromRGB(230, 200, 40) or Color3.fromRGB(220, 60, 60))
        if v.hpcol ~= hcol then
            v.hpcol = hcol
            v.hpFill.BackgroundColor3 = hcol
        end
        v.hpBg.Visible = true
        v.hpFill.Visible = true
    else
        v.hpBg.Visible = false
        v.hpFill.Visible = false
    end

    -- المعلومات (نص الصحة + المسافة)
    v.infoT = v.infoT + dt
    if v.infoT >= (Config.PerfMode and 0.3 or 0.15) then
        v.infoT = 0
        local infoText = ""
        if Config.Health and curHp then
            infoText = "❤️ " .. math.floor(curHp + 0.5) .. "/" .. math.floor((maxHp or 100) + 0.5)
        end
        if Config.ShowDistance then
            infoText = infoText .. (infoText ~= "" and " | " or "") .. math.floor(dist) .. "m"
        end
        if v.lastInfo ~= infoText then
            v.lastInfo = infoText
            v.infoLbl.Text = infoText
        end
        v.infoEmpty = (infoText == "")
    end
    if not v.infoEmpty then
        local ixi, iy = math.floor(cx), by + bh + 4
        if v.ix ~= ixi or v.iy ~= iy then
            v.ix, v.iy = ixi, iy
            v.infoLbl.Position = UDim2.new(0, ixi, 0, iy)
        end
        v.infoLbl.Visible = true
    elseif v.infoLbl.Visible then
        v.infoLbl.Visible = false
    end

    -- السلاح / الأداة بيده
    if Config.Weapons then
        v.weaponT = v.weaponT + dt
        if v.weaponT >= 0.25 then
            v.weaponT = 0
            v.weapon = getHeldWeapon(char, ref) or false
        end
        local w = v.weapon
        if w then
            if v.lastWeapon ~= w then
                v.lastWeapon = w
                v.toolLbl.Text = "🔫 " .. w
            end
            local wx = math.floor(cx)
            local wy = by + bh + 4 + (v.infoEmpty and 0 or 13)
            if v.wx ~= wx or v.wy ~= wy then
                v.wx, v.wy = wx, wy
                v.toolLbl.Position = UDim2.new(0, wx, 0, wy)
            end
            v.toolLbl.Visible = true
        elseif v.toolLbl.Visible then
            v.toolLbl.Visible = false
        end
    elseif v.toolLbl.Visible then
        v.toolLbl.Visible = false
    end

    -- الهايت لايت (يتعطل في وضع الأداء)
    if Config.Highlight and not Config.PerfMode then
        if v.highlightChar ~= char or not v.highlight or not v.highlight.Parent then
            if v.highlight then pcall(function() v.highlight:Destroy() end) end
            local hl = Instance.new("Highlight")
            hl.Name = "ESP_HL"
            hl.FillTransparency = 0.65
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            local ok = pcall(function() hl.Parent = char end)
            if not ok or not hl.Parent then
                hl.Adornee = char
                hl.Parent = espContainer
            end
            hl.FillColor = color
            hl.OutlineColor = color
            v.highlight = hl
            v.highlightChar = char
        end
        v.highlight.Enabled = true
    elseif v.highlight and v.highlight.Enabled then
        v.highlight.Enabled = false
    end
end

-- ========================== كشف المركبات (اسم + مسافة فقط) ==========================
local VEH_MAX_DIAG = 120   -- أكبر قطر (studs) يُعتبر مركبة
local MAX_VEHICLES = 60

-- ترتيب الفحص مهم: الأدق أولاً
local VEH_KINDS = {
    { emoji = "🪖", word = "Tank",  keys = {"tank", "panzer", "abrams", "sherman", "apc", "ifv", "bradley", "armor", "leopard"} },
    { emoji = "🚁", word = "Heli",  keys = {"heli", "chopper", "blackhawk", "apache", "huey", "copter", "osprey"} },
    { emoji = "✈️", word = "Plane", keys = {"plane", "jet", "aircraft", "fighter", "bomber", "cessna", "spitfire", "biplane", "glider", "f-16", "f16", "a-10"} },
    { emoji = "🚤", word = "Boat",  keys = {"boat", "ship", "jetski", "yacht", "submarine", "hovercraft"} },
    { emoji = "🏍️", word = "Bike",  keys = {"motorcycle", "motorbike", "moto", "motor", "bike", "atv", "quad", "scooter", "dirtbike"} },
}
local CAR_KIND = { emoji = "🚗", word = "Car" }

local SEAT_HINTS = {"drive", "pilot", "cockpit", "vehicle", "gunner"}
local ALL_MODEL_HINTS = {"car", "truck", "jeep", "humvee", "vehicle", "taxi", "tractor", "buggy", "kart", "bus"}
for _, k in ipairs(VEH_KINDS) do
    for _, key in ipairs(k.keys) do ALL_MODEL_HINTS[#ALL_MODEL_HINTS + 1] = key end
end

local function hasHint(str, list)
    str = str:lower()
    for _, h in ipairs(list) do
        if str:find(h, 1, true) then return true end
    end
    return false
end

local function classifyVehicle(model, seat)
    local s = model.Name:lower()
    local p = model.Parent
    if p and p ~= workspace then s = s .. " " .. p.Name:lower() end
    s = s .. " " .. seat.Name:lower()
    for _, k in ipairs(VEH_KINDS) do
        for _, key in ipairs(k.keys) do
            if s:find(key, 1, true) then return k end
        end
    end
    return CAR_KIND
end

-- فلتر سريع: كراسي المباني العادية لا تُعتبر مركبات
local function quickHint(seat)
    if seat.ClassName == "VehicleSeat" then return true end
    if hasHint(seat.Name, SEAT_HINTS) or hasHint(seat.Name, ALL_MODEL_HINTS) then return true end
    local p = seat.Parent
    for _ = 1, 2 do
        if not p or p == workspace then break end
        if hasHint(p.Name, ALL_MODEL_HINTS) or hasHint(p.Name, SEAT_HINTS) then return true end
        p = p.Parent
    end
    return false
end

local extCache = setmetatable({}, { __mode = "k" })
local function modelDiag(m)
    local d = extCache[m]
    if d == nil then
        local ok, sz = pcall(m.GetExtentsSize, m)
        d = ok and sz.Magnitude or math.huge
        extCache[m] = d
    end
    return d
end

-- أكبر Model حول الكرسي بحجم معقول (يتجنب اعتبار الماب كلها مركبة)
local function findVehicleModel(seat)
    local best = nil
    local cur = seat.Parent
    local depth = 0
    while cur and cur ~= workspace and depth < 10 do
        if cur:IsA("Model") then
            if Players:GetPlayerFromCharacter(cur) then return nil end
            if modelDiag(cur) <= VEH_MAX_DIAG then best = cur else break end
        elseif best then
            break
        end
        cur = cur.Parent
        depth = depth + 1
    end
    return best
end

local function registerSeat(seat)
    if not Running then return end
    local cn = seat.ClassName
    if cn ~= "VehicleSeat" and cn ~= "Seat" then return end
    if vehicleCount >= MAX_VEHICLES then return end
    if not quickHint(seat) then return end
    local model = findVehicleModel(seat)
    if not model or vehicles[model] then return end

    local kind = classifyVehicle(model, seat)
    local nm = model.Name
    if nm == "" or nm:lower() == "model" then nm = kind.word end
    if #nm > 24 then nm = nm:sub(1, 24) end

    vehicles[model] = {
        model = model, ref = seat, baseText = kind.emoji .. " " .. nm,
        rel = nil, size = nil, bbT = 99, v = nil,
    }
    vehicleCount = vehicleCount + 1
end

local function scanVehicles()
    local d = workspace:GetDescendants()
    for i, inst in ipairs(d) do
        if not Running then return end
        if i % 3000 == 0 then task.wait() end
        local cn = inst.ClassName
        if cn == "VehicleSeat" or cn == "Seat" then
            pcall(registerSeat, inst)
        end
    end
end

-- الفحص يبدأ فقط عند تفعيل زر المركبات (لتوفير الأداء)
track(workspace.DescendantAdded:Connect(function(inst)
    if not vehScanned then return end
    local cn = inst.ClassName
    if cn == "VehicleSeat" or cn == "Seat" then
        task.defer(function() pcall(registerSeat, inst) end)
    end
end))

local function buildVehicleVisuals()
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = VEH_COLOR
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    lbl.AnchorPoint = Vector2.new(0.5, 1)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Size = UDim2.new(0, 200, 0, 14)
    lbl.Visible = false
    lbl.ZIndex = 6
    lbl.Parent = espContainer
    return { lbl = lbl, shown = false, txtT = 99, lastTxt = nil }
end

local function hideVehicle(e)
    local vv = e.v
    if vv and vv.shown then
        vv.shown = false
        vv.lbl.Visible = false
    end
end

local function drawVehicle(e, camPos, dt, mySeat)
    local model = e.model
    local ref = e.ref
    if (not ref) or (not ref.Parent) or (not ref:IsDescendantOf(model)) then
        ref = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        e.ref, e.rel = ref, nil
        if not ref then hideVehicle(e) return end
    end

    -- لا نرسم المركبة التي أنت جالس فيها
    if mySeat and mySeat:IsDescendantOf(model) then hideVehicle(e) return end

    local dist = (ref.Position - camPos).Magnitude
    if dist > Config.MaxDistance then hideVehicle(e) return end

    -- صندوق الإحاطة يُحسب كل ثانيتين فقط لمعرفة مركز المركبة وارتفاعها
    e.bbT = e.bbT + dt
    if (not e.rel) or e.bbT >= 2 then
        e.bbT = 0
        local ok, cf, size = pcall(model.GetBoundingBox, model)
        if ok and cf and size then
            e.rel = ref.CFrame:ToObjectSpace(cf)
            e.size = size
        end
    end
    if not e.rel then hideVehicle(e) return end

    local cf = ref.CFrame * e.rel
    local wp = cf.Position + Vector3.new(0, e.size.Y * 0.5 + 1.5, 0)
    local sp = Camera:WorldToViewportPoint(wp)
    if sp.Z <= 0 then hideVehicle(e) return end

    local vv = e.v
    if not vv then
        vv = buildVehicleVisuals()
        e.v = vv
    end

    vv.txtT = vv.txtT + dt
    if vv.txtT >= 0.2 then
        vv.txtT = 0
        local t = e.baseText
        if Config.ShowDistance then t = t .. " | " .. math.floor(dist) .. "m" end
        if vv.lastTxt ~= t then
            vv.lastTxt = t
            vv.lbl.Text = t
        end
    end
    vv.lbl.Position = UDim2.new(0, math.floor(sp.X), 0, math.floor(sp.Y))

    vv.shown = true
    vv.lbl.Visible = true
end

-- ========================== 💎 كشف الغنائم (Loot / Item ESP) ==========================
-- الكشف يعتمد على ثلاثة مصادر:
--   1) Tool ساقط على الأرض (خارج أي شخصية/حقيبة)  -> سلاح/أداة
--   2) ProximityPrompt بنص مثل Pick up / Loot / Collect (أدق مصدر)
--   3) Model/Part اسمه يحتوي كلمة مفتاحية (Crate, Ammo, Cash, Rifle ...)
-- لإضافة كلمات جديدة لعبتك عدّل الجداول keys في LOOT_KINDS أدناه.
do
    local MAX_LOOT = 200        -- أقصى عدد غنائم مسجّلة
    local LOOT_MAX_DIAG = 40    -- أكبر قطر (studs) يُعتبر غنيمة (يستبعد المباني)

    -- fidx = رقم الفلتر الذي يظهر فيه (nil = يظهر فقط عند فلتر "الكل")
    local LOOT_KINDS = {
        { emoji = "🔫", label = "Weapon", fidx = 2, color = Color3.fromRGB(255, 90, 90),
          keys = {"rifle", "pistol", "shotgun", "smg", "glock", "revolver", "uzi", "sniper", "knife",
                  "sword", "weapon", "gun", "machete", "katana", "grenade", "rpg", "carbine",
                  "crossbow", "spear", "flamethrower", "ak47", "ak-47", "m4a1", "deagle", "mp5",
                  "tec9", "tec-9", "mac10", "mac-10"} },
        { emoji = "💊", label = "Supply", fidx = 3, color = Color3.fromRGB(80, 255, 130),
          keys = {"ammo", "magazine", "bullets", "medkit", "medical", "bandage", "firstaid",
                  "first aid", "health", "syringe", "potion", "bodyarmor", "body armor", "kevlar",
                  "bulletproof"} },
        { emoji = "💵", label = "Cash", fidx = 4, color = Color3.fromRGB(255, 230, 80),
          keys = {"cash", "money", "coin", "dollar", "wallet", "gold", "diamond"} },
        { emoji = "📦", label = "Crate", fidx = 5, color = Color3.fromRGB(80, 190, 255),
          keys = {"crate", "chest", "loot", "supply", "supplies", "airdrop", "stash", "resource",
                  "scrap", "mineral", "herb"} },
        { emoji = "🎒", label = "Item", fidx = nil, color = Color3.fromRGB(255, 255, 255),
          keys = {"pickup", "pick_up", "pick up", "collectible", "dropped"} },
    }
    local LOOT_ITEM_KIND = LOOT_KINDS[5]
    local LOOT_TOOL_KIND = { emoji = "🛠️", label = "Tool", fidx = 2, color = Color3.fromRGB(255, 150, 60), keys = {} }

    -- كلمات نص الـ ProximityPrompt التي تدل على التقاط شيء
    local PROMPT_WORDS = {"pick", "loot", "take", "collect", "grab", "search", "equip"}

    -- الأصناف التي نفحصها
    local LOOT_CLASSES = {
        Tool = true, ProximityPrompt = true, Model = true,
        Part = true, MeshPart = true, UnionOperation = true,
    }

    -- كاش تصنيف الأسماء (الأسماء تتكرر كثيراً)
    local nameCache, nameCacheN = {}, 0
    local function classifyName(str)
        local s = str:lower()
        local c = nameCache[s]
        if c ~= nil then return c or nil end
        local found = false
        for _, k in ipairs(LOOT_KINDS) do
            for _, key in ipairs(k.keys) do
                if s:find(key, 1, true) then
                    found = k
                    break
                end
            end
            if found then break end
        end
        nameCacheN = nameCacheN + 1
        if nameCacheN > 3000 then nameCache, nameCacheN = {}, 0 end
        nameCache[s] = found
        return found or nil
    end

    -- استبعاد كل ما هو داخل شخصية (لاعب/بوت) أو خارج الـ workspace (مثل Backpack)
    local function isExcluded(inst)
        if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then return true end
        local p = inst.Parent
        for _ = 1, 25 do
            if p == workspace then return false end
            if not p then return true end
            if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return true end
            p = p.Parent
        end
        return true
    end

    -- هل أحد آباء العنصر مسجّل مسبقاً؟ (لتجنب تكرار Model + Part داخله)
    local function ancestorRegistered(inst)
        local p = inst.Parent
        for _ = 1, 6 do
            if not p or p == workspace then return false end
            if Loot.items[p] then return true end
            p = p.Parent
        end
        return false
    end

    local function register(inst)
        if not Loot.scanned or not Running then return end
        if Loot.count >= MAX_LOOT or Loot.items[inst] then return end
        local cn = inst.ClassName
        local tgt, kind

        if cn == "Tool" then
            if isExcluded(inst) then return end
            tgt = inst
            kind = classifyName(inst.Name) or LOOT_TOOL_KIND

        elseif cn == "ProximityPrompt" then
            local par = inst.Parent
            if par and par:IsA("Attachment") then par = par.Parent end
            if not par or par == workspace then return end
            tgt = par
            if par:IsA("BasePart") then
                local m = par.Parent
                if m and m ~= workspace and m:IsA("Model") and modelDiag(m) <= LOOT_MAX_DIAG then
                    tgt = m
                end
            end
            if Loot.items[tgt] or isExcluded(tgt) or ancestorRegistered(tgt) then return end
            local txt = inst.ActionText .. " " .. inst.ObjectText .. " " .. tgt.Name
            kind = classifyName(txt)
            if not kind then
                if not hasHint(txt, PROMPT_WORDS) then return end
                kind = LOOT_ITEM_KIND
            end

        else
            local k = classifyName(inst.Name)
            if not k then return end
            if cn == "Model" then
                if modelDiag(inst) > LOOT_MAX_DIAG then return end
            elseif inst.Size.Magnitude > LOOT_MAX_DIAG then
                return
            end
            if isExcluded(inst) or ancestorRegistered(inst) then return end
            tgt, kind = inst, k
        end

        local nm = tgt.Name
        if nm == "" or nm == "Model" or nm == "Part" or nm == "Handle" or nm == "MeshPart" then
            nm = kind.label
        end
        if #nm > 24 then nm = nm:sub(1, 24) end

        Loot.items[tgt] = {
            target = tgt, kind = kind, text = kind.emoji .. " " .. nm,
            part = nil, chkT = 0, excluded = false, txtT = 99,
            lbl = nil, shown = false, lastTxt = nil,
        }
        Loot.count = Loot.count + 1
    end

    local function scan()
        local d = workspace:GetDescendants()
        for i, inst in ipairs(d) do
            if not Running or not Loot.scanned then return end
            if i % 2500 == 0 then task.wait() end
            if LOOT_CLASSES[inst.ClassName] then pcall(register, inst) end
        end
    end

    -- عناصر جديدة (إسقاط سلاح، ظهور صندوق، ستريمنج ...)
    track(workspace.DescendantAdded:Connect(function(inst)
        if not Loot.scanned then return end
        if LOOT_CLASSES[inst.ClassName] then
            task.defer(function() pcall(register, inst) end)
        end
    end))

    local function getPart(tgt)
        if tgt:IsA("BasePart") then return tgt end
        if tgt:IsA("Model") then
            return tgt.PrimaryPart or tgt:FindFirstChildWhichIsA("BasePart", true)
        end
        local h = tgt:FindFirstChild("Handle")
        if h and h:IsA("BasePart") then return h end
        return tgt:FindFirstChildWhichIsA("BasePart", true)
    end

    local function makeLabel(color)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.AnchorPoint = Vector2.new(0.5, 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.Size = UDim2.new(0, 200, 0, 14)
        lbl.Visible = false
        lbl.ZIndex = 6
        lbl.Parent = espContainer
        return lbl
    end

    local function hide(e)
        if e.shown then
            e.shown = false
            if e.lbl then e.lbl.Visible = false end
        end
    end

    local function destroyEntry(e)
        if e and e.lbl then
            pcall(function() e.lbl:Destroy() end)
            e.lbl = nil
        end
    end

    local function draw(e, camPos, dt)
        local kind = e.kind
        local f = Prefs.LootFilter
        if f ~= 1 and kind.fidx ~= f then hide(e) return end

        local tgt = e.target
        e.chkT = e.chkT + dt
        if e.chkT >= 0.5 then
            e.chkT = 0
            e.excluded = isExcluded(tgt)   -- مثلاً: التقطه لاعب فأصبح داخل شخصيته
        end
        if e.excluded then hide(e) return end

        local part = e.part
        if (not part) or (not part.Parent) or (part ~= tgt and not part:IsDescendantOf(tgt)) then
            part = getPart(tgt)
            e.part = part
            if not part then hide(e) return end
        end

        local pos = part.Position
        local dist = (pos - camPos).Magnitude
        if dist > Config.MaxDistance then hide(e) return end

        local sp = Camera:WorldToViewportPoint(pos + Vector3.new(0, part.Size.Y * 0.5 + 0.8, 0))
        if sp.Z <= 0 then hide(e) return end
        local vp = Camera.ViewportSize
        if sp.X < -60 or sp.X > vp.X + 60 or sp.Y < -20 or sp.Y > vp.Y + 20 then
            hide(e)
            return
        end

        local lbl = e.lbl
        if not lbl then
            lbl = makeLabel(kind.color)
            e.lbl = lbl
        end

        e.txtT = e.txtT + dt
        if e.txtT >= (Config.PerfMode and 0.4 or 0.2) then
            e.txtT = 0
            local t = e.text
            if Config.ShowDistance then t = t .. " | " .. math.floor(dist) .. "m" end
            if e.lastTxt ~= t then
                e.lastTxt = t
                lbl.Text = t
            end
        end
        lbl.Position = UDim2.new(0, math.floor(sp.X), 0, math.floor(sp.Y))
        if not e.shown then
            e.shown = true
            lbl.Visible = true
        end
    end

    function Loot.destroyAll()
        for _, e in pairs(Loot.items) do destroyEntry(e) end
        Loot.items = {}
        Loot.count = 0
        Loot.scanned = false
    end

    -- يُستدعى كل فريم من حلقة الرسم
    function Loot.step(camPos, dt)
        if Config.LootESP and Config.ESPEnabled then
            if not Loot.scanned then
                Loot.scanned = true
                task.spawn(scan)
            end
            for tgt, e in pairs(Loot.items) do
                if not tgt:IsDescendantOf(workspace) then
                    destroyEntry(e)
                    Loot.items[tgt] = nil
                    Loot.count = Loot.count - 1
                else
                    local ok, err = pcall(draw, e, camPos, dt)
                    if not ok and not e.errShown then
                        e.errShown = true
                        warn("[UniversalESP][Loot] خطأ: " .. tostring(err))
                    end
                end
            end
        elseif Loot.scanned or Loot.count > 0 then
            Loot.destroyAll()
        end
    end
end

-- ========================== 🎯 الأيم بوت (Aimbot) ==========================
-- يعمل داخل حلقة الرسم (بعد سكربت الكاميرا) ويحرّك الكاميرا نحو أقرب هدف داخل FOV.
-- يستخدم Team Check و مسافة الكشف من الإعدادات العامة.
local Aim = { lock = nil }
-- ملاحظة: الوحدة داخل دالة مستقلة لأن Luau يحدّ المتغيرات المحلية بـ 200 في المستوى الرئيسي
local function setupAim()
    Config.AimFOV = math.clamp(Config.AimFOV, 20, 600)
    Config.AimSmooth = math.clamp(Config.AimSmooth, 1, 20)

    -- دائرة FOV
    local circle = Instance.new("Frame")
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.Position = UDim2.new(0.5, 0, 0.5, 0)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Visible = false
    circle.ZIndex = 4
    circle.Parent = espContainer
    addCorner(circle, 1000)
    local circleStroke = addStroke(circle, Color3.new(1, 1, 1), 1.2)
    local lastFov = nil

    -- 🖱️ تحريك الماوس الحقيقي (تتبعه اللعبة: الكاميرا + اليد + السلاح)
    local mouseMoveFn = (typeof(mousemoverel) == "function") and mousemoverel or nil
    local accX, accY = 0, 0            -- الباقي الكسري من حركة الماوس بين الفريمات
    local MAX_STEP = 150               -- أقصى حركة ماوس في فريم واحد
    local sensT, sensV = 99, 1

    -- كم بكسل على الشاشة تتحرك الكاميرا لكل وحدة ماوس (تقدير حسب حساسية روبلوكس + FOV)
    local function mouseGain(dt)
        sensT = sensT + dt
        if sensT >= 1 then
            sensT = 0
            local s = 1
            pcall(function()
                s = UserSettings():GetService("UserGameSettings").MouseSensitivity
            end)
            if type(s) == "number" and s > 0 then sensV = s else sensV = 1 end
        end
        local fovHalf = math.rad(math.clamp(Camera.FieldOfView, 10, 120) / 2)
        local pxPerRad = (Camera.ViewportSize.Y / 2) / math.tan(fovHalf)
        return math.max(0.5, 0.002 * math.pi * pxPerRad * sensV),
               math.max(0.5, 0.0015 * math.pi * pxPerRad * sensV)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local function canSee(char, pos, camPos)
        local ignore = { char }
        local mine = LocalPlayer.Character
        if mine then ignore[2] = mine end
        rayParams.FilterDescendantsInstances = ignore
        return workspace:Raycast(camPos, pos - camPos, rayParams) == nil
    end

    local function screenDist(part, center)
        local sp = Camera:WorldToViewportPoint(part.Position)
        if sp.Z <= 0 then return nil end
        return (Vector2.new(sp.X, sp.Y) - center).Magnitude
    end

    local function getAimPart(char, center)
        local head = char:FindFirstChild("Head")
        if head and not head:IsA("BasePart") then head = nil end
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
        if torso and not torso:IsA("BasePart") then torso = nil end

        local mode = Prefs.AimPartIdx
        if mode == 1 then return head or torso end
        if mode == 2 then return torso or head end
        -- 3: الأقرب لمركز الشاشة
        if head and torso then
            local dh, dt2 = screenDist(head, center), screenDist(torso, center)
            if dh and dt2 then return (dh <= dt2) and head or torso end
            return dh and head or torso
        end
        return head or torso
    end

    -- يرجع (الجزء، المسافة عن مركز الشاشة) أو nil إذا غير صالح كهدف
    local function evaluate(char, isBot, ref, camPos, center, fov)
        if not char or not char.Parent then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return nil end

        local isTeam
        if isBot then isTeam = isBotSameTeam(char)
        else isTeam = ref ~= nil and isSameTeam(ref) end
        if isTeam and Config.TeamCheck then return nil end

        local part = getAimPart(char, center)
        if not part then return nil end
        local pos = part.Position
        if (pos - camPos).Magnitude > Config.MaxDistance then return nil end

        local d = screenDist(part, center)
        if not d or d > fov then return nil end
        if Config.AimWallCheck and not canSee(char, pos, camPos) then return nil end
        return part, d
    end

    local function overMenu()
        if not UserInputService.MouseEnabled or not mainFrame.Visible then return false end
        local m = UserInputService:GetMouseLocation()
        local p, s = mainFrame.AbsolutePosition, mainFrame.AbsoluteSize
        return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
    end

    -- 📱 جهاز لمس بدون ماوس: أزرار الماوس لا تعمل، فنستخدم زر AIM على الشاشة
    local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    local function effectiveKey()
        local k = Prefs.AimKeyIdx
        if touchOnly and k < 3 then return 4 end
        return k
    end

    -- زر AIM على الشاشة: اضغط لتشغيله/إيقافه، واسحبه لتغيير مكانه
    local aimOn = false
    local aimBtn = Instance.new("TextButton")
    aimBtn.Size = UDim2.fromOffset(54, 54)
    do
        local vpv = viewport()
        aimBtn.Position = UDim2.fromOffset(math.max(2, vpv.X - 140), math.floor(vpv.Y * 0.45))
    end
    aimBtn.Text = "AIM"
    aimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    aimBtn.TextColor3 = Color3.new(1, 1, 1)
    aimBtn.Font = Enum.Font.GothamBold
    aimBtn.TextSize = 13
    aimBtn.AutoButtonColor = false
    aimBtn.Visible = false
    aimBtn.ZIndex = 90
    aimBtn.Parent = screenGui
    addCorner(aimBtn, 27)
    local aimBtnStroke = addStroke(aimBtn, Color3.new(1, 1, 1), 1.5)

    local function paintAimBtn()
        aimBtn.BackgroundColor3 = aimOn and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(60, 60, 60)
        aimBtnStroke.Color = aimOn and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
    end

    local aDown, aMoved = nil, false
    aimBtn.InputBegan:Connect(function(input)
        if isPress(input) then aDown, aMoved = input.Position, false end
    end)
    aimBtn.InputEnded:Connect(function(input)
        if isPress(input) then
            if aDown and not aMoved and Running then
                aimOn = not aimOn
                paintAimBtn()
            end
            aDown = nil
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if aDown and isMove(input) and (input.Position - aDown).Magnitude > 10 then
            aMoved = true
        end
    end))
    makeDraggable(aimBtn, aimBtn)

    local function isActive()
        if UserInputService:GetFocusedTextBox() then return false end
        if dragging or overMenu() then return false end
        local k = effectiveKey()
        if k == 1 then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif k == 2 then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        elseif k == 4 then
            return aimOn
        end
        return true
    end

    -- 🧍 جعل الشخصية تواجه الهدف حتى تتبعها اليد والسلاح (يعمل مع طريقة الكاميرا)
    local faceActive = false

    local function restoreFace()
        if not faceActive then return end
        faceActive = false
        local mc = LocalPlayer.Character
        local mh = mc and mc:FindFirstChildOfClass("Humanoid")
        if mh then mh.AutoRotate = true end
    end
    env.UniversalESP_AimCleanup = restoreFace

    local function faceTarget(targetPos, alpha)
        local mc = LocalPlayer.Character
        if not mc then return end
        local hrp = mc:FindFirstChild("HumanoidRootPart")
        local mh = mc:FindFirstChildOfClass("Humanoid")
        if not hrp or not mh or mh.Health <= 0 or mh.SeatPart then
            restoreFace()
            return
        end
        local dir = targetPos - hrp.Position
        local flat = Vector3.new(dir.X, 0, dir.Z)
        if flat.Magnitude < 0.5 then return end
        if mh.AutoRotate then
            mh.AutoRotate = false
            faceActive = true
        end
        local goal = CFrame.lookAt(hrp.Position, hrp.Position + flat)
        hrp.CFrame = hrp.CFrame:Lerp(goal, math.max(alpha, 0.35))
    end

    -- حالة البحث عن أقرب هدف (متغيرات خارجية لتجنب إنشاء closures كل فريم)
    local bestPart, bestD, bestInfo
    local sCamPos, sCenter, sFov

    local function consider(char, isBot, ref)
        local p, d = evaluate(char, isBot, ref, sCamPos, sCenter, sFov)
        if p and d < bestD then
            bestPart, bestD = p, d
            bestInfo = { char = char, isBot = isBot, ref = ref }
        end
    end

    function Aim.step(camPos, dt)
        local fov = Config.AimFOV
        local showCircle = Config.AimEnabled and Config.AimFOVCircle
        if circle.Visible ~= showCircle then circle.Visible = showCircle end
        local wantBtn = Config.AimEnabled and effectiveKey() == 4
        if aimBtn.Visible ~= wantBtn then aimBtn.Visible = wantBtn end
        if showCircle and lastFov ~= fov then
            lastFov = fov
            circle.Size = UDim2.fromOffset(fov * 2, fov * 2)
        end

        if not Config.AimEnabled or not isActive() then
            Aim.lock = nil
            accX, accY = 0, 0
            restoreFace()
            circleStroke.Color = Color3.new(1, 1, 1)
            return
        end

        local center = Camera.ViewportSize / 2
        local part = nil

        -- تثبيت الهدف: نكمل على نفس الهدف طالما صالح (حتى لو خرج من FOV)
        local lock = Aim.lock
        if Config.AimSticky and lock then
            part = evaluate(lock.char, lock.isBot, lock.ref, camPos, center, math.huge)
            if not part then Aim.lock = nil end
        end

        if not part then
            bestPart, bestD, bestInfo = nil, math.huge, nil
            sCamPos, sCenter, sFov = camPos, center, fov

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then consider(plr.Character, false, plr) end
            end
            -- ملاحظة: قائمة البوتات تُملأ فقط عند تفعيل "البوتات" في تبويب ESP
            if Config.AimBots then
                for model in pairs(botCache) do
                    if model.Parent then consider(model, true, nil) end
                end
            end

            part = bestPart
            if part and Config.AimSticky then Aim.lock = bestInfo end
        end

        if not part then
            restoreFace()
            circleStroke.Color = Color3.new(1, 1, 1)
            return
        end
        circleStroke.Color = Color3.fromRGB(255, 60, 60)

        local sm = Config.AimSmooth
        local alpha = (sm <= 1) and 1 or (1 - math.exp(-dt * 60 / sm))

        if Prefs.AimMethodIdx == 1 and mouseMoveFn then
            -- الطريقة 1: تحريك الماوس فعلياً، فتتبعه اللعبة نفسها (اليد والسلاح يصوّبون معه)
            local sp = Camera:WorldToViewportPoint(part.Position)
            local ex, ey = sp.X - center.X, sp.Y - center.Y
            if math.abs(ex) < 1 and math.abs(ey) < 1 then
                accX, accY = 0, 0
                return
            end

            local gx, gy = mouseGain(dt)
            local mul = Config.AimMousePct / 100
            local mx = math.clamp(ex * alpha * mul / gx + accX, -MAX_STEP, MAX_STEP)
            local my = math.clamp(ey * alpha * mul / gy + accY, -MAX_STEP, MAX_STEP)
            local ix = (mx >= 0) and math.floor(mx) or math.ceil(mx)
            local iy = (my >= 0) and math.floor(my) or math.ceil(my)
            accX, accY = mx - ix, my - iy
            if ix ~= 0 or iy ~= 0 then
                pcall(mouseMoveFn, ix, iy)
            end
        else
            -- الطريقة 2 (احتياطية): تدوير الكاميرا مباشرة
            local cf = Camera.CFrame
            local goal = CFrame.lookAt(cf.Position, part.Position)
            Camera.CFrame = cf:Lerp(goal, alpha)

            -- الشخصية تواجه الهدف: اليد والسلاح تتبعها بدل ما تبقى متحركة
            if Config.AimFaceChar then
                faceTarget(part.Position, alpha)
            else
                restoreFace()
            end
        end
    end
end
setupAim()

-- ========================== حلقة الرسم ==========================
local function safeDraw(e, char, isBot, ref, camPos, bottomCenter, dt)
    local ok, err = pcall(drawESP, char, e.visuals, isBot, ref, camPos, bottomCenter, dt)
    if not ok and not e.errShown then
        e.errShown = true
        warn("[UniversalESP] خطأ: " .. tostring(err))
    end
end

RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
    Camera = workspace.CurrentCamera
    if not Running or not Camera then return end

    local vp = Camera.ViewportSize
    local bottomCenter = Vector2.new(vp.X / 2, vp.Y)
    local camPos = Camera.CFrame.Position

    Trail.budget = Trail.BUDGET   -- ميزانية خطوط الآثار لهذا الفريم

    botScanT = botScanT + dt
    if botScanT >= 2.5 then
        botScanT = 0
        task.spawn(sweepBots)
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and char.Parent and getRoot(char) then
                local e = spawnEntry(entries, plr)
                if not e.visuals then e.visuals = buildVisuals() end
                safeDraw(e, char, false, plr, camPos, bottomCenter, dt)
            else
                local e = entries[plr]
                if e and e.visuals then hideVisuals(e.visuals) end
            end
        end
    end

    if Config.ShowBots then
        for model, e in pairs(botCache) do
            if not model.Parent then
                destroyVisuals(e.visuals)
                botCache[model] = nil
            else
                if not e.visuals then e.visuals = buildVisuals() end
                safeDraw(e, model, true, nil, camPos, bottomCenter, dt)
            end
        end
    else
        for _, e in pairs(botCache) do
            if e.visuals then hideVisuals(e.visuals) end
        end
    end

    -- المركبات
    if Config.Vehicles and Config.ESPEnabled then
        if not vehScanned then
            vehScanned = true
            task.spawn(scanVehicles)
        end
        local mc = LocalPlayer.Character
        local mh = mc and mc:FindFirstChildOfClass("Humanoid")
        local mySeat = mh and mh.SeatPart or nil
        for model, e in pairs(vehicles) do
            if not model.Parent then
                destroyVehicle(e)
                vehicles[model] = nil
                vehicleCount = vehicleCount - 1
            else
                local ok, err = pcall(drawVehicle, e, camPos, dt, mySeat)
                if not ok and not e.errShown then
                    e.errShown = true
                    warn("[UniversalESP][Vehicle] خطأ: " .. tostring(err))
                end
            end
        end
    else
        for _, e in pairs(vehicles) do hideVehicle(e) end
    end

    -- 💎 الغنائم
    Loot.step(camPos, dt)

    -- 🎯 الأيم بوت (آخر شيء حتى يأخذ الأولوية على الكاميرا)
    local okA, errA = pcall(Aim.step, camPos, dt)
    if not okA and not Aim.errShown then
        Aim.errShown = true
        warn("[UniversalESP][Aim] خطأ: " .. tostring(errA))
    end
end)

track(Players.PlayerRemoving:Connect(function(plr)
    local e = entries[plr]
    if e then destroyVisuals(e.visuals) end
    entries[plr] = nil
end))

print("✅ Universal ESP V24 + Aim By " .. AUTHOR_SIGNATURE .. " جاهز")

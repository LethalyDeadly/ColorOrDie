-- =============================================================================
-- ─── MASTER CONFIGURATION (Shared across all chapters) ───────────────────────
-- =============================================================================
local Cfg = {
    ToggleESP         = "F1",
    ToggleWalkthrough = "F2",
    StepBack          = "F3",
    StepForward       = "F4",

    DotEnabled  = true,  DotRadius  = 5,
    NameEnabled = true,  NameSize   = 13,
    NameColor   = Color3.fromRGB(255, 255, 255),
  
    ShowBrushes = true,  ShowBuckets = true,
    ShowTools   = true,  ShowSecrets = true,
    ShowDoors   = true,  ShowMonster = true,

    Debug       = false 
}

local BUCKET_COLOR = {
    ["Blue"]   = Color3.fromRGB(60,  130, 255),
    ["Pink"]   = Color3.fromRGB(255, 105, 180),
    ["Purple"] = Color3.fromRGB(160,  60, 255),
    ["White"]  = Color3.fromRGB(230, 230, 230),
    ["Teal"]   = Color3.fromRGB(0,   200, 200),
    ["Green"]  = Color3.fromRGB(60,  220, 80),
    ["Yellow"] = Color3.fromRGB(255, 220, 0),
    ["Orange"] = Color3.fromRGB(255, 140, 0),
    ["Red"]    = Color3.fromRGB(255,  60, 60),
    ["Black"]  = Color3.fromRGB(60,   60,  60),
}

-- =============================================================================
-- ─── LOCAL GAME ROUTER ───────────────────────────────────────────────────────
-- =============================================================================
local placeId = game.PlaceId

if placeId == 12931609417 then
    do
local Vec2  = Vector2.new
local Vec3  = Vector3.new
local C3    = Color3.fromRGB
local WTS   = WorldToScreen
local floor = math.floor

local VK_MAP = {
    A=0x41, B=0x42, C=0x43, D=0x44, E=0x45, F=0x46, G=0x47, H=0x48, I=0x49, J=0x4A,
    K=0x4B, L=0x4C, M=0x4D, N=0x4E, O=0x4F, P=0x50, Q=0x51, R=0x52, S=0x53, T=0x54,
    U=0x55, V=0x56, W=0x57, X=0x58, Y=0x59, Z=0x5A,
    ["0"]=0x30, ["1"]=0x31, ["2"]=0x32, ["3"]=0x33, ["4"]=0x34,
    ["5"]=0x35, ["6"]=0x36, ["7"]=0x37, ["8"]=0x38, ["9"]=0x39,
    F1=0x70, F2=0x71, F3=0x72, F4=0x73, F5=0x74, F6=0x75, 
    F7=0x76, F8=0x77, F9=0x78, F10=0x79, F11=0x7A, F12=0x7B,
    LEFTBRACKET=0xDB, RIGHTBRACKET=0xDD,
    ["-"] = 0xBD, ["="] = 0xBB, [","] = 0xBC, ["."] = 0xBE, ["/"] = 0xBF,
    ["`"] = 0xC0, [";"] = 0xBA, ["'"] = 0xDE, ["\\"] = 0xDC, 
    ["["] = 0xDB, ["]"] = 0xDD
}

local function validateKeybinds()
    local defaultKeys = { ToggleESP = "J", ToggleWalkthrough = "K", StepBack = "[", StepForward = "]" }
    local invalid = false
    
    local function check(k)
        if type(Cfg[k]) == "string" and not VK_MAP[string.upper(Cfg[k])] then invalid = true end
    end
    
    check("ToggleESP"); check("ToggleWalkthrough"); check("StepBack"); check("StepForward")
    
    if invalid then
        Cfg.ToggleESP = defaultKeys.ToggleESP
        Cfg.ToggleWalkthrough = defaultKeys.ToggleWalkthrough
        Cfg.StepBack = defaultKeys.StepBack
        Cfg.StepForward = defaultKeys.StepForward
        if Cfg.Debug then print("[WT-DEBUG] Invalid keybind | keybinds reset") end
    end
end
validateKeybinds()

local function getVK(keyStr)
    if type(keyStr) == "string" then return VK_MAP[string.upper(keyStr)] or 0 end
    return keyStr
end

-- ─── Core Script Functions ────────────────────────────────────────────────────
local function roundV2(v) return Vec2(floor(v.X + 0.5), floor(v.Y + 0.5)) end

local function getAnchor(model)
    local r = model:FindFirstChild("Root")
    if r and r:IsA("BasePart") then return r end
    local pp = model.PrimaryPart
    if pp then return pp end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

local function getPos(anchor)
    local ok, pos = pcall(function() return anchor.Position end)
    return ok and pos or nil
end

local function newEntry(dotColor, label, labelColor, anchor, zDot, zTxt)
    local d = Drawing.new("Circle")
    d.Filled  = true
    d.Radius  = Cfg.DotRadius
    d.Color   = dotColor
    d.Visible = false
    d.ZIndex  = zDot or 10

    local t = Drawing.new("Text")
    t.Font    = Drawing.Fonts.SystemBold
    t.Size    = Cfg.NameSize
    t.Color   = labelColor or Cfg.NameColor
    t.Outline = true
    t.Center  = true
    t.Text    = label
    t.Visible = false
    t.ZIndex  = zTxt or 11

    return { dot = d, txt = t, anchor = anchor, baseName = label }
end

local function removeEntry(e)
    pcall(function() e.dot:Remove() end)
    pcall(function() e.txt:Remove() end)
end

local Players = game:GetService("Players")

local function renderPool(pool, isCategoryEnabled)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

    for _, e in pairs(pool) do
        if not isCategoryEnabled then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local pos = e.staticPos or getPos(e.anchor)
        if not pos then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local ok, sc, onSc = pcall(WTS, pos)
        if not ok or not onSc or not sc then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local sp = roundV2(sc)
        
        -- Dot rendering logic (handles noDot override)
        if Cfg.DotEnabled and not e.noDot then
            e.dot.Position = sp; e.dot.Visible = true
        else
            e.dot.Visible = false
        end
        
        -- Text rendering logic (handles distance)
        if Cfg.NameEnabled then
            local label = e.baseName
            if e.showDistance and hrp then
                local dist = floor((pos - hrp.Position).Magnitude)
                label = label .. "\n[" .. dist .. "]"
            end
            
            e.txt.Text = label
            -- Shift up slightly less if there's no dot to avoid visual gap
            e.txt.Position = Vec2(sp.X, sp.Y - (e.noDot and 0 or Cfg.DotRadius) - 4) 
            e.txt.Visible = true
        else
            e.txt.Visible = false
        end
    end
end

-- ─── Walkthrough Logic & State Verification ───────────────────────────────────
local function SafeFind(parent, ...)
    local current = parent
    local args = {...}
    for i = 1, #args do
        local name = args[i]
        if not current then return nil end
        local ok, child = pcall(function() return current:FindFirstChild(name) end)
        if ok and child then current = child else return nil end
    end
    return current
end

local function getGameplayParts()
    local correctParts = game.Workspace:FindFirstChild("GameplayParts")
    if correctParts then return correctParts end
    return game.Workspace:FindFirstChild("_GameplayParts")
end

local function isMissingWithFallback(obj, label, isItem)
    if not obj then return true end
    if isItem then return false end

    local parts = obj:IsA("Model") and obj:GetDescendants() or {obj}
    local isStillVisible = false
    
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") then
            local name = p.Name:lower()
            if not name:find("root") and not name:find("touch") and p.Transparency < 1 then
                isStillVisible = true
                break
            end
        end
    end
    
    return not isStillVisible
end

local function isDoorMissing(category, subCategory, name)
    local parts = getGameplayParts()
    if not parts then return false end
    local folder = SafeFind(parts, "Doors", category, subCategory)
    local door = folder and SafeFind(folder, name)
    return isMissingWithFallback(door, name, false)
end

local function isToolMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "Tool", name)
    return isMissingWithFallback(nFound, name, true)
end

local function isBucketMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "PaintBucket", name)
    return isMissingWithFallback(nFound, name, true)
end

local function getBrushCount()
    local lp = Players.LocalPlayer
    if not lp then return 0 end
    local val = 0
    pcall(function()
        local numText = lp.PlayerGui.MainGui.TopMenu.BrushCount.BrushesNumber.Text
        local numStr = string.match(numText, "^(%d+)")
        if numStr then val = tonumber(numStr) end
    end)
    return val or 0
end

local function getTool(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "Tool", name)
end

local function getBucket(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "PaintBucket", name)
end

local function getPaintableDoor(color) return SafeFind(getGameplayParts(), "Doors", "Normal", "Paintable", color) end
local function getUnlockableDoor(tool) return SafeFind(getGameplayParts(), "Doors", "Normal", "Unlockable", tool) end
local function getBuildableDoor(name) return SafeFind(getGameplayParts(), "Doors", "Normal", "Buildable", name) end

local function checkDistanceTo(pos, dist)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local p1 = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
        local p2 = Vector3.new(pos.X, 0, pos.Z)
        if (p1 - p2).Magnitude <= dist then return true end
    end
    return false
end

-- ─── Walkthrough HUD & Pools ──────────────────────────────────────────────────
local wtPool = {}
local seenWt = {}

local hudText = Drawing.new("Text")
hudText.Font = Drawing.Fonts.SystemBold; hudText.Size = 15; hudText.Position = Vec2(30, 30)
hudText.Color = C3(255, 200, 50); hudText.Outline = true; hudText.Visible = false; hudText.ZIndex = 50

local currentStepIndex = 1
local previousStepIndex = 1
local ignoredSteps = {}
local stepCompletedLocally = {}

local function resetLocalSteps() stepCompletedLocally = {} end

local function drawPos(pos, name, color, uniqueSuffix)
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, nil, 30, 31)
        wtPool[poolKey].staticPos = pos
    else
        wtPool[poolKey].staticPos = pos
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function drawTarget(obj, name, color, uniqueSuffix)
    local anchor = getAnchor(obj) or obj 
    if not anchor or not anchor:IsA("BasePart") then return end
    
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, anchor, 30, 31)
    else
        wtPool[poolKey].anchor = anchor
        wtPool[poolKey].staticPos = nil
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function positionStep(stepIndex, pos, name)
    return {
        name = name,
        isComplete = function()
            if stepCompletedLocally[stepIndex] then return true end
            if checkDistanceTo(pos, 5) then
                stepCompletedLocally[stepIndex] = true
                return true
            end
            return false
        end,
        draw = function() drawPos(pos, name, C3(200, 200, 200), tostring(stepIndex)) end
    }
end

local Steps = {
    { name = "Black Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Black") end, draw = function() drawTarget(getPaintableDoor("Black"), "Black Wall", C3(60,60,60)) end },
    { name = "Red Bucket", isComplete = function() return isBucketMissing("Red") end, draw = function() drawTarget(getBucket("Red"), "Red Bucket", C3(255, 60, 60)) end },
    { name = "Red Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Red") end, draw = function() drawTarget(getPaintableDoor("Red"), "Red Wall", C3(255, 60, 60)) end },
    { name = "Screwdriver", isComplete = function() return isToolMissing("ScrewDriver") end, draw = function() drawTarget(getTool("ScrewDriver"), "Screwdriver", C3(200, 200, 200)) end },
    { name = "Vent", isComplete = function() return isDoorMissing("Normal", "Unlockable", "ScrewDriver") end, draw = function() drawTarget(getUnlockableDoor("ScrewDriver"), "Vent", C3(200, 200, 200)) end },
    positionStep(6, Vec3(118.24, 5.19, 37.04), "Door"),
    { name = "Orange Bucket", isComplete = function() return isBucketMissing("Orange") end, draw = function() drawTarget(getBucket("Orange"), "Orange Bucket", C3(255, 140, 0)) end },
    positionStep(8, Vec3(838.13, 71.45, -615.87), "Door"),
    { name = "Orange Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Orange") end, draw = function() drawTarget(getPaintableDoor("Orange"), "Orange Door", C3(255, 140, 0)) end },
    { name = "Yellow Bucket", isComplete = function() return isBucketMissing("Yellow") end, draw = function() drawTarget(getBucket("Yellow"), "Yellow Bucket", C3(255, 220, 0)) end },
    { name = "Yellow Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Yellow") end, draw = function() drawTarget(getPaintableDoor("Yellow"), "Yellow Door", C3(255, 220, 0)) end },
    positionStep(12, Vec3(215.44, 5.14, -83.23), "Door"),
    { name = "Green Bucket", isComplete = function() return isBucketMissing("Green") end, draw = function() drawTarget(getBucket("Green"), "Green Bucket", C3(60, 220, 80)) end },
    positionStep(14, Vec3(685.59, 154.04, 354.78), "Door"),
    { name = "Green Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Green") end, draw = function() drawTarget(getPaintableDoor("Green"), "Green Door", C3(60, 220, 80)) end },
    { name = "Teal Bucket", isComplete = function() return isBucketMissing("Teal") end, draw = function() drawTarget(getBucket("Teal"), "Teal Bucket", C3(0, 200, 200)) end },
    positionStep(17, Vec3(118.24, 5.19, 37.04), "Door"),
    { name = "Teal Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Teal") end, draw = function() drawTarget(getPaintableDoor("Teal"), "Teal Door", C3(0, 200, 200)) end },
    { name = "Puzzle Piece", isComplete = function() return isToolMissing("Puzzle") end, draw = function() drawTarget(getTool("Puzzle"), "Puzzle Piece", C3(200, 200, 200)) end },
    positionStep(20, Vec3(838.13, 71.45, -615.87), "Door"),
    { name = "Puzzle Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Puzzle") end, draw = function() drawTarget(getUnlockableDoor("Puzzle"), "Puzzle Door", C3(200, 200, 200)) end },
    { name = "Blue Bucket", isComplete = function() return isBucketMissing("Blue") end, draw = function() drawTarget(getBucket("Blue"), "Blue Bucket", C3(60, 130, 255)) end },
    { name = "Blue Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Blue") end, draw = function() drawTarget(getPaintableDoor("Blue"), "Blue Wall", C3(60, 130, 255)) end },
    { name = "Saw", isComplete = function() return isToolMissing("Saw") end, draw = function() drawTarget(getTool("Saw"), "Saw", C3(200, 200, 200)) end },
    { name = "Barricade", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Saw") end, draw = function() drawTarget(getUnlockableDoor("Saw"), "Barricade", C3(200, 200, 200)) end },
    { name = "Wood Plank", isComplete = function() return isToolMissing("Plank") end, draw = function() drawTarget(getTool("Plank"), "Wood Plank", C3(200, 200, 200)) end },
    positionStep(27, Vec3(191.44, 5.14, -83.23), "Door"),
    { name = "Purple Bucket", isComplete = function() return isBucketMissing("Purple") end, draw = function() drawTarget(getBucket("Purple"), "Purple Bucket", C3(160, 60, 255)) end },
    positionStep(29, Vec3(867.9, 44.39, -63.77), "Door"),
    { name = "Purple Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Purple") end, draw = function() drawTarget(getPaintableDoor("Purple"), "Purple Door", C3(160, 60, 255)) end },
    { name = "Place Plank & Pick up Hammer", isComplete = function() return isToolMissing("Hammer") end, draw = function() 
            local door = getBuildableDoor("Plank")
            local hammer = getTool("Hammer")
            if door then drawTarget(door, "Place Plank", C3(200, 200, 200)) end
            if hammer then drawTarget(hammer, "Pick up Hammer", C3(200, 200, 200)) end
        end },
    { name = "Weak Wall", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Hammer") end, draw = function() drawTarget(getUnlockableDoor("Hammer"), "Weak Wall", C3(200, 200, 200)) end },
    { name = "Pink Bucket", isComplete = function() return isBucketMissing("Pink") end, draw = function() drawTarget(getBucket("Pink"), "Pink Bucket", C3(255, 105, 180)) end },
    { name = "Pink Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Pink") end, draw = function() drawTarget(getPaintableDoor("Pink"), "Pink Door", C3(255, 105, 180)) end },
    { name = "Key", isComplete = function() return isToolMissing("Key") end, draw = function() drawTarget(getTool("Key"), "Key", C3(200, 200, 200)) end },
    positionStep(36, Vec3(215.44, 5.14, -83.23), "Door"),
    { name = "Locked Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Key") end, draw = function() drawTarget(getUnlockableDoor("Key"), "Locked Door", C3(200, 200, 200)) end },
    { name = "Collect all Paintbrushes", isComplete = function() return getBrushCount() >= 13 end, draw = function()
            local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
            local collectFolder = items and SafeFind(items, "Collectable", "Collectable")
            if collectFolder then
                for i, model in ipairs(collectFolder:GetChildren()) do
                    if model:IsA("Model") then drawTarget(model, "Paintbrush", C3(200,140,60), tostring(i)) end
                end
            end
        end },
    positionStep(39, Vec3(423.55, 5.14, -24.47), "Door"),
    { name = "White Bucket", isComplete = function() return isBucketMissing("White") end, draw = function() drawTarget(getBucket("White"), "White Bucket", C3(230, 230, 230)) end },
    positionStep(41, Vec3(-175.64, -60.25, -85.86), "Door"),
    { name = "White Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "White") end, draw = function() drawTarget(getPaintableDoor("White"), "White Door", C3(230, 230, 230)) end },
    { name = "Endings", isComplete = function() return false end, draw = function()
            local function drawEndingDynamic(folderName, label, color, num)
                local folder = SafeFind(game.Workspace, "GameplayParts", "Teleporters", folderName)
                if folder then
                    local targetPart = nil
                    for _, v in ipairs(folder:GetDescendants()) do
                        if v:IsA("BasePart") then targetPart = v break end
                    end
                    if targetPart then drawTarget(targetPart, label, color, num) end
                end
            end
            
            drawEndingDynamic("EndingA", "Bill Crying", C3(255, 255, 255), "1")
            drawEndingDynamic("EndingB", "Bob Chase", C3(255, 255, 255), "2")
            drawEndingDynamic("EndingC", "Rising Lava", C3(255, 255, 255), "3")
            drawEndingDynamic("EndingD", "Bill Chase", C3(255, 255, 255), "4")
        end }
}

local function DetermineCurrentStep()
    if currentStepIndex > 1 then
        local ok, step1Complete = pcall(Steps[1].isComplete)
        if ok and not step1Complete then
            currentStepIndex = 1
            ignoredSteps = {}
            resetLocalSteps()
            return
        end
    end

    while currentStepIndex <= #Steps do
        local step = Steps[currentStepIndex]
        if not step then break end
        
        if ignoredSteps[currentStepIndex] then
            currentStepIndex = currentStepIndex + 1
        else
            local isCompOk, compVal = pcall(step.isComplete)
            if isCompOk and compVal == true then
                currentStepIndex = currentStepIndex + 1
            else
                break
            end
        end
    end
end

-- ─── Normal ESP Pools & Scanning ──────────────────────────────────────────────
local collectPool = {}
local bucketPool  = {}
local toolPool    = {}
local secretPool  = {}
local doorPool    = {}
local monsterPool = {} 

local normalToolNames = {}

local function scanItems()
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    local gp = getGameplayParts()
    local sM = {}
    local monster = SafeFind(game.Workspace, "GameplayAssets", "Monsters", "Bill")
    
    if monster then
        local anchor = getAnchor(monster)
        if anchor then
            local key = "Monster_Bill"
            sM[key] = true
            if not monsterPool[key] then
                local e = newEntry(C3(255, 60, 60), "BILL", C3(255, 60, 60), anchor, 40, 41)
                e.txt.Size = 25 
                e.noDot = true      
                e.showDistance = true 
                monsterPool[key] = e
            else
                monsterPool[key].anchor = anchor
            end
        end
    end
    for k,e in pairs(monsterPool) do if not sM[k] then removeEntry(e) monsterPool[k]=nil end end

    local seenCollect, seenBucket, seenTool, seenSecret, seenDoor = {}, {}, {}, {}, {}

    if items then
        local collectFolder = SafeFind(items, "Collectable", "Collectable")
        if collectFolder then
            local ok, ch = pcall(function() return collectFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local key = model:GetFullName()
                    seenCollect[key] = true
                    if not collectPool[key] then collectPool[key] = newEntry(C3(200,140,60), "paintbrush", Cfg.NameColor, anchor)
                    else collectPool[key].anchor = anchor end
                end
            end
        end
        
        local bucketFolder = SafeFind(items, "Normal", "PaintBucket")
        if bucketFolder then
            local ok, ch = pcall(function() return bucketFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local bucketName = model.Name
                    local dotCol  = BUCKET_COLOR[bucketName] or C3(200,200,200)
                    local poolKey = model:GetFullName() 
                    seenBucket[poolKey] = true
                    if not bucketPool[poolKey] then bucketPool[poolKey] = newEntry(dotCol, bucketName, dotCol, anchor, 20, 21)
                    else bucketPool[poolKey].anchor = anchor; bucketPool[poolKey].dot.Color = dotCol; bucketPool[poolKey].txt.Color = dotCol; bucketPool[poolKey].baseName = bucketName end
                end
            end
        end

        normalToolNames = {}
        local normalToolFolder = SafeFind(items, "Normal", "Tool")
        if normalToolFolder then
            local ok, ch = pcall(function() return normalToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local toolName = model.Name
                    normalToolNames[toolName] = true
                    local poolKey = model:GetFullName()
                    seenTool[poolKey] = true
                    if not toolPool[poolKey] then toolPool[poolKey] = newEntry(C3(180,180,180), toolName, Cfg.NameColor, anchor)
                    else toolPool[poolKey].anchor = anchor; toolPool[poolKey].baseName = toolName end
                end
            end
        end

        local secretToolFolder = SafeFind(items, "Secret", "Tool")
        if secretToolFolder then
            local ok, ch = pcall(function() return secretToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local toolName = model.Name
                    if normalToolNames[toolName] then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local poolKey = model:GetFullName()
                    seenSecret[poolKey] = true
                    if not secretPool[poolKey] then secretPool[poolKey] = newEntry(C3(255,200,50), toolName.." (2)", C3(255,200,50), anchor)
                    else secretPool[poolKey].anchor = anchor; secretPool[poolKey].baseName = toolName.." (2)" end
                end
            end
        end
    end

    local function addDoorToPool(model, suffix)
        local anchor = getAnchor(model)
        if not anchor then return end
        local key = model.Name
        local doorName = key .. suffix
        if key == "ScrewDriver" then doorName = "Vent"
        elseif key == "Saw" then doorName = "Barricade"
        elseif key == "Hammer" then doorName = "Breakable Wall" end
        local dotCol = BUCKET_COLOR[key] or C3(200, 200, 200)
        local poolKey = model:GetFullName()
        
        seenDoor[poolKey] = true
        if not doorPool[poolKey] then doorPool[poolKey] = newEntry(dotCol, doorName, dotCol, anchor, 15, 16)
        else doorPool[poolKey].anchor = anchor; doorPool[poolKey].dot.Color = dotCol; doorPool[poolKey].txt.Color = dotCol; doorPool[poolKey].baseName = doorName end
    end

    local paintableDoors = gp and SafeFind(gp, "Doors", "Normal", "Paintable")
    if paintableDoors then
        local ok, ch = pcall(function() return paintableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Wall") end end end
    end

    local unlockableDoors = gp and SafeFind(gp, "Doors", "Normal", "Unlockable")
    if unlockableDoors then
        local ok, ch = pcall(function() return unlockableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Door") end end end
    end

    local buildableDoors = gp and SafeFind(gp, "Doors", "Normal", "Buildable")
    if buildableDoors then
        local ok, ch = pcall(function() return buildableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Buildable") end end end
    end

    for key, e in pairs(collectPool) do if not seenCollect[key] then removeEntry(e); collectPool[key] = nil end end
    for key, e in pairs(bucketPool)  do if not seenBucket[key]  then removeEntry(e); bucketPool[key]  = nil end end
    for key, e in pairs(toolPool)    do if not seenTool[key]    then removeEntry(e); toolPool[key]    = nil end end
    for key, e in pairs(secretPool)  do if not seenSecret[key]  then removeEntry(e); secretPool[key]  = nil end end
    for key, e in pairs(doorPool)    do if not seenDoor[key]    then removeEntry(e); doorPool[key]    = nil end end
end

-- ─── Input & Main Loops ───────────────────────────────────────────────────────
local espEnabled = false
local wtEnabled  = false

local keyWasDown = { ToggleESP = false, ToggleWT = false, StepBack = false, StepForward = false }

local function pollKeybinds()
    local ok, down = pcall(iskeypressed, getVK(Cfg.ToggleESP))
    if ok then
        if down and not keyWasDown.ToggleESP then
            espEnabled = not espEnabled
            if espEnabled then wtEnabled = false end
        end
        keyWasDown.ToggleESP = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.ToggleWalkthrough))
    if ok then
        if down and not keyWasDown.ToggleWT then
            wtEnabled = not wtEnabled
            if wtEnabled then espEnabled = false end
        end
        keyWasDown.ToggleWT = down
    end
    
    ok, down = pcall(iskeypressed, getVK(Cfg.StepForward))
    if ok then
        if down and not keyWasDown.StepForward then
            if wtEnabled and currentStepIndex < #Steps then
                ignoredSteps[currentStepIndex] = true
            end
        end
        keyWasDown.StepForward = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.StepBack))
    if ok then
        if down and not keyWasDown.StepBack then
            if wtEnabled and currentStepIndex > 1 then
                local prev = currentStepIndex - 1
                currentStepIndex = prev          -- Explicitly change the current step tracker back
                ignoredSteps[prev] = false       -- Ensure it's not marked as skipped
                stepCompletedLocally[prev] = nil -- Clear positional cache so it doesn't instantly auto-complete
            end
        end
        keyWasDown.StepBack = down
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(scanItems)
    end
end)

task.spawn(function()
    while true do
        task.wait(0)
        pcall(function()
            pollKeybinds()
            
            renderPool(monsterPool, Cfg.ShowMonster)

            if espEnabled then
                renderPool(collectPool, Cfg.ShowBrushes)
                renderPool(bucketPool,  Cfg.ShowBuckets)
                renderPool(toolPool,    Cfg.ShowTools)
                renderPool(secretPool,  Cfg.ShowSecrets)
                renderPool(doorPool,    Cfg.ShowDoors)
            else
                renderPool(collectPool, false)
                renderPool(bucketPool,  false)
                renderPool(toolPool,    false)
                renderPool(secretPool,  false)
                renderPool(doorPool,    false)
            end

            if wtEnabled then
                seenWt = {}
                DetermineCurrentStep()
                local step = Steps[currentStepIndex]

                if currentStepIndex ~= previousStepIndex then
                    previousStepIndex = currentStepIndex
                end

                if step then
                    hudText.Visible = true
                    hudText.Text = string.format("Walkthrough Step: %d/%d - %s", currentStepIndex, #Steps, step.name)
                    pcall(step.draw)
                else
                    hudText.Visible = true
                    hudText.Text = "Walkthrough: Done!"
                end

                for k, e in pairs(wtPool) do
                    if not seenWt[k] then
                        removeEntry(e)
                        wtPool[k] = nil
                    end
                end
                
                renderPool(wtPool, true)
            else
                hudText.Visible = false
                renderPool(wtPool, false)
            end
        end)
    end
end)

task.spawn(function()
    task.wait(2)
    notify("Keybinds", "Press " .. Cfg.ToggleESP .. " to enable normal esp", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.ToggleWalkthrough .. " to enable walkthrough", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.StepBack .. " and " .. Cfg.StepForward .. " to cycle through steps", 10)
end)
    end

elseif placeId == 13429735204 then
    do
local Vec2  = Vector2.new
local Vec3  = Vector3.new
local C3    = Color3.fromRGB
local WTS   = WorldToScreen
local floor = math.floor

local VK_MAP = {
    A=0x41, B=0x42, C=0x43, D=0x44, E=0x45, F=0x46, G=0x47, H=0x48, I=0x49, J=0x4A,
    K=0x4B, L=0x4C, M=0x4D, N=0x4E, O=0x4F, P=0x50, Q=0x51, R=0x52, S=0x53, T=0x54,
    U=0x55, V=0x56, W=0x57, X=0x58, Y=0x59, Z=0x5A,
    ["0"]=0x30, ["1"]=0x31, ["2"]=0x32, ["3"]=0x33, ["4"]=0x34,
    ["5"]=0x35, ["6"]=0x36, ["7"]=0x37, ["8"]=0x38, ["9"]=0x39,
    F1=0x70, F2=0x71, F3=0x72, F4=0x73, F5=0x74, F6=0x75, 
    F7=0x76, F8=0x77, F9=0x78, F10=0x79, F11=0x7A, F12=0x7B,
    LEFTBRACKET=0xDB, RIGHTBRACKET=0xDD,
    ["-"] = 0xBD, ["="] = 0xBB, [","] = 0xBC, ["."] = 0xBE, ["/"] = 0xBF,
    ["`"] = 0xC0, [";"] = 0xBA, ["'"] = 0xDE, ["\\"] = 0xDC, 
    ["["] = 0xDB, ["]"] = 0xDD
}

local function validateKeybinds()
    local defaultKeys = { ToggleESP = "J", ToggleWalkthrough = "K", StepBack = "[", StepForward = "]" }
    local invalid = false
    
    local function check(k)
        if type(Cfg[k]) == "string" and not VK_MAP[string.upper(Cfg[k])] then invalid = true end
    end
    
    check("ToggleESP"); check("ToggleWalkthrough"); check("StepBack"); check("StepForward")
    
    if invalid then
        Cfg.ToggleESP = defaultKeys.ToggleESP
        Cfg.ToggleWalkthrough = defaultKeys.ToggleWalkthrough
        Cfg.StepBack = defaultKeys.StepBack
        Cfg.StepForward = defaultKeys.StepForward
        if Cfg.Debug then print("[WT-DEBUG] Invalid keybind | keybinds reset") end
    end
end
validateKeybinds()

local function getVK(keyStr)
    if type(keyStr) == "string" then return VK_MAP[string.upper(keyStr)] or 0 end
    return keyStr
end

-- ─── Core Script Functions ────────────────────────────────────────────────────
local function roundV2(v) return Vec2(floor(v.X + 0.5), floor(v.Y + 0.5)) end

local function getAnchor(model)
    local r = model:FindFirstChild("Root")
    if r and r:IsA("BasePart") then return r end
    local pp = model.PrimaryPart
    if pp then return pp end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

local function getPos(anchor)
    local ok, pos = pcall(function() return anchor.Position end)
    return ok and pos or nil
end

local function newEntry(dotColor, label, labelColor, anchor, zDot, zTxt)
    local d = Drawing.new("Circle")
    d.Filled  = true
    d.Radius  = Cfg.DotRadius
    d.Color   = dotColor
    d.Visible = false
    d.ZIndex  = zDot or 10

    local t = Drawing.new("Text")
    t.Font    = Drawing.Fonts.SystemBold -- Inherently a thick/bold font
    t.Size    = Cfg.NameSize
    t.Color   = labelColor or Cfg.NameColor
    t.Outline = true
    t.Center  = true
    t.Text    = label
    t.Visible = false
    t.ZIndex  = zTxt or 11

    return { dot = d, txt = t, anchor = anchor, baseName = label }
end

local function removeEntry(e)
    pcall(function() e.dot:Remove() end)
    pcall(function() e.txt:Remove() end)
end

local Players = game:GetService("Players")

local function renderPool(pool, isCategoryEnabled)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

    for _, e in pairs(pool) do
        if not isCategoryEnabled then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local pos = e.staticPos or getPos(e.anchor)
        if not pos then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local ok, sc, onSc = pcall(WTS, pos)
        if not ok or not onSc or not sc then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local sp = roundV2(sc)
        
        -- Dot rendering logic (handles noDot override)
        if Cfg.DotEnabled and not e.noDot then
            e.dot.Position = sp; e.dot.Visible = true
        else
            e.dot.Visible = false
        end
        
        -- Text rendering logic (handles distance)
        if Cfg.NameEnabled then
            local label = e.baseName
            if e.showDistance and hrp then
                local dist = floor((pos - hrp.Position).Magnitude)
                label = label .. "\n[" .. dist .. "]"
            end
            
            e.txt.Text = label
            -- Shift up slightly less if there's no dot to avoid visual gap
            e.txt.Position = Vec2(sp.X, sp.Y - (e.noDot and 0 or Cfg.DotRadius) - 4) 
            e.txt.Visible = true
        else
            e.txt.Visible = false
        end
    end
end

-- ─── Walkthrough Logic & State Verification ───────────────────────────────────
local function SafeFind(parent, ...)
    local current = parent
    local args = {...}
    for i = 1, #args do
        local name = args[i]
        if not current then return nil end
        local ok, child = pcall(function() return current:FindFirstChild(name) end)
        if ok and child then current = child else return nil end
    end
    return current
end

local function getGameplayParts()
    local correctParts = game.Workspace:FindFirstChild("GameplayParts")
    if correctParts then return correctParts end
    return game.Workspace:FindFirstChild("_GameplayParts")
end

local function isMissingWithFallback(obj, label, isItem)
    if not obj then return true end
    if isItem then return false end

    local parts = obj:IsA("Model") and obj:GetDescendants() or {obj}
    local isStillVisible = false
    
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") then
            local name = p.Name:lower()
            if not name:find("root") and not name:find("touch") and p.Transparency < 1 then
                isStillVisible = true
                break
            end
        end
    end
    
    return not isStillVisible
end

local function isDoorMissing(category, subCategory, name)
    local parts = getGameplayParts()
    if not parts then return false end
    local folder = SafeFind(parts, "Doors", category, subCategory)
    local door = folder and SafeFind(folder, name)
    return isMissingWithFallback(door, name, false)
end

local function isToolMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "Tool", name)
    return isMissingWithFallback(nFound, name, true)
end

local function isBucketMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "PaintBucket", name)
    return isMissingWithFallback(nFound, name, true)
end

local function getBrushCount()
    local lp = Players.LocalPlayer
    if not lp then return 0 end
    local val = 0
    pcall(function()
        local numText = lp.PlayerGui.MainGui.TopMenu.BrushCount.BrushesNumber.Text
        local numStr = string.match(numText, "^(%d+)")
        if numStr then val = tonumber(numStr) end
    end)
    return val or 0
end

local function getTool(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "Tool", name)
end

local function getBucket(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "PaintBucket", name)
end

local function getPaintableDoor(color) return SafeFind(getGameplayParts(), "Doors", "Normal", "Paintable", color) end
local function getUnlockableDoor(tool) return SafeFind(getGameplayParts(), "Doors", "Normal", "Unlockable", tool) end
local function getBuildableDoor(name) return SafeFind(getGameplayParts(), "Doors", "Normal", "Buildable", name) end

local function checkDistanceTo(pos, dist)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local p1 = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
        local p2 = Vector3.new(pos.X, 0, pos.Z)
        if (p1 - p2).Magnitude <= dist then return true end
    end
    return false
end

-- ─── Walkthrough HUD & Pools ──────────────────────────────────────────────────
local wtPool = {}
local seenWt = {}

local hudText = Drawing.new("Text")
hudText.Font = Drawing.Fonts.SystemBold; hudText.Size = 15; hudText.Position = Vec2(30, 30)
hudText.Color = C3(255, 200, 50); hudText.Outline = true; hudText.Visible = false; hudText.ZIndex = 50

local currentStepIndex = 1
local previousStepIndex = 1
local ignoredSteps = {}
local stepCompletedLocally = {}

local function resetLocalSteps() stepCompletedLocally = {} end

local function drawPos(pos, name, color, uniqueSuffix)
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, nil, 30, 31)
        wtPool[poolKey].staticPos = pos
    else
        wtPool[poolKey].staticPos = pos
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function drawTarget(obj, name, color, uniqueSuffix)
    local anchor = getAnchor(obj) or obj 
    if not anchor or not anchor:IsA("BasePart") then return end
    
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, anchor, 30, 31)
    else
        wtPool[poolKey].anchor = anchor
        wtPool[poolKey].staticPos = nil
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function positionStep(stepIndex, pos, name)
    return {
        name = name,
        isComplete = function()
            if stepCompletedLocally[stepIndex] then return true end
            if checkDistanceTo(pos, 5) then
                stepCompletedLocally[stepIndex] = true
                return true
            end
            return false
        end,
        draw = function() drawPos(pos, name, C3(200, 200, 200), tostring(stepIndex)) end
    }
end

local Steps = {
    { name = "Black Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Black") end, draw = function() drawTarget(getPaintableDoor("Black"), "Black Wall", C3(60,60,60)) end },
    { name = "Red Bucket", isComplete = function() return isBucketMissing("Red") end, draw = function() drawTarget(getBucket("Red"), "Red Bucket", C3(255, 60, 60)) end },
    { name = "Red Door", isComplete = function() return isDoorMissing("Normal", "Paintable", "Red") end, draw = function() drawTarget(getPaintableDoor("Red"), "Red Door", C3(255, 60, 60)) end },
    { name = "Screwdriver", isComplete = function() return isToolMissing("ScrewDriver") end, draw = function() drawTarget(getTool("ScrewDriver"), "Screwdriver", C3(200, 200, 200)) end },
    { name = "Vent", isComplete = function() return isDoorMissing("Normal", "Unlockable", "ScrewDriver") end, draw = function() drawTarget(getUnlockableDoor("ScrewDriver"), "Vent", C3(200, 200, 200)) end },
    { name = "Orange Bucket", isComplete = function() return isBucketMissing("Orange") end, draw = function() drawTarget(getBucket("Orange"), "Orange Bucket", C3(255, 140, 0)) end },
    { name = "Orange Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Orange") end, draw = function() drawTarget(getPaintableDoor("Orange"), "Orange Wall", C3(255, 140, 0)) end },
    { name = "Yellow Bucket", isComplete = function() return isBucketMissing("Yellow") end, draw = function() drawTarget(getBucket("Yellow"), "Yellow Bucket", C3(255, 220, 0)) end },
    { name = "Yellow Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Yellow") end, draw = function() drawTarget(getPaintableDoor("Yellow"), "Yellow Wall", C3(255, 220, 0)) end },
    { name = "Dynamite", isComplete = function() return isToolMissing("Dynamite") end, draw = function() drawTarget(getTool("Dynamite"), "Dynamite", C3(200, 200, 200)) end },
    { name = "Dynamite Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Dynamite") end, draw = function() drawTarget(getUnlockableDoor("Dynamite"), "Dynamite Door", C3(200, 200, 200)) end },
    positionStep(12, Vec3(339.2, 6.03, -403.32), "Door"),
    { name = "Green Bucket", isComplete = function() return isBucketMissing("Green") end, draw = function() drawTarget(getBucket("Green"), "Green Bucket", C3(60, 220, 80)) end },
    positionStep(14, Vec3(-810.18, 83.63, -858.87), "Door"),
    { name = "Green Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Green") end, draw = function() drawTarget(getPaintableDoor("Green"), "Green Wall", C3(60, 220, 80)) end },
    { name = "Pickaxe", isComplete = function() return isToolMissing("Pickaxe") end, draw = function() drawTarget(getTool("Pickaxe"), "Pickaxe", C3(200, 200, 200)) end },
    { name = "Pickaxe Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Pickaxe") end, draw = function() drawTarget(getUnlockableDoor("Pickaxe"), "Pickaxe Door", C3(200, 200, 200)) end },
    positionStep(18, Vec3(215.2, -19.47, -592.82), "Door"),
    { name = "Teal Bucket", isComplete = function() return isBucketMissing("Teal") end, draw = function() drawTarget(getBucket("Teal"), "Teal Bucket", C3(0, 200, 200)) end },
    positionStep(20, Vec3(-1205.27, 56.35, -1166.74), "Door"),
    positionStep(21, Vec3(339.2, 6.03, -403.32), "Door"),
    { name = "Teal Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Teal") end, draw = function() drawTarget(getPaintableDoor("Teal"), "Teal Wall", C3(0, 200, 200)) end },
    { name = "Blue Bucket", isComplete = function() return isBucketMissing("Blue") end, draw = function() drawTarget(getBucket("Blue"), "Blue Bucket", C3(60, 130, 255)) end },
    positionStep(24, Vec3(-810.18, 83.63, -858.87), "Door"),
    { name = "Blue Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Blue") end, draw = function() drawTarget(getPaintableDoor("Blue"), "Blue Wall", C3(60, 130, 255)) end },
    { name = "Torch", isComplete = function() return isToolMissing("Torch") end, draw = function() drawTarget(getTool("Torch"), "Torch", C3(200, 200, 200)) end },
    { name = "Torch Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Torch") end, draw = function() drawTarget(getUnlockableDoor("Torch"), "Torch Door", C3(200, 200, 200)) end },
    { name = "Purple Bucket", isComplete = function() return isBucketMissing("Purple") end, draw = function() drawTarget(getBucket("Purple"), "Purple Bucket", C3(160, 60, 255)) end },
    { name = "Purple Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Purple") end, draw = function() drawTarget(getPaintableDoor("Purple"), "Purple Wall", C3(160, 60, 255)) end },
    { name = "Card", isComplete = function() return isToolMissing("Card") end, draw = function() drawTarget(getTool("Card"), "Card", C3(200, 200, 200)) end },
    { name = "Card Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Card") end, draw = function() drawTarget(getUnlockableDoor("Card"), "Card Door", C3(200, 200, 200)) end },
    positionStep(32, Vec3(133.2, 6.03, -533.82), "Door"),
    { name = "Crowbar", isComplete = function() return isToolMissing("Crowbar") end, draw = function() drawTarget(getTool("Crowbar"), "Crowbar", C3(200, 200, 200)) end },
    positionStep(34, Vec3(-1205.37, 117.54, -589.4), "Door"),
    { name = "Crowbar Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Crowbar") end, draw = function() drawTarget(getUnlockableDoor("Crowbar"), "Crowbar Door", C3(200, 200, 200)) end },
    { name = "Pink Bucket", isComplete = function() return isBucketMissing("Pink") end, draw = function() drawTarget(getBucket("Pink"), "Pink Bucket", C3(255, 105, 180)) end },
    { name = "Pink Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Pink") end, draw = function() drawTarget(getPaintableDoor("Pink"), "Pink Wall", C3(255, 105, 180)) end },
    { name = "Key", isComplete = function() return isToolMissing("Key") end, draw = function() drawTarget(getTool("Key"), "Key", C3(200, 200, 200)) end },
    { name = "Key Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Key") end, draw = function() drawTarget(getUnlockableDoor("Key"), "Key Door", C3(200, 200, 200)) end },
    { name = "Collect all Paintbrushes", isComplete = function() return getBrushCount() >= 13 end, draw = function()
            local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
            local collectFolder = items and SafeFind(items, "Collectable", "Collectable")
            if collectFolder then
                for i, model in ipairs(collectFolder:GetChildren()) do
                    if model:IsA("Model") then drawTarget(model, "Paintbrush", C3(200,140,60), tostring(i)) end
                end
            end
        end },
    positionStep(41, Vec3(433.05, 5.58, -564.67), "Door"),
    { name = "White Bucket", isComplete = function() return isBucketMissing("White") end, draw = function() drawTarget(getBucket("White"), "White Bucket", C3(230, 230, 230)) end },
    positionStep(43, Vec3(129.3, 43.83, -2255.47), "Door"),
    { name = "White Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "White") end, draw = function() drawTarget(getPaintableDoor("White"), "White Wall", C3(230, 230, 230)) end },
    { name = "Endings", isComplete = function() return false end, draw = function()
            local function drawEndingDynamic(folderName, label, color, num)
                local gp = getGameplayParts()
                local folder = gp and SafeFind(gp, "Teleporters", folderName)
                if folder then
                    local targetPart = nil
                    for _, v in ipairs(folder:GetDescendants()) do
                        if v:IsA("BasePart") then targetPart = v break end
                    end
                    if targetPart then drawTarget(targetPart, label, color, num) end
                end
            end
            
            drawEndingDynamic("EndingA", "Dropper", C3(255, 255, 255), "1")
            drawEndingDynamic("EndingB", "Obby", C3(255, 255, 255), "2")
            drawEndingDynamic("EndingC", "Paint Buckets", C3(255, 255, 255), "3")
            drawEndingDynamic("EndingD", "Light Bulb", C3(255, 255, 255), "4")
        end }
}

local function DetermineCurrentStep()
    if currentStepIndex > 1 then
        local ok, step1Complete = pcall(Steps[1].isComplete)
        if ok and not step1Complete then
            currentStepIndex = 1
            ignoredSteps = {}
            resetLocalSteps()
            return
        end
    end

    while currentStepIndex <= #Steps do
        local step = Steps[currentStepIndex]
        if not step then break end
        
        if ignoredSteps[currentStepIndex] then
            currentStepIndex = currentStepIndex + 1
        else
            local isCompOk, compVal = pcall(step.isComplete)
            if isCompOk and compVal == true then
                currentStepIndex = currentStepIndex + 1
            else
                break
            end
        end
    end
end

-- ─── Normal ESP Pools & Scanning ──────────────────────────────────────────────
local collectPool = {}
local bucketPool  = {}
local toolPool    = {}
local secretPool  = {}
local doorPool    = {}
local monsterPool = {} 
local plugPool    = {}

local normalToolNames = {}

local function scanItems()
    local gp = getGameplayParts()
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    
    -- Monster ESP Scanner
    local sM = {}
    local monstersFolder = SafeFind(game.Workspace, "GameplayAssets", "Monsters")
    
    if monstersFolder then
        -- BigBob ESP
        local bigBob = SafeFind(monstersFolder, "BigBob")
        if bigBob then
            local anchor = getAnchor(bigBob)
            if anchor then
                local key = "Monster_BigBob"
                sM[key] = true
                if not monsterPool[key] then
                    local e = newEntry(C3(255, 60, 60), "BOB", C3(255, 60, 60), anchor, 40, 41)
                    e.txt.Size = 25 
                    e.noDot = true 
                    e.showDistance = true 
                    monsterPool[key] = e
                else
                    monsterPool[key].anchor = anchor
                end
            end
        end
        
        -- Ross ESP
        local ross = SafeFind(monstersFolder, "Ross")
        if ross then
            local anchor = getAnchor(ross)
            if anchor then
                local key = "Monster_Ross"
                sM[key] = true
                if not monsterPool[key] then
                    local e = newEntry(C3(255, 100, 100), "ROSS", C3(255, 100, 100), anchor, 40, 41)
                    e.txt.Size = 18 
                    e.noDot = true
                    e.showDistance = true
                    monsterPool[key] = e
                else
                    monsterPool[key].anchor = anchor
                end
            end
        end
    end
    for k,e in pairs(monsterPool) do if not sM[k] then removeEntry(e) monsterPool[k]=nil end end

    -- Plugs ESP Scanner (For transparency == 1)
    local seenPlug = {}
    local buttonsFolder = gp and SafeFind(gp, "ActivatedDoors", "DoorA", "Buttons")
    if buttonsFolder then
        local ok, ch = pcall(function() return buttonsFolder:GetChildren() end)
        if ok and ch then
            for _, btn in ipairs(ch) do
                -- Find the 'Visual' part (handles "5Visual" literal typo or standard "Visual" child)
                local visual
                if btn.Name:match("Visual$") then 
                    visual = btn 
                else
                    visual = SafeFind(btn, "Visual")
                end
                
                -- Only draw ESP if the transparency is 1 (meaning it needs to be clicked/plugged)
                if visual and visual:IsA("BasePart") and visual.Transparency >= 0.99 then
                    local key = "Plug_" .. btn.Name
                    seenPlug[key] = true
                    if not plugPool[key] then
                        local e = newEntry(C3(200, 200, 255), "plug", C3(200, 200, 255), visual, 35, 36)
                        e.showDistance = true
                        plugPool[key] = e
                    else
                        plugPool[key].anchor = visual
                    end
                end
            end
        end
    end
    for k, e in pairs(plugPool) do if not seenPlug[k] then removeEntry(e); plugPool[k] = nil end end

    local seenCollect, seenBucket, seenTool, seenSecret, seenDoor = {}, {}, {}, {}, {}

    if items then
        local collectFolder = SafeFind(items, "Collectable", "Collectable")
        if collectFolder then
            local ok, ch = pcall(function() return collectFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local key = model:GetFullName()
                    seenCollect[key] = true
                    if not collectPool[key] then collectPool[key] = newEntry(C3(200,140,60), "paintbrush", Cfg.NameColor, anchor)
                    else collectPool[key].anchor = anchor end
                end
            end
        end
        
        local bucketFolder = SafeFind(items, "Normal", "PaintBucket")
        if bucketFolder then
            local ok, ch = pcall(function() return bucketFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local bucketName = model.Name
                    local dotCol  = BUCKET_COLOR[bucketName] or C3(200,200,200)
                    local poolKey = model:GetFullName() 
                    seenBucket[poolKey] = true
                    if not bucketPool[poolKey] then bucketPool[poolKey] = newEntry(dotCol, bucketName, dotCol, anchor, 20, 21)
                    else bucketPool[poolKey].anchor = anchor; bucketPool[poolKey].dot.Color = dotCol; bucketPool[poolKey].txt.Color = dotCol; bucketPool[poolKey].baseName = bucketName end
                end
            end
        end

        normalToolNames = {}
        local normalToolFolder = SafeFind(items, "Normal", "Tool")
        if normalToolFolder then
            local ok, ch = pcall(function() return normalToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local toolName = model.Name
                    normalToolNames[toolName] = true
                    local poolKey = model:GetFullName()
                    seenTool[poolKey] = true
                    if not toolPool[poolKey] then toolPool[poolKey] = newEntry(C3(180,180,180), toolName, Cfg.NameColor, anchor)
                    else toolPool[poolKey].anchor = anchor; toolPool[poolKey].baseName = toolName end
                end
            end
        end

        local secretToolFolder = SafeFind(items, "Secret", "Tool")
        if secretToolFolder then
            local ok, ch = pcall(function() return secretToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local toolName = model.Name
                    if normalToolNames[toolName] then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local poolKey = model:GetFullName()
                    seenSecret[poolKey] = true
                    if not secretPool[poolKey] then secretPool[poolKey] = newEntry(C3(255,200,50), toolName.." (2)", C3(255,200,50), anchor)
                    else secretPool[poolKey].anchor = anchor; secretPool[poolKey].baseName = toolName.." (2)" end
                end
            end
        end
    end

    local function addDoorToPool(model, suffix)
        local anchor = getAnchor(model)
        if not anchor then return end
        local key = model.Name
        local doorName = key .. suffix
 
        if key == "ScrewDriver" then doorName = "Vent"
        elseif key == "Saw" then doorName = "Barricade"
        elseif key == "Hammer" then doorName = "Breakable Wall" end
        local dotCol = BUCKET_COLOR[key] or C3(200, 200, 200)
        local poolKey = model:GetFullName()
        
        seenDoor[poolKey] = true
        if not doorPool[poolKey] then doorPool[poolKey] = newEntry(dotCol, doorName, dotCol, anchor, 15, 16)
        else doorPool[poolKey].anchor = anchor; doorPool[poolKey].dot.Color = dotCol; doorPool[poolKey].txt.Color = dotCol; doorPool[poolKey].baseName = doorName end
    end

    local paintableDoors = gp and SafeFind(gp, "Doors", "Normal", "Paintable")
    if paintableDoors then
        local ok, ch = pcall(function() return paintableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Wall") end end end
    end

    local unlockableDoors = gp and SafeFind(gp, "Doors", "Normal", "Unlockable")
    if unlockableDoors then
        local ok, ch = pcall(function() return unlockableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Door") end end end
    end

    local buildableDoors = gp and SafeFind(gp, "Doors", "Normal", "Buildable")
    if buildableDoors then
        local ok, ch = pcall(function() return buildableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Buildable") end end end
    end

    for key, e in pairs(collectPool) do if not seenCollect[key] then removeEntry(e); collectPool[key] = nil end end
    for key, e in pairs(bucketPool)  do if not seenBucket[key]  then removeEntry(e); bucketPool[key]  = nil end end
    for key, e in pairs(toolPool)    do if not seenTool[key]    then removeEntry(e); toolPool[key]    = nil end end
    for key, e in pairs(secretPool)  do if not seenSecret[key]  then removeEntry(e); secretPool[key]  = nil end end
    for key, e in pairs(doorPool)    do if not seenDoor[key]    then removeEntry(e); doorPool[key]    = nil end end
end

-- ─── Input & Main Loops ───────────────────────────────────────────────────────
local espEnabled = false
local wtEnabled  = false

local keyWasDown = { ToggleESP = false, ToggleWT = false, StepBack = false, StepForward = false }

local function pollKeybinds()
    local ok, down = pcall(iskeypressed, getVK(Cfg.ToggleESP))
    if ok then
        if down and not keyWasDown.ToggleESP then
            espEnabled = not espEnabled
            if espEnabled then wtEnabled = false end
        end
        keyWasDown.ToggleESP = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.ToggleWalkthrough))
    if ok then
        if down and not keyWasDown.ToggleWT then
            wtEnabled = not wtEnabled
            if wtEnabled then espEnabled = false end
        end
        keyWasDown.ToggleWT = down
    end
    
    ok, down = pcall(iskeypressed, getVK(Cfg.StepForward))
    if ok then
        if down and not keyWasDown.StepForward then
            if wtEnabled and currentStepIndex < #Steps then
                ignoredSteps[currentStepIndex] = true
            end
        end
        keyWasDown.StepForward = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.StepBack))
    if ok then
        if down and not keyWasDown.StepBack then
            if wtEnabled and currentStepIndex > 1 then
                local prev = currentStepIndex - 1
                currentStepIndex = prev    
                -- Explicitly change the current step tracker back
                ignoredSteps[prev] = false       -- Ensure it's not marked as skipped
                stepCompletedLocally[prev] = nil -- Clear positional cache so it doesn't instantly auto-complete
            end
        end
        keyWasDown.StepBack = down
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(scanItems)
    end
end)

task.spawn(function()
    while true do
        task.wait(0)
        pcall(function()
            pollKeybinds()
            
            renderPool(monsterPool, Cfg.ShowMonster)
            
            -- Plugs are rendered whether you use Normal ESP or Walkthrough mode
            if espEnabled or wtEnabled then
                renderPool(plugPool, true)
            else
                renderPool(plugPool, false)
            end

            if espEnabled then
                renderPool(collectPool, Cfg.ShowBrushes)
                renderPool(bucketPool,  Cfg.ShowBuckets)
                renderPool(toolPool,    Cfg.ShowTools)
                renderPool(secretPool,  Cfg.ShowSecrets)
                renderPool(doorPool,    Cfg.ShowDoors)
            else
                renderPool(collectPool, false)
                renderPool(bucketPool,  false)
                renderPool(toolPool,    false)
                renderPool(secretPool,  false)
                renderPool(doorPool,    false)
            end

            if wtEnabled then
                seenWt = {}
                DetermineCurrentStep()
                local step = Steps[currentStepIndex]

                if currentStepIndex ~= previousStepIndex then
                    previousStepIndex = currentStepIndex
                end

                if step then
                    hudText.Visible = true
                    hudText.Text = string.format("Walkthrough Step: %d/%d - %s", currentStepIndex, #Steps, step.name)
                    pcall(step.draw)
                else
                    hudText.Visible = true
                    hudText.Text = "Walkthrough: Done!"
                end

                for k, e in pairs(wtPool) do
                    if not seenWt[k] then
                        removeEntry(e)
                        wtPool[k] = nil
                    end
                end
                
                renderPool(wtPool, true)
            else
                hudText.Visible = false
                renderPool(wtPool, false)
            end
        end)
    end
end)

task.spawn(function()
    task.wait(2)
    notify("Keybinds", "Press " .. Cfg.ToggleESP .. " to enable normal esp", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.ToggleWalkthrough .. " to enable walkthrough", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.StepBack .. " and " .. Cfg.StepForward .. " to cycle through steps", 10)
end)
    end

elseif placeId == 13622138404 then
    do
local Vec2  = Vector2.new
local Vec3  = Vector3.new
local C3    = Color3.fromRGB
local WTS   = WorldToScreen
local floor = math.floor

local VK_MAP = {
    A=0x41, B=0x42, C=0x43, D=0x44, E=0x45, F=0x46, G=0x47, H=0x48, I=0x49, J=0x4A,
    K=0x4B, L=0x4C, M=0x4D, N=0x4E, O=0x4F, P=0x50, Q=0x51, R=0x52, S=0x53, T=0x54,
    U=0x55, V=0x56, W=0x57, X=0x58, Y=0x59, Z=0x5A,
    ["0"]=0x30, ["1"]=0x31, ["2"]=0x32, ["3"]=0x33, ["4"]=0x34,
    ["5"]=0x35, ["6"]=0x36, ["7"]=0x37, ["8"]=0x38, ["9"]=0x39,
    F1=0x70, F2=0x71, F3=0x72, F4=0x73, F5=0x74, F6=0x75, 
    F7=0x76, F8=0x77, F9=0x78, F10=0x79, F11=0x7A, F12=0x7B,
    LEFTBRACKET=0xDB, RIGHTBRACKET=0xDD,
    ["-"] = 0xBD, ["="] = 0xBB, [","] = 0xBC, ["."] = 0xBE, ["/"] = 0xBF,
    ["`"] = 0xC0, [";"] = 0xBA, ["'"] = 0xDE, ["\\"] = 0xDC, 
    ["["] = 0xDB, ["]"] = 0xDD
}

local function validateKeybinds()
    local defaultKeys = { ToggleESP = "J", ToggleWalkthrough = "K", StepBack = "[", StepForward = "]" }
    local invalid = false
    
    local function check(k)
        if type(Cfg[k]) == "string" and not VK_MAP[string.upper(Cfg[k])] then invalid = true end
    end
    
    check("ToggleESP"); check("ToggleWalkthrough"); check("StepBack"); check("StepForward")
    
    if invalid then
        Cfg.ToggleESP = defaultKeys.ToggleESP
        Cfg.ToggleWalkthrough = defaultKeys.ToggleWalkthrough
        Cfg.StepBack = defaultKeys.StepBack
        Cfg.StepForward = defaultKeys.StepForward
        if Cfg.Debug then print("[WT-DEBUG] Invalid keybind | keybinds reset") end
    end
end
validateKeybinds()

local function getVK(keyStr)
    if type(keyStr) == "string" then return VK_MAP[string.upper(keyStr)] or 0 end
    return keyStr
end

-- ─── Core Script Functions ────────────────────────────────────────────────────
local function roundV2(v) return Vec2(floor(v.X + 0.5), floor(v.Y + 0.5)) end

local function getAnchor(model)
    local r = model:FindFirstChild("Root")
    if r and r:IsA("BasePart") then return r end
    local pp = model.PrimaryPart
    if pp then return pp end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

local function getPos(anchor)
    local ok, pos = pcall(function() return anchor.Position end)
    return ok and pos or nil
end

local function newEntry(dotColor, label, labelColor, anchor, zDot, zTxt)
    local d = Drawing.new("Circle")
    d.Filled  = true
    d.Radius  = Cfg.DotRadius
    d.Color   = dotColor
    d.Visible = false
    d.ZIndex  = zDot or 10

    local t = Drawing.new("Text")
    t.Font    = Drawing.Fonts.SystemBold
    t.Size    = Cfg.NameSize
    t.Color   = labelColor or Cfg.NameColor
    t.Outline = true
    t.Center  = true
    t.Text    = label
    t.Visible = false
    t.ZIndex  = zTxt or 11

    return { dot = d, txt = t, anchor = anchor, baseName = label }
end

local function removeEntry(e)
    pcall(function() e.dot:Remove() end)
    pcall(function() e.txt:Remove() end)
end

local Players = game:GetService("Players")

local function renderPool(pool, isCategoryEnabled)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

    for _, e in pairs(pool) do
        if not isCategoryEnabled then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local pos = e.staticPos or getPos(e.anchor)
        if not pos then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local ok, sc, onSc = pcall(WTS, pos)
        if not ok or not onSc or not sc then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local sp = roundV2(sc)
        
        if Cfg.DotEnabled and not e.noDot then
            e.dot.Position = sp; e.dot.Visible = true
        else
            e.dot.Visible = false
        end
        
        if Cfg.NameEnabled then
            local label = e.baseName
            if e.showDistance and hrp then
                local dist = floor((pos - hrp.Position).Magnitude)
                label = label .. "\n[" .. dist .. "]"
            end
            
            e.txt.Text = label
            e.txt.Position = Vec2(sp.X, sp.Y - (e.noDot and 0 or Cfg.DotRadius) - 4) 
            e.txt.Visible = true
        else
            e.txt.Visible = false
        end
    end
end

-- ─── Walkthrough Logic & State Verification ───────────────────────────────────
local function SafeFind(parent, ...)
    local current = parent
    local args = {...}
    for i = 1, #args do
        local name = args[i]
        if not current then return nil end
        local ok, child = pcall(function() return current:FindFirstChild(name) end)
        if ok and child then current = child else return nil end
    end
    return current
end

local function getGameplayParts()
    local correctParts = game.Workspace:FindFirstChild("GameplayParts")
    if correctParts then return correctParts end
    return game.Workspace:FindFirstChild("_GameplayParts")
end

local function isMissingWithFallback(obj, label, isItem)
    if not obj then return true end
    if isItem then return false end

    local parts = obj:IsA("Model") and obj:GetDescendants() or {obj}
    local isStillVisible = false
    
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") then
            local name = p.Name:lower()
            if not name:find("root") and not name:find("touch") and p.Transparency < 1 then
                isStillVisible = true
                break
            end
        end
    end
    
    return not isStillVisible
end

local function isDoorMissing(category, subCategory, name)
    local parts = getGameplayParts()
    if not parts then return false end
    local folder = SafeFind(parts, "Doors", category, subCategory)
    local door = folder and SafeFind(folder, name)
    return isMissingWithFallback(door, name, false)
end

local function isToolMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "Tool", name)
    return isMissingWithFallback(nFound, name, true)
end

local function isBucketMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "PaintBucket", name)
    return isMissingWithFallback(nFound, name, true)
end

local function getBrushCount()
    local lp = Players.LocalPlayer
    if not lp then return 0 end
    local val = 0
    pcall(function()
        local numText = lp.PlayerGui.MainGui.TopMenu.BrushCount.BrushesNumber.Text
        local numStr = string.match(numText, "^(%d+)")
        if numStr then val = tonumber(numStr) end
    end)
    return val or 0
end

local function getTool(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "Tool", name)
end

local function getBucket(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "PaintBucket", name)
end

local function getPaintableDoor(color) return SafeFind(getGameplayParts(), "Doors", "Normal", "Paintable", color) end
local function getUnlockableDoor(tool) return SafeFind(getGameplayParts(), "Doors", "Normal", "Unlockable", tool) end

local function checkDistanceTo(pos, dist)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local p1 = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
        local p2 = Vector3.new(pos.X, 0, pos.Z)
        if (p1 - p2).Magnitude <= dist then return true end
    end
    return false
end

-- ─── Walkthrough HUD & Pools ──────────────────────────────────────────────────
local wtPool = {}
local seenWt = {}

local hudText = Drawing.new("Text")
hudText.Font = Drawing.Fonts.SystemBold; hudText.Size = 15; hudText.Position = Vec2(30, 30)
hudText.Color = C3(255, 200, 50); hudText.Outline = true; hudText.Visible = false; hudText.ZIndex = 50

local currentStepIndex = 1
local previousStepIndex = 1
local ignoredSteps = {}
local stepCompletedLocally = {}

local function resetLocalSteps() stepCompletedLocally = {} end

local function drawPos(pos, name, color, uniqueSuffix)
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, nil, 30, 31)
        wtPool[poolKey].staticPos = pos
    else
        wtPool[poolKey].staticPos = pos
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function drawTarget(obj, name, color, uniqueSuffix)
    local anchor = getAnchor(obj) or obj 
    if not anchor or not anchor:IsA("BasePart") then return end
    
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, anchor, 30, 31)
    else
        wtPool[poolKey].anchor = anchor
        wtPool[poolKey].staticPos = nil
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function positionStep(stepIndex, pos, name)
    return {
        name = name,
        isComplete = function()
            if stepCompletedLocally[stepIndex] then return true end
            if checkDistanceTo(pos, 5) then
                stepCompletedLocally[stepIndex] = true
                return true
            end
            return false
        end,
        draw = function() drawPos(pos, name, C3(200, 200, 200), tostring(stepIndex)) end
    }
end

local Steps = {
    { name = "Black Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Black") end, draw = function() drawTarget(getPaintableDoor("Black"), "Black Wall", C3(60,60,60)) end },
    { name = "Red Bucket", isComplete = function() return isBucketMissing("Red") end, draw = function() drawTarget(getBucket("Red"), "Red Bucket", C3(255, 60, 60)) end },
    { name = "Red Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Red") end, draw = function() drawTarget(getPaintableDoor("Red"), "Red Wall", C3(255, 60, 60)) end },
    { name = "Orange Bucket", isComplete = function() return isBucketMissing("Orange") end, draw = function() drawTarget(getBucket("Orange"), "Orange Bucket", C3(255, 140, 0)) end },
    { name = "Orange Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Orange") end, draw = function() drawTarget(getPaintableDoor("Orange"), "Orange Wall", C3(255, 140, 0)) end },
    { name = "Yellow Bucket", isComplete = function() return isBucketMissing("Yellow") end, draw = function() drawTarget(getBucket("Yellow"), "Yellow Bucket", C3(255, 220, 0)) end },
    { name = "Yellow Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Yellow") end, draw = function() drawTarget(getPaintableDoor("Yellow"), "Yellow Wall", C3(255, 220, 0)) end },
    positionStep(8, Vec3(-135.69, 5.29, -228.41), "Door"),
    { name = "MetalSaw", isComplete = function() return isToolMissing("MetalSaw") end, draw = function() drawTarget(getTool("MetalSaw"), "MetalSaw", C3(200, 200, 200)) end },
    positionStep(10, Vec3(-559.61, 133.48, -516.39), "Door"),
    { name = "MetalSaw Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "MetalSaw") end, draw = function() drawTarget(getUnlockableDoor("MetalSaw"), "MetalSaw Door", C3(200, 200, 200)) end },
    { name = "Green Bucket", isComplete = function() return isBucketMissing("Green") end, draw = function() drawTarget(getBucket("Green"), "Green Bucket", C3(60, 220, 80)) end },
    { name = "Green Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Green") end, draw = function() drawTarget(getPaintableDoor("Green"), "Green Wall", C3(60, 220, 80)) end },
    { name = "Extinguisher", isComplete = function() return isToolMissing("Extinguisher") end, draw = function() drawTarget(getTool("Extinguisher"), "Extinguisher", C3(200, 200, 200)) end },
    { name = "Extinguisher Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Extinguisher") end, draw = function() drawTarget(getUnlockableDoor("Extinguisher"), "Extinguisher Door", C3(200, 200, 200)) end },
    { name = "Teal Bucket", isComplete = function() return isBucketMissing("Teal") end, draw = function() drawTarget(getBucket("Teal"), "Teal Bucket", C3(0, 200, 200)) end },
    positionStep(17, Vec3(-135.69, 5.29, -228.41), "Door"),
    { name = "Teal Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Teal") end, draw = function() drawTarget(getPaintableDoor("Teal"), "Teal Wall", C3(0, 200, 200)) end },
    { name = "Grappling", isComplete = function() return isToolMissing("Grappling") end, draw = function() drawTarget(getTool("Grappling"), "Grappling", C3(200, 200, 200)) end },
    positionStep(20, Vec3(-559.61, 133.48, -516.39), "Door"),
    { name = "Place Grapple & Blue Bucket", isComplete = function() return isBucketMissing("Blue") end, draw = function() 
            local buildable = SafeFind(getGameplayParts(), "Doors", "Normal", "Buildable", "Grappling")
            if buildable then drawTarget(buildable, "Place Grapple", C3(200, 200, 200)) end
            local bBucket = getBucket("Blue")
            if bBucket then drawTarget(bBucket, "Blue Bucket", C3(60, 130, 255)) end
        end },
    { name = "Blue Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Blue") end, draw = function() drawTarget(getPaintableDoor("Blue"), "Blue Wall", C3(60, 130, 255)) end },
    { name = "Purple Bucket", isComplete = function() return isBucketMissing("Purple") end, draw = function() drawTarget(getBucket("Purple"), "Purple Bucket", C3(160, 60, 255)) end },
    { name = "Purple Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Purple") end, draw = function() drawTarget(getPaintableDoor("Purple"), "Purple Wall", C3(160, 60, 255)) end },
    positionStep(25, Vec3(-93.33, 5.55, -341.92), "Door"),
    { name = "Laser", isComplete = function() return isToolMissing("Laser") end, draw = function() drawTarget(getTool("Laser"), "Laser", C3(200, 200, 200)) end },
    { name = "Laser Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Laser") end, draw = function() drawTarget(getUnlockableDoor("Laser"), "Laser Door", C3(200, 200, 200)) end },
    { name = "Pink Bucket", isComplete = function() return isBucketMissing("Pink") end, draw = function() drawTarget(getBucket("Pink"), "Pink Bucket", C3(255, 105, 180)) end },
    { name = "Pink Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Pink") end, draw = function() drawTarget(getPaintableDoor("Pink"), "Pink Wall", C3(255, 105, 180)) end },
    { name = "Key", isComplete = function() return isToolMissing("Key") end, draw = function() drawTarget(getTool("Key"), "Key", C3(200, 200, 200)) end },
    { name = "Key Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Key") end, draw = function() drawTarget(getUnlockableDoor("Key"), "Key Door", C3(200, 200, 200)) end },
    { name = "Collect all Paintbrushes", isComplete = function() return getBrushCount() >= 16 end, draw = function()
            local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
            local collectFolder = items and SafeFind(items, "Collectable", "Collectable")
            if collectFolder then
                for i, model in ipairs(collectFolder:GetChildren()) do
                    if model:IsA("Model") then drawTarget(model, "Paintbrush", C3(200,140,60), tostring(i)) end
                end
            end
        end },
    positionStep(33, Vec3(-4.84, 5.61, -404.74), "Door"),
    { name = "White Bucket", isComplete = function() return isBucketMissing("White") end, draw = function() drawTarget(getBucket("White"), "White Bucket", C3(230, 230, 230)) end },
    positionStep(35, Vec3(-746.16, 105.94, -750.43), "Door"),
    { name = "White Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "White") end, draw = function() drawTarget(getPaintableDoor("White"), "White Wall", C3(230, 230, 230)) end },
    { name = "Endings", isComplete = function() return false end, draw = function()
            local function drawEndingDynamic(folderName, label, color, num)
                local gp = getGameplayParts()
                local folder = gp and SafeFind(gp, "Teleporters", folderName)
                if folder then
                    local targetPart = nil
                    for _, v in ipairs(folder:GetDescendants()) do
                        if v:IsA("BasePart") then targetPart = v break end
                    end
                    if targetPart then drawTarget(targetPart, label, color, num) end
                end
            end
            
            drawEndingDynamic("EndingA", "Palette", C3(255, 255, 255), "1")
            drawEndingDynamic("EndingB", "Falling Floor", C3(255, 255, 255), "2")
            drawEndingDynamic("EndingC", "Sunset", C3(255, 255, 255), "3")
            drawEndingDynamic("EndingD", "Maze", C3(255, 255, 255), "4")
        end }
}

local function DetermineCurrentStep()
    if currentStepIndex > 1 then
        local ok, step1Complete = pcall(Steps[1].isComplete)
        if ok and not step1Complete then
            currentStepIndex = 1
            ignoredSteps = {}
            resetLocalSteps()
            return
        end
    end

    while currentStepIndex <= #Steps do
        local step = Steps[currentStepIndex]
        if not step then break end
        
        if ignoredSteps[currentStepIndex] then
            currentStepIndex = currentStepIndex + 1
        else
            local isCompOk, compVal = pcall(step.isComplete)
            if isCompOk and compVal == true then
                currentStepIndex = currentStepIndex + 1
            else
                break
            end
        end
    end
end

-- ─── Normal ESP Pools & Scanning ──────────────────────────────────────────────
local collectPool = {}
local bucketPool  = {}
local toolPool    = {}
local secretPool  = {}
local doorPool    = {}
local monsterPool = {} 
local plugPool    = {}

local normalToolNames = {}

local function scanItems()
    local gp = getGameplayParts()
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    
    -- Monster ESP Scanner
    local sM = {}
    local monstersFolder = SafeFind(game.Workspace, "GameplayAssets", "Monsters")
    
    if monstersFolder then
        -- Claude ESP
        local claude = SafeFind(monstersFolder, "Claude")
        if not claude then claude = SafeFind(game.Workspace, "Claude") end
        
        if claude then
            local anchor = getAnchor(claude)
            if anchor then
                local key = "Monster_Claude"
                sM[key] = true
                if not monsterPool[key] then
                    local e = newEntry(C3(255, 60, 60), "CLAUDE", C3(255, 60, 60), anchor, 40, 41)
                    e.txt.Size = 25 
                    e.noDot = true
                    e.showDistance = true
                    monsterPool[key] = e
                else
                    monsterPool[key].anchor = anchor
                end
            end
        end
    end
    for k,e in pairs(monsterPool) do if not sM[k] then removeEntry(e) monsterPool[k]=nil end end

    -- Plugs ESP Scanner (For transparency == 1)
    local seenPlug = {}
    local buttonsFolder = gp and SafeFind(gp, "ActivatedDoors", "DoorA", "Buttons")
    if buttonsFolder then
        local ok, ch = pcall(function() return buttonsFolder:GetChildren() end)
        if ok and ch then
            for _, btn in ipairs(ch) do
                local visual
                if btn.Name:match("Visual$") then 
                    visual = btn 
                else
                    visual = SafeFind(btn, "Visual")
                end
                
                if visual and visual:IsA("BasePart") and visual.Transparency >= 0.99 then
                    local key = "Plug_" .. btn.Name
                    seenPlug[key] = true
                    if not plugPool[key] then
                        local e = newEntry(C3(200, 200, 255), "plug", C3(200, 200, 255), visual, 35, 36)
                        e.showDistance = true
                        plugPool[key] = e
                    else
                        plugPool[key].anchor = visual
                    end
                end
            end
        end
    end
    for k, e in pairs(plugPool) do if not seenPlug[k] then removeEntry(e); plugPool[k] = nil end end

    local seenCollect, seenBucket, seenTool, seenSecret, seenDoor = {}, {}, {}, {}, {}

    if items then
        local collectFolder = SafeFind(items, "Collectable", "Collectable")
        if collectFolder then
            local ok, ch = pcall(function() return collectFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local key = model:GetFullName()
                    seenCollect[key] = true
                    if not collectPool[key] then collectPool[key] = newEntry(C3(200,140,60), "paintbrush", Cfg.NameColor, anchor)
                    else collectPool[key].anchor = anchor end
                end
            end
        end
        
        local bucketFolder = SafeFind(items, "Normal", "PaintBucket")
        if bucketFolder then
            local ok, ch = pcall(function() return bucketFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local bucketName = model.Name
                    local dotCol  = BUCKET_COLOR[bucketName] or C3(200,200,200)
                    local poolKey = model:GetFullName() 
                    seenBucket[poolKey] = true
                    if not bucketPool[poolKey] then bucketPool[poolKey] = newEntry(dotCol, bucketName, dotCol, anchor, 20, 21)
                    else bucketPool[poolKey].anchor = anchor; bucketPool[poolKey].dot.Color = dotCol; bucketPool[poolKey].txt.Color = dotCol; bucketPool[poolKey].baseName = bucketName end
                end
            end
        end

        normalToolNames = {}
        local normalToolFolder = SafeFind(items, "Normal", "Tool")
        if normalToolFolder then
            local ok, ch = pcall(function() return normalToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local toolName = model.Name
                    normalToolNames[toolName] = true
                    local poolKey = model:GetFullName()
                    seenTool[poolKey] = true
                    if not toolPool[poolKey] then toolPool[poolKey] = newEntry(C3(180,180,180), toolName, Cfg.NameColor, anchor)
                    else toolPool[poolKey].anchor = anchor; toolPool[poolKey].baseName = toolName end
                end
            end
        end

        local secretToolFolder = SafeFind(items, "Secret", "Tool")
        if secretToolFolder then
            local ok, ch = pcall(function() return secretToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local toolName = model.Name
                    if normalToolNames[toolName] then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local poolKey = model:GetFullName()
                    seenSecret[poolKey] = true
                    if not secretPool[poolKey] then secretPool[poolKey] = newEntry(C3(255,200,50), toolName.." (2)", C3(255,200,50), anchor)
                    else secretPool[poolKey].anchor = anchor; secretPool[poolKey].baseName = toolName.." (2)" end
                end
            end
        end
    end

    local function addDoorToPool(model, suffix)
        local anchor = getAnchor(model)
        if not anchor then return end
        local key = model.Name
        local doorName = key .. suffix
 
        if key == "ScrewDriver" then doorName = "Vent"
        elseif key == "Saw" then doorName = "Barricade"
        elseif key == "Hammer" then doorName = "Breakable Wall"
        elseif key == "MetalSaw" then doorName = "MetalSaw Door"
        elseif key == "Extinguisher" then doorName = "Extinguisher Door"
        elseif key == "Grappling" then doorName = "Grapple Spot"
        elseif key == "Laser" then doorName = "Laser Door" end
        
        local dotCol = BUCKET_COLOR[key] or C3(200, 200, 200)
        local poolKey = model:GetFullName()
        
        seenDoor[poolKey] = true
        if not doorPool[poolKey] then doorPool[poolKey] = newEntry(dotCol, doorName, dotCol, anchor, 15, 16)
        else doorPool[poolKey].anchor = anchor; doorPool[poolKey].dot.Color = dotCol; doorPool[poolKey].txt.Color = dotCol; doorPool[poolKey].baseName = doorName end
    end

    local paintableDoors = gp and SafeFind(gp, "Doors", "Normal", "Paintable")
    if paintableDoors then
        local ok, ch = pcall(function() return paintableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Wall") end end end
    end

    local unlockableDoors = gp and SafeFind(gp, "Doors", "Normal", "Unlockable")
    if unlockableDoors then
        local ok, ch = pcall(function() return unlockableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Door") end end end
    end

    local buildableDoors = gp and SafeFind(gp, "Doors", "Normal", "Buildable")
    if buildableDoors then
        local ok, ch = pcall(function() return buildableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Buildable") end end end
    end

    for key, e in pairs(collectPool) do if not seenCollect[key] then removeEntry(e); collectPool[key] = nil end end
    for key, e in pairs(bucketPool)  do if not seenBucket[key]  then removeEntry(e); bucketPool[key]  = nil end end
    for key, e in pairs(toolPool)    do if not seenTool[key]    then removeEntry(e); toolPool[key]    = nil end end
    for key, e in pairs(secretPool)  do if not seenSecret[key]  then removeEntry(e); secretPool[key]  = nil end end
    for key, e in pairs(doorPool)    do if not seenDoor[key]    then removeEntry(e); doorPool[key]    = nil end end
end

-- ─── Input & Main Loops ───────────────────────────────────────────────────────
local espEnabled = false
local wtEnabled  = false

local keyWasDown = { ToggleESP = false, ToggleWT = false, StepBack = false, StepForward = false }

local function pollKeybinds()
    local ok, down = pcall(iskeypressed, getVK(Cfg.ToggleESP))
    if ok then
        if down and not keyWasDown.ToggleESP then
            espEnabled = not espEnabled
            if espEnabled then wtEnabled = false end
        end
        keyWasDown.ToggleESP = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.ToggleWalkthrough))
    if ok then
        if down and not keyWasDown.ToggleWT then
            wtEnabled = not wtEnabled
            if wtEnabled then espEnabled = false end
        end
        keyWasDown.ToggleWT = down
    end
    
    ok, down = pcall(iskeypressed, getVK(Cfg.StepForward))
    if ok then
        if down and not keyWasDown.StepForward then
            if wtEnabled and currentStepIndex < #Steps then
                ignoredSteps[currentStepIndex] = true
            end
        end
        keyWasDown.StepForward = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.StepBack))
    if ok then
        if down and not keyWasDown.StepBack then
            if wtEnabled and currentStepIndex > 1 then
                local prev = currentStepIndex - 1
                currentStepIndex = prev    
                -- Explicitly change the current step tracker back
                ignoredSteps[prev] = false       -- Ensure it's not marked as skipped
                stepCompletedLocally[prev] = nil -- Clear positional cache so it doesn't instantly auto-complete
            end
        end
        keyWasDown.StepBack = down
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(scanItems)
    end
end)

task.spawn(function()
    while true do
        task.wait(0)
        pcall(function()
            pollKeybinds()
            
            renderPool(monsterPool, Cfg.ShowMonster)
            
            -- Plugs are rendered whether you use Normal ESP or Walkthrough mode
            if espEnabled or wtEnabled then
                renderPool(plugPool, true)
            else
                renderPool(plugPool, false)
            end

            if espEnabled then
                renderPool(collectPool, Cfg.ShowBrushes)
                renderPool(bucketPool,  Cfg.ShowBuckets)
                renderPool(toolPool,    Cfg.ShowTools)
                renderPool(secretPool,  Cfg.ShowSecrets)
                renderPool(doorPool,    Cfg.ShowDoors)
            else
                renderPool(collectPool, false)
                renderPool(bucketPool,  false)
                renderPool(toolPool,    false)
                renderPool(secretPool,  false)
                renderPool(doorPool,    false)
            end

            if wtEnabled then
                seenWt = {}
                DetermineCurrentStep()
                local step = Steps[currentStepIndex]

                if currentStepIndex ~= previousStepIndex then
                    previousStepIndex = currentStepIndex
                end

                if step then
                    hudText.Visible = true
                    hudText.Text = string.format("Walkthrough Step: %d/%d - %s", currentStepIndex, #Steps, step.name)
                    pcall(step.draw)
                else
                    hudText.Visible = true
                    hudText.Text = "Walkthrough: Done!"
                end

                for k, e in pairs(wtPool) do
                    if not seenWt[k] then
                        removeEntry(e)
                        wtPool[k] = nil
                    end
                end
                
                renderPool(wtPool, true)
            else
                hudText.Visible = false
                renderPool(wtPool, false)
            end
        end)
    end
end)

task.spawn(function()
    task.wait(2)
    notify("Keybinds", "Press " .. Cfg.ToggleESP .. " to enable normal esp", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.ToggleWalkthrough .. " to enable walkthrough", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.StepBack .. " and " .. Cfg.StepForward .. " to cycle through steps", 10)
end)
    end

elseif placeId == 92691286130182 then
    do
local Vec2  = Vector2.new
local Vec3  = Vector3.new
local C3    = Color3.fromRGB
local WTS   = WorldToScreen
local floor = math.floor

local VK_MAP = {
    A=0x41, B=0x42, C=0x43, D=0x44, E=0x45, F=0x46, G=0x47, H=0x48, I=0x49, J=0x4A,
    K=0x4B, L=0x4C, M=0x4D, N=0x4E, O=0x4F, P=0x50, Q=0x51, R=0x52, S=0x53, T=0x54,
    U=0x55, V=0x56, W=0x57, X=0x58, Y=0x59, Z=0x5A,
    ["0"]=0x30, ["1"]=0x31, ["2"]=0x32, ["3"]=0x33, ["4"]=0x34,
    ["5"]=0x35, ["6"]=0x36, ["7"]=0x37, ["8"]=0x38, ["9"]=0x39,
    F1=0x70, F2=0x71, F3=0x72, F4=0x73, F5=0x74, F6=0x75, 
    F7=0x76, F8=0x77, F9=0x78, F10=0x79, F11=0x7A, F12=0x7B,
    LEFTBRACKET=0xDB, RIGHTBRACKET=0xDD,
    ["-"] = 0xBD, ["="] = 0xBB, [","] = 0xBC, ["."] = 0xBE, ["/"] = 0xBF,
    ["`"] = 0xC0, [";"] = 0xBA, ["'"] = 0xDE, ["\\"] = 0xDC, 
    ["["] = 0xDB, ["]"] = 0xDD
}

local function validateKeybinds()
    local defaultKeys = { ToggleESP = "J", ToggleWalkthrough = "K", StepBack = "[", StepForward = "]" }
    local invalid = false
    
    local function check(k)
        if type(Cfg[k]) == "string" and not VK_MAP[string.upper(Cfg[k])] then invalid = true end
    end
    
    check("ToggleESP"); check("ToggleWalkthrough"); check("StepBack"); check("StepForward")
    
    if invalid then
        Cfg.ToggleESP = defaultKeys.ToggleESP
        Cfg.ToggleWalkthrough = defaultKeys.ToggleWalkthrough
        Cfg.StepBack = defaultKeys.StepBack
        Cfg.StepForward = defaultKeys.StepForward
        if Cfg.Debug then print("[WT-DEBUG] Invalid keybind | keybinds reset") end
    end
end
validateKeybinds()

local function getVK(keyStr)
    if type(keyStr) == "string" then return VK_MAP[string.upper(keyStr)] or 0 end
    return keyStr
end

-- ─── Core Script Functions ────────────────────────────────────────────────────
local function roundV2(v) return Vec2(floor(v.X + 0.5), floor(v.Y + 0.5)) end

local function getAnchor(model)
    local r = model:FindFirstChild("Root")
    if r and r:IsA("BasePart") then return r end
    local pp = model.PrimaryPart
    if pp then return pp end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

local function getPos(anchor)
    local ok, pos = pcall(function() return anchor.Position end)
    return ok and pos or nil
end

local function newEntry(dotColor, label, labelColor, anchor, zDot, zTxt)
    local d = Drawing.new("Circle")
    d.Filled  = true
    d.Radius  = Cfg.DotRadius
    d.Color   = dotColor
    d.Visible = false
    d.ZIndex  = zDot or 10

    local t = Drawing.new("Text")
    t.Font    = Drawing.Fonts.SystemBold
    t.Size    = Cfg.NameSize
    t.Color   = labelColor or Cfg.NameColor
    t.Outline = true
    t.Center  = true
    t.Text    = label
    t.Visible = false
    t.ZIndex  = zTxt or 11

    return { dot = d, txt = t, anchor = anchor, baseName = label }
end

local function removeEntry(e)
    pcall(function() e.dot:Remove() end)
    pcall(function() e.txt:Remove() end)
end

local Players = game:GetService("Players")

local function renderPool(pool, isCategoryEnabled)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

    for _, e in pairs(pool) do
        if not isCategoryEnabled then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local pos = e.staticPos or getPos(e.anchor)
        if not pos then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local ok, sc, onSc = pcall(WTS, pos)
        if not ok or not onSc or not sc then
            e.dot.Visible = false; e.txt.Visible = false; continue
        end
        
        local sp = roundV2(sc)
        
        if Cfg.DotEnabled and not e.noDot then
            e.dot.Position = sp; e.dot.Visible = true
        else
            e.dot.Visible = false
        end
        
        if Cfg.NameEnabled then
            local label = e.baseName
            if e.showDistance and hrp then
                local dist = floor((pos - hrp.Position).Magnitude)
                label = label .. "\n[" .. dist .. "]"
            end
            
            e.txt.Text = label
            e.txt.Position = Vec2(sp.X, sp.Y - (e.noDot and 0 or Cfg.DotRadius) - 4) 
            e.txt.Visible = true
        else
            e.txt.Visible = false
        end
    end
end

-- ─── Walkthrough Logic & State Verification ───────────────────────────────────
local function SafeFind(parent, ...)
    local current = parent
    local args = {...}
    for i = 1, #args do
        local name = args[i]
        if not current then return nil end
        local ok, child = pcall(function() return current:FindFirstChild(name) end)
        if ok and child then current = child else return nil end
    end
    return current
end

local function getGameplayParts()
    local correctParts = game.Workspace:FindFirstChild("GameplayParts")
    if correctParts then return correctParts end
    return game.Workspace:FindFirstChild("_GameplayParts")
end

local function isMissingWithFallback(obj, label, isItem)
    if not obj then return true end
    if isItem then return false end

    local parts = obj:IsA("Model") and obj:GetDescendants() or {obj}
    local isStillVisible = false
    
    for _, p in ipairs(parts) do
        if p:IsA("BasePart") then
            local name = p.Name:lower()
            if not name:find("root") and not name:find("touch") and p.Transparency < 1 then
                isStillVisible = true
                break
            end
        end
    end
    
    return not isStillVisible
end

local function isDoorMissing(category, subCategory, name)
    local parts = getGameplayParts()
    if not parts then return false end
    local folder = SafeFind(parts, "Doors", category, subCategory)
    local door = folder and SafeFind(folder, name)
    return isMissingWithFallback(door, name, false)
end

local function isToolMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "Tool", name)
    return isMissingWithFallback(nFound, name, true)
end

local function isBucketMissing(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return false end
    local nFound = SafeFind(items, "Normal", "PaintBucket", name)
    return isMissingWithFallback(nFound, name, true)
end

local function getBrushCount()
    local lp = Players.LocalPlayer
    if not lp then return 0 end
    local val = 0
    pcall(function()
        local numText = lp.PlayerGui.MainGui.TopMenu.BrushCount.BrushesNumber.Text
        local numStr = string.match(numText, "^(%d+)")
        if numStr then val = tonumber(numStr) end
    end)
    return val or 0
end

local function getTool(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "Tool", name)
end

local function getBucket(name)
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
    if not items then return nil end
    return SafeFind(items, "Normal", "PaintBucket", name)
end

local function getPaintableDoor(color) return SafeFind(getGameplayParts(), "Doors", "Normal", "Paintable", color) end
local function getUnlockableDoor(tool) return SafeFind(getGameplayParts(), "Doors", "Normal", "Unlockable", tool) end

local function checkDistanceTo(pos, dist)
    local lp = Players.LocalPlayer
    local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local p1 = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
        local p2 = Vector3.new(pos.X, 0, pos.Z)
        if (p1 - p2).Magnitude <= dist then return true end
    end
    return false
end

-- ─── Walkthrough HUD & Pools ──────────────────────────────────────────────────
local wtPool = {}
local seenWt = {}

local hudText = Drawing.new("Text")
hudText.Font = Drawing.Fonts.SystemBold; hudText.Size = 15; hudText.Position = Vec2(30, 30)
hudText.Color = C3(255, 200, 50); hudText.Outline = true; hudText.Visible = false; hudText.ZIndex = 50

local currentStepIndex = 1
local previousStepIndex = 1
local ignoredSteps = {}
local stepCompletedLocally = {}

local function resetLocalSteps() stepCompletedLocally = {} end

local function drawPos(pos, name, color, uniqueSuffix)
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, nil, 30, 31)
        wtPool[poolKey].staticPos = pos
    else
        wtPool[poolKey].staticPos = pos
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function drawTarget(obj, name, color, uniqueSuffix)
    local anchor = getAnchor(obj) or obj 
    if not anchor or not anchor:IsA("BasePart") then return end
    
    local poolKey = "WT_" .. name .. (uniqueSuffix or "")
    seenWt[poolKey] = true
    if not wtPool[poolKey] then
        wtPool[poolKey] = newEntry(color, name, color, anchor, 30, 31)
    else
        wtPool[poolKey].anchor = anchor
        wtPool[poolKey].staticPos = nil
        wtPool[poolKey].dot.Color = color
        wtPool[poolKey].txt.Color = color
        wtPool[poolKey].baseName  = name
    end
end

local function positionStep(stepIndex, pos, name)
    return {
        name = name,
        isComplete = function()
            if stepCompletedLocally[stepIndex] then return true end
            if checkDistanceTo(pos, 5) then
                stepCompletedLocally[stepIndex] = true
                return true
            end
            return false
        end,
        draw = function() drawPos(pos, name, C3(200, 200, 200), tostring(stepIndex)) end
    }
end

local Steps = {
    { name = "Black Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Black") end, draw = function() drawTarget(getPaintableDoor("Black"), "Black Wall", C3(60,60,60)) end },
    { name = "Red Bucket", isComplete = function() return isBucketMissing("Red") end, draw = function() drawTarget(getBucket("Red"), "Red Bucket", C3(255, 60, 60)) end },
    { name = "Red Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Red") end, draw = function() drawTarget(getPaintableDoor("Red"), "Red Wall", C3(255, 60, 60)) end },
    { name = "PuzzlePiece", isComplete = function() return isToolMissing("PuzzlePiece") end, draw = function() drawTarget(getTool("PuzzlePiece"), "PuzzlePiece", C3(200, 200, 200)) end },
    { name = "PuzzlePiece Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "PuzzlePiece") end, draw = function() drawTarget(getUnlockableDoor("PuzzlePiece"), "PuzzlePiece Door", C3(200, 200, 200)) end },
    { name = "Orange Bucket", isComplete = function() return isBucketMissing("Orange") end, draw = function() drawTarget(getBucket("Orange"), "Orange Bucket", C3(255, 140, 0)) end },
    { name = "Orange Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Orange") end, draw = function() drawTarget(getPaintableDoor("Orange"), "Orange Wall", C3(255, 140, 0)) end },
    { name = "Yellow Bucket", isComplete = function() return isBucketMissing("Yellow") end, draw = function() drawTarget(getBucket("Yellow"), "Yellow Bucket", C3(255, 220, 0)) end },
    { name = "Yellow Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Yellow") end, draw = function() drawTarget(getPaintableDoor("Yellow"), "Yellow Wall", C3(255, 220, 0)) end },
    positionStep(10, Vec3(73.08, 6, 30.13), "Door"),
    { name = "Green Bucket", isComplete = function() return isBucketMissing("Green") end, draw = function() drawTarget(getBucket("Green"), "Green Bucket", C3(60, 220, 80)) end },
    positionStep(12, Vec3(821.86, 407.56, 1254.17), "Door"),
    { name = "Green Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Green") end, draw = function() drawTarget(getPaintableDoor("Green"), "Green Wall", C3(60, 220, 80)) end },
    positionStep(14, Vec3(318.05, 5.98, 109), "Door"),
    { name = "Teal Bucket", isComplete = function() return isBucketMissing("Teal") end, draw = function() drawTarget(getBucket("Teal"), "Teal Bucket", C3(0, 200, 200)) end },
    positionStep(16, Vec3(-1849.35, 1014.5, 2343.28), "Door"),
    { name = "Teal Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Teal") end, draw = function() drawTarget(getPaintableDoor("Teal"), "Teal Wall", C3(0, 200, 200)) end },
    { name = "Code", isComplete = function() return isToolMissing("Code") end, draw = function() drawTarget(getTool("Code"), "Code", C3(200, 200, 200)) end },
    { name = "Code Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Code") end, draw = function() drawTarget(getUnlockableDoor("Code"), "Code Door", C3(200, 200, 200)) end },
    { name = "Blue Bucket", isComplete = function() return isBucketMissing("Blue") end, draw = function() drawTarget(getBucket("Blue"), "Blue Bucket", C3(60, 130, 255)) end },
    { name = "Blue Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Blue") end, draw = function() drawTarget(getPaintableDoor("Blue"), "Blue Wall", C3(60, 130, 255)) end },
    { name = "DoorKnob", isComplete = function() return isToolMissing("DoorKnob") end, draw = function() drawTarget(getTool("DoorKnob"), "DoorKnob", C3(200, 200, 200)) end },
    positionStep(23, Vec3(73.08, 6, 30.13), "Door"),
    { name = "DoorKnob Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "DoorKnob") end, draw = function() drawTarget(getUnlockableDoor("DoorKnob"), "DoorKnob Door", C3(200, 200, 200)) end },
    { name = "Gear", isComplete = function() return isToolMissing("Gear") end, draw = function() drawTarget(getTool("Gear"), "Gear", C3(200, 200, 200)) end },
    positionStep(26, Vec3(821.86, 407.56, 1254.17), "Door"),
    { name = "Gear Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Gear") end, draw = function() drawTarget(getUnlockableDoor("Gear"), "Gear Door", C3(200, 200, 200)) end },
    { name = "Purple Bucket", isComplete = function() return isBucketMissing("Purple") end, draw = function() drawTarget(getBucket("Purple"), "Purple Bucket", C3(160, 60, 255)) end },
    positionStep(29, Vec3(318.05, 5.98, 109), "Door"),
    { name = "Purple Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Purple") end, draw = function() drawTarget(getPaintableDoor("Purple"), "Purple Wall", C3(160, 60, 255)) end },
    { name = "StaffPass", isComplete = function() return isToolMissing("StaffPass") end, draw = function() drawTarget(getTool("StaffPass"), "StaffPass", C3(200, 200, 200)) end },
    positionStep(32, Vec3(-1849.35, 1014.5, 2343.28), "Door"),
    { name = "StaffPass Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "StaffPass") end, draw = function() drawTarget(getUnlockableDoor("StaffPass"), "StaffPass Door", C3(200, 200, 200)) end },
    { name = "Pink Bucket", isComplete = function() return isBucketMissing("Pink") end, draw = function() drawTarget(getBucket("Pink"), "Pink Bucket", C3(255, 105, 180)) end },
    { name = "Pink Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "Pink") end, draw = function() drawTarget(getPaintableDoor("Pink"), "Pink Wall", C3(255, 105, 180)) end },
    { name = "Book", isComplete = function() return isToolMissing("Book") end, draw = function() drawTarget(getTool("Book"), "Book", C3(200, 200, 200)) end },
    { name = "Book Door", isComplete = function() return isDoorMissing("Normal", "Unlockable", "Book") end, draw = function() drawTarget(getUnlockableDoor("Book"), "Book Door", C3(200, 200, 200)) end },
    { name = "Collect all Paintbrushes", isComplete = function() return getBrushCount() >= 13 end, draw = function()
            local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
            local collectFolder = items and SafeFind(items, "Collectable", "Collectable")
            if collectFolder then
                for i, model in ipairs(collectFolder:GetChildren()) do
                    if model:IsA("Model") then drawTarget(model, "Paintbrush", C3(200,140,60), tostring(i)) end
                end
            end
        end },
    positionStep(39, Vec3(427.75, 6, -0.42), "Door"),
    { name = "White Bucket", isComplete = function() return isBucketMissing("White") end, draw = function() drawTarget(getBucket("White"), "White Bucket", C3(230, 230, 230)) end },
    positionStep(41, Vec3(3122.27, 29.65, 393.49), "Door"),
    { name = "White Wall", isComplete = function() return isDoorMissing("Normal", "Paintable", "White") end, draw = function() drawTarget(getPaintableDoor("White"), "White Wall", C3(230, 230, 230)) end },
    { name = "Endings", isComplete = function() return false end, draw = function()
            local function drawEndingDynamic(folderName, label, color, num)
                local gp = getGameplayParts()
                local folder = gp and SafeFind(gp, "Teleporters", folderName)
                if folder then
                    local targetPart = nil
                    for _, v in ipairs(folder:GetDescendants()) do
                        if v:IsA("BasePart") then targetPart = v break end
                    end
                    if targetPart then drawTarget(targetPart, label, color, num) end
                end
            end
            
            drawEndingDynamic("EndingA", "Room Dropper", C3(255, 255, 255), "1")
            drawEndingDynamic("EndingB", "Dropper", C3(255, 255, 255), "2")
        end }
}

local function DetermineCurrentStep()
    if currentStepIndex > 1 then
        local ok, step1Complete = pcall(Steps[1].isComplete)
        if ok and not step1Complete then
            currentStepIndex = 1
            ignoredSteps = {}
            resetLocalSteps()
            return
        end
    end

    while currentStepIndex <= #Steps do
        local step = Steps[currentStepIndex]
        if not step then break end
        
        if ignoredSteps[currentStepIndex] then
            currentStepIndex = currentStepIndex + 1
        else
            local isCompOk, compVal = pcall(step.isComplete)
            if isCompOk and compVal == true then
                currentStepIndex = currentStepIndex + 1
            else
                break
            end
        end
    end
end

-- ─── Normal ESP Pools & Scanning ──────────────────────────────────────────────
local collectPool = {}
local bucketPool  = {}
local toolPool    = {}
local secretPool  = {}
local doorPool    = {}
local monsterPool = {} 
local plugPool    = {}

local normalToolNames = {}

local function scanItems()
    local gp = getGameplayParts()
    local items = SafeFind(game.Workspace, "GameplayAssets", "Items")
     
    -- Monster ESP Scanner
    local sM = {}
    local monstersFolder = SafeFind(game.Workspace, "GameplayAssets", "Monsters")
    
    if monstersFolder then
        -- SirLeon ESP (Chapter 4)
        local claude = SafeFind(monstersFolder, "SirLeon")
        if not claude then claude = SafeFind(game.Workspace, "SirLeon") end
        
        if claude then
            local anchor = getAnchor(claude)
            if anchor then
                local key = "Monster_SirLeon"
                sM[key] = true
                if not monsterPool[key] then
                    local e = newEntry(C3(255, 60, 60), "SIR LEON", C3(255, 60, 60), anchor, 40, 41)
                    e.txt.Size = 25 
                    e.noDot = true
                    e.showDistance = true
                    monsterPool[key] = e
                else
                    monsterPool[key].anchor = anchor
                end
            end
        end
    end
    for k,e in pairs(monsterPool) do if not sM[k] then removeEntry(e) monsterPool[k]=nil end end

    -- Plugs ESP Scanner (For transparency == 1)
    local seenPlug = {}
    local buttonsFolder = gp and SafeFind(gp, "ActivatedDoors", "DoorA", "Buttons")
    if buttonsFolder then
        local ok, ch = pcall(function() return buttonsFolder:GetChildren() end)
        if ok and ch then
            for _, btn in ipairs(ch) do
                local visual
                if btn.Name:match("Visual$") then 
                    visual = btn 
                else
                    visual = SafeFind(btn, "Visual")
                end
                
                if visual and visual:IsA("BasePart") and visual.Transparency >= 0.99 then
                    local key = "Plug_" .. btn.Name
                    seenPlug[key] = true
                    if not plugPool[key] then
                        local e = newEntry(C3(200, 200, 255), "plug", C3(200, 200, 255), visual, 35, 36)
                        e.showDistance = true
                        plugPool[key] = e
                    else
                        plugPool[key].anchor = visual
                    end
                end
            end
        end
    end
    for k, e in pairs(plugPool) do if not seenPlug[k] then removeEntry(e); plugPool[k] = nil end end

    local seenCollect, seenBucket, seenTool, seenSecret, seenDoor = {}, {}, {}, {}, {}

    if items then
        local collectFolder = SafeFind(items, "Collectable", "Collectable")
        if collectFolder then
            local ok, ch = pcall(function() return collectFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local key = model:GetFullName()
                    seenCollect[key] = true
                    if not collectPool[key] then collectPool[key] = newEntry(C3(200,140,60), "paintbrush", Cfg.NameColor, anchor)
                    else collectPool[key].anchor = anchor end
                end
            end
        end
        
        local bucketFolder = SafeFind(items, "Normal", "PaintBucket")
        if bucketFolder then
            local ok, ch = pcall(function() return bucketFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local bucketName = model.Name
                    local dotCol  = BUCKET_COLOR[bucketName] or C3(200,200,200)
                    local poolKey = model:GetFullName() 
                    seenBucket[poolKey] = true
                    if not bucketPool[poolKey] then bucketPool[poolKey] = newEntry(dotCol, bucketName, dotCol, anchor, 20, 21)
                    else bucketPool[poolKey].anchor = anchor; bucketPool[poolKey].dot.Color = dotCol; bucketPool[poolKey].txt.Color = dotCol; bucketPool[poolKey].baseName = bucketName end
                end
            end
        end

        normalToolNames = {}
        local normalToolFolder = SafeFind(items, "Normal", "Tool")
        if normalToolFolder then
            local ok, ch = pcall(function() return normalToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local toolName = model.Name
                    normalToolNames[toolName] = true
                    local poolKey = model:GetFullName()
                    seenTool[poolKey] = true
                    if not toolPool[poolKey] then toolPool[poolKey] = newEntry(C3(180,180,180), toolName, Cfg.NameColor, anchor)
                    else toolPool[poolKey].anchor = anchor; toolPool[poolKey].baseName = toolName end
                end
            end
        end

        local secretToolFolder = SafeFind(items, "Secret", "Tool")
        if secretToolFolder then
            local ok, ch = pcall(function() return secretToolFolder:GetChildren() end)
            if ok and ch then
                for _, model in ipairs(ch) do
                    if not model:IsA("Model") then continue end
                    local toolName = model.Name
                    if normalToolNames[toolName] then continue end
                    local anchor = getAnchor(model)
                    if not anchor then continue end
                    local poolKey = model:GetFullName()
                    seenSecret[poolKey] = true
                    if not secretPool[poolKey] then secretPool[poolKey] = newEntry(C3(255,200,50), toolName.." (2)", C3(255,200,50), anchor)
                    else secretPool[poolKey].anchor = anchor; secretPool[poolKey].baseName = toolName.." (2)" end
                end
            end
        end
    end

    local function addDoorToPool(model, suffix)
        local anchor = getAnchor(model)
        if not anchor then return end
        local key = model.Name
        local doorName = key .. suffix

        if key == "PuzzlePiece" then doorName = "Puzzle Door"
        elseif key == "Code" then doorName = "Code Door"
        elseif key == "DoorKnob" then doorName = "DoorKnob Door"
        elseif key == "Gear" then doorName = "Gear Door"
        elseif key == "StaffPass" then doorName = "StaffPass Door"
        elseif key == "Book" then doorName = "Book Door" end
        
        local dotCol = BUCKET_COLOR[key] or C3(200, 200, 200)
        local poolKey = model:GetFullName()
        
        seenDoor[poolKey] = true
        if not doorPool[poolKey] then doorPool[poolKey] = newEntry(dotCol, doorName, dotCol, anchor, 15, 16)
        else doorPool[poolKey].anchor = anchor; doorPool[poolKey].dot.Color = dotCol; doorPool[poolKey].txt.Color = dotCol; doorPool[poolKey].baseName = doorName end
    end

    local paintableDoors = gp and SafeFind(gp, "Doors", "Normal", "Paintable")
    if paintableDoors then
        local ok, ch = pcall(function() return paintableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Wall") end end end
    end

    local unlockableDoors = gp and SafeFind(gp, "Doors", "Normal", "Unlockable")
    if unlockableDoors then
        local ok, ch = pcall(function() return unlockableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Door") end end end
    end

    local buildableDoors = gp and SafeFind(gp, "Doors", "Normal", "Buildable")
    if buildableDoors then
        local ok, ch = pcall(function() return buildableDoors:GetChildren() end)
        if ok and ch then for _, model in ipairs(ch) do if model:IsA("Model") then addDoorToPool(model, " Buildable") end end end
    end

    for key, e in pairs(collectPool) do if not seenCollect[key] then removeEntry(e); collectPool[key] = nil end end
    for key, e in pairs(bucketPool)  do if not seenBucket[key]  then removeEntry(e); bucketPool[key]  = nil end end
    for key, e in pairs(toolPool)    do if not seenTool[key]    then removeEntry(e); toolPool[key]    = nil end end
    for key, e in pairs(secretPool)  do if not seenSecret[key]  then removeEntry(e); secretPool[key]  = nil end end
    for key, e in pairs(doorPool)    do if not seenDoor[key]    then removeEntry(e); doorPool[key]    = nil end end
end

-- ─── Input & Main Loops ───────────────────────────────────────────────────────
local espEnabled = false
local wtEnabled  = false

local keyWasDown = { ToggleESP = false, ToggleWT = false, StepBack = false, StepForward = false }

local function pollKeybinds()
    local ok, down = pcall(iskeypressed, getVK(Cfg.ToggleESP))
    if ok then
        if down and not keyWasDown.ToggleESP then
            espEnabled = not espEnabled
            if espEnabled then wtEnabled = false end
        end
        keyWasDown.ToggleESP = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.ToggleWalkthrough))
    if ok then
        if down and not keyWasDown.ToggleWT then
            wtEnabled = not wtEnabled
            if wtEnabled then espEnabled = false end
        end
        keyWasDown.ToggleWT = down
    end
    
    ok, down = pcall(iskeypressed, getVK(Cfg.StepForward))
    if ok then
        if down and not keyWasDown.StepForward then
            if wtEnabled and currentStepIndex < #Steps then
                ignoredSteps[currentStepIndex] = true
            end
        end
        keyWasDown.StepForward = down
    end

    ok, down = pcall(iskeypressed, getVK(Cfg.StepBack))
    if ok then
        if down and not keyWasDown.StepBack then
            if wtEnabled and currentStepIndex > 1 then
                local prev = currentStepIndex - 1
                currentStepIndex = prev    

                -- Explicitly change the current step tracker back
                ignoredSteps[prev] = false       -- Ensure it's not marked as skipped
                stepCompletedLocally[prev] = nil -- Clear positional cache so it doesn't instantly auto-complete
            end
        end
        keyWasDown.StepBack = down
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(scanItems)
    end
end)

task.spawn(function()
    while true do
        task.wait(0)
        pcall(function()
            pollKeybinds()
            
            renderPool(monsterPool, Cfg.ShowMonster)
            
            -- Plugs are rendered whether you use Normal ESP or Walkthrough mode
            if espEnabled or wtEnabled then
                renderPool(plugPool, true)
            else
                renderPool(plugPool, false)
            end

            if espEnabled then
                renderPool(collectPool, Cfg.ShowBrushes)
                renderPool(bucketPool,  Cfg.ShowBuckets)
                renderPool(toolPool,    Cfg.ShowTools)
                renderPool(secretPool,  Cfg.ShowSecrets)
                renderPool(doorPool,    Cfg.ShowDoors)
            else
                renderPool(collectPool, false)
                renderPool(bucketPool,  false)
                renderPool(toolPool,    false)
                renderPool(secretPool,  false)
                renderPool(doorPool,    false)
            end

            if wtEnabled then
                seenWt = {}
                DetermineCurrentStep()
                local step = Steps[currentStepIndex]

                if currentStepIndex ~= previousStepIndex then
                    previousStepIndex = currentStepIndex
                end

                if step then
                    hudText.Visible = true
                    hudText.Text = string.format("Walkthrough Step: %d/%d - %s", currentStepIndex, #Steps, step.name)
                    pcall(step.draw)
                else
                    hudText.Visible = true
                    hudText.Text = "Walkthrough: Done!"
                end

                for k, e in pairs(wtPool) do
                    if not seenWt[k] then
                        removeEntry(e)
                        wtPool[k] = nil
                    end
                end
                
                renderPool(wtPool, true)
            else
                hudText.Visible = false
                renderPool(wtPool, false)
            end
        end)
    end
end)

task.spawn(function()
    task.wait(2)
    notify("Keybinds", "Press " .. Cfg.ToggleESP .. " to enable normal esp", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.ToggleWalkthrough .. " to enable walkthrough", 10)
    task.wait(.25)
    notify("Keybinds", "Press " .. Cfg.StepBack .. " and " .. Cfg.StepForward .. " to cycle through steps", 10)
end)
    end

else
    notify("Game not recognized, please join Color Or Die.", 10)
end
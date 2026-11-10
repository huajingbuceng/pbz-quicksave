--[[
    PBZ QuickSave
    《影之刃零》随时存档 + 位置记忆

    F8   → 让游戏存一次档（写入「继续」槽）+ 记录当前坐标
    F9   → 传送回记录的坐标（不读档，进度不变）
    F11  → 打印当前坐标与记录坐标

    存档走游戏自己的 PBZSaveLoadSubsystem:TrySave，
    传送走游戏自己的 PBZCheatManager:GM_TeleportToLocation。
    不修改任何游戏文件。

    关于「游戏内读档为什么没做」，见 docs/存档系统逆向笔记.md
--]]

local MOD = "PBZQuickSave"

-- 游戏进程的工作目录是 ProjectPBZ\Binaries\Win64，所以相对路径就写在这
local CANDIDATES = { "pos.txt", "Mods/PBZQuickSave/pos.txt", "../ue4ss/Mods/PBZQuickSave/pos.txt" }

local posPath = nil
local state = { x = 0.0, y = 0.0, z = 0.0, yaw = 0.0, map = "", valid = false }

local function log(fmt, ...)
    local msg
    if select('#', ...) > 0 then
        local ok, r = pcall(string.format, fmt, ...)
        if ok then msg = r else msg = tostring(fmt) end
    else
        msg = tostring(fmt)
    end
    print("[" .. MOD .. "] " .. msg)
end

local function safe(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

-- ------------------------------------------------------------------
-- 坐标持久化
-- ------------------------------------------------------------------
local function resolvePath()
    if posPath ~= nil then return posPath end
    if io == nil then return nil end
    for i = 1, #CANDIDATES do
        local f = io.open(CANDIDATES[i], "a")
        if f ~= nil then
            f:close()
            posPath = CANDIDATES[i]
            return posPath
        end
    end
    return nil
end

local function saveState()
    local p = resolvePath()
    if p == nil then return end
    pcall(function()
        local f = io.open(p, "w")
        if f == nil then error("open failed") end
        f:write(string.format("%.3f,%.3f,%.3f,%.3f,%s\n",
            state.x, state.y, state.z, state.yaw, state.map))
        f:close()
    end)
end

local function loadState()
    local p = resolvePath()
    if p == nil then return false end
    local ok = pcall(function()
        local f = io.open(p, "r")
        if f == nil then error("missing") end
        local line = f:read("*l")
        f:close()
        if line == nil or line == "" then error("empty") end
        local a, b, c, d, rest = string.match(line, "([^,]+),([^,]+),([^,]+),([^,]+),(.*)")
        if a == nil then error("bad format") end
        state.x = tonumber(a) or 0
        state.y = tonumber(b) or 0
        state.z = tonumber(c) or 0
        state.yaw = tonumber(d) or 0
        state.map = rest or ""
        state.valid = true
    end)
    if not ok then state.valid = false; return false end
    return true
end

-- ------------------------------------------------------------------
-- 游戏对象
-- ------------------------------------------------------------------
local function getPawn()
    local pawn = safe(function() return UEHelpers.GetPlayerPawn() end)
    if pawn then
        if safe(function() return pawn:IsValid() end) then return pawn end
    end
    local pc = safe(function() return FindFirstOf("PlayerController") end)
    if pc then
        local p2 = safe(function() return pc.Pawn end)
        if p2 then
            if safe(function() return p2:IsValid() end) then return p2 end
        end
    end
    return nil
end

local function getPos()
    local pawn = getPawn()
    if not pawn then return nil end
    local loc = safe(function() return pawn:K2_GetActorLocation() end)
    if not loc then return nil end
    local rot = safe(function() return pawn:K2_GetActorRotation() end)
    local yaw = 0.0
    if rot then yaw = rot.Yaw or 0.0 end
    local world = safe(function() return pawn:GetWorld() end)
    local mapName = ""
    if world then
        local n = safe(function() return world:GetFName():ToString() end)
        if n then mapName = n end
    end
    return { X = loc.X, Y = loc.Y, Z = loc.Z, yaw = yaw, map = mapName }
end

local function subsystem()
    local ss = safe(function() return FindFirstOf("PBZSaveLoadSubsystem") end)
    if ss then
        if safe(function() return ss:IsValid() end) then return ss end
    end
    return nil
end

local function cheatManager()
    local cm = safe(function() return FindFirstOf("PBZCheatManager") end)
    if cm then
        if safe(function() return cm:IsValid() end) then return cm end
    end
    local pc = safe(function() return FindFirstOf("PlayerController") end)
    if pc then
        local c = safe(function() return pc.CheatManager end)
        if c then return c end
    end
    return nil
end

-- ------------------------------------------------------------------
-- 功能
-- ------------------------------------------------------------------
local function teleportToRecorded()
    if not state.valid then
        log("还没有记录点，先按 F8")
        return
    end
    local cm = cheatManager()
    if cm == nil then
        log("CheatManager 不可用")
        return
    end
    local fn = safe(function() return cm["GM_TeleportToLocation"] end)
    if fn == nil then
        log("找不到 GM_TeleportToLocation")
        return
    end
    local ok = pcall(function()
        return fn(cm, { X = state.x, Y = state.y, Z = state.z })
    end)
    if ok then
        log("已传送到 %.1f / %.1f / %.1f", state.x, state.y, state.z)
    else
        log("传送失败")
    end
end

local function doQuickSave()
    local p = getPos()
    if p == nil then
        log("拿不到坐标（还在主菜单？）")
        return
    end

    state.x, state.y, state.z, state.yaw, state.map = p.X, p.Y, p.Z, p.yaw, p.map
    state.valid = true
    log("记录位置 %.1f / %.1f / %.1f", p.X, p.Y, p.Z)
    saveState()

    local ss = subsystem()
    if ss == nil then
        log("找不到存档子系统，只记录了位置")
        return
    end

    -- 4 = EPBZSaveReason::ManualSave
    local ok, res = pcall(function() return ss:TrySave(4, {}, nil) end)
    if ok then
        local meaning = "未知"
        if res == 0 then meaning = "已立即保存"
        elseif res == 1 then meaning = "已排队"
        elseif res == 2 then meaning = "被拒绝" end
        log("存档结果 %s（%s）", tostring(res), meaning)
    else
        log("存档异常：%s", tostring(res))
    end
end

local function bind(key, label, fn)
    local cb = function()
        log("-------- %s --------", label)
        fn()
        log("------------------------------")
    end
    local ok = pcall(function() RegisterKeyBind(key, cb) end)
    log("注册 %s = %s", label, tostring(ok))
end

log("=========================================")
log("PBZ QuickSave 已加载")
log("  F8=存档+记位置   F9=传送回记录点   F11=坐标")
log("=========================================")

resolvePath()
if loadState() then
    log("读到上次记录点：%.1f / %.1f / %.1f", state.x, state.y, state.z)
else
    log("没有历史记录点（按 F8 创建）")
end

bind(Key.F8, "F8 存档+记位置", doQuickSave)
bind(Key.F9, "F9 传送回记录点", function() teleportToRecorded() end)
bind(Key.F11, "F11 坐标", function()
    local p = getPos()
    if p then log("当前 %.1f / %.1f / %.1f  %s", p.X, p.Y, p.Z, p.map) end
    if state.valid then log("记录 %.1f / %.1f / %.1f", state.x, state.y, state.z) end
end)

log("就绪。")

local ADDON_NAME, LHA = ...
_G.LHA = LHA

LHA.defaults = {
    locked = true,
    tooClose = {
        enabled = true,
        scale = 1.0,
        sound = false,
        pos = { "CENTER", "CENTER", 0, 80 },
    },
    growl = {
        enabled = true,
        sound = true,
        pos = { "TOP", "TOP", 0, -150 },
    },
}

-- Fill in any keys missing from saved data, leaving existing values alone.
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function LHA:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffabd473LHA|r: " .. tostring(msg))
end

function LHA:PlayAlert(soundKitID)
    PlaySound(soundKitID, "Master")
end

----------------------------------------------------------------------
-- Spell API helpers (prefer C_Spell, fall back to the older globals)
----------------------------------------------------------------------

function LHA.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return (GetSpellInfo(spellID))
end

function LHA.GetSpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    return GetSpellTexture(spellID)
end

-- Returns true / false, or nil when the range can't be checked
-- (spell unknown, no ranged weapon, invalid target).
function LHA.IsSpellInRange(spell, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        return C_Spell.IsSpellInRange(spell, unit)
    end
    local r = IsSpellInRange(spell, unit)
    if r == nil then return nil end
    return r == 1
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

function LHA:RegisterEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

----------------------------------------------------------------------
-- Modules
----------------------------------------------------------------------

LHA.modules = {}

function LHA:RegisterModule(name, module)
    module.name = name
    table.insert(self.modules, module)
    return module
end

local function CallAll(method, ...)
    for _, module in ipairs(LHA.modules) do
        if module[method] then
            module[method](module, ...)
        end
    end
end

function LHA:RefreshAll()
    CallAll("Refresh")
end

LHA:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    LHA_DB = CopyDefaults(LHA.defaults, LHA_DB or {})
    LHA.db = LHA_DB
    CallAll("OnInitialize")
end)

LHA:RegisterEvent("PLAYER_LOGIN", function()
    CallAll("OnEnable")
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = getMetadata(ADDON_NAME, "Version") or "?"
    LHA:Print(format("Logan's Hunter Addon v%s loaded. Type |cffffd100/lha|r for options.", version))
end)

----------------------------------------------------------------------
-- Movable frames, lock/unlock, test mode
----------------------------------------------------------------------

LHA.movables = {}

function LHA:ApplyPosition(frame, pos)
    frame:ClearAllPoints()
    frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

-- pos is the saved-variables table for this frame; it is updated in place.
function LHA:MakeMovable(frame, pos, defaultPos)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        f:SetUserPlaced(false)
        local point, _, relPoint, x, y = f:GetPoint()
        pos[1], pos[2], pos[3], pos[4] = point, relPoint, x, y
    end)
    frame:EnableMouse(not self.db.locked)
    self:ApplyPosition(frame, pos)
    table.insert(self.movables, { frame = frame, pos = pos, default = defaultPos })
end

function LHA:SetLocked(locked)
    self.db.locked = locked
    for _, m in ipairs(self.movables) do
        m.frame:EnableMouse(not locked)
    end
    self:RefreshAll()
end

function LHA:ResetPositions()
    for _, m in ipairs(self.movables) do
        for i = 1, 4 do m.pos[i] = m.default[i] end
        self:ApplyPosition(m.frame, m.pos)
    end
end

-- Frames show as a preview while unlocked or during /lha test.
function LHA:IsPreview()
    return not self.db.locked or GetTime() < (self.testUntil or 0)
end

function LHA:StartTest()
    self.testUntil = GetTime() + 10
    self:RefreshAll()
    C_Timer.After(10.1, function() LHA:RefreshAll() end)
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------

SLASH_LHA1 = "/lha"
SlashCmdList.LHA = function(msg)
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "" then
        LHA:OpenSettings()
    elseif cmd == "unlock" then
        LHA:SetLocked(false)
        LHA:Print("Frames unlocked - drag to move, then /lha lock.")
    elseif cmd == "lock" then
        LHA:SetLocked(true)
        LHA:Print("Frames locked.")
    elseif cmd == "test" then
        LHA:StartTest()
        LHA:Print("Showing all frames for 10 seconds.")
    elseif cmd == "reset" then
        LHA:ResetPositions()
        LHA:Print("Frame positions reset.")
    elseif cmd == "probe" then
        LHA.TooClose:Probe()
        LHA.Growl:Probe()
    else
        LHA:Print("/lha - settings | unlock | lock | test | reset | probe")
    end
end

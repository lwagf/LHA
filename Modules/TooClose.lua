-- Shows a red "!!" while the current hostile target is too close to shoot
-- (inside Auto Shot's minimum range: melee range or the deadzone).

local ADDON_NAME, LHA = ...
local M = LHA:RegisterModule("TooClose", {})
LHA.TooClose = M

local TICK = 0.1
local AUTO_SHOT_ID = 75
-- CheckInteractDistance index that covers ~28 yd on this client (verified
-- in-game: true at ~20 yd, false beyond Auto Shot range; works in combat).
local NEAR_INDEX = 1
local SOUND = SOUNDKIT.IG_QUEST_FAILED or 847

local autoShot
local interactBlocked = false -- set if CheckInteractDistance gets blocked in combat
local active = false          -- real (non-preview) alert state
local elapsed = 0
local frame, driver

local function IsValidTarget()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

local function IsNear()
    if interactBlocked and InCombatLockdown() then return nil end
    return CheckInteractDistance("target", NEAR_INDEX)
end

local function IsTooClose()
    local shootable = autoShot and LHA.IsSpellInRange(autoShot, "target")
    if shootable == nil then return false end -- no ranged weapon or can't tell
    if shootable then return false end
    -- Auto Shot is out of range: either under its minimum range or beyond its
    -- maximum. Auto Shot's max range is always beyond the ~28 yd near check,
    -- so "near" means the target is inside the minimum range.
    local near = IsNear()
    if near ~= nil then return near and true or false end
    -- No proximity check available: keep the alert while the target stays
    -- unshootable after we last saw it too close.
    return active
end

local function OnUpdate(_, dt)
    elapsed = elapsed + dt
    if elapsed < TICK then return end
    elapsed = 0
    M:Evaluate()
end

function M:OnInitialize()
    self.db = LHA.db.tooClose
    autoShot = LHA.GetSpellName(AUTO_SHOT_ID)

    frame = CreateFrame("Frame", "LHA_TooCloseFrame", UIParent)
    frame:SetSize(80, 50)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.4)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 40, "THICKOUTLINE")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 0.1, 0.1)
    text:SetText("!!")

    frame:SetScale(self.db.scale)
    LHA:MakeMovable(frame, self.db.pos, LHA.defaults.tooClose.pos)

    driver = CreateFrame("Frame")

    LHA:RegisterEvent("PLAYER_TARGET_CHANGED", function() M:OnTargetChanged() end)
    LHA:RegisterEvent("ADDON_ACTION_BLOCKED", function(_, addon, func)
        if addon == ADDON_NAME and func and func:find("CheckInteractDistance") then
            interactBlocked = true
        end
    end)
end

function M:OnEnable()
    self:OnTargetChanged()
end

function M:OnTargetChanged()
    elapsed = 0
    active = false
    if self.db.enabled and UnitExists("target") then
        driver:SetScript("OnUpdate", OnUpdate)
    else
        driver:SetScript("OnUpdate", nil)
    end
    self:Evaluate()
end

function M:OnSettingsChanged()
    frame:SetScale(self.db.scale)
    LHA:ApplyPosition(frame, self.db.pos)
    self:OnTargetChanged()
end

function M:Evaluate()
    local now = self.db.enabled and IsValidTarget() and IsTooClose() or false
    if now and not active and self.db.sound then
        LHA:PlayAlert(SOUND)
    end
    active = now
    self:Refresh()
end

function M:Refresh()
    frame:SetShown(self.db.enabled and (active or LHA:IsPreview()))
    frame.bg:SetShown(not LHA.db.locked)
end

function M:Probe()
    if not UnitExists("target") then
        LHA:Print("probe: no target")
        return
    end
    local shoot = autoShot and LHA.IsSpellInRange(autoShot, "target")
    LHA:Print(format("probe: combat=%s shoot=%s interact1-4=%s/%s/%s/%s blocked=%s tooClose=%s",
        tostring(InCombatLockdown()), tostring(shoot),
        tostring(CheckInteractDistance("target", 1)), tostring(CheckInteractDistance("target", 2)),
        tostring(CheckInteractDistance("target", 3)), tostring(CheckInteractDistance("target", 4)),
        tostring(interactBlocked), tostring(active)))
end

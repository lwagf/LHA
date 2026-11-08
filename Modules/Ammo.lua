-- Shows how much ammo is left, and warns when it runs low or out.
-- Only applies while a bow, gun or crossbow is equipped.

local _, LHA = ...
local M = LHA:RegisterModule("Ammo", {})
LHA.Ammo = M

local AMMO_SLOT = INVSLOT_AMMO or 0
local RANGED_SLOT = INVSLOT_RANGED or 18
local WEAPON_CLASS = 2
-- Weapon subclasses that fire ammo: bows, guns, crossbows (not thrown or wands).
local USES_AMMO = { [2] = true, [3] = true, [18] = true }
local FALLBACK_ICON = "Interface\\Icons\\INV_Ammo_Arrow_02"
local SOUND = SOUNDKIT.RAID_WARNING or 8959
-- Bags can read as empty just after a loading screen, so stay quiet briefly.
local SOUND_GRACE = 5

local OK, LOW, OUT = 1, 2, 3
local COLORS = {
    [OK] = { 1, 1, 1 },
    [LOW] = { 1, 0.82, 0 },
    [OUT] = { 1, 0.1, 0.1 },
}

local GetItemCountFn = C_Item and C_Item.GetItemCount or GetItemCount
local GetItemInfoInstantFn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local level        -- OK / LOW / OUT, or nil when no ammo-firing weapon is equipped
local count = 0
local severity = OK -- last level seen, so re-equipping a weapon doesn't re-alert
local soundAfter = math.huge
local frame

local function RangedWeaponUsesAmmo()
    local id = GetInventoryItemID("player", RANGED_SLOT)
    if not id then return false end
    local _, _, _, _, _, classID, subclassID = GetItemInfoInstantFn(id)
    return classID == WEAPON_CLASS and USES_AMMO[subclassID] or false
end

-- An empty ammo slot counts as out of ammo.
local function GetAmmoCount()
    local id = GetInventoryItemID("player", AMMO_SLOT)
    if not id then return 0 end
    return GetItemCountFn(id) or 0
end

function M:OnInitialize()
    self.db = LHA.db.ammo

    frame = CreateFrame("Frame", "LHA_AmmoFrame", UIParent)
    frame:SetSize(110, 40)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    frame.glow = frame:CreateTexture(nil, "BORDER")
    frame.glow:SetAllPoints()
    frame.glow:SetColorTexture(1, 0, 0, 0.7)
    frame.glow:Hide()

    frame.pulse = frame.glow:CreateAnimationGroup()
    frame.pulse:SetLooping("BOUNCE")
    local fade = frame.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.15)
    fade:SetDuration(0.5)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(30, 30)
    frame.icon:SetPoint("LEFT", 5, 0)

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
    frame.text:SetPoint("RIGHT", -4, 0)
    frame.text:SetJustifyH("CENTER")

    LHA:MakeMovable(frame, self.db.pos, LHA.defaults.ammo.pos)

    local function Evaluate() M:Evaluate() end
    LHA:RegisterEvent("BAG_UPDATE", Evaluate)
    LHA:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Evaluate)
    LHA:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
        if unit == "player" then Evaluate() end
    end)
    LHA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        soundAfter = GetTime() + SOUND_GRACE
        Evaluate()
    end)
end

function M:OnSettingsChanged()
    self:Evaluate()
end

function M:Evaluate()
    level, count = nil, 0
    if self.db.enabled and RangedWeaponUsesAmmo() then
        count = GetAmmoCount()
        if count == 0 then
            level = OUT
        elseif count <= self.db.lowThreshold then
            level = LOW
        else
            level = OK
        end
    end
    if level then
        if level > severity and self.db.sound and GetTime() >= soundAfter then
            LHA:PlayAlert(SOUND)
        end
        severity = level
    end
    self:Refresh()
end

function M:Refresh()
    local preview = LHA:IsPreview()
    frame:SetShown(self.db.enabled and (level ~= nil or preview))

    -- /lha test shows the out-of-ammo alert; so does an unlocked frame with
    -- no real count to display.
    local testing = GetTime() < (LHA.testUntil or 0)
    local shown, shownCount = level, count
    if testing or not level then
        shown, shownCount = OUT, 0
    end

    frame.icon:SetTexture(GetInventoryItemTexture("player", AMMO_SLOT) or FALLBACK_ICON)
    frame.icon:SetDesaturated(shown == OUT)
    frame.text:SetText(shown == OUT and "OUT" or shownCount)
    frame.text:SetTextColor(unpack(COLORS[shown]))

    local out = shown == OUT and frame:IsShown()
    frame.glow:SetShown(out)
    if out and not frame.pulse:IsPlaying() then
        frame.pulse:Play()
    elseif not out then
        frame.pulse:Stop()
    end
end

function M:Probe()
    local ammoID = GetInventoryItemID("player", AMMO_SLOT)
    LHA:Print(format("probe: ranged=%s usesAmmo=%s ammo=%s itemCount=%s slotCount=%s level=%s",
        tostring(GetInventoryItemID("player", RANGED_SLOT)), tostring(RangedWeaponUsesAmmo()),
        tostring(ammoID), tostring(ammoID and GetItemCountFn(ammoID)),
        tostring(GetInventoryItemCount("player", AMMO_SLOT)), tostring(level)))
end

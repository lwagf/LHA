-- Shows a banner while the pet has Growl autocast on inside a dungeon or raid.

local _, LHA = ...
local M = LHA:RegisterModule("Growl", {})
LHA.Growl = M

local GROWL_ID = 2649
local SOUND = SOUNDKIT.RAID_WARNING or 8959

local growlName
local active = false
local frame

-- Returns true / false, or nil if Growl isn't on the pet bar.
local function GetGrowlAutocast()
    for i = 1, NUM_PET_ACTION_SLOTS or 10 do
        local name, _, _, _, _, autoCastEnabled = GetPetActionInfo(i)
        if name and name == growlName then
            return autoCastEnabled and true or false
        end
    end
    return nil
end

local function IsInDungeonOrRaid()
    local _, instanceType = IsInInstance()
    return instanceType == "party" or instanceType == "raid"
end

function M:OnInitialize()
    self.db = LHA.db.growl
    growlName = LHA.GetSpellName(GROWL_ID)

    frame = CreateFrame("Frame", "LHA_GrowlFrame", UIParent)
    frame:SetSize(240, 44)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexture(LHA.GetSpellTexture(GROWL_ID))

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetTextColor(1, 0.55, 0.1)
    text:SetText("Growl is ON")

    LHA:MakeMovable(frame, self.db.pos, LHA.defaults.growl.pos)

    local function Evaluate() M:Evaluate() end
    LHA:RegisterEvent("PLAYER_ENTERING_WORLD", Evaluate)
    LHA:RegisterEvent("ZONE_CHANGED_NEW_AREA", Evaluate)
    LHA:RegisterEvent("PET_BAR_UPDATE", Evaluate)
    LHA:RegisterEvent("PLAYER_REGEN_ENABLED", Evaluate)
    LHA:RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then Evaluate() end
    end)
end

function M:OnSettingsChanged()
    self:Evaluate()
end

function M:Evaluate()
    local now = self.db.enabled and IsInDungeonOrRaid() and UnitExists("pet")
        and GetGrowlAutocast() or false
    if now and not active and self.db.sound then
        LHA:PlayAlert(SOUND)
    end
    active = now
    self:Refresh()
end

function M:Refresh()
    frame:SetShown(self.db.enabled and (active or LHA:IsPreview()))
end

function M:Probe()
    LHA:Print(format("probe: growl=%s autocast=%s instance=%s pet=%s warning=%s",
        tostring(growlName), tostring(GetGrowlAutocast()), tostring(IsInDungeonOrRaid()),
        tostring(UnitExists("pet")), tostring(active)))
end

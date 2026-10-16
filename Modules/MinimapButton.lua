-- Minimap button via LibDataBroker + LibDBIcon, so button-collector addons
-- can pick it up. Left-click: pet journal. Right-click: settings.

local _, LHA = ...
local M = LHA:RegisterModule("MinimapButton", {})
LHA.MinimapButton = M

local NAME = "LHA"
local ICON = "Interface\\Icons\\Ability_Hunter_Pet_Spider"

local icon

local function OnTooltipShow(tooltip)
    tooltip:AddLine("LHA - Logan's Hunter Addon")
    local p = LHA.JournalTracker.ActiveProfile()
    if p then
        tooltip:AddLine(format("%s · %s battles together", p.name, LHA.Milestones.FormatNumber(p.battles)), 1, 1, 1)
    end
    tooltip:AddLine("|cffffd100Left-click|r pet journal", 0.8, 0.8, 0.8)
    tooltip:AddLine("|cffffd100Right-click|r settings", 0.8, 0.8, 0.8)
end

function M:OnInitialize()
    self.db = LHA.db.minimap
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, {
        type = "launcher",
        label = NAME,
        icon = ICON,
        OnClick = function(_, button) LHA_OnAddonCompartmentClick(NAME, button) end,
        OnTooltipShow = OnTooltipShow,
    })
    icon = LibStub("LibDBIcon-1.0")
    icon:Register(NAME, launcher, self.db)
end

function M:SetShown(show)
    self.db.hide = not show
    if show then icon:Show(NAME) else icon:Hide(NAME) end
end

function M:Toggle()
    self:SetShown(self.db.hide)
end

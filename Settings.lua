-- Settings panel (Blizzard Settings canvas) and addon compartment entry.

local _, LHA = ...
local M = LHA:RegisterModule("Settings", {})

local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 3.0, 0.1
local AMMO_MIN, AMMO_MAX, AMMO_STEP = 50, 1000, 50

local panel, category

local function Header(parent, text, anchor, yOff)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    fs:SetText(text)
    return fs
end

local function Checkbox(parent, label, anchor, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    local text = cb.Text or cb.text
    if not text then
        text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    text:SetText(label)
    cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    return cb
end

local function Button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- Builds a checkbox bound to db[key] that notifies module on change.
local function Option(parent, label, anchor, db, key, module)
    return Checkbox(parent, label, anchor,
        function() return db[key] end,
        function(v)
            db[key] = v
            module:OnSettingsChanged()
        end)
end

local function BuildPanel()
    local db = LHA.db
    panel = CreateFrame("Frame")
    panel.name = "LHA"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("LHA - Logan's Hunter Addon")

    -- Too-close alert
    local h1 = Header(panel, "Too-close alert (!!)", title, -20)
    local tcEnabled = Option(panel, "Show when target is too close to shoot", h1, db.tooClose, "enabled", LHA.TooClose)
    local tcSound = Option(panel, "Play sound when it appears", tcEnabled, db.tooClose, "sound", LHA.TooClose)

    local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", tcSound, "BOTTOMLEFT", 4, -10)
    local function UpdateSizeLabel()
        sizeLabel:SetText(format("Icon size: %.1f", db.tooClose.scale))
    end
    local function ChangeScale(delta)
        local s = db.tooClose.scale + delta
        s = math.max(SCALE_MIN, math.min(SCALE_MAX, s))
        db.tooClose.scale = math.floor(s * 10 + 0.5) / 10
        UpdateSizeLabel()
        LHA.TooClose:OnSettingsChanged()
    end
    local minus = Button(panel, "-", 26, function() ChangeScale(-SCALE_STEP) end)
    minus:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)
    local plus = Button(panel, "+", 26, function() ChangeScale(SCALE_STEP) end)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    panel:HookScript("OnShow", UpdateSizeLabel)

    -- Growl warning
    local h2 = Header(panel, "Growl warning (dungeons & raids)", sizeLabel, -24)
    local grEnabled = Option(panel, "Warn when pet Growl autocast is on", h2, db.growl, "enabled", LHA.Growl)
    local grSound = Option(panel, "Play sound when the warning appears", grEnabled, db.growl, "sound", LHA.Growl)

    -- Pet journal (second column)
    local h4 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h4:SetPoint("TOPLEFT", h1, "TOPLEFT", 320, 0)
    h4:SetText("Pet journal milestones")
    local noModule = { OnSettingsChanged = function() end }
    local lChat = Option(panel, "Chat message", h4, db.journal, "milestoneChat", noModule)
    local lFlash = Option(panel, "Center-screen flash", lChat, db.journal, "milestoneFlash", noModule)
    local lSound = Option(panel, "Sound", lFlash, db.journal, "milestoneSound", noModule)
    local lGroup = Option(panel, "Announce to party/raid chat", lSound, db.journal, "announceGroup", noModule)
    local lGuild = Option(panel, "Announce to guild chat", lGroup, db.journal, "announceGuild", noModule)
    local openCard = Button(panel, "Open pet journal", 140, function() LHA.PetCard:Show() end)
    openCard:SetPoint("TOPLEFT", lGuild, "BOTTOMLEFT", 4, -10)

    -- Ammo counter (second column)
    local h5 = Header(panel, "Ammo counter", lGuild, -48)
    local amEnabled = Option(panel, "Show ammo count", h5, db.ammo, "enabled", LHA.Ammo)
    local amSound = Option(panel, "Play sound when low or out", amEnabled, db.ammo, "sound", LHA.Ammo)

    local lowLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lowLabel:SetPoint("TOPLEFT", amSound, "BOTTOMLEFT", 4, -10)
    local function UpdateLowLabel()
        lowLabel:SetText(format("Low at: %d", db.ammo.lowThreshold))
    end
    local function ChangeLow(delta)
        local n = db.ammo.lowThreshold + delta
        db.ammo.lowThreshold = math.max(AMMO_MIN, math.min(AMMO_MAX, n))
        UpdateLowLabel()
        LHA.Ammo:OnSettingsChanged()
    end
    local lowMinus = Button(panel, "-", 26, function() ChangeLow(-AMMO_STEP) end)
    lowMinus:SetPoint("LEFT", lowLabel, "RIGHT", 10, 0)
    local lowPlus = Button(panel, "+", 26, function() ChangeLow(AMMO_STEP) end)
    lowPlus:SetPoint("LEFT", lowMinus, "RIGHT", 4, 0)
    panel:HookScript("OnShow", UpdateLowLabel)

    -- Frames
    local h3 = Header(panel, "Frames", grSound, -16)
    local unlocked = Checkbox(panel, "Unlock frames (drag to move)", h3,
        function() return not db.locked end,
        function(v) LHA:SetLocked(not v) end)

    local minimap = Checkbox(panel, "Show minimap button", unlocked,
        function() return not db.minimap.hide end,
        function(v) LHA.MinimapButton:SetShown(v) end)

    local test = Button(panel, "Test (10s)", 110, function() LHA:StartTest() end)
    test:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 4, -10)
    local reset = Button(panel, "Reset positions", 130, function() LHA:ResetPositions() end)
    reset:SetPoint("LEFT", test, "RIGHT", 8, 0)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "LHA")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function M:OnInitialize()
    BuildPanel()
end

function LHA:OpenSettings()
    if category then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Called twice: the first call can land on the wrong page.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Left-click opens the pet journal, any other button opens settings.
function LHA_OnAddonCompartmentClick(_, button)
    if button == "LeftButton" then
        LHA.PetCard:Toggle()
    else
        LHA:OpenSettings()
    end
end

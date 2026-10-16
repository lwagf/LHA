-- The pet profile card: summary, stats, memories and a list of every pet.

local _, LHA = ...
local Loyalty = LHA.Loyalty
local Card = {}
LHA.PetCard = Card

local WIDTH, HEIGHT = 640, 440
local LIST_WIDTH = 170
local MODEL_SIZE = 150
local MODEL_FACING = -0.6 -- three-quarter view toward the camera
local GREY = "|cff888888"

local frame, selectedKey
local listButtons = {}

local function FormatDuration(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    return format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
end

local function FormatDate(t)
    return t and date("%d %b %Y", t) or "?"
end

local function MetLine(p)
    local met = p.met
    if not met then return "" end
    -- Pets LHA didn't see being tamed: we don't know where you met.
    if met.kind ~= "tame" then
        return format("Together since before LHA  %s· tracked since %s (Lv. %s)|r",
            GREY, FormatDate(met.date), tostring(met.level or "?"))
    end
    local where = met.zone or "?"
    if met.subzone and met.subzone ~= "" and met.subzone ~= met.zone then
        where = where .. " (" .. met.subzone .. ")"
    end
    return format("Met at Lv. %s in %s  %s· %s|r", tostring(met.level or "?"), where, GREY, FormatDate(met.date))
end

local function StatsText(p)
    local N = LHA.Milestones.FormatNumber
    return table.concat({
        format("Time together   %s  %s(%s in combat)|r", FormatDuration(p.timeOut), GREY, FormatDuration(p.timeCombat)),
        format("Battles together  %s", N(p.battles)),
        format("Bosses %d  ·  Rares %d  ·  World bosses %d", p.bosses, p.rares, p.worldBosses),
    }, "\n")
end

local function MemoriesText(p)
    if #p.memories == 0 then
        return GREY .. "No memories yet - go make some!|r"
    end
    local lines = {}
    for i = #p.memories, 1, -1 do
        local m = p.memories[i]
        local showZone = m.zone and m.zone ~= "" and not m.text:find(m.zone, 1, true)
        local zone = showZone and (" " .. GREY .. "(" .. m.zone .. ")|r") or ""
        table.insert(lines, GREY .. date("%d %b %Y", m.date) .. "|r  " .. m.text .. zone)
    end
    return table.concat(lines, "\n")
end

Card.MemoriesText = MemoriesText -- exposed for tests
Card.MetLine = MetLine

-- Current pet first, then everyone else by most recently seen.
local function SortedKeys()
    local active = LHA.LoyaltyTracker:GetActiveKey()
    local keys = {}
    for key in pairs(Loyalty.db.pets) do table.insert(keys, key) end
    table.sort(keys, function(a, b)
        if a == active then return true end
        if b == active then return false end
        return (Loyalty.db.pets[a].lastSeen or 0) > (Loyalty.db.pets[b].lastSeen or 0)
    end)
    return keys
end

----------------------------------------------------------------------
-- Building
----------------------------------------------------------------------

local function Text(parent, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    return fs
end

local function Build()
    frame = CreateFrame("Frame", "LHA_PetCard", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:Hide()
    table.insert(UISpecialFrames, "LHA_PetCard") -- Escape closes it

    local title = frame.TitleText or Text(frame, "GameFontNormal")
    if not frame.TitleText then title:SetPoint("TOP", 0, -6) end
    title:SetText("Pet Loyalty")

    local left = 14
    local rightEdge = WIDTH - LIST_WIDTH - 20

    -- Model
    local model = CreateFrame("PlayerModel", nil, frame)
    model:SetSize(MODEL_SIZE, MODEL_SIZE)
    model:SetPoint("TOPLEFT", left, -32)
    model:SetScript("OnModelLoaded", function(m) m:SetFacing(MODEL_FACING) end)
    frame.model = model

    -- Summary
    local name = Text(frame, "GameFontNormalHuge")
    name:SetPoint("TOPLEFT", model, "TOPRIGHT", 12, -6)
    frame.name = name

    local info = Text(frame)
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
    frame.info = info

    local orig = Text(frame, "GameFontDisable")
    orig:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -4)
    frame.orig = orig

    local met = Text(frame)
    met:SetPoint("TOPLEFT", orig, "BOTTOMLEFT", 0, -12)
    met:SetWidth(rightEdge - left - MODEL_SIZE - 12)
    frame.met = met

    -- Stats
    local stats = Text(frame)
    stats:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 0, -12)
    stats:SetSpacing(4)
    frame.stats = stats

    -- Memories
    local memHeader = Text(frame, "GameFontNormal")
    memHeader:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", 0, -14)
    memHeader:SetText("Memories")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", memHeader, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", rightEdge - 22, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(rightEdge - left - 30, 1)
    scroll:SetScrollChild(content)
    local memories = Text(content)
    memories:SetPoint("TOPLEFT")
    memories:SetWidth(rightEdge - left - 30)
    memories:SetSpacing(3)
    frame.memories, frame.memContent = memories, content

    -- Pet list
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.15)
    divider:SetPoint("TOPLEFT", frame, "TOPRIGHT", -LIST_WIDTH - 10, -30)
    divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -LIST_WIDTH - 10, 10)
    divider:SetWidth(1)

    local listHeader = Text(frame, "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", frame, "TOPRIGHT", -LIST_WIDTH, -34)
    listHeader:SetText("Pets")
    frame.listHeader = listHeader
end

local function ListButton(i)
    local b = listButtons[i]
    if b then return b end
    b = CreateFrame("Button", nil, frame)
    b:SetSize(LIST_WIDTH - 14, 20)
    b:SetPoint("TOPLEFT", frame.listHeader, "BOTTOMLEFT", 0, -6 - (i - 1) * 22)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.text = Text(b)
    b.text:SetPoint("LEFT", 4, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b:SetScript("OnClick", function(self) Card:Show(self.key) end)
    listButtons[i] = b
    return b
end

----------------------------------------------------------------------
-- Refreshing
----------------------------------------------------------------------

function Card:Refresh()
    if not frame or not frame:IsShown() then return end
    local pets = Loyalty.db.pets
    local keys = SortedKeys()
    if not pets[selectedKey or ""] then selectedKey = keys[1] end
    local active = LHA.LoyaltyTracker:GetActiveKey()

    -- List
    for i, key in ipairs(keys) do
        local b, p = ListButton(i), pets[key]
        b.key = key
        local label = format("%s  %sLv%s|r", p.name, GREY, tostring(p.level or "?"))
        if p.retired then label = GREY .. p.name .. " (retired)|r" end
        if key == selectedKey then label = "> " .. label end
        b.text:SetText(label)
        b:Show()
    end
    for i = #keys + 1, #listButtons do listButtons[i]:Hide() end

    local p = pets[selectedKey or ""]
    if not p then
        frame.name:SetText("No pets yet")
        frame.info:SetText("Summon or tame a pet to start its story.")
        frame.orig:SetText("")
        frame.met:SetText("")
        frame.stats:SetText("")
        frame.memories:SetText("")
        frame.model:ClearModel()
        return
    end

    frame.name:SetText(p.name .. (p.retired and (GREY .. "  (retired)|r") or ""))
    local info = format("Lv. %s %s", tostring(p.level or "?"), p.family or "")
    if p.loyalty then info = info .. "  ·  " .. p.loyalty end
    frame.info:SetText(info)
    frame.orig:SetText(p.creatureName and ("orig. " .. p.creatureName) or "")
    frame.met:SetText(MetLine(p))
    frame.stats:SetText(StatsText(p))
    frame.memories:SetText(MemoriesText(p))
    frame.memContent:SetHeight(math.max(1, frame.memories:GetStringHeight()))

    -- Only reload the model when the selection (or whether it's the live pet)
    -- changes, so the idle animation isn't restarted on every stat refresh.
    local modelKey = selectedKey .. (selectedKey == active and ":live" or "")
    if frame.modelKey ~= modelKey then
        frame.modelKey = modelKey
        frame.model:ClearModel()
        if selectedKey == active then
            frame.model:SetUnit("pet")
        elseif p.npcID then
            frame.model:SetCreature(p.npcID)
        end
        frame.model:SetFacing(MODEL_FACING)
    end
end

function Card:Show(key)
    if not frame then Build() end
    selectedKey = key or LHA.LoyaltyTracker:GetActiveKey() or Loyalty.db.current or selectedKey
    -- Always reload the model on open: the live pet may have been despawned
    -- and resummoned (or died and revived) while the card was closed.
    frame.modelKey = nil
    frame:Show()
    self:Refresh()
end

function Card:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

Loyalty:OnChanged(function() Card:Refresh() end)

LHA:RegisterEvent("UNIT_MODEL_CHANGED", function(_, unit)
    if unit == "pet" and frame and frame:IsShown() then
        frame.modelKey = nil
        Card:Refresh()
    end
end)

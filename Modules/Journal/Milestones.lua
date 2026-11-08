-- Milestone thresholds, memories and announcements (chat, flash, sound, and
-- optionally party/raid/guild chat).

local _, LHA = ...
local Journal = LHA.Journal
local Milestones = {}
LHA.Milestones = Milestones

local BATTLE_THRESHOLDS = { 100, 500, 1000, 2500, 5000 }
local BATTLE_STEP_AFTER = 5000
local HOUR_THRESHOLDS = { 10, 25, 50, 100, 250, 500 }
local SOUND = SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 or SOUNDKIT.READY_CHECK or 8960
local GREEN = "|cffabd473"

local function FormatNumber(n)
    local s = tostring(n)
    local result = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (result:gsub("^,", ""))
end
Milestones.FormatNumber = FormatNumber

local function NextBattleThreshold(last)
    for _, t in ipairs(BATTLE_THRESHOLDS) do
        if t > last then return t end
    end
    return (math.floor(last / BATTLE_STEP_AFTER) + 1) * BATTLE_STEP_AFTER
end

local function NextHourThreshold(last)
    for _, t in ipairs(HOUR_THRESHOLDS) do
        if t > last then return t end
    end
    return nil
end

local function SendPublic(text)
    local db = LHA.db.journal
    if db.announceGroup then
        if IsInRaid() then
            SendChatMessage(text, "RAID")
        elseif IsInGroup() then
            SendChatMessage(text, "PARTY")
        end
    end
    if db.announceGuild and IsInGuild() then
        SendChatMessage(text, "GUILD")
    end
end

-- text: shown locally and stored as the memory, e.g. "1,000 battles together".
-- publicText: first-person message for party/raid/guild chat.
function Milestones:Announce(p, memoryType, text, publicText)
    Journal:AddMemory(p, memoryType, text)
    local db = LHA.db.journal
    local line = p.name .. " - " .. text .. "!"
    if db.milestoneChat then
        LHA:Print(GREEN .. p.name .. "|r - " .. text .. "!")
    end
    if db.milestoneFlash and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, GREEN .. line .. "|r", ChatTypeInfo["RAID_WARNING"])
    end
    if db.milestoneSound then
        LHA:PlayAlert(SOUND)
    end
    SendPublic("[LHA] " .. publicText)
end

function Milestones:CheckBattles(p)
    local nextBattles = NextBattleThreshold(p.milestones.battles)
    if p.battles < nextBattles then return end
    p.milestones.battles = nextBattles
    local n = FormatNumber(nextBattles)
    self:Announce(p, "battles", n .. " battles together",
        format("%s and I have fought %s battles together!", p.name, n))
end

function Milestones:CheckTime(p)
    local hours = p.timeOut / 3600
    local nextHours = NextHourThreshold(p.milestones.hours)
    while nextHours and hours >= nextHours do
        p.milestones.hours = nextHours
        self:Announce(p, "hours", nextHours .. " hours together",
            format("%s and I have now spent %d hours together!", p.name, nextHours))
        nextHours = NextHourThreshold(nextHours)
    end
end

local NOTABLE = {
    boss = { text = "First boss: %s", public = "%s and I defeated %s together for the first time!" },
    rare = { text = "Rare: %s", public = "%s and I took down the rare %s!" },
    worldboss = { text = "World boss: %s", public = "%s and I defeated the world boss %s!" },
}

-- Announces the first kill of a given boss/rare/world boss for this pet.
function Milestones:Notable(p, kind, name)
    if LHA.IsSecret(name) then return end -- can't be saved or announced
    local key = kind .. ":" .. name
    if p.seenNotable[key] then return end
    p.seenNotable[key] = true
    local def = NOTABLE[kind]
    self:Announce(p, kind, format(def.text, name), format(def.public, p.name, name))
end

function Milestones:Tamed(p)
    local met = p.met
    local where = met.zone or "?"
    self:Announce(p, "tame", format("Met at Lv. %d in %s", met.level or 0, where),
        format("I tamed a new companion: %s (Lv. %d %s) in %s!",
            p.name, met.level or 0, p.creatureName or p.family or "beast", where))
end

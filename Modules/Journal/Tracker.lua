-- Records time together, battles, notable kills and tames for the pet
-- currently out. (This client forbids the combat log, so nothing here uses it.)

local _, LHA = ...
local Journal = LHA.Journal
local M = LHA:RegisterModule("JournalTracker", {})
LHA.JournalTracker = M

local TAME_BEAST_ID = 1515
local TAME_WINDOW = 10   -- seconds between the tame channel ending and the new pet appearing
local TICK = 60

-- Target classifications that count as notable, and the kind they're logged as.
local NOTABLE_KIND = { rare = "rare", rareelite = "rare", worldboss = "worldboss" }

local petGUID
local activeKey                   -- profile key of the pet currently out
local outSince, combatSince       -- GetTime() marks, flushed into the profile
local engagedGUID                 -- notable target we've been in combat with
local tame                        -- Tame Beast snapshot
local lastEncounter               -- last ENCOUNTER_END payload, for /lha probe

local function ActiveProfile()
    return Journal:GetProfile(activeKey)
end
M.ActiveProfile = ActiveProfile

function M:GetActiveKey()
    return activeKey
end

----------------------------------------------------------------------
-- Time
----------------------------------------------------------------------

function M:FlushTime()
    local p = ActiveProfile()
    if not p then return end
    local now = GetTime()
    if outSince then
        p.timeOut = p.timeOut + (now - outSince)
        outSince = now
    end
    if combatSince then
        p.timeCombat = p.timeCombat + (now - combatSince)
        combatSince = now
    end
    LHA.Milestones:CheckTime(p)
end

----------------------------------------------------------------------
-- Pet changes
----------------------------------------------------------------------

function M:AssignMet(p)
    if tame and tame.stoppedAt and GetTime() - tame.stoppedAt <= TAME_WINDOW then
        p.met = { kind = "tame", level = tame.level, zone = tame.zone, subzone = tame.subzone, date = tame.date }
        p.creatureName = tame.name
        tame = nil
        LHA.Milestones:Tamed(p)
    else
        p.met = {
            kind = "seen",
            level = UnitLevel("pet"),
            zone = GetZoneText(),
            subzone = GetSubZoneText(),
            date = time(),
        }
    end
end

function M:UpdatePet()
    Journal:SyncStable()
    petGUID = UnitExists("pet") and UnitGUID("pet") or nil
    local key = Journal:GetCurrentPetKey()
    if key == activeKey then
        local p = ActiveProfile()
        if p then
            Journal:RefreshInfo(p)
            Journal:NotifyChanged()
        end
        return
    end

    -- Close out the previous pet before switching.
    self:FlushTime()
    outSince, combatSince = nil, nil
    activeKey = key

    if key then
        local p = Journal:GetProfile(key)
        if not p then
            p = Journal:CreateProfile(key)
            self:AssignMet(p)
        end
        Journal:RefreshInfo(p)
        Journal.db.current = key
        outSince = GetTime()
        if UnitAffectingCombat("player") then combatSince = outSince end
    end
    Journal:NotifyChanged()
end

function M:OnPetNameUpdate()
    local key = Journal:GetCurrentPetKey()
    -- Same pet object with a new name means a rename; anything else is a pet change.
    if activeKey and key and key ~= activeKey and petGUID and UnitGUID("pet") == petGUID then
        activeKey = Journal:Rename(activeKey, key, UnitName("pet"))
        Journal.db.current = activeKey
        Journal:NotifyChanged()
    else
        self:UpdatePet()
    end
end

----------------------------------------------------------------------
-- Battles and notable kills
----------------------------------------------------------------------

function M:OnCombatStart()
    local p = ActiveProfile()
    if not p then return end
    combatSince = GetTime()
    p.battles = p.battles + 1
    LHA.Milestones:CheckBattles(p)
    self:CheckTarget()
    Journal:NotifyChanged()
end

-- Remembers a notable target we're fighting, and records it if it has died.
function M:CheckTarget()
    if not UnitExists("target") then return end
    local guid = UnitGUID("target")
    local class = UnitClassification("target")
    -- Secret values can't be compared or looked up, so this target can't be tracked.
    if LHA.IsSecret(guid) or LHA.IsSecret(class) then return end
    if UnitIsDead("target") then
        if guid == engagedGUID then
            engagedGUID = nil
            if not UnitIsTapDenied("target") then
                self:NotableKill(class, UnitName("target"))
            end
        end
    elseif UnitAffectingCombat("player") and NOTABLE_KIND[class]
        and UnitCanAttack("player", "target") then
        engagedGUID = guid
    end
end

function M:NotableKill(class, name)
    local p = ActiveProfile()
    local kind = NOTABLE_KIND[class]
    if not p or not kind then return end
    if kind == "worldboss" then
        p.worldBosses = p.worldBosses + 1
    else
        p.rares = p.rares + 1
    end
    LHA.Milestones:Notable(p, kind, name)
    Journal:NotifyChanged()
end

function M:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    lastEncounter = { id = encounterID, name = encounterName, success = success }
    local p = ActiveProfile()
    if not p or success ~= 1 then return end
    p.bosses = p.bosses + 1
    LHA.Milestones:Notable(p, "boss", encounterName)
    Journal:NotifyChanged()
end

function M:OnTick()
    if activeKey then
        self:FlushTime()
        Journal:NotifyChanged()
    end
end

----------------------------------------------------------------------
-- Tame / met
----------------------------------------------------------------------

function M:OnTameStart()
    tame = {
        name = UnitName("target"),
        level = UnitLevel("target"),
        zone = GetZoneText(),
        subzone = GetSubZoneText(),
        date = time(),
    }
end

function M:OnTameStop()
    if tame then tame.stoppedAt = GetTime() end
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

function M:OnInitialize()
    LHA:RegisterEvent("UNIT_PET", function(_, unit)
        if unit == "player" then M:UpdatePet() end
    end)
    LHA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        M:UpdatePet()
        -- Stable data can arrive from the server a little after login.
        C_Timer.After(5, function() M:UpdatePet() end)
        C_Timer.After(30, function() M:UpdatePet() end)
    end)
    -- Opening the stable master always has fresh stable data.
    LHA:RegisterEvent("PET_STABLE_SHOW", function() M:UpdatePet() end)
    LHA:RegisterEvent("PET_STABLE_UPDATE", function() M:UpdatePet() end)
    LHA:RegisterEvent("UNIT_NAME_UPDATE", function(_, unit)
        if unit == "pet" then M:OnPetNameUpdate() end
    end)
    LHA:RegisterEvent("UNIT_LEVEL", function(_, unit)
        if unit == "pet" then M:UpdatePet() end
    end)
    LHA:RegisterEvent("PET_UI_UPDATE", function() M:UpdatePet() end)

    LHA:RegisterEvent("PLAYER_REGEN_DISABLED", function() M:OnCombatStart() end)
    LHA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        M:FlushTime()
        combatSince = nil
    end)
    LHA:RegisterEvent("PLAYER_LOGOUT", function() M:FlushTime() end)

    LHA:RegisterEvent("ENCOUNTER_END", function(_, ...) M:OnEncounterEnd(...) end)
    LHA:RegisterEvent("PLAYER_TARGET_CHANGED", function() M:CheckTarget() end)
    LHA:RegisterEvent("UNIT_HEALTH", function(_, unit)
        if unit == "target" then M:CheckTarget() end
    end)

    LHA:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellID)
        if unit == "player" and spellID == TAME_BEAST_ID then M:OnTameStart() end
    end)
    LHA:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit, _, spellID)
        if unit == "player" and spellID == TAME_BEAST_ID then M:OnTameStop() end
    end)

    if PetAbandon then
        hooksecurefunc("PetAbandon", function()
            if activeKey then Journal:Retire(activeKey) end
        end)
    end
end

function M:OnEnable()
    -- The pet is picked up on PLAYER_ENTERING_WORLD, once the zone is known.
    C_Timer.NewTicker(TICK, function() M:OnTick() end)
end

-- Diagnostics: what does this client's C_StableInfo offer? (/lha probe stable)
local function Describe(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, val in pairs(v) do
        if type(val) ~= "table" then table.insert(parts, tostring(k) .. "=" .. tostring(val)) end
    end
    table.sort(parts)
    return "{" .. table.concat(parts, " ") .. "}"
end

function M:ProbeStable()
    if not C_StableInfo then
        LHA:Print("probe stable: no C_StableInfo")
        return
    end
    local names = {}
    for k in pairs(C_StableInfo) do table.insert(names, k) end
    table.sort(names)
    LHA:Print("probe stable: functions: " .. table.concat(names, ", "))
    if C_StableInfo.GetStablePetInfo then
        for slot = 0, 6 do
            local ok, info = pcall(C_StableInfo.GetStablePetInfo, slot)
            if ok and info then LHA:Print(format("probe stable: slot %d %s", slot, Describe(info))) end
        end
    end
end

function M:Probe()
    local guid = UnitExists("pet") and UnitGUID("pet")
    LHA:Print(format("probe: petGUID=%s npcID=%s family=%s loyalty=%s key=%s",
        tostring(guid), tostring(Journal.ParseNpcID(guid)), tostring(UnitCreatureFamily("pet")),
        tostring(GetPetLoyalty and GetPetLoyalty()), tostring(activeKey)))
    LHA:Print(format("probe: tame=%s lv%s stopped=%s encounter=%s success=%s",
        tostring(tame and tame.name), tostring(tame and tame.level),
        tostring(tame and tame.stoppedAt and format("%.0fs ago", GetTime() - tame.stoppedAt)),
        tostring(lastEncounter and lastEncounter.name), tostring(lastEncounter and lastEncounter.success)))
end

-- Pet profile storage: identity, create/rename/retire, memories.
--
-- Identity: every hunter pet on this client shares the generic creature ID
-- 165189, and the pet GUID changes on every summon. The stable data
-- (C_StableInfo) gives each pet a permanent petNumber, so profiles are keyed
-- "pet:<petNumber>". Stable data may not be loaded yet right after login; until
-- it is, the current pet falls back to a name-based key, and that profile is
-- adopted onto its petNumber as soon as the stable data arrives.

local _, LHA = ...
local Journal = {}
LHA.Journal = Journal

local MAX_STABLE_SLOTS = 20

local listeners = {}

function Journal:OnInitialize()
    self.db = LHA.db.journal
end
LHA:RegisterModule("JournalData", Journal)

-- Listeners (the card) are told whenever any profile changes.
function Journal:OnChanged(fn)
    table.insert(listeners, fn)
end

function Journal:NotifyChanged()
    for _, fn in ipairs(listeners) do fn() end
end

-- Pet GUIDs look like Pet-0-server-instance-zone-npcID-spawnUID.
function Journal.ParseNpcID(guid)
    if not guid then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Pet" and unitType ~= "Creature" then return nil end
    return tonumber(npcID)
end

-- Fallback key, used only until stable data is available.
function Journal.KeyFor(npcID, name, family)
    return tostring(npcID or family or "?") .. ":" .. name
end

function Journal.KeyForPetNumber(petNumber)
    return "pet:" .. petNumber
end

----------------------------------------------------------------------
-- Stable data
----------------------------------------------------------------------

-- Every pet the stable data knows about (active and stabled). Returns an
-- empty list when the data isn't available or hasn't loaded yet; callers must
-- treat that as "unknown", never as "no pets".
function Journal:GetStablePets()
    local pets = {}
    if not (C_StableInfo and C_StableInfo.GetStablePetInfo) then return pets end
    local numActive = C_StableInfo.GetNumActivePets and C_StableInfo.GetNumActivePets() or 1
    for slot = 1, MAX_STABLE_SLOTS do
        local ok, info = pcall(C_StableInfo.GetStablePetInfo, slot)
        if ok and info and info.petNumber then
            info.isActive = slot <= numActive
            table.insert(pets, info)
        end
    end
    return pets
end

-- Finds the stable entry for the pet that's out: the active slot with its
-- name, or the only active slot (just after a rename the stable data can still
-- hold the old name).
function Journal:GetCurrentStableInfo(stablePets)
    local name = UnitName("pet")
    local active = {}
    for _, info in ipairs(stablePets or self:GetStablePets()) do
        if info.isActive then
            if info.name == name then return info end
            table.insert(active, info)
        end
    end
    if #active == 1 then return active[1] end
end

-- Copies the stable data's view of a pet onto its profile.
function Journal:ApplyStableInfo(p, info)
    p.petNumber = info.petNumber
    p.displayID = info.displayID or p.displayID
    p.creatureID = info.creatureID or p.creatureID
    p.name = info.name or p.name
    p.family = info.familyName or p.family
    p.level = info.level or p.level
    p.loyalty = info.loyaltyName or p.loyalty
    p.loyaltyLevel = info.loyaltyLevel or p.loyaltyLevel
end

-- Returns the profile for a stable entry, moving a name-keyed profile (saved
-- before stable data was used, or while it was loading) onto the petNumber key.
function Journal:Adopt(info)
    local pets = self.db.pets
    local key = self.KeyForPetNumber(info.petNumber)
    if pets[key] then return pets[key], key end
    for oldKey, p in pairs(pets) do
        if not p.petNumber and not p.retired and p.name == info.name
            and (not p.family or p.family == info.familyName) then
            pets[oldKey] = nil
            pets[key] = p
            if self.db.current == oldKey then self.db.current = key end
            return p, key
        end
    end
    return nil, key
end

-- Brings profiles in line with the stable data. Stabled pets LHA hasn't seen
-- yet get a "before LHA" profile. The active pet is left to the tracker, so a
-- fresh tame still gets its "Met" record. Returns false if no data was available.
function Journal:SyncStable()
    local stablePets = self:GetStablePets()
    if #stablePets == 0 then return false end
    for _, info in ipairs(stablePets) do
        local p = self:Adopt(info)
        if not p and not info.isActive then
            p = self:NewProfile(info.name)
            p.met = { kind = "seen", level = info.level, date = time() }
            self.db.pets[self.KeyForPetNumber(info.petNumber)] = p
        end
        if p then self:ApplyStableInfo(p, info) end
    end
    return true
end

----------------------------------------------------------------------
-- Profiles
----------------------------------------------------------------------

-- Key for the pet currently out, or nil if there is none (or its name
-- hasn't loaded yet).
function Journal:GetCurrentPetKey()
    if not UnitExists("pet") then return nil end
    local name = UnitName("pet")
    if not name or name == UNKNOWNOBJECT then return nil end
    local info = self:GetCurrentStableInfo()
    if info then
        local _, key = self:Adopt(info)
        return key
    end
    -- Stable data hasn't loaded yet. If exactly one existing pet has this name
    -- and family, it's this one: use its profile rather than starting a
    -- name-keyed placeholder that would be left behind as a duplicate.
    local family = UnitCreatureFamily("pet")
    local matchKey, matches = nil, 0
    for key, p in pairs(self.db.pets) do
        if p.petNumber and not p.retired and p.name == name
            and (not p.family or not family or p.family == family) then
            matchKey, matches = key, matches + 1
        end
    end
    if matches == 1 then return matchKey end
    return self.KeyFor(self.ParseNpcID(UnitGUID("pet")), name, family)
end

function Journal:GetProfile(key)
    return key and self.db.pets[key]
end

function Journal:NewProfile(name)
    return {
        name = name,
        retired = false,
        timeOut = 0, timeCombat = 0,
        battles = 0,
        bosses = 0, rares = 0, worldBosses = 0,
        seenNotable = {},
        milestones = { battles = 0, hours = 0 },
        memories = {},
    }
end

-- Creates the profile for the pet currently out.
function Journal:CreateProfile(key)
    local p = self:NewProfile(UnitName("pet"))
    self.db.pets[key] = p
    self:RefreshInfo(p)
    return p
end

-- Updates the fields that can change while the pet is out. Live unit values
-- win over stable data, which can lag behind (e.g. just after a rename).
function Journal:RefreshInfo(p)
    local info = self:GetCurrentStableInfo()
    if info then self:ApplyStableInfo(p, info) end
    p.name = UnitName("pet") or p.name
    p.family = UnitCreatureFamily("pet") or p.family
    p.level = UnitLevel("pet") or p.level
    p.lastSeen = time()
end

-- Moves a name-keyed profile to a new key after the pet is renamed (only
-- needed while stable data is unavailable; petNumber keys survive renames).
-- Returns the key now in use.
function Journal:Rename(oldKey, newKey, newName)
    local pets = self.db.pets
    if pets[newKey] or not pets[oldKey] then return newKey end
    pets[newKey] = pets[oldKey]
    pets[oldKey] = nil
    pets[newKey].name = newName
    if self.db.current == oldKey then self.db.current = newKey end
    return newKey
end

function Journal:Retire(key)
    local p = self:GetProfile(key)
    if not p then return end
    p.retired = true
    p.retiredDate = time()
    self:NotifyChanged()
end

-- /lha retire <name>: for pets abandoned while LHA wasn't watching.
function Journal:RetireByName(name)
    local matches = {}
    for key, p in pairs(self.db.pets) do
        if p.name and p.name:lower() == name:lower() and not p.retired then
            table.insert(matches, key)
        end
    end
    if #matches == 0 then
        LHA:Print(format("No active pet profile named %s.", name))
    elseif #matches > 1 then
        LHA:Print(format("%d pets are named %s - rename one first so they can be told apart.", #matches, name))
    else
        self:Retire(matches[1])
        LHA:Print(format("%s retired. Thanks for the memories.", self.db.pets[matches[1]].name))
    end
end

function Journal:AddMemory(p, memoryType, text)
    table.insert(p.memories, {
        type = memoryType,
        text = text,
        zone = GetZoneText(),
        date = time(),
        petLevel = p.level,
    })
end

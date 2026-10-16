-- Pet profile storage: identity, create/rename/retire, memories.

local _, LHA = ...
local Loyalty = {}
LHA.Loyalty = Loyalty

local listeners = {}

-- Brings profiles saved by older builds up to the current shape.
local function Normalize(p)
    p.battles = p.battles or 0
    p.milestones.battles = p.milestones.battles or 0
    p.kills, p.petKillingBlows, p.elites, p.milestones.kills = nil, nil, nil, nil
end

function Loyalty:OnInitialize()
    self.db = LHA.db.loyalty
    for _, p in pairs(self.db.pets) do Normalize(p) end
end
LHA:RegisterModule("LoyaltyData", Loyalty)

-- Listeners (the card) are told whenever any profile changes.
function Loyalty:OnChanged(fn)
    table.insert(listeners, fn)
end

function Loyalty:NotifyChanged()
    for _, fn in ipairs(listeners) do fn() end
end

-- Pet GUIDs look like Pet-0-server-instance-zone-npcID-spawnUID.
function Loyalty.ParseNpcID(guid)
    if not guid then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Pet" and unitType ~= "Creature" then return nil end
    return tonumber(npcID)
end

function Loyalty.KeyFor(npcID, name, family)
    return tostring(npcID or family or "?") .. ":" .. name
end

-- Key for the pet currently out, or nil if there is none (or its name
-- hasn't loaded yet).
function Loyalty:GetCurrentPetKey()
    if not UnitExists("pet") then return nil end
    local name = UnitName("pet")
    if not name or name == UNKNOWNOBJECT then return nil end
    return self.KeyFor(self.ParseNpcID(UnitGUID("pet")), name, UnitCreatureFamily("pet"))
end

function Loyalty:GetProfile(key)
    return key and self.db.pets[key]
end

function Loyalty:CreateProfile(key)
    local p = {
        name = UnitName("pet"),
        npcID = self.ParseNpcID(UnitGUID("pet")),
        retired = false,
        timeOut = 0, timeCombat = 0,
        battles = 0,
        bosses = 0, rares = 0, worldBosses = 0,
        seenNotable = {},
        milestones = { battles = 0, hours = 0 },
        memories = {},
    }
    self.db.pets[key] = p
    self:RefreshInfo(p)
    return p
end

-- Updates the fields that can change while the pet is out.
function Loyalty:RefreshInfo(p)
    p.family = UnitCreatureFamily("pet") or p.family
    p.level = UnitLevel("pet") or p.level
    p.loyalty = (GetPetLoyalty and GetPetLoyalty()) or p.loyalty
    p.lastSeen = time()
end

-- Moves a profile to a new key after the pet is renamed. Returns the key now
-- in use (the existing one if a profile already exists for newKey).
function Loyalty:Rename(oldKey, newKey, newName)
    local pets = self.db.pets
    if pets[newKey] or not pets[oldKey] then return newKey end
    pets[newKey] = pets[oldKey]
    pets[oldKey] = nil
    pets[newKey].name = newName
    if self.db.current == oldKey then self.db.current = newKey end
    return newKey
end

function Loyalty:Retire(key)
    local p = self:GetProfile(key)
    if not p then return end
    p.retired = true
    p.retiredDate = time()
    self:NotifyChanged()
end

function Loyalty:AddMemory(p, memoryType, text)
    table.insert(p.memories, {
        type = memoryType,
        text = text,
        zone = GetZoneText(),
        date = time(),
        petLevel = p.level,
    })
end

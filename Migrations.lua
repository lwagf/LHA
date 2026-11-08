-- Upgrade steps for saved data (LHA_DB).
--
-- Each step upgrades data saved by an older build to the next version. Steps
-- run once, in order, before defaults are filled in. To change the shape or
-- meaning of saved data: append a step here. Never edit or reorder existing
-- steps, because players' data may be at any older version.
--
-- Fresh installs start at the latest version and skip every step.

local _, LHA = ...

LHA.migrations = {
    -- 1: the combat log is unavailable on this client, so kills were replaced
    -- by battles together. Kill-based fields can't be converted and are dropped.
    function(db)
        local pets = db.loyalty and db.loyalty.pets
        if not pets then return end
        for _, p in pairs(pets) do
            p.milestones = p.milestones or {}
            p.battles = p.battles or 0
            p.milestones.battles = p.milestones.battles or 0
            p.kills, p.petKillingBlows, p.elites, p.milestones.kills = nil, nil, nil, nil
        end
    end,

    -- 2: the "loyalty" feature was renamed "Pet Journal" (to avoid confusion
    -- with the game's own pet loyalty), including its saved-data key.
    function(db)
        if db.loyalty and not db.journal then
            db.journal = db.loyalty
        end
        db.loyalty = nil
    end,

    -- 3: logging in before stable data loaded could create a name-keyed
    -- placeholder (e.g. "165189:Ryn") beside the pet's real profile, which then
    -- showed as a duplicate. Fold each placeholder into its real profile.
    function(db)
        local journal = db.journal
        local pets = journal and journal.pets
        if not pets then return end
        for key, p in pairs(pets) do
            if not p.petNumber and not p.retired then
                local realKey, matches = nil, 0
                for k, q in pairs(pets) do
                    if q.petNumber and not q.retired and q.name == p.name
                        and (not q.family or not p.family or q.family == p.family) then
                        realKey, matches = k, matches + 1
                    end
                end
                if matches == 1 then
                    local real = pets[realKey]
                    for _, field in ipairs({ "timeOut", "timeCombat", "battles", "bosses", "rares", "worldBosses" }) do
                        real[field] = (real[field] or 0) + (p[field] or 0)
                    end
                    real.seenNotable = real.seenNotable or {}
                    for k in pairs(p.seenNotable or {}) do real.seenNotable[k] = true end
                    real.memories = real.memories or {}
                    for _, m in ipairs(p.memories or {}) do table.insert(real.memories, m) end
                    table.sort(real.memories, function(a, b) return (a.date or 0) < (b.date or 0) end)
                    pets[key] = nil
                    if journal.current == key then journal.current = realKey end
                end
            end
        end
    end,
}

LHA.DB_VERSION = #LHA.migrations

-- Brings db up to DB_VERSION. db.version is missing on data saved before
-- versioning existed, which counts as version 0.
function LHA:Migrate(db)
    for version = (db.version or 0) + 1, self.DB_VERSION do
        self.migrations[version](db)
    end
    db.version = self.DB_VERSION
end

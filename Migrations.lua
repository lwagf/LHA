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

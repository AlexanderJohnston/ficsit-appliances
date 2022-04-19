local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local binser = Deps("bakpakin/binser:binser", "0.0-8")
local DB = Deps("lib/database")
local DBEntry = Deps("lib/database_entry")
local HistoryEntry = Deps("lib/history_entry")
local History = class("History")
function History:initialize(o)
    o = o or {}
    self.entries = o.entries or {}
    self.retention = o.retention or CONFIG.retention
    self.frequency = o.frequency or CONFIG.frequency
end

function History:record(db, duration)
    table.insert(self.entries, HistoryEntry:new{
        db = db,
        duration = duration
    })
    self:prune()
end

function History:size()
    return #self.entries
end

function History:prune()
    local cutoff = computer.millis() / 1000 - self.retention
    local i = 1
    while i <= #self.entries do
        if self.entries[i].time < cutoff then
            table.remove(self.entries, i)
        else
            i = i + 1
        end
    end
end

function History:rate_per_minute(item_type, duration)
    local oldest_i = 1
    while oldest_i < #self.entries and self.entries[oldest_i]:age() > duration do
        oldest_i = oldest_i + 1
    end
    local oldest = self.entries[oldest_i]
    local newest = self.entries[#self.entries]

    local delta = newest.db:entry(item_type).count - oldest.db:entry(item_type).count
    local elapsed_seconds = newest.time - oldest.time
    local elapsed_minutes = elapsed_seconds / 60
    return math.floor(delta / elapsed_minutes)
end

function History:time_to_next_snapshot()
    if self.entries == nil then
        self.entries = {}
        return 0
    end
    if #self.entries == 0 then
        return 0
    end
    return math.ceil(self.frequency - self:last():age())
end

function History:last()
    return self.entries[#self.entries]
end

function History:_serialize()
    local raw_history_entries = {}
    for i, history_entry in pairs(self.entries) do
        local raw_db_entries = {}
        for j, db_entry in pairs(history_entry.db.entries) do
            raw_db_entries[j] = {db_entry.count, db_entry.storage_capacity, db_entry.item_type_index}
        end
        raw_history_entries[i] = {history_entry.time, history_entry.duration, raw_db_entries}
    end
    return raw_history_entries
end
function History._deserialize(raw_history_entries)
    local now = computer.millis() / 1000
    local last = raw_history_entries[#raw_history_entries][1]

    local h = History:new()
    for i, raw_history_entry in pairs(raw_history_entries) do
        local history_entry = HistoryEntry:new{
            -- Timekeeping is messy (see https://github.com/Panakotta00/FicsIt-Networks/issues/200),
            -- so pretend that the last snapshot happened NOW.
            time = now - (last - raw_history_entry[1]),
            duration = raw_history_entry[2],
            db = DB:new()
        }
        for j, raw_db_entry in pairs(raw_history_entry[3]) do
            local db_entry = DBEntry:new{
                count = raw_db_entry[1],
                storage_capacity = raw_db_entry[2],
                item_type_index = raw_db_entry[3]
            }
            history_entry.db.entries[j] = db_entry
        end
        h.entries[i] = history_entry
    end
    return h
end
binser.registerClass(History)
return History
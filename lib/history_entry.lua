local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
HistoryEntry = class("HistoryEntry")
function HistoryEntry:initialize(o)
    self.time = o.time or computer.millis() / 1000
    self.db = o.db
    self.duration = o.duration
end

function HistoryEntry:age()
    return math.floor(computer.millis() / 1000 - self.time)
end
return HistoryEntry
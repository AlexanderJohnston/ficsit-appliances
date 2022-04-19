local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local item_type_registry = Deps("lib/item_type_registry")
local Database_Entry = class("Database_Entry")
function Database_Entry:initialize(o)
    self.item_type_index = o.item_type_index
    self.count = o.count or 0
    self.storage_capacity = o.storage_capacity or 0
end

function Database_Entry:record_items(count)
    self.count = self.count + count
    return self
end

function Database_Entry:record_capacity(stacks)
    self.storage_capacity = self.storage_capacity + stacks * self:item_type().max
    return self
end

function Database_Entry:get_fill_percent()
    return math.floor(self.count / self.storage_capacity * 100)
end

function Database_Entry:item_type()
    return item_type_registry:get(self.item_type_index)
end 
return Database_Entry
local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local item_type_registry = Deps("lib/item_type_registry")
local database_entry  = Deps("lib/database_entry")

local Database = class("Database")
function Database:initialize()
    self.entries = {}
end

function Database:entry(item_type)
    local item_type_index = item_type_registry:register(item_type)
    if self.entries[item_type_index] == nil then
        self.entries[item_type_index] = database_entry:new{
            item_type_index = item_type_index
        }
    end
    return self.entries[item_type_index]
end
return Database
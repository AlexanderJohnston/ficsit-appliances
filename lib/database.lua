local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local item_type_registry = Deps("lib/item_type_registry")
local database_entry  = Deps("lib/database_entry")

local Database = class("Database")
function Database:initialize()
    self.registry = item_type_registry:new()
end

function Database:entry(item_type)
    local registry = self.registry:register(item_type)
    if self.registry.entries[item_type_index] == nil then
        self.registry.entries[item_type_index] = database_entry:new{
            item_type_index = item_type_index
        }
    end
    self.registry = registry
    return self.registry.entries[item_type_index]
end
return Database
local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local binser = Deps("bakpakin/binser:binser", "0.0-8")
local ItemTypeRegistry = class("ItemTypeRegistry")
function ItemTypeRegistry:initialize()
    self.entries = {}
    self.lookup = {}
end
function ItemTypeRegistry:register(item_type)
    if self.lookup[item_type.name] == nil then
        table.insert(self.entries, {
            name = item_type.name,
            max = item_type.max
        })
        self.lookup[item_type.name] = #self.entries
    end
    return self.lookup[item_type.name]
end
function ItemTypeRegistry:get(index)
    return self.entries[index]
end
function ItemTypeRegistry:_serialize()
    return self.entries
end
function ItemTypeRegistry._deserialize(entries)
    local registry = ItemTypeRegistry:new()
    registry.entries = entries
    for i, entry in pairs(entries) do
        registry.lookup[entry.name] = i
    end
    return registry
end
binser.registerClass(ItemTypeRegistry)
return ItemTypeRegistry
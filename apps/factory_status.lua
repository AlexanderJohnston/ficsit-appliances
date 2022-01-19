local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local inspect = Deps("kikito/inspect.lua:inspect", "v3.1.2")

local EntryBuilder = class("EntryBuilder")
function EntryBuilder:initialize(o)
    o = o or {}
    self.productivities = {}
    self.statuses = {}
end
function EntryBuilder:record(productivity, inventories)
    table.insert(self.productivities, productivity)
    local status = "Working"
    local full_inventories = 0
    local empty_inventories = 0

    for _, inventory in pairs(inventories) do
        local full_stacks = 0
        local empty_stacks = 0
        for nStack = 0, inventory.size - 1, 1 do
            local stack = inventory:getStack(nStack)
            if stack.count == stack.item.max then
                full_stacks = full_stacks + 1
            elseif stack.count == 0 then
                empty_stacks = empty_stacks + 1
            end
        end
        if full_stacks == inventory.size then
            full_inventories = full_inventories + 1
        elseif empty_stacks == inventory.size then
            empty_inventories = empty_inventories + 1
        end
    end

    if full_inventories == #inventories then
        status = "BackedUp"
    elseif empty_inventories == #inventories then
        status = "Starved"
    end

    if self.statuses[status] == nil then
        self.statuses[status] = 0
    end
    self.statuses[status] = self.statuses[status] + 1
end
function EntryBuilder:build()
    local sum_productivity = 0
    for _, productivity in pairs(self.productivities) do
        sum_productivity = sum_productivity + productivity
    end
    return {
        productivity = sum_productivity / #self.productivities,
        statuses = self.statuses
    }
end

local SnapshotBuilder = class("SnapshotBuilder")
function SnapshotBuilder:initialize(o)
    o = o or {}
    self.entry_builders = {}
end
function SnapshotBuilder:record(name, productivity, inventories)
    if self.entry_builders[name] == nil then
        self.entry_builders[name] = EntryBuilder:new()
    end
    self.entry_builders[name]:record(productivity, inventories)
end
function SnapshotBuilder:build()
    local entries = {}
    for name, entry_builder in pairs(self.entry_builders) do
        entries[name] = entry_builder:build()
    end
    return entries
end

local function main()
    local builder = SnapshotBuilder:new()
    local factories = component.proxy(component.findComponent(findClass("Factory")))
    for _, factory in pairs(factories) do
        builder:record(factory:getRecipe().name, factory.productivity, factory:getInventories())
    end
    print(inspect(builder:build()))
end

return main

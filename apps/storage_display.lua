local fs = Deps("lib/fs")
local binser = Deps("bakpakin/binser:binser", "0.0-8")
local class = Deps("kikito/middleclass:middleclass", "v4.1.1")
local time = Deps("lib/time")
local shellsort = Deps("third_party/shellsort")
local hw = Deps("lib/hw")

CONFIG = {
    main_display = "7FC05BBE4B398CD7430CFDAF66DDCC17",
    history_file = "/storage_display/history.binser"
}

BLACK = {0, 0, 0, 1}
WHITE = {1, 1, 1, 1}
GRAY30 = {0.3, 0.3, 0.3, 1}
GRAY50 = {0.5, 0.5, 0.5, 1}
GREEN = {0, 1, 0, 1}
RED = {1, 0, 0, 1}
YELLOW = {1, 1, 0, 1}

local ItemTypeRegistry = class("ItemTypeRegistry")
binser.registerClass(ItemTypeRegistry)
ItemTypeRegistry.static._template = {"entries", "lookup"}
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
local item_type_registry = ItemTypeRegistry:new()

DB = class("DB")
binser.registerClass(DB)
DB.static._template = {"entries"}
function DB:initialize()
    self.entries = {}
end

function DB:entry(item_type)
    local item_type_index = item_type_registry:register(item_type)
    if self.entries[item_type_index] == nil then
        self.entries[item_type_index] = DBEntry:new{
            item_type_index = item_type_index
        }
    end
    return self.entries[item_type_index]
end

DBEntry = class("DBEntry")
binser.registerClass(DBEntry)
DBEntry.static._template = {"count", "storage_capacity", "item_type_index"}
function DBEntry:initialize(o)
    self.item_type_index = o.item_type_index
    self.count = 0
    self.storage_capacity = 0
end

function DBEntry:record_items(count)
    self.count = self.count + count
    return self
end

function DBEntry:record_capacity(stacks)
    self.storage_capacity = self.storage_capacity + stacks * self:item_type().max
    return self
end

function DBEntry:get_fill_percent()
    return math.floor(self.count / self.storage_capacity * 100)
end

function DBEntry:item_type()
    return item_type_registry:get(self.item_type_index)
end

History = class("History")
binser.registerClass(History)
History.static._template = {"entries", "retention", "frequency"}

function History:initialize(o)
    self.entries = {}
    self.retention = o.retention or 300
    self.frequency = o.frequency or 5
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
    local cutoff = time.timestamp() - self.retention
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
    if #self.entries == 0 then
        return 0
    end
    return math.ceil(self.frequency - self:last():age())
end

function History:last()
    return self.entries[#self.entries]
end

HistoryEntry = class("HistoryEntry")
binser.registerClass(HistoryEntry)
HistoryEntry.static._template = {"time", "db", "duration"}

function HistoryEntry:initialize(o)
    self.time = time.timestamp()
    self.db = o.db
    self.duration = o.duration
end

function HistoryEntry:age()
    return math.floor(time.timestamp() - self.time)
end

local function count_items(db, container)
    local inventories = container:getInventories()
    for _, inventory in pairs(inventories) do
        local db_entry = nil
        for nStack = 0, inventory.size - 1, 1 do
            local stack = inventory:getStack(nStack)
            if stack ~= nil and stack.count ~= 0 then
                if db_entry == nil then
                    db_entry = db:entry(stack.item.type)
                elseif db_entry:item_type().name ~= stack.item.type.name then
                    computer.panic("ERROR: multiple items in container " .. container:getHash() .. " inventory " ..
                                       inventory:getHash() .. ": " .. db_entry:item_type().name .. " and " ..
                                       stack.item.type.name)
                end
                db_entry:record_items(stack.count)
            end
        end
        if db_entry ~= nil then
            db_entry:record_capacity(inventory.size)
        end
    end
end

TablePrinter = class("TablePrinter")
function TablePrinter:initialize(o)
    self.headings = {
        cells = o.headings
    }
    self.rows = {}
    self.rowcolors = {}
    self.widths = {}

    for i, heading in pairs(self.headings.cells) do
        self.widths[i] = #heading
    end
end

function TablePrinter:sort()
    shellsort(self.rows, function(a, b)
        return a.cells[1] < b.cells[1]
    end)
end

function TablePrinter:insert(color, row)
    local row_str = {}
    for _, col in pairs(row) do
        table.insert(row_str, tostring(col))
    end

    for i, cell in pairs(row_str) do
        if self.widths[i] == nil or #cell > self.widths[i] then
            self.widths[i] = #cell
        end
    end

    table.insert(self.rows, {
        color = color,
        cells = row_str
    })
end

function TablePrinter:align_columns(row)
    local padding
    local retval = {}
    for j, cell in pairs(row) do
        padding = self.widths[j] - #cell
        table.insert(retval, string.rep(" ", padding) .. " " .. cell .. " ")
    end
    return retval
end

function TablePrinter:colors(cell, highlight)
    local x, y, width = table.unpack(cell)
    if y == 0 then
        return BLACK, WHITE
    end
    local bgcolor = BLACK
    if highlight ~= nil and highlight[2] <= #self.rows then
        local x_hit = x < highlight[1] and x + width >= highlight[1]
        local y_hit = y == highlight[2]
        if x_hit and y_hit then
            bgcolor = GRAY50
        elseif x_hit or y_hit then
            bgcolor = GRAY30
        end
    end
    return self.rows[y].color, bgcolor
end

function TablePrinter:format_row(y, highlight, row)
    local retval = {}
    local x = 1
    for _, cell in pairs(self:align_columns(row.cells)) do
        local fg, bg = self:colors({x, y, #cell}, highlight)
        table.insert(retval, {cell, fg, bg})
        x = x + #cell
    end
    return retval
end

function TablePrinter:format(highlight)
    local retval = {}
    table.insert(retval, self:format_row(0, highlight, self.headings))
    for y, row in pairs(self.rows) do
        table.insert(retval, self:format_row(y, highlight, row))
    end
    return retval
end

local function display_status(gpu, y, status)
    gpu:setForeground(table.unpack(GRAY30))
    gpu:setBackground(table.unpack(BLACK))
    gpu:setText(0, y, status)
    gpu:setForeground(table.unpack(WHITE))
end

local function display(history, highlight, gpu, status)
    local table_printer = TablePrinter:new{
        headings = {"NAME", "COUNT", "CAPACITY", "FILL%", "RATE@15S", "RATE@1M", "RATE@10M"}
    }
    local width = #status

    local history_entry = history:last()
    if history_entry ~= nil then
        local db = history_entry.db
        for _, entry in pairs(db.entries) do
            local fill_percent = entry:get_fill_percent()
            local rate_10min = history:rate_per_minute(entry:item_type(), 600)
            local color
            if fill_percent >= 99 then
                color = GREEN
            elseif fill_percent > 75 and rate_10min > 0 then
                color = WHITE
            elseif rate_10min > 0 then
                color = YELLOW
            else
                color = RED
            end
            table_printer:insert(color,
                {entry:item_type().name, entry.count, entry.storage_capacity, entry:get_fill_percent(),
                 string.format("%s/m", history:rate_per_minute(entry:item_type(), 15)),
                 string.format("%s/m", history:rate_per_minute(entry:item_type(), 60)),
                 string.format("%s/m", rate_10min)})
        end
        table_printer:sort()

        local rows = table_printer:format(highlight)
        for _, row in pairs(rows) do
            local this_width = 0
            for _, cell in pairs(row) do
                this_width = this_width + #cell[1]
            end
            if this_width > width then
                width = this_width
            end
        end
        local height = #rows + 2
        gpu:setSize(width, height)
        gpu:setForeground(table.unpack(WHITE))
        gpu:setBackground(table.unpack(BLACK))
        gpu:fill(0, 0, width, height, "")
        for y, row in pairs(rows) do
            local x = 0
            for _, cellspec in pairs(row) do
                local cell, fg, bg = table.unpack(cellspec)
                gpu:setForeground(table.unpack(fg))
                gpu:setBackground(table.unpack(bg))
                gpu:setText(x, y - 1, cell)
                x = x + #cell
            end
        end
        display_status(gpu, height - 1, status)
    else
        display_status(gpu, 0, status)
    end

    gpu:flush()
end

local function snapshot(history, containers)
    local timer = time.timer()
    local db = DB:new()
    for _, container in pairs(containers) do
        count_items(db, container)
    end
    history:record(db, timer())
end

local function highlight_changed(old, new)
    if old == nil then
        return new ~= nil
    end
    if new == nil then
        return old ~= nil
    end
    return old[1] ~= new[1] or old[2] ~= new[2]
end

local function load_history()
    local timer = time.timer()
    local content = fs.read_all(CONFIG.history_file)
    print("Read " .. #content .. " bytes from " .. CONFIG.history_file .. " in " .. timer() .. "ms")

    timer = time.timer()
    local registry, history = binser.deserializeN(content, 2)
    print("Deserialized history with " .. history:size() .. " entries in " .. timer() .. "ms")

    return registry, history
end

local function main()
    local containers = component.proxy(component.findComponent(findClass("Build_StorageContainerMk2_C")))
    local gpu = hw.gpu()
    local main_display = component.proxy(CONFIG.main_display)

    local history = nil
    if fs.exists(CONFIG.history_file) then
        local status, registry_or_error, new_history = pcall(load_history)
        if status then
            item_type_registry = registry_or_error
            history = new_history
        else
            print("Error loading history: " .. registry_or_error)
        end
    end
    if history == nil then
        history = History:new{
            retention = 900,
            frequency = 5
        }
        print("Created new history")
    end

    gpu:bindScreen(main_display)
    event.listen(gpu)

    local last_highlight = nil
    local last_time_to_next_snapshot = nil
    while true do
        local highlight = nil
        local dirty = false
        local force_update = false

        -- Process the event queue
        local e, s, x, y = event.pull(1.0)
        while e ~= nil do
            if e == "OnMouseMove" then
                highlight = {x, y}
                if highlight_changed(last_highlight, highlight) then
                    dirty = true
                    last_highlight = highlight
                end
            end
            if e == "OnMouseDown" then
                force_update = true
            end
            e, s, x, y = event.pull(0)
        end

        local time_to_next_snapshot = history:time_to_next_snapshot()
        if last_time_to_next_snapshot ~= time_to_next_snapshot then
            dirty = true
        end
        if time_to_next_snapshot <= 0 or force_update then
            snapshot(history, containers)
            last_time_to_next_snapshot = time_to_next_snapshot
            dirty = true

            local timer = time.timer()
            fs.mkdir_p(fs.dirname(CONFIG.history_file))
            local content = binser.serialize(item_type_registry, history)
            fs.write_all(CONFIG.history_file, content)
            print("Dumped " .. #content .. " bytes of history to " .. CONFIG.history_file .. " in " .. timer() .. " ms")
        end

        if dirty then
            local status = string.format("Last update %ss ago (took %sms). Next update in %ss or on click.",
                history:last():age(), history:last().duration, time_to_next_snapshot)
            display(history, last_highlight, gpu, status)
        end
    end
end

return main

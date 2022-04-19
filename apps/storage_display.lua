local fs = Deps("lib/fs")
local binser = Deps("bakpakin/binser:binser", "0.0-8")
local class = Deps("kikito/middleclass:middleclass", "v4.1.1")

local time = Deps("lib/time")
local hw = Deps("lib/hw")
local TablePrinter = Deps("lib/table_printer")
local colors = Deps("lib/colors")
local DB = Deps("lib/database")
local History = Deps("lib/history")

CONFIG = CONFIG or {
    entries = {}
    main_display = "MainScreen",
    history_file = "/storage_display/history.binser",
    retention = 650,
    frequency = 25,
    rates = {{"30s", 30}, {"5m", 5 * 60}, {"10m", 10 * 60}}
}

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

local function display_status(gpu, y, status)
    gpu:setForeground(table.unpack(colors.gray30))
    gpu:setBackground(table.unpack(colors.black))
    gpu:setText(0, y, status)
    gpu:setForeground(table.unpack(colors.white))
end

local function display(history, highlight, gpu, status)
    local headings = {"NAME", "COUNT", "CAPACITY", "FILL%"}
    for _, rate in pairs(CONFIG.rates) do
        table.insert(headings, "RATE@" .. rate[1])
    end
    local table_printer = TablePrinter:new{
        headings = headings
    }
    local width = #status

    local max_rate = 0
    for _, rate in pairs(CONFIG.rates) do
        if rate[2] > max_rate then
            max_rate = rate[2]
        end
    end

    local history_entry = History:last()
    if history_entry ~= nil then
        local db = history_entry.db
        for _, entry in pairs(db.entries) do
            local fill_percent = entry:get_fill_percent()
            local rate_longest = History:rate_per_minute(entry:item_type(), max_rate)
            local color
            if fill_percent >= 99 then
                color = colors.green
            elseif fill_percent > 75 and rate_longest > 0 then
                color = colors.white
            elseif rate_longest > 0 then
                color = colors.yellow
            else
                color = colors.red
            end
            local cells = {entry:item_type().name, entry.count, entry.storage_capacity, entry:get_fill_percent()}
            for _, rate in pairs(CONFIG.rates) do
                table.insert(cells, string.format("%s/m", History:rate_per_minute(entry:item_type(), rate[2])))
            end
            table_printer:insert(color, cells)
        end
        table_printer:sort()

        local height = table_printer:print(highlight, gpu)
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
    History:record(db, timer())
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
    print("Deserialized history with " .. History:size() .. " entries in " .. timer() .. "ms")

    return registry, history
end

local history_saving_coro = coroutine.create(function(registry, history)
    while true do
        local timer = time.timer()
        local content = binser.serialize(registry, history)
        print("Serialized history with " .. History:size() .. " entries in " .. timer() .. "ms")

        timer = time.timer()
        fs.mkdir_p(fs.dirname(CONFIG.history_file))
        fs.write_all(CONFIG.history_file, content)
        print("Wrote " .. #content .. " bytes to " .. CONFIG.history_file .. " in " .. timer() .. "ms")

        _, registry, history = coroutine.yield()
    end
end)

local function save_history(registry, history)
    if coroutine.status(history_saving_coro) == "running" then
        print("Previous history save in progress, ignoring request")
        return
    end
    coroutine.resume(history_saving_coro, registry, history)
end

local function main()
    local containers = component.proxy(component.findComponent(findClass("Build_StorageContainerMk2_C")))
    print("yo")
    print(containers[0], containers[1])
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
            entries = CONFIG.entries,
            retention = CONFIG.retention,
            frequency = CONFIG.frequency
        }
        history.entries = {}
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

        local time_to_next_snapshot = history.time_to_next_snapshot()
        if last_time_to_next_snapshot ~= time_to_next_snapshot then
            dirty = true
        end
        if time_to_next_snapshot <= 0 or force_update then
            snapshot(history, containers)
            last_time_to_next_snapshot = time_to_next_snapshot
            dirty = true
            save_history(item_type_registry, history)
        end

        if dirty then
            local status = string.format("Last update %ss ago (took %sms). Next update in %ss or on click.",
                History:last():age(), History:last().duration, time_to_next_snapshot)
            display(history, last_highlight, gpu, status)
        end
    end
end

return main

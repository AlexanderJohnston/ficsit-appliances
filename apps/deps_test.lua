function bootstrap_deps(main_disk_uuid)
    if filesystem.initFileSystem("/dev") == false then
        computer.panic("Cannot initialize /dev")
    end
    if main_disk_uuid == nil then
        local drives = filesystem.childs("/dev")
        for idx, drive in pairs(drives) do
            if drive == "serial" then
                table.remove(drives, idx)
            end
        end
        if #drives == 0 then
            computer.panic("No drives found")
        end
        if #drives > 1 then
            computer.panic("Multiple drives found")
        end
        main_disk_uuid = drives[1]
    end
    filesystem.mount("/dev/" .. main_disk_uuid, "/")
    print("[bootstrap] Mounted /dev/" .. main_disk_uuid .. " to /")
    local internet = computer.getPCIDevices(findClass("FINInternetCard"))[1]
    local req = internet:request("https://raw.githubusercontent.com/abesto/ficsit-appliances/b3b1f17/lib/deps.lua",
        "GET", "", "User-Agent", "Ficsit-Appliances/Bootstrap https://github.com/abesto/ficsit-appliances")
    local _, Deps_source = req:await()
    return load(Deps_source)()
end

Deps = bootstrap_deps()
deps = Deps:new()

shellsort = deps:require("third_party/shellsort", "main")

local t = {3, 2, 1}
shellsort(t)
for _, n in pairs(t) do
    print(t)
end

function bootstrap_deps()
    local internet = computer.getPCIDevices(findClass("FINInternetCard"))[1]
    local req = internet:request("https://raw.githubusercontent.com/abesto/ficsit-appliances/master/lib/deps.lua",
        "GET", "", "User-Agent", "Ficsit-Appliances/Bootstrap https://github.com/abesto/ficsit-appliances")
    local _, Deps_source = req:await()
    return loadstring(Deps_source)()
end

Deps = bootstrap_deps()
shellsort = Deps:require("shellsort", "main")

local t = {3, 2, 1}
shellsort(t)
for _, n in pairs(t) do
    print(t)
end

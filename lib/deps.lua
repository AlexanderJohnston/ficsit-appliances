--- Load libraries from the internets with caching to disk
local USER_AGENT = "Ficsit-Appliances/Deps https://github.com/abesto/ficsit-appliances"
local REPOSITORY = "abesto/ficsit-appliances"

local function pci(cls)
    local device = computer.getPCIDevices(findClass(cls))[1]
    if device == nil then
        error("No device found for class " .. cls)
    end
    return device
end

local Deps = {
    cache = {}
}
Deps.__index = Deps
function Deps:new(cachedir)
    local self = setmetatable({}, Deps)
    self.internet = pci("FINInternetCard")
    self.cachedir = cachedir or "/deps_cache"
    if not filesystem.isDir(self.cachedir) and not filesystem.createDir(self.cachedir) then
        computer.panic("Cannot create cache directory " .. self.cachedir)
    end
    return self
end

function Deps:download(url, path)
    --- Downloads a file to disk. url must be a full URL, and path an absolute path.
    local req = self.internet:request(url, "GET", "", "User-Agent", USER_AGENT)
    local _, content = req:await()

    local file = filesystem.open(path, "w")
    file:write(content)
    file:close()
end

function Deps:resolve(input, version)
    --- Resolves a dependency to a URL.
    --- input is a string, either a URL or a name of a package.
    ---   If input is a URL, it is returned as-is.
    ---   If input is a name, it can be one of:
    ---     * Path (resolved into this GitHub repository)
    ---     * repository:path
    --- version must reference a commit (can be a tag, commit hash, branch, etc.)
    local libname
    local url
    local cachepath

    if version == nil then
        version = "main"
    end

    if string.match(input, "^https?://") then
        local _, libname = string.match(input, "^(https?://[^/]+)/(.*)$")
        url = input
    elseif string.match(input, "^([^:]+):(.*)$") then
        local repo, path = string.match(input, "^([^:]+):(.*)$")
        libname = input
        url = "https://raw.githubusercontent.com/" .. repo .. "/" .. version .. "/" .. path
    else
        url = "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. version .. "/" .. input
        libname = REPOSITORY .. ":" .. input
    end

    cachepath = self.cachedir .. "/" .. libname .. "-" .. version

    return libname, url, cachepath
end

function Deps:ensure_downloaded(input, version)
    local libname, url, cachepath = self:resolve(input, version)
    if version == "main" or not filesystem.exists(cachepath) then
        print("[Deps] Downloading " .. libname .. "\n       version " .. version .. "\n       from " .. url ..
                  "\n       to " .. cachepath)
        self:download(url, cachepath)
    else
        print("[Deps] Cache hit: " .. libname .. " version " .. version .. " at " .. cachepath)
    end
    return cachepath
end

function Deps:require(input, version)
    local libname, url, cachepath = self:resolve(input, version)
    if Deps.cache[libname] == nil then
        self:ensure_downloaded(input, version)
        Deps.cache[libname] = {
            version = version,
            module = filesystem.doPath(cachepath)
        }
    elseif Deps[libname].version ~= version then
        computer.panic("[Deps] " .. libname .. " is already loaded with version " .. Deps[libname] ..
                           " and cannot be loaded with version " .. version)
    else
        computer.print("[Deps] " .. libname .. " is already loaded with version " .. version)
        return Deps[libname].module
    end
end

return Deps

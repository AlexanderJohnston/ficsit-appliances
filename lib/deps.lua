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

local function mkdir_p(dir)
    local path = ""
    for part in string.gmatch(dir, "[^/]+") do
        path = path .. "/" .. part
        if not filesystem.isDir(path) then
            if filesystem.createDir(path) then
                print("[Deps] Created directory " .. path)
            else
                computer.panic("[Deps] Cannot create directory " .. path)
            end
        end
    end
end

local Deps = {
    cache = {}
}
Deps.__index = Deps
function Deps:new(cachedir)
    local self = setmetatable({}, Deps)
    self.internet = pci("FINInternetCard")
    self.cachedir = cachedir or "/deps_cache"
    mkdir_p(self.cachedir)
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
    else
        local repo, path
        if string.match(input, "^([^:]+):(.*)$") then
            repo, path = string.match(input, "^([^:]+):(.*)$")
        else
            repo, path = REPOSITORY, input
        end
        libname = repo .. ":" .. input
        url = "https://raw.githubusercontent.com/" .. repo .. "/" .. version .. "/" .. path .. ".lua"
    end

    cachepath = self.cachedir .. "/" .. libname .. "-" .. version
    cachepath = string.gsub(cachepath, ":", "/")
    if not string.match(cachepath, "\\.lua$") then
        cachepath = cachepath .. ".lua"
    end

    return libname, url, cachepath
end

function Deps:ensure_downloaded(input, version)
    local libname, url, cachepath = self:resolve(input, version)
    if version == "main" or not filesystem.exists(cachepath) then
        print("[Deps] Downloading " .. libname .. "\n       version " .. version .. "\n       from " .. url ..
                  "\n       to " .. cachepath)
        mkdir_p(string.gsub(cachepath, "/[^/]+$", ""))
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
            module = filesystem.doFile(cachepath)
        }
    elseif Deps[libname].version ~= version then
        computer.panic("[Deps] " .. libname .. " is already loaded with version " .. Deps[libname] ..
                           " and cannot be loaded with version " .. version)
    else
        computer.print("[Deps] " .. libname .. " is already loaded with version " .. version)
        return Deps[libname].module
    end
end

Deps.default = Deps:new()
function Deps:require(...)
    return self.default:require(...)
end

return Deps

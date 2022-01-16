--- Filesystem helpers. Exposes all functions of the build-in "filesystem" module.
local fs = setmetatable({}, {
    __index = filesystem
})

function fs.mkdir_p(dir)
    local path = ""
    for part in string.gmatch(dir, "[^/]+") do
        path = path .. "/" .. part
        if not filesystem.isDir(path) then
            if filesystem.createDir(path) then
                print("[fs.mkdir_p] Created directory " .. path)
            else
                computer.panic("[fs.mkdir_p] Cannot create directory " .. path)
            end
        end
    end
end

return fs

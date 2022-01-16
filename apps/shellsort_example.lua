shellsort = Deps("third_party/shellsort", "fd1ff9f")

function main()
    local t = {3, 2, 1}
    shellsort(t)
    for _, n in pairs(t) do
        print(n)
    end
end

return main

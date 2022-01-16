shellsort = Deps("third_party/shellsort", "main")

local t = {3, 2, 1}
shellsort(t)
for _, n in pairs(t) do
    print(n)
end

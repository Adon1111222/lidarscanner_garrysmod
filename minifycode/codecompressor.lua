local function compresscode(filename)
    local file = io.open(filename,"r")
    local code = file:read("*all")
    code = string.gsub(code,"%-%-%[%[.-%]%]", "")
    code = string.gsub(code,"%-%-.-\n", "")
    code = string.gsub(string.gsub(code,"^%s+", ""),"%s+$", "")
    code = string.gsub(string.gsub(code,"%s+", " "),"\n", "")
    local file2 = io.open(filename .. ".cmp","w")
    file2:write(code)
end

local args = {...}

local filename = args[1]
if filename then
    if #filename > 2 then
        compresscode(filename)
        print("success, check for errors. " .. filename .. ".cmp")
    else
        print("invalid filename")
    end
else
    print("usage: codecompressor.lua [filename]")
end
if not CLIENT then return end

CreateClientConVar("lidarscanner_language","",true,false,"LidarScanner language")

-- Languages example structure:
-- languages = {
--   en = {
--     name = "English"
--     strings = {
--       ["lidarscanner_enabled"] = "Enabled",
--       ...
--     }
--   }
-- }
local languages = {}

-- Functions that can be re-defined
local setcvarstr = RunConsoleCommand
local getcvarstr = GetConVarString
local fsfind = file.Find
local smatch = string.match
local fopen = file.Open
local strrep = string.Replace
local function freadline(file)
	local ln = file:ReadLine()
	if not ln then return nil end
	return strrep(ln,"\n","")
end
local function slen(str)
	return #str
end
local function schar(str,idx)
	return str[idx]
end
local language_Add = language.Add

-- Checks if language is valid and can be used
local function Language_HasLanguage(langname)
	if not languages[langname] then return false end
	if not languages[langname].strings then return false end
	return true
end

-- Returns current language name.
-- If "lidarscanner_language" convar set to "", then it tries to get value of "gmod_language" convar
-- If it fails to get languages from "lidarscanner_language" or "gmod_language" then it will use default language value("en")
local function Language_GetCurrentName()
	if slen(getcvarstr("lidarscanner_language")) == 0 then
		if Language_HasLanguage(getcvarstr("gmod_language")) then
			return getcvarstr("gmod_language")
		end
	end
	if Language_HasLanguage(getcvarstr("lidarscanner_language")) then
		return getcvarstr("lidarscanner_language")
	end
	return "en"
end

-- Loads languages from disk
local function Language_LoadData()
	languages = {}
	local lfiles = fsfind("data_static/lidarscanner2_languages/lidarscanner2_language_*.txt","GAME","nameasc")
	for _,fn in pairs(lfiles) do
		-- Short Name: If input string equals "lidarscanner2_language_en.txt" then sname will be "en"
		local sname = smatch(fn,"^.+language_([a-z]+)%.txt$")
		local ifile = fopen("data_static/lidarscanner2_languages/" .. fn,"r","GAME")
		if ifile then
			-- Full Name
			local fname = freadline(ifile)
			if fname then
				local strings = {}
				while not ifile:EndOfFile() do
					local ln = freadline(ifile)
					if not ln then break end
					-- Skip blank and commentary lines
					if (slen(ln) ~= 0) and (schar(ln,1) ~= '?') then
						local k,v = smatch(ln,"^%[(.+)%]\t(.+)$")
						if k and v then
							if schar(k,1) == "#" then
								-- Removes '#' from the k start and replaces "\n" with new lines in v
								strings[smatch(k,"^#(.*)$")] = strrep(v,"\\n","\n")
							end
						end
					end
				end
				languages[sname] = {name = fname,strings = strings}
			end
			ifile:Close()
		end
	end
end

-- Updates current language from languages table
local function Language_Update(dbg)
	local curlang = Language_GetCurrentName()
	if not Language_HasLanguage(curlang) then
		if dbg then
			print("Failed to find language: " .. curlang)
		end
		return
	end
	if dbg then
		print("Loaded language: " .. tostring(languages[curlang].name) .. 
			"(" .. curlang .. "):")
		for k,v in pairs(languages[curlang].strings) do
			language_Add(k,v)
			print("\t",k,"=",v)
		end
	else
		for k,v in pairs(languages[curlang].strings) do
			language_Add(k,v)
		end
	end
end
concommand.Add("lidarscanner_language_reload",function()
	Language_LoadData()
	Language_Update(true)
	print("Done")
end)
cvars.AddChangeCallback("lidarscanner_language",function()
	Language_Update(false)
end)
cvars.AddChangeCallback("gmod_language",function()
	Language_Update(false)
end)
Language_LoadData()
Language_Update(false)

local LSL = {}

function LSL.GetLanguages()
	local out = {}
	for k,v in pairs(languages) do
		out[k] = v.name
	end
	return out
end

function LSL.GetCurrentLanguage()
	return Language_GetCurrentName()
end

function LSL.SetCurrentLanguage(lname)
	if not lname then
		setcvarstr("lidarscanner_language","en")
		return
	end
	setcvarstr("lidarscanner_language",lname)
end

return LSL

-- LidarScanner 2 main file

AddCSLuaFile()

LIDARSCANNER_VERSION = "2.3"

-- Functions that can be re-defined
local utraceline = util.TraceLine
local smatch = string.match
local randf = math.Rand

local LIDARSCANNER_SOUND_SEEKER = "lidarscanner2_sounds_valve/lidarscanner2_onseen.mp3"

local LIDARSCANNER_NOSCAN = 0
local LIDARSCANNER_FASTSCAN = 1
local LIDARSCANNER_BURSTSCAN = 2

local NULLVECTOR = Vector(0,0,0)
local NULLANGLE = Angle(0,0,0)


local ls_sv_cvars = {}

-- createcvar(string convarname,any defaultvalue,number flags,string description,number minvalue,number maxvalue)
local function createcvar(name,...)
	ls_sv_cvars[#ls_sv_cvars+1] = name
	return CreateConVar(name,...)
end

-- number getcvarnum(string convarname)
local getcvarnum = GetConVarNumber

local function getcvarbool(...)
    return getcvarnum(...) ~= 0
end

local function setcvarval(name,value)
    RunConsoleCommand(name,tostring(value))
end

if SERVER then
	createcvar("lidarscanner_sv_enabled",1,FCVAR_ARCHIVE,"SV. 1 - enables addon. 0 - disables addon.",0,1)
	createcvar("lidarscanner_sv_maxdist",4096,FCVAR_ARCHIVE,"SV. Maximum scanning distance. 512 - 8192",512,8192)
	createcvar("lidarscanner_sv_seeker_enabled",0,FCVAR_ARCHIVE,"SV. 1 - enables seeker. 0 - disables seeker.",0,1)

	createcvar("lidarscanner_sv_multiplayerbridge_enabled",0,FCVAR_ARCHIVE,"SV. 1 - enables multiplayer bridge. 0 - disables multiplayer bridge.",0,1)

	-- Send extension files to clients
	for k,v in pairs(file.Find("lidarscanner2_extensions/_lidarscanner2_extension_*.lua","LUA","nameasc")) do
		AddCSLuaFile("lidarscanner2_extensions/" .. v)
	end

	-- vec_origin - e.g. player eye pos
	-- vec_dir - e.g. player eye directory
	-- trace_filter - e.g. player
	-- Returns: seeker entity if seeker was created, nil otherwise
	function LidarScanner_CallSeeker(vec_origin,vec_dir,trace_filter)
		if not getcvarbool("lidarscanner_sv_seeker_enabled") then return nil end
		local rnd = math.random(1,100)
		if rnd == 50 then
			local tr = utraceline({start = vec_origin,endpos = vec_origin+(vec_dir*1024),filter = trace_filter})
			if not tr.HitSky then
				if tr.HitPos:DistToSqr(vec_origin) > 65536 then
					local navarea = navmesh.GetNearestNavArea(tr.HitPos,false,128)
					if IsValid(navarea) then
						local pnt = navarea:GetClosestPointOnArea(tr.HitPos)
						if pnt then
							local seeker = ents.Create("npc_stalker")
							seeker:SetPos(pnt)
							seeker:SetAngles((vec_origin-seeker:EyePos()):Angle())
							seeker:Spawn()
							seeker:AddFlags(FL_FROZEN)
							seeker:SetColor(Color(0,0,0,1))
							seeker:SetRenderMode(RENDERMODE_TRANSCOLOR)
							seeker:SetCollisionGroup(20)
							seeker:StopMoving()
							local tr = utraceline({start = vec_origin,endpos = (seeker:GetPos()+seeker:EyePos())/2,filter = trace_filter})
							if tr.Entity ~= seeker then
								seeker:Remove()
							else
								local flt = RecipientFilter()
								flt:RemoveAllPlayers()
								flt:AddPlayer(trace_filter)
								trace_filter:EmitSound(LIDARSCANNER_SOUND_SEEKER,75,100,1,CHAN_AUTO,0,0,flt)
								timer.Simple(0.5,function()
									if IsValid(seeker) then
										seeker:Remove()
									end
								end)
								return seeker
							end
						end
					end
				end
			end
		end
		return nil
	end
end
if CLIENT then
	local ls_cvars = {}
	-- createclcvar(string convarname,any defaultvalue,boolean shouldsave,boolean userinfo,string description,number minvalue,number maxvalue)
	local function createclcvar(name,...)
		ls_cvars[#ls_cvars+1] = name
		return CreateClientConVar(name,...)
	end
	local scrollmousevalue_old = input.GetAnalogValue(3)
	local function GetScrollMouseDeltaValue()
		return input.GetAnalogValue(3)-scrollmousevalue_old
	end

	local MAX_LIDARSCANNER_SAVE_DOTS = 2147483647
	local BURSTSCAN_TYPE_NORMAL = 0
	local BURSTSCAN_TYPE_INTERLEAVED = 1
	local BURSTSCAN_TYPE_CROSSED = 2

	local lidarscanner_extensions = {}
	local lidarscanner_configext = {}
	local screen_glitch = 1
	local input_scansize_canscroll = false
	createclcvar("lidarscanner_enabled",1,true,false,"1 - enables addon. 0 - disables addon.",0,1)
	createclcvar("lidarscanner_showprojectors",1,true,false,"1 - enables projectors display. 0 - disables.",0,1)
	createclcvar("lidarscanner_glitch_enabled",1,true,false,"1 - enables screen glitch. 0 - disables screen glitch.",0,1)
	createclcvar("lidarscanner_savescans_syncwritesnum",60,true,false,"the number of dots that will be written in one file request. the more, the faster and the more the load on the disk. 5 - 60",5,60)
	createclcvar("lidarscanner_savedots",0,true,false,"1 - saves dots for later saving. 0 - does not save, which prevents you from saving.",0,1)
	createclcvar("lidarscanner_loadscans_cleardots",0,true,false,"1 - clears dots before loading. 0 - does not clear.",0,1)
	createclcvar("lidarscanner_prescan_enabled",0,true,false,"1 - enables prescan functions call. 0 - disables. ",0,1)
	createclcvar("lidarscanner_postscan_enabled",0,true,false,"1 - enables postscan function call. 0 - disables.",0,1)
	createclcvar("lidarscanner_burstscan_180scan",0,true,false,"1 - enables 180 degrees burst scan. 0 - disables.",0,1)
	createclcvar("lidarscanner_burstscan_360scan",0,true,false,"1 - enables 360 degrees burst scan. 0 - disables.",0,1)
	createclcvar("lidarscanner_burstscan_direction",0,true,false,"1 - rotated burst scan by 90 degrees. 0 - normal burst scan.",0,1)
	createclcvar("lidarscanner_burstscan_reverse",1,true,false,"1 - reversed burst scan. 0 - normal burst scan.",0,1)
	createclcvar("lidarscanner_showdots",1,true,false,"1 - shows dots. 0 - disables dots.",0,1)
	createclcvar("lidarscanner_viewmodel_blurscale",1.5,true,false,"view model blur size.",0.5,6)
	createclcvar("lidarscanner_viewmodel_farscale",1,true,false,"how close should the view model be.",0.5,5)
	createclcvar("lidarscanner_mirror_enabled",1,true,false,"1 - enables view mirroring. 0 - disables mirroring.",0,1)
	createclcvar("lidarscanner_mirror_input_enabled",1,true,false,"1 - enables input mirroring(lidarscanner_mirror_enabled must be enabled). 0 - disables input mirroring.",0,1)
	createclcvar("lidarscanner_developer",0,true,false,"1 - enables developer hud. 0 - disables developer hud.",0,1)
	createclcvar("lidarscanner_hud_enabled",1,true,false,"1 - enables hud. 0 - disables hud.",0,1)
	createclcvar("lidarscanner_showscanspositions",0,true,false,"1 - enables show scan positions. 0 - disables show scan positions.",0,1)
	createclcvar("lidarscanner_savescanspositions",0,true,false,"1 - enables save scan positions. 0 - disables save scan positions.",0,1)
	createclcvar("lidarscanner_maxscanspositions",128,true,false,"sets the maximum number of scans positions. 64 - 1024",64,1024)
	createclcvar("lidarscanner_background_enabled",1,true,false,"1 - enables the background. 0 - disables the background.",0,1)
	createclcvar("lidarscanner_background_colour_r",0,true,false,"background colour. R channel. 0 - 255",0,255)
	createclcvar("lidarscanner_background_colour_g",0,true,false,"background colour. G channel. 0 - 255",0,255)
	createclcvar("lidarscanner_background_colour_b",0,true,false,"background colour. B channel. 0 - 255",0,255)
	createclcvar("lidarscanner_optimize_visible",0,true,false,"1 - enables optimization of dynamic dots by calculating their visibility. 0 - disables.",0,1)
	createclcvar("lidarscanner_optimize_colour",0,true,false,"1 - enables optimizing dots by checking their colour. if the brightness of all channels is less than 10, then the dot will not be added to memory. 0 - disables.",0,1)
	createclcvar("lidarscanner_nohitsky",1,true,false,"1 - enables checking dots for hit the sky, if a dot hit the sky, it will not be added to memory. 0 - disables.",0,1)
	createclcvar("lidarscanner_dotsize",1,true,false,"sets the dynamic dots size. 0.25 - 5",0.25,5)
	createclcvar("lidarscanner_maxdots",2500,true,false,"sets the maximum number of dynamic dots. 64 - 2500",64,3000)
	createclcvar("lidarscanner_maxmeshes",128,true,false,"sets the maximum number of meshes. 16 - 512",16,512)
	createclcvar("lidarscanner_dotsperfastscan",100,true,false,"sets the maximum number of dots per fast scan. 25 - 1000",25,1000)
	local lidarscanner_convar_maxdist = createclcvar("lidarscanner_maxdist",4096,true,false,"sets the maximum scanning distance. this convar also limited by the server. 512 - 8192",512,8192)
	createclcvar("lidarscanner_scansize",16,true,false,"sets the size(angle) of the fast scan. 1 - 64",1,64)
	createclcvar("lidarscanner_scansize_scrollinput",0,true,false,"1 - enables fast scan size control using the mouse wheel. you also need to hold down the button binded with +lidarscanner_scansize_unlockscroll. 0 - disables.",0,1)
	createclcvar("lidarscanner_scansize_sizediff",1,true,false,"by what amount should the scan size value change when lidarscanner_scansize_up and lidarscanner_scansize_down. 1 - 4",1,4)

	createclcvar("lidarscanner_scanlines_colour_r",255,true,false,"sets the colour of the scan lines. channel R. 0 - 255",0,255)
	createclcvar("lidarscanner_scanlines_colour_g",0,true,false,"sets the colour of the scan lines. channel G. 0 - 255",0,255)
	createclcvar("lidarscanner_scanlines_colour_b",0,true,false,"sets the colour of the scan lines. channel B. 0 - 255",0,255)

	createclcvar("lidarscanner_multiplayerbridge_enabled",0,true,false,"1 - enables multiplayer bridge. 0 - disables multiplayer bridge.",0,1)
	createclcvar("lidarscanner_showplayers",0,true,false,"1 - enables players display. 0 - disables.",0,1)

	createclcvar("lidarscanner_burstscan_type",0,true,false,"burst scan type: 0 - normal. 1 - interleaved. 2 - crossed.",0,2)

	setcvarval("lidarscanner_savedots",0) -- if the user forgets

	concommand.Add("lidarscanner_scansize_up",function()
		setcvarval("lidarscanner_scansize",math.min(getcvarnum("lidarscanner_scansize")+getcvarnum("lidarscanner_scansize_sizediff"),64))
	end)
	concommand.Add("lidarscanner_scansize_down",function()
		setcvarval("lidarscanner_scansize",math.max(getcvarnum("lidarscanner_scansize")-getcvarnum("lidarscanner_scansize_sizediff"),1))
	end)
	concommand.Add("+lidarscanner_scansize_unlockscroll",function()
		input_scansize_canscroll = true
	end)
	concommand.Add("-lidarscanner_scansize_unlockscroll",function()
		input_scansize_canscroll = false
	end)

	cvars.AddChangeCallback("lidarscanner_enabled",function(_,_,val)
		if val == 1 then
			if game.SinglePlayer() or LocalPlayer():IsSuperAdmin() then
				RunConsoleCommand("lidarscanner_sv_enabled","1")
			end
		end
	end)
	cvars.AddChangeCallback("lidarscanner_maxdist",function(_,_,val)
		lidarscanner_convar_maxdist:SetFloat(math.floor(math.min(val,getcvarnum("lidarscanner_sv_maxdist"))))
	end)
	concommand.Add("lidarscanner_resetconvars",function()
		for k,v in pairs(ls_cvars) do
			local cvar = GetConVar(v)
			print("[" .. v .. "] " .. tostring(cvar:GetString()) .. " ==> " .. tostring(cvar:GetDefault()))
			cvar:SetString(cvar:GetDefault())
		end
		-- Trying to reset server convars
		for k,v in pairs(ls_sv_cvars) do
			local cvar = GetConVar(v)
			print("[" .. v .. "] " .. tostring(cvar:GetString()) .. " ==> " .. tostring(cvar:GetDefault()))
			cvar:SetString(cvar:GetDefault())
		end
	end)
	concommand.Add("lidarscanner_resetsvconvars",function()
		-- Trying to reset server convars
		for k,v in pairs(ls_sv_cvars) do
			local cvar = GetConVar(v)
			print("[" .. v .. "] " .. tostring(cvar:GetString()) .. " ==> " .. tostring(cvar:GetDefault()))
			cvar:SetString(cvar:GetDefault())
		end
	end)
	local rt = render.GetScreenEffectTexture():GetName()
	local screeneffect_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_material","UnLitGeneric",{["$basetexture"]=rt,["$basetexturetransform"]="center .5 .5 scale -1 1 rotate 0 translate 0 0",["$ignorez"]=1})
	local screeneffect_glitch_r_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_r_material","UnLitGeneric",{["$basetexture"] = rt,["$color2"] = "[1 0 0]",["$ignorez"] = 1,["$additive"] = 1})
	local screeneffect_glitch_g_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_g_material","UnLitGeneric",{["$basetexture"] = rt,["$color2"] = "[0 1 0]",["$ignorez"] = 1,["$additive"] = 1})
	local screeneffect_glitch_b_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_b_material","UnLitGeneric",{["$basetexture"] = rt,["$color2"] = "[0 0 1]",["$ignorez"] = 1,["$additive"] = 1})

	-- Quick Reversed Square Root from Quake
	local pi2 = math.pi*2
	local Q_rsqrt_threehalfs = 1.5
	local function Q_rsqrt(number)
		local x2 = number*0.5
		local y = number
		local i = y
		i = 0x5f3759df - bit.rshift(i,1) -- magic byte
		y = y * (Q_rsqrt_threehalfs - (x2 * y * y)) -- first iteration
		return y
	end

	-- It is easier to store the length of the array and add/subtract from it than to recalculate the length of the array every time...
	--  array functions
	local function new_array()
		return {first = 0,last = 0,data = {}}
	end
	local function array_data(array)
		return array.data
	end
	local function array_get(array,pos)
		return array.data[pos]
	end
	local function array_insertlast(array,data)
		array.last = array.last + 1
		array.data[array.last] = data
	end
	local function array_remove_last(array)
		array.data[array.last] = nil
		array.last = array.last - 1
		if array.last < array.first then array.first = 0 array.last = 0 end
	end
	local function array_get_first(array)
		return array.data[array.first]
	end
	local function array_get_last(array)
		return array.data[array.last]
	end
	local function array_remove_first(array)
		array.data[array.first] = nil
		array.first = array.first + 1
	end
	local function array_count(array)
		return array.last - array.first
	end
	--

	local extensions_currentext = {}
	local lidarscanner_configuredcur = ""
	local burstscan_pos = 2
	local scanspos = {}
	local scansang = {}
	local shouldupdatedots = false
	local curclrcalc = function() return Color(255,255,255) end

	local static_meshes = new_array()
	local dynamic_dots_pos = new_array()
	local dynamic_dots_normal = new_array()
	local dynamic_dots_colour = new_array()

	local saved_dots = new_array()

	local mat_scanned_dot = nil
	function LidarScanner_SetScannedDotMaterial(mat)
		if isstring(mat) then
			return LidarScanner_SetScannedDotMaterial(Material("lidarscanner2_valve_materials/scanned_dots/" .. mat .. ".png","nocull"))
		end
		mat_scanned_dot = mat
	end
	function LidarScanner_GetScannedDotMaterialName()
		-- 
		return smatch(mat_scanned_dot:GetName(),"%g+/(%g+)$") or "?"
	end
	LidarScanner_SetScannedDotMaterial("circle")

	local blurx = Material("pp/blurx")
	local blury = Material("pp/blury")
	local camerasmat = Material("models/wireframe")
	local function LidarScanner_LoadExtConfigFile()
		local filedata = file.Read("_lidarscanner2_extensionconfigurationfile.txt","DATA")
		if filedata then
			if #filedata > 0 then
				lidarscanner_configext = util.JSONToTable(filedata) or {}
				if lidarscanner_configext.__colourctrl then
					lidarscanner_configuredcur = lidarscanner_configext.__colourctrl
					lidarscanner_configext.__colourctrl = nil
				end
			end
		else
			file.Write("_lidarscanner2_extensionconfigurationfile.txt","[[]]")
		end
	end
	local function LidarScanner_SaveExtConfigFile()
		lidarscanner_configext = {}
		if extensions_currentext._name then
			lidarscanner_configext.__colourctrl = extensions_currentext._name
		end
		for k,v in pairs(lidarscanner_extensions) do
			local newtbl = {}
			newtbl.enabled = v.enabled
			newtbl.variables = v.variables
			lidarscanner_configext[v.name] = newtbl
		end
		local filedata = util.TableToJSON(lidarscanner_configext)
		file.Write("_lidarscanner2_extensionconfigurationfile.txt",filedata)
	end
	local function LidarScanner_GetExtensionEnabled(name)
		if lidarscanner_configext[name] then
			if lidarscanner_configext[name].enabled then
				if lidarscanner_configuredcur == name then
					return 0
				else
					return true
				end
			else
				return false
			end
		else
			if name == "Default Colours" then
				return 0
			else
				return false
			end
		end
	end
	local function LidarScanner_LoadExtensions()
		LidarScanner_LoadExtConfigFile()
		lidarscanner_extensions = {}
		for k,v in pairs(file.Find("lidarscanner2_extensions/_lidarscanner2_extension_*.lua","LUA","nameasc")) do
			local tbl = include("lidarscanner2_extensions/" .. v)
			if type(tbl) == "table" then
				local name = tbl.name
				local desc = tbl.desc
				if type(name) == "string" and type(desc) == "string" then
					if #name > 5 and #name < 64 then
						local enabled = LidarScanner_GetExtensionEnabled(name)
						local enabl = enabled
						if enabl == 0 or enabl == true then enabl = true end
						local ext_tbl = {name = name,desc = desc,enabled = enabl}
						local func_prescan = tbl.prescan
						local func_postscan = tbl.postscan
						local func_colourcalc = tbl.colourcalc
						local tbl_variables = tbl.variables
						local version = tbl.version or "not provided"
						local tbl_gui = tbl.gui
						if type(func_colourcalc) == "function" then
							ext_tbl.func_colourcalc = func_colourcalc
						end
						if type(func_prescan) == "function" then
							ext_tbl.func_prescan = func_prescan
						end
						if type(func_postscan) == "function" then
							ext_tbl.func_postscan = func_postscan
						end
						if type(tbl_variables) == "table" then
							ext_tbl.variables = tbl_variables
						end
						if type(tbl_gui) == "table" then
							ext_tbl.gui = tbl_gui
						end
						if enabled == 0 then
							curclrcalc = func_colourcalc
							extensions_currentext = tbl_variables
							extensions_currentext._name = name
						end
						if lidarscanner_configext[name] then
							if lidarscanner_configext[name].variables then
								for k,v in pairs(lidarscanner_configext[name].variables) do
									ext_tbl.variables[k] = v
								end
							end
						end
						ext_tbl.version = version
						lidarscanner_extensions[#lidarscanner_extensions+1] = ext_tbl
					end
				end
			end
		end
	end
	concommand.Add("lidarscanner_extensions_save_config",LidarScanner_SaveExtConfigFile)
	concommand.Add("lidarscanner_extensions_reload",LidarScanner_LoadExtensions)
	function LidarScanner_GetExtensionsList()
		return lidarscanner_extensions
	end
	function LidarScanner_GetCurrentExtension()
		return extensions_currentext
	end
	function LidarScanner_SetCurrentExtension(ind)
		if ind == 0 then
			extensions_currentext = {}
			return
		end
		extensions_currentext = LidarScanner_GetExtensionsList()[ind].variables
		extensions_currentext._name = LidarScanner_GetExtensionsList()[ind].name
	end
	local function safequad(pos,norm,sizex,sizey,colour)
		mesh.QuadEasy(pos or NULLVECTOR,norm or NULLVECTOR,sizex or 1,sizey or 1,colour or Color(255,255,255))
	end
	local maxmeshes = getcvarnum("lidarscanner_maxmeshes")
	local dotsize = getcvarnum("lidarscanner_dotsize")
	local maxdots = getcvarnum("lidarscanner_maxdots")
	local colouropt = getcvarbool("lidarscanner_optimize_colour")
	local shouldsave = getcvarbool("lidarscanner_savedots")
	function LidarScanner_AddDot(pos,normal,colour)
		if colouropt and (colour.r < 10 and colour.g < 10 and colour.b < 10) then return true end
		array_insertlast(dynamic_dots_pos,pos)
		array_insertlast(dynamic_dots_normal,normal)
		array_insertlast(dynamic_dots_colour,colour)
		if shouldsave then
			array_insertlast(saved_dots,{pos,normal,colour})
			if array_count(saved_dots) > MAX_LIDARSCANNER_SAVE_DOTS then
				array_remove_last(saved_dots)
			end
		end
		shouldupdatedots = true
		if array_count(dynamic_dots_pos) > maxdots then
			local smesh = Mesh(mat_scanned_dot)
			mesh.Begin(smesh,7,maxdots)
			for k,v in pairs(array_data(dynamic_dots_pos)) do
				safequad(v,array_get(dynamic_dots_normal,k),dotsize,dotsize,array_get(dynamic_dots_colour,k))
			end
			mesh.End()
			array_insertlast(static_meshes,smesh)
			if array_count(static_meshes) > maxmeshes then
				if IsValid(array_get_first(static_meshes)) then
					array_get_first(static_meshes):Destroy()
				end
				array_remove_first(static_meshes)
			end

			dynamic_dots_pos = new_array()
			dynamic_dots_normal = new_array()
			dynamic_dots_colour = new_array()
		end
	end
	function LidarScanner_GetColour(mattype,hitpos,hitnormal,ind,scanpos)
		if not curclrcalc then
			return Color(255,255,255)
		end
		return curclrcalc(mattype,hitpos,hitnormal,ind,extensions_currentext,scanpos,burstscan_pos)
	end
	local lplyeyedir = Vector(0,0,1)
	local function checkcamlookdot(ply,pos)
		if not getcvarbool("lidarscanner_optimize_visible") then return true end
		local difference = pos - ply:EyePos()
		return lplyeyedir:Dot(difference) / difference:Length() > 0.4
	end
	-- "Fixes" normal of surface(otherwise it will lead to distortions in sizes of dots on displacements)
	local function LidarScanner_FixNormal(norm)
		norm:Normalize()
		norm:Sub(Vector(0.000144,0,0))
	end
	local function LidarScanner_SaveScanPos(pos,ang)
		if not getcvarbool("lidarscanner_savescanspositions") then return end
		scanspos[#scanspos+1] = pos
		scansang[#scansang+1] = ang
		if #scanspos > getcvarnum("lidarscanner_maxscanspositions") then
			table.remove(scanspos,1)
			table.remove(scansang,1)
		end
	end
	local function LidarScanner_DrawScanPos(pos,ang)
		render.DrawQuadEasy(pos,ang:Forward(),5,2.5,Color(255,200,55),0)
		render.DrawQuadEasy(pos+ang:Up()+(ang:Forward()*0.5),-ang:Up(),1,1,Color(255,200,55),0)
	end
	local function LidarScanner_UpdateScanVariables()
		maxmeshes = getcvarnum("lidarscanner_maxmeshes")
		colouropt = getcvarbool("lidarscanner_optimize_colour")
		dotsize = getcvarnum("lidarscanner_dotsize")
		maxdots = getcvarnum("lidarscanner_maxdots")
		shouldsave = getcvarbool("lidarscanner_savedots")
	end
	local lidarscanner_actionqueue = {}
	local function LidarScanner_PreScan()
		LidarScanner_UpdateScanVariables()
		if getcvarbool("lidarscanner_prescan_enabled") then
			for k,v in pairs(lidarscanner_extensions) do
				if v.enabled then
					if v.func_prescan then
						v.func_prescan()
					end
				end
			end
		end
	end
	local function LidarScanner_PostScan()
		LidarScanner_UpdateScanVariables()
		if getcvarbool("lidarscanner_postscan_enabled") then
			for k,v in pairs(lidarscanner_extensions) do
				if v.enabled then
					if v.func_postscan then
						v.func_postscan()
					end
				end
			end
		end
	end
	-- Internal. Performs fast scan
	local function LidarScanner_DoFastScan_int(vec_scanorigin,ang_scanang,filter)
		local out_lines = {}
		LidarScanner_PreScan()
		local hitsky = not getcvarbool("lidarscanner_nohitsky")
		local scansize = getcvarnum("lidarscanner_scansize")
		local maxdist = getcvarnum("lidarscanner_maxdist")
		local maxi = getcvarnum("lidarscanner_dotsperfastscan")*(scansize/64)
		local tr = {}
		for i = 1,maxi do
			local pos = scansize * Q_rsqrt(randf(0,1))
			local h = randf(0,1) * pi2
			local y = pos * math.sin(h)
			local x = pos * math.cos(h)
			local _,dang = LocalToWorld(NULLVECTOR,Angle(y,x,0),NULLVECTOR,ang_scanang)
			local endpos = vec_scanorigin+(dang:Forward()*maxdist)
			utraceline({start = vec_scanorigin,endpos = endpos,filter = filter,output = tr})
			if (not tr.HitSky or hitsky) and tr.Hit then
				LidarScanner_FixNormal(tr.HitNormal)
				LidarScanner_AddDot(tr.HitPos,tr.HitNormal,LidarScanner_GetColour(tr.MatType,tr.HitPos,tr.HitNormal,i,vec_scanorigin))
				out_lines[i] = tr.HitPos
			end
		end
		LidarScanner_SaveScanPos(vec_scanorigin,ang_scanang)
		hitsky = nil
		scansize = nil
		maxdist = nil
		LidarScanner_PostScan()
		return out_lines
	end
	-- Adds a new FastScan action to the action queue. After scan complete, action will be removed from queue.
	-- filter: a Filter value that will be directly passed to utraceline() arguments.
	-- asynclinesfunc: function that will be asynchrously(at any time) called after action complete.
	-- Returns ID of a new scan action
	function LidarScanner_DoFastScan(vec_scanorigin,ang_scanang,filter,asynclinesfunc)
		lidarscanner_actionqueue[#lidarscanner_actionqueue+1] = {type = LIDARSCANNER_FASTSCAN,
			origin = vec_scanorigin,ang = ang_scanang,filter = filter,asyncfunc = asynclinesfunc}
	end
	-- Internal. Performs a single-row burst scan
	local function LidarScanner_DoBurstScan_int(vec_scanorigin,ang_scanang,filter,burstscan_ang)
		if burstscan_ang > 1 then return nil end
		LidarScanner_PreScan()
		local out_lines = {}
		local scandir = ang_scanang:Forward()
		local hitsky = not getcvarbool("lidarscanner_nohitsky")
		local maxdist = getcvarnum("lidarscanner_maxdist")
		local scandir2 = 45
		local scanang2 = (burstscan_ang-0.5)*2
		if getcvarbool("lidarscanner_burstscan_180scan") then
			scandir2 = 90
			scanang2 = (burstscan_ang-0.5)*2
		end
		if getcvarbool("lidarscanner_burstscan_360scan") then
			scandir2 = 90
			scanang2 = (burstscan_ang-0.5)*4
		end
		if getcvarbool("lidarscanner_burstscan_reverse") then
			scandir2 = -scandir2
		end
		local brotatedir = getcvarbool("lidarscanner_burstscan_direction")
		if brotatedir then
			scandir2 = 45
			scanang2 = (burstscan_ang-0.5)*2
		end
		local binterleavedscan = getcvarnum("lidarscanner_burstscan_type") == BURSTSCAN_TYPE_INTERLEAVED
		local bcrossedscan = getcvarnum("lidarscanner_burstscan_type") == BURSTSCAN_TYPE_CROSSED
		local tr = {}
		for i = -64,64 do
			local dang = nil
			local rscanang2 = scanang2
			if binterleavedscan then
				if (i % 2) ~= 0 then
					rscanang2 = -rscanang2
				end
			end
			if bcrossedscan then
				if (i % 2) == 0 then -- Horizontal
					_,dang = LocalToWorld(NULLVECTOR,Angle(((i)/2)+randf(-0.025,0.025),rscanang2*scandir2,0),
						NULLVECTOR,ang_scanang)
				else -- Vertical
					_,dang = LocalToWorld(NULLVECTOR,Angle((rscanang2*scandir2)+randf(-0.025,0.025),((i)/2),0),
						NULLVECTOR,ang_scanang)
				end
			else
				if brotatedir then
					_,dang = LocalToWorld(NULLVECTOR,Angle((rscanang2*scandir2)+randf(-0.025,0.025),((i)/2),0),
						NULLVECTOR,ang_scanang)
				else
					_,dang = LocalToWorld(NULLVECTOR,Angle(((i)/2)+randf(-0.025,0.025),rscanang2*scandir2,0),
						NULLVECTOR,ang_scanang)
				end
			end
			if dang then
				utraceline({
					start = vec_scanorigin,
					endpos = vec_scanorigin+(dang:Forward()*maxdist),
					filter = filter,
					output = tr
				})
				if (not tr.HitSky or hitsky) and tr.Hit then
					LidarScanner_FixNormal(tr.HitNormal)
					LidarScanner_AddDot(tr.HitPos,tr.HitNormal,LidarScanner_GetColour(tr.MatType,tr.HitPos,tr.HitNormal,i,vec_scanorigin))
					out_lines[i] = tr.HitPos
				end
			end
		end
		LidarScanner_SaveScanPos(vec_scanorigin,ang_scanang)
		hitsky = nil
		maxdist = nil
		scandir = nil
		LidarScanner_PostScan()
		return out_lines
	end
	-- Adds a new BurstScan action to the action queue. After scan complete(when burst ang gets end), action will be removed from queue.
	-- filter: a filter value that will be directly passed to utraceline() arguments.
	-- asynclinesfunc: function that will be asynchrously(at any time) called after action complete. Burst scan calls this functions multiple times.
	-- Returns ID of a new scan action
	function LidarScanner_DoBurstScan(vec_scanorigin,ang_scanang,filter,asynclinesfunc)
		lidarscanner_actionqueue[#lidarscanner_actionqueue+1] = {type = LIDARSCANNER_BURSTSCAN,
			origin = vec_scanorigin,ang = ang_scanang,filter = filter,asyncfunc = asynclinesfunc,
			burstang = 0,}
		return #lidarscanner_actionqueue
	end
	-- Updates Burst Scan values
	-- Pass any value as nil to remove action from queue(filter value must be {})
	function LidarScanner_UpdateBurstScan(vec_scanorigin,ang_scanang,filter,scanid)
		if not lidarscanner_actionqueue[scanid] then return end
		if lidarscanner_actionqueue[scanid].type ~= LIDARSCANNER_BURSTSCAN then return end
		if vec_scanorigin == nil or ang_scanang == nil or filter == nil then
			lidarscanner_actionqueue[scanid] = nil
			return
		end
		lidarscanner_actionqueue[scanid].origin = vec_scanorigin
		lidarscanner_actionqueue[scanid].ang = ang_scanang
		lidarscanner_actionqueue[scanid].filter = filter
	end
	function LidarScanner_ChangeColourCalc(ind)
		if not lidarscanner_extensions[ind] then return false end
		if not lidarscanner_extensions[ind].func_colourcalc then return false end
		lidarscanner_extensions[ind].enabled = true
		--if not IsColor(lidarscanner_extensions[ind].func_colourcalc(1,NULLVECTOR,Vector(0,0,1),1)) then return false end
		curclrcalc = lidarscanner_extensions[ind].func_colourcalc
		return true
	end
	function LidarScanner_ClearAllScans(dont_clear_saved_dots)
		for k,v in pairs(array_data(static_meshes)) do
			v:Destroy()
		end
		if IsValid(dynamic_mesh) then
			dynamic_mesh:Destroy()
		end
		static_meshes = new_array()
		dynamic_dots_colour = new_array()
		dynamic_dots_normal = new_array()
		dynamic_dots_pos = new_array()
		if not dont_clear_saved_dots then
			saved_dots = new_array()
		end
	end
	function LidarScanner_ClearLastScan()
		if array_count(dynamic_dots_pos) == 0 then
			if IsValid(array_get_last(static_meshes)) then
				array_get_last(static_meshes):Destroy()
			end
			array_remove_last(static_meshes)
		else
			if IsValid(dynamic_mesh) then
				dynamic_mesh:Destroy()
				dynamic_mesh = nil
			end
			dynamic_dots_pos = new_array()
			dynamic_dots_normal = new_array()
			dynamic_dots_colour = new_array()
		end
		if getcvarbool("lidarscanner_savedots") then
			for i = 1,getcvarnum("lidarscanner_maxdots") do
				array_remove_last(saved_dots)
			end
		end
	end
	function LidarScanner_SaveScans(afile)
		local ofile
		if isstring(afile) then
			ofile = file.Open("lidarscanner_savedscans/" .. afile .. ".txt","wb","DATA")
		else
			ofile = afile
		end
		if not ofile then
			print("Failed to open output file: " .. tostring(afile))
			return
		end
		local arraysize = array_count(saved_dots)
		local rp = 0
		local maxnum = getcvarnum("lidarscanner_savescans_syncwritesnum")
		local infofilename = "lidarscanner_savedscans/_info.json"
		file.Write(infofilename,"0/" .. arraysize)
		--
		ofile:Write("LIDARSCANNERSCANS2\0\0") -- 20
		ofile:WriteLong(arraysize)
		for k,v in pairs(array_data(saved_dots)) do
			local pos,norm,clr = v[1],v[2],v[3]
			ofile:WriteFloat(pos.x)
			ofile:WriteFloat(pos.y)
			ofile:WriteFloat(pos.z)
			
			ofile:WriteFloat(norm.x)
			ofile:WriteFloat(norm.y)
			ofile:WriteFloat(norm.z)
			
			ofile:WriteByte(clr.r)
			ofile:WriteByte(clr.g)
			ofile:WriteByte(clr.b)
			rp = rp + 1
			if rp > maxnum then
				file.Write(infofilename,tostring(afile) .. "\n" .. k .. "/" .. arraysize)
				rp = 0
			end
		end
		ofile:Close()
	end
	function LidarScanner_LoadScans(afile)
		local ifile
		if isstring(afile) then
			ifile = file.Open("lidarscanner_savedscans/" .. afile .. ".txt","rb","DATA")
		else
			ifile = afile
		end
		if not ifile then
			print("Failed to open input file: " .. tostring(afile))
			return
		end
		if getcvarbool("lidarscanner_loadscans_cleardots") then
			LidarScanner_ClearAllScans()
		end
		local headersign = ifile:Read(20)
		if headersign == "LIDARSCANNERSCANFILE" then -- first version
			ifile:Seek(20)
			for i = 1,MAX_LIDARSCANNER_SAVE_DOTS do
				local data = ifile:ReadLine()
				if not data then break end
				if #data == 0 then break end
				local tbl = util.JSONToTable(data)
				if tbl then
					local pos,normal,colour = tbl[1],tbl[2],tbl[3]
					LidarScanner_AddDot(pos or NULLVECTOR,normal or NULLVECTOR,colour or Color(0,0,0))
				end
			end
		elseif headersign == "LIDARSCANNERSCANS2\0\0" then -- second version
			local len = ifile:ReadLong()
			-- size = len * 27
			for i = 1,math.max(len,0) do
				local vec_Pos = Vector(ifile:ReadFloat(),ifile:ReadFloat(),ifile:ReadFloat())
				local vec_Normal = Vector(ifile:ReadFloat(),ifile:ReadFloat(),ifile:ReadFloat())
				local clr = Color(ifile:ReadByte(),ifile:ReadByte(),ifile:ReadByte())
				LidarScanner_AddDot(vec_Pos or NULLVECTOR,vec_Normal or NULLVECTOR,clr or Color(0,0,0))
				if ifile:EndOfFile() then break end
			end
		else
			print("Unknown input file signature: " .. headersign)
		end
		ifile:Close()
	end
	concommand.Add("lidarscanner_clearallscans",LidarScanner_ClearAllScans)
	concommand.Add("lidarscanner_rebuildfromsaved",function()
		LidarScanner_ClearAllScans(true)
		-- Update scan variables(dot size, limits, e.t.c.)
		LidarScanner_UpdateScanVariables()
		local shouldsave_old = shouldsave
		-- Disable dots saving to saved_dots so it doesn't will be an infinity loop(LidarScanner_AddDot adds dots to a saved_dots array)
		shouldsave = false
		for k,v in pairs(array_data(saved_dots)) do
			LidarScanner_AddDot(v[1],v[2],v[3])
		end
		shouldsave = shouldsave_old
	end)
	function LidarScanner_SetGlitchFactor(nglitch)
		screen_glitch = nglitch
	end
	local function DrawGlitchEffect()
		if getcvarbool("lidarscanner_glitch_enabled") then
			local glitch = screen_glitch
			if glitch > 1 then
				glitch = glitch + (math.sin(CurTime())*(screen_glitch-1)*10)
				screen_glitch = screen_glitch - (RealFrameTime()/2)
			end
			cam.Start2D()
			DrawMotionBlur(0.5,0.4,0.01)
			render.UpdateScreenEffectTexture(0)
			render.SetMaterial(screeneffect_glitch_r_mat)
			render.DrawScreenQuadEx(-glitch*2,-glitch*2,ScrW()+(glitch*4),ScrH()+(glitch*4))
			render.SetMaterial(screeneffect_glitch_g_mat)
			render.DrawScreenQuadEx(-glitch,-glitch,ScrW()+(glitch*2),ScrH()+(glitch*2))
			render.SetMaterial(screeneffect_glitch_b_mat)
			render.DrawScreenQuadEx(-glitch*4,-glitch*4,ScrW()+(glitch*8),ScrH()+(glitch*8))
			render.UpdateScreenEffectTexture(0)
			cam.End2D()
		end
	end
	local addoninitialized = false
	hook.Add("PostDrawEffects","lidarscanner2_renderscanhook",function()
		if not addoninitialized then
			LidarScanner_LoadExtensions()
			file.CreateDir("lidarscanner_savedscans")
			addoninitialized = true
		end
		if getcvarbool("lidarscanner_enabled") then
			-- Do any scan actions here, so pre- and post- functions will see screen even with blindness on
			local i = 1
			while (i <= #lidarscanner_actionqueue) do
				local v = lidarscanner_actionqueue[i]
				if v then
					if v.type == LIDARSCANNER_FASTSCAN then
						v.asyncfunc(LidarScanner_DoFastScan_int(v.origin,v.ang,v.filter))
						lidarscanner_actionqueue[i] = nil
					elseif v.type == LIDARSCANNER_BURSTSCAN then
						local ftime = RealFrameTime()
						local outlines = {}
						-- BurstScan rows stabilization
						for i = 0,ftime/0.005 do
							if ftime then
								v.burstang = v.burstang + 0.0025
								local lines = LidarScanner_DoBurstScan_int(v.origin,v.ang,v.filter,v.burstang)
								if lines then
									table.Add(outlines,lines)
								else
									outlines = nil
								end
							end
						end
						if outlines then
							v.asyncfunc(outlines)
						else
							v.asyncfunc()
							lidarscanner_actionqueue[i] = nil
						end
					end
				end
				i = i + 1
			end
		else
			local ply = LocalPlayer()
			if IsValid(ply) then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) then
					if wep:GetClass() == "lidarscanner2_lidarscanner" then
						if wep.DrawLidarScannerWeaponModel then
							wep:DrawLidarScannerWeaponModel(ply)
						end
					end
				end
			end
			return
		end
		if getcvarbool("lidarscanner_background_enabled") then
			cam.Start2D()
			draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(getcvarnum("lidarscanner_background_colour_r"),
				getcvarnum("lidarscanner_background_colour_g"),
				getcvarnum("lidarscanner_background_colour_b")))
			cam.End2D()
			if getcvarbool("lidarscanner_showprojectors") then
				halo.Render({
					Ents = ents.FindByClass("lidarscanner2_projector"),
					Color = Color(255,255,55),
					BlurX = 2,
					BlurY = 2,
					DrawPasses = 1,
					Additive = true,
					IgnoreZ = true,
				})
			end
			if getcvarbool("lidarscanner_showplayers") then
				halo.Render({
					Ents = player.GetAll(),
					Color = Color(255,55,55),
					BlurX = 4,
					BlurY = 4,
					DrawPasses = 1,
					Additive = true,
					IgnoreZ = true,
				})
			end
		end
		local ply = LocalPlayer()
		if IsValid(ply) then
			cam.Start3D()
			cam.IgnoreZ(true)
			if getcvarbool("lidarscanner_showdots") then
				render.SetMaterial(mat_scanned_dot)
				for k,v in pairs(array_data(static_meshes)) do
					v:Draw()
				end
				if IsValid(dynamic_mesh) then
					dynamic_mesh:Draw()
				end
				if shouldupdatedots then
					if array_count(dynamic_dots_pos) > 0 then
						lplyeyedir = LocalPlayer():GetAimVector()
						local dotsize = getcvarnum("lidarscanner_dotsize")
						if IsValid(dynamic_mesh) then
							dynamic_mesh:Destroy()
							dynamic_mesh = nil
						end
						dynamic_mesh = Mesh(mat_scanned_dot)
						mesh.Begin(dynamic_mesh,7,3000)
						for k,v in pairs(array_data(dynamic_dots_pos)) do
							if checkcamlookdot(ply,v) then
								safequad(v,array_get(dynamic_dots_normal,k),dotsize,dotsize,array_get(dynamic_dots_colour,k))
							end
						end
						mesh.End()
					end
					shouldupdatedots = false 
				end
			end
			if getcvarbool("lidarscanner_showscanspositions") then
				render.SetMaterial(camerasmat)
				for k,v in pairs(scanspos) do
					LidarScanner_DrawCamera(v,scansang[k] or NULLANGLE)
				end
			end
			cam.IgnoreZ(false)
			cam.End3D()
			local swep = true
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then
				if wep:GetClass() == "lidarscanner2_lidarscanner" then
					swep = false
					wep:DrawLidarScannerWeaponModel(ply)
					if getcvarbool("lidarscanner_scansize_scrollinput") then
						if input_scansize_canscroll then
							setcvarval("lidarscanner_scansize",getcvarnum("lidarscanner_scansize")+math.Clamp(GetScrollMouseDeltaValue()*4,-4,4))
						end
					end
					DrawGlitchEffect()
					cam.Start2D()
					if getcvarbool("lidarscanner_hud_enabled") then
						draw.RoundedBox(3,(ScrW()/2.5),ScrH()/1.125,ScrW()/5,ScrH()/50,Color(55,55,55))
						local sizew = (ScrW()/5)*(getcvarnum("lidarscanner_scansize")/64)
						draw.RoundedBox(3,(ScrW()/2)-(sizew/2),ScrH()/1.125,sizew,ScrH()/50,Color(127,127,127))
						draw.SimpleText(tostring(math.Round(getcvarnum("lidarscanner_scansize"),1)),"DermaDefault",ScrW()/2,ScrH()/1.125,Color(10,10,10),1,3)
					end
					cam.End2D()
				end
			end
			if swep then
				if getcvarbool("lidarscanner_mirror_enabled") then
					cam.Start2D()
					render.UpdateScreenEffectTexture(0)
					render.SetMaterial(screeneffect_mat)
					render.DrawScreenQuad()
					render.UpdateScreenEffectTexture(0)
					cam.End2D()
				end
				DrawGlitchEffect()
			end
			if getcvarbool("lidarscanner_developer") then
				cam.Start2D()
				local tclr = Color(255,255,255)
				if array_count(static_meshes) == maxmeshes then
					tclr = Color(255,0,0)
				end
				draw.DrawText("FramesPerSecond: " .. tostring(math.floor(1/RealFrameTime())) .. 
					"\nMeshes: " .. tostring(array_count(static_meshes)) .. "/" .. tostring(maxmeshes) .. 
					"\nDots:" .. tostring(array_count(dynamic_dots_pos)) .. 
					"\nScans positions: " .. tostring(#scanspos) .. 
					"\nLock Scroll: " .. tostring(input_scansize_canscroll) .. 
					"\nScan Size: " .. tostring(getcvarnum("lidarscanner_scansize")),"DebugFixed",30,30,tclr,0)
				cam.End2D()
			end
			if getcvarbool("lidarscanner_savedots") then
				cam.Start2D()
				draw.SimpleText("Lidar Scanner Saved Dots: " ..
					tostring(array_count(saved_dots)) .. "/" .. MAX_LIDARSCANNER_SAVE_DOTS .. " = " ..
					tostring(math.Round(array_count(saved_dots)/MAX_LIDARSCANNER_SAVE_DOTS,2)) .. "/100%")
				cam.End2D()
			end
		end
		scrollmousevalue_old = input.GetAnalogValue(3)
	end)
	hook.Add("InputMouseApply","lidarscanner2_input_hook",function(cmd,x,y,ang)
		if not getcvarbool("lidarscanner_enabled") then return end
		if getcvarbool("lidarscanner_scansize_scrollinput") and input_scansize_canscroll then
			cmd:SetMouseWheel(0)
		end
		if not (getcvarbool("lidarscanner_mirror_enabled") and getcvarbool("lidarscanner_mirror_input_enabled")) then return end
    ang.pitch = math.Clamp(ang.pitch + (y * getcvarnum("m_pitch")),-89,89)
    ang.yaw = ang.yaw - (x * -getcvarnum("m_yaw"))
    cmd:SetViewAngles(ang)
		cmd:SetSideMove(-cmd:GetSideMove())
		return true
	end)
	hook.Add("HUDShouldDraw","lidarscanner2_hudfilter_hook", function(name)
		if name == "CHudWeaponSelection" then
			if getcvarbool("lidarscanner_enabled") and getcvarbool("lidarscanner_scansize_scrollinput") and input_scansize_canscroll then
				return false
			end
		end
	end)
end

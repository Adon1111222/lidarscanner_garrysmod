AddCSLuaFile()

local LIDARSCANNER_VERSION = "2.1"

SWEP.ViewModel              = "models/weapons/c_pistol.mdl"
SWEP.WorldModel             = "models/weapons/w_pistol.mdl"
SWEP.UseHands 				= false
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= true
SWEP.Secondary.Ammo			= "none"
SWEP.Category   			= "Other"
SWEP.PrintName  			= "LIDAR Scanner"
SWEP.Instructions           = "Left Mouse Button(+attack) - fast scan. Right Mouse Button(+attack2) - burst scan. Reload(+reload) - delete the last scan."
SWEP.Slot					= 3
SWEP.SlotPos				= 1
SWEP.DrawAmmo				= false
SWEP.DrawCrosshair			= false
SWEP.Spawnable				= true

function SWEP:Initialize()
	self:SetHoldType("pistol")
end
if SERVER then
	CreateConVar("lidarscanner_sv_enabled",1,FCVAR_ARCHIVE,"1 - enables addon. 0 - disables addon.",0,1)
	CreateConVar("lidarscanner_sv_maxdist",4096,FCVAR_ARCHIVE,"maximum scanning distance. 512 - 8192",512,8192)
	CreateConVar("lidarscanner_sv_seeker_enabled",0,FCVAR_ARCHIVE,"1 - enables seeker. 0 - disables seeker.",0,1)

	util.AddNetworkString("lidarscanner2_network")
	function SWEP:StopScanSound()
		local owner = self:GetOwner()
		if IsValid(owner) then
			self:StopSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
			net.Start("lidarscanner2_network")
			net.WriteInt(-1,3)
			net.Send(owner)
		end
	end
	function SWEP:OnDrop()
		self:StopScanSound()
	end
	function SWEP:Holster(weapon)
		self:StopScanSound()
		return true
	end
	function SWEP:OnRemove()
		self:StopScanSound()
	end
	function SWEP:Reload()
		if GetConVarNumber("lidarscanner_sv_enabled") ~= 1 then return end
		local owner = self:GetOwner()
		if IsValid(owner) then
			net.Start("lidarscanner2_network")
			net.WriteInt(0,3)
			net.Send(owner)
			self:SetNextSecondaryFire(CurTime()+0.25)
		end
	end
	function SWEP:PrimaryAttack()
		if GetConVarNumber("lidarscanner_sv_enabled") ~= 1 then return end
		local owner = self:GetOwner()
		if IsValid(owner) and not self.burstscanning then
			net.Start("lidarscanner2_network")
			net.WriteInt(1,3)
			net.Send(owner)
			if not self.scanning then
				self:EmitSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
			end
			self.scanning = true
		end
	end
	function SWEP:SecondaryAttack()
		if GetConVarNumber("lidarscanner_sv_enabled") ~= 1 then return end
		local owner = self:GetOwner()
		if IsValid(owner) and not self.burstscanning then
			self:StopSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
			net.Start("lidarscanner2_network")
			net.WriteInt(2,3)
			net.Send(owner)
			self.burstscanning = true
			local snd = CreateSound(self,"lidarscanner2_sounds_valve/lidarscanner2_burstscanning" .. math.random(1,4) .. ".wav")
			snd:Play()
			if GetConVarNumber("lidarscanner_sv_seeker_enabled") == 1 then
				local rnd = math.random(1,10)
				if rnd == 5 then
					timer.Simple(0.75,function()
						local owner = self:GetOwner()
						if IsValid(owner) then
							local tr = util.TraceLine({start = owner:EyePos(),endpos = owner:EyePos()+(owner:EyeAngles():Forward()*1024),filter = owner})
							if not tr.HitSky then
								if tr.HitPos:DistToSqr(owner:EyePos()) > 65536 then
									local navarea = navmesh.GetNearestNavArea(tr.HitPos,false,128)
									if IsValid(navarea) then
										local pnt = navarea:GetClosestPointOnArea(tr.HitPos)
										if pnt then
											local seeker = ents.Create("npc_stalker")
											seeker:SetPos(pnt)
											seeker:SetAngles((owner:EyePos()-seeker:EyePos()):Angle())
											seeker:Spawn()
											seeker:AddFlags(FL_FROZEN)
											seeker:SetColor(Color(0,0,0,1))
											seeker:SetRenderMode(RENDERMODE_TRANSCOLOR)
											seeker:SetCollisionGroup(20)
											seeker:StopMoving()
											local tr = util.TraceLine({start = owner:EyePos(),endpos = (seeker:GetPos()+seeker:EyePos())/2,filter = owner})
											if tr.Entity ~= seeker then
												seeker:Remove()
											else
												local flt = RecipientFilter()
												flt:RemoveAllPlayers()
												flt:AddPlayer(owner)
												owner:EmitSound("lidarscanner2_sounds_valve/lidarscanner2_onseen.wav",75,100,1,CHAN_AUTO,0,0,flt)
												net.Start("lidarscanner2_network")
												net.WriteInt(-3,3)
												net.Send(owner)
												timer.Simple(0.5,function()
													if IsValid(seeker) then
														seeker:Remove()
													end
												end)
											end
										end
									end
								end
							end
						end
					end)
				end
			end
			timer.Simple(2,function() if IsValid(self) then self.burstscanning = false end if snd then snd:FadeOut(1) end end)
			self:SetNextSecondaryFire(CurTime()+3)
		end
	end
	function SWEP:Think()
		if GetConVarNumber("lidarscanner_sv_enabled") ~= 1 then return end
		local owner = self:GetOwner()
		if IsValid(owner) then
			if not owner:KeyDown(IN_ATTACK) then
				net.Start("lidarscanner2_network")
				net.WriteInt(-1,3)
				net.Send(owner)
				if self.scanning then
					self:StopSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
					self:EmitSound("lidarscanner2_sounds_valve/lidarscanner2_onstopscanning.wav")
					self.scanning = false
				end
			end
		end
	end
end
if CLIENT then
	file.CreateDir("lidarscanner_savedscans")
	function SWEP:PreDrawViewModel() return true end
	local lidarscanner_currentcolour = 0
	local lidarscanner_extensions = {}
	local lidarscanner_configext = {}
	local screen_glitch = 1
	local curscantype = 0
	local input_scansize_canscroll = false
	CreateClientConVar("lidarscanner_enabled",1,true,false,"1 - enables addon. 0 - disables addon.",0,1)
	CreateClientConVar("lidarscanner_showprojectors",1,true,false,"1 - enables projectors display. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_glitch_enabled",1,true,false,"1 - enables screen glitch. 0 - disables screen glitch.",0,1)
	CreateClientConVar("lidarscanner_savescans_syncwritesnum",20,true,false,"the number of dots that will be written in one file request. the more, the faster and the more the load on the disk. 5 - 30",5,30)
	CreateClientConVar("lidarscanner_savedots",0,true,false,"1 - saves dots for later saving. 0 - does not save, which prevents you from saving.",0,1)
	CreateClientConVar("lidarscanner_prescan_enabled",0,true,false,"1 - enables prescan functions call. 0 - disables. ",0,1)
	CreateClientConVar("lidarscanner_postscan_enabled",0,true,false,"1 - enables postscan function call. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_burstscan_180scan",0,true,false,"1 - enables 180 degrees burst scan. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_burstscan_360scan",0,true,false,"1 - enables 360 degrees burst scan. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_burstscan_direction",0,true,false,"1 - rotated burst scan by 90 degrees. 0 - normal burst scan.",0,1)
	CreateClientConVar("lidarscanner_burstscan_reverse",1,true,false,"1 - reversed burst scan. 0 - normal burst scan.",0,1)
	CreateClientConVar("lidarscanner_showdots",1,true,false,"1 - shows dots. 0 - disables dots.",0,1)
	CreateClientConVar("lidarscanner_viewmodel_blurscale",1.5,true,false,"view model blur size.",0.5,6)
	CreateClientConVar("lidarscanner_viewmodel_farscale",1,true,false,"how close should the view model be.",0.5,5)
	CreateClientConVar("lidarscanner_mirror_enabled",1,true,false,"1 - enables view mirroring. 0 - disables mirroring.",0,1)
	CreateClientConVar("lidarscanner_mirror_input_enabled",1,true,false,"1 - enables input mirroring(lidarscanner_mirror_enabled must be enabled). 0 - disables input mirroring.",0,1)
	CreateClientConVar("lidarscanner_developer",0,true,false,"1 - enables developer hud. 0 - disables developer hud.",0,1)
	CreateClientConVar("lidarscanner_hud_enabled",1,true,false,"1 - enables hud. 0 - disables hud.",0,1)
	CreateClientConVar("lidarscanner_showscanspositions",0,true,false,"1 - enables show scan positions. 0 - disables show scan positions.",0,1)
	CreateClientConVar("lidarscanner_savescanspositions",0,true,false,"1 - enables save scan positions. 0 - disables save scan positions.",0,1)
	CreateClientConVar("lidarscanner_maxscanspositions",128,true,false,"sets the maximum number of scans positions. 64 - 1024",64,1024)
	CreateClientConVar("lidarscanner_background_enabled",1,true,false,"1 - enables the background. 0 - disables the background.",0,1)
	CreateClientConVar("lidarscanner_background_colour_r",0,true,false,"background colour. R channel. 0 - 255",0,255)
	CreateClientConVar("lidarscanner_background_colour_g",0,true,false,"background colour. G channel. 0 - 255",0,255)
	CreateClientConVar("lidarscanner_background_colour_b",0,true,false,"background colour. B channel. 0 - 255",0,255)
	CreateClientConVar("lidarscanner_optimize_visible",0,true,false,"1 - enables optimization of dynamic dots by calculating their visibility. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_optimize_colour",0,true,false,"1 - enables optimizing dots by checking their colour. if the brightness of all channels is less than 10, then the dot will not be added to memory. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_nohitsky",1,true,false,"1 - enables checking dots for hit the sky, if a dot hit the sky, it will not be added to memory. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_dotsize",1,true,false,"sets the dynamic dots size. 0.25 - 5",0.25,5)
	CreateClientConVar("lidarscanner_maxdots",2500,true,false,"sets the maximum number of dynamic dots. 64 - 2500",64,3000)
	CreateClientConVar("lidarscanner_maxmeshes",128,true,false,"sets the maximum number of meshes. 16 - 512",16,512)
	CreateClientConVar("lidarscanner_dotsperfastscan",100,true,false,"sets the maximum number of dots per fast scan. 25 - 1000",25,1000)
	local lidarscanner_convar_maxdist = CreateClientConVar("lidarscanner_maxdist",4096,true,false,"sets the maximum scanning distance. this convar also limited by the server. 512 - 8192",512,8192)
	local lidarscanner_convar_scansize = CreateClientConVar("lidarscanner_scansize",16,true,false,"sets the size(angle) of the fast scan. 1 - 64",1,64)
	CreateClientConVar("lidarscanner_scansize_scrollinput",0,true,false,"1 - enables fast scan size control using the mouse wheel. you also need to hold down the button binded with +lidarscanner_scansize_unlockscroll. 0 - disables.",0,1)
	CreateClientConVar("lidarscanner_scansize_sizediff",1,true,false,"by what amount should the scan size value change when lidarscanner_scansize_up and lidarscanner_scansize_down. 1 - 4",1,4)

	CreateClientConVar("lidarscanner_scanlines_colour_r",255,true,false,"sets the colour of the scan lines. channel R. 0 - 255",0,255)
	CreateClientConVar("lidarscanner_scanlines_colour_g",0,true,false,"sets the colour of the scan lines. channel G. 0 - 255",0,255)
	CreateClientConVar("lidarscanner_scanlines_colour_b",0,true,false,"sets the colour of the scan lines. channel B. 0 - 255",0,255)

	RunConsoleCommand("lidarscanner_savedots","0") -- if the user forgets

	concommand.Add("lidarscanner_scansize_up",function()
		lidarscanner_convar_scansize:SetFloat(math.min(lidarscanner_convar_scansize:GetFloat()+GetConVarNumber("lidarscanner_scansize_sizediff"),64))
	end)
	concommand.Add("lidarscanner_scansize_down",function()
		lidarscanner_convar_scansize:SetFloat(math.max(lidarscanner_convar_scansize:GetFloat()-GetConVarNumber("lidarscanner_scansize_sizediff"),1))
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
		lidarscanner_convar_maxdist:SetFloat(math.floor(math.min(val,GetConVarNumber("lidarscanner_sv_maxdist"))))
	end)
	local ls_cvars = {
	"lidarscanner_enabled","lidarscanner_burstscan_180scan","lidarscanner_burstscan_360scan","lidarscanner_burstscan_direction","lidarscanner_burstscan_reverse","lidarscanner_showdots",
	"lidarscanner_viewmodel_blurscale","lidarscanner_viewmodel_farscale","lidarscanner_mirror_enabled","lidarscanner_mirror_input_enabled","lidarscanner_developer","lidarscanner_hud_enabled",
	"lidarscanner_showscanspositions","lidarscanner_savescanspositions","lidarscanner_maxscanspositions","lidarscanner_background_enabled","lidarscanner_optimize_visible","lidarscanner_optimize_colour",
	"lidarscanner_nohitsky","lidarscanner_dotsize","lidarscanner_maxdots","lidarscanner_maxmeshes","lidarscanner_dotsperfastscan","lidarscanner_maxdist","lidarscanner_scansize","lidarscanner_scansize_scrollinput",
	"lidarscanner_scansize_sizediff","lidarscanner_scanlines_colour_r","lidarscanner_scanlines_colour_g","lidarscanner_scanlines_colour_b","lidarscanner_background_colour_r","lidarscanner_background_colour_g","lidarscanner_background_colour_b","lidarscanner_glitch_enabled","lidarscanner_showprojectors"}
	concommand.Add("lidarscanner_resetconvars",function()
		for k,v in pairs(ls_cvars) do
			local cvar = GetConVar(v)
			print("[" .. v .. "] " .. tostring(cvar:GetFloat()) .. " -> " .. tostring(cvar:GetDefault()))
			cvar:SetFloat(cvar:GetDefault())
		end
	end)
	local rt = render.GetScreenEffectTexture():GetName()
	local screeneffect_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_material","UnLitGeneric",{["$basetexture"]=rt,["$basetexturetransform"]="center .5 .5 scale -1 1 rotate 0 translate 0 0",["$ignorez"]=1})
	local screeneffect_glitch_r_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_r_material","UnLitGeneric",{["$basetexture"] = rt,["$color2"] = "[1 0 0]",["$ignorez"] = 1,["$additive"] = 1})
    local screeneffect_glitch_g_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_g_material","UnLitGeneric",{["$basetexture"] = rt,["$color2"] = "[0 1 0]",["$ignorez"] = 1,["$additive"] = 1})
    local screeneffect_glitch_b_mat = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_b_material","UnLitGeneric",{["$basetexture"] = rt,["$color2"] = "[0 0 1]",["$ignorez"] = 1,["$additive"] = 1})

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

	local lidarscanner_configuredcur = ""
	local extensions_currentext = {}
	local burstscan_pos = 2
	local scanspos = {}
	local scansang = {}
	local dynamicmesh = nil
	local updatedots = false
	local lidarscanner_readqueue = nil
	local curclrcalc = function() return Color(255,255,255) end

	local lines = {}
	local meshes = new_array()--{}
	local dynamic_dots_pos = new_array()
	local dynamic_dots_normal = new_array()
	local dynamic_dots_colour = new_array()

	local savedots = new_array()

	local pi2 = math.pi*2
	local threehalfs = 1.5
	local blurx = Material("pp/blurx")
	local blury = Material("pp/blury")
	local camerasmat = Material("models/wireframe")
	local scanmat = Material("lidarscanner2_valve_materials/scanned_dot_visible.png","nocull")
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
	local function LidarScanner_AddScanLine(linestart,lineend)
		lines[#lines+1] = {linestart,lineend}
	end
	local function safequad(pos,norm,sizex,sizey,colour)
		mesh.QuadEasy(pos or Vector(0,0,0),norm or Vector(0,0,0),sizex or 1,sizey or 1,colour or Color(255,255,255))
	end
	local frametime = (RealFrameTime()/2)
	local maxmeshes = GetConVarNumber("lidarscanner_maxmeshes")
	local dotsize = GetConVarNumber("lidarscanner_dotsize")
	local maxdots = GetConVarNumber("lidarscanner_maxdots")
	local colouropt = GetConVarNumber("lidarscanner_optimize_colour") == 1
	local shouldsave = GetConVarNumber("lidarscanner_savedots") == 1
	local function LidarScanner_AddDot(pos,normal,colour)
		if colouropt and (colour.r < 10 and colour.g < 10 and colour.b < 10) then return true end
		array_insertlast(dynamic_dots_pos,pos)
		array_insertlast(dynamic_dots_normal,normal)
		array_insertlast(dynamic_dots_colour,colour)
		if shouldsave then
			array_insertlast(savedots,{pos,normal,colour})
			if array_count(savedots) > 2147483647 then
				array_remove_last(savedots)
			end
		end
		updatedots = true
		if array_count(dynamic_dots_pos) > maxdots then
			local smesh = Mesh(scanmat)
			mesh.Begin(smesh,7,maxdots)
			for k,v in pairs(array_data(dynamic_dots_pos)) do
				safequad(v,array_get(dynamic_dots_normal,k),dotsize,dotsize,array_get(dynamic_dots_colour,k))
			end
			mesh.End()
			array_insertlast(meshes,smesh)
			if array_count(meshes) > maxmeshes then
				if IsValid(array_get_first(meshes)) then
					array_get_first(meshes):Destroy()
				end
				array_remove_first(meshes)
			end

			dynamic_dots_pos = new_array()
			dynamic_dots_normal = new_array()
			dynamic_dots_colour = new_array()
		end
	end
	local function LidarScanner_GetColour(mattype,hitpos,hitnormal,ind,scanpos)
		return curclrcalc(mattype,hitpos,hitnormal,ind,extensions_currentext,scanpos,burstscan_pos)--HSVToColor(ind,1,1)--Color(255,255,255)
	end
	-- Quick Reversed Square Root from Quake
	local function Q_rsqrt(number)
		local x2 = number*0.5
		local y = number
		local i = y
		i = 0x5f3759df - bit.rshift(i,1) -- magic byte
		y = y * (threehalfs - (x2 * y * y)) -- first iteration
		return y
	end
	local lplyeyedir = Vector(0,0,1)
	local function checkcamlookdot(ply,pos)
		if GetConVarNumber("lidarscanner_optimize_visible") ~= 1 then return true end
		local difference = pos - ply:EyePos()
		return lplyeyedir:Dot(difference) / difference:Length() > 0.4
	end
	local function LidarScanner_FixNormal(norm)
		norm = norm:GetNormalized() - Vector(0.000144,0,0)
	end
	local function LidarScanner_SaveScanPos(pos,ang)
		if GetConVarNumber("lidarscanner_savescanspositions") ~= 1 then return end
		scanspos[#scanspos+1] = pos
		scansang[#scansang+1] = ang
		if #scanspos > GetConVarNumber("lidarscanner_maxscanspositions") then
			table.remove(scanspos,1)
			table.remove(scansang,1)
		end
	end
	local function LidarScanner_DrawCamera(pos,ang)
		render.DrawQuadEasy(pos,ang:Forward(),5,2.5,Color(255,200,55),0)
		render.DrawQuadEasy(pos+ang:Up()+(ang:Forward()*0.5),-ang:Up(),1,1,Color(255,200,55),0)
	end
	local function LidarScanner_PreScan()
		maxmeshes = GetConVarNumber("lidarscanner_maxmeshes")
		colouropt = GetConVarNumber("lidarscanner_optimize_colour") == 1
		dotsize = GetConVarNumber("lidarscanner_dotsize")
		maxdots = GetConVarNumber("lidarscanner_maxdots")
		shouldsave = GetConVarNumber("lidarscanner_savedots") == 1
		if GetConVarNumber("lidarscanner_prescan_enabled") == 1 then
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
		maxmeshes = GetConVarNumber("lidarscanner_maxmeshes")
		colouropt = GetConVarNumber("lidarscanner_optimize_colour") == 1
		dotsize = GetConVarNumber("lidarscanner_dotsize")
		maxdots = GetConVarNumber("lidarscanner_maxdots")
		shouldsave = GetConVarNumber("lidarscanner_savedots") == 1
		if GetConVarNumber("lidarscanner_postscan_enabled") == 1 then
			for k,v in pairs(lidarscanner_extensions) do
				if v.enabled then
					if v.func_postscan then
						v.func_postscan()
					end
				end
			end
		end
	end
	local function LidarScanner_DoScan(scanpos,scanang,filter,lineemitpos)
		LidarScanner_PreScan()
		local hitsky = GetConVarNumber("lidarscanner_nohitsky") ~= 1
		local scansize = lidarscanner_convar_scansize:GetFloat()
		local maxdist = lidarscanner_convar_maxdist:GetFloat()
		for i = 1,GetConVarNumber("lidarscanner_dotsperfastscan")*(scansize/64) do
			local pos = scansize * Q_rsqrt(math.Rand(0,1))
			local h = math.Rand(0,1) * pi2
			local y = pos * math.sin(h)
			local x = pos * math.cos(h)
			local _,dang = LocalToWorld(Vector(0,0,0),Angle(y,x,0),Vector(0,0,0),scanang)
			local endpos = scanpos+(dang:Forward()*maxdist)
			local tr = util.TraceLine({start = scanpos,endpos = endpos,filter = filter})
			if (not tr.HitSky or hitsky) and tr.Hit then
				LidarScanner_FixNormal(tr.HitNormal)
				LidarScanner_AddDot(tr.HitPos,tr.HitNormal,LidarScanner_GetColour(tr.MatType,tr.HitPos,tr.HitNormal,i,scanpos))
				LidarScanner_AddScanLine(lineemitpos,tr.HitPos)
			end
		end
		LidarScanner_SaveScanPos(scanpos,scanang)
		hitsky = nil
		scansize = nil
		maxdist = nil
		LidarScanner_PostScan()
	end
	local function LidarScanner_DoBurstScan(mirrorenabled)
		if burstscan_pos > 1 then return end
		local ply = LocalPlayer()
		if not ply:Alive() then curscantype = 0 burstscan_pos = 1.1 return end
		curscantype = 2
		LidarScanner_PreScan()
		local scanpos,scanang,filter = ply:EyePos(),ply:EyeAngles(),ply
		local scandir = scanang:Forward()
		local hitsky = GetConVarNumber("lidarscanner_nohitsky") ~= 1
		local maxdist = lidarscanner_convar_maxdist:GetFloat()
		local scandir2 = 45
		local scanang2 = (burstscan_pos-0.5)*2
		if GetConVarNumber("lidarscanner_burstscan_180scan") == 1 then
			scandir2 = 90
			scanang2 = (burstscan_pos-0.5)*2
		end
		if GetConVarNumber("lidarscanner_burstscan_360scan") == 1 then
			scandir2 = 90
			scanang2 = (burstscan_pos-0.5)*4
		end
		if mirrorenabled then scandir2 = -scandir2 end if GetConVarNumber("lidarscanner_burstscan_reverse") == 1 then scandir2 = -scandir2 end
		local directionrotation = GetConVarNumber("lidarscanner_burstscan_direction") == 1
		if directionrotation then
			scandir2 = 45
			scanang2 = (burstscan_pos-0.5)*2
		end
		for i = -64,64 do
			local popang = nil
			if directionrotation then
				popang = ply:LocalToWorldAngles(Angle((scanang2*scandir2)+math.Rand(-0.025,0.025),((i)/1.5),0))
			else
				popang = ply:LocalToWorldAngles(Angle(((i)/2)+math.Rand(-0.025,0.025),scanang2*scandir2,0))
			end
			local tr = util.TraceLine({
				start = scanpos,
				endpos = scanpos+(popang:Forward()*maxdist),
				filter = filter
			})
			if (not tr.HitSky or hitsky) and tr.Hit then
				LidarScanner_FixNormal(tr.HitNormal)
				LidarScanner_AddDot(tr.HitPos,tr.HitNormal,LidarScanner_GetColour(tr.MatType,tr.HitPos,tr.HitNormal,i,scanpos))
				LidarScanner_AddScanLine(nil,tr.HitPos)
			end
		end
		LidarScanner_SaveScanPos(scanpos,scanang)
		burstscan_pos = burstscan_pos + frametime
		if burstscan_pos > 1 then
			curscantype = 0
		end
		hitsky = nil
		maxdist = nil
		scandir = nil
		LidarScanner_PostScan()
	end
	local function LidarScanner_StartBurstScan()
		frametime = (RealFrameTime()/2)
		--LidarScanner_DoBurstScan(GetConVarNumber("lidarscanner_mirror_enabled") == 1)
		burstscan_pos = 0
	end
	local function LidarScanner_ChangeColourCalc(ind)
		if not lidarscanner_extensions[ind] then return false end
		if not lidarscanner_extensions[ind].func_colourcalc then return false end
		lidarscanner_extensions[ind].enabled = true
		--if not IsColor(lidarscanner_extensions[ind].func_colourcalc(1,Vector(0,0,0),Vector(0,0,1),1)) then return false end
		curclrcalc = lidarscanner_extensions[ind].func_colourcalc
		extensions_currentext = lidarscanner_extensions[ind].variables
		extensions_currentext._name = lidarscanner_extensions[ind].name
		return true
	end
	function LidarScanner_ClearAllScans()
		for k,v in pairs(array_data(meshes)) do
			v:Destroy()
		end
		if IsValid(dynamicmesh) then dynamicmesh:Destroy() end
		meshes = new_array()--{}
		dynamic_dots_colour = new_array()
		dynamic_dots_normal = new_array()
		dynamic_dots_pos = new_array()
		savedots = new_array()
	end
	function LidarScanner_ClearLast()
		if array_count(dynamic_dots_pos) == 0 then
			if IsValid(array_get_last(meshes)) then
				array_get_last(meshes):Destroy()
			end
			array_remove_last(meshes)
		else
			if IsValid(dynamicmesh) then
				dynamicmesh:Destroy()
				dynamicmesh = nil
			end
			dynamic_dots_pos = new_array()
			dynamic_dots_normal = new_array()
			dynamic_dots_colour = new_array()
		end
		if GetConVarNumber("lidarscanner_savedots") == 1 then
			for i = 1,GetConVarNumber("lidarscanner_maxdots") do
				array_remove_last(savedots)
			end
		end
	end
	local function DrawWeaponModel(ply)
		cam.Start3D(ply:EyePos(),ply:EyeAngles())
		cam.IgnoreZ(true)
		local mdl = ClientsideModel("models/weapons/v_pistol.mdl")
		local scansc = 0
		if curscantype == 1 then
			scansc = 0.125
		elseif curscantype == 2 then
			scansc = 0.2
		end
		mdl:SetPos(ply:EyePos()+Vector((math.sin(CurTime())/10)+math.Rand(-scansc,scansc),math.Rand(-scansc,scansc),math.Rand(-scansc,scansc))-((ply:EyeAngles():Forward()*(render.GetViewSetup(true).fov/10))*GetConVarNumber("lidarscanner_viewmodel_farscale")))
		mdl:SetAngles(ply:EyeAngles())
		local bonepos = mdl:GetAttachment(mdl:LookupAttachment("muzzle")).Pos
		if not bonepos then bonepos = ply:LocalToWorld(Vector(70,-16,-4)) end
		local mirrorenabled = GetConVarNumber("lidarscanner_mirror_enabled") == 1 and GetConVarNumber("lidarscanner_enabled") == 1
		if mirrorenabled then
			-- flip Y
			bonepos = ply:WorldToLocal(bonepos)
			bonepos.y = -bonepos.y
			bonepos = ply:LocalToWorld(bonepos)
		end

		local colour = Color(GetConVarNumber("lidarscanner_scanlines_colour_r"),GetConVarNumber("lidarscanner_scanlines_colour_g"),GetConVarNumber("lidarscanner_scanlines_colour_b"))
		for k,v in pairs(lines) do
			if v[1] then
				render.DrawLine(v[1],v[2],colour,true)
			else
				render.DrawLine(bonepos,v[2],colour,true)
			end
		end
		if mirrorenabled then
			cam.Start2D()
			render.UpdateScreenEffectTexture(0)
			render.SetMaterial(screeneffect_mat)
			render.DrawScreenQuad()
			render.UpdateScreenEffectTexture(0)
			cam.End2D()
		end
		lines = {}
			if GetConVarNumber("lidarscanner_background_enabled") == 1 and GetConVarNumber('lidarscanner_enabled') == 1 then
				render.SuppressEngineLighting(true)
				render.ResetModelLighting(0,0,0)
				-- it still does not work without suppress. so let is just not waste the resources
				if curscantype ~= 0 then
					render.SetLocalModelLights({{type = 1,color = colour:ToVector(),pos = bonepos+(mdl:GetUp()*2),range = 10,}})
				end
			end
			render.SetStencilEnable(true)
			render.ClearStencil()
			render.SetStencilTestMask(255)
			render.SetStencilWriteMask(255)
			render.SetStencilPassOperation(STENCILOPERATION_KEEP)
			render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
			render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
			render.SetStencilReferenceValue(9)
			render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
			mdl:DrawModel()
			render.SetStencilFailOperation(STENCILOPERATION_KEEP)
			render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
			render.OverrideAlphaWriteEnable(true,false)
			mdl:DrawModel()
			--render.ClearDepth()
			cam.IgnoreZ(false)
			cam.End3D()
			local vblurscale = GetConVarNumber("lidarscanner_viewmodel_blurscale")
			render.UpdateScreenEffectTexture(0)
			local rt = render.GetScreenEffectTexture(0)
			blurx:SetTexture("$basetexture",rt)
			blurx:SetFloat("$size",vblurscale)
			render.SetMaterial(blurx)
			render.DrawScreenQuad()
			render.UpdateScreenEffectTexture(0)
			blury:SetTexture("$basetexture",rt)
			blury:SetFloat("$size",vblurscale)
			render.SetMaterial(blury)
			render.DrawScreenQuad()
			render.SetStencilEnable(false)
			mdl:Remove()
		render.SuppressEngineLighting(false)
	end
	function LidarScanner_SaveScans(oldfilename)
		local oldfilename = oldfilename .. ".txt"
		local infofilename = "lidarscanner_savedscans/_info.json"
		local filename = "lidarscanner_savedscans/" .. oldfilename
		local arraysize = array_count(savedots)
		file.Write(infofilename,"0/" .. arraysize)
		file.Write(filename,"LIDARSCANNERSCANFILE") -- 20
		local maxnum = GetConVarNumber("lidarscanner_savescans_syncwritesnum")
		local str = ""
		local rp = 0
		for k,v in pairs(array_data(savedots)) do
			str = str .. "\n" .. util.TableToJSON(v)
			rp = rp + 1
			if rp > maxnum then
				file.Append(filename,str)
				file.Write(infofilename,oldfilename .. "\n" .. k .. "/" .. arraysize)
				str = ""
				rp = 0
			end
		end
		if rp ~= 0 then
			file.Append(filename,str)
			file.Write(infofilename,oldfilename .. "\n" .. arraysize .. "/" .. arraysize .. "\nDONE")
			system.FlashWindow()
		end
		str = nil
		rp = nil
		maxnum = nil
		arraysize = nil
		filename = nil
		infofilename = nil
	end
	function LidarScanner_LoadScans(filename)
		local file = file.Open("lidarscanner_savedscans/" .. filename .. ".txt","r","DATA")
		local header = file:Read(20)
		if header == "LIDARSCANNERSCANFILE" then
			file:Seek(20)
			--file:ReadLine()
			for i = 1,2147483647 do
				local data = file:ReadLine()
				if not data then break end
				if #data == 0 then
					break
				else
					local tbl = util.JSONToTable(data)
					if tbl then
						local pos,normal,colour = tbl[1],tbl[2],tbl[3]
						LidarScanner_AddDot(pos or Vector(0,0,0),normal or Vector(0,0,0),colour or Color(0,0,0))
					end
				end
			end
		else
			print("HEADER NOT VALID: " .. header .. " " .. "LIDARSCANNERSCANFILE")
		end
		file:Close()
	end
	concommand.Add("lidarscanner_clearallscans",LidarScanner_ClearAllScans)
	local function vfunc(self,w,h,cvardesc,df)
		if not self:GetParent():HasFocus() then return end
		local cx,cy = self:LocalCursorPos()
		if cx>0 and cy>0 and cx<math.min(w,df or w) and cy<h then
			local old = DisableClipping(true)
			surface.SetFont("DermaDefault")
			local textw,texth = surface.GetTextSize(cvardesc)
			draw.RoundedBox(3,cx+10,cy,textw,texth,Color(200,200,200))
			draw.SimpleText(cvardesc,"DermaDefault",cx+10,cy,Color(10,10,10))
			DisableClipping(old)
		end
	end
	local function headertext(par,x,y,text)
		local label = vgui.Create("DLabel",par)
		label:SetPos(x,y)
		label:SetText(text)
		label:SetFont("HudHintTextLarge")
		label:SizeToContents()
		return label
	end
	local function helptext(par,x,y,text)
		local label = vgui.Create("DLabel",par)
		label:SetPos(x,y)
		label:SetText(text)
		label:SizeToContents()
		return label
	end
	local function slider(par,x,y,w,text,cvarname,dec,def,min,max,desc,sfunc,val)
		local cvar = nil
		if cvarname then
			cvar = GetConVar(cvarname)
			if not cvar then return end
		end
		local cvardesc = ""
		if cvarname then
			cvardesc = cvar:GetHelpText() .. " (" .. tostring(cvarname) .. ")"
		else
			cvardesc = desc or "*none provided*"
		end
		local slider = nil
		local slider_Btn_Increase = vgui.Create("DButton",par)
		slider_Btn_Increase:SetPos(x+w,y)
		slider_Btn_Increase:SetText("+")
		slider_Btn_Increase:SetSize(15,15)
		slider_Btn_Increase.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		slider_Btn_Increase.DoClick = function()
			slider:SetValue(slider:GetValue()+1)
		end
		local slider_Btn_Decrease = vgui.Create("DButton",par)
		slider_Btn_Decrease:SetPos(x+w+16,y)
		slider_Btn_Decrease:SetText("-")
		slider_Btn_Decrease:SetSize(15,15)
		slider_Btn_Decrease.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		slider_Btn_Decrease.DoClick = function()
			slider:SetValue(slider:GetValue()-1)
		end
		local slider_Btn_DefaultVal = vgui.Create("DButton",par)
		slider_Btn_DefaultVal:SetPos(x+w+32,y)
		slider_Btn_DefaultVal:SetText("DEF")
		slider_Btn_DefaultVal:SetSize(32,15)
		slider_Btn_DefaultVal.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		if cvarname then
			slider_Btn_DefaultVal.DoClick = function()
				slider:SetValue(cvar:GetDefault())
			end
		else
			slider_Btn_DefaultVal.DoClick = function()
				slider:SetValue(def)
			end
		end
		slider = vgui.Create("DNumSlider",par)
		slider:SetPos(x,y)
		slider:SetText(text)
		slider:SetSize(w,15)
		slider:SetDecimals(dec or 0)
		if cvarname then
			slider:SetMin(cvar:GetMin())
			slider:SetMax(cvar:GetMax())
			slider:SetConVar(cvarname)
		else
			slider:SetMin(min)
			slider:SetMax(max)
			slider:SetValue(val)
			slider.OnValueChanged = function(self,value)
				sfunc(value)
			end
		end
		slider.PaintOver = function(self,w,h) vfunc(self,w,h,cvardesc,200) end
		slider.Btn_Increase = slider_Btn_Increase
		slider.Btn_Decrease = slider_Btn_Decrease
		slider.Btn_DefaultVal = slider_Btn_DefaultVal
		slider.OnRemove = function()
			slider.Btn_Increase:Remove()
			slider.Btn_Decrease:Remove()
			slider.Btn_DefaultVal:Remove()
		end
		return slider
	end
	local function checkbox(par,x,y,text,cvarname,parentcvarname,val,sfunc,desc)
		local cvar = nil
		if cvarname then
			cvar = GetConVar(cvarname)
			if not cvar then return end
		end
		local cvardesc = ""
		if cvarname then
			cvardesc = cvar:GetHelpText() .. " (" .. tostring(cvarname) .. ")"
		else
			cvardesc = desc or "*none provided*"
		end
		local parentcvar = nil
		if parentcvarname then
			parentcvar = GetConVar(parentcvarname)
			if not parentcvar then return end
		end
		local checkbox = vgui.Create("DCheckBoxLabel",par)
		checkbox:SetPos(x,y)
		checkbox:SetText(text)
		if cvarname then
			checkbox:SetConVar(cvarname)
			checkbox:SetValue(cvar:GetInt() == 1)
		else
			checkbox.OnChange = function(self,value)
				sfunc(value)
			end
			checkbox:SetValue(val)
		end
		checkbox:SizeToContents()
		if parentcvar then
			checkbox.PaintOver = function(self,w,h)
				if parentcvar:GetInt() == 1 then
					self:SetDisabled(false)
				else
					self:SetDisabled(true)
				end
				vfunc(self,w,h,cvardesc)
			end
		else
			checkbox.PaintOver = function(self,w,h) vfunc(self,w,h,cvardesc) end
		end
		return checkbox
	end
	local function button(par,x,y,w,h,text,func)
		local button = vgui.Create("DButton",par)
		button:SetPos(x,y)
		button:SetText(text)
		button:SetSize(w,h)
		button.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		button.DoClick = func or function() end
		return button
	end
	local function binder(parent,x,y,w,h,bindcmd,bindname)
		local binder = vgui.Create("DBinder",parent)
		binder:SetPos(x,y)
		binder:SetSize(w,h)
		binder:SetText(bindname)
		binder.bind_cmdname = bindcmd
		binder.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		binder.OnChange = function(self,keynumber)
			chat.AddText(Color(255,200,10),"Now open the console, paste the clipboard text using CTR+V and press Enter")
			SetClipboardText('bind "' .. tostring(input.GetKeyName(keynumber)) .. '" "' .. tostring(self.bind_cmdname) .. '"')
		end
	end
	concommand.Add("lidarscanner_openbindsmenu",function()
		local extlist_curext = nil
		local frame = vgui.Create("DFrame")
		frame:SetSize(256,256)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("LidarScanner Bindings Menu","DermaDefault",5,5,Color(200,200,200),0,3)
		end
		binder(frame,5,30,128,64,"lidarscanner_scansize_up","Increase Scan Size")
		binder(frame,5,94,128,64,"lidarscanner_scansize_down","Decrease Scan Size")
		binder(frame,5,158,128,64,"+lidarscanner_scansize_unlockscroll","Unlock Scroll Scan Size")
	end)
	concommand.Add("lidarscanner_openextmenu",function()
		local extlist_curext = nil
		local frame = vgui.Create("DFrame")
		frame:SetSize(640,480)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("LidarScanner Extensions Menu","DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		frame.PaintOver = function(self,w,h)
			draw.SimpleText("SHIFT to toggle extension","DermaDefault",405,465,Color(10,10,10))
			if extlist_curext then
				draw.DrawText(extlist_curext.name,"DermaLarge",405,50,Color(10,10,10))
				draw.DrawText(extlist_curext.desc,"DermaDefault",410,80,Color(10,10,10))
			else
				draw.DrawText("SELECT\nEXTENSION","DermaLarge",512,200,Color(10,10,10),1)
			end
		end
		local btn_togglecolour = nil
		local btn_toggleextension = nil
		local ext_gui = nil
		local extlist = vgui.Create("DListView",frame)
		extlist:SetPos(0,30)
		extlist:SetSize(400,450)
		extlist:SetMultiSelect(false)
		extlist:AddColumn("CLR")
		extlist:AddColumn("Ind")
		extlist:AddColumn("Enabled")
		extlist:AddColumn("Name")
		extlist:AddColumn("Ver")
		extlist:AddColumn("Colour")
		extlist:AddColumn("PreScan")
		extlist:AddColumn("PostScan")
		local function cbform(bool)
			if bool then
				return " +"
			else
				return " -"
			end
		end
		local function rebuildextensionlist()
			for k,v in pairs(extlist:GetLines()) do
				extlist:RemoveLine(k)
			end
			for k,v in pairs(lidarscanner_extensions) do
				extlist:AddLine(cbform((extensions_currentext and v.name == extensions_currentext._name)),k,cbform(v.enabled),v.name,v.version,cbform(type(v.func_colourcalc) == "function"),cbform(type(v.func_prescan) == "function"),cbform(type(v.func_postscan) == "function"))
			end
		end
		local btn_refreshall = vgui.Create("DButton",frame)
		btn_refreshall:SetPos(404,35)
		btn_refreshall:SetSize(64,16)
		btn_refreshall:SetText("refresh")
		btn_refreshall.DoClick = rebuildextensionlist
		local btn_reloadall = vgui.Create("DButton",frame)
		btn_reloadall:SetPos(512,35)
		btn_reloadall:SetSize(64,16)
		btn_reloadall:SetText("reload")
		btn_reloadall.DoClick = function() LidarScanner_SaveExtConfigFile() LidarScanner_LoadExtensions() end
		local function toggleextension(ind)
			-- toggle extension
			lidarscanner_extensions[ind].enabled = not lidarscanner_extensions[ind].enabled
			if not lidarscanner_extensions[ind].enabled then
				if extensions_currentext then
					if extensions_currentext._name == lidarscanner_extensions[ind].name then
						extensions_currentext = {}
					end
				end
				curclrcalc = function() return Color(255,255,255) end
			end
			rebuildextensionlist()
		end
		extlist.OnRowSelected = function(lst,index,pnl)
			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
				toggleextension(pnl:GetColumnText(2))
			else
				local pind = pnl:GetColumnText(2)
				local tbl = lidarscanner_extensions[pind]
				extlist_curext = {ind = pind,name = tbl.name,desc = tbl.desc,enabled = tbl.enabled}
				if btn_togglecolour then btn_togglecolour:Remove() end
				if btn_toggleextension then btn_toggleextension:Remove() end
				if ext_gui then
					for k,v in pairs(ext_gui) do v:Remove() end
				end
				btn_togglecolour = vgui.Create("DButton",frame)
				btn_togglecolour:SetPos(425,425)
				btn_togglecolour:SetSize(196,32)
				btn_togglecolour:SetText("SET AS COLOUR ALGORITHM")
				btn_togglecolour.DoClick = function() LidarScanner_ChangeColourCalc(extlist_curext.ind) rebuildextensionlist() end
				btn_toggleextension = vgui.Create("DButton",frame)
				btn_toggleextension:SetPos(425,393)
				btn_toggleextension:SetSize(196,32)
				btn_toggleextension:SetText("TOGGLE EXTENSION")
				btn_toggleextension.DoClick = function() toggleextension(extlist_curext.ind) rebuildextensionlist() end
				ext_gui = {}
				for k,v in pairs(tbl.gui) do
					local newguielement = nil
					local sffunc = function(val) lidarscanner_extensions[pind].variables[v.variable] = val end
					if v.type == "slider" then
						newguielement = slider(frame,400+v.pos_x,100+v.pos_y,v.size,v.name,nil,v.dec,v.def,v.min,v.max,v.desc,sffunc,lidarscanner_extensions[pind].variables[v.variable])
					end
					if v.type == "checkbox" then
						newguielement = checkbox(frame,400+v.pos_x,100+v.pos_y,v.name,nil,nil,lidarscanner_extensions[pind].variables[v.variable],sffunc,v.desc)
					end
					if v.type == "header" then
						newguielement = headertext(frame,400+v.pos_x,100+v.pos_y,v.name)
					end
					if v.type == "text" then
						newguielement = helptext(frame,400+v.pos_x,100+v.pos_y,v.name)
						newguielement:SetFont("DebugFixed")
						newguielement:SizeToContents()
					end
					if newguielement then
						ext_gui[#ext_gui+1] = newguielement
					end
				end
			end
		end
		rebuildextensionlist()
	end)
	concommand.Add("lidarscanner_openscanlinesmenu",function()
		local frame = vgui.Create("DFrame")
		frame:SetSize(640,480)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.btnMaxim:Hide(true)
		frame.btnMinim:Hide(true)
		frame.btnClose.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
			draw.SimpleText("X","DermaLarge",7,-4,Color(10,10,10))
		end
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Scan Lines Menu","DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		helptext(frame,495,30,"Scan lines colour:")
		local scanlines_preview_background_image = vgui.Create("DImage",frame)
		scanlines_preview_background_image:SetPos(5,30)
		scanlines_preview_background_image:SetSize(444,444)
		scanlines_preview_background_image:SetImage("lidarscanner2_valve_materials/gui/scanlines_preview_background_image.png")
		local scanlines_preview_foreground_image = vgui.Create("DImage",frame)
		scanlines_preview_foreground_image:SetPos(5,30)
		scanlines_preview_foreground_image:SetSize(444,444)
		scanlines_preview_foreground_image:SetImage("lidarscanner2_valve_materials/gui/scanlines_preview_foreground_image.png")
		local colour_picker = vgui.Create("DRGBPicker",frame)
		colour_picker:SetPos(623,50)
		colour_picker:SetSize(15,128)
		local colour_cube = vgui.Create("DColorCube",frame)
		colour_cube:SetPos(495,50)
		colour_cube:SetSize(128,128)
		colour_cube.OnUserChanged = function(self,col)
			RunConsoleCommand("lidarscanner_scanlines_colour_r",col.r)
			RunConsoleCommand("lidarscanner_scanlines_colour_g",col.g)
			RunConsoleCommand("lidarscanner_scanlines_colour_b",col.b)
			scanlines_preview_foreground_image:SetImageColor(col)
		end
		colour_picker.OnChange = function(self,col)
			local h = ColorToHSV(col)
			local _, s, v = ColorToHSV(colour_cube:GetRGB())
			col = HSVToColor(h, s, v)
			colour_cube:SetColor(col)
			colour_cube.OnUserChanged(colour_cube,col)
		end

		helptext(frame,495,240,"Background colour:")
		local colour_picker_background = vgui.Create("DRGBPicker",frame)
		colour_picker_background:SetPos(623,256)
		colour_picker_background:SetSize(15,128)
		local colour_cube_background = vgui.Create("DColorCube",frame)
		colour_cube_background:SetPos(495,256)
		colour_cube_background:SetSize(128,128)
		colour_cube_background.OnUserChanged = function(self,col)
			scanlines_preview_background_image:SetImageColor(col)
		end
		colour_cube_background:SetColor(Color(255,255,255))
		colour_picker_background.OnChange = function(self,col)
			local h = ColorToHSV(col)
			local _, s, v = ColorToHSV(colour_cube_background:GetRGB())
			col = HSVToColor(h, s, v)
			colour_cube_background:SetColor(col)
			colour_cube_background.OnUserChanged(colour_cube_background,col)
		end

		local vscanlinecolour = Color(GetConVarNumber("lidarscanner_scanlines_colour_r"),GetConVarNumber("lidarscanner_scanlines_colour_g"),GetConVarNumber("lidarscanner_scanlines_colour_b"))
		colour_cube:SetColor(vscanlinecolour)
		scanlines_preview_foreground_image:SetImageColor(vscanlinecolour)
		local slider_r = slider(frame,455,180,200,"Scan lines R","lidarscanner_scanlines_colour_r",0)
		local slider_g = slider(frame,455,195,200,"Scan lines G","lidarscanner_scanlines_colour_g",0)
		local slider_b = slider(frame,455,210,200,"Scan lines B","lidarscanner_scanlines_colour_b",0)
		slider_r.OnValueChanged = function(self,val) local col = Color(val,GetConVarNumber("lidarscanner_scanlines_colour_g"),GetConVarNumber("lidarscanner_scanlines_colour_b")) scanlines_preview_foreground_image:SetImageColor(col) colour_cube:SetColor(col) end
		slider_g.OnValueChanged = function(self,val) local col = Color(GetConVarNumber("lidarscanner_scanlines_colour_r"),val,GetConVarNumber("lidarscanner_scanlines_colour_b")) scanlines_preview_foreground_image:SetImageColor(col) colour_cube:SetColor(col) end
		slider_b.OnValueChanged = function(self,val) local col = Color(GetConVarNumber("lidarscanner_scanlines_colour_r"),GetConVarNumber("lidarscanner_scanlines_colour_g"),val) scanlines_preview_foreground_image:SetImageColor(col) colour_cube:SetColor(col) end
	end)
	concommand.Add("lidarscanner_opensavescansavesmenu",function()
		local writequeue = nil
		local savemenu = vgui.Create("DFrame")
		savemenu:SetSize(512,128)
		savemenu:Center()
		savemenu:SetTitle("")
		savemenu:MakePopup()
		savemenu:SetDraggable(false)
		local label = nil
		savemenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner Save Scans Menu","DermaDefault",5,5,Color(127,200,255),0,3)
			if writequeue then
				timer.Simple(RealFrameTime(),function()
					if writequeue then
						LidarScanner_SaveScans(writequeue)
						if label then label:Remove() end
						writequeue = nil
					end
				end)
			end
		end
        local text_entry_filename = vgui.Create("DTextEntry",savemenu)
        text_entry_filename:SetPos(11,60)
		text_entry_filename:SetSize(379,25)
		text_entry_filename:SetPlaceholderText("scan save name without extension")
		button(savemenu,405,57,64,32,"SAVE",function()
			if not writequeue then
				if text_entry_filename:GetValue() then
					label = vgui.Create("DLabel",savemenu)
					label:SetPos(5,90)
					label:SetText("do not worry, we will save everything quickly...\nyou can watch the process in the folder Garry's Mod/garrysmod/data/lidarscanner_savedscans/_info.json")
					label:SizeToContents()
					writequeue = text_entry_filename:GetValue()
				end
			end
		end)
	end)
	concommand.Add("lidarscanner_openloadscansavesmenu",function()
		local loadmenu = vgui.Create("DFrame")
		loadmenu:SetSize(512,256)
		loadmenu:Center()
		loadmenu:SetTitle("")
		loadmenu:MakePopup()
		loadmenu:SetDraggable(false)
		loadmenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner Load Scans Menu","DermaDefault",5,5,Color(200,255,200),0,3)
		end
		local saveslist = vgui.Create("DListView",loadmenu)
		saveslist:SetPos(0,30)
		saveslist:SetSize(400,224)
		saveslist:SetMultiSelect(false)
		saveslist:AddColumn("Ind")
		saveslist:AddColumn("Name")
		saveslist:AddColumn("Size(KB)")
		local function reloadsaveslist()
			for k,v in pairs(saveslist:GetLines()) do
				saveslist:RemoveLine(k)
			end
			for k,v in pairs(file.Find("lidarscanner_savedscans/*.txt","DATA")) do
				saveslist:AddLine(k,string.TrimRight(v,".txt"),math.Round(file.Size("lidarscanner_savedscans/" .. v,"DATA")/1024,2))
			end
		end
		reloadsaveslist()
		button(loadmenu,405,60,64,32,"LOAD",function() local _,pnl = saveslist:GetSelectedLine() if pnl then LidarScanner_LoadScans(pnl:GetColumnText(2)) reloadsaveslist() end end)
		button(loadmenu,405,30,64,16,"REFRESH",function() reloadsaveslist() end)
	end)
	concommand.Add("lidarscanner_opensaveloadmenu",function()
		local saveloadmenu = vgui.Create("DFrame")
		saveloadmenu:SetSize(400,140)
		saveloadmenu:Center()
		saveloadmenu:SetTitle("")
		saveloadmenu:MakePopup()
		saveloadmenu:SetDraggable(false)
		saveloadmenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner Save/Load Menu","DermaDefault",5,5,Color(255,200,127),0,3)
		end
		
		headertext(saveloadmenu,48,30,"Extensions")
		button(saveloadmenu,5,60,64,32,"LOAD CFG",function() RunConsoleCommand("lidarscanner_extensions_reload","") end)
		button(saveloadmenu,96,60,64,32,"SAVE CFG",function() RunConsoleCommand("lidarscanner_extensions_save_config","") end)

		headertext(saveloadmenu,256,30,"Scans saves")
		button(saveloadmenu,213,60,64,32,"LOAD",function() RunConsoleCommand("lidarscanner_openloadscansavesmenu","") end)
		button(saveloadmenu,304,60,64,32,"SAVE",function() RunConsoleCommand("lidarscanner_opensavescansavesmenu","") end)
		headertext(saveloadmenu,128,94,"FOR THE SAVE FUNCTION TO WORK,\nYOU NEED lidarscanner_savedots 1 \nBEFORE SCANNING!!!!!!")
	end)
	concommand.Add("lidarscanner_openmenu",function()
		local frame = vgui.Create("DFrame")
		frame:SetSize(640,256)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.btnMaxim:Hide(true)
		frame.btnMinim:Hide(true)
		frame.btnClose.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
			draw.SimpleText("X","DermaLarge",9,-2,Color(127,127,127))
			draw.SimpleText("X","DermaLarge",8,-3,Color(75,75,75))
			draw.SimpleText("X","DermaLarge",7,-4,Color(10,10,10))
		end
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner " .. tostring(LIDARSCANNER_VERSION),"DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		button(frame,574,62,64,32,"   CLEAR\n   SCANS",function()
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,128)
			popup_window:Center()
			popup_window:SetTitle("WARNING")
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetPos(30,30)
			label:SetText("Are you sure you want to clear all scans?\n (lidarscanner_clearallscans)")
			label:SizeToContents()
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,90)
			reset_btn_accept:SetSize(32,32)
			reset_btn_accept:SetText("YES")
			reset_btn_accept.DoClick = function() RunConsoleCommand("lidarscanner_clearallscans","") popup_window:Close() end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,64)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText("NO")
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)
		button(frame,574,94,64,32,"BINDS",function() RunConsoleCommand("lidarscanner_openbindsmenu","") end)
		button(frame,542,126,96,32,"EXTENSIONS",function() RunConsoleCommand("lidarscanner_openextmenu","") end)
		button(frame,510,158,128,32,"SAVE/LOAD MENU",function() RunConsoleCommand("lidarscanner_opensaveloadmenu","")end)
		button(frame,510,190,128,32,"RESET SETTINGS",function()
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,128)
			popup_window:Center()
			popup_window:SetTitle("WARNING")
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetPos(30,30)
			label:SetText("Are you sure you want to reset settings?\n (lidarscanner_resetconvars)")
			label:SizeToContents()
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,90)
			reset_btn_accept:SetSize(32,32)
			reset_btn_accept:SetText("YES")
			reset_btn_accept.DoClick = function() RunConsoleCommand("lidarscanner_resetconvars","") popup_window:Close() end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,64)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText("NO")
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)
		button(frame,510,222,128,32,"SCAN LINES COLOUR",function() RunConsoleCommand("lidarscanner_openscanlinesmenu","") end)

		headertext(frame,280,105,"Burst Scan")
		
		checkbox(frame,282,120,"Rotated","lidarscanner_burstscan_direction")
		checkbox(frame,282,135,"Reversed","lidarscanner_burstscan_reverse")
		checkbox(frame,282,150,"180 degrees","lidarscanner_burstscan_180scan")
		checkbox(frame,282,165,"360 degrees","lidarscanner_burstscan_360scan")

		headertext(frame,280,180,"Other")

		checkbox(frame,282,195,"Weapon HUD","lidarscanner_hud_enabled")
		checkbox(frame,282,210,"Optimize Visible","lidarscanner_optimize_visible")
		checkbox(frame,282,225,"Optimize Colour","lidarscanner_optimize_colour")
		checkbox(frame,282,240,"Glitch","lidarscanner_glitch_enabled")
		checkbox(frame,390,195,"PreScan Functions","lidarscanner_prescan_enabled")
		checkbox(frame,390,210,"PostScan Functions","lidarscanner_postscan_enabled")
		checkbox(frame,390,225,"!!Save Dots!!","lidarscanner_savedots")
		checkbox(frame,390,240,"Seeker(admin only)","lidarscanner_sv_seeker_enabled")

		headertext(frame,5,30,"General")

		checkbox(frame,7,45,"Enabled","lidarscanner_enabled")
		checkbox(frame,7,60,"Blindness enabled","lidarscanner_background_enabled")
		checkbox(frame,7,75,"Mirror enabled","lidarscanner_mirror_enabled")
		checkbox(frame,9,90,"Mirror input","lidarscanner_mirror_input_enabled","lidarscanner_mirror_enabled")

		headertext(frame,5,105,"Scan")

		slider(frame,10,120,200,"Dot Size","lidarscanner_dotsize",1)
		slider(frame,10,135,200,"Max dots","lidarscanner_maxdots",0)
		slider(frame,10,150,200,"Max meshes","lidarscanner_maxmeshes",0)
		checkbox(frame,7,165,"No Hit Sky","lidarscanner_nohitsky")
		
		headertext(frame,5,180,"View Model")

		slider(frame,10,195,200,"Blur Scale","lidarscanner_viewmodel_blurscale",2)
		slider(frame,10,210,200,"Far Scale","lidarscanner_viewmodel_farscale",2)

		headertext(frame,196,30,"Fast Scan")

		slider(frame,199,45,300,"Scan Size","lidarscanner_scansize",1)
		slider(frame,199,60,300,"Scan Size Bind Difference","lidarscanner_scansize_sizediff",1)
		checkbox(frame,196,75,"Scan Size Scroll Control","lidarscanner_scansize_scrollinput")
		slider(frame,199,90,300,"Dots per scan","lidarscanner_dotsperfastscan",0)

		checkbox(frame,564,27,"Developer","lidarscanner_developer")
	end)
	net.Receive("lidarscanner2_network",function()
		if GetConVarNumber("lidarscanner_enabled") ~= 1 then return end
		local ply = LocalPlayer()
		if IsValid(ply) then
			local int = net.ReadInt(3)
			if int then
				if int == -3 then
					screen_glitch = 3
				else
					lidarscanner_readqueue = {int = int,start = net.ReadVector(),angles = net.ReadAngle(),ent = net.ReadEntity()}
				end
			end
		end
	end)
	local function DrawGlitchEffect()
		if GetConVarNumber("lidarscanner_glitch_enabled") == 1 then
			local glitch = screen_glitch
			if glitch > 1 then
				glitch = glitch + (math.sin(CurTime())*20)
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
			addoninitialized = true
		end
		if GetConVarNumber("lidarscanner_enabled") ~= 1 then
			local ply = LocalPlayer()
			if IsValid(ply) then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) then
					if wep:GetClass() == "lidarscanner2_lidarscanner" then
						DrawWeaponModel(ply)
					end
				end
			end
			return
		end
		LidarScanner_DoBurstScan(GetConVarNumber("lidarscanner_mirror_enabled") == 1)
		if lidarscanner_readqueue then
			local int = lidarscanner_readqueue.int
			if int == -2 then
				local start = lidarscanner_readqueue.start
				local angles = lidarscanner_readqueue.angles
				local ent = lidarscanner_readqueue.ent
				LidarScanner_DoScan(start,angles,ent,start)
			elseif int == -1 then
				if burstscan_pos > 1 then
					curscantype = 0
				end
			elseif int == 0 then
				LidarScanner_ClearLast()
			elseif int == 1 then
				local ply = LocalPlayer()
				curscantype = 1
				LidarScanner_DoScan(ply:EyePos(),ply:EyeAngles(),ply)
			elseif int == 2 then
				LidarScanner_StartBurstScan()
				curscantype = 2
			end
			lidarscanner_readqueue = nil
		end
		if GetConVarNumber("lidarscanner_background_enabled") == 1 then
			cam.Start2D()
			draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(GetConVarNumber("lidarscanner_background_colour_r"),GetConVarNumber("lidarscanner_background_colour_g"),GetConVarNumber("lidarscanner_background_colour_b")))
			cam.End2D()
			if GetConVarNumber("lidarscanner_showprojectors") == 1 then
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
		end
		local ply = LocalPlayer()
		if IsValid(ply) then
			cam.Start3D()
			cam.IgnoreZ(true)
			if GetConVarNumber("lidarscanner_showdots") == 1 then
				render.SetMaterial(scanmat)
				for k,v in pairs(array_data(meshes)) do
					v:Draw()
				end
				if IsValid(dynamicmesh) then
					dynamicmesh:Draw()
				end
				if updatedots then
					if array_count(dynamic_dots_pos) > 0 then
						lplyeyedir = LocalPlayer():GetAimVector()
						local dotsize = GetConVarNumber("lidarscanner_dotsize")
						if IsValid(dynamicmesh) then
							dynamicmesh:Destroy()
							dynamicmesh = nil
						end
						dynamicmesh = Mesh(scanmat)
						mesh.Begin(dynamicmesh,7,3000)
						for k,v in pairs(array_data(dynamic_dots_pos)) do
							if checkcamlookdot(ply,v) then
								safequad(v,array_get(dynamic_dots_normal,k),dotsize,dotsize,array_get(dynamic_dots_colour,k))
							end
						end
						mesh.End()
					end
					updatedots = false 
				end
			end
			if GetConVarNumber("lidarscanner_showscanspositions") == 1 then
				render.SetMaterial(camerasmat)
				for k,v in pairs(scanspos) do
					LidarScanner_DrawCamera(v,scansang[k] or Angle(0,0,0))
				end
			end
			cam.IgnoreZ(false)
			cam.End3D()
			local swep = true
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then
				if wep:GetClass() == "lidarscanner2_lidarscanner" then
					swep = false
					DrawWeaponModel(ply)
					if GetConVarNumber("lidarscanner_scansize_scrollinput") == 1 then
						if input_scansize_canscroll then
							lidarscanner_convar_scansize:SetFloat(lidarscanner_convar_scansize:GetFloat()+math.Clamp(input.GetAnalogValue(3)/10,-4,4))
						end
					end
					DrawGlitchEffect()
					cam.Start2D()
					if GetConVarNumber("lidarscanner_hud_enabled") == 1 then
						draw.RoundedBox(3,(ScrW()/2.5),ScrH()/1.125,ScrW()/5,ScrH()/50,Color(55,55,55))
						local sizew = (ScrW()/5)*(lidarscanner_convar_scansize:GetFloat()/64)
						draw.RoundedBox(3,(ScrW()/2)-(sizew/2),ScrH()/1.125,sizew,ScrH()/50,Color(127,127,127))
						draw.SimpleText(tostring(math.Round(lidarscanner_convar_scansize:GetFloat(),1)),"DermaDefault",ScrW()/2,ScrH()/1.125,Color(10,10,10),1,3)
						if input_scansize_canscroll and GetConVarNumber("lidarscanner_scansize_scrollinput") == 1 then
							local sizew = (ScrW()/10)*math.Clamp((input.GetAnalogValue(3)/8)+0.5,0.1,1)
							draw.RoundedBox(3,(ScrW()/2)-(sizew/2),ScrH()*0.9022,sizew,ScrH()/150,Color(255,255,255))
							draw.SimpleText(tostring(math.Clamp(input.GetAnalogValue(3)/8,-0.5,0.5)),"DebugFixed",ScrW()/2,(ScrH()*0.9022)-5,Color(10,10,10),1,3)
						end
					end
					cam.End2D()
				end
			end
			if swep then
				if GetConVarNumber("lidarscanner_mirror_enabled") == 1 then
					cam.Start2D()
					render.UpdateScreenEffectTexture(0)
					render.SetMaterial(screeneffect_mat)
					render.DrawScreenQuad()
					render.UpdateScreenEffectTexture(0)
					cam.End2D()
				end
				DrawGlitchEffect()
			end
			if GetConVarNumber("lidarscanner_developer") == 1 then
				cam.Start2D()
				draw.DrawText("FramesPerSecond: " .. tostring(math.floor(1/RealFrameTime())) .. "\nMeshes: " .. tostring(array_count(meshes)) .. "\nDots:" .. tostring(array_count(dynamic_dots_pos)) .. "\nLines:" .. tostring(#lines) .. "\nScans positions: " .. tostring(#scanspos) .. "\nLock Scroll: " .. tostring(input_scansize_canscroll) .. "\nScan Size: " .. tostring(lidarscanner_convar_scansize:GetFloat()),"DebugFixed",30,30,Color(255,255,255),0)
				cam.End2D()
			end
			if GetConVarNumber("lidarscanner_savedots") == 1 then
				cam.Start2D()
				draw.SimpleText("Lidar Scanner Saved Dots: " .. tostring(array_count(savedots)) .. "/2147483647")
				cam.End2D()
			end
		end
	end)
	hook.Add("InputMouseApply","lidarscanner2_input_hook",function(cmd,x,y,ang)
		if GetConVarNumber("lidarscanner_enabled") ~= 1 then return end
		if GetConVarNumber("lidarscanner_mirror_enabled") == 1 then
			if GetConVarNumber("lidarscanner_mirror_input_enabled") == 1 then
                ang.pitch = math.Clamp(ang.pitch + (y * GetConVar("m_pitch"):GetFloat()),-89,89)
                ang.yaw = ang.yaw - (x * -GetConVar("m_yaw"):GetFloat())
                cmd:SetViewAngles(ang)
				cmd:SetSideMove(-cmd:GetSideMove())
				return true
			end
		end
	end)
end
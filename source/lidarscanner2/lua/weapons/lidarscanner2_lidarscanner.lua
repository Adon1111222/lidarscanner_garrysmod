-- LidarScanner 2
-- The actual LIDAR scanner weapon

AddCSLuaFile()

local LIDARSCANNER_SOUND_BURSTSCANNINGFMT = "lidarscanner2_sounds_valve/lidarscanner2_burstscanning%i.mp3"
local LIDARSCANNER_SOUND_FASTSCANNING = "lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav"
local LIDARSCANNER_SOUND_ONSTOPSCANNING = "lidarscanner2_sounds_valve/lidarscanner2_onstopscanning.wav"

-- strformat(string format,...)
local strformat = string.format

-- createcvar(string convarname,any defaultvalue,number flags,string description,number minvalue,number maxvalue)
local createcvar = CreateConVar

-- number getcvarnum(string convarname)
local getcvarnum = GetConVarNumber

local function getcvarbool(...)
    return getcvarnum(...) ~= 0
end

local LSCANNERWEP_NET_SCREEN_GLITCH = -3
local LSCANNERWEP_NET_FAST_SCAN = -2
-- RESERVED NET VALUE: -1
local LSCANNERWEP_NET_CLEARLAST = 0
-- RESERVED NET VALUE: 1
local LSCANNERWEP_NET_BURST_SCAN_START = 2

local LIDARSCANNER_NOSCAN = 0
local LIDARSCANNER_FASTSCAN = 1
local LIDARSCANNER_BURSTSCAN = 2

SWEP.ViewModel              	= "models/weapons/c_pistol.mdl"
SWEP.WorldModel             	= "models/weapons/w_pistol.mdl"
SWEP.UseHands 			= false
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo		= "none"
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo		= "none"
SWEP.Category   		= "Other"
SWEP.PrintName  		= "LIDAR Scanner"
SWEP.Instructions		= "Left Mouse Button(+attack) - fast scan." ..
				" Right Mouse Button(+attack2) - burst scan." ..
				" Reload(+reload) - delete the last scan."
SWEP.Slot			= 3
SWEP.SlotPos			= 1
SWEP.DrawAmmo			= false
SWEP.DrawCrosshair		= false
SWEP.Spawnable			= true

function SWEP:Initialize()
	self:SetHoldType("pistol")
end
if SERVER then
	util.AddNetworkString("lidarscanner2_network")
	function SWEP:StopScanSound()
		local owner = self:GetOwner()
		if IsValid(owner) then
			self:StopSound(LIDARSCANNER_SOUND_FASTSCANNING)
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
		if not getcvarbool("lidarscanner_sv_enabled") then return end
		local owner = self:GetOwner()
		if IsValid(owner) then
			net.Start("lidarscanner2_network")
			net.WriteInt(LSCANNERWEP_NET_CLEARLAST,3)
			net.Send(owner)
			self:SetNextSecondaryFire(CurTime()+0.25)
		end
	end
	function SWEP:PrimaryAttack()
		if not getcvarbool("lidarscanner_sv_enabled") then return end
		local owner = self:GetOwner()
		if IsValid(owner) and not self.burstscanning_time then
			-- Multiplayer bridge scan
			if getcvarbool("lidarscanner_sv_multiplayerbridge_enabled") then
				net.Start("lidarscanner2_network")
				net.WriteInt(LSCANNERWEP_NET_FAST_SCAN,3)
				net.WriteVector(owner:EyePos())
				net.WriteAngle(owner:EyeAngles())
				net.WriteEntity(owner)
				-- Sends this message to everyone except owner
				net.SendOmit(owner)
			end
			if not self.fastscanning then
				self:EmitSound(LIDARSCANNER_SOUND_FASTSCANNING)
				self.fastscanning = true
			end
		end
	end
	function SWEP:SecondaryAttack()
		if not getcvarbool("lidarscanner_sv_enabled") then return end
		local owner = self:GetOwner()
		if IsValid(owner) and not self.burstscanning_time then
			self:StopSound(LIDARSCANNER_SOUND_FASTSCANNING)
			net.Start("lidarscanner2_network")
			net.WriteInt(LSCANNERWEP_NET_BURST_SCAN_START,3)
			net.WriteVector(owner:EyePos())
			net.WriteAngle(owner:EyeAngles())
			net.WriteEntity(owner)
			net.Send(owner)
			self.burstscanning_time = CurTime()
			self.burstscanning_snd = CreateSound(self,strformat(LIDARSCANNER_SOUND_BURSTSCANNINGFMT,math.random(1,4)))
			self.burstscanning_snd:Play()
			self:SetNextSecondaryFire(CurTime()+1.25)
		end
	end
	function SWEP:Think()
		if not getcvarbool("lidarscanner_sv_enabled") then return end
		local owner = self:GetOwner()
		if IsValid(owner) then
			if not owner:KeyDown(IN_ATTACK) then
				if self.fastscanning then
					self:StopSound(LIDARSCANNER_SOUND_FASTSCANNING)
					self:EmitSound(LIDARSCANNER_SOUND_ONSTOPSCANNING)
					self.fastscanning = nil
				end
			end
			if self.burstscanning_time then
				if CurTime()-self.burstscanning_time > 0.25 then
					if not self.calledseeker then
						if LidarScanner_CallSeeker(owner:EyePos(),owner:EyeAngles():Forward(),owner) then
							net.Start("lidarscanner2_network")
							net.WriteInt(LSCANNERWEP_NET_SCREEN_GLITCH,3)
							net.Send(owner)
						end
						self.calledseeker = true
					end
				end
			end
		end
		if self.burstscanning_time then
			if CurTime()-self.burstscanning_time >= 1 then
				if CurTime()-self.burstscanning_time >= 1.25 then
					self.burstscanning_time = nil
					self.calledseeker = nil
				else
					if self.burstscanning_snd then
						self.burstscanning_snd:FadeOut(1)
					end
				end
			end
		end
	end
end
if CLIENT then
	local curscantype = LIDARSCANNER_NOSCAN
	local burstscanid = nil
	local scanner_lines = {}

	function SWEP:OnDrop()
		if burstscanid then
			LidarScanner_UpdateBurstScan(nil,nil,{},burstscanid)
			burstscanid = nil
		end
	end
	function SWEP:Holster(weapon)
		if burstscanid then
			LidarScanner_UpdateBurstScan(nil,nil,{},burstscanid)
			burstscanid = nil
		end
		return true
	end
	function SWEP:OnRemove()
		if burstscanid then
			LidarScanner_UpdateBurstScan(nil,nil,{},burstscanid)
			burstscanid = nil
		end
	end
	function SWEP:PreDrawViewModel() return true end
	function SWEP:PrimaryAttack()
	end
	function SWEP:SecondaryAttack()
	end
	function SWEP:Think()
		if not getcvarbool("lidarscanner_sv_enabled") then return end
		local owner = self:GetOwner()
		if IsValid(owner) and owner == LocalPlayer() then
			if burstscanid then
				LidarScanner_UpdateBurstScan(owner:EyePos(),owner:EyeAngles(),owner,burstscanid)
			else
				if owner:KeyDown(IN_ATTACK) then
					LidarScanner_DoFastScan(owner:EyePos(),owner:EyeAngles(),owner,function(lines)
						scanner_lines = lines
					end)
					curscantype = LIDARSCANNER_FASTSCAN
				end
			end
		end
		self:SetNextClientThink(CurTime()+0.1)
		return true
	end

	-- To hide view model envmaps(cubemaps), we can create a new material without envmap and change it on render.
	local viewmdl_mat = CreateMaterial("lidarscanner2_lua_materials/v_pistol_sheet_override",
		"VertexLitGeneric",Material("models/weapons/v_pistol/v_pistol_sheet"):GetKeyValues())
	viewmdl_mat:SetVector("$envmaptint",Vector(0,0,0))
	-- Switches entity envmaps on/off.
	local function SwitchModelsEnvmaps(mdl,envenable)
		if envenable then
			for k,v in pairs(mdl:GetMaterials()) do
				mdl:SetSubMaterial(k-1,nil)
			end
		else
			for k,v in pairs(mdl:GetMaterials()) do
				if v == "models/weapons/v_pistol/v_pistol_sheet" then
					mdl:SetSubMaterial(k-1,"!lidarscanner2_lua_materials/v_pistol_sheet_override")
					break
				end
			end
		end
	end

	local tex_screeneffect = render.GetScreenEffectTexture(0)
	local screeneffect_tex_name = tex_screeneffect:GetName()
	local mat_screeneffect = CreateMaterial("lidarscanner2_lua_materials/screeneffect_material","UnLitGeneric",
		{["$basetexture"]=screeneffect_tex_name,["$basetexturetransform"]="center .5 .5 scale -1 1 rotate 0 translate 0 0",["$ignorez"]=1})
	local mat_screeneffect_glitch_r = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_r_material","UnLitGeneric",
		{["$basetexture"]=screeneffect_tex_name,["$color2"] = "[1 0 0]",["$ignorez"] = 1,["$additive"] = 1})
	local mat_screeneffect_glitch_g = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_g_material","UnLitGeneric",
		{["$basetexture"]=screeneffect_tex_name,["$color2"] = "[0 1 0]",["$ignorez"] = 1,["$additive"] = 1})
	local mat_screeneffect_glitch_b = CreateMaterial("lidarscanner2_lua_materials/screeneffect_glitch_b_material","UnLitGeneric",
		{["$basetexture"]=screeneffect_tex_name,["$color2"] = "[0 0 1]",["$ignorez"] = 1,["$additive"] = 1})

	local mat_blurx = Material("pp/blurx")
	local mat_blury = Material("pp/blury")
	local view_mdl = ClientsideModel("models/weapons/v_pistol.mdl")
	view_mdl:SetNoDraw(true)
	function SWEP:DrawLidarScannerWeaponModel(ply)
		cam.Start3D(ply:EyePos(),ply:EyeAngles())
		cam.IgnoreZ(true)
		local scansc = 0
		if curscantype == LIDARSCANNER_FASTSCAN then
			scansc = 0.1
		elseif curscantype == LIDARSCANNER_BURSTSCAN then
			scansc = 0.125
		end
		view_mdl:SetPos(ply:EyePos()+Vector((math.sin(CurTime())/10)+math.Rand(-scansc,scansc),math.Rand(-scansc,scansc),math.Rand(-scansc,scansc))-((ply:EyeAngles():Forward()*(render.GetViewSetup(true).fov/10))*getcvarnum("lidarscanner_viewmodel_farscale")))
		view_mdl:SetAngles(ply:EyeAngles())
		local bonepos = view_mdl:GetAttachment(view_mdl:LookupAttachment("muzzle")).Pos
		if not bonepos then
			bonepos = ply:LocalToWorld(Vector(70,-16,-4))
		end
		local mirrorenabled = getcvarbool("lidarscanner_mirror_enabled") and getcvarbool("lidarscanner_enabled")
		if mirrorenabled then
			-- flip Y
			bonepos = ply:WorldToLocal(bonepos)
			bonepos.y = -bonepos.y
			bonepos = ply:LocalToWorld(bonepos)
		end

		local colour = Color(getcvarnum("lidarscanner_scanlines_colour_r"),
			getcvarnum("lidarscanner_scanlines_colour_g"),
			getcvarnum("lidarscanner_scanlines_colour_b"))
		for k,v in pairs(scanner_lines) do
			render.DrawLine(bonepos,v,colour,true)
		end
		if mirrorenabled then
			cam.Start2D()
			render.UpdateScreenEffectTexture(0)
			render.SetMaterial(mat_screeneffect)
			render.DrawScreenQuad()
			render.UpdateScreenEffectTexture(0)
			cam.End2D()
		end
		local scanner_lines_num = #scanner_lines
		scanner_lines = {}
		if getcvarbool("lidarscanner_background_enabled") and getcvarbool('lidarscanner_enabled') then
			render.SuppressEngineLighting(true)
			render.ResetModelLighting(0,0,0)
			-- it still does not work without suppress. so let is just not waste the resources
			if curscantype ~= LIDARSCANNER_NOSCAN then
				render.SetLocalModelLights({{type = 1,color = colour:ToVector()*(scanner_lines_num/1000),pos = bonepos+(view_mdl:GetUp()*2),range = 10,}})
			end
			SwitchModelsEnvmaps(view_mdl,false)
		end
		render.SetStencilEnable(true)
		render.ClearDepth()
		render.ClearStencil()
		render.SetStencilTestMask(255)
		render.SetStencilWriteMask(255)
		render.SetStencilPassOperation(STENCILOPERATION_KEEP)
		render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
		render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER)
		render.SetStencilReferenceValue(9)
		render.SetStencilFailOperation(STENCILOPERATION_REPLACE)
		view_mdl:DrawModel()
		render.SetStencilFailOperation(STENCILOPERATION_KEEP)
		render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
		render.OverrideAlphaWriteEnable(true,false)
		view_mdl:DrawModel()
		--render.ClearDepth()
		cam.IgnoreZ(false)
		cam.End3D()
		local vblurscale = getcvarnum("lidarscanner_viewmodel_blurscale")
		render.UpdateScreenEffectTexture(0)
		mat_blurx:SetTexture("$basetexture",tex_screeneffect)
		mat_blurx:SetFloat("$size",vblurscale)
		render.SetMaterial(mat_blurx)
		render.DrawScreenQuad()
		render.UpdateScreenEffectTexture(0)
		mat_blury:SetTexture("$basetexture",tex_screeneffect)
		mat_blury:SetFloat("$size",vblurscale)
		render.SetMaterial(mat_blury)
		render.DrawScreenQuad()
		render.SetStencilEnable(false)
		--view_mdl:Remove()
		render.SuppressEngineLighting(false)
		if curscantype == LIDARSCANNER_FASTSCAN then
			curscantype = LIDARSCANNER_NOSCAN
		end
		if getcvarbool("lidarscanner_background_enabled") and getcvarbool('lidarscanner_enabled') then
			SwitchModelsEnvmaps(view_mdl,true)
		end
	end
	net.Receive("lidarscanner2_network",function()
		if not getcvarbool("lidarscanner_enabled") then return end
		local ply = LocalPlayer()
		if IsValid(ply) then
			local int = net.ReadInt(3)
			if int then
				if int == LSCANNERWEP_NET_SCREEN_GLITCH then
					LidarScanner_SetGlitchFactor(3)
				elseif int == LSCANNERWEP_NET_FAST_SCAN then
					local pos = net.ReadVector()
					local ang = net.ReadAngle()
					local filter = net.ReadEntity()
					if filter == LocalPlayer() then
						-- Local player scan
						LidarScanner_DoFastScan(pos,ang,filter,function(lines)
							scanner_lines = lines
							curscantype = LIDARSCANNER_NOSCAN
						end)
						curscantype = LIDARSCANNER_FASTSCAN
					elseif IsValid(filter) and filter:IsPlayer() then
						-- Multiplayer bridge scan
						if getcvarbool("lidarscanner_multiplayerbridge_enabled") then
							local wep = ply:GetActiveWeapon()
							if IsValid(wep) then
								if wep:GetClass() == "lidarscanner2_lidarscanner" then
									LidarScanner_DoFastScan(pos,ang,filter,function()end)
								end
							end
						end
					else
						-- Other scans(projectors, e.t.c.)
						LidarScanner_DoFastScan(pos,ang,filter,function()end)
					end
				elseif int == LSCANNERWEP_NET_CLEARLAST then
					LidarScanner_ClearLastScan()
				elseif int == LSCANNERWEP_NET_BURST_SCAN_START then
					burstscanid = LidarScanner_DoBurstScan(net.ReadVector(),net.ReadAngle(),net.ReadEntity(),function(lines)
						if not lines then
							curscantype = LIDARSCANNER_NOSCAN
							burstscanid = nil
							return
						end
						scanner_lines = lines
					end)
					curscantype = LIDARSCANNER_BURSTSCAN
				end
			end
		end
	end)
end

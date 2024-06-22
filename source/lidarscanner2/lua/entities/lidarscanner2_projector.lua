AddCSLuaFile()
DEFINE_BASECLASS("base_anim")
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "Lidar Scanner" 
ENT.PrintName = "Projector"
ENT.Author = ""
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
	self:NetworkVar("Entity",0,"Scanning")
end
if SERVER then
    function ENT:Initialize()
        self:SetScanning(nil)
        self:SetModel("models/lamps/torch.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        if IsValid(self:GetPhysicsObject()) then
            self:GetPhysicsObject():Wake()
        end
        self:SetUseType(USE_TOGGLE)
    end
end
if CLIENT then
    function ENT:Think()
        local scanning = self:GetScanning()
        if IsValid(scanning) and scanning == LocalPlayer() then
            local dlight = DynamicLight(self:EntIndex())
            if dlight then
                dlight.pos = self:GetPos()
                dlight.r = GetConVarNumber("lidarscanner_scanlines_colour_r")
                dlight.g = GetConVarNumber("lidarscanner_scanlines_colour_g")
                dlight.b = GetConVarNumber("lidarscanner_scanlines_colour_b")
                dlight.brightness = 3
                dlight.Decay = 1000
                dlight.Size = 32
                dlight.DieTime = CurTime() + 1
            end
        end
    end
end
if SERVER then
    function ENT:Think()
        local scanning = self:GetScanning()
        if IsValid(scanning) then
            net.Start("lidarscanner2_network")
                net.WriteInt(-2,3)
                net.WriteVector(self:GetPos())
                net.WriteAngle(self:GetAngles())
                net.WriteEntity(self)
            net.Send(scanning)
            self:NextThink(CurTime()+FrameTime())
            return true
        end
    end
end
function ENT:Use(ply)
    if not IsValid(self:GetScanning()) then
        self:EmitSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
        self:SetScanning(ply)
        timer.Simple(1,function()
            if IsValid(self) then
                self:SetScanning(nil)
                self:StopSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
                self:EmitSound("lidarscanner2_sounds_valve/lidarscanner2_onstopscanning.wav")
            end
        end)
    end
end
function ENT:OnRemove()
    if SERVER then
        self:StopSound("lidarscanner2_sounds_valve/lidarscanner2_fastscanning1.wav")
        self:EmitSound("lidarscanner2_sounds_valve/lidarscanner2_onstopscanning.wav")
    end
end
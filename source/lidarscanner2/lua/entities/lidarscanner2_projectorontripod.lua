AddCSLuaFile()
DEFINE_BASECLASS("base_anim")
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "Lidar Scanner" 
ENT.PrintName = "Projector On Tripod"
ENT.Author = ""
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:Initialize()
    if CLIENT then return end
    self:SetModel("models/lidarscanner2_models_valve/tripod.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    if ( self:GetPhysicsObject():IsValid() ) then
        self:GetPhysicsObject():Wake()
    end
    if not IsValid(constraint.GetAllConstrainedEntities(self)[1]) then
        local ent = ents.Create("lidarscanner2_projector")
        ent:SetPos(self:LocalToWorld(Vector(0,0,56.404297)))
        ent:SetAngles(self:GetAngles())
        ent:Spawn()
        constraint.Axis(ent,self,0,0,Vector(0,0,50.031250),Vector(0,0,-5.414168),0,0,0,0)
    end
end
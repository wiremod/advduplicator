

ENT.Type 			= "anim"
//ENT.Base 			= "base_wire_entity"
ENT.Base 			= "base_gmodentity"

ENT.PrintName		= "Adv Duplicator Paster"
ENT.Author			= "TAD2020"
ENT.Contact			= "http://www.wiremod.com/"
ENT.Purpose			= ""
ENT.Instructions	= ""

ENT.Spawnable			= false
ENT.AdminSpawnable		= false

function ENT:SetSkewX(value)
	self.Entity:SetNetworkedFloat("SkewX", math.max(-1, math.min(value, 1)))
end

function ENT:SetSkewY(value)
	self.Entity:SetNetworkedFloat("SkewY", math.max(-1, math.min(value, 1)))
end

function ENT:SetSkewZ(value)
	self.Entity:SetNetworkedFloat("SkewZ", math.max(0, math.min(value, 1000)))
end

function ENT:SetBeamLength(length)
	self.Entity:SetNetworkedFloat("BeamLength", length)
end


function ENT:GetSkewX()
	return self.Entity:GetNetworkedFloat("SkewX") or 0
end

function ENT:GetSkewY()
	return self.Entity:GetNetworkedFloat("SkewY") or 0
end

function ENT:GetSkewZ()
	return self.Entity:GetNetworkedFloat("SkewZ") or 0
end

function ENT:GetBeamLength()
	return self.Entity:GetNetworkedFloat("BeamLength") or 0
end

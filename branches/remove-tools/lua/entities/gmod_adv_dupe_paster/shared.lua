

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
	self:SetNetworkedFloat("SkewX", math.max(-1, math.min(value, 1)))
end

function ENT:SetSkewY(value)
	self:SetNetworkedFloat("SkewY", math.max(-1, math.min(value, 1)))
end

function ENT:SetSkewZ(value)
	self:SetNetworkedFloat("SkewZ", math.max(0, math.min(value, 1000)))
end

function ENT:SetBeamLength(length)
	self:SetNetworkedFloat("BeamLength", length)
end


function ENT:GetSkewX()
	return self:GetNetworkedFloat("SkewX") or 0
end

function ENT:GetSkewY()
	return self:GetNetworkedFloat("SkewY") or 0
end

function ENT:GetSkewZ()
	return self:GetNetworkedFloat("SkewZ") or 0
end

function ENT:GetBeamLength()
	return self:GetNetworkedFloat("BeamLength") or 0
end

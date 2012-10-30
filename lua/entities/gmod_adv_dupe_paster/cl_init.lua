ENT.Spawnable			= false
ENT.AdminSpawnable		= false

include('shared.lua')
local LaserMat = Material("tripmine_laser")

function ENT:Initialize()
	mx, mn = self:GetRenderBounds()
	self:SetRenderBounds( mn + Vector(0,0,128), mx )
end


local function OnUndo()

	GAMEMODE:AddNotify( "Undone Pasted", NOTIFY_UNDO, 2 )
end

usermessage.Hook( "UndoWirePasterProp", OnUndo )


function ENT:Draw()
	self.BaseClass.Draw(self)

	local beam_length = self:GetBeamLength()
	if (beam_length > 0) then
		local skew = Vector(self:GetSkewX(), self:GetSkewY(), 1)
		skew = skew*(beam_length/skew:Length())
		local beam_x = self:GetRight()*skew.x
		local beam_y = self:GetForward()*skew.y
		local beam_z = self:GetUp()*skew.z

		local start = self:GetPos() + self:GetUp()*self:OBBMaxs().z
		local endpos = start + beam_x + beam_y + beam_z

		local bbmin, bbmax = self:GetRenderBounds()
		local lspos = self:WorldToLocal(start)
		local lepos = self:WorldToLocal(endpos)
		if (lspos.x < bbmin.x) then bbmin.x = lspos.x end
		if (lspos.y < bbmin.y) then bbmin.y = lspos.y end
		if (lspos.z < bbmin.z) then bbmin.z = lspos.z end
		if (lspos.x > bbmax.x) then bbmax.x = lspos.x end
		if (lspos.y > bbmax.y) then bbmax.y = lspos.y end
		if (lspos.z > bbmax.z) then bbmax.z = lspos.z end
		if (lepos.x < bbmin.x) then bbmin.x = lepos.x end
		if (lepos.y < bbmin.y) then bbmin.y = lepos.y end
		if (lepos.z < bbmin.z) then bbmin.z = lepos.z end
		if (lepos.x > bbmax.x) then bbmax.x = lepos.x end
		if (lepos.y > bbmax.y) then bbmax.y = lepos.y end
		if (lepos.z > bbmax.z) then bbmax.z = lepos.z end
		self:SetRenderBounds(bbmin, bbmax)

		local trace = {}
		trace.start = start
		trace.endpos = endpos
		trace.filter = { self }
		if (self:GetNetworkedInt("TraceWater") == 1) then trace.mask = MASK_ALL end

		local trace = util.TraceLine(trace)
		if (trace.Hit) then
			endpos = trace.HitPos
		end

		render.SetMaterial(LaserMat)
		render.DrawBeam(start, endpos, 6, 0, 10, self:GetColor())
	end
end

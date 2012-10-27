
TOOL.Category		= "Constraints"
TOOL.Name			= "#Tool.weld_ez2.name"
TOOL.Command		= nil
TOOL.ConfigName		= ""

if ( CLIENT ) then
    language.Add( "Tool.weld_ez2.name", "Weld - Easy w/ Snapping" )
    language.Add( "Tool.weld_ez2.desc", "Same as easy weld execpt with angle snapping" )
    language.Add( "Tool.weld_ez2.0", "Click on a wall, prop or a ragdoll" )
	language.Add( "Tool.weld_ez2.1", "Now click on something else to weld it to" )
	language.Add( "Tool.weld_ez2.2", "Now move your mouse to rotate the prop (shift/run to snap at 45s) and click to finish" )
end

TOOL.ClientConVar[ "forcelimit" ]	= "0"
TOOL.ClientConVar[ "nocollide" ]	= "0"

local ang1 = Angle()
local axis2 = Vector()
local degrees = 0

function TOOL:LeftClick( trace )

	// Make sure the object we're about to use is valid
	local iNum = self:NumObjects()
	local Phys = trace.Entity:GetPhysicsObjectNum( trace.PhysicsBone )

	// You can click anywhere on the 3rd pass
	if ( iNum < 2 ) then

		// If there's no physics object then we can't constraint it!
		if (  SERVER && !util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) ) then return false end

		// Don't weld players, or to players
		if ( trace.Entity:IsPlayer() ) then return false end

		// Don't do anything with stuff without any physics..
		if ( SERVER && !Phys:IsValid() ) then return false end

	end

	if (iNum == 0) then

		if ( !trace.Entity:IsValid() ) then return false end
		if ( trace.Entity:GetClass() == "prop_vehicle_jeep" ) then return false end

	end

	self:SetObject( iNum + 1, trace.Entity, trace.HitPos, Phys, trace.PhysicsBone, trace.HitNormal )

	if ( iNum > 1 ) then

		if ( CLIENT ) then
			self:ClearObjects()
			return true
		end

		// Get client's CVars
		local forcelimit = self:GetClientNumber( "forcelimit" )
		local nocollide  = ( self:GetClientNumber( "nocollide" ) == 1 )

		// Get information we're about to use
		local Ent1,  Ent2  = self:GetEnt(1),    self:GetEnt(2)
		local Bone1, Bone2 = self:GetBone(1),   self:GetBone(2)
		local Phys1 = self:GetPhys(1)

		// Something happened, the entity became invalid half way through
		// Finish it.
		if ( !Ent1:IsValid() ) then
			self:ClearObjects()
			return false
		end

		local constraint = constraint.Weld( Ent1, Ent2, Bone1, Bone2, forcelimit, nocollide )
		if (!constraint) then return false end

		Phys1:EnableMotion( true )

		undo.Create("Weld")
		undo.AddEntity( constraint )
		undo.SetPlayer( self:GetOwner() )
		undo.Finish()

		self:GetOwner():AddCleanup( "constraints", constraint )

		// Clear the objects so we're ready to go again
		self:ClearObjects()

	elseif ( iNum == 1 ) then

		if ( CLIENT ) then
			self:ReleaseGhostEntity()
			return true
		end

		// Get information we're about to use
		local Ent1,  Ent2  = self:GetEnt(1),      self:GetEnt(2)
		local Bone1, Bone2 = self:GetBone(1),     self:GetBone(2)
		local WPos1, WPos2 = self:GetPos(1),      self:GetPos(2)
		local LPos1, LPos2 = self:GetLocalPos(1), self:GetLocalPos(2)
		local Norm1, Norm2 = self:GetNormal(1),   self:GetNormal(2)
		local Phys1, Phys2 = self:GetPhys(1),     self:GetPhys(2)

		// Note: To keep stuff ragdoll friendly try to treat things as physics objects rather than entities
		local Ang1, Ang2 = Norm1:Angle(), (Norm2 * -1):Angle()
		local TargetAngle = Phys1:AlignAngles( Ang1, Ang2 )

		Phys1:SetAngles( TargetAngle )

		// Move the object so that the hitpos on our object is at the second hitpos
		local TargetPos = WPos2 + (Phys1:GetPos() - self:GetPos(1)) + (Norm2)

		// Set the position
		Phys1:SetPos( TargetPos )
		Phys1:EnableMotion( false )

		// Wake up the physics object so that the entity updates
		Phys1:Wake()

		ang1 = TargetAngle
		axis2 = Norm2
		--axis2:Rotate( Angle(90,0,90))

		self:ReleaseGhostEntity()

		self:SetStage( iNum+1 )

	else

		self:StartGhostEntity( trace.Entity )

		self:SetStage( iNum+1 )

	end

	return true

end

function TOOL:RightClick( trace )

	local iNum = self:NumObjects()

	if ( iNum > 1 ) then
		local Phys1 = self:GetPhys(1)
		Phys1:EnableMotion( true )
		self:ClearObjects()
	elseif ( iNum == 1 ) then
		self:ReleaseGhostEntity()
		self:ClearObjects()
	end

end

function TOOL:Think()

	if (self:NumObjects() < 1) then return end

	if ( SERVER ) then

		local Ent1 = self:GetEnt(1)

		if ( !Ent1:IsValid() ) then
			self:ClearObjects()
			return
		end

	end

	if (self:NumObjects() == 1) then

		self:UpdateGhostEntity()

	else

		if ( SERVER ) then

			local Phys1 = self:GetPhys(1)
			local LPos1, LPos2 = self:GetLocalPos(1), self:GetLocalPos(2)
			local WPos1, WPos2 = self:GetPos(1), self:GetPos(2)
			local Norm1, Norm2 = self:GetNormal(1), self:GetNormal(2)

			local cmd = self:GetOwner():GetCurrentCommand()

			degrees = degrees + cmd:GetMouseX() * 0.05

			local ra = degrees
			if (self:GetOwner():KeyDown(IN_SPEED)) then ra = math.Round(ra/45)*45 end

			local Ang = Angle(ang1.p,ang1.y,ang1.r)
			--Norm2
			Ang:RotateAroundAxis(axis2, ra)
			Phys1:SetAngles( Ang )

			// Move so spots join up
			local TargetPos = WPos2 + (Phys1:GetPos() - self:GetPos(1)) + (Norm2)
			Phys1:SetPos( TargetPos )
			Phys1:Wake()

		end

	end

end

function TOOL:Reload( trace )

	if (!trace.Entity:IsValid() || trace.Entity:IsPlayer() ) then return false end
	if ( CLIENT ) then return true end

	local  bool = constraint.RemoveConstraints( trace.Entity, "Weld" )
	return bool

end

if ( CLIENT ) then

function TOOL:FreezeMovement()

	local iNum = self:GetStage()

	if ( iNum > 1 ) then
		return true
	end

	return false

end

end

function TOOL:Holster()

	self:ClearObjects()

end


function TOOL.BuildCPanel(panel)
	panel:AddControl("ComboBox", {
		Label = "#Presets",
		MenuButton = "1",
		Folder = "weld_ez2",

		Options = {
			Default = {
				weld_ez2_forcelimit = "0",
			}
		},

		CVars = {
			[0] = "weld_ez2_forcelimit",
		}
	})

	panel:AddControl("CheckBox", {
		Label = "#NoCollide Until Break",
		Command = "weld_ez2_nocollide"
	})

	panel:AddControl("Slider", {
		Label = "#Force Limit",
		Description = "#Force Limit",
		Type = "Float",
		Min = "0",
		Max = "1000",
		Command = "weld_ez2_forcelimit"
	})
end

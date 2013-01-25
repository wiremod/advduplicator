

EFFECT.Mat = Material( "effects/tool_tracer" )

/*---------------------------------------------------------
   Init( data table )
---------------------------------------------------------*/
function EFFECT:Init( data )

	//self.WeaponEnt = data:GetEntity()
	//self.Attachment = data:GetAttachment()

	// Keep the start and end pos - we're going to interpolate between them
	//self.StartPos = self:GetTracerShootPos( self.Position, self.WeaponEnt, self.Attachment )
	self.StartPos = data:GetStart()
	self.EndPos = data:GetOrigin()

	// This determines a bounding box - if the box is on screen we get drawn
	// You pass the 2 corners of the bounding box
	// It doesn't matter what order you pass them in - I sort them for you in the engine
	// We want to draw from start to origin
	// These Vectors are in entity space
	self:SetRenderBoundsWS( self.StartPos, self.EndPos )

	self.Alpha = 255

end

/*---------------------------------------------------------
   THINK
---------------------------------------------------------*/
function EFFECT:Think( )




	self.Alpha = self.Alpha - 2000 * FrameTime()
	if (self.Alpha < 0) then return false end

	return true

end

/*---------------------------------------------------------
   Draw the effect
---------------------------------------------------------*/
function EFFECT:Render( )

	local texcoord = math.Rand( 0, 1 )

	//self.StartPos = self:GetTracerShootPos( self.Position, self.WeaponEnt, self.Attachment )
	self.Length = (self.StartPos - self.EndPos):Length()

	render.SetMaterial( self.Mat )

	//for i=0, 3 do
		render.DrawBeam( self.StartPos, 						// Start
					 self.EndPos,								// End
					 8,											// Width
					 texcoord,									// Start tex coord
					 texcoord + self.Length / 128,				// End tex coord
					 Color( 255, 255, 255, self.Alpha ) )		// Color (optional)
	//end

end

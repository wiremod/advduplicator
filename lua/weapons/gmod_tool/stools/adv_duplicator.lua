--[[------------------------------------------
	Advanced Duplicator by TAD2020
	Built on Garry Duplicator Technology
	but most of that's been writen by now
--]]------------------------------------------

TOOL.Category		= "Construction"
TOOL.Name			= "#tool.adv_duplicator.name"
TOOL.IsAdvDuplicator = true

if CLIENT then
	language.Add( "tool.adv_duplicator.name", "Advanced Duplicator" )
	language.Add( "tool.adv_duplicator.desc", "Duplicate an entity, or group of entities" )
	language.Add( "tool.adv_duplicator.0", "Left: Paste, Right: Copy, Reload: Place/Update Paster" )
end


TOOL.ClientConVar = {
	save_filename    = "",
	load_filename    = "",
	load_filename2   = "",
	load_filename_cl = "",
	file_desc        = "",
	delay            = 0,
	undo_delay       = 0,
	range            = 1500,
	show_beam        = 1,
	debugsave        = 0,
	LimitedGhost     = 0,
	pasterkey        = -1,
	pasterundo_key   = -1,
	height           = 0,
	angle            = 0,
	worldOrigin      = 0,
	worldAngles      = 0,
	pastefrozen      = 0,
	pastewoconst     = 0
}

cleanup.Register( "duplicates" )

TOOL.Info = {}
TOOL.Pasting = false

--
-- Paste a copy
--
function TOOL:LeftClick( trace )
	
	if CLIENT then	return true	end
	if self:GetPasting() or not self.Entities then return end
	
	local Snapping = self:GetOwner():KeyDown(IN_SPEED)
	
	local angle  = self:GetOwner():GetAngles()
	angle.pitch = 0
	angle.roll = 0
	
	if Snapping then
		angle.yaw = math.Round( angle.yaw / 45 ) * 45
	end
	angle.yaw = angle.yaw + self:GetClientNumber( "angle" )
	
	local Ents, Constraints = nil,nil
	
	if self.Legacy then
		
		--paste using legacy data
		--Msg("===doing old paste===\n")
		Ents, Constraints = AdvDupe.OldPaste( self:GetOwner(), self.Entities, self.Constraints, self.DupeInfo, self.DORInfo, self.HeadEntityIdx, trace.HitPos )
		
	else
		
		AdvDupe.SetPasting( self:GetOwner(), true )
		self:HideGhost(true)
		self:SetPercentText("Pasting")
		
		local PasteFrozen = ( self:GetClientNumber( "pastefrozen" ) == 1 )
		local PastewoConst = ( self:GetClientNumber( "pastewoconst" ) == 1 )
		
		local DupePos, DupeAngle
		if self:GetClientNumber( "worldOrigin" ) ~= 0 then
			-- Paste at original location
			DupePos, DupeAngle = self.StartPos, Angle(0,self:GetClientNumber( "angle" ),0)
		elseif self:GetClientNumber( "worldAngles" ) ~= 0 then
			-- Paste at original Angles
			DupePos, DupeAngle = trace.HitPos, Angle(0,self:GetClientNumber( "angle" ),0)
		else
			-- nothing checked
			local HoldAngle = self.HoldAngle
			--HoldAngle.yaw = self:GetClientNumber( "angle" )
			DupePos, DupeAngle = trace.HitPos, angle - HoldAngle
		end
		local height = self:GetClientNumber( "height" )
		if(height > 1024)then height = 1024 end
		AdvDupe.StartPaste(
			self:GetOwner(), self.Entities, self.Constraints, self.HeadEntityIdx,
			DupePos + Vector(0,0,self:GetClientNumber( "height" )), DupeAngle,
			self.NumOfEnts, self.NumOfConst, PasteFrozen, PastewoConst
		)
		
	end
	
	return true
	
end

--
-- Put the stuff in the 'clipboard'
--
function TOOL:RightClick( trace )
	
	if self:GetPasting() then return end
	--self:SetPercentText("Copying")
	
	local AddToSelection = self:GetOwner():KeyDown(IN_SPEED) and not self.Legacy and not self.FileLoaded and self.Copied
	
	if not AddToSelection and not IsValid(trace.Entity) or trace.Entity:IsPlayer() then
		self:ClearClipBoard()
		return true
	end

	-- Filter duplicator blocked entities out.
	if IsValid(trace.Entity) and trace.Entity.DoNotDuplicate then
		return false
	end
	
	if CLIENT then return true end
	
	--self:SetPercentText("Copying...")
	
	local StartPos
	if AddToSelection then
		StartPos = self.OrgStartPos
		self.Entities = self.Entities or {}
		self.Constraints = self.Constraints or {}
	else
		StartPos = trace.HitPos
		self:ReleaseGhostEntity()
		self.GhostEntitiesCount = 0
		
		self.Entities = {}
		self.Constraints = {}
		
		-- Get the distance from the floor
		local tr = {}
		tr.start = StartPos
		tr.endpos = StartPos + Vector(0,0,-1024)
		tr.mask = MASK_NPCSOLID_BRUSHONLY
		local tr_floor = util.TraceLine( tr )
		if tr_floor.Hit then 
			StartPos = StartPos  + Vector(0,0,-1) * tr_floor.Fraction * 1024
		end
	end
	
	AdvDupe.Copy( trace.Entity, self.Entities, self.Constraints, StartPos )
	
	if AddToSelection then
		if not self.GhostEntities[ self.HeadEntityIdx ] or not self.GhostEntities[ self.HeadEntityIdx ]:IsValid() then
			self:StartGhostEntities( self.Entities, self.HeadEntityIdx, self.HoldPos, self.HoldAngle )
		else
			self:SetPercentText("Ghosting")
			--self:AddToGhost()
			NextAddGhostTime = CurTime() + .2
			self.UnfinishedGhost = true
		end
	else
		local angle  = self:GetOwner():GetAngles()
		angle.pitch = 0
		angle.roll = 0
		
		self.HeadEntityIdx	= trace.Entity:EntIndex()
		self.HoldAngle 		= angle
		self.HoldPos 		= trace.Entity:WorldToLocal( StartPos )
		self.StartPos		= StartPos
		self.Legacy			= false
		self.OrgStartPos	= StartPos
		
		self:StartGhostEntities( self.Entities, self.HeadEntityIdx, self.HoldPos, self.HoldAngle )
		
	end
	
	local NumOfEnts		= table.Count(self.Entities)	or 0
	local NumOfConst	= table.Count(self.Constraints)	or 0
	self.NumOfEnts		= NumOfEnts
	self.NumOfConst		= NumOfConst
	
	self.FileLoaded		= false
	self.Copied			= true
	
	self.Info				= {}
	self.Info.Creator		= self:GetOwner():GetName()	or "unknown"
	self.Info.FilePath		= "unsaved data"
	self.Info.Desc			= ""
	self.Info.FileVersion	= ""
	self.Info.FileDate		= ""
	self.Info.FileTime		= ""
	
	self:UpdateLoadedFileInfo(true)
	
	--self:SetPercent(100)
	
	return true
	
end


--
--make a paster ent
function TOOL:Reload( trace )
	if self:GetPasting() then return end
	
	if not trace.HitPos then return false end
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end
	
	local ply = self:GetOwner()
	
	if self.Legacy then
		WireLib.AddNotify(ply, "Paster does not support old saves!", NOTIFY_GENERIC, 7)
		return false
	end
	if not self.Entities then
		WireLib.AddNotify(ply, "No copied data for Paster!", NOTIFY_GENERIC, 7)
		return false
	end
	
	local paster = trace.Entity -- assume we are aiming at a paster
	if trace.Entity:IsValid() and trace.Entity:GetClass() == "gmod_adv_dupe_paster" and trace.Entity:GetPlayer() == ply then -- if we are not, create a new paster
		--TODO: clear previous numpad bindings
	else
		paster = ents.Create( "gmod_adv_dupe_paster" )
	
		if not paster:IsValid() then return false end

		paster:SetPos( trace.HitPos )

		local Ang = trace.HitNormal:Angle()
		Ang.pitch = Ang.pitch + 90
		paster:SetAngles( Ang )

		paster:Spawn()
		paster:SetPlayer( ply )

		local min = paster:OBBMins()
		paster:SetPos( trace.HitPos - trace.HitNormal * min.z )

		local const = WireLib.Weld(paster, trace.Entity, trace.PhysicsBone, true)

		undo.Create("Paster")
			undo.AddEntity( paster )
			undo.SetPlayer( ply )
		undo.Finish()
	end
	
	local delay 		= self:GetClientNumber( "delay" )
	local undo_delay	= self:GetClientNumber( "undo_delay" )
	local range			= self:GetClientNumber( "range" )
	local show_beam		= self:GetClientNumber( "show_beam" ) == 1
	local key			= self:GetClientNumber( "pasterkey" )
	local undo_key 		= self:GetClientNumber( "pasterundo_key" )
	local PasteFrozen = ( self:GetClientNumber( "pastefrozen" ) == 1 )
	local PastewoConst = ( self:GetClientNumber( "pastewoconst" ) == 1 )
	
	paster:Setup(
		table.Copy(self.Entities),
		table.Copy(self.Constraints),
		self.HoldAngle, delay, undo_delay, range, show_beam, self.HeadEntityIdx,
		self.NumOfEnts, self.NumOfConst, PasteFrozen, PastewoConst
	)
	
	if key > -1 then numpad.OnDown( ply, key, "PasterCreate", paster, true ) end
	if undo_key > -1 then numpad.OnDown( ply, undo_key, "PasterUndo", paster, true ) end
	
	return true
end

--just because
function TOOL.BuildCPanel( CPanel )
	
	CPanel:AddControl( "Header", { Text = "#Tool.adv_duplicator.name", Description	= "#Tool.adv_duplicator.desc" }  )

end

local NextAddGhostTime = 0
function TOOL:Think()
	--not much to think about.
	
	if not self:GetPasting() and self.UnfinishedGhost and CurTime() >= NextAddGhostTime then
		self:AddToGhost()
		NextAddGhostTime = CurTime() + AdvDupe.GhostAddDelay(self:GetOwner())
	end
	
	self:UpdateGhostEntities()
	
end

-- the EntityModifiers that will be applied to the ghost
local GhostModifiers = { "material", "colour" }

--
--	Make the ghost entities
--
function TOOL:MakeGhostFromTable( EntTable, pParent, HoldAngle, HoldPos )
	if not EntTable then return end
	if not util.IsValidModel(EntTable.Model) then return end
	
	local GhostEntity = nil
	
	if EntTable.Model:sub( 1, 1 ) == "*" then
		GhostEntity = ents.Create( "func_physbox" )
	else
		GhostEntity = ents.Create( "gmod_ghost" )
	end
	
	-- If there are too many entities we might not spawn..
	if not IsValid(GhostEntity) then return end
	
	duplicator.DoGeneric( GhostEntity, EntTable )
	
	GhostEntity:SetPos( EntTable.LocalPos + HoldPos )
	GhostEntity:SetAngles( EntTable.LocalAngle )
	GhostEntity:Spawn()

	for _, modifier in ipairs(GhostModifiers) do
		if EntTable.EntityMods and EntTable.EntityMods[modifier] then
			duplicator.EntityModifiers[modifier](self:GetOwner(), GhostEntity, EntTable.EntityMods[modifier])
		end
	end

	GhostEntity:DrawShadow( false )
	GhostEntity:SetMoveType( MOVETYPE_NONE )
	GhostEntity:SetSolid( SOLID_VPHYSICS );
	GhostEntity:SetNotSolid( true )
	GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )

	local color = GhostEntity:GetColor()
	color.a = color.a * 150 / 255
	GhostEntity:SetColor( color )

	GhostEntity.Pos 	= EntTable.LocalPos
	GhostEntity.Angle 	= EntTable.LocalAngle - HoldAngle
	
	if pParent then
		GhostEntity:SetParent( pParent )
	end
	
	-- If we're a ragdoll send our bone positions
	if EntTable.Class == "prop_ragdoll" then
		for k, v in pairs( EntTable.PhysicsObjects ) do
			local lPos = v.LocalPos
			-- The physics object positions are stored relative to the head entity
			if ( pParent ) then
				lPos = pParent:LocalToWorld( v.LocalPos )
				lPos = GhostEntity:WorldToLocal( v.LocalPos )
			else
				lPos = lPos + HoldPos
			end
			GhostEntity:SetNetworkedBonePosition( k, lPos, v.LocalAngle )
		end	
	end
	
	return GhostEntity
	
end


--
--	Starts up the ghost entities
--
function TOOL:StartGhostEntities( EntityTable, Head, HoldPos, HoldAngle )
	if not EntityTable or not EntityTable[ Head ] then return end
	
	self:ReleaseGhostEntity()
	self.GhostEntities = {}
	self.GhostEntitiesCount = 0
	if self.Legacy then return end --no ghosting support for lagcey loads, table are too fucking different
	
	-- Make the head entity first
	self.GhostEntities[ Head ] = self:MakeGhostFromTable( EntityTable[ Head ], self.GhostEntities[ Head ], HoldAngle, HoldPos )
	
	if not IsValid(self.GhostEntities[ Head ]) then return self:SetPercent(-1) end
	
	-- Set NW vars for clientside
	self.Weapon:SetNetworkedEntity( "GhostEntity", self.GhostEntities[ Head ] )
	self.Weapon:SetNetworkedVector( "HeadPos", self.GhostEntities[ Head ].Pos )
	self.Weapon:SetNetworkedAngle( 	"HeadAngle", self.GhostEntities[ Head ].Angle )	
	self.Weapon:SetNetworkedVector( "HoldPos", HoldPos )
	self.Weapon:SetNetworkedAngle( "HoldAngle", EntityTable[ Head ].LocalAngle )
	
	if not IsValid(self.GhostEntities[ Head ]) then
		self:ReleaseGhostEntity()
		self.GhostEntities = nil
		self.UnfinishedGhost = false
		return
	end
	
	self:SetPercentText("Ghosting")
	
	self.GhostEntitiesCount = 1
	NextAddGhostTime = CurTime() + .2
	self.UnfinishedGhost = true
	
end

--
--	Update the ghost entity positions
--
function TOOL:UpdateGhostEntities()
	
	if SERVER and not self.GhostEntities then return end
	
	local tr = util.GetPlayerTrace( self:GetOwner(), self:GetOwner():GetAimVector() )
	local trace = util.TraceLine( tr )
	if not trace.Hit then return end
	
	local Snapping = self:GetOwner():KeyDown(IN_SPEED)
	
	local angle  = self:GetOwner():GetAngles()
	angle.pitch = 0
	angle.roll = 0
	
	if Snapping then
		angle.yaw = math.Round( angle.yaw / 45 ) * 45
	end
	angle.yaw = angle.yaw + self:GetClientNumber( "angle" )
	
	local GhostEnt = nil
	local HoldPos = nil
	
	if SERVER then
		GhostEnt = self.GhostEntities[ self.HeadEntityIdx ]
		HoldPos = self.HoldPos
		
		local height = self:GetClientNumber( "height" )
		if(height > 1024)then height = 1024 end
		self.Weapon:SetNetworkedFloat( "height", height )	
		
		self.Weapon:SetNetworkedBool( "worldOrigin", false )
		self.Weapon:SetNetworkedBool( "worldAngles", false )
		if self.StartPos and self:GetClientNumber( "worldOrigin" ) ~= 0 then
			-- Paste at Original Location
			self.Weapon:SetNetworkedBool( "worldOrigin", true )
			self.Weapon:SetNetworkedVector( "StartPos", self.StartPos )
			trace.HitPos = self.StartPos
		elseif self:GetClientNumber( "worldAngles" ) ~= 0 then
			-- Paste at Original Angle
			self.Weapon:SetNetworkedBool( "worldAngles", true )
		else
			-- nothing checked
		end
		trace.HitPos = trace.HitPos + Vector(0,0,height)
	else
		-- TODO: fix client part for "worldAngles"
		GhostEnt = self.Weapon:GetNetworkedEntity( "GhostEntity", nil )
		GhostEnt.Pos = self.Weapon:GetNetworkedVector( "HeadPos", Vector(0,0,0) )
		GhostEnt.Angle = self.Weapon:GetNetworkedAngle( "HeadAngle", Angle(0,0,0) )
		HoldPos = self.Weapon:GetNetworkedVector( "HoldPos", Vector(0,0,0) )
		
		if self.Weapon:GetNetworkedBool( "worldOrigin" ) then
			-- Paste at Original Location
			trace.HitPos = self.Weapon:GetNetworkedVector( "StartPos" )
		else
			-- Paste at Original Angles or nothing checked
		end
		local height = self.Weapon:GetNetworkedFloat( "height" )
		if(height > 1024)then height = 1024 end
		trace.HitPos = trace.HitPos + Vector(0,0,height)
		
	end
	
	if not IsValid(GhostEnt) then 
		self:ReleaseGhostEntity()
		self.GhostEntities = nil
		self.UnfinishedGhost = false
		return
	end
	
	GhostEnt:SetMoveType( MOVETYPE_VPHYSICS )
	GhostEnt:SetNotSolid( true )
	
	local TargetPos = GhostEnt:GetPos() - GhostEnt:LocalToWorld( HoldPos )
	
	local PhysObj = GhostEnt:GetPhysicsObject()
	if PhysObj and PhysObj:IsValid() then
		
		PhysObj:EnableMotion( false )
		PhysObj:SetPos( TargetPos + trace.HitPos )
		
		if self.Weapon:GetNetworkedBool( "worldOrigin" ) or self.Weapon:GetNetworkedBool( "worldAngles" )then
			-- Paste at Original Location or Paste at Original Angles
			PhysObj:SetAngles( self.Weapon:GetNetworkedAngle( "HoldAngle" ) + Angle(0, self:GetClientNumber( "angle" ), 0) )
		else
			-- nothing checked
			PhysObj:SetAngles( (GhostEnt.Angle or Angle(0,0,0)) + angle )
		end
		
		PhysObj:Wake()
		
	else
		
		-- Give the head ghost entity a physics object
		-- This way the movement will be predicted on the client
		if CLIENT then
			GhostEnt:PhysicsInit( SOLID_VPHYSICS )
		end
		
	end
	
end

--
--	Add more ghost ents
--
function TOOL:AddToGhost()
	local LimitedGhost = ( self:GetClientNumber( "LimitedGhost" ) == 1 ) or AdvDupe.LimitedGhost(self:GetOwner())
	limit = not LimitedGhost and AdvDupe.GhostLimitNorm(self:GetOwner()) or LimitedGhost and AdvDupe.GhostLimitLimited(self:GetOwner())
	
	if self.GhostEntitiesCount < limit then
		
		if not self.GhostEntities or not IsValid(self.GhostEntities[self.HeadEntityIdx]) then
			self:ReleaseGhostEntity()
			self.GhostEntities = nil
			self.UnfinishedGhost = false
			return
		end
		
		if AdvDupe[self:GetOwner()].PercentText ~= "Ghosting" then
			self:SetPercentText("Ghosting")
		end
		
		self.GhostEntities[self.HeadEntityIdx]:SetPos(		self.Entities[self.HeadEntityIdx].LocalPos + self.HoldPos )
		self.GhostEntities[self.HeadEntityIdx]:SetAngles(	self.Entities[self.HeadEntityIdx].LocalAngle )
		self.GhostEntities[self.HeadEntityIdx].Pos 		=	self.Entities[self.HeadEntityIdx].LocalPos
		self.GhostEntities[self.HeadEntityIdx].Angle 	=	self.Entities[self.HeadEntityIdx].LocalAngle - self.HoldAngle
		self.Weapon:SetNetworkedVector( "HeadPos",			self.GhostEntities[self.HeadEntityIdx].Pos )
		self.Weapon:SetNetworkedAngle( 	"HeadAngle",		self.GhostEntities[self.HeadEntityIdx].Angle )	
		self.Weapon:SetNetworkedVector( "HoldPos",			self.HoldPos )
		
		local ghostcount = 0
		for k, entTable in pairs( self.Entities ) do
			if not self.GhostEntities[ k ] then
				self.GhostEntities[ k ] = self:MakeGhostFromTable( entTable, self.GhostEntities[self.HeadEntityIdx], self.HoldAngle, self.HoldPos )
				
				ghostcount = ghostcount + 1
				self.GhostEntitiesCount = self.GhostEntitiesCount + 1
			end
			if ghostcount == AdvDupe.GhostsPerTick(self:GetOwner()) then
				self.UnfinishedGhost = true
				self:SetPercent( 100 * self.GhostEntitiesCount / math.min(limit, self.NumOfEnts) )
				return
			end
		end
		
	end
	
	self.UnfinishedGhost = false
	self:SetPercent(100)
	timer.Simple(.1, function() AdvDupe.SetPercent( self:GetOwner(), -1) end) --hide progress bar
end

--
--	Hides/Unhides ghost
--
local next_ghost_remove_timer_number = 1
function TOOL:HideGhost(Hide)
	if CLIENT then return end
	if not Hide and (!self.GhostEntities or !self.GhostEntities[ self.HeadEntityIdx ] || !self.GhostEntities[ self.HeadEntityIdx ]:IsValid() ) then
		self:StartGhostEntities( self.Entities, self.HeadEntityIdx, self.HoldPos, self.HoldAngle )
	elseif self.GhostEntities then
		for k,v in pairs( self.GhostEntities ) do
			if ( v:IsValid() ) then
				v:SetNoDraw(Hide)
			else
				self.GhostEntities[k] = nil
			end
		end
	end
	if Hide and self.GhostEntities then
		if not self.GhostCleanUpTimerName then
			local timer_name = "AdvDupeGhost"..next_ghost_remove_timer_number
			next_ghost_remove_timer_number = next_ghost_remove_timer_number + 1
			self.GhostCleanUpTimerName = timer_name
		end
		local ghosts = self.GhostEntities
		local ply = self:GetOwner()
		timer.Create(self.GhostCleanUpTimerName, 180, 1,
			function ()
				if ghosts then
					for k,v in pairs(ghosts) do
						if v:IsValid() then v:Remove() end
						ghosts[k] = nil
					end
					ghosts = nil
				end
				if ply and IsValid(ply) then
					timer.Simple(.1, function() AdvDupe.SetPercent( ply, -1 ) end) --hide progress bar
				end
			end
		)
	elseif not Hide and self.GhostCleanUpTimerName then
		timer.Stop(self.GhostCleanUpTimerName)
	end
end

if SERVER then
	util.AddNetworkString("AdvDupe.ResetDirectories")
	util.AddNetworkString(dupeshare.BaseDir)
else
	net.Receive("AdvDupe.ResetDirectories", function(netlen)
		AdvDupeClient.CLcdir = net.ReadString()
		AdvDupeClient.CLcdir2 = net.ReadString()
		AdvDupeClient.MyBaseDir = net.ReadString()
		AdvDupeClient.CurMenu = "main"
	end)
end

function TOOL:Deploy()
	if CLIENT then return end
	
	if not self:GetPasting() and self.Entities then self:HideGhost(false) end
	
	if !AdvDupe[self:GetOwner()] then AdvDupe[self:GetOwner()] = {} end
	AdvDupe[self:GetOwner()].cdir = AdvDupe.GetPlayersFolder(self:GetOwner())
	AdvDupe[self:GetOwner()].cdir2 = ""
	
	net.Start("AdvDupe.ResetDirectories")
		net.WriteString(dupeshare.BaseDir)
		net.WriteString(dupeshare.BaseDir)
		net.WriteString(AdvDupe[self:GetOwner()].cdir)
	net.Send(self:GetOwner())
	
	self:UpdateLoadedFileInfo()
	
	self:UpdateList()
end

function TOOL:Holster()
	if CLIENT then return end
	self:HideGhost(true)
end

if SERVER then
	util.AddNetworkString("AdvDupe.UpdateLoadedFileInfo")
else
	net.Receive("AdvDupe.UpdateLoadedFileInfo", function(netlen)
		AdvDupeClient.FileLoaded = net.ReadBit() ~= 0
		AdvDupeClient.Copied = net.ReadBit() ~= 0
		AdvDupeClient.LoadedFilename = net.ReadString()
		AdvDupeClient.LoadedCreator = net.ReadString()
		AdvDupeClient.LoadedDesc = net.ReadString()
		AdvDupeClient.LoadedNumOfEnts = net.ReadString()
		AdvDupeClient.LoadedNumOfConst = net.ReadString()
		AdvDupeClient.LoadedFileVersion = net.ReadString()
		AdvDupeClient.LoadedFileDate = net.ReadString()
		AdvDupeClient.LoadedFileTime = net.ReadString()
		AdvDupeClient.HasStartPos = net.ReadBit() ~= 0
		
		if net.ReadBit() ~= 0 then AdvDuplicator_UpdateControlPanel() end
	end)
end

function TOOL:UpdateLoadedFileInfo(RefreshCPanel)
	net.Start("AdvDupe.UpdateLoadedFileInfo")
		net.WriteBit(self.FileLoaded)
		net.WriteBit(self.Copied)
		net.WriteString(self.Info.FilePath or "")
		net.WriteString(self.Info.Creator or "n/a")
		net.WriteString(self.Info.Desc or "none")
		net.WriteString(self.NumOfEnts or "n/a")
		net.WriteString(self.NumOfConst or "n/a")
		net.WriteString(self.Info.FileVersion or "n/a")
		net.WriteString(self.Info.FileDate or "n/a")
		net.WriteString(self.Info.FileTime or "n/a")
		net.WriteBit(self.StartPos ~= nil)
		net.WriteBit(RefreshCPanel ~= nil)
	net.Send(self:GetOwner())
end

if SERVER then
	util.AddNetworkString("AdvDupe.ClearClipBoard")
else
	net.Receive("AdvDupe.ClearClipBoard", function(netlen)
		AdvDupeClient.FileLoaded=false
		AdvDupeClient.Copied=false
	end)
end

function TOOL:ClearClipBoard()

	if not self.Entities then return end -- Already cleared
	
	self:ReleaseGhostEntity()
	self.GhostEntities = {}
	self.GhostEntitiesCount = 0
	self.UnfinishedGhost = false
	self.HeadEntityIdx	= nil
	self.HoldAngle 		= nil
	self.HoldPos 		= nil
	self.StartPos		= nil
	self.Entities		= nil
	self.Constraints	= nil
	self.FileLoaded		= false
	self.Copied			= false
	
	self:GetOwner():ConCommand( "adv_duplicator_height 0")
	self:GetOwner():ConCommand( "adv_duplicator_angle 0")
	self:GetOwner():ConCommand( "adv_duplicator_worldOrigin 0")
	self:GetOwner():ConCommand( "adv_duplicator_pastefrozen 0")
	self:GetOwner():ConCommand( "adv_duplicator_pastewoconst 0")
	
	if SERVER then
		self:SetPercent(-1)
		net.Start("AdvDupe.ClearClipBoard") net.Send(self:GetOwner())
		self:UpdateList()
	end
end


function TOOL:SaveFile( filename, desc )
	if ( CLIENT ) then return end
	if (!filename) or (!self.Entities) then return end
	if (self.Legacy) or (!self.Copied) then return end
	
	local Filename, Creator, Desc, NumOfEnts, NumOfConst, FileVersion = AdvDupe.SaveDupeTablesToFile( 
		self:GetOwner(), self.Entities, self.Constraints,
		self.HeadEntityIdx, self.HoldAngle, self.HoldPos,
		filename, desc, self.StartPos, (self:GetClientNumber( "debugsave" ) == 1)
	)
	
	self.NumOfEnts		= NumOfEnts
	self.NumOfConst		= NumOfConst
	
	self.FileLoaded			= true
	self.Copied				= false
	
	self.Info				= {}
	self.Info.Creator		= Creator
	self.Info.FilePath		= Filename
	self.Info.Desc			= Desc
	self.Info.FileVersion	= FileVersion
	self.Info.FileDate		= FileDate
	self.Info.FileTime		= FileTime
	
	self:UpdateLoadedFileInfo()
	
	self:UpdateList()
	
	self:HideGhost(false)
	self:SetPercentText("Saving")
	
end

function TOOL:LoadFile( filepath )
	if ( CLIENT ) then return end
	
	self:ClearClipBoard()
	
	self:SetPercentText("Loading")
	
	AdvDupe.LoadDupeTableFromFile( self:GetOwner(), filepath )
	
end

function TOOL:LoadFileCallBack( filepath, Entities, Constraints, DupeInfo, DORInfo, HeadEntityIdx, HoldAngle, HoldPos, Legacy, Creator, Desc, NumOfEnts, NumOfConst, FileVersion, FileDate, FileTime, StartPos )
	if ( CLIENT ) then return end
	
	if Entities then
		
		self.HeadEntityIdx	= HeadEntityIdx
		self.HoldAngle 		= HoldAngle or Angle(0,0,0)
		self.HoldPos 		= HoldPos or Vector(0,0,0)
		self.StartPos 		= StartPos
		
		self.Entities		= Entities
		self.Constraints	= Constraints or {}
		self.DupeInfo		= DupeInfo
		self.DORInfo		= DORInfo
		
		self.NumOfEnts		= NumOfEnts
		self.NumOfConst		= NumOfConst
		
		self.Legacy			= Legacy
		
		self.FileLoaded		= true
		self.Copied			= false
		
		self.Info				= {}
		self.Info.Creator		= Creator
		self.Info.FilePath		= filepath
		self.Info.Desc			= Desc
		self.Info.FileVersion	= FileVersion
		self.Info.FileDate		= FileDate
		self.Info.FileTime		= FileTime
		
		--self:GetOwner():ConCommand( "adv_duplicator_angle "..self.HoldAngle.yaw)
		
		self:UpdateLoadedFileInfo(true)
		
		self:SetPercent(100)
		
		self:StartGhostEntities( self.Entities, self.HeadEntityIdx, self.HoldPos, self.HoldAngle )
	end
	
end

if SERVER then
	util.AddNetworkString("AdvDupe.UpdateList")
else
	net.Receive("AdvDupe.UpdateList", function(netlen)
		if not duplicator then AdvDupeClient={} end -- uhh why?
		AdvDupeClient.LoadListDirs  = {}
		AdvDupeClient.LoadListFiles = {}
		AdvDupeClient.SScdir = net.ReadString()
		local updir = net.ReadString()
		if updir ~= "" then 
			AdvDupeClient.LoadListDirs["/.."] = updir
		else
			-- They're in their root folder, show them public folders
			for _,dir in pairs(dupeshare.PublicDirs) do
				AdvDupeClient.LoadListDirs["/"..dir] = dupeshare.BaseDir.."/"..dir
			end
		end
		
		-- The list of files
		for k=1,net.ReadUInt(16) do
			local name = net.ReadString()
			AdvDupeClient.LoadListFiles[name] = name
		end
		
		-- The list of folders
		for k=1,net.ReadUInt(16) do
			local name = net.ReadString()
			AdvDupeClient.LoadListDirs["/"..name] = AdvDupeClient.SScdir.."/"..name
		end
		
		if net.ReadBit() ~= 0 then
			-- cdir2 stuff (basically just cdir1 again)
			AdvDupeClient.LoadListDirs2  = {}
			AdvDupeClient.LoadListFiles2 = {}
			AdvDupeClient.SScdir2 = net.ReadString()
			
			local updir = net.ReadString()
			if updir ~= "" then 
				AdvDupeClient.LoadListDirs2["/.."] = updir
			else
				-- They're in their root folder, show them public folders
				for _,dir in pairs(dupeshare.PublicDirs) do
					AdvDupeClient.LoadListDirs2["/"..dir] = dupeshare.BaseDir.."/"..dir
				end
			end
			
			-- The list of files
			for k=1,net.ReadUInt(16) do
				local name = net.ReadString()
				AdvDupeClient.LoadListFiles2[name] = AdvDupeClient.SScdir2.."/"..name
			end
			
			-- The list of folders
			for k=1,net.ReadUInt(16) do
				local name = net.ReadString()
				AdvDupeClient.LoadListDirs2["/"..name] = AdvDupeClient.SScdir2.."/"..name
			end
		end
		AdvDuplicator_UpdateControlPanel()
	end)
end

function TOOL:UpdateList()
	local ply = self:GetOwner()
	if not ply:IsValid() or not ply:IsPlayer() then return false end
	
	if not AdvDupe[ply] then AdvDupe[ply] = {} end
	if not AdvDupe[ply].cdir then AdvDupe[ply].cdir = AdvDupe.GetPlayersFolder(ply) end
	
	local cdir = AdvDupe[ply].cdir
	local cdir2 = AdvDupe[ply].cdir2
	
	net.Start("AdvDupe.UpdateList")
		net.WriteString(cdir)
		
		if dupeshare.NamedLikeAPublicDir(dupeshare.GetFileFromFilename(cdir)) then
			net.WriteString(AdvDupe.GetPlayersFolder(ply)) -- "/.." will go to the player's directory
		elseif cdir ~= AdvDupe.GetPlayersFolder(ply) then
			net.WriteString(dupeshare.UpDir(cdir)) -- "/.." will go up a dir
		else
			net.WriteString("") -- Its at root, no /.. will be present
		end
		
		local files, dirs = file.Find(dupeshare.ParsePath( cdir.."/*" ), "DATA")
		net.WriteUInt(#files, 16)
		for _, val in pairs(files) do net.WriteString(val) end
		net.WriteUInt(#dirs, 16)
		for _, val in pairs(dirs) do net.WriteString(val) end
	
		net.WriteBit(cdir2 ~= "")
		if cdir2 ~= "" then
			-- cdir2 stuff, basically a copypaste of the above
			net.WriteString(cdir2)
			
			if dupeshare.NamedLikeAPublicDir(dupeshare.GetFileFromFilename(cdir2)) then
				net.WriteString(AdvDupe.GetPlayersFolder(ply)) -- "/.." will go to the player's directory
			elseif cdir2 ~= AdvDupe.GetPlayersFolder(ply) then
				net.WriteString(dupeshare.UpDir(cdir2)) -- "/.." will go up a dir
			else
				net.WriteString("") -- Its at root, no /.. will be present
			end
			
			local files, dirs = file.Find(dupeshare.ParsePath( cdir2.."/*" ), "DATA")
			net.WriteUInt(#files, 16)
			for _, val in pairs(files) do net.WriteString(val) end
			net.WriteUInt(#dirs, 16)
			for _, val in pairs(dirs) do net.WriteString(val) end
		end
	net.Send(ply)
end


function TOOL:GetPasting()
	if ( SERVER ) and ( AdvDupe[self:GetOwner()] ) then return AdvDupe[self:GetOwner()].Pasting
	elseif ( CLIENT ) then return AdvDupeClient.Pasting end
end



if SERVER then
	
	--Serverside save of duplicated ents
	local function AdvDupeSS_Save( pl, _, args )
		if !pl:IsValid() or !pl:IsPlayer() then return end
		
		local tool = pl:GetActiveWeapon()
		if !dupeshare.CurrentToolIsDuplicator(tool) then return end
		if (!tool:GetTable():GetToolObject().Entities) then return end
		if (tool:GetTable():GetToolObject().Legacy) then
			AdvDupe.SendClientError(pl, "Cannot Save Loaded Legacy Data!")
		end
		
		local filename = ""
		if !args[1] --if a filename wasn't passed with a arg, then get the selection in the panel
		then filename = pl:GetInfo( "adv_duplicator_save_filename" )
		else filename = tostring(args[1]) end
		
		local desc = ""
		if !args[2] --if a filename wasn't passed with a arg, then get the selection in the panel
		then desc = pl:GetInfo( "adv_duplicator_file_desc" )
		else desc = tostring(args[2]) end
		
		--save to file
		tool:GetTable():GetToolObject():SaveFile( tostring(filename), tostring(desc) )
		
	end
	concommand.Add( "adv_duplicator_save", AdvDupeSS_Save )
	
	
	--Load duplicated file or open folder
	local function AdvDupeSS_Open( pl, command, args )
		
		if !pl:IsValid() 
		or !pl:IsPlayer() 
		then return end
		
		local tool = pl:GetActiveWeapon()
		if (!dupeshare.CurrentToolIsDuplicator(tool)) then return end
		
		local filepath = ""
		if !args[1] --if a filename wasn't passed with a arg, then get the selection in the panel
		--then filepath = tool:GetTable():GetToolObject().load_filename2
		then filepath = pl:GetInfo( "adv_duplicator_load_filename" )
		else filepath = tostring(args[1]) end
		
		filepath = (AdvDupe[pl].cdir.."/"..filepath):lower()
		
		if ( file.Exists(filepath, "DATA") && file.IsDir(filepath, "DATA") ) then
			--dupeshare.UsePWSys
			tool:GetTable():GetToolObject().cdir = filepath
			tool:GetTable():GetToolObject():UpdateList()
			
		elseif ( file.Exists(filepath, "DATA") && !file.IsDir(filepath, "DATA") ) then
			
			tool:GetTable():GetToolObject():LoadFile( filepath )
			
		else --list must be outdated, refresh it
			tool:GetTable():GetToolObject():UpdateList()
			return
		end
		
	end
	concommand.Add( "adv_duplicator_open", AdvDupeSS_Open )
	
	local function AdvDupeSS_OpenDir(pl, command, args)
		if not pl:IsValid() or not pl:IsPlayer() or not args[1] then return end
		
		local tool = pl:GetActiveWeapon()
		if not dupeshare.CurrentToolIsDuplicator(tool) then return end
		
		local dir = string.Implode(" ", args):lower()
		
		if dir == "" then
			dir = AdvDupe.GetPlayersFolder(pl)
		elseif not game.SinglePlayer() then
			local plydir = AdvDupe.GetPlayersFolder(pl)
			
			local baddir = (dir.."/"):sub(1, plydir:len()+1) ~= plydir.."/"
			if baddir then
				-- The directory isn't the player's, might it be a public folder?
				for _,pubdir in pairs(dupeshare.PublicDirs) do
					pubdir = (dupeshare.BaseDir.."/"..pubdir):lower()
					if dir:sub(1, pubdir:len()) == pubdir then
						-- The directory starts with adv_duplicator/apublicfolder/, we're okay
						baddir = false
						break
					end
				end
			end
			if baddir then
				print("AdvDupe: WARNING: "..tostring(pl).." tried to access a folder outside of Public or /"..plydir)
				return
			end
		end
		
		if file.Exists(dir, "DATA") and file.IsDir(dir, "DATA") then
			AdvDupe[pl].cdir = dir
			tool:GetTable():GetToolObject():UpdateList()
		end
		
	end
	concommand.Add( "adv_duplicator_open_dir", AdvDupeSS_OpenDir )
	
	
	local function AdvDupeSS_OpenDir2(pl, command, args)
		if !pl:IsValid() or !pl:IsPlayer() then return end
		
		local tool = pl:GetActiveWeapon()
		if (!dupeshare.CurrentToolIsDuplicator(tool)) then return end
		
		if (!args[1]) then
			AdvDupe[pl].cdir2 = AdvDupe[pl].cdir
		else
			local dir = string.Implode(" ", args):lower()
			if ( file.Exists(dir, "DATA") && file.IsDir(dir, "DATA") ) then
				--dupeshare.UsePWSys
				AdvDupe[pl].cdir2 = dir
			end
		end
		
		tool:GetTable():GetToolObject():UpdateList()
		
	end
	concommand.Add( "adv_duplicator_open_dir2", AdvDupeSS_OpenDir2 )
	
	-- Clientside save of duplicated ents
	--[[local function AdvDupeCL_Save( pl, command, args )
		
		if !pl:IsValid() 
		or !pl:IsPlayer() 
		--or !pl:GetTable().Duplicator 
		or !AdvDupe[pl] 
		then return end

		--save to file
		AdvDupe.SaveAndSendSaveToClient( pl, tostring(pl:GetInfo( "adv_duplicator_save_filename" )), tostring(pl:GetInfo( "adv_duplicator_file_desc" )) )
		
		AdvDupe.UpdateList(pl)
	end
	concommand.Add( "adv_duplicator_save_cl", AdvDupeCL_Save )]]
	
	--sends the selected file to the client
	local function AdvDupeSS_ClSend( pl, command, args )
		if not pl:IsValid() or not pl:IsPlayer() then return end
		
		--if a filename wasn't passed with a arg, then get the selection in the panel
		local filename = AdvDupe[pl].cdir.."/"..tostring(args[1] or pl:GetInfo( "adv_duplicator_load_filename" ))
		
		AdvDupe.SendSaveToClient( pl, filename )
	end
	concommand.Add( "adv_duplicator_send_cl", AdvDupeSS_ClSend )
	
	
	--allow the client to refresh the list
	local function AdvDupeSS_UpdateLoadList( pl, command, args )
		if args[1] then AdvDupe[pl].cdir2 = "" end
		
		AdvDupe.UpdateList(pl)
	end
	concommand.Add( "adv_duplicator_updatelist", AdvDupeSS_UpdateLoadList )
	
	
	function TOOL:SetPercentText( Txt )
		AdvDupe.SetPercentText( self:GetOwner(), Txt )
	end
	
	function TOOL:SetPercent( Percent )
		--[[umsg.Start("AdvDupe_Update_Percent", self:GetOwner())
			umsg.Short(Percent)
		umsg.End()]]
		AdvDupe.SetPercent(self:GetOwner(), Percent)
	end
	
end	
	
if CLIENT then
	
	local function build_serverdir_list(dirs, files, concommand_file, concommand_dir)
		local list = vgui.Create("DListView")
		list:SetMultiSelect(false)
		function list:OnRowSelected(LineID, line)
			if not line.is_dir then RunConsoleCommand(concommand_file, line.key) end
		end
		function list:DoDoubleClick(LineID, line)
			if line.is_dir then RunConsoleCommand(concommand_dir, line.key) end
		end
		if dirs then
			for k,v in pairs(dirs) do
				local line = list:AddLine(k)
				line.is_dir = true
				line.key = v
			end
		end
		if files then
			for k,v in pairs(files) do
				local line = list:AddLine(k)
				line.key = v
				if v == LocalPlayer():GetInfo(concommand_file) then line:SetSelected( true ) end
			end
		end
		list:SortByColumn(1)
		return list
	end
	
	local function build_clientdir_list(dir, concommand_file, concommand_dir)
		dir = dir:lower()
		local list = vgui.Create("DListView")
			list:SetMultiSelect(false)
			function list:OnRowSelected(LineID, line)
				if not line.is_dir then RunConsoleCommand(concommand_file, line.key) end
			end
			function list:DoDoubleClick(LineID, line)
				if line.is_dir then RunConsoleCommand(concommand_dir, line.key) end
			end
			if dir ~= dupeshare.BaseDir then
				local line = list:AddLine("/..")
				line.is_dir = true
				line.key = dupeshare.UpDir(dir)
			end
			if file.Exists(dir, "DATA") and file.IsDir(dir, "DATA") then
				local files, folders = file.Find( dir.."/*", "DATA" )
				for _, foldername in pairs(folders) do
					if file.Exists(dir.."/"..foldername, "DATA") then -- file.Find can return files with invalid names
						local line = list:AddLine("/"..foldername)
						line.key = dir.."/"..foldername
						line.is_dir = true
					end
				end
				for _, filename in pairs(files) do
					if file.Exists(dir.."/"..filename, "DATA") then -- file.Find can return files with invalid names
						local line = list:AddLine(filename)
						line.key = dir.."/"..filename
						if line.key == LocalPlayer():GetInfo(concommand_file) then line:SetSelected( true ) end
					end
				end
			end
		return list
	end
	
	function AdvDuplicator_UpdateControlPanel()
		local CPanel = controlpanel.Get( "adv_duplicator" )
		if not CPanel then return end
		
		--clear the panel so we can make it again!
		for i,v in pairs(CPanel.Items) do
			if v.Left then v.Left:GetParent():Remove() end-- v.Left:Remove() end
			CPanel.Items[i]:Remove()
			CPanel.Items[i] = nil
		end
		
		CPanel:InvalidateLayout()
		
		local menu = AdvDupeClient.CurMenu
		
		--build the folder lists, if we'll need them
		local ServerDir
		local ClientDir
		local ServerDir2
		local ClientDir2
		if menu == "main" or not menu or menu == "" or menu == "serverdir" or menu == "clientupload" then
			ServerDir = build_serverdir_list(AdvDupeClient.LoadListDirs, AdvDupeClient.LoadListFiles, "adv_duplicator_load_filename", "adv_duplicator_open_dir")
			if menu == "serverdir" then
				if not game.SinglePlayer() then
					ServerDir:AddColumn("Source: Server:"..string.gsub(AdvDupeClient.SScdir, AdvDupeClient.MyBaseDir, ""))
				else
					ServerDir:AddColumn("Local Source: "..string.gsub(AdvDupeClient.SScdir, dupeshare.BaseDir, ""))
				end
			else
				if not game.SinglePlayer() then
					ServerDir:AddColumn("Server: "..string.gsub(AdvDupeClient.SScdir, AdvDupeClient.MyBaseDir, ""))
				else
					ServerDir:AddColumn("Local: "..string.gsub(AdvDupeClient.SScdir, dupeshare.BaseDir, ""))
				end
			end
			
		end
		if menu == "clientupload" or menu == "clientdir" then
			ClientDir = build_clientdir_list(AdvDupeClient.CLcdir, "adv_duplicator_load_filename_cl", "adv_duplicator_open_cl")
			if menu == "clientdir" then
				ClientDir:AddColumn("Local Source: "..string.gsub(AdvDupeClient.CLcdir, dupeshare.BaseDir, ""))
			else
				ClientDir:AddColumn("Local: "..string.gsub(AdvDupeClient.CLcdir, dupeshare.BaseDir, ""))
			end
		end
		if menu == "serverdir" then
			ServerDir2 = build_serverdir_list(AdvDupeClient.LoadListDirs, AdvDupeClient.LoadListFiles, "adv_duplicator_load_filename2", "adv_duplicator_open_dir2")
			if not game.SinglePlayer() then
				ServerDir2:AddColumn("Destination: Server:"..string.gsub(AdvDupeClient.SScdir2, AdvDupeClient.MyBaseDir, ""))
			else
				ServerDir2:AddColumn("Local Destination: "..string.gsub(AdvDupeClient.SScdir2, dupeshare.BaseDir, ""))
			end
		elseif menu == "clientdir" then
			ClientDir2 = build_clientdir_list(AdvDupeClient.CLcdir2, "adv_duplicator_load_filename_cl2", "adv_duplicator_open_cl2")
			ClientDir2:AddColumn("Local Destination: "..string.gsub(AdvDupeClient.CLcdir2, dupeshare.BaseDir, ""))
		end
		
		
		--show the current menu
		if menu == "main" or not menu or menu == "" then
			CPanel:Help((game.SinglePlayer() and "Main" or "Server").." Menu (save and load)")
			local bottom = vgui.Create( "DForm")
			
			-- Hide the blue header
			bottom.Header:SetVisible(false)
			bottom.Paint = function(self,w,h) return false end
			
			bottom:Button("Open", "adv_duplicator_open")
			if game.SinglePlayer() then
				bottom:Button("Save", "adv_duplicator_save_gui")
				bottom:Button("Open Folder Manager Menu", "adv_duplicator_cl_menu", "serverdir")
			else
				bottom:Button("Save To Server", "adv_duplicator_save_gui")
				--bottom:Button("Save to Server Then Download", "adv_duplicator_save_cl")
				bottom:Button("Open Upload/Download Menu", "adv_duplicator_cl_menu", "clientupload")
				bottom:Button("Open Server Folder Manager Menu", "adv_duplicator_cl_menu", "serverdir")
			end
			bottom:Button("Open Paster Menu", "adv_duplicator_cl_menu", "paster")
			local txt
			if AdvDupeClient.FileLoaded then
				txt = "File Loaded: \""..string.gsub(AdvDupeClient.LoadedFilename, dupeshare.BaseDir, "").."\""
				txt = txt.."\nCreator: "..AdvDupeClient.LoadedCreator
				if AdvDupeClient.LoadedDesc != "none" then txt = txt.."\nDesc: "..AdvDupeClient.LoadedDesc end
				txt = txt.."\nDate: "..AdvDupeClient.LoadedFileDate
				txt = txt.."\nTime: "..AdvDupeClient.LoadedFileTime
				txt = txt.."\nNumber of Entities: "..AdvDupeClient.LoadedNumOfEnts
				txt = txt.."\nNumber of Constraints: "..AdvDupeClient.LoadedNumOfConst
				txt = txt.."\nFile Version: "..(AdvDupeClient.LoadedFileVersion or "n/a")
			elseif AdvDupeClient.Copied then
				txt = "Unsaved Data Stored in Clipboard"
				txt = txt.."\nNumber of Entities: "..AdvDupeClient.LoadedNumOfEnts
				txt = txt.."\nNumber of Constraints: "..AdvDupeClient.LoadedNumOfConst
			else
				txt = "No Data in Clipboard"
			end
			bottom:Help(txt)
			--bottom:CheckBox("Debug Save (larger file):", "adv_duplicator_debugsave")
			if AdvDupeClient.FileLoaded or AdvDupeClient.Copied then
				bottom:NumSlider("Height Offset:", "adv_duplicator_height", -1024, 1024, 0)
				bottom:NumSlider( "Angle Offset:", "adv_duplicator_angle", -180, 180, 0 )
				bottom:CheckBox("Paste Frozen:", "adv_duplicator_pastefrozen")
				bottom:CheckBox("Paste w/o Constraints (and frozen):", "adv_duplicator_pastewoconst")
			end
			bottom:CheckBox("Limited Ghost:", "adv_duplicator_LimitedGhost")
			if AdvDupeClient.HasStartPos then
				bottom:CheckBox("Paste at Original Location:", "adv_duplicator_worldOrigin")
			end
			bottom:CheckBox("Paste at Original Angles:", "adv_duplicator_worldAngles")
			
			CPanel:AddItem(ServerDir)
			
			-- Calculate height of the list of dupes
			local bottomtall = 32
			for k,v in pairs(bottom.Items) do bottomtall = bottomtall + v:GetTall() + 18 end
			local parent = CPanel:GetParent()
			if parent:GetParent() then parent = parent:GetParent() end
			
			-- Clamp *ScrH() - how much space the bottom section needs* between *5 lines* and *20 lines*
			ServerDir:SetTall(math.Clamp(parent:GetTall()-bottomtall,ServerDir:GetHeaderHeight() + 20 + ServerDir:GetDataHeight()*5, ServerDir:GetHeaderHeight() + 20 + ServerDir:GetDataHeight()*#ServerDir:GetLines()))
			
			CPanel:AddItem(bottom)
		elseif menu == "serverdir" then
			
			CPanel:Button( "--Back--", "adv_duplicator_cl_menu", "main")
			
			CPanel:Help((game.SinglePlayer() and "Local" or "Server").." Folder Management")
			
			local middle = vgui.Create( "ControlPanel")
			middle:Button("Make New Folder", "adv_duplicator_makedir_gui", "server")
			if not game.SinglePlayer() and dupeshare.UsePWSys then
				middle:Button("Add/Change Password for Current Folder", "adv_duplicator_changepass")
			end
			middle:Button("Rename", "adv_duplicator_renamefile_gui", "server")
			middle:Button("Copy", "adv_duplicator_fileopts", "copy")
			middle:Button("Move", "adv_duplicator_fileopts", "move")
			middle:Button("Delete", "adv_duplicator_confirmdelete_gui", "server") --"adv_duplicator_fileopts delete"
			middle:PerformLayout() --do this so bottom:GetTall() will return the correct value
			
			local listtall = (CPanel:GetParent():GetParent():GetTall()-120-middle:GetTall())/2
			
			--1st folder list
			CPanel:AddItem(ServerDir)
			ServerDir:SetTall(listtall)
			
			CPanel:AddItem(middle)
			
			--2nd folder list
			CPanel:AddItem(ServerDir2)
			ServerDir2:SetTall(listtall)
			
		elseif menu == "paster" then
			CPanel:Button("--Back--", "adv_duplicator_cl_menu", "main")
			CPanel:Help("Paster Settings (make with reload)")
			CPanel:NumSlider("Spawn Delay", "adv_duplicator_delay", 0, 100, 1)
			CPanel:NumSlider("Automatic Undo Delay", "adv_duplicator_undo_delay", 0, 100, 1)
			CPanel:NumSlider("Range", "adv_duplicator_range", 0, 1000, 0)
			CPanel:CheckBox("Show Beam", "adv_duplicator_show_beam")
			
			local params = { 
				Label		= "#Spawn Key",
				Label2		= "#Undo Key",
				Command		= "adv_duplicator_pasterkey",
				Command2	= "adv_duplicator_pasterundo_key",
				ButtonSize	= "22",
			}
			CPanel:AddControl( "Numpad",  params )
			
			
		elseif (menu == "clientupload") then
			CPanel:Button("--Back--", "adv_duplicator_cl_menu", "main")
			
			if not game.SinglePlayer() then
			
				CPanel:Help("Upload/Download Menu")
				
				CPanel:Help("Files on Server")
				
				local middle = vgui.Create( "ControlPanel")
				if AdvDupeClient.downloading then
					middle:Help("==Download in Progress==")
				elseif AdvDupeClient.CanDownload() then
					middle:Button("Download Selected File", "adv_duplicator_send_cl")
				else
					middle:Help("Server Disabled Downloads")
				end
				
				if AdvDupeClient.sending then
					middle:Help("==Upload in Progress==")
				elseif AdvDupeClient.CanUpload() then
					middle:Button("Upload File to server", "adv_duplicator_upload_cl")
				else
					middle:Help("Server Disabled Uploads")
				end
				middle:Help("Local Files")
				middle:PerformLayout() --do this so bottom:GetTall() will return the correct value
				
				local listtall = (CPanel:GetParent():GetParent():GetTall()-170-middle:GetTall())/2
			
				--1st folder list
				CPanel:AddItem(ServerDir)
				ServerDir:SetTall(listtall)
				
				CPanel:AddItem(middle)
				
				--2nd folder list
				CPanel:AddItem(ClientDir)
				ClientDir:SetTall(listtall)
				
				--I don't think this ever worked
				--CPanel:Button("Open Local Folder Manager Menu", "adv_duplicator_cl_menu", "clientdir")
			end
			
			
		elseif menu == "clientdir" then
			CPanel:Button("--Back--", "adv_duplicator_cl_menu", "clientupload")
			
			
			if not game.SinglePlayer() then
				CPanel:Help("Local Folder Management")
				
				local middle = vgui.Create( "ControlPanel")
				middle:Button("Make New Folder", "adv_duplicator_makedir_gui", "client")
				middle:Button("Rename", "adv_duplicator_renamefile_gui", "client")
				middle:Button("Copy", "adv_duplicator_cl_fileopts", "copy")
				middle:Button("Move", "adv_duplicator_cl_fileopts", "move")
				middle:Button("Delete", "adv_duplicator_confirmdelete_gui", "client") --"adv_duplicator_cl_fileopts delete"
				middle:Help("Local Files")
				middle:PerformLayout() --do this so bottom:GetTall() will return the correct value
				
				local listtall = (CPanel:GetParent():GetParent():GetTall()-120-middle:GetTall())/2
			
				--1st folder list
				CPanel:AddItem(ClientDir)
				ClientDir:SetTall(listtall)
				
				CPanel:AddItem(middle)
				
				--2nd folder list
				CPanel:AddItem(ClientDir2)
				ClientDir2:SetTall(listtall)
			end
		end
	end
	
	
	
	function AdvDupeCL_Menu(pl, command, args)
		if !pl:IsValid() or !pl:IsPlayer() or !args[1] then return end
		
		AdvDupeClient.CurMenu = args[1]
		
		if args[1] == "serverdir" then
			LocalPlayer():ConCommand("adv_duplicator_open_dir2")
		else
			LocalPlayer():ConCommand("adv_duplicator_updatelist 1")
		end
		
	end
	concommand.Add( "adv_duplicator_cl_menu", AdvDupeCL_Menu )
	
	
	local function AdvDupeCl_OpenDir(pl, command, args)
		if !pl:IsValid() or !pl:IsPlayer() then return end
		
		local dir = string.Implode(" ", args):lower()
		
		if ( file.Exists(dir, "DATA") && file.IsDir(dir, "DATA") ) then
			AdvDupeClient.CLcdir = dir
		end
		
		LocalPlayer():ConCommand("adv_duplicator_updatelist")
		
	end
	concommand.Add( "adv_duplicator_open_cl", AdvDupeCl_OpenDir )
	
	local function AdvDupeCl_OpenDir2(pl, command, args)
		if !pl:IsValid() or !pl:IsPlayer() then return end
		
		local dir = string.Implode(" ", args):lower()
		
		if ( file.Exists(dir, "DATA") && file.IsDir(dir, "DATA") ) then
			AdvDupeClient.CLcdir2 = dir
		end
		
		LocalPlayer():ConCommand("adv_duplicator_updatelist")
		
	end
	concommand.Add( "adv_duplicator_open_cl2", AdvDupeCl_OpenDir2 )
	
	
	local function AdvDupeCL_UpLoad( pl, command, args )
		if !pl:IsValid() or !pl:IsPlayer() then return end
		
		local filename = ""
		if !args[1] --if a filename wasn't passed with an arg, then get the selection in the panel
		then filename = pl:GetInfo( "adv_duplicator_load_filename_cl" )
		else filename = tostring(args[1]) end
		
		AdvDupeClient.UpLoadFile( pl, filename:lower() )
		
		AdvDuplicator_UpdateControlPanel()
	end
	concommand.Add( "adv_duplicator_upload_cl", AdvDupeCL_UpLoad )
	
end

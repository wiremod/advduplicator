--[[------------------------------------------
	Advanced Duplicator by TAD2020
	Built on Garry Duplicator Technology
	but most of that's been writen by now
--]]------------------------------------------

TOOL.Category		= "Construction"
TOOL.Name			= "#AdvancedDuplicator"

if CLIENT then
	language.Add( "AdvancedDuplicator", "Advanced Duplicator" )
	language.Add( "Tool_adv_duplicator_name", "Advanced Duplicator" )
	language.Add( "Tool_adv_duplicator_desc", "Duplicate an entity, or group of entities" )
	language.Add( "Tool_adv_duplicator_0", "Left: Paste, Right: Copy, Reload: Place/Update Paster" )
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
		Msg("===doing old paste===\n")
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
			DupePos, DupeAngle = self.StartPos, Angle(0,0,0)
		elseif self:GetClientNumber( "worldAngles" ) ~= 0 then
			-- Paste at original Angles
			DupePos, DupeAngle = trace.HitPos, Angle(0,0,0)
		else
			-- nothing checked
			local HoldAngle = self.HoldAngle
			--HoldAngle.yaw = self:GetClientNumber( "angle" )
			DupePos, DupeAngle = trace.HitPos, angle - HoldAngle
		end

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

	if not AddToSelection and not trace.Entity or not trace.Entity:IsValid() or trace.Entity:IsPlayer() then
		self:ClearClipBoard()
		return true
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

	self:UpdateLoadedFileInfo()

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

	CPanel:AddControl( "Header", { Text = "#Tool_adv_duplicator_name", Description	= "#Tool_adv_duplicator_desc" }  )

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
	if not GhostEntity or GhostEntity == NULL then return end

	duplicator.DoGeneric( GhostEntity, EntTable )

	GhostEntity:SetPos( EntTable.LocalPos + HoldPos )
	GhostEntity:SetAngles( EntTable.LocalAngle )
	GhostEntity:Spawn()

	GhostEntity:DrawShadow( false )
	GhostEntity:SetMoveType( MOVETYPE_NONE )
	GhostEntity:SetSolid( SOLID_VPHYSICS );
	GhostEntity:SetNotSolid( true )
	GhostEntity:SetRenderMode( RENDERMODE_TRANSALPHA )
	GhostEntity:SetColor( 255, 255, 255, 150 )

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

	if not (self.GhostEntities[ Head ] and self.GhostEntities[ Head ]:IsValid()) then return self:SetPercent(-1) end

	-- Set NW vars for clientside
	self.Weapon:SetNetworkedEntity( "GhostEntity", self.GhostEntities[ Head ] )
	self.Weapon:SetNetworkedVector( "HeadPos", self.GhostEntities[ Head ].Pos )
	self.Weapon:SetNetworkedAngle( 	"HeadAngle", self.GhostEntities[ Head ].Angle )
	self.Weapon:SetNetworkedVector( "HoldPos", HoldPos )
	self.Weapon:SetNetworkedAngle( "HoldAngle", EntityTable[ Head ].LocalAngle )

	if not self.GhostEntities[ Head ] or not self.GhostEntities[ Head ]:IsValid() then
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

	local tr = utilx.GetPlayerTrace( self:GetOwner(), self:GetOwner():GetCursorAimVector() )
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
			trace.HitPos = self.Weapon:GetNetworkedVector( "StartPos" ) + Vector(0,0,self.Weapon:GetNetworkedFloat( "height" ))
		else
			-- Paste at Original Angles or nothing checked
		end
		trace.HitPos = trace.HitPos + Vector(0,0,self.Weapon:GetNetworkedFloat( "height" ))

	end

	if not GhostEnt or not GhostEnt:IsValid() then
		self.GhostEntities = nil
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
			PhysObj:SetAngle( self.Weapon:GetNetworkedAngle( "HoldAngle" ) )
		else
			-- nothing checked
			PhysObj:SetAngle( (GhostEnt.Angle or Angle(0,0,0)) + angle )
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

		if not self.GhostEntities[self.HeadEntityIdx] or not self.GhostEntities[self.HeadEntityIdx]:IsValid() then
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
	timer.Simple(.1, AdvDupe.SetPercent, self:GetOwner(), -1) --hide progress bar
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
				if ply and ply:IsValid() then
					timer.Simple(.1, AdvDupe.SetPercent, ply, -1) --hide progress bar
				end
			end
		)
	elseif not Hide and self.GhostCleanUpTimerName then
		timer.Stop(self.GhostCleanUpTimerName)
	end
end



function TOOL:Deploy()
	if CLIENT then return end

	if not self:GetPasting() and self.Entities then self:HideGhost(false) end

	if !AdvDupe[self:GetOwner()] then AdvDupe[self:GetOwner()] = {} end
	AdvDupe[self:GetOwner()].cdir = AdvDupe.GetPlayersFolder(self:GetOwner())
	AdvDupe[self:GetOwner()].cdir2 = ""

	--	TODO: Replace these with umsging
	self:GetOwner():SendLua( "AdvDupeClient.CLcdir=\""..dupeshare.BaseDir.."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.CLcdir2=\""..dupeshare.BaseDir.."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.MyBaseDir=\""..AdvDupe[self:GetOwner()].cdir.."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.CurMenu=\"main\"" )

	self:UpdateLoadedFileInfo()

	self:UpdateList()
end

function TOOL:Holster()
	if CLIENT then return end
	self:HideGhost(true)
end


function TOOL:UpdateLoadedFileInfo()
	self:GetOwner():SendLua( "AdvDupeClient.FileLoaded="..tostring(self.FileLoaded) )
	self:GetOwner():SendLua( "AdvDupeClient.Copied="..tostring(self.Copied) )
	self:GetOwner():SendLua( "AdvDupeClient.LoadedFilename=\""..(self.Info.Filepath or "").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedCreator=\""..(self.Info.Creator or "n/a").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedDesc=\""..(self.Info.Desc or "n/a").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedNumOfEnts=\""..(self.NumOfEnts or "n/a").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedNumOfConst=\""..(self.NumOfConst or "n/a").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedFileVersion=\""..(self.Info.FileVersion or "n/a").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedFileFileDate=\""..(self.Info.FileDate or "n/a").."\"" )
	self:GetOwner():SendLua( "AdvDupeClient.LocadedFileFileTime=\""..(self.Info.FileTime or "n/a").."\"" )
	if ( self.StartPos ) then
		self:GetOwner():SendLua( "AdvDupeClient.HasStartPos=true" )
	else
		self:GetOwner():SendLua( "AdvDupeClient.HasStartPos=false" )
	end
end


function TOOL:ClearClipBoard()

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
	if (SERVER) then
		self:SetPercent(-1)
		self:GetOwner():SendLua( "AdvDupeClient.FileLoaded=false" )
		self:GetOwner():SendLua( "AdvDupeClient.Copied=false" )
	end

	self:GetOwner():ConCommand( "adv_duplicator_height 0")
	self:GetOwner():ConCommand( "adv_duplicator_angle 0")
	self:GetOwner():ConCommand( "adv_duplicator_worldOrigin 0")
	self:GetOwner():ConCommand( "adv_duplicator_pastefrozen 0")
	self:GetOwner():ConCommand( "adv_duplicator_pastewoconst 0")

	if SERVER then
		AdvDupe.UpdateList(self:GetOwner())
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
	self.Info.FilePath		= filepath
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

		self:UpdateLoadedFileInfo()

		self:UpdateList()

		self:SetPercent(100)

		self:StartGhostEntities( self.Entities, self.HeadEntityIdx, self.HoldPos, self.HoldAngle )
	end

end


function TOOL:UpdateList()
	if (!self:GetOwner():IsValid()) then return false end
	if (!self:GetOwner():IsPlayer()) then return false end

	self:GetOwner():SendLua( "if ( !duplicator ) then AdvDupeClient={} end" )

	if !AdvDupe[self:GetOwner()] then AdvDupe[self:GetOwner()] = {} end
	if !AdvDupe[self:GetOwner()].cdir then
		AdvDupe[self:GetOwner()].cdir = AdvDupe.GetPlayersFolder(self:GetOwner())
	end


	local cdir = AdvDupe[self:GetOwner()].cdir

	Msg("cdir= "..cdir.."\n")
 	self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs={}" )
	self:GetOwner():SendLua( "AdvDupeClient.LoadListFiles={}" )
	self:GetOwner():SendLua( "AdvDupeClient.SScdir=\""..cdir.."\"" )

	if ( cdir == dupeshare.BaseDir.."/=Public Folder=" ) or ( dupeshare.NamedLikeAPublicDir(dupeshare.GetFileFromFilename(cdir)) ) or ( cdir == "Contraption Saver Tool" ) then
		self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs[\"/..\"] = \""..AdvDupe.GetPlayersFolder(self:GetOwner()).."\"" )
	elseif ( cdir ~= AdvDupe.GetPlayersFolder(self:GetOwner()) ) then
		self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs[\"/..\"] = \""..dupeshare.UpDir(cdir).."\"" )
	elseif (GetConVarNumber("sv_AdvDupeEnablePublicFolder") == 1) then --is at root
		self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs[\"/=Public Folder=\"] = \""..dupeshare.BaseDir.."/=Public Folder=\"" )

		if ( file.Exists("Contraption Saver Tool") && file.IsDir("Contraption Saver Tool") ) then
			self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs[\"/=Contraption Saver Dir=\"] = \"Contraption Saver Tool\"" )
		end
	end

	if ( file.Exists(cdir) && file.IsDir(cdir) ) then
		for key, val in pairs( file.Find(dupeshare.ParsePath( cdir.."/*" )) ) do
			if ( !file.IsDir(dupeshare.ParsePath( cdir.."/"..val )) ) then
				--self:GetOwner():SendLua( "AdvDupeClient.LoadListFiles[\""..val.."\"] = \""..cdir.."/"..val.."\"" )
				self:GetOwner():SendLua( "AdvDupeClient.LoadListFiles[\""..val.."\"] = \""..val.."\"" )
			elseif  ( file.IsDir(dupeshare.ParsePath( cdir.."/"..val )) ) then
				self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs[\"/"..val.."\"] = \""..cdir.."/"..val.. "\"" )
			end
		end
	end


	if (AdvDupe[self:GetOwner()].cdir2 ~= "") then

		local cdir2 = AdvDupe[self:GetOwner()].cdir2
		--Msg("cdir2= "..cdir2.."\n")
		self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs2={}" )
		self:GetOwner():SendLua( "AdvDupeClient.LoadListFiles2={}" )
		self:GetOwner():SendLua( "AdvDupeClient.SScdir2=\""..cdir2.."\"" )

		if ( cdir2 == dupeshare.BaseDir.."/=Public Folder=" ) or ( dupeshare.NamedLikeAPublicDir(dupeshare.GetFileFromFilename(cdir2)) ) or ( cdir2 == "Contraption Saver Tool" ) then
			self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs2[\"/..\"] = \""..AdvDupe.GetPlayersFolder(self:GetOwner()).."\"" )
		elseif ( cdir2 ~= AdvDupe.GetPlayersFolder(self:GetOwner()) ) then
			self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs2[\"/..\"] = \""..dupeshare.UpDir(cdir2).."\"" )
		elseif (GetConVarNumber("sv_AdvDupeEnablePublicFolder") == 1) then --is at root
			self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs2[\"/=Public Folder=\"] = \""..dupeshare.BaseDir.."/=Public Folder=\"" )

			if ( file.Exists("Contraption Saver Tool") && file.IsDir("Contraption Saver Tool") ) then
				self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs2[\"/=Contraption Saver Dir=\"] = \"Contraption Saver Tool\"" )
			end
		end

		if ( file.Exists(cdir2) && file.IsDir(cdir2)) then
			for key, val in pairs( file.Find(dupeshare.ParsePath( cdir2.."/*" ) )) do
				if ( !file.IsDir(dupeshare.ParsePath( cdir2.."/"..val )) ) then
					self:GetOwner():SendLua( "AdvDupeClient.LoadListFiles2[\""..val.."\"] = \""..cdir2.."/"..val.."\"" )
				elseif  ( file.IsDir(dupeshare.ParsePath( cdir2.."/"..val )) ) then
					self:GetOwner():SendLua( "AdvDupeClient.LoadListDirs2[\"/"..val.."\"] = \""..cdir2.."/"..val.. "\"" )
				end
			end
		end

	end


	-- Force user to update list
	self:GetOwner():SendLua( "AdvDuplicator_UpdateControlPanel()" )

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

		filepath = AdvDupe[pl].cdir.."/"..filepath

		if ( file.Exists(filepath) && file.IsDir(filepath) ) then
			--dupeshare.UsePWSys
			tool:GetTable():GetToolObject().cdir = filepath
			tool:GetTable():GetToolObject():UpdateList()

		elseif ( file.Exists(filepath) && !file.IsDir(filepath) ) then

			tool:GetTable():GetToolObject():LoadFile( filepath )

			--pl:SendLua(  "LocalPlayer():GetActiveWeapon():GetTable():GetToolObject():StartGhostEntities()")
			--tool:GetTable():GetToolObject():StartGhostEntities()
			--tool:GetTable():GetToolObject():SendGhostToClient(true)
			--pl:SendLua(  "LocalPlayer():GetActiveWeapon():GetTable():GetToolObject():UpdateGhostEntities()" )

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

		local dir = string.Implode(" ", args)

		if dir == "" then
			dir = AdvDupe.GetPlayersFolder(pl)
		elseif not SinglePlayer() then
			local plydir = dupeshare.ReplaceBadChar(tostring(pl:SteamID()))
			plydir = string.gsub(plydir, "STEAM_1", "STEAM_0") -- I think this was needed cause Valve randomly changed everybody's IDs - Jimlad
			plydir = dupeshare.BaseDir.."/"..plydir

			local pubdir = dupeshare.BaseDir.."/=Public Folder="

			if
				dir:sub(1, pubdir:len()) ~= pubdir and
				(dir.."/"):sub(1, plydir:len()+1) ~= plydir.."/" then
			--if not string.find(dir, "^"..dupeshare.BaseDir.."/=Public Folder=") and not string.find(dir.."/", "^"..plydir.."/") then -- extra "/" is required for cases where the first part of two players' SteamIDs happen to match
				print("AdvDupe: WARNING: "..tostring(pl).." tried to access a folder outside of Public or /"..plydir)
				return
			end
		end

		if file.Exists(dir) and file.IsDir(dir) then
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
			local dir = string.Implode(" ", args)
			if ( file.Exists(dir) && file.IsDir(dir) ) then
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

		if !pl:IsValid()
		or !pl:IsPlayer()
		then return end

		local filename = ""
		if !args[1] --if a filename wasn't passed with a arg, then get the selection in the panel
		then filename = pl:GetInfo( "adv_duplicator_load_filename" )
		else filename = tostring(args[1]) end

		filename = AdvDupe[pl].cdir.."/"..filename

		AdvDupe.SendSaveToClient( pl, filename )

		pl:SendLua( "AdvDuplicator_UpdateControlPanel()" )
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
		local list = vgui.Create("DListView")
			list:SetMultiSelect(false)
			function list:OnRowSelected(LineID, line)
				if not line.is_dir then RunConsoleCommand(concommand_file, line.key) end
			end
			function list:DoDoubleClick(LineID, line)
				if line.is_dir then RunConsoleCommand(concommand_dir, line.key) end
			end
			if dir ~= dupeshare.BaseDir then
				if dir == "Contraption Saver Tool" then
					local line = list:AddLine("/..")
					line.is_dir = true
					line.key = dupeshare.BaseDir
				else
					local line = list:AddLine("/..")
					line.is_dir = true
					line.key = dupeshare.UpDir(dir)
				end
			else
				if file.Exists("Contraption Saver Tool") && file.IsDir("Contraption Saver Tool") then
					local line = list:AddLine("=Contraption Saver Dir=")
					line.is_dir = true
					line.key = "Contraption Saver Tool"
				end
			end
			if file.Exists(dir) and file.IsDir(dir) then
				for key, val in pairs(file.Find( dir.."/*" )) do
					if not file.IsDir(dir.."/"..val) then
						local line = list:AddLine(val)
						line.key = dir.."/"..val
					if line.key == LocalPlayer():GetInfo(concommand_file) then line:SetSelected( true ) end
					elseif file.IsDir(dir.."/"..val) then
						local line = list:AddLine("/"..val)
						line.is_dir = true
						line.key = dir.."/"..val
					end
				end
			end
		return list
	end

	function AdvDuplicator_UpdateControlPanel()
		local CPanel = GetControlPanel( "adv_duplicator" )
		if not CPanel then return end

		--clear the panel so we can make it again!
		CPanel:ClearControls()

		local menu = AdvDupeClient.CurMenu

		--build the folder lists, if we'll need them
		local ServerDir
		local ClientDir
		local ServerDir2
		local ClientDir2
		if menu == "main" or not menu or menu == "" or menu == "serverdir" or menu == "clientupload" then
			ServerDir = build_serverdir_list(AdvDupeClient.LoadListDirs, AdvDupeClient.LoadListFiles, "adv_duplicator_load_filename", "adv_duplicator_open_dir")
			if menu == "serverdir" then
				if not SinglePlayer() then
					ServerDir:AddColumn("Source: Server:"..string.gsub(AdvDupeClient.SScdir, AdvDupeClient.MyBaseDir, ""))
				else
					ServerDir:AddColumn("Local Source: "..string.gsub(AdvDupeClient.SScdir, dupeshare.BaseDir, ""))
				end
			else
				if not SinglePlayer() then
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
			if not SinglePlayer() then
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
			if not SinglePlayer() then
				CPanel:AddItem(Label("Server Menu (save and load)"))
			else
				CPanel:AddItem(Label("Main Menu (save and load)"))
			end

			local bottom = vgui.Create( "ControlPanel")
			bottom:Button("Open", "adv_duplicator_open")
			if SinglePlayer() then
				bottom:Button("Save", "adv_duplicator_save_gui")
				bottom:Button("Open Folder Manager Menu", "adv_duplicator_cl_menu", "serverdir")
			else
				bottom:Button("Save To Server", "adv_duplicator_save_gui")
				--bottom:Button("Save to Server Then Download", "adv_duplicator_save_cl")
				bottom:Button("Open Upload/Download Menu", "adv_duplicator_cl_menu", "clientupload")
				bottom:Button("Open Server Folder Manager Menu", "adv_duplicator_cl_menu", "serverdir")
			end
			bottom:Button("Open Paster Menu", "adv_duplicator_cl_menu", "paster")
			if AdvDupeClient.FileLoaded then
				bottom:AddItem(Label("File Loaded: \""..string.gsub(AdvDupeClient.LoadedFilename, dupeshare.BaseDir, "").."\""))
				bottom:AddItem(Label("Creator: "..AdvDupeClient.LocadedCreator))
				bottom:AddItem(Label("Desc: "..AdvDupeClient.LocadedDesc))
				bottom:AddItem(Label("Date: "..AdvDupeClient.LocadedFileFileDate))
				bottom:AddItem(Label("Time: "..AdvDupeClient.LocadedFileFileTime))
				bottom:AddItem(Label("NumOfEnts: "..AdvDupeClient.LocadedNumOfEnts))
				bottom:AddItem(Label("NumOfConst: "..AdvDupeClient.LocadedNumOfConst))
				bottom:AddItem(Label("FileVersion: "..(AdvDupeClient.LocadedFileVersion or "n/a")))
			elseif AdvDupeClient.Copied then
				bottom:AddItem(Label("Unsaved Data Stored in Clipboard"))
			else
				bottom:AddItem(Label("No Data in Clipboard"))
			end
			--bottom:CheckBox("Debug Save (larger file):", "adv_duplicator_debugsave")
			if AdvDupeClient.FileLoaded or AdvDupeClient.Copied then
				bottom:NumSlider("Height Offset:", "adv_duplicator_height", -128, 128, 0)
				bottom:NumSlider( "Angle Offset:", "adv_duplicator_angle", -180, 180, 0 )
				bottom:CheckBox("Paste Frozen:", "adv_duplicator_pastefrozen")
				bottom:CheckBox("Paste w/o Constraints (and frozen):", "adv_duplicator_pastewoconst")
			end
			bottom:CheckBox("Limited Ghost:", "adv_duplicator_LimitedGhost")
			if AdvDupeClient.HasStartPos then
				bottom:CheckBox("Paste at Original Location:", "adv_duplicator_worldOrigin")
			end
			bottom:CheckBox("Paste at Original Angles:", "adv_duplicator_worldAngles")

			bottom:PerformLayout() --do this so bottom:GetTall() will return the correct value

			CPanel:AddItem(ServerDir)
			ServerDir:SetTall(CPanel:GetParent():GetParent():GetTall()-80-bottom:GetTall())
			CPanel:AddItem(bottom)

		elseif menu == "serverdir" then

			CPanel:Button( "--Back--", "adv_duplicator_cl_menu", "main")

			if not SinglePlayer() then
				CPanel:AddItem(Label("Server Folder Management"))
			else
				CPanel:AddItem(Label("Local Folder Management"))
			end

			local middle = vgui.Create( "ControlPanel")
			middle:Button("Make New Folder", "adv_duplicator_makedir_gui", "server")
			if not SinglePlayer() and dupeshare.UsePWSys then
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
			CPanel:AddItem(Label("Paster Settings (make with reload)"))
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

			if not SinglePlayer() then

				CPanel:AddItem(Label("Upload/Download Menu"))

				CPanel:AddItem(Label("Files on Server"))

				local middle = vgui.Create( "ControlPanel")
				if AdvDupeClient.downloading then
					middle:AddItem(Label("==Download in Progress=="))
				elseif AdvDupeClient.CanDownload() then
					middle:Button("Download Selected File", "adv_duplicator_send_cl")
				else
					middle:AddItem(Label("Server Disabled Downloads"))
				end

				if AdvDupeClient.sending then
					middle:AddItem(Label("==Upload in Progress=="))
				elseif AdvDupeClient.CanUpload() then
					middle:Button("Upload File to server", "adv_duplicator_upload_cl")
				else
					middle:AddItem(Label("Server Disabled Uploads"))
				end
				middle:AddItem(Label("Local Files"))
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


			if not SinglePlayer() then
				CPanel:AddItem(Label("Local Folder Management"))

				local middle = vgui.Create( "ControlPanel")
				middle:Button("Make New Folder", "adv_duplicator_makedir_gui", "client")
				middle:Button("Rename", "adv_duplicator_renamefile_gui", "client")
				middle:Button("Copy", "adv_duplicator_cl_fileopts", "copy")
				middle:Button("Move", "adv_duplicator_cl_fileopts", "move")
				middle:Button("Delete", "adv_duplicator_confirmdelete_gui", "client") --"adv_duplicator_cl_fileopts delete"
				middle:AddItem(Label("Local Files"))
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

		local dir = string.Implode(" ", args)

		if ( file.Exists(dir) && file.IsDir(dir) ) then
			AdvDupeClient.CLcdir = dir
		end

		LocalPlayer():ConCommand("adv_duplicator_updatelist")

	end
	concommand.Add( "adv_duplicator_open_cl", AdvDupeCl_OpenDir )

	local function AdvDupeCl_OpenDir2(pl, command, args)
		if !pl:IsValid() or !pl:IsPlayer() then return end

		local dir = string.Implode(" ", args)

		if ( file.Exists(dir) && file.IsDir(dir) ) then
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

		AdvDupeClient.UpLoadFile( pl, filename )

		AdvDuplicator_UpdateControlPanel()
	end
	concommand.Add( "adv_duplicator_upload_cl", AdvDupeCL_UpLoad )

end

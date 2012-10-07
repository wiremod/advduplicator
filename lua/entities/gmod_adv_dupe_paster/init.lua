//Advanced Duplicator Paster by TAD2020
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

ENT.WireDebugName = "Paster"
ENT.OverlayDelay = 0

local MODEL = Model( "models/props_lab/powerbox02d.mdl" )

function ENT:Initialize()
	self:SetModel( MODEL )

	self:SetMoveType( MOVETYPE_NONE )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	self:DrawShadow( false )

	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then phys:Wake() end

	self.UndoListEnts	= {}
	self.UndoListConsts	= {}
	self.PropCount	= 0

	// Spawner is "edge-triggered"
	self.SpawnLastValue	= 0
	self.UndoLastValue	= 0

	if WireAddon then
		// Add inputs/outputs (TheApathetic)
		self.Inputs = Wire_CreateInputs(self, {"Spawn", "Undo", "X", "Y", "Z" })
		self.Outputs = Wire_CreateOutputs(self, {"PropCount", "ClearToPaste"})
		Wire_TriggerOutput(self, "ClearToPaste", 1)
	end

	self.ClearToPaste = true

	self.stage = 0
	self.thinkdelay = 0.05

	self.Ents,self.Constraints,self.DupeInfo,self.offset = nil,nil,nil,nil
	self.constIDtable, self.entIDtable, self.CreatedConstraints, self.CreatedEnts, self.TempMoveTypes = {}, {}, {}, {}, {}

end

function ENT:Setup(ents, const, holdangle, delay, undo_delay, max_range, show_beam, HeadEntityIdx, NumOfEnts, NumOfConst, PasteFrozen, PastewoConst)

	self.MyEnts 			= ents
	self.MyConstraints 		= const
	self.MyHoldAngle		= holdangle
	self.delay				= delay
	self.undo_delay			= undo_delay
	self.MaxRange			= max_range
	self.ShowBeam			= show_beam
	self.MyHeadEntityIdx	= HeadEntityIdx
	self.NumOfEnts			= NumOfEnts
	self.NumOfConst			= NumOfConst
	self.PasteFrozen		= PasteFrozen
	self.PastewoConst		= PastewoConst

	self:ShowOutput()

	if (show_beam) then
		self:SetBeamLength(math.min(self.MaxRange, 2000))
	else
		self:SetBeamLength(0)
	end

end

function ENT:OnTakeDamage( dmginfo )	self:TakePhysicsDamage( dmginfo ) end

local function OnPasteFin( paster, Ents, Consts )
	paster.PropCount = paster.PropCount + 1
	paster.UndoListEnts[paster.PropCount] = {}

	for k, ent in pairs( Ents ) do
		table.insert(paster.UndoListEnts[paster.PropCount], ent)
	end
	--Msg("adding undos\n")
	paster:ShowOutput()
end


local function ClearToPaste( ent )
	ent:GetTable().ClearToPaste = true
	if WireAddon then
		Wire_TriggerOutput(ent, "ClearToPaste", 1)
	end
end


function ENT:Paste()

	if (self.MaxRange > 0) then
		local skew		= Vector(self:GetSkewX(), self:GetSkewY(), 1)
		skew			= skew*((self.MaxRange + self:GetSkewZ())/skew:Length())
		local beam_x	= self:GetRight()*skew.x
		local beam_y	= self:GetForward()*skew.y
		local beam_z	= self:GetUp()*skew.z
		local trace		= {}
		trace.start		= self:GetPos() + self:GetUp()*self:OBBMaxs().z
		trace.endpos	= trace.start + beam_x + beam_y + beam_z
		local trace		= util.TraceLine(trace)
		self.offset		= trace.HitPos
	else
		self.offset = self:GetPos() + self:GetUp() * self:OBBMaxs().z
	end

	local angle  = self:GetAngles()
	angle.pitch = 0
	angle.roll = 0

	AdvDupe.StartPaste( self:GetPlayer(), self.MyEnts, self.MyConstraints, self.MyHeadEntityIdx, self.offset, angle - self.MyHoldAngle, self.NumOfEnts, self.NumOfConst, self.PasteFrozen, self.PastewoConst, OnPasteFin, true, self, true )

	timer.Simple( AdvDupe.GetPasterClearToPasteDelay(), function() ClearToPaste( self ) end)

end


function ENT:TriggerInput(iname, value)
	local pl = self:GetPlayer()

	if (iname == "Spawn") then
		// Spawner is "edge-triggered" (TheApathetic)
		if ((value > 0) == self.SpawnLastValue) or (!self.ClearToPaste) then return end
		self.SpawnLastValue = (value > 0)

		if (self.SpawnLastValue) then
			Wire_TriggerOutput(self, "ClearToPaste", 0)
			self.ClearToPaste = false

			// Simple copy/paste of old numpad Spawn with a few modifications
			if (self.delay == 0) then self:Paste() return end

			local TimedSpawn = 	function ( ent, pl )
				if (!ent) then return end
				if (!ent == NULL) then return end
				ent:GetTable():Paste()
			end

			timer.Simple( self.delay, function() TimedSpawn( self, pl ) end)
		end
	elseif (iname == "Undo") then
		// Same here
		if ((value > 0) == self.UndoLastValue) then return end
		self.UndoLastValue = (value > 0)

		if (self.UndoLastValue) then self:DoUndo(pl) end
	elseif (iname == "X") then
		self:SetSkewX(self.Inputs.X.Value or 0)
	elseif (iname == "Y") then
		self:SetSkewY(self.Inputs.Y.Value or 0)
	elseif (iname == "Z") then
		if (self.ShowBeam) then
			self:SetBeamLength(math.min((self.MaxRange + value), 2000))
		end
		self.SkewZ = math.min(value, -self.MaxRange)
	end
end


function ENT:ShowOutput()
	self:SetOverlayText("Spawn Delay: "..self.delay.."\nUndo Delay: "..self.undo_delay.."\nCurrent Props: "..self.PropCount)
	if WireAddon then
		Wire_TriggerOutput(self, "PropCount", self.PropCount)
	end
end


function ENT:DoUndo( pl )

	if (!self.UndoListEnts or #self.UndoListEnts == 0) then return end

	local Ents = {}
	local FoundOne = false

	repeat

		Ents = table.remove(self.UndoListEnts, 1)

		self.PropCount = self.PropCount - 1

		if Ents then
			for _, ent in pairs( Ents ) do
				if (ent and ent:IsValid()) then
					ent:Remove()
					--Msg("undoing\n")
					FoundOne = true
				end
			end
		else
			FoundOne = true
		end

	until FoundOne

	/*for _, ent in pairs( Ents ) do
		if (ent && ent:IsValid()) then
			ent:Remove()
			FoundOne = true
		end
	end*/

	umsg.Start( "UndoWirePasterProp", pl ) umsg.End()

	Wire_TriggerOutput(self, "Out", self.PropCount)
	self:ShowOutput()
end


function ENT:UndoPaste(pastenum)

	//todo: for delay undo
	//need a way to index a pasted ent and remove it's table from the undolist table and be able to add to the undo list.

end


function ENT:OnRemove()
	Wire_Remove(self)
end

function ENT:OnRestore()
    Wire_Restored(self)
end


local function Paste( pl, ent )
	if (!ent:IsValid()) or (!ent.ClearToPaste) then return end

	ent.ClearToPaste = false

	local delay = ent.delay
	if (delay == 0) then ent:Paste() return end

	local TimedSpawn = 	function ( ent, pl )
							if (!ent) then return end
							if (!ent == NULL) then return end
							ent:Paste()
						end
	timer.Simple( delay, function() TimedSpawn( ent, pl ) end)
end

local function Undo( pl, ent )
	if (!ent:IsValid()) then return end
	ent:DoUndo( pl )
end

numpad.Register( "PasterCreate",	Paste )
numpad.Register( "PasterUndo",		Undo  )


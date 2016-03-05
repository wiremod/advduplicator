AddCSLuaFile( "autorun/client/cl_advdupe.lua" )
AddCSLuaFile( "autorun/shared/dupeshare.lua" )

include( "autorun/shared/dupeshare.lua" )
if (!dupeshare) then Msg("===AdvDupe: Error! dupeshare module not loaded\n") end
--[[---------------------------------------------------------
   Advanced Duplicator module
   Author: TAD2020
   Thanks to: TheApathetic, SatriAli, Erkle
-----------------------------------------------------------]]

AdvDupe = {}

if (CLIENT) then return end

AdvDupe.Version = 1.85
AdvDupe.ToolVersion = 1.9
AdvDupe.FileVersion = 0.84

CreateConVar( "sv_AdvDupeEnablePublicFolder", 1, {FCVAR_ARCHIVE} )

--[[---------------------------------------------------------
  Process and save given dupe tables to file
-----------------------------------------------------------]]
function AdvDupe.SaveDupeTablesToFile( ply, EntTables, ConstraintTables, HeadEntityIdx, HoldAngle, HoldPos, filename, desc, StartPos, debugsave )
	
	--save to a sub folder for each player
	--local dir = "adv_duplicator/"..dupeshare.GetPlayerName(ply)
	if (!AdvDupe[ply]) then AdvDupe[ply] = {} end
	local dir = AdvDupe[ply].cdir or AdvDupe.GetPlayersFolder(ply)
	
	--get and check the that filename contains no illegal characters
	local filename = dupeshare.ReplaceBadChar(filename)
	--tostring(ply:GetInfo( "adv_duplicator_save_filename" )))
	
	filename = dupeshare.FileNoOverWriteCheck( dir, filename )
	
	--save to file
	local temp = {}
	temp.HeadEntityIdx		= HeadEntityIdx
	temp.HoldAngle			= HoldAngle
	temp.HoldPos			= HoldPos
	temp.Entities			= EntTables
	ConstsTable				= {}
	for k, v in pairs(ConstraintTables) do
		table.insert( ConstsTable, v )
	end
	temp.Constraints		= ConstsTable
	
	local Creator			= ply:GetName() or "unknown"
	local NumOfEnts			= table.Count(EntTables) or 0
	local NumOfConst		= table.Count(ConstraintTables) or 0
	
	local Header = {}
	Header[1] = "Type:"			.."AdvDupe File"
	Header[2] =	"Creator:"		..string.format('%q', Creator)
	Header[3] =	"Date:"			..os.date("%m/%d/%y")
	if (!desc) or (desc == "") then desc = "none" end
	Header[4] =	"Description:"	..string.format('%q', desc)
	Header[5] =	"Entities:"		..NumOfEnts
	Header[6] =	"Constraints:"	..NumOfConst
	
	local ExtraHeader = {}
	ExtraHeader[1] = "FileVersion:"				..AdvDupe.FileVersion
	ExtraHeader[2] = "AdvDupeVersion:"			..AdvDupe.Version
	ExtraHeader[3] = "AdvDupeToolVersion:"		..AdvDupe.ToolVersion
	ExtraHeader[4] = "AdvDupeSharedVersion:"	..dupeshare.Version
	ExtraHeader[5] = "SerialiserVersion:"		..Serialiser.Version
	ExtraHeader[6] = "WireVersion:"				..(WireVersion or "Not Installed")
	ExtraHeader[7] = "Time:"					..os.date("%I:%M %p")
	ExtraHeader[8] = "Head:"					..HeadEntityIdx
	ExtraHeader[9] = "HoldAngle:"				..string.format( "%g,%g,%g", HoldAngle.pitch, HoldAngle.yaw, HoldAngle.roll )
	ExtraHeader[10] = "HoldPos:"				..string.format( "%g,%g,%g", HoldPos.x, HoldPos.y, HoldPos.z )
	ExtraHeader[11] = "StartPos:"				..string.format( "%g,%g,%g", StartPos.x, StartPos.y, StartPos.z )
	
	Serialiser.SaveTablesToFile( ply, filename, Header, ExtraHeader, NumOfEnts, EntTables, NumOfConst, ConstsTable, debugsave )
	
	return filename, Creator, desc , NumOfEnts, NumOfConst, AdvDupe.FileVersion --for sending to client after saving
end

--[[---------------------------------------------------------
  Load and return dupe tables from given file
-----------------------------------------------------------]]
function AdvDupe.LoadDupeTableFromFile( ply, filepath )
	filepath = filepath:lower()
	
	if ( !file.Exists(filepath, "DATA") ) then return end
	
	local tool = AdvDupe.GetAdvDupeToolObj(ply)
	if ( !tool ) then return end
	
	local function Load1(ply, filepath, tool, temp)
		
		--
		--	new file format
		--
		if ( string.Left(temp, 5) != "\"Out\"") then
			
			--local HeaderTbl, ExtraHeaderTbl, Data = Serialiser.DeserialiseWithHeaders( temp )
			
			local function Load2NewFile(ply, filepath, tool, HeaderTbl, ExtraHeaderTbl, Data)
				if ( HeaderTbl.Type ) and ( HeaderTbl.Type == "AdvDupe File" ) then
					
					--MsgN("AdvDupe:Loaded new file ",filepath,"  version: ",ExtraHeaderTbl.FileVersion)
					
					ExtraHeaderTbl.FileVersion = tonumber(ExtraHeaderTbl.FileVersion)
					
					if (ExtraHeaderTbl.FileVersion > AdvDupe.FileVersion) then
						Msg("AdvDupeINFO:File is newer than installed version, failure may occure, you should update.")
					end
					
					if ( ExtraHeaderTbl.FileVersion >= 0.82 ) and ( ExtraHeaderTbl.FileVersion < 0.9 )then
						
						local a,b,c = ExtraHeaderTbl.HoldAngle:match("(.-),(.-),(.+)")
						local HoldAngle = Angle( tonumber(a), tonumber(b), tonumber(c) )
						
						local a,b,c = ExtraHeaderTbl.HoldPos:match("(.-),(.-),(.+)")
						local HoldPos = Vector( tonumber(a), tonumber(b), tonumber(c) )
						
						local StartPos
						if ( ExtraHeaderTbl.FileVersion >= 0.83 ) then
							local a,b,c = ExtraHeaderTbl.StartPos:match("(.-),(.-),(.+)")
							StartPos = Vector( tonumber(a), tonumber(b), tonumber(c) )
						end
						
						tool:LoadFileCallBack( filepath,
							Data.Entities, Data.Constraints,
							{},{}, tonumber(ExtraHeaderTbl.Head),
							HoldAngle,
							HoldPos, false,
							HeaderTbl.Creator:sub(2, -2),
							HeaderTbl.Description:sub(2, -2),
							tonumber(HeaderTbl.Entities),
							tonumber(HeaderTbl.Constraints),
							ExtraHeaderTbl.FileVersion,
							HeaderTbl.Date,
							ExtraHeaderTbl.Time, StartPos
						)
					elseif ( ExtraHeaderTbl.FileVersion <= 0.81 ) then
						tool:LoadFileCallBack( filepath,
							Data.Entities, Data.Constraints,
							{},{}, Data.HeadEntityIdx,
							Data.HoldAngle,
							Data.HoldPos, false,
							HeaderTbl.Creator:sub(2, -2),
							HeaderTbl.Description:sub(2, -2),
							tonumber(HeaderTbl.Entities),
							tonumber(HeaderTbl.Constraints),
							ExtraHeaderTbl.FileVersion,
							HeaderTbl.Date,
							ExtraHeaderTbl.Time
						)
					end
					
					--[[return Data.Entities, Data.Constraints,
					{},{}, Data.HeadEntityIdx,
					Data.HoldAngle,
					Data.HoldPos, false, 
					HeaderTbl.Creator:sub(2, -2),
					HeaderTbl.Description:sub(2, -2), 
					HeaderTbl.Entities,
					HeaderTbl.Constraints,
					ExtraHeaderTbl.FileVersion,
					HeaderTbl.Date,
					ExtraHeaderTbl.Time--]]
					
				elseif ( HeaderTbl.Type ) and ( HeaderTbl.Type == "Contraption Saver File" ) then
					
					--MsgN("AdvDupe:Loaded Contraption Saver file ",filepath,"  version: ",ExtraHeaderTbl.Version)
					
					--[[for k,v in pairs(Data.Entities) do
						v.LocalPos.z = v.LocalPos.z + Data.Height + 8
					end--]]
					
					--[[for k,v in pairs(Data.Constraints) do
						if (v.Entity) then
							for b, j in pairs(v.Entity) do
								if ( j.World and j.LPos ) then
									v.Entity[b].LPos.z = j.LPos.z + Data.Height + 8
								end
							end
						end
					end--]]
					
					ply:ConCommand( "adv_duplicator_height "..(Data.Height + 8) )
					
					tool:LoadFileCallBack( filepath,
						Data.Entities, Data.Constraints,
						{},{}, Data.Head, Angle(0,0,0), 
						Vector(0,0, -(Data.Height + 8)), --Data.Entities[Data.Head].LocalPos.z + 
						false, HeaderTbl.Creator:sub(2, -2),
						"Contraption Saver file v"..ExtraHeaderTbl.Version, 
						tonumber(HeaderTbl.Entities),
						tonumber(HeaderTbl.Constraints),
						tonumber(ExtraHeaderTbl.Version),
						HeaderTbl.Date,
						"n/a"
					)
					
				elseif (Data.Information) then
					--MsgN("AdvDupe:Loaded old Contraption Saver file version ",Data.Information.Version)
					
					--find the lowest and use that as the head
					local head,low
					for k,v in pairs(Data.Entities) do
						if (!head) or (v.Pos.z < low) then
							head = k
							low = v.Pos.z
						end
					end
					
					--Convert the Pos and Angle keys to a system AdvDupe understands
					AdvDupe.ConvertPositionsToLocal( Data.Entities, Data.Constraints, Data.Entities[head].Pos + Vector(0,0,-15), Angle(0,0,0) )
					
					tool:LoadFileCallBack( filepath,
						Data.Entities, Data.Constraints,
						{},{}, head, Angle(0,0,0), Vector(0,0,0), false, 
						Data.Information.Creator,
						"Old Contraption Saver file v"..Data.Information.Version, 
						Data.Information.Entities,
						Data.Information.Constraints,
						Data.Information.Version,
						Data.Information.Date,
						"n/a"
					)
					
					--[[return Data.Entities, Data.Constraints,
					{},{}, head,
					Angle(0,0,0),
					Vector(0,0,0), false, 
					Data.Information.Creator,
					"Old Contraption Saver file v"..Data.Information.Version, 
					Data.Information.Entities,
					Data.Information.Constraints,
					Data.Information.Version,
					Data.Information.Date,
					"n/a"--]]
					
				else
					AdvDupe.SendClientError(ply, "Unknown File Type or Bad File")
					Msg("AdvDupeERROR: Unknown File Type or Bad File\n")
					AdvDupe.SetPercent( ply, -1 )
					return
				end
			end
			
			--timer.Simple(.1, Load2NewFile, ply, filepath, tool, HeaderTbl, ExtraHeaderTbl, Data)
			
			Serialiser.DeserialiseWithHeaders( temp, Load2NewFile, ply, filepath, tool )
			
			return --or it will try to load as an old file
			
		end
		
		--
		--	old file formats
		--
		temp = util.KeyValuesToTable(temp)
		
		if ( temp["VersionInfo"] or temp["versioninfo"] ) then --pre-0.6x file, it ueses a different meathod os stroing FullCase
			--Msg("AdvDipe: Loading old legacy file type\n")
			temp = dupeshare.RebuildTableFromLoad_Old(temp)
		elseif ( temp["strtbl"] ) then -- v0.7x
			--Msg("AdvDipe: Loading v0.7x file type\n")
			local StrTbl = temp["strtbl"]
			temp["strtbl"] = nil
			temp = dupeshare.RebuildTableFromLoad(temp, {}, StrTbl)
		else --0.6x
			--Msg("AdvDipe: Loading v0.6x file type\n")
			temp = dupeshare.RebuildTableFromLoad(temp)
		end
		
		if (temp) and (temp["VersionInfo"]) and (temp["VersionInfo"]["FileVersion"] > AdvDupe.FileVersion) then
			Msg("AdvDupeINFO:File is newer than installed version, failure may occure, you should update.")
		end
		
		local function Load3(ply, filepath, tool, temp)
			--check the file was loaded and we understand it's version then load the data in to the tables
			if (temp) and (temp["VersionInfo"]) and (temp["VersionInfo"]["FileVersion"] >= 0.6) then
				--MsgN("AdvDupe:Loaded old file ",filepath,"  version: ",temp.VersionInfo.FileVersion)
				
				tool:LoadFileCallBack( filepath,
					temp.EntTables, temp.ConstraintTables, {},{}, 
					temp.HeadEntityIdx, temp.HoldAngle, temp.HoldPos, 
					false, temp.VersionInfo.Creator, temp.VersionInfo.Desc, 
					temp.VersionInfo.NumOfEnts, temp.VersionInfo.NumOfConst, 
					temp.VersionInfo.FileVersion
				)
				
				--[[return temp.EntTables, temp.ConstraintTables, {},{}, 
				temp.HeadEntityIdx, temp.HoldAngle, temp.HoldPos, false, 
				temp.VersionInfo.Creator, temp.VersionInfo.Desc, temp.VersionInfo.NumOfEnts, 
				temp.VersionInfo.NumOfConst, temp.VersionInfo.FileVersion--]]
				
			--Legacy versions, there are no version 0.5 files
			elseif (temp) and (temp["VersionInfo"]) and (temp["VersionInfo"]["FileVersion"] <= 0.4) then
				--MsgN("AdvDupe:Loaded old legacy file ",filepath,"  version: ",temp.VersionInfo.FileVersion)
				
				if (temp["VersionInfo"]["FileVersion"] <= 0.2) then
					temp.DupeInfo = {}
					for id, entTable in pairs(temp.Ents) do
						if (entTable.DupeInfo) then
							temp.DupeInfo[id] = entTable.DupeInfo
						end
					end
				end
				
				tool:LoadFileCallBack( filepath,
					temp.Ents, temp.Constraints, temp.DupeInfo, 
					(temp.DORInfo or {}), temp.HeadEntID, temp.HoldAngle, Vector(0,0,0), 
					true, temp.VersionInfo.Creator, temp.VersionInfo.Desc, 
					temp.VersionInfo.NumOfEnts, temp.VersionInfo.NumOfConst, 
					temp.VersionInfo.FileVersion
				)
				
				--[[return temp.Ents, temp.Constraints, temp.DupeInfo, 
				(temp.DORInfo or {}), temp.HeadEntID, temp.HoldAngle, Vector(0,0,0), 
				true, temp.VersionInfo.Creator, temp.VersionInfo.Desc, 
				temp.VersionInfo.NumOfEnts, temp.VersionInfo.NumOfConst, 
				temp.VersionInfo.FileVersion--]]
				
			elseif (temp) and (temp["Information"]) then --Old Contrpation Saver File
				--Msg("AdvDupe:Loading old Contraption Saver file.\n")
				
				--find the lowest and use that as the head
				local head,low
				for k,v in pairs(temp.Entities) do
					if (!head) or (v.Pos.z < low) then
						head = k
						low = v.Pos.z
					end
				end
				
				--Convert the Pos and Angle keys to a system AdvDupe understands
				AdvDupe.ConvertPositionsToLocal( temp.Entities, temp.Constraints, temp.Entities[head].Pos, Angle(0,0,0) )
				
				tool:LoadFileCallBack( filepath,
					temp.Entities, temp.Constraints,
					{},{}, head, Angle(0,0,0), Vector(0,0,0),
					false, temp.Information.Creator, "Old Contrpaption Saver File",
					temp.Information.Entities, temp.Information.Constraints, 
					"Old Contrpaption Saver File", temp.Date
				)
				
				--[[return temp.Entities, temp.Constraints,
				{},{}, head, Angle(0,0,0), Vector(0,0,0),
				false, temp.Information.Creator, "Old Contrpaption Saver File",
				temp.Information.Entities, temp.Information.Constraints, "Old Contrpaption Saver File", temp.Date--]]
				
				
			else
				MsgN("AdvDupeERROR:FILE FAILED TO LOAD! something is wrong with this file:  ",filepath)
				AdvDupe.SendClientError( ply, "Failed loading file" )
				AdvDupe.SetPercent( ply, -1 )
			end
			
			AdvDupe.SetPercent(ply, 50)
			
		end
		
		AdvDupe.SetPercent(ply, 30)
		timer.Simple(.1, function() Load3( ply, filepath, tool, temp ) end)
	end
	
	AdvDupe.SetPercent(ply, 10)
	local f, temp = file.Open(dupeshare.ParsePath(filepath), "r", "DATA"), ""
	if f then
		temp = f:Read( f:Size() )
		f:Close()
	end
	timer.Simple(.1, function() Load1( ply, filepath, tool, temp) end)
	
end


--[[---------------------------------------------------------
  Prepreares Tables For Save
   Compacts the size of the table by
   returning what will be needed
-----------------------------------------------------------]]
--[[function AdvDupe.CompactTables( EntityList, ConstraintList )

	local SaveableEntities = {}
	for k, v in pairs( EntityList ) do
		
		if AdvDupe.NewSave then
			SaveableEntities[ k ] = AdvDupe.EntityArgsFromTable( v )
		else
			SaveableEntities[ k ] = AdvDupe.SaveableEntityFromTable( v )
		end
		
		SaveableEntities[ k ].BoneMods = ( v.BoneMods ) --table.Copy
		SaveableEntities[ k ].EntityMods = ( v.EntityMods )
		SaveableEntities[ k ].PhysicsObjects = ( v.PhysicsObjects )
		
	end
	
	local SaveableConstraints = {}
	for k, Constraint in pairs( ConstraintList ) do
		
		local SaveableConst = AdvDupe.SaveableConstraintFromTable( Constraint )
		
		if ( SaveableConst ) then
			table.insert( SaveableConstraints, SaveableConst )
		end
		
	end
	
	return SaveableEntities, SaveableConstraints
	
end

function AdvDupe.StoreBasicsFromEntityTable( EntTable )
	
	local SaveableEntity = {}
	SaveableEntity.Class = EntTable.Class
	
	if ( EntTable.Model ) then SaveableEntity.Model = EntTable.Model end
	if ( EntTable.Angle ) then SaveableEntity.Angle = EntTable.Angle end
	if ( EntTable.Pos ) then SaveableEntity.Pos = EntTable.Pos end
	if ( EntTable.LocalPos ) then SaveableEntity.LocalPos = EntTable.LocalPos end
	if ( EntTable.LocalAngle ) then SaveableEntity.LocalAngle = EntTable.LocalAngle end
	
	if ( EntTable.CollisionGroup ) then
		if ( !EntTable.EntityMods ) then EntTable.EntityMods = {} end
		EntTable.EntityMods.CollisionGroupMod = EntTable.CollisionGroup
	end
	
	return SaveableEntity
	
end

function AdvDupe.SaveableEntityFromTable( EntTable )

	local EntityClass = duplicator.FindEntityClass( EntTable.Class )
	local SaveableEntity = AdvDupe.StoreBasicsFromEntityTable( EntTable )
	
	if (!EntityClass) then
		return SaveableEntity
	end
	
	for iNumber, Key in pairs( EntityClass.Args ) do
		
		SaveableEntity[ Key ] = EntTable[ Key ]
		
	end
	
	return SaveableEntity
	
end

function AdvDupe.SaveableConstraintFromTable( Constraint )

	local Factory = duplicator.ConstraintType[ Constraint.Type ]
	if ( !Factory ) then return end
	
	local SaveableConst = {}
	SaveableConst.Type = Constraint.Type
	SaveableConst.Entity = table.Copy( Constraint.Entity )
	if (Constraint.Entity1) then SaveableConst.Entity1 = table.Copy( Constraint.Entity1 ) end
	
	for k, Key in pairs( Factory.Args ) do
		if (!string.find(Key, "Ent") or string.len(Key) != 4)
		and (!string.find(Key, "Bone") or string.len(Key) != 5)
		and (Key != "Ent") and (Key != "Bone")
		and (Constraint[ Key ]) and (Constraint[ Key ] != false) then --don't include faluse values
			SaveableConst[ Key ] = Constraint[ Key ]
		end
	end
	
	return SaveableConst

end--]]

--[[function AdvDupe.EntityArgsFromTable( EntTable )
	
	local EntityClass = duplicator.FindEntityClass( EntTable.Class )
	local SaveableEntity = AdvDupe.StoreBasicsFromEntityTable( EntTable )
	
	-- This class is unregistered. Just save the basics instead
	if (!EntityClass) then
		return SaveableEntity
	end
	
	-- Build the argument list
	local ArgList = {}
	for iNumber, Key in pairs( EntityClass.Args ) do
		local Arg = nil
		-- Translate keys from old system
		if ( Key == "pos" || Key == "position" ) then Key = "Pos" end
		if ( Key == "ang" || Key == "Ang" || Key == "angle" ) then Key = "Angle" end
		if ( Key == "model" ) then Key = "Model" end
		Arg = EntTable[ Key ]
		-- Doesn't save space to prebuild the arglist when there is a data key, we'd end up with a self-nested table
		if ( Key == "Data" ) then return SaveableEntity end
		-- If there's a missing argument then unpack will stop sending at that argument
		if ( Arg == nil ) then Arg = false end
		if ( Key != "Pos" ) and ( Key != "Angle" ) then
			ArgList[ iNumber ] = Arg
		end
	end
	
	SaveableEntity.arglist = ArgList
	
	return SaveableEntity
	
end--]]


--
--	Gets savable info from an entity
--
function AdvDupe.GetSaveableEntity( Ent, Offset )
	-- Filter duplicator blocked entities out.
	if ( Ent.DoNotDuplicate ) then return end

	if ( Ent.PreEntityCopy ) then Ent:PreEntityCopy() end
	
	--we're going to be a little distructive to this table, let's not use the orginal
	local Tab = table.Copy( Ent:GetTable() )
	
	if ( Ent.PostEntityCopy ) then Ent:PostEntityCopy() end
	
	--let's junk up the table a little
	Tab.Angle = Ent:GetAngles()
	Tab.Pos = Ent:GetPos()
	Tab.CollisionGroup = Ent:GetCollisionGroup()
	
	-- Physics Objects
	Tab.PhysicsObjects =  Tab.PhysicsObjects or {}
	local iNumPhysObjects = Ent:GetPhysicsObjectCount()
	for Bone = 0, iNumPhysObjects-1 do 
		local PhysObj = Ent:GetPhysicsObjectNum( Bone )
		if ( PhysObj:IsValid() ) then
			Tab.PhysicsObjects[ Bone ] = Tab.PhysicsObjects[ Bone ] or {}
			Tab.PhysicsObjects[ Bone ].Pos = PhysObj:GetPos()
			Tab.PhysicsObjects[ Bone ].Angle = PhysObj:GetAngles()
			Tab.PhysicsObjects[ Bone ].Frozen = !PhysObj:IsMoveable()
			if PhysObj:IsGravityEnabled() == false then Tab.PhysicsObjects[ Bone ].NoGrav = true end
		end
	end
	
	-- Flexes (WTF are these?)
	local FlexNum = Ent:GetFlexNum()
	for i = 0, FlexNum do
		Tab.Flex = Tab.Flex or {}
		Tab.Flex[ i ] = Ent:GetFlexWeight( i )
	end
	Tab.FlexScale = Ent:GetFlexScale()
	
	-- Let the ent fuckup our nice new table if it wants too
	if ( Ent.OnEntityCopyTableFinish ) then Ent:OnEntityCopyTableFinish( Tab ) end
	
	--moved from ConvertPositionsToLocal
	Tab.Pos = Tab.Pos - Offset
	Tab.LocalPos = Tab.Pos * 1
	Tab.LocalAngle = Tab.Angle * 1
	if ( Tab.PhysicsObjects ) then
		for Num, Object in pairs(Tab.PhysicsObjects) do
			Object.Pos = Object.Pos - Offset
			Object.LocalPos = Object.Pos * 1
			Object.LocalAngle = Object.Angle * 1
			Object.Pos = nil
			Object.Angle = nil
		end
	end
	
	--Save CollisionGroupMod
	if ( Tab.CollisionGroup ) then
		if ( !Tab.EntityMods ) then Tab.EntityMods = {} end
		Tab.EntityMods.CollisionGroupMod = Tab.CollisionGroup
	end
	
	--fix for saving key on camera
	if (Ent:GetClass() == "gmod_cameraprop") then
		Tab.key = Ent:GetNetworkedInt("key")
	end
	
	--Saveablity
	local SaveableEntity = {}
	SaveableEntity.Class		 = Ent:GetClass()
	
	-- escape the model string properly cause something out there rapes it sometimes
	SaveableEntity.Model = table.concat( dupeshare.split( Ent:GetModel(), '\\+' ), "/" )
	
	SaveableEntity.Skin				= Ent:GetSkin()
	SaveableEntity.LocalPos			= Tab.LocalPos
	SaveableEntity.LocalAngle		= Tab.LocalAngle
	SaveableEntity.BoneMods			= table.Copy( Tab.BoneMods )
	SaveableEntity.EntityMods		= table.Copy( Tab.EntityMods )
	SaveableEntity.PhysicsObjects	= table.Copy( Tab.PhysicsObjects )
	if Ent.GetNetworkVars then SaveableEntity.DT = Ent:GetNetworkVars() end
	
	if IsValid( Ent:GetParent() ) then
		SaveableEntity.SavedParentIdx = Ent:GetParent():EntIndex()
	end
	
	local EntityClass = duplicator.FindEntityClass( SaveableEntity.Class )
	if (!EntityClass) then return SaveableEntity end -- This class is unregistered. Just save what we have so far
	
	--filter functions, we only want to save what will be used
	for iNumber, key in pairs( EntityClass.Args ) do
		--we dont need this crap, it's already added
		if (key != "pos") and (key != "position") and (key != "Pos") and ( key != "model" ) and (key != "Model")
		and (key != "ang") and (key != "Ang") and (key != "angle") and (key != "Angle") and (key != "Class") then
			SaveableEntity[ key ] = Tab[ key ]
		end
	end
	
	--[[local ArgList = {}
	for iNumber, Key in pairs( EntityClass.Args ) do
		
		-- Doesn't save space to prebuild the arglist when there is a data key, we'd end up with a self-nested table
		if ( Key == "Data" ) then
			for iNumber, key in pairs( EntityClass.Args ) do
				--we dont need this crap, it's already added
				if (key != "pos") and (key != "position") and (key != "Pos") and ( key != "model" ) and (key != "Model")
				and (key != "ang") and (key != "Ang") and (key != "angle") and (key != "Angle") then
					SaveableEntity[ key ] = Tab[ key ]
				end
			end
			ArgList = nil
			break
		end
		
		if (key != "pos") and (key != "position") and (key != "Pos")
		and (key != "ang") and (key != "Ang") and (key != "angle") and (key != "Angle") then
			local Arg
			if ( Key == "model" ) or ( Key == "Model" ) then
				Arg = Ent:GetModel()
			elseif Tab[ Key ] then
				Arg = Tab[ Key ]
			else
				Arg = false
			end
			ArgList[ iNumber ] = Arg
		end
		
	end
	SaveableEntity.arglist = ArgList--]]
	
	return SaveableEntity	
end

--
--	Gets savable info from an constraint
--
function AdvDupe.GetSaveableConst( ConstraintEntity, Offset )
	if (!ConstraintEntity) then return end

	-- Filter duplicator blocked constraint out.
	if ConstraintEntity.DoNotDuplicate then return end
	
	local SaveableConst = {}
	local ConstTable = ConstraintEntity:GetTable()
	
	local Factory = duplicator.ConstraintType[ ConstTable.Type ]
	if ( Factory ) then
		SaveableConst.Type = ConstTable.Type
		
		for k, Key in pairs( Factory.Args ) do
			if (!string.find(Key, "Ent") or string.len(Key) != 4)
			and (!string.find(Key, "Bone") or string.len(Key) != 5)
			and (Key != "Ent") and (Key != "Bone")
			and (ConstTable[ Key ]) and (ConstTable[ Key ] != false) then
				SaveableConst[ Key ] = ConstTable[ Key ]
			end
		end
		
	else
		table.Merge( SaveableConst, ConstraintEntity:GetTable() )
	end
	
	if ( ConstTable.Type == "Elastic" ) or ( ConstTable.length ) then
		SaveableConst.length = ConstTable.length
	end
	
	SaveableConst.Entity = {}
	local ents = {}
	
	if ( ConstTable[ "Ent" ] && ( ConstTable[ "Ent" ]:IsWorld() || ConstTable[ "Ent" ]:IsValid() ) ) then
		
		SaveableConst.Entity[ 1 ] = {}
		SaveableConst.Entity[ 1 ].Index	 	= ConstTable[ "Ent" ]:EntIndex()
		if ConstTable[ "Ent" ]:IsWorld() then SaveableConst.Entity[ 1 ].World = true end
		SaveableConst.Entity[ 1 ].Bone 		= ConstTable[ "Bone" ]
		
	else
		for i=1, 6 do
			local entn = "Ent"..i
			if ( ConstTable[ entn ] && ( ConstTable[ entn ]:IsWorld() || ConstTable[ entn ]:IsValid() ) ) then
				SaveableConst.Entity[ i ] = {}
				SaveableConst.Entity[ i ].Index	 	= ConstTable[ entn ]:EntIndex()
				SaveableConst.Entity[ i ].Bone 		= ConstTable[ "Bone"..i ]
				SaveableConst.Entity[ i ].WPos 		= ConstTable[ "WPos"..i ]
				SaveableConst.Entity[ i ].Length 	= ConstTable[ "Length"..i ]
				if ConstTable[ entn ]:IsWorld() then
					SaveableConst.Entity[ i ].World = true
					if ( ConstTable[ "LPos"..i ] ) then
						SaveableConst.Entity[ i ].LPos = ConstTable[ "LPos"..i ] - Offset
					else
						SaveableConst.Entity[ i ].LPos = Offset
					end
				else
					SaveableConst.Entity[ i ].LPos = ConstTable[ "LPos"..i ]
				end
				table.insert( ents, ConstTable[ entn ] )
			end
		end
	end
	
	return SaveableConst, ents
end


--
--	Custom GetAllConstrainedEntitiesAndConstraints
--	Built for speed and saveablity
--	Compatable in place of duplicator.GetAllConstrainedEntitiesAndConstraints
--	Do not steal
function AdvDupe.Copy( Ent, EntTable, ConstraintTable, Offset )
	if not IsValid(Ent) then
		return EntTable, ConstraintTable
	end

	if EntTable[ Ent:EntIndex() ] then
		return EntTable, ConstraintTable
	end

	if ( Ent:GetClass() == "prop_physics" and Ent:GetVar("IsPlug", nil) == 1 ) then
		return EntTable, ConstraintTable
	end

	-- Filter duplicator blocked entities out.
	--if Ent.DoNotDuplicate then return EntTable, ConstraintTable end

	EntTable[ Ent:EntIndex() ] = AdvDupe.GetSaveableEntity( Ent, Offset )
	if ( !constraint.HasConstraints( Ent ) ) then return EntTable, ConstraintTable end
	
	for key, ConstraintEntity in pairs( Ent.Constraints ) do
		if ( !ConstraintTable[ ConstraintEntity ] ) and ConstraintEntity.Type != "" then
			local ConstTable, ents = AdvDupe.GetSaveableConst( ConstraintEntity, Offset )
			ConstraintTable[ ConstraintEntity ] = ConstTable
			for k,e in pairs(ents or {}) do
				AdvDupe.Copy( e, EntTable, ConstraintTable, Offset )
			end
		end
	end
	
	return EntTable, ConstraintTable
end



--
--	Gets the entity's constraints and connected entities
--	Like GetAll, but only returns a table of fisrt level connects
--	Might be usefull for for something later
--
function AdvDupe.GetEntitysConstrainedEntitiesAndConstraints( ent )
	if not IsValid( Ent ) then return {},{} end

	-- Filter duplicator blocked entities out.
	if Ent.DoNotDuplicate then return {},{} end

	local Consts, Ents = {},{}
	Ents[ Ent:EntIndex()] = Ent
	if ( constraint.HasConstraints( Ent ) ) then
		for key, ConstraintEntity in pairs( Ent.Constraints ) do
			if ConstraintEntity.DoNotDuplicate then continue end
			local ConstTable = ConstraintEntity:GetTable()
			table.insert( Consts, ConstraintEntity )
			for i=1, 6 do
				local entn = "Ent"..i
				if ( ConstTable[ entn ] && ( ConstTable[ entn ]:IsWorld() || ConstTable[ entn ]:IsValid() ) ) then
					local ent = ConstTable[ entn ]
					if ent.DoNotDuplicate then continue end
					Ents[ ent:EntIndex() ] = ent
				end
			end
		end
	end
	return Ents, Consts
end

function AdvDupe.GetAllEnts( Ent, OrderedEntList, EntsTab, ConstsTab )
	if not IsValid( Ent ) then
		return OrderedEntList
	end

	if EntsTab[ Ent:EntIndex() ] then
		return OrderedEntList
	end

	-- Filter duplicator blocked entities out.
	if Ent.DoNotDuplicate then
		return OrderedEntList
	end
	
	EntsTab[ Ent:EntIndex() ] = Ent
	table.insert(OrderedEntList, Ent)
	if ( !constraint.HasConstraints( Ent ) ) then return OrderedEntList end
	for key, ConstraintEntity in pairs( Ent.Constraints ) do
		if ConstraintEntity.DoNotDuplicate then continue end
		if ( !ConstsTab[ ConstraintEntity ] ) then
			ConstsTab[ ConstraintEntity ] = true
			local ConstTable = ConstraintEntity:GetTable()
			for i=1, 6 do
				local e = ConstTable[ "Ent"..i ]
				AdvDupe.GetAllEnts( e, OrderedEntList, EntsTab, ConstsTab )
			end
		end
	end
	
	return OrderedEntList
end


--[[AdvDupe.NewSave = true
local function NewSaveSet(ply, cmd, args)
	if args[1] and args[1] == "1" or args[1] == 1 then
		AdvDupe.NewSave = true
	elseif args[1] and args[1] == "0" or args[1] == 0 then
		AdvDupe.NewSave = false
	end
	Msg("\AdvDupe_NewSave = "..tostring(AdvDupe.NewSave).."\n")
end
concommand.Add( "AdvDupe_NewSave", NewSaveSet )--]]


--
--	some modifer functions
--
local function CollisionGroupModifier(ply, Ent, group )
	
	if ( group == 19 or group == COLLISION_GROUP_WORLD ) then --COLLISION_GROUP_WORLD is fucked up
		Ent:SetCollisionGroup( COLLISION_GROUP_WORLD )
	else
		Ent:SetCollisionGroup( COLLISION_GROUP_NONE )
	end
	
end
duplicator.RegisterEntityModifier( "CollisionGroupMod", CollisionGroupModifier )

local function SetMassMod( Player, Entity, Data )
	if Data and Data.Mass and Data.Mass > 0 then
		Entity:GetPhysicsObject():SetMass(Data.Mass)
		duplicator.StoreEntityModifier( Entity, "MassMod", Data )
	end
	return true
end
duplicator.RegisterEntityModifier( "MassMod", SetMassMod )




if (dupeshare and dupeshare.PublicDirs) then
	AdvDupe.PublicDirs = {}
	for k, v in pairs(dupeshare.PublicDirs) do
		local dir = (dupeshare.BaseDir.."/"..v):lower()
		AdvDupe.PublicDirs[v] = dir
		if ( !file.Exists(dir, "DATA") ) or ( file.Exists(dir, "DATA") and !file.IsDir(dir, "DATA") ) then 
			file.CreateDir( dupeshare.ParsePath(dir), "DATA" )
		end
	end
end


function AdvDupe.GetPlayersFolder(ply)
	local dir = dupeshare.BaseDir
	
	if not game.SinglePlayer() then
		local name = dupeshare.ReplaceBadChar(tostring(ply:SteamID()))
		name = string.gsub(name, "STEAM_1", "STEAM_0") --I think this was needed cause Valve randomly changed everybody's IDs
		
		if (name == "STEAM_ID_LAN") or (name == "UNKNOWN") or (name == "STEAM_ID_PENDING") then
			name = dupeshare.GetPlayerName(ply) or "unknown"
		end
		
		dir = dir.."/"..name
	end
	
	return dir:lower()
end



function AdvDupe.MakeDir(ply, cmd, args)
	if !IsValid(ply) or !ply:IsPlayer() or !args[1] then return end
	
	local dir = AdvDupe[ply].cdir
	local foldername = dupeshare.ReplaceBadChar(string.Implode(" ", args))
	
	AdvDupe.FileOpts(ply, "makedir", foldername, dir)
	
	--[[local dir = AdvDupe[ply].cdir.."/"..dupeshare.ReplaceBadChar(args[1])
	
	if file.Exists(dir) and file.IsDir(dir) then 
		AdvDupe.SendClientError(ply, "Folder Already Exists!")
		return
	end
	
	file.CreateDir(dir)--]]
	
	if (dupeshare.UsePWSys) and (!game.SinglePlayer()) then
		--todo
	end
	
	--AdvDupe.UpdateList(ply)
	
end
concommand.Add("adv_duplicator_makedir", AdvDupe.MakeDir)

local function FileOptsCommand(ply, cmd, args)
	if !IsValid(ply) or !ply:IsPlayer() or !args[1] then return end
	
	local action = args[1]
	--local filename = dupeshare.GetFileFromFilename(ply:GetInfo( "adv_duplicator_load_filename" ))..".txt"
	local filename = ply:GetInfo( "adv_duplicator_load_filename" )
	--local filename2 = ply:GetInfo( "adv_duplicator_load_filename2" )
	local dir	= AdvDupe[ply].cdir
	local dir2	= AdvDupe[ply].cdir2
	
	AdvDupe.FileOpts(ply, action, filename, dir, dir2)
	
end
concommand.Add("adv_duplicator_fileopts", FileOptsCommand)

local function FileOptsRenameCommand(ply, cmd, args)
	--Msg("rename cmd\n")
	if !IsValid(ply) or !ply:IsPlayer() or !args[1] then return end
	
	--local filename = dupeshare.GetFileFromFilename(ply:GetInfo( "adv_duplicator_load_filename" ))..".txt"
	local filename = ply:GetInfo( "adv_duplicator_load_filename" )
	local dir	= AdvDupe[ply].cdir
	local newname = string.Implode(" ", args)
	newname = dupeshare.ReplaceBadChar(dupeshare.GetFileFromFilename(newname))..".txt"
	--MsgN("s-newname= ",newname)
	AdvDupe.FileOpts(ply, "rename", filename, dir, newname)
	
end
concommand.Add("adv_duplicator_fileoptsrename", FileOptsRenameCommand)

function AdvDupe.FileOpts(ply, action, filename, dir, dir2)
	if not filename or not dir then return end
	
	local file1 = (dir.."/"..filename):lower()
	--MsgN("action= ",action,"  filename= ",filename,"  dir= ",dir,"  dir2= ",(dir2 or "none"))
	
	if not AdvDupe.CheckPerms(ply, "", dir, "access") then 
		AdvDupe.SendClientError(ply, "You lack access permissions in "..dir)
		return 
	end
	
	if (action == "delete") then
		if not AdvDupe.CheckPerms(ply, "", dir, "delete") then 
			AdvDupe.SendClientError(ply, "You lack delete permissions in "..dir)
			return 
		end
		
		file.Delete(dupeshare.ParsePath(file1))
		AdvDupe.HideGhost(ply, false)
		AdvDupe.UpdateList(ply)
		
	elseif (action == "copy") then
		if not AdvDupe.CheckPerms(ply, "", dir2, "write") then 
			AdvDupe.SendClientError(ply, "You lack write permissions in "..dir2)
			return 
		end
		
		local file2 = (dir2.."/"..filename):lower()
		if file.Exists(file2, "DATA") then
			local filename2 = ""
			file2, filename2 = dupeshare.FileNoOverWriteCheck(dir2, filename)
			if dir == dir2 then
				AdvDupe.SendClientError(ply, "Destination Same as Source, Saved File as: "..filename2)
			else
				AdvDupe.SendClientError(ply, "File Exists at Destination, Saved File as: "..filename2)
			end
		end
		file.Write(dupeshare.ParsePath(file2), file.Read(dupeshare.ParsePath(file1), "DATA") or "")
		AdvDupe.UpdateList(ply)
		
	elseif (action == "move") then
		if not AdvDupe.CheckPerms(ply, "", dir, "delete") then 
			AdvDupe.SendClientError(ply, "You lack delete permissions in "..dir)
			return 
		end
		if not AdvDupe.CheckPerms(ply, "", dir2, "write") then 
			AdvDupe.SendClientError(ply, "You lack write permissions in "..dir2)
			return 
		end
		
		if dir == dir2 then
			AdvDupe.SendClientError(ply, "Cannot move file to same directory")
			return
		end
		
		AdvDupe.FileOpts(ply, "copy", filename, dir, dir2)
		AdvDupe.FileOpts(ply, "delete", filename, dir)
		
	elseif (action == "makedir") then
		if not AdvDupe.CheckPerms(ply, "", dir, "write") then 
			AdvDupe.SendClientError(ply, "You lack write permissions in "..dir)
			return 
		end
		
		if !game.SinglePlayer() and dupeshare.NamedLikeAPublicDir(filename) then
			AdvDupe.SendClientError(ply, "You Cannot Name a Folder Like a Public Folder")
			return
		end
		
		if file.Exists(file1, "DATA") and file.IsDir(file1, "DATA") then 
			AdvDupe.SendClientError(ply, "Folder Already Exists!")
			return
		end
		
		file.CreateDir(dupeshare.ParsePath(file1), "DATA")
		AdvDupe.HideGhost(ply, false)
		AdvDupe.UpdateList(ply)
		
	elseif (action == "rename") then
		if not (AdvDupe.CheckPerms(ply, "", dir, "delete") and AdvDupe.CheckPerms(ply, "", dir, "write")) then 
			AdvDupe.SendClientError(ply, "You lack delete permissions in "..dir)
			return 
		end
		
		AdvDupe.FileOpts(ply, "duplicate", filename, dir, dir2)
		AdvDupe.FileOpts(ply, "delete", filename, dir)
		
	elseif (action == "duplicate") then
		if not AdvDupe.CheckPerms(ply, "", dir, "write") then 
			AdvDupe.SendClientError(ply, "You lack delete permissions in "..dir)
			return 
		end
		
		local file2 = (dir.."/"..dir2):lower() --using dir2 to hold the new filename
		if file.Exists(file2, "DATA") then
			local filename2 = ""
			file2, filename2 = dupeshare.FileNoOverWriteCheck(dir, dir2)
			AdvDupe.SendClientError(ply, "File Exists With That Name Already, Renamed as: "..filename2)
		end
		file.Write(dupeshare.ParsePath(file2), file.Read(dupeshare.ParsePath(file1), "DATA") or "")
		AdvDupe.UpdateList(ply)
		
	else
		AdvDupe.SendClientError(ply, "FileOpts: Bad Action Command!")
	end
	
end

--TODO
function AdvDupe.CheckPerms(ply, dir, password, action)
	
	if (dupeshare.UsePWSys) and (!game.SinglePlayer()) then
		--todo
		return true
	else
		return true
	end
	
	AdvDupe.SendClientError(ply, "Permission error!")
end




--makes the player see an error
--todo: make enum error codes
function AdvDupe.SendClientError(ply, errormsg, NoSound)
	if ( !IsValid(ply) or !ply:IsPlayer() or !errormsg ) then return end
	MsgN("AdvDupe: Sending this ErrorMsg to ",tostring(ply),"\nAdvDupe-ERROR: \"",tostring(errormsg).."\"")
	umsg.Start("AdvDupeCLError", ply)
		umsg.String(errormsg)
		umsg.Bool(NoSound)
	umsg.End()
end
function AdvDupe.SendClientInfoMsg(ply, msg, NoSound)
	if ( !IsValid(ply) or !ply:IsPlayer() or !msg ) then return end
	MsgN("AdvDupe, Sending This InfoMsg to ",tostring(ply),"\nAdvDupe: \"",tostring(msg).."\"")
	umsg.Start("AdvDupeCLInfo", ply)
		umsg.String(msg)
		umsg.Bool(NoSound)
	umsg.End()
end

function AdvDupe.UpdateList(ply)
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	local tool = AdvDupe.GetAdvDupeToolObj(ply)
	if (tool) then
		tool:UpdateList()
	end
end

function AdvDupe.HideGhost(ply, Hide)
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	local tool = AdvDupe.GetAdvDupeToolObj(ply)
	if (tool) then
		tool:HideGhost(Hide)
	end
end
local function AdvDupe_HideGhost( ply, command, args )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if ( args[1] ) and  ( args[1] == "0" ) then
		AdvDupe.HideGhost(ply, false)
	elseif ( args[1] ) and  ( args[1] == "1" ) then
		AdvDupe.HideGhost(ply, true)
	end
end
concommand.Add( "adv_duplicator_hideghost", AdvDupe_HideGhost )

function AdvDupe.SetPasting(ply, Pasting)
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	AdvDupe[ply] = AdvDupe[ply] or {}
	AdvDupe[ply].Pasting = Pasting
	
	umsg.Start("AdvDupeSetPasting", ply)
		umsg.Bool(Pasting)
	umsg.End()
end

function AdvDupe.SetPercentText( ply, Txt )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	AdvDupe[ply] = AdvDupe[ply] or {}
	AdvDupe[ply].PercentText = Txt
	umsg.Start("AdvDupe_Start_Percent", ply)
		umsg.String(Txt)
	umsg.End()
end

function AdvDupe.SetPercent(ply, Percent)
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	umsg.Start("AdvDupe_Update_Percent", ply)
		umsg.Short(Percent)
	umsg.End()
end

function AdvDupe.GetAdvDupeToolObj(ply)
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	local tool = ply:GetActiveWeapon()
	if ( dupeshare.CurrentToolIsDuplicator(tool) ) then
		return tool:GetTable():GetToolObject()
	end
	return 
end



--
--	admin stuff: functions and vars
--	TODO: setting saving to file and maybe concommands
AdvDupe.AdminSettings = {}
--
--	==Defaults==
--	You can chage this values from lua now, but keep in mind that they're set this way for a reason
--	Sure, you can make upload go fast by making it send more, more often, but it will fucking fail most of the time
--	same for download, if you don't mind your server crashing
--	Only change this vars so it will go slower or to disable, otherwise you're going to break something or crash
--	I'll add limits if people break shit by fucking with this stuff too much.
--
--client upload settings
local MaxUploadLength = 180			--common to all players. it's the size of string in each piece, over 200 and it _WILL_ fail
local UploadPiecesPerSend = 3		--per player. number of pieces the player send per interval. over 5 and it _WILL_ fail
local UploadSendDelay = 0.15		--per player. seconds between each inverval. under 0.01 and there is no real difference. Don't set less than .1 and 2 above, it will fail a lot.
local MaxUploadSize = 0				--per player. -1 disable, 0 no limit, >0 K characers allowed (K = 1024).  allows up to (MaxUploadLength - 1) charcters over this limit.,
--download settings
local MaxDownloadLength = 200		--common to all players. same as above, but limit is _MAX_ 255, but it doesn't work well above 200
local DownloadPiecesPerSend = 3		--per player. same as above. set it to high and the server _WILL_ most likely crash
local DownloadSendInterval = 0.1	--per player. same as above. this should be the lowest you should use
local CanDownloadDefault = true		--per player. if you can't figure this out, i have a stick i can hit you with :V
--ghost settings	-- all per player
local LimitedGhost = false			--same as the panel option, just overrides that option with true
local GhostLimitNorm = 500			--max size of ghost. DON'T make it higher than this!!!!
local GhostLimitLimited = 50		--size of ghost when limiting is on. minimum is 1
local GhostAddDelay = .2			--delay between adding to the ghost when ghosting
local GhostsPerTick = 3				--ghost ents added per tick
--per player settings
local PlayerSettings = {}
--
--	admin setting function
--
--	uploads
local function SendUploadSettings( ply, pieces, delay )
	if ( ply ) and ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	umsg.Start( "AdvDupeUploadSettings", ply )
		umsg.Short( MaxUploadLength )
		umsg.Short( pieces )
		umsg.Short( delay * 100 )
	umsg.End()
end
local function SendMaxUploadSize( ply, Kchars )
	if ( ply ) and ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	umsg.Start( "AdvDupeMaxUploadSize", ply )
		umsg.Short( Kchars )
	umsg.End()
end
local function CanUpload( ply )
	if ( PlayerSettings[ply].MaxUploadSize >= 0 ) then return true end
end
local function GetMaxUpload( ply )
	return PlayerSettings[ply].MaxUploadSize * 1024
end
function AdvDupe.AdminSettings.DefaultUploadSettings( len, pieces, delay, Kchars, DontUpdatePl  )
	if not isnumber(len) or not isnumber(pieces) or not isnumber(delay) or isnumber(Kchars) then return end
	len = math.floor(len)
	pieces = math.floor(pieces)
	Kchars = math.floor(Kchars)
	if ( len >= 50 ) then MaxUploadLength = len end
	if ( pieces >= 1 ) then UploadPiecesPerSend = pieces end
	if ( delay >= 0.01 ) and ( delay <= 2 ) then UploadSendDelay = delay end
	if ( Kchars >= -1 ) then MaxUploadSize = Kchars end
	if ( !DontUpdatePl ) then
		for ply,v in pairs( PlayerSettings ) do
			PlayerSettings[ply].UploadPiecesPerSend = UploadPiecesPerSend
			PlayerSettings[ply].UploadSendDelay = UploadSendDelay
			PlayerSettings[ply].MaxUploadSize = MaxUploadSize
		end
		SendUploadSettings( nil, pieces, delay )
		SendMaxUploadSize( nil, Kchars )
	end
end
function AdvDupe.AdminSettings.UploadSettings( ply, pieces, delay, Kchars )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if not isnumber(pieces) or not isnumber(delay) or not isnumber(Kchars) then return end
	pieces = math.floor(pieces)
	if ( pieces >= 1 ) then PlayerSettings[ply].UploadPiecesPerSend = pieces end
	if ( delay >= 0.01 ) and ( delay <= 2 ) then PlayerSettings[ply].UploadSendDelay = delay end
	SendUploadSettings( ply, pieces, delay )
	if ( Kchars ) then AdvDupe.AdminSettings.MaxUploadSize( ply, Kchars ) end
end
function AdvDupe.AdminSettings.MaxUploadSize( ply, Kchars )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if not isnumber(Kchars) then return end
	Kchars = math.floor(Kchars)
	if ( Kchars >= -1 ) then
		PlayerSettings[ply].MaxUploadSize = Kchars
		SendMaxUploadSize( ply, Kchars )
	end
end
function AdvDupe.RecieveFileContentStart( ply, cmd, args )
	if not IsValid(ply) or not ply:IsAdmin() then return end
	 AdvDupe.AdminSettings.UploadSettings( ply, tonumber(args[1]), tonumber(args[2]), tonumber(args[3] or 0) )
end
concommand.Add("AdvDupe_UploadSettings", AdvDupe.RecieveFileContentStart)
--
--	downlaods
local function SendCanDownload( ply, candownload )
	if ( ply ) and ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	umsg.Start( "AdvDupeCanDownload", ply )
		umsg.Bool( candownload )
	umsg.End()
end
function AdvDupe.AdminSettings.DefaultDownloadSettings( len, pieces, delay, candownload, DontUpdatePl )
	if not isnumber(len) or not isnumber(pieces) or not isnumber(delay) then return end
	len = math.floor(len)
	pieces = math.floor(pieces)
	if ( len >= 50 ) then MaxDownloadLength = len end
	if ( pieces >= 1 ) then DownloadPiecesPerSend = pieces end
	if ( delay >= 0.01 ) and ( delay <= 2 ) then DownloadSendInterval = delay end
	if ( candownload ) then CanDownload = true else CanDownload = false end
	if ( !DontUpdatePl ) then
		for ply,v in pairs( PlayerSettings ) do
			PlayerSettings[ply].DownloadPiecesPerSend = DownloadPiecesPerSend
			PlayerSettings[ply].DownloadSendInterval = DownloadSendInterval
			PlayerSettings[ply].CanDownload = CanDownload
		end
	end
end
function AdvDupe.AdminSettings.DownloadSettings( ply, pieces, delay, candownload )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if not isnumber(pieces) or not isnumber(delay) then return end
	pieces = math.floor(pieces)
	if ( pieces >= 1 ) then PlayerSettings[ply].DownloadPiecesPerSend = pieces end
	if ( delay >= 0.01 ) and ( delay <= 2 ) then PlayerSettings[ply].DownloadSendInterval = delay end
	if ( candownload != nil ) then AdvDupe.AdminSettings.SetCanDownload( ply, candownload ) end
end
function AdvDupe.AdminSettings.SetCanDownload( ply, candownload )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if ( candownload ) then PlayerSettings[ply].CanDownload = true
	else PlayerSettings[ply].CanDownload = false end
	SendCanDownload( ply, PlayerSettings[ply].CanDownload )
end
local function CanDownload( ply )
	return PlayerSettings[ply].CanDownload
end
--
--	ghost
function AdvDupe.LimitedGhost( ply )
	return PlayerSettings[ply].LimitedGhost
end
function AdvDupe.GhostLimitNorm( ply )
	return PlayerSettings[ply].GhostLimitNorm
end
function AdvDupe.GhostLimitLimited( ply )
	return PlayerSettings[ply].GhostLimitLimited
end
function AdvDupe.GhostAddDelay( ply )
	return PlayerSettings[ply].GhostAddDelay
end
function AdvDupe.GhostsPerTick( ply )
	return PlayerSettings[ply].GhostsPerTick
end
function AdvDupe.AdminSettings.DefaultGhostSettings( normsize, limitsize, delay, num, limited, DontUpdatePl )
	if not isnumber(normsize) or not isnumber(limitsize) or not isnumber(delay) or not isnumber(num) then return end
	normsize = math.floor(normsize)
	limitsize = math.floor(limitsize)
	num = math.floor(num)
	if ( normsize > 0 ) then GhostLimitNorm = normsize end
	if ( limitsize > 0 ) then GhostLimitLimited = limitsize end
	if ( delay >= 0.01 ) and ( delay <= 1 ) then GhostAddDelay = delay end
	if ( num > 0 ) then GhostsPerTick = num end
	if ( limited ) then LimitedGhost = true else LimitedGhost = false end
	if ( !DontUpdatePl ) then
		for ply,v in pairs( PlayerSettings ) do
			PlayerSettings[ply].GhostLimitNorm = GhostLimitNorm
			PlayerSettings[ply].GhostLimitLimited = GhostLimitLimited
			PlayerSettings[ply].GhostAddDelay = GhostAddDelay
			PlayerSettings[ply].LimitedGhost = LimitedGhost
			PlayerSettings[ply].GhostsPerTick = GhostsPerTick
		end
	end
end
function AdvDupe.AdminSettings.GhostSettings( ply, normsize, limitsize, delay, num, limited )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if not isnumber(normsize) or not isnumber(limitsize) or not isnumber(delay) or not isnumber(num) then return end
	normsize = math.floor(normsize)
	limitsize = math.floor(limitsize)
	num = math.floor(num)
	if ( normsize > 0 ) then PlayerSettings[ply].GhostLimitNorm = normsize end
	if ( limitsize > 0 ) then PlayerSettings[ply].GhostLimitLimited = limitsize end
	if ( delay >= 0.01 ) and ( delay <= 1 ) then PlayerSettings[ply].GhostAddDelay = delay end
	if ( num > 0 ) then PlayerSettings[ply].GhostsPerTick = num end
	if ( limited != nil ) then AdvDupe.AdminSettings.SetLimitedGhost( ply, limited ) end
end
function AdvDupe.AdminSettings.SetLimitedGhost( ply, limited )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	if ( limited ) then PlayerSettings[ply].LimitedGhost = true
	else PlayerSettings[ply].LimitedGhost = false end
end


--	set defaults for player on join
function AdvDupe.AdminSettings.SetPlayerToDefault( ply )
	if ( !IsValid(ply) or !ply:IsPlayer() ) then return end
	PlayerSettings[ply] = {}
	
	--upload
	--[[PlayerSettings[ply].UploadPiecesPerSend = UploadPiecesPerSend
	PlayerSettings[ply].UploadSendDelay = UploadSendDelay
	PlayerSettings[ply].MaxUploadSize = MaxUploadSize--]]
	AdvDupe.AdminSettings.UploadSettings( ply, UploadPiecesPerSend, UploadSendDelay, MaxUploadSize )
	
	--download
	--[[PlayerSettings[ply].DownloadPiecesPerSend = DownloadPiecesPerSend
	PlayerSettings[ply].DownloadSendInterval = DownloadSendInterval
	PlayerSettings[ply].CanDownload = CanDownload--]]
	AdvDupe.AdminSettings.DownloadSettings( ply, DownloadPiecesPerSend, DownloadSendInterval, CanDownload )
	
	--ghost
	--[[PlayerSettings[ply].LimitedGhost = LimitedGhost
	PlayerSettings[ply].GhostLimitNorm = GhostLimitNorm
	PlayerSettings[ply].GhostLimitLimited = GhostLimitLimited--]]
	AdvDupe.AdminSettings.GhostSettings( ply, GhostLimitNorm, GhostLimitLimited, GhostAddDelay, GhostsPerTick, LimitedGhost )
	
	--PrintTable(PlayerSettings[ply])
	
	--update client side vars too
	--[[SendUploadSettings( ply, UploadPiecesPerSend, UploadSendDelay )
	SendMaxUploadSize( ply, MaxUploadSize )
	SendCanDownload( ply, CanDownload )--]]
end
hook.Add( "PlayerInitialSpawn", "AdvDupePlayerJoinSettings", AdvDupe.AdminSettings.SetPlayerToDefault )




--
--	Upload: Recieves file from client
--
util.AddNetworkString("AdvDupeUploadOK")
util.AddNetworkString("AdvDupeUploadStart")
util.AddNetworkString("AdvDupeUploadData")
net.Receive("AdvDupeUploadStart", function(netlen, ply)
	if not ply:IsValid() then return end
	if not CanUpload( ply ) then
		MsgN("player ",tostring(ply)," not allowed to upload")
		return
	end
	
	if not AdvDupe[ply] then AdvDupe[ply] = {} end
	AdvDupe[ply].uploadLast = net.ReadUInt(16)
	if ( GetMaxUpload(ply) > 0 and (AdvDupe[ply].uploadLast - 1) * 64000 > GetMaxUpload(ply) ) then
		MsgN("player ",tostring(ply)," is trying to upload over ",(AdvDupe[ply].uploadLast - 1) * 64000," the limit is ",GetMaxUpload(ply))
		SendMaxUploadSize( ply ) --tell the player what the max is
		net.Start("AdvDupeUploadOK") net.WriteBit(false) net.Send(ply)
		return
	end
	
	AdvDupe[ply].uploadFilename = net.ReadString()
	AdvDupe[ply].uploadBuffer = ""
	AdvDupe[ply].uploadDir = AdvDupe[ply].cdir
	
	net.Start("AdvDupeUploadOK") net.WriteBit(true) net.Send(ply)
end)

net.Receive("AdvDupeUploadData", function(netlen, ply)
	if not ply:IsValid() or not AdvDupe[ply].uploadBuffer then return end
	
	local datalen = net.ReadUInt(16)
	AdvDupe[ply].uploadBuffer = AdvDupe[ply].uploadBuffer .. net.ReadData(datalen)
	
	if net.ReadBit() != 0 then
		local filepath = dupeshare.FileNoOverWriteCheck( AdvDupe[ply].uploadDir, AdvDupe[ply].uploadFilename )
		AdvDupe.RecieveFileContentSave( ply, filepath )
	end
end)

function AdvDupe.RecieveFileContentSave( ply, filepath )
	if not ply:IsValid() or not AdvDupe[ply].uploadBuffer then return end
	
	local uploaded = util.Decompress(AdvDupe[ply].uploadBuffer)
	local FileName = dupeshare.GetFileFromFilename( filepath )
	
	if not uploaded then
		AdvDupe.SendClientError(ply, "ERROR: '"..FileName.."', failed uploading", true)
		AdvDupe.SendClientInfoMsg(ply, "Try resending it.", true)
		
		ply:PrintMessage(HUD_PRINTCONSOLE, "AdvDupeERROR: Your file, '"..FileName.."', was not recieved properly")
		MsgN("AdvDupe: This file, '",filepath,"', was not recieved properly")
	else
	
		file.Write(dupeshare.ParsePath(filepath), uploaded)
		AdvDupe[ply].uploadBuffer = nil
		
		AdvDupe.SendClientInfoMsg(ply, "Your file: '"..FileName.."' was uploaded to the server")
		ply:PrintMessage(HUD_PRINTCONSOLE, "Your file: '"..FileName.."' was uploaded to the server")
		
		AdvDupe.UpdateList(ply)
	end
	net.Start("AdvDupeUploadOK") net.WriteBit(false) net.Send(ply)
end




--
--	Download: Sends a file to the client
--
util.AddNetworkString("AdvDupeDownloadStart")
util.AddNetworkString("AdvDupeDownloadData")
AdvDupe.SendBuffer = {}
function AdvDupe.SendSaveToClient( ply, filename )
	if ( !CanDownload( ply ) ) then return end
	if (!AdvDupe[ply]) then AdvDupe[ply] = {} end
	if (AdvDupe.SendBuffer[ply]) then return end --then were sending already and give up
	
	local filepath = filename
	local dir = "adv_duplicator"
	local ndir = dir.."/"..dupeshare.GetPlayerName(ply)
	
	if !file.Exists(filepath, "DATA") then --if filepath was just a file name then try to find the file, for sending from list
		if !file.Exists(dir.."/"..filename, "DATA") && !file.Exists(ndir.."/"..filename, "DATA") then
			--MsgN("AdvDupe: File not found: \"",filepath,"\"")
			return
		end
		if ( file.Exists(ndir.."/"..filename, "DATA") ) then filepath = ndir.."/"..filename end
		if ( file.Exists(dir.."/"..filename, "DATA") ) then filepath = dir.."/"..filename end
	end
	
	filename = dupeshare.GetFileFromFilename(filepath)
	
	local f, temp = file.Open(dupeshare.ParsePath(filepath), "r", "DATA"), ""
	if f then
		temp = f:Read( f:Size() )
		f:Close()
	end
	AdvDupe.SendBuffer[ply] = util.Compress(temp)
	
	-- Consider compression
	
	local last = math.ceil(#AdvDupe.SendBuffer[ply] / 64000)
	
	net.Start("AdvDupeDownloadStart")
		net.WriteUInt(last,16)
		net.WriteString(filename)
	net.Send(ply)
	
	AdvDupe.SendSaveToClientData( ply, 1, last )
end

function AdvDupe.SendSaveToClientData(ply, offset, last)
	if not IsValid(ply) or not AdvDupe.SendBuffer[ply] then return end
		
	local SubStrStart = (offset - 1) * 64000
	net.Start("AdvDupeDownloadData")
		local towrite = AdvDupe.SendBuffer[ply]:sub( SubStrStart, SubStrStart + 64000 - 1 )
		net.WriteUInt(#towrite, 16)
		net.WriteData(towrite, #towrite)
		offset = offset + 1
		if offset <= last then
			net.WriteBit(false) -- Not last chunk
			timer.Create( "AdvDupe.SendSaveToClientData_"..ply:UniqueID(), 0.5, 1, function()
				AdvDupe.SendSaveToClientData( ply, offset, last ) 
			end)
		else
			net.WriteBit(true) -- This is the last chunk
			AdvDupe.SendBuffer[ply] = nil --clear this to send again
		end
	net.Send(ply)
end




--	======================
--	AdvDupePaste Functions
--	======================
--
--	Settings and vars
local UseTimedPasteThreshold = 100
local PasteEntsPerTick = 2
local PostEntityPastePerTick = 20
local PasteConstsPerTick = 5
local DelayAfterPaste = 2
if ( game.SinglePlayer() ) then --go faster in single players
	UseTimedPasteThreshold = 500
	PasteEntsPerTick = 4
	PostEntityPastePerTick = 40
	PasteConstsPerTick = 20
	DelayAfterPaste = .25
end

local PasterInstantPasteThreshold = 50
local PasterClearToPasteDelay = 3
function AdvDupe.GetPasterClearToPasteDelay()
	return PasterClearToPasteDelay
end

local DoPasteFX = false
local UseTaskSwitchingPaste = false
local DebugWeldsByDrawingThem = false
local DontAllowPlayersAdminOnlyEnts = true


--
--	Admin functions
--

--	only one of thise you need to worry about too much is SetUseTimedPasteThreshold, sets the number of ents+consts to triger using the paste over time instead
--	leave SetPostEntityPastePerTick at the default, it doesn't do much outside of wire and life support
local function SetTimedPasteVars(ply, cmd, args)
	if ( args[1] ) and ( ( ply:IsAdmin() ) or ( ply:IsSuperAdmin( )() ) ) then
		if args[1] then 
			UseTimedPasteThreshold = tonumber( args[1] )
		end
		if args[2] then
			PasteEntsPerTick = tonumber( args[2] )
		end
		if args[3] then
			PostEntityPastePerTick = tonumber( args[3] )
		end
		if args[4] then
			PasteConstsPerTick = tonumber( args[4] )
		end
		ply:PrintMessage(HUD_PRINTCONSOLE, "\nAdvDupe_SetTimedPasteVars:\n\tUseTimedPasteThreshold = "..UseTimedPasteThreshold.."\n\tPasteEntsPerTick = "..PasteEntsPerTick.."\n\tPostEntityPastePerTick = "..PostEntityPastePerTick.."\n\tPasteConstsPerTick = "..PasteConstsPerTick.."\nDefault: 100, 2, 20, 10\n")
	else
		ply:PrintMessage(HUD_PRINTCONSOLE, "Usage: \n  AdvDupe_SetTimedPasteVars <UseTimedPasteThreshold> [PasteEntsPerTick] [PostEntityPastePerTick] [PasteConstsPerTick]\nDefault: 100, 2, 20, 10\n")
	end
end
concommand.Add( "AdvDupe_SetTimedPasteVars", SetTimedPasteVars )
function AdvDupe.AdminSettings.SetTimedPasteVars( a, b, c, d )
	if isnumber(a) then UseTimedPasteThreshold = a end
	if isnumber(b) then PasteEntsPerTick = b end
	if isnumber(c) then PostEntityPastePerTick = c end
	if isnumber(d) then PasteConstsPerTick = d end
end
function AdvDupe.AdminSettings.SetUseTimedPasteThreshold( a ) if isnumber(a) then UseTimedPasteThreshold = a end end
function AdvDupe.AdminSettings.SetPasteEntsPerTick( a ) if isnumber(a) then PasteEntsPerTick = a end end
function AdvDupe.AdminSettings.SetPostEntityPastePerTick( a ) if isnumber(a) then PostEntityPastePerTick = a end end
function AdvDupe.AdminSettings.SetPasteConstsPerTick( a ) if isnumber(a) then PasteConstsPerTick = a end end

--PasterInstantPasteThreshold
local function SetPasterInstantPasteThreshold(ply, cmd, args)
	if ( args[1] ) and ( ( ply:IsAdmin() ) or ( ply:IsSuperAdmin( )() ) ) then
		PasterInstantPasteThreshold = tonumber( args[1] )
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "\nPasterInstantPasteThreshold = "..PasterInstantPasteThreshold.." (Default: 50)\n")
end
concommand.Add( "AdvDupe_SetPasterInstantPasteThreshold", SetPasterInstantPasteThreshold )
function AdvDupe.AdminSettings.SetPasterInstantPasteThreshold( a ) if isnumber(a) then PasterInstantPasteThreshold = a end end

--PasterClearToPasteDelay
local function SetPasterClearToPasteDelay(ply, cmd, args)
	if ( args[1] ) and ( ( ply:IsAdmin() ) or ( ply:IsSuperAdmin( )() ) ) then
		PasterClearToPasteDelay = tonumber( args[1] )
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "\nPasterClearToPasteDelay = "..PasterClearToPasteDelay.." (Default: 3)\n")
end
concommand.Add( "AdvDupe_SetPasterClearToPasteDelay", SetPasterClearToPasteDelay )
function AdvDupe.AdminSettings.SetPasterClearToPasteDelay( a ) if isnumber(a) then PasterClearToPasteDelay = a end end


--	TaskSwitchingPaste makes the paste system built on each thinger by switching to the next one each tick instead of finishing the first placed one first
local function SetUseTaskSwitchingPaste(ply, cmd, args)
	if ( !ply:IsAdmin() and !ply:IsSuperAdmin( )() ) then return end
	if ( args[1] ) then
		if args[1] == "1" or args[1] == 1 then 
			UseTaskSwitchingPaste = true
		elseif args[1] == "0" or args[1] == 0 then
			UseTaskSwitchingPaste = false
		else
			ply:PrintMessage(HUD_PRINTCONSOLE, "Only takes 0 or 1")
		end
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "\n  AdvDupe_UseTaskSwitchingPaste = "..tostring(UseTaskSwitchingPaste).."  ( norm: False(0) )\n")
end
concommand.Add( "AdvDupe_UseTaskSwitchingPaste", SetUseTaskSwitchingPaste )
function AdvDupe.AdminSettings.SetUseTaskSwitchingPaste( a )
	if ( a ) then
		UseTaskSwitchingPaste = true
	else
		UseTaskSwitchingPaste = false
	end
end

--	DoPasteFX turns back on the cool pasting effects. works best when paste over time is slowed down a bit
local function SetDoPasteFX(ply, cmd, args)
	if ( !ply:IsAdmin() and !ply:IsSuperAdmin( )() ) then return end
	if ( args[1] ) then
		if args[1] == "1" or args[1] == 1 then 
			DoPasteFX = true
		elseif args[1] == "0" or args[1] == 0 then
			DoPasteFX = false
		else
			ply:PrintMessage(HUD_PRINTCONSOLE, "Only takes 0 or 1")
		end
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "\n  AdvDupe_DoPasteFX = "..tostring(DoPasteFX).."  ( norm: False(0) )\n")
end
concommand.Add( "AdvDupe_DoPasteFX", SetDoPasteFX )
function AdvDupe.AdminSettings.SetDoPasteFX( a )
	if ( a ) then
		DoPasteFX = true
	else
		DoPasteFX = false
	end
end

--	DebugWeldsByDrawingThem makes a beam where ever there a weld is made
local function SetDebugWeldsByDrawingThem(ply, cmd, args)
	if ( !ply:IsAdmin() and !ply:IsSuperAdmin( )() ) then return end
	if ( args[1] ) then
		if args[1] == "1" or args[1] == 1 then 
			DebugWeldsByDrawingThem = true
		elseif args[1] == "0" or args[1] == 0 then
			DebugWeldsByDrawingThem = false
		else
			ply:PrintMessage(HUD_PRINTCONSOLE, "Only takes 0 or 1")
		end
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "\n  AdvDupe_DebugWeldsByDrawingThem = "..tostring(DebugWeldsByDrawingThem).."  ( norm: False(0) )\n")
end
concommand.Add( "AdvDupe_DebugWeldsByDrawingThem", SetDebugWeldsByDrawingThem )
function AdvDupe.AdminSettings.SetDebugWeldsByDrawingThem( a )
	if ( a ) then
		DebugWeldsByDrawingThem = true
	else
		DebugWeldsByDrawingThem = false
	end
end

--	DontAllowPlayersAdminOnlyEnts, allows you to turn off the admin only ents protection
local function SetDontAllowPlayersAdminOnlyEnts(ply, cmd, args)
	if ( !ply:IsAdmin() and !ply:IsSuperAdmin( )() ) then return end
	if ( args[1] ) then
		if args[1] == "1" or args[1] == 1 then 
			DontAllowPlayersAdminOnlyEnts = true
		elseif args[1] == "0" or args[1] == 0 then
			DontAllowPlayersAdminOnlyEnts = false
		else
			ply:PrintMessage(HUD_PRINTCONSOLE, "Only takes 0 or 1")
		end
	end
	ply:PrintMessage(HUD_PRINTCONSOLE, "\n  AdvDupe_DontAllowPlayersAdminOnlyEnts = "..tostring(DontAllowPlayersAdminOnlyEnts).."  ( norm: True(1) )\n")
end
concommand.Add( "AdvDupe_DontAllowPlayersAdminOnlyEnts", SetDontAllowPlayersAdminOnlyEnts )
function AdvDupe.AdminSettings.SetDontAllowPlayersAdminOnlyEnts( a )
	if ( a ) then
		DontAllowPlayersAdminOnlyEnts = true
	else
		DontAllowPlayersAdminOnlyEnts = false
	end
end

--	ChangeDisallowedClass, add/remove classes from the disallowed list
local DisallowedClasses = {}
function AdvDupe.AdminSettings.ChangeDisallowedClass( ClassName, DisallowPlayers, DisallowAdminsToo )
	if (!DisallowPlayers) then DisallowedClasses[ClassName] = nil
	elseif (DisallowAdminsToo) then DisallowedClasses[ClassName] = 2
	else DisallowedClasses[ClassName] = 1 end
end
AdvDupe.AdminSettings.ChangeDisallowedClass( "sky_camera", true, true )


--	=============
--	AdvDupeThink
--	=============
--	Paste Duplication Managment
--	Special Timer Control
local TimedPasteDataNum = 0
local TimedPasteDataCurrent = 1
local TimedPasteData = {}
local NextPasteTime = 0
--local NumPastePartCallInRun = 0
local LastDelay = 0
local Timers = {}
local function AdvDupeThink()
	
	if (CurTime() >= NextPasteTime) then
		NextPasteTime = CurTime() +  .08
		if TimedPasteData[TimedPasteDataCurrent] then
			if ( !TimedPasteData[TimedPasteDataCurrent].Shooting_Ent )
			or ( !IsValid(TimedPasteData[TimedPasteDataCurrent].Shooting_Ent.Entity) ) then
				for k, ent in pairs( TimedPasteData[TimedPasteDataCurrent].CreatedEntities ) do
					if IsValid(ent) then
						ent:Remove()
					end
				end

				AdvDupe.FinishPasting( TimedPasteData,TimedPasteDataCurrent )
				--table.remove(TimedPasteData,TimedPasteDataCurrent)
				NextPasteTime = CurTime() +  .08
			else
				if ( TimedPasteData[TimedPasteDataCurrent].NormPaste ) and ( TimedPasteData[TimedPasteDataCurrent].Delay < CurTime() ) then
					
					local NoFail, Result = xpcall( AdvDupe.NormPasteFromTable, debug.traceback, TimedPasteData[TimedPasteDataCurrent] )
					if ( !NoFail ) then
						MsgN("AdvDupeERROR: NormPaste Failed, Error: ",tostring(Result))
					end
					
					AdvDupe.FinishPasting( TimedPasteData, TimedPasteDataCurrent )
					
					NextPasteTime = CurTime() + DelayAfterPaste
					
				elseif ( TimedPasteData[TimedPasteDataCurrent].Delay < CurTime() ) then
					
					local NoFail, Result = xpcall( AdvDupe.OverTimePasteProcessFromTable, debug.traceback )
					if ( !NoFail ) then
						MsgN("AdvDupeERROR: OverTimePaste Failed in stage ",(TimedPasteData[TimedPasteDataCurrent].Stage or "BadStage"),", Error: ",tostring(Result))
						TimedPasteData[TimedPasteDataCurrent].Stage = 5
					end
					
					TimedPasteData[TimedPasteDataCurrent].CallsInRun = TimedPasteData[TimedPasteDataCurrent].CallsInRun + 1
					
					if ( TimedPasteData[TimedPasteDataCurrent].Stage ) and ( TimedPasteData[TimedPasteDataCurrent].Stage == 5 ) then
						
						--Msg("==TotalTicks= "..TimedPasteData[TimedPasteDataCurrent].TotalTicks.."\n")
						--Msg("==CallsInRun = "..TimedPasteData[TimedPasteDataCurrent].CallsInRun.."\n")
						--Msg("==LastDelay = "..LastDelay.."\n")
						
						AdvDupe.FinishPasting( TimedPasteData,TimedPasteDataCurrent )
						
						NextPasteTime = CurTime() +  DelayAfterPaste
						
					else
						
						if ( !TimedPasteData[TimedPasteDataCurrent].DontRemoveThinger ) then
							AdvDupe.SetPercent(TimedPasteData[TimedPasteDataCurrent].Player, 
								(TimedPasteData[TimedPasteDataCurrent].CallsInRun / TimedPasteData[TimedPasteDataCurrent].TotalTicks) * 100)
						end
						
						LastDelay = .08 + .01 * TimedPasteData[TimedPasteDataCurrent].CallsInRun / 20
						
						NextPasteTime = CurTime() + LastDelay
						
					end
					
				end
				
				--task switching mode
				if ( UseTaskSwitchingPaste) and ( TimedPasteData[TimedPasteDataCurrent + 1] ) then
					TimedPasteDataCurrent = TimedPasteDataCurrent + 1
				elseif ( UseTaskSwitchingPaste ) then
					TimedPasteDataCurrent = 1
				end
				
			end
		elseif TimedPasteDataCurrent != 1 then
			TimedPasteDataCurrent = 1
		end
	end
	
	-- Run Special Timers
	for key, value in pairs( Timers ) do
		if ( value.Finish <= CurTime() ) then
			local b, e = xpcall( value.Func, debug.traceback, unpack( value.FuncArgs ) )
			if ( !b ) then
				MsgN("AdvDupe Timer Error: ",tostring(e))
				if ( value.OnFailFunc ) then
					local b, e = xpcall( value.OnFailFunc, debug.traceback, unpack( value.OnFailArgs ) )
					if ( !b ) then
						MsgN("AdvDupe Timer Error: OnFailFunc Error: ",tostring(e))
					end
				end
			end
			Timers[ key ] = nil
		end
	end
	
end
hook.Add("Think", "AdvDupe_Think", AdvDupeThink)

--	ReAddAdvDupeThink readds the hook when it dies, this is done automaticly when a new paste is started
local function ReAddAdvDupeThink( ply, cmd, args )
	hook.Add("Think", "AdvDupe_Think", AdvDupeThink)
	ply:PrintMessage(HUD_PRINTCONSOLE, "ReAdded AdvDupe_Think Hook\n")
end 
concommand.Add( "AdvDupe_ReAdd_Think", ReAddAdvDupeThink ) 
--	RestartAdvDupeThink clears all current pasting and restarts the hook, good to clear a paste that keeps bailing the hook each time it tries to run
local function RestartAdvDupeThink( ply, cmd, args )
	if ( !ply:IsAdmin() and !ply:IsSuperAdmin( )() ) then return end
	hook.Remove("Think", "AdvDupe_Think", AdvDupeThink)
	TimedPasteDataNum = 0
	TimedPasteDataCurrent = 1
	NextPasteTime = 0
	
	for n,d in pairs(TimedPasteData) do
		if ( d.Shooting_Ent ) and IsValid( d.Shooting_Ent.Entity ) then
			d.Shooting_Ent.Entity:Remove()
		end
		d = nil
	end
	TimedPasteData = {}
	
	hook.Add("Think", "AdvDupe_Think", AdvDupeThink)
	
	ply:PrintMessage(HUD_PRINTCONSOLE, "Restarted AdvDupe_Think Hook\n")
end 
concommand.Add( "AdvDupe_Restart_Think", RestartAdvDupeThink ) 



function AdvDupe.MakeTimer( Delay, Func, FuncArgs, OnFailFunc, OnFailArgs )
	if ( !Delay or !Func ) then Msg("AdvDupe.MakeTimer: Missings arg\n"); return end
	
	FuncArgs = FuncArgs or {}
	OnFailArgs = OnFailArgs or {}
	
	local timer			= {}
	timer.Finish		= CurTime() + Delay --UnPredictedCurTime()
	timer.Func			= Func
	timer.FuncArgs		= FuncArgs
	timer.OnFailFunc	= OnFailFunc
	timer.OnFailArgs	= OnFailArgs
	
	table.insert( Timers, timer )
	
	hook.Add("Think", "AdvDupe_Think", AdvDupeThink)
	
	return true;
	
end




local function MakeThinger(Player, Hide)
	
	local Shooting_Ent = ents.Create( "base_gmodentity" )
		Shooting_Ent:SetModel( "models/props_lab/labpart.mdl" )
		Shooting_Ent:SetAngles( Player:GetAimVector():Angle() )
		Shooting_Ent:SetPos( Player:GetShootPos() + (Player:GetAimVector( ) * 24) - Vector(0,0,20) )
		Shooting_Ent:SetNotSolid(true)
	Shooting_Ent:Spawn()
	if IsValid( Shooting_Ent:GetPhysicsObject() ) then
		Shooting_Ent:GetPhysicsObject():EnableMotion(false)
	end
	Shooting_Ent:Activate()
	Shooting_Ent:SetNoDraw(Hide)
	Shooting_Ent:SetOverlayText("AdvDupe Paster")
	--DoPropSpawnedEffect( Shooting_Ent )
	Player:AddCleanup( "duplicates", Shooting_Ent )
	undo.Create( "AdvDupe (pasting...)" )
		undo.SetCustomUndoText("Undone AdvDupe")
		undo.AddEntity( Shooting_Ent )
		undo.SetPlayer( Player )
	undo.Finish()
	
	return Shooting_Ent
end

local function TingerFX( Shooting_Ent, HitPos )
	if (!Shooting_Ent) or !IsValid(Shooting_Ent.Entity) then return end
	local effectdata = EffectData()
		effectdata:SetOrigin( HitPos )
		effectdata:SetStart( Shooting_Ent.Entity:GetPos() )
	util.Effect( "PasteBeam", effectdata )
end


function AdvDupe.StartPaste( Player, inEntityList, inConstraintList, HeadEntityIdx, HitPos, HoldAngle, NumOfEnts, NumOfConst, PasteFrozen, PastewoConst, CallOnPasteFin, DontRemoveThinger, Thinger, FromPaster )
	hook.Add("Think", "AdvDupe_Think", AdvDupeThink)
	hook.Run("AdvDupe_StartPasting", Player, NumOfEnts)
	
	if ( FromPaster ) and ( NumOfEnts + NumOfConst > PasterInstantPasteThreshold ) then
		local CreatedEntities, CreatedConstraints = {},{}
		AdvDupe.NormPaste( Player, inEntityList, inConstraintList, HeadEntityIdx, HitPos, HoldAngle, Thinger, PasteFrozen, PastewoConst, CreatedEntities, CreatedConstraints )
		CallOnPasteFin( Thinger, CreatedEntities, CreatedConstraints )
	elseif ( NumOfEnts + NumOfConst > UseTimedPasteThreshold) then
		--Msg("===adding new timed paste===\n")
		AdvDupe.OverTimePasteStart( Player, inEntityList, inConstraintList, HeadEntityIdx, HitPos, HoldAngle, NumOfEnts, NumOfConst, PasteFrozen, PastewoConst, CallOnPasteFin, DontRemoveThinger, Thinger )
	else
		--Msg("===adding new delayed paste===\n")
		AdvDupe.AddDelayedPaste( Player, inEntityList, inConstraintList, HeadEntityIdx, HitPos, HoldAngle, false, PasteFrozen, PastewoConst, CallOnPasteFin, DontRemoveThinger, Thinger )
	end
end



--
--	Normal instant paste
--
function AdvDupe.AddDelayedPaste( Player, EntityList, ConstraintList, HeadEntityIdx, HitPos, HoldAngle, HideThinger, PasteFrozen, PastewoConst, CallOnPasteFin, DontRemoveThinger, Thinger )
	T = {
		Player            = Player,
		EntityList        = EntityList,
		ConstraintList    = ConstraintList,
		HeadEntityIdx     = HeadEntityIdx,
		HitPos            = HitPos,
		HoldAngle         = HoldAngle,
		Shooting_Ent      = Thinger,
		DontRemoveThinger = DontRemoveThinger,
		NormPaste         = true,
		Delay             = CurTime() + .2,
		PasteFrozen       = PasteFrozen,
		PastewoConst      = PastewoConst,
		CallOnPasteFin    = CallOnPasteFin,
		CreatedEntities   = {
			EntityList = EntityList,
		},
		CreatedConstraints = {},
	}
	
	if not IsValid(Thinger) then
		T.Shooting_Ent      = MakeThinger(Player, HideThinger)
		T.DontRemoveThinger = nil
	end
	
	table.insert(TimedPasteData, T)
	
end

function AdvDupe.NormPasteFromTable( PasteData )
	AdvDupe.NormPaste( PasteData.Player, PasteData.EntityList, PasteData.ConstraintList, 
		PasteData.HeadEntityIdx, PasteData.HitPos, PasteData.HoldAngle, PasteData.Shooting_Ent,
		PasteData.PasteFrozen, PasteData.PastewoConst, PasteData.CreatedEntities, PasteData.CreatedConstraints)
end

function AdvDupe.GetUndoDescription(Player)
	local gmod_tool = Player:GetWeapon("gmod_tool")
	if not gmod_tool:IsValid() then return "AdvDupe" end
	
	local self = gmod_tool.Tool.adv_duplicator
	if not self.Info then return "AdvDupe" end
	
	local path = self.Info.FilePath
	if not path then return "AdvDupe" end
	
	path = path:match("([^/\\]*)%.txt$")
	if not path then return "AdvDupe" end
	
	return "AdvDupe ("..path..")"
end

function AdvDupe.NormPaste( Player, EntityList, ConstraintList, HeadEntityIdx, Offset, HoldAngle, Shooting_Ent, PasteFrozen, PastewoConst, CreatedEntities, CreatedConstraints )
	
	--do the effect
	--[[if (DoPasteFX) then
		Shooting_Ent:EmitSound( "Airboat.FireGunRevDown" )
		TingerFX( Shooting_Ent, HitPos )
	end--]]
	
	--Msg("===doing delayed paste===\n")
	AdvDupe.Paste( Player, EntityList, ConstraintList, HeadEntityIdx, Offset, HoldAngle, Shooting_Ent, PastewoConst, CreatedEntities, CreatedConstraints )
	
	CreatedEntities.EntityList = nil
	local desc = AdvDupe.GetUndoDescription(Player)
	undo.Create( desc )
		undo.SetCustomUndoText( "Undone "..desc )
		
		for EntID, Ent in pairs( CreatedEntities ) do
			undo.AddEntity( Ent )
			
			if ( PasteFrozen or PastewoConst ) then --and (Ent:GetPhysicsObject():IsValid()) then
				AdvDupe.FreezeEntity( Player, Ent, true )
				--[[local Phys = Ent:GetPhysicsObject()
				Phys:Sleep()
				Phys:EnableMotion(false)
				Player:AddFrozenPhysicsObject( Ent, Phys )--]]
			end
			
			if ( !PastewoConst ) then
				AdvDupe.ApplyParenting( Ent, EntID, EntityList, CreatedEntities )
			end
			
			-- Resets the positions of all the entities in the table
			EntTable = EntityList[ EntID ]
			EntTable.Pos = EntTable.LocalPos * 1
			EntTable.Angle = EntTable.LocalAngle * 1
			if ( EntTable.PhysicsObjects ) then
				for Num, Object in pairs( EntTable.PhysicsObjects ) do
					Object.Pos = Object.LocalPos * 1
					Object.Angle = Object.LocalAngle * 1
				end
			end
			
		end
		
		undo.SetPlayer( Player )
		
	undo.Finish()
	
	
	
	--AdvDupe.ResetPositions( EntityList, ConstraintList )
	
end

function AdvDupe.Paste( Player, EntityList, ConstraintList, HeadEntityIdx, Offset, HoldAngle, Shooting_Ent, PastewoConst, CreatedEntities, CreatedConstraints )
	
	--local CreatedEntities = {}
	
	--
	-- Create the Entities
	--
	for EntID, EntTable in pairs( EntityList ) do
		
		CreatedEntities[ EntID ] = AdvDupe.PasteEntity( Player, EntTable, EntID, Offset, HoldAngle )
		
	end
	
	--
	-- Apply modifiers to the created entities
	--
	for EntID, Ent in pairs( CreatedEntities ) do	
		
		--AdvDupe.AfterPasteApply( Player, Ent, CreatedEntities )
		local NoFail, Result = xpcall( AdvDupe.AfterPasteApply, debug.traceback, Player, Ent, CreatedEntities )
		if ( !NoFail ) then
			MsgN("AdvDupeERROR: AfterPasteApply, Error: ",tostring(Result))
		end
		
	end
	
	
	--local CreatedConstraints = {}
	
	--
	-- Create constraints
	--
	if ( !PastewoConst ) and ( ConstraintList ) then
		for k, Constraint in pairs( ConstraintList ) do
			
			if ( Constraint.Type and Constraint.Type != "" ) then
				local Entity = AdvDupe.CreateConstraintFromTable( Player, Constraint, CreatedEntities, Offset, HoldAngle )
				
				if IsValid( Entity ) then
					table.insert( CreatedConstraints, Entity )
				else
					MsgN("AdvDupeERROR:Could not make constraint type: ",(Constraint.Type or "NIL"))
				end
			end
			
		end
	end
	
	--return CreatedEntities, CreatedConstraints
	
end


--
--	Paste of time
--
function AdvDupe.OverTimePasteStart( Player, inEntityList, inConstraintList, HeadEntityIdx, HitPos, HoldAngle, NumOfEnts, NumOfConst, PasteFrozen, PastewoConst, CallOnPasteFin, DontRemoveThinger, Thinger )
	
	local EntityList = {}
	local EntIDList = {}
	EntIDList[1] = HeadEntityIdx
	for EntID, EntTable in pairs( inEntityList ) do
		EntityList[EntID] = inEntityList[EntID]
		if ( EntID != HeadEntityIdx ) then
			table.insert( EntIDList, EntID )
		end
	end
	
	local ConstraintList = {}
	for ConstID, ConstTable in pairs( inConstraintList ) do
		table.insert(ConstraintList, ConstTable)
	end
	
	T						= {}
	T.Player				= Player
	T.EntityList			= EntityList
	T.ConstraintList		= ConstraintList
	T.HeadEntityIdx			= HeadEntityIdx
	T.CallsInRun			= 0
	T.Stage					= 1
	T.LastID				= 1
	T.EntIDList				= EntIDList
	T.CreatedEntities		= {}
	T.CreatedEntities.EntityList = EntityList
	T.CreatedConstraints	= {}
	T.HitPos				= HitPos
	T.HoldAngle				= HoldAngle
	if IsValid( Thinger ) then
		T.Shooting_Ent		= Thinger
		T.DontRemoveThinger = DontRemoveThinger
	else
		T.Shooting_Ent		= MakeThinger(Player)
	end
	T.CallOnPasteFin	= CallOnPasteFin
	T.Delay					= CurTime() + 0.2
	if ( PastewoConst ) then --guess how many ticks it will require so the progress bar looks right
		T.TotalTicks = math.ceil(NumOfEnts / PasteEntsPerTick) + math.ceil(NumOfEnts / PostEntityPastePerTick) + 5
	else
		T.TotalTicks = math.ceil(NumOfEnts / PasteEntsPerTick) + math.ceil(NumOfEnts / PostEntityPastePerTick) + math.ceil(NumOfConst / PasteConstsPerTick) + 5
	end
	T.PasteFrozen			= PasteFrozen
	T.PastewoConst			= PastewoConst
	
	table.insert(TimedPasteData, T)
	
end

function AdvDupe.OverTimePasteProcessFromTable()
	AdvDupe.OverTimePasteProcess(
		TimedPasteData[TimedPasteDataCurrent].Player, 
		TimedPasteData[TimedPasteDataCurrent].EntityList, 
		TimedPasteData[TimedPasteDataCurrent].ConstraintList, 
		TimedPasteData[TimedPasteDataCurrent].HeadEntityIdx, 
		TimedPasteData[TimedPasteDataCurrent].Stage, 
		TimedPasteData[TimedPasteDataCurrent].LastID, 
		TimedPasteData[TimedPasteDataCurrent].EntIDList, 
		TimedPasteData[TimedPasteDataCurrent].CreatedEntities, 
		TimedPasteData[TimedPasteDataCurrent].CreatedConstraints, 
		TimedPasteData[TimedPasteDataCurrent].Shooting_Ent,
		TimedPasteDataCurrent,
		TimedPasteData[TimedPasteDataCurrent].HitPos,
		TimedPasteData[TimedPasteDataCurrent].HoldAngle,
		TimedPasteData[TimedPasteDataCurrent].PasteFrozen,
		TimedPasteData[TimedPasteDataCurrent].PastewoConst )
end

function AdvDupe.OverTimePasteProcess( Player, EntityList, ConstraintList, HeadEntityIdx, Stage, LastID, EntIDList, CreatedEntities, CreatedConstraints, Shooting_Ent, DataNum, Offset, HoldAngle, PasteFrozen, PastewoConst )
	
	if Stage == 1 then
		
		if (DoPasteFX) then Shooting_Ent:EmitSound( "Airboat.FireGunRevDown" ) end
		
		for i = 1,PasteEntsPerTick do
			if EntIDList[ LastID ] then
				
				local EntID		= EntIDList[ LastID ]
				local EntTable	= EntityList[ EntID ]
				
				--[[CreatedEntities[ EntID ] = AdvDupe.CreateEntityFromTable( Player, EntTable, EntID, Offset, HoldAngle )
				
				if ( CreatedEntities[ EntID ] and CreatedEntities[ EntID ]:IsValid() )
				and not ( CreatedEntities[ EntID ].AdminSpawnable and !game.SinglePlayer() and (!Player:IsAdmin( ) or !Player:IsSuperAdmin() ) and DontAllowPlayersAdminOnlyEnts ) then
					
					Player:AddCleanup( "duplicates", CreatedEntities[ EntID ] )
					
					CreatedEntities[ EntID ].BoneMods = table.Copy( EntTable.BoneMods )
					CreatedEntities[ EntID ].EntityMods = table.Copy( EntTable.EntityMods )
					CreatedEntities[ EntID ].PhysicsObjects = table.Copy( EntTable.PhysicsObjects )
					
					local NoFail, Result = pcall( duplicator.ApplyEntityModifiers, Player, CreatedEntities[ EntID ] )
					if ( !NoFail ) then
						Msg("AdvDupeERROR: ApplyEntityModifiers, Error: "..tostring(Result).."\n")
					end
					
					local NoFail, Result = pcall( duplicator.ApplyBoneModifiers, Player, CreatedEntities[ EntID ] )
					if ( !NoFail ) then
						Msg("AdvDupeERROR: ApplyBoneModifiers Error: "..tostring(Result).."\n")
					end
					
					--freeze it and make it not solid so it can't be altered while the rest is made
					if (CreatedEntities[ EntID ]:GetPhysicsObject():IsValid()) then
						CreatedEntities[ EntID ]:GetPhysicsObject():Sleep()
						CreatedEntities[ EntID ]:GetPhysicsObject():EnableMotion(false)
					end
					CreatedEntities[ EntID ]:SetNotSolid(true)
					
					--do the effect
					if (DoPasteFX) and (math.random(5) > 3) then
						TingerFX( Shooting_Ent, CreatedEntities[ EntID ]:GetPos() )
					end
					
				else
					Msg("AdvDupeERROR:Created Entity Bad! Class: "..(EntTable.Class or "NIL").." Ent: "..EntID.."\n")
					CreatedEntities[ EntID ] = nil
				end--]]
				
				
				CreatedEntities[ EntID ] = AdvDupe.PasteEntity( Player, EntTable, EntID, Offset, HoldAngle )
				
				if ( CreatedEntities[ EntID ] ) then
					--freeze it and make it not solid so it can't be altered while the rest is made
					--AdvDupe.FreezeEntity( Player, CreatedEntities[ EntID ], false )
					if (CreatedEntities[ EntID ]:GetPhysicsObject():IsValid()) then
						--CreatedEntities[ EntID ]:GetPhysicsObject():Sleep()
						CreatedEntities[ EntID ]:GetPhysicsObject():EnableMotion(false)
					end
					
					CreatedEntities[ EntID ]:SetNotSolid(true)
					
					CreatedEntities[ EntID ]:SetParent( Shooting_Ent )
					
					--do the effect
					if (DoPasteFX) and (math.random(5) > 3) then
						TingerFX( Shooting_Ent, CreatedEntities[ EntID ]:GetPos() )
					end
				end
				
				
				LastID = LastID + 1
				
			else
				LastID = 1
				Stage = 2
				break
			end
		end
		
	elseif Stage == 2 then
		
		--for EntID, Ent in pairs( CreatedEntities ) do	
		for i = 1,PostEntityPastePerTick do
			if EntIDList[ LastID ] then
				
				local EntID		= EntIDList[ LastID ]
				local Ent		= CreatedEntities[ EntID ]
				
				if (Ent != nil) then
					local NoFail, Result = xpcall( AdvDupe.AfterPasteApply, debug.traceback, Player, Ent, CreatedEntities )
					if ( !NoFail ) then
						MsgN("AdvDupeERROR: AfterPasteApply, Error: ",tostring(Result))
					end
				end
				
				LastID = LastID + 1
				
			else
				LastID = 1
				Stage = 3
				break
			end
		end
		
	elseif Stage == 3 then
		
		if ( PastewoConst ) then
			TimedPasteData[DataNum].Stage  = 4
			return
		end
		
		if (DoPasteFX) then Shooting_Ent:EmitSound( "Airboat.FireGunRevDown" ) end
		
		for i = 1,PasteConstsPerTick do
			if ( ConstraintList and ConstraintList[ LastID ] ) then
				
				local Constraint = ConstraintList[ LastID ]
				if ( Constraint.Type and Constraint.Type != "" ) then
					
					local Entity = AdvDupe.CreateConstraintFromTable( Player, Constraint, CreatedEntities, Offset, HoldAngle )
					
					if IsValid( Entity ) then
						table.insert( CreatedConstraints, Entity )
						
						if (DoPasteFX) and (math.random(5) > 3) then
							TingerFX( Shooting_Ent, CreatedEntities[ Constraint.Entity[1].Index ]:GetPos() )
						end
						
					else
						MsgN("AdvDupeERROR:Created Constraint Bad! Type= ",(Constraint.Type or "NIL"))
						Entity = nil
					end
				end
				
				LastID = LastID + 1
				
			else
				LastID = 1
				Stage = 4
				
				--[=[for EntID, Ent in pairs( CreatedEntities ) do
					Ent:SetNotSolid(false)
					--[[if ( Ent:GetPhysicsObject():IsValid() ) then
						local Phys = Ent:GetPhysicsObject()
						Phys:Wake()
					end--]]
				end--]=]
				
				break
			end
		end
		
	elseif Stage == 4 then
		
		CreatedEntities.EntityList = nil
		local desc = AdvDupe.GetUndoDescription(Player)
		undo.Create( desc )
			undo.SetCustomUndoText( "Undone "..desc )
			for EntID, Ent in pairs( CreatedEntities ) do
				if IsValid(Ent) then
					
					undo.AddEntity( Ent )
					
					EntTable = EntityList[ EntID ]
					
					--if ( Ent:GetPhysicsObject():IsValid() ) then
						--[=[local Phys = Ent:GetPhysicsObject()
						if ( PasteFrozen or PastewoConst ) or ( EntTable.PhysicsObjects[0].Frozen ) then
							--[[Phys:Wake()
							Phys:EnableMotion(false)
							Player:AddFrozenPhysicsObject( Ent, Phys )--]]
							--Phys:EnableMotion(true)
							--Phys:Wake()
							AdvDupe.FreezeEntity( Player, Ent, !(Ent.EntityMods and Ent.EntityMods.Freeze_o_Matic_SuperFreeze and Ent.EntityMods.Freeze_o_Matic_SuperFreeze.NoPickUp == true) )
						else
							Phys:EnableMotion(true)
							Phys:Wake()
						end--]=]
							
					--end
					
					Ent:SetNotSolid(false)
					
					// Note: As of February 2016 Gmod Hotfix #2, SetParent'ing a frozen prop will unfreeze it (though it stays asleep), so we have to refreeze it
					Ent:SetParent()
					
					for Bone = 0, Ent:GetPhysicsObjectCount() do
						local Phys = Ent:GetPhysicsObjectNum( Bone )
						if IsValid( Phys ) then
							if ( PasteFrozen or PastewoConst ) or ( EntTable.PhysicsObjects[0].Frozen ) then
								if ( !(Ent.EntityMods and Ent.EntityMods.Freeze_o_Matic_SuperFreeze and Ent.EntityMods.Freeze_o_Matic_SuperFreeze.NoPickUp == true) ) then
									Phys:EnableMotion(false)
									Player:AddFrozenPhysicsObject( Ent, Phys )
								end
							else
								Phys:EnableMotion(true)
							end
						end
					end
					
					--[[local Phys = Ent:GetPhysicsObject()
					if ( Phys and Phys:IsValid() ) then
						Phys:Wake()
					end--]]
					
					if ( Ent.RDbeamlibDrawer ) then
						Ent.RDbeamlibDrawer:SetParent( Ent )
					end
					
					if ( !PastewoConst ) then
						AdvDupe.ApplyParenting( Ent, EntID, EntityList, CreatedEntities )
					end
					
					-- Resets the positions of all the entities in the table
					EntTable.Pos = EntTable.LocalPos * 1
					EntTable.Angle = EntTable.LocalAngle * 1
					if ( EntTable.PhysicsObjects ) then
						for Num, Object in pairs( EntTable.PhysicsObjects ) do
							Object.Pos = Object.LocalPos * 1
							Object.Angle = Object.LocalAngle * 1
						end
					end
					
				else
					Ent = nil
				end
			end
			undo.SetPlayer( Player )
		undo.Finish()
		
		--[[for EntID, Ent in pairs( CreatedEntities ) do
			AdvDupe.ApplyParenting( Ent, EntID, EntityList, CreatedEntities )
		end--]]
		
		--AdvDupe.ResetPositions( EntityList, ConstraintList )
		
		Stage = 5 --done!
		
	end
	
	TimedPasteData[DataNum].Stage  = Stage
	
	if Stage < 5 then
		TimedPasteData[DataNum].LastID = LastID
	end
	
end


--
--	Clean Up
--
function AdvDupe.FinishPasting( TimedPasteData,TimedPasteDataCurrent )
	-- This hook is for E2's dupefinished function
	-- Use TimedPasteData[TimedPasteDataCurrent].Player to get the player
	hook.Run("AdvDupe_FinishPasting", TimedPasteData, TimedPasteDataCurrent)
	
	if ( !TimedPasteData[TimedPasteDataCurrent].DontRemoveThinger ) then
		if IsValid( TimedPasteData[TimedPasteDataCurrent].Shooting_Ent.Entity ) then
			TimedPasteData[TimedPasteDataCurrent].Shooting_Ent.Entity:Remove()
		end
		AdvDupe.HideGhost( TimedPasteData[TimedPasteDataCurrent].Player, false ) --unhide ghost now
		AdvDupe.SetPasting( TimedPasteData[TimedPasteDataCurrent].Player, false ) --allow the player to paste again
		
		AdvDupe.SetPercent(TimedPasteData[TimedPasteDataCurrent].Player, 100)
		AdvDupe.SetPercent(TimedPasteData[TimedPasteDataCurrent].Player, -1)
	end
	
	if ( TimedPasteData[TimedPasteDataCurrent].CallOnPasteFin ) then
		TimedPasteData[TimedPasteDataCurrent].CallOnPasteFin(
			TimedPasteData[TimedPasteDataCurrent].Shooting_Ent,
			TimedPasteData[TimedPasteDataCurrent].CreatedEntities, 
			TimedPasteData[TimedPasteDataCurrent].CreatedConstraints
		)
	end
	
	table.remove(TimedPasteData,TimedPasteDataCurrent)
end



--
--	Makes single entity
--
function AdvDupe.PasteEntity( Player, EntTable, EntID, Offset, HoldAngle )
	
	if ( not AdvDupe.CheckOkEnt( Player, EntTable ) ) then
		return
	end
	
	local Ent = AdvDupe.CreateEntityFromTable( Player, EntTable, EntID, Offset, HoldAngle )
	
	if IsValid( Ent ) then
		
		Player:AddCleanup( "duplicates", Ent )

		if Ent.OnDuplicated then Ent:OnDuplicated(EntTable) end
		
		Ent.BoneMods = table.Copy( EntTable.BoneMods )
		Ent.EntityMods = table.Copy( EntTable.EntityMods )
		Ent.PhysicsObjects = table.Copy( EntTable.PhysicsObjects )
		
		local Success, Result = xpcall( duplicator.ApplyEntityModifiers, debug.traceback, Player, Ent )
		if ( !Success ) then
			MsgN("AdvDupeERROR: ApplyEntityModifiers, Error: ",tostring(Result))
		end
		
		local Success, Result = xpcall( duplicator.ApplyBoneModifiers, debug.traceback, Player, Ent )
		if ( !Success ) then
			MsgN("AdvDupeERROR: ApplyBoneModifiers Error: ",tostring(Result))
		end
		
		if ( EntTable.Skin ) then Ent:SetSkin( EntTable.Skin ) end
		if ( Ent.RestoreNetworkVars ) then Ent:RestoreNetworkVars( EntTable.DT ) end
		
		if Ent:GetClass() == "prop_vehicle_prisoner_pod" and Ent:GetModel() != "models/vehicles/prisoner_pod_inner.mdl" and !Ent.HandleAnimation then
			local function FixChair( vehicle, Player )
				return Player:SelectWeightedSequence( ACT_GMOD_SIT_ROLLERCOASTER )
			end
			table.Merge( Ent, { HandleAnimation = FixChair } )
		end
		
		return Ent
		
	else
		
		MsgN("AdvDupeERROR:Created Entity Bad! Class: ",(EntTable.Class or "NIL")," Ent: ",EntID)
		
	end
	
end


--
--	Generic function for duplicating stuff
--
function AdvDupe.GenericDuplicatorFunction( Player, data, ID )
	if (!data) or (!data.Class) then return false end
	
	--Msg("AdvDupeInfo: Generic make function for Class: "..data.Class.." Ent: ".."\n")
	
	local Entity = NULL
	if ( data.Class != "lua_run" and data.Class:Left( 5 ) != "base_" and scripted_ents.GetList()[data.Class] ) then
		Entity = ents.Create( data.Class )
	end
	
	if (!Entity:IsValid()) then
		MsgN("AdvDupeError: Unknown class \"",data.Class,"\", making prop instead for ent: ",ID)
		Entity = ents.Create( "prop_physics" )
		Entity:SetCollisionGroup( COLLISION_GROUP_WORLD )
	end
	
	duplicator.DoGeneric( Entity, data )
	Entity:Spawn()
	Entity:Activate()
	duplicator.DoGenericPhysics( Entity, Player, data )

	table.Add( Entity:GetTable(), data )
	
	return Entity
end

--
--	Create an entity from a table.
--
local KeyLookup = {
	pos = "Pos",
	position = "Pos",
	ang = "Angle",
	Ang = "Angle",
	angle = "Angle",
	model = "Model",
}

function AdvDupe.CreateEntityFromTable( Player, EntTable, ID, Offset, HoldAngle )
	
	local EntityClass = duplicator.FindEntityClass( EntTable.Class )
	
	
	local NewPos, NewAngle = LocalToWorld( EntTable.LocalPos, EntTable.LocalAngle, Offset, HoldAngle )
	EntTable.Pos = NewPos
	EntTable.Angles = NewAngle
	EntTable.Angle = NewAngle
	if ( EntTable.PhysicsObjects ) then
		for Num, Object in pairs( EntTable.PhysicsObjects ) do
			local NewPos, NewAngle = LocalToWorld( Object.LocalPos, Object.LocalAngle, Offset, HoldAngle )
			Object.Pos = NewPos
			Object.Angles = NewAngle
			Object.Angle = NewAngle
		end
	end
	
	-- This class is unregistered. Instead of failing try using a generic
	-- Duplication function to make a new copy..
	if (!EntityClass) then
		return AdvDupe.GenericDuplicatorFunction( Player, EntTable, ID )
	end
	
	-- Build the argument list
	-- if (!EntTable.arglist) then
		local arglist = {}
		
		for index, Key in ipairs( EntityClass.Args ) do
			
			-- Translate keys from old system
			local Arg = EntTable[ KeyLookup[Key] or Key ]
			
			-- Special keys
			if ( Key == "Data" ) then Arg = EntTable end
			
			arglist[ index ] = Arg or false -- If there's a missing argument, replace it by false, because unpack would stop on nil
			
		end
		EntTable.arglist = arglist
	-- Removed this else branch because it broke entities that had changed their duplicator.RegisterEntityClass call
	--[[else
		local fpos, fang = false, false --found ang and pos
		for iNumber, Key in pairs( EntityClass.Args ) do
			
			if ( Key == "pos" || Key == "position" || Key == "Pos") then
				EntTable.arglist[ iNumber ] = EntTable.Pos
				fpos = true
			end
			
			if ( Key == "ang" || Key == "Ang" || Key == "angle" || Key == "Angle" ) then
				EntTable.arglist[ iNumber ] = EntTable.Angle
				fang = true
			end
			
			if (fpos and fang) then break end
			
		end
	end--]]
	
	-- Create and return the entity
	--return EntityClass.Func( Player, unpack(EntTable.arglist) )
	local ok, Result
	if ( EntTable.Class == "prop_physics" ) then
		ok, Result = xpcall( AdvDupe.MakeProp, debug.traceback, Player, unpack(EntTable.arglist) )
	elseif ( EntTable.Class == "gmod_thruster" ) then -- Adds missing sound information to old dupes.
		if ( EntTable.arglist[10] == false and EntTable.arglist[11] == true ) then
			EntTable.arglist[10] = ""
			EntTable.arglist[11] = false
		end
		ok, Result = xpcall( EntityClass.Func, debug.traceback, Player, unpack(EntTable.arglist) )
	else
		ok, Result = xpcall( EntityClass.Func, debug.traceback, Player, unpack(EntTable.arglist) )
	end
	if ( !ok ) then
		MsgN("AdvDupeERROR: CreateEntity failed to make \"",(EntTable.Class or "NIL" ),"\", Error: ",tostring(Result))
		AdvDupe.SendClientError( Player, "Failed to make \""..(EntTable.Class or "NIL").."\"" )
		return
	else
		return Result
	end
	
end

--
--	Make a constraint from a constraint table
--
function AdvDupe.CreateConstraintFromTable( Player, Constraint, EntityList, Offset, HoldAngle )
	if ( !Constraint ) then return end

	local Factory = duplicator.ConstraintType[ Constraint.Type ]
	if ( !Factory ) then return end
	
	local Args = {}
	for k, Key in pairs( Factory.Args ) do
		
		local Val = Constraint[ Key ]
		
		if ( Key == "pl" ) then Val = Player end
		
		for i=1, 6 do 
			if ( Constraint.Entity[ i ] ) then
				if ( Key == "Ent"..i ) or ( Key == "Ent" ) then						
					if ( Constraint.Entity[ i ].World ) then
						Val = game.GetWorld()
					else
						Val = EntityList[ Constraint.Entity[ i ].Index ] 
						if (!Val) or (!Val:IsValid()) then
							MsgN("AdvDupeERROR: Problem with = ",(Constraint.Type or "NIL")," Constraint. Could not find Ent: ",Constraint.Entity[ i ].Index)
							return
						end
					end
				end
				if ( Key == "Bone"..i ) or ( Key == "Bone" ) then Val = Constraint.Entity[ i ].Bone end
				if ( Key == "LPos"..i ) then
					if (Constraint.Entity[ i ].World && Constraint.Entity[ i ].LPos) then
						local NewPos, NewAngle = LocalToWorld( Constraint.Entity[ i ].LPos, Angle(0,0,0), Offset, HoldAngle )
						Val = NewPos
					else
						Val = Constraint.Entity[ i ].LPos
					end
				end
				if ( Key == "WPos"..i ) then Val = Constraint.Entity[ i ].WPos end
				if ( Key == "Length"..i ) then Val = Constraint.Entity[ i ].Length end
			end
		end
		
		-- If there's a missing argument then unpack will stop sending at that argument
		if ( Val == nil ) then Val = false end
		
		table.insert( Args, Val )
		
	end
	
	--local Entity = Factory.Func( unpack(Args) )
	--return Entity
	
	
	
	if ( DebugWeldsByDrawingThem) and ( Constraint.Type == "Weld" ) then
		RDbeamlib.MakeSimpleBeam(
			EntityList[ Constraint.Entity[ 1 ].Index ], Vector(0,0,0), 
			EntityList[ Constraint.Entity[ 2 ].Index ], Vector(0,0,0), 
			"cable/cable2", Color(255,0,0,255), 1, true
		)
	end
	
	
	
	local ok, Result = xpcall( Factory.Func, debug.traceback, unpack(Args) )
	if ( !ok ) then
		MsgN("AdvDupeERROR: CreateConstraint failed to make \"",(Constraint.Type or "NIL"),"\", Error: ",tostring(Result))
		AdvDupe.SendClientError( Player, "Failed to make \""..(Constraint.Type or "NIL").."\"" )
		return
	else
		
		if (Constraint.Type == "Elastic" or Constraint.length) and isnumber(Constraint.length) then --fixed?
			Result:Fire("SetSpringLength", Constraint.length, 0)
			Result.length = Constraint.length
		end
		
		return Result
	end
	
end

--
--	Makes a physics prop with out the spawn effect (cause we don't need it)
--
function AdvDupe.MakeProp( Player, Pos, Ang, Model, PhysicsObjects, Data )

	-- Uck.
	Data.Pos = Pos
	Data.Angle = Ang
	Data.Model = Model

	-- Make sure this is allowed
	if ( !gamemode.Call( "PlayerSpawnProp", Player, Model ) ) then return end
	
	local Prop = ents.Create( "prop_physics" )
		duplicator.DoGeneric( Prop, Data )
	Prop:Spawn()
	Prop:Activate()
	
	duplicator.DoGenericPhysics( Prop, Player, Data )
	duplicator.DoFlex( Prop, Data.Flex, Data.FlexScale )
	
--	if ( Data && !Data.SkipSolidCheck ) then
--		timer.Simple( 0.01, CheckPropSolid, Prop, COLLISION_GROUP_NONE, COLLISION_GROUP_WORLD )
--	end

	-- Tell the gamemode we just spawned something
	gamemode.Call( "PlayerSpawnedProp", Player, Model, Prop )
	--DoPropSpawnedEffect( Prop ) --fuck no
	
	return Prop
	
end

--
--	Apply after paste stuff
--
function AdvDupe.AfterPasteApply( Player, Ent, CreatedEntities )
	
	if ( Ent.PostEntityPaste ) then
		Ent:PostEntityPaste( Player, Ent, CreatedEntities )
	end
	
	--clean up
	if (Ent.EntityMods) then
		if (Ent.EntityMods.RDDupeInfo) then -- fix: RDDupeInfo leak 
			Ent.EntityMods.RDDupeInfo = nil
		end
		if (Ent.EntityMods.WireDupeInfo) then 
			Ent.EntityMods.WireDupeInfo = nil
		end
	end

end

function AdvDupe.ApplyParenting( Ent, EntID, EntityList, CreatedEntities )

	if ( EntityList[ EntID ].SavedParentIdx ) then
		local Ent2 = CreatedEntities[ EntityList[ EntID ].SavedParentIdx ]
		if IsValid( Ent2 ) and ( Ent != Ent2 ) then
			Ent:SetParent()
			if ( Ent == Ent2:GetParent() ) then
				Ent2:SetParent()
			end
			Ent:SetParent( Ent2 )
		end
	end
	
end

function AdvDupe.FreezeEntity( ply, Ent, AddToFrozenList )
	for Bone = 0, Ent:GetPhysicsObjectCount() do
		local Phys = Ent:GetPhysicsObjectNum( Bone )
		if IsValid( Phys ) then
			Phys:EnableMotion( false )
			if ( AddToFrozenList ) then
				ply:AddFrozenPhysicsObject( Ent, Phys )
			end
		end
	end
end

local tablecache = {}
local lower = string.lower
local function GetCaselessEntTable(class)
	local lclass = lower(class)
	local tbl = tablecache[lclass]
	if tbl then return tbl end
	
	tbl = scripted_ents.GetStored(class) or scripted_ents.GetStored(lclass)
	if tbl then
		tablecache[lclass] = tbl
		return tbl
	end
	
	for thisclass,tbl in pairs(scripted_ents.GetList()) do
		if lower(thisclass) == lclass then
			tablecache[lclass] = tbl
			return tbl
		end
	end
end

hook.Add("InitPostEntity", "GetCaselessEntTable", function()
	for thisclass,tbl in pairs(scripted_ents.GetList()) do
		tablecache[lower(thisclass)] = tbl
	end
end)

local function IsAllowed(Player, Class, EntityClass)
	if ( scripted_ents.GetMember( Class, "DoNotDuplicate" ) ) then return false end

	if ( IsValid( Player ) and (!Player:IsAdmin() or !DontAllowPlayersAdminOnlyEnts)) then
		if !duplicator.IsAllowed(Class) then return false end
		if ( !scripted_ents.GetMember( Class, "Spawnable" ) and not EntityClass ) then return false end
		if ( scripted_ents.GetMember( Class, "AdminOnly" ) ) then return false end
	end
	return true
end

--
--	==Even More Admin stuff==
--	Ent make check hooks
--
--	Add a hook to check if player should be allowed to make the ent. return true to allow ent creation, false to deny
-- 	Example hook:	
--	AdvDupe.AddEntCheckHook( "TestHook", 
--		function(Player, Ent, EntTable) return true end, 
--		function(HookName) Msg("my advdupe ent check hook \""..HookName.."\" died and was removed\n") end )
--
local CheckFunctions = {}
function AdvDupe.CheckOkEnt( Player, EntTable )
	EntTable.Class = EntTable.Class or ""

	-- Filter duplicator blocked entities out.
	if EntTable.DoNotDuplicate then return false end

	--MsgN("EntCheck on Class: ",EntTable.Class)
	for HookName, TheHook in pairs (CheckFunctions) do
		
		local Success, Result = xpcall( TheHook.Func, debug.traceback, Player, EntTable.Class, EntTable )
		if ( !Success ) then
			ErrorNoHalt("AdvDupeERROR: Entity check hook \"",HookName,"\" failed, removing.\nHook Error: \"",tostring(Result),"\"\n")
			
			local OnFailCallBack = TheHook.OnFailCallBack
			
			CheckFunctions[ HookName ] = nil
			
			if ( OnFailCallBack ) then
				--MsgN("OnFailCallBack")
				local Success, Result = xpcall( OnFailCallBack, debug.traceback, HookName )
				if ( !Success ) then
					ErrorNoHalt("AdvDupeERROR: WTF! \"",HookName,"\" OnFailCallBack failed too! Tell who ever make that hook that they're doing it wrong. Error: \"",tostring(Result),"\"\n")
				end
			end
			
		elseif ( Result == false ) then
			
			return false
			
		end
		
	end
	
	local EntityClass = duplicator.FindEntityClass( EntTable.Class )
	if not IsAllowed(Player, EntTable.Class, EntityClass) then
		AdvDupe.SendClientError(Player, "Sorry, you can't cheat like that")
		MsgN("AdvDupeERROR: ",tostring(Player)," tried to paste admin only prop ",(EntTable.Class or "NIL")," : ",EntID)
		return false
	end
	
	--[[local test = GetCaselessEntTable( EntTable.Class )
	if ( Player:IsAdmin( ) or Player:IsSuperAdmin() or game.SinglePlayer() or !DontAllowPlayersAdminOnlyEnts ) then
		return true
	elseif ( test and test.t and test.t.AdminSpawnable and !test.t.Spawnable ) then
		AdvDupe.SendClientError(Player, "Sorry, you can't cheat like that")
		MsgN("AdvDupeERROR: ",tostring(Player)," tried to paste admin only prop ",(EntTable.Class or "NIL")," : ",EntID)
		return false
	else
		return true
		--return false
	end]]
	
	return true
end

-- Func = HookFunction( Player, Class, EntTable )
--OnFailCallBack = function to call if your hook function generates an error and is removed
function AdvDupe.AdminSettings.AddEntCheckHook( HookName, Func, OnFailCallBack )
	CheckFunctions[ HookName ] = {}
	CheckFunctions[ HookName ].Func = Func
	CheckFunctions[ HookName ].OnFailCallBack = OnFailCallBack
	--MsgN("Added EntCheckHook: ",HookName)
end
function AdvDupe.AdminSettings.RemoveEntCheckHook( HookName )
	if ( CheckFunctions[ HookName ] ) then
		CheckFunctions[ HookName ] = nil
		--MsgN("Removed EntCheckHook: ",HookName)
		return true
	end
end



if (!game.SinglePlayer()) then
	local function NoItems(Player, ClassName, EntTable)
		if ( Player:IsAdmin( ) or Player:IsSuperAdmin() ) then return true end
		if string.find(ClassName, "^weapon_.*")
		or string.find(ClassName, "^item_.*")
		or string.find(ClassName, "^npc_.*") then
			MsgN("AdvDupe: disalowing ",tostring(Player)," pasting item ",ClassName," (NoItems Rule)")
			AdvDupe.SendClientInfoMsg(Player, "Not allowed to paste Weapons or NPCs", true)
			return false
		else
			return true
		end
	end
	local function AddNoItems()
		AdvDupe.AdminSettings.AddEntCheckHook("AdvDupe_NoItems", NoItems, AddNoItems)
	end
	
	local b_NoItems = CreateConVar( "AdvDupe_NoItems", 1, {FCVAR_ARCHIVE} )
	if b_NoItems:GetBool() then
		AddNoItems()
	end
	
	--this doesn't work yet, cvars.AddChangeCallback is bugged
	local function OnChange( name, oldvalue, newvalue )
		MsgN("changed: ",name)
		if ( newvalue != "0" ) then
			AddNoItems()
		else
			AdvDupe.AdminSettings.RemoveEntCheckHook("AdvDupe_NoItems")
		end
		
	end
	cvars.AddChangeCallback( "AdvDupe_NoItems", OnChange )
	
	
	local function DisallowedClassesCheck(Player, ClassName, EntTable)
		if DisallowedClasses[ClassName] then
			if (DisallowedClasses[ClassName] == 2) then return false
			elseif ( DisallowedClasses[ClassName] == 1 and !Player:IsAdmin( ) and !Player:IsSuperAdmin() ) then
				MsgN("AdvDupe: disalowing ",tostring(Player)," pasting item ",ClassName," (DisallowedClass Rule)")
				AdvDupe.SendClientInfoMsg(Player, "Not allowed to paste "..ClassName, true)
				return false
			end
		end
		return true
	end
	local function AddDisallowedClassesCheck()
		AdvDupe.AdminSettings.AddEntCheckHook("AdvDupe_DisallowedClasses", DisallowedClassesCheck, AddDisallowedClassesCheck)
	end
	AddDisallowedClassesCheck()
end
	
local function ModelCheck(Player, ClassName, EntTable)
	if EntTable.Model then
		if string.find(EntTable.Model, "^%*%d+") then --crash fix for brushes :/
			MsgN("AdvDupe: ",tostring(Player),": trying to use a brush ",tostring(EntTable.Model)," on ",ClassName," (ModelCheck)")
			return false
		elseif !util.IsValidModel(EntTable.Model) then
			MsgN("AdvDupe: ",tostring(Player),": invalid model ",tostring(EntTable.Model)," on ",ClassName," (ModelCheck)")
			AdvDupe.SendClientInfoMsg(Player, "Invalid (missing?) model "..EntTable.Model.." for "..ClassName, true)
			return false
		end
	end
	return true
end
local function AddModelCheck()
	AdvDupe.AdminSettings.AddEntCheckHook("AdvDupe_ModelCheck", ModelCheck, AddModelCheck)
end
AddModelCheck()



--
-- Legacy paste stuff
--
-- Paste duplicated ents
function AdvDupe.OldPaste( ply, Ents, Constraints, DupeInfo, DORInfo, HeadEntityID, offset )
	
	local constIDtable, entIDtable, CreatedConstraints, CreatedEnts = {}, {}, {}, {}
	local HeadEntity = nil
	
	
	--Msg("\n=================--DoingLegacyPaste--=================\n")
	
	if (!Ents) then return false end
	
	
	for entID, EntTable in pairs( Ents ) do
		
		local Ent = nil
		
		local EntClass = EntTable.Class
		local EntType = duplicator.EntityClasses[EntClass]
		
		
		-- Check the antities class is registered with the duplicator
		if EntClass and EntType then
			
			local Args = AdvDupe.PasteGetEntArgs( ply, EntTable, offset )
			
			-- make the Entity
			if EntClass == "prop_physics" then --cause new prop swaner uses different args
				Ent = AdvDupe.OldMakeProp( ply, unpack(Args) )
			elseif EntClass == "gmod_wheel" then --cause new wheels use different args
				Ent = AdvDupe.OldMakeWheel( ply, unpack(Args) )
			else
				Ent = EntType.Func( ply, unpack(Args) )
			end
			
		elseif (EntClass) then
			MsgN("Duplicator paste: Unknown ent class " , (EntClass or "NIL") )
		end
		
		if IsValid(Ent) then
			entIDtable[entID] = Ent
			table.insert(CreatedEnts,Ent)
			table.Add( Ent:GetTable(), EntTable )
			
			AdvDupe.PasteApplyEntMods( ply, Ent, EntTable )
		end
		
		if ( entID == HeadEntityID ) then
			HeadEntity = Ent
		end
		
	end
	
	
	
	for _, Constraint in pairs(Constraints) do
		
		local ConstraintType = duplicator.ConstraintType[Constraint.Type]
		
		-- Check If the constraint type has been registered with the duplicator
		if Constraint.Type and ConstraintType then
			
			local Args, DoConstraint = AdvDupe.PasteGetConstraintArgs( ply, Constraint, entIDtable, offset )
			
			-- make the constraint
			if DoConstraint then
				local const = ConstraintType.Func(unpack(Args))
				table.insert(CreatedConstraints,const)
				
				--[[if (Constraint.ConstID) then
					constIDtable[Constraint.ConstID] = const
					Msg("Dupe add constraint ID: " .. Constraint.ConstID .. "\n")
				end--]]
			end
			
		elseif (Constraint.Type) then
			MsgN("Duplicator paste: Unknown constraint " , (Constraint.Type or "NIL") )
		end
	end
	
	AdvDupe.PasteApplyDupeInfo( ply, DupeInfo, entIDtable )
	
	AdvDupe.PasteApplyDORInfo( DORInfo, function(id) return entIDtable[id] end )
	
	
	--[[for entid, motordata in pairs(Wheels) do
		local ent = entIDtable[entid]
		ent:GetTable():SetMotor( constIDtable[motordata.motor] )
		ent:GetTable():SetToggle( motordata.toggle )
	end--]]
	
	
	--AdvDupe.PasteRotate( ply, HeadEntity, CreatedEnts ) --remember to turn ghost rotation back on too
	
	return CreatedEnts, CreatedConstraints
end

function AdvDupe.PasteGetEntArgs( ply, EntTable, offset )
	
	local EntArgs, Args, BoneArgs, nBone = {}, {}, nil, nil
	
	
	--these classes use different args than what new commands takes
	if EntTable.Class == "prop_physics"  then
		EntArgs = {"Pos", "Ang", "Model", "Vel", "aVel", "frozen"}
	elseif EntTable.Class == "gmod_wheel"  then
		EntArgs = {"Pos", "Ang", "model", "Vel", "aVel", "frozen", "key_f", "key_r"}
	else
		EntArgs = duplicator.EntityClasses[EntTable.Class].Args
	end
	
	for n,Key in pairs(EntArgs) do
		
		if istable(Key) then
			BoneArgs = Key
			nBone	 = n
		else
			local Arg = EntTable[Key]
			
			key = string.lower(Key)
			
			if		key == "ang"	or key == "angle"			then Arg = Arg or Vector(0,0,0)
			elseif	key == "pos"	or key == "position"		then Arg = Arg + offset or Vector(0,0,0)
			elseif	key == "vel"	or key == "velocity"		then Arg = Arg or Vector(0,0,0)
			elseif	key == "avel"	or key == "anglevelocity"	then Arg = Arg or Vector(0,0,0)
			elseif	key == "pl" 	or key == "ply"				then Arg = ply 
			-- TODO:  Arg = ply.GetBySteamID(Arg)
			end
			
			Args[n] = Arg
		end
	end
	
	if EntTable.Bones and BoneArgs then
		
		local Arg = {}
					
		-- Get args for each bone
		for Bone,Args in pairs(EntTable.Bones) do
			Arg[Bone] = {}
			
			for n, bKey in pairs( BoneArgs ) do
				
				local bArg = EntTable.Bones[Bone][bKey] or tostring(0)
				
				-- Do special cases
				local bkey = string.lower(bKey)
				
				if	bkey == "ang"	or bkey == "angle"				then bArg = bArg or Vector(0,0,0)
				elseif	bkey == "pos"	or bkey == "position"		then bArg = bArg + offset or Vector(0,0,0)
				elseif	bkey == "vel"	or bkey == "velocity"		then bArg = bArg or Vector(0,0,0)
				elseif	bkey == "avel"	or bkey == "angvelocity"	then bArg = bArg or Vector(0,0,0)
				end
				
				Arg[Bone][n] = bArg
			end
		end
		
		Args[nBone] = Arg
	end
	
	return Args
	
end

-- Legacy prop physics function
function AdvDupe.OldMakeProp( ply, Pos, Ang, Model, Vel, aVel, frozen )
	
	-- check we're allowed to spawn
	if ( !ply:CheckLimit( "props" ) ) then return end
	local Ent = ents.Create( "prop_physics" )
		Ent:SetModel( Model )
		Ent:SetAngles( Ang )
		Ent:SetPos( Pos )
	Ent:Spawn()
	
	-- apply velocity If required
	if IsValid( Ent:GetPhysicsObject() ) then
		Phys = Ent:GetPhysicsObject()
		Phys:SetVelocity(Vel or 0)
		Phys:AddAngleVelocity(aVel or 0)
		Phys:EnableMotion(frozen != true)
	end
	Ent:Activate()
	
	-- tell the gamemode we just spawned something
	ply:AddCount( "props", Ent )
	
	local ed = EffectData()
		ed:SetEntity( Ent )
	util.Effect( "propspawn", ed )
	
	return Ent	
end

-- Legacy prop phyics function
function AdvDupe.OldMakeWheel( ply, Pos, Ang, Model, Vel, aVel, frozen, key_f, key_r )

	if ( !ply:CheckLimit( "wheels" ) ) then return false end

	local wheel = ents.Create( "gmod_wheel" )
	if ( !wheel:IsValid() ) then return end
	
	wheel:SetModel(Model )
	wheel:SetPos( Pos )
	wheel:SetAngles( Ang )
	wheel:Spawn()
	
	wheel:GetTable():SetPlayer( ply )

	if ( wheel:GetPhysicsObject():IsValid() ) then
	
		Phys = wheel:GetPhysicsObject()
		if Vel then Phys:SetVelocity(Vel) end
		if aVel then Phys:AddAngleVelocity(aVel) end
		Phys:EnableMotion(frozen != true)
		
	end

	wheel:GetTable().model = model
	wheel:GetTable().key_f = key_f
	wheel:GetTable().key_r = key_r
	
	wheel:GetTable().KeyBinds = {}
	
	-- Bind to keypad
	wheel:GetTable().KeyBinds[1] = numpad.OnDown( 	ply, 	key_f, 	"WheelForward", 	wheel, 	true )
	wheel:GetTable().KeyBinds[2] = numpad.OnUp( 	ply, 	key_f, 	"WheelForward", 	wheel, 	false )
	wheel:GetTable().KeyBinds[3] = numpad.OnDown( 	ply, 	key_r, 	"WheelReverse", 	wheel, 	true )
	wheel:GetTable().KeyBinds[4] = numpad.OnUp( 	ply, 	key_r, 	"WheelReverse", 	wheel, 	false )
	
	ply:AddCount( "wheels", wheel )
	
	return wheel
	
end

function AdvDupe.PasteApplyEntMods( ply, Ent, EntTable )
	
	for ModifierType, Modifier in pairs(AdvDupe.OldEntityModifiers) do
		if EntTable[ModifierType] then
			--MsgN("Applying Mod Type: ",ModifierType)
			local args = {}
			
			for n,arg in pairs(Modifier.Args) do
				args[n] = EntTable[ModifierType][arg]
			end
			
			Modifier.Func( ply, Ent, unpack(args))
		end
	end
	
	--Apply PhysProp data
	if EntTable.Bones then
		for BoneID,Args in pairs(EntTable.Bones) do
			if Args["physprops"] then
				local Data = {}
				for n,arg in pairs({"motionb", "gravityb", "mass", "dragb", "drag", "buoyancy", "rotdamping", "speeddamping", "material"}) do
					Data[n] = Args["physprops"][arg]
				end
				local PhysObject = Ent:GetPhysicsObjectNum( BoneID )
				AdvDupe.OldSetPhysProp( Player, Ent, BoneID, PhysObject, Data )
			end
		end
	end
	
end

--legacy EntityModifiers for color and material
AdvDupe.OldEntityModifiers = {}
AdvDupe.OldEntityModifiers.colour = {}
AdvDupe.OldEntityModifiers.colour.Args = {"r","g","b","a", "mode", "fx"}
AdvDupe.OldEntityModifiers.material = {}
AdvDupe.OldEntityModifiers.material.Args = {"mat"}
--AdvDupe.OldSetColour
function AdvDupe.OldEntityModifiers.colour.Func( ply, Entity, r,g,b,a, mode, fx )

	Entity:SetColor( Color(r,g,b,a) )
	Entity:SetRenderMode(mode)
	Entity:SetKeyValue("renderfx", fx)
	
	local Data = {}
	Data.Color = Color(r,g,b,a)
	//Data.Color.r, Data.Color.g, Data.Color.b, Data.Color.a = r,g,b,a
	Data.RenderMode = mode
	Data.RenderFX = fx
	for k, v in pairs( Data ) do Entity[ k ] = v end

	return true
end
--AdvDupe.OldSetMaterial
function AdvDupe.OldEntityModifiers.material.Func( ply, Entity, mat )

	if (!mat) then return end
	if (!Entity || !Entity:IsValid()) then return end

	Entity:SetMaterial( mat )
	--Entity:GetTable().material = {mat = mat}
	Entity.MaterialOverride = mat
	
	return true

end

--the data table uses the old names instead
function AdvDupe.OldSetPhysProp( ply, ent, BoneID, Bone, Data )
		
		if ( !Bone ) then
			Bone = Entity:GetPhysicsObjectNum( BoneID )
			if ( !Bone || !Bone:IsValid() ) then 
				Msg("SetPhysProp: Error applying attributes to invalid physics object!\n")
				return
			end
		end
		
		
		-- Set the physics properties on the bone
		Data2 = {}
		if (Data.gravityb!= nil )	then
			PhysBone:EnableGravity( gravityb )
			Data2.GravityToggle = gravityb
		end
		if (Data.material!= nil)		then 
			PhysBone:EnableGravity( gravityb )
			Data2.Material = material
		end
		if (Data.motionb != nil )	then Bone:EnableMotion( Data.motionb ) end
		if (Data.mass!=nil)			then Bone:SetMass( Data.mass ) end
		if (Data.dragb!=nil)		then Bone:EnableDrag( Data.dragb ) end
		if (Data.drag!=nil)			then Bone:SetDragCoefficient( Data.drag ) end
		if (Data.buoyancy!=nil)		then Bone:SetBuoyancyRatio( Data.buoyancy ) end
		if (Data.rotdamping!=nil)	then Bone:SetDamping( PhysBone:GetSpeedDamping(), Data.rotdamping ) end
		if (Data.speeddamping!=nil)	then Bone:SetDamping( Data.speeddamping, PhysBone:GetRotDamping() ) end
		
		-- Add the settings to the bone's table
		if not ent:GetTable().Bones then ent:GetTable().Bones = {} end
		if not ent:GetTable().Bones[Bone] then ent:GetTable().Bones[Bone] = {} end
		
		-- Copy these to the new object
		for k, v in pairs(Data2) do
			Entity.PhysicsObjects = Entity.PhysicsObjects or {}
			Entity.PhysicsObjects[ BoneID ] = Entity.PhysicsObjects[ BoneID ] or {}
			Entity.PhysicsObjects[ BoneID ][k] = v 
		end
		
		-- HACK HACK
		-- If we don't do this the prop will be motion enabled and will
		-- slide through the world with no gravity.
		if ( !Bone:IsMoveable() ) then
			Bone:EnableMotion( true )
			Bone:EnableMotion( false )
		end
		
	end

-- Get the args to make the constraints
function AdvDupe.PasteGetConstraintArgs( ply, Constraint, entIDtable, offset )
	local Args = {}
	local DoConstraint = true
	local ConstraintType = duplicator.ConstraintType[Constraint.Type]
	
	-- Get the args that we need from the ConstraintType table
	for n,key in pairs(ConstraintType.Args) do
		
		local Arg = Constraint[key]
		local len = string.len(key)
		
		-- DO SPECIAL CASES
		-- If key represents an entity, convert from an entID back to an ent
		if	string.find(key, "Ent")		and ( len == 3 or len == 4 ) then
			Arg = entIDtable[Arg]
			if !IsValid(Arg) then DoConstraint = nil end
			
		-- If key represents an Local angle or vector, convert from string, back to a vector
		elseif	(string.find(key, "LPos")	and ( len == 4 or len == 5 ))
		or	(string.find(key, "Ang")	and ( len == 3 or len == 4 )) then 
			Arg = Arg or Vector(0,0,0)
			
		-- If key represents a World Vector or angle, convert from string, back to a vector
		elseif	(string.find(key, "WPos")	and ( len == 4 or len == 5 )) then
			Arg = Arg + offset or Vector(0,0,0)
			
		-- If key represents a ply, convert from steamid back to a ply
		elseif	key == "pl" or key == "ply" or key == "ply" then
			--Arg = ply.GetBySteamID(Arg)
			Arg = ply
			if not Arg:IsValid() then DoConstraint = nil end
		end
		
		Args[n] = Arg
	end
	
	return Args, DoConstraint
end

-- Apply DupeInfo for wire stuff
function AdvDupe.PasteApplyDupeInfo( ply, DupeInfoTable, entIDtable )
	if (!DupeInfoTable) then return end
	for id, infoTable in pairs(DupeInfoTable) do
		local ent = entIDtable[id]
		if IsValid(ent) and (infoTable) and (ent.ApplyDupeInfo) then
			ent:ApplyDupeInfo( ply, ent, infoTable, function(id) return entIDtable[id] end )
		end
	end
end

-- Apply DORInfo for DeleteOnRemove
function AdvDupe.PasteApplyDORInfo( DORInfoTable, GetentID )
	
	for id, DORInfo in pairs(DORInfoTable) do
		local ent = GetentID(id)
		if IsValid(ent) and (DORInfo) then
			--ent:SetDeleteOnRemoveInfo(DORInfo, function(id) return GetentID(id) end)
			
			for _,entindex in pairs(DORInfo) do
				local ent2 = GetentID(entindex)
				if (IsValid(ent2) && ent2:EntIndex() > 0) then
					-- Add the entity
					
					ent:DeleteOnRemove(ent2)
				end
			end
			
		end
	end
	
end

-- Rotate entities relative to the ply's hold angles
--[[function AdvDupe.PasteRotate( ply, HeadEntity, CreatedEnts )
	
	local EntOffsets = {}
	
	if (HeadEntity) then
	
		for i, ent in pairs( CreatedEnts ) do
		
			EntOffsets[ ent ] = {}
			
			if ( ent != HeadEntity ) then 
				
				local Pos = ent:GetPos()
				local Ang = ent:GetAngles()
				
				EntOffsets[ ent ].Pos = HeadEntity:WorldToLocal( Pos )
				EntOffsets[ ent ].Ang = Ang - HeadEntity:GetAngles()
				
			end
			
			-- And physics objects (for ragdolls)
			local Bones = {}
			for Bone=0, ent:GetPhysicsObjectCount()-1 do
				
				local PhysObject = ent:GetPhysicsObjectNum( Bone )
				
				if ( PhysObject:IsValid() ) then
					
					Bones[PhysObject] = {}
					Bones[PhysObject].Pos = HeadEntity:WorldToLocal( PhysObject:GetPos() )
					Bones[PhysObject].Ang = PhysObject:GetAngle() - HeadEntity:GetAngles()
					
				end
					
			end
			
			EntOffsets[ ent ].Bones = Bones
			
		end
		
		-- Rotate main object
		local angle = ply:GetAngles()
		angle.pitch = 0
		angle.roll 	= 0
		
		HeadEntity:SetAngles( angle - AdvDupe[ply].HoldAngle )
		
		for ent, tab in pairs( EntOffsets ) do
			
			if (HeadEntity != ent) then
				ent:SetPos( HeadEntity:LocalToWorld( tab.Pos ) )
				ent:SetAngles( HeadEntity:GetAngles() + tab.Ang )
			end
			
			-- Ragdoll Bones
			for phys, ptab in pairs( tab.Bones ) do
				
				phys:SetPos( HeadEntity:LocalToWorld( ptab.Pos ) )
				phys:SetAngle( HeadEntity:GetAngles() + ptab.Ang )
				
			end
			
		end
		
	else
		Msg("Error! Head Duplicator entity not found!\n")
	end
end
--]]

-- Returns all ents & constraints in a system
--[[	function duplicator.GetEnts(ent, EntTable, ConstraintTable)

	local EntTable			= EntTable	  or {}
	local ConstraintTable	= ConstraintTable or {}
	
	-- Ignore the world
	if not ent:IsValid() then return EntTable, ConstraintTable end
	
	-- Add ent to the list of found ents
	EntTable[ent:EntIndex()] = ent
	
	-- If there are no Constraints attached then return
	if not ent:GetTable().Constraints then return EntTable, ConstraintTable end
	
	for key, const in pairs( ent:GetTable().Constraints ) do
		
		-- If the constraint doesn't exist, delete it from the list
		if ( !const:IsValid() ) then
			
			ent:GetTable().Constraints[key] = nil
			
		-- Check that the constraint has not already been added to the constraints table
		elseif ( !ConstraintTable[const:GetTable()] ) then
			
			-- Add constraint to the constraints table
			ConstraintTable[const:GetTable()] = const
			
			-- Run the Function for any ents attached to this constraint
			for key,Ent in pairs(const:GetTable()) do
				local len = string.len(key)
				if	string.find(key, "Ent")
				and	( len == 3 or len == 4 )
				and	Ent:IsValid() 
				and	!EntTable[Ent:EntIndex()] then
					
					EntTable, ConstraintTable  = duplicator.GetEnts(Ent, EntTable, ConstraintTable)
				end
			end
			
		end
	end
	
	return EntTable, ConstraintTable
end
--]]




--
--	Register camera entity class
--	fixes key not being saved (Conna)
local function CamRegister(Player, Pos, Ang, Key, Locked, Toggle, Vel, aVel, Frozen, Nocollide)
	if (!Key) then return end
	
	local Camera = ents.Create("gmod_cameraprop")
	Camera:SetAngles(Ang)
	Camera:SetPos(Pos)
	Camera:Spawn()
	Camera:SetKey(Key)
	Camera:SetPlayer(Player)
	Camera:SetLocked(Locked)
	Camera.toggle = Toggle
	Camera:SetTracking(NULL, Vector(0))
	
	if (Toggle == 1) then
		numpad.OnDown(Player, Key, "Camera_Toggle", Camera)
	else
		numpad.OnDown(Player, Key, "Camera_On", Camera)
		numpad.OnUp(Player, Key, "Camera_Off", Camera)
	end
	
	if (Nocollide) then Camera:GetPhysicsObject():EnableCollisions(false) end
	
	-- Merge table
	local Table = {
		key			= Key,
		toggle 		= Toggle,
		locked      = Locked,
		pl			= Player,
		nocollide 	= nocollide
	}
	table.Merge(Camera:GetTable(), Table)
	
	-- remove any camera that has the same key defined for this player then add the new one
	local ID = Player:UniqueID()
	GAMEMODE.CameraList[ID] = GAMEMODE.CameraList[ID] or {}
	local List = GAMEMODE.CameraList[ID]
	if (List[Key] and List[Key] != NULL ) then
		local Entity = List[Key]
		Entity:Remove()
	end
	List[Key] = Camera
	return Camera
	
end
duplicator.RegisterEntityClass("gmod_cameraprop", CamRegister, "Pos", "Ang", "key", "locked", "toggle", "Vel", "aVel", "frozen", "nocollide")




--Garry's functions copied from duplicator STOOL
--Make them global so pasters can use of them too
--
-- Converts to world so that the entities will be spawned in the correct positions
function AdvDupe.ConvertEntityPositionsToWorld( EntTable, Offset, HoldAngle )
	for k, Ent in pairs( EntTable ) do
		local NewPos, NewAngle = LocalToWorld( Ent.LocalPos, Ent.LocalAngle, Offset, HoldAngle )
		Ent.Pos = NewPos
		Ent.Angle = NewAngle
		-- And for physics objects
		if ( Ent.PhysicsObjects ) then
			for Num, Object in pairs( Ent.PhysicsObjects ) do
				local NewPos, NewAngle = LocalToWorld( Object.LocalPos, Object.LocalAngle, Offset, HoldAngle )
				Object.Pos = NewPos
				Object.Angle = NewAngle
			end
		end
	end
end

-- Move the world positions
function AdvDupe.ConvertConstraintPositionsToWorld( Constraints, Offset, HoldAngle )
	if (!Constraints) then return end
	for k, Constraint in pairs( Constraints ) do
		if ( Constraint.Entity ) then
			for k, Entity in pairs( Constraint.Entity ) do
				if (Entity.World && Entity.LPos) then
					local NewPos, NewAngle = LocalToWorld( Entity.LPos, Angle(0,0,0), Offset, HoldAngle )
					Entity.LPosOld = Entity.LPos
					Entity.LPos = NewPos
				end
			end
		end
	end
end

-- Resets the positions of all the entities in the table
function AdvDupe.ResetPositions( EntTable, Constraints )

	for k, Ent in pairs( EntTable ) do
		Ent.Pos = Ent.LocalPos * 1
		Ent.Angle = Ent.LocalAngle * 1
		-- And for physics objects
		if ( Ent.PhysicsObjects ) then
			for Num, Object in pairs( Ent.PhysicsObjects ) do
				Object.Pos = Object.LocalPos * 1
				Object.Angle = Object.LocalAngle * 1
			end
		end
	end
	
	--[[if (!Constraints) then return end
	for k, Constraint in pairs( Constraints ) do
		if ( Constraint.Entity ) then
			for k, Entity in pairs( Constraint.Entity ) do
				if (Entity.LPosOld) then
					Entity.LPos = Entity.LPosOld
					Entity.LPosOld = nil
				end
			end
		end
	end--]]
	
end

-- Converts the positions from world positions to positions local to Offset
function AdvDupe.ConvertPositionsToLocal( EntTable, Constraints, Offset, HoldAngle )

	for k, Ent in pairs( EntTable ) do
		Ent.Pos = Ent.Pos - Offset
		Ent.LocalPos = Ent.Pos * 1
		Ent.LocalAngle = Ent.Angle * 1
		if ( Ent.PhysicsObjects ) then
			for Num, Object in pairs(Ent.PhysicsObjects) do
				Object.Pos = Object.Pos - Offset
				Object.LocalPos = Object.Pos * 1
				Object.LocalAngle = Object.Angle * 1
				Object.Pos = nil
				Object.Angle = nil
			end
		end
	end
	
	-- If the entity is constrained to the world we want to move the points to be
	-- relative to where we're clicking
	if (!Constraints) then return end
	for k, Constraint in pairs( Constraints ) do
		if ( Constraint.Entity ) then
			for k, Entity in pairs( Constraint.Entity ) do
				if (Entity.World && Entity.LPos) then
					Entity.LPos = Entity.LPos - Offset
				end
			end
		end
	end

end




--MsgN("==== Advanced Duplicator v.",AdvDupe.Version," server module installed! ====")

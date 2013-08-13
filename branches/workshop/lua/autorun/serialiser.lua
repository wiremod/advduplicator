//////////////////////////////////////////////////////////////
//			Table (De)Serialiser Module				//
//	Turns a table in to a file with a header				//
//	Module and common string pooling by: TAD2020			//
//	(De)Serialise functions by the awesome DEADBEEF		//
//////////////////////////////////////////////////////////////

local ThisVersion = 1.4
if (Serialiser) and (Serialiser.Version) and (Serialiser.Version > ThisVersion) then
	Msg("======== A Newer Version of Table (De)Serialiser Module Detected ========\n")
	Msg("======== This ver: "..ThisVersion.." || Detected ver: "..Serialiser.Version.." || Skipping\n")
	return
elseif (Serialiser) and (Serialiser.Version) and (Serialiser.Version == ThisVersion) then
	Msg("======== The Same Version of Table (De)Serialiser Module Detected || Skipping ========\n")
	return
elseif (Serialiser) and (Serialiser.Version) then
	Msg("======== An Older Version of Table (De)Serialiser Module Detected ========\n")
	Msg("======== This ver: "..ThisVersion.." || Detected ver: "..Serialiser.Version.." || Overriding\n")
end
--[[ else --we don't need to tell everyone that it loaded succesfully. If it loads successfully nothing should print
	Msg("======== Installing Table (De)Serialiser Module | ver: "..ThisVersion.." ========\n")
end ]] 

Serialiser = {}
Serialiser.Version = ThisVersion
AddCSLuaFile()

Serialiser.SaveCompressed = CreateConVar( "Serialiser_SaveCompressed", 0, {FCVAR_ARCHIVE} )


// String pooling (TAD2020)
local function MakeStringCommon( str, StrTbl, dontpoolstrings )
	if (dontpoolstrings) or (string.len(str) < 4) then
		return string.format('S:%q', str:gsub(";","»") )
	end
	
	local Idx
	if StrTbl.StringIndx[ str ] then
		StrTbl.Saved = StrTbl.Saved + 1
		Idx = StrTbl.StringIndx[ str ]
	else
		StrTbl.LastIndx = StrTbl.LastIndx + 1
		StrTbl.StringIndx[ str ] = StrTbl.LastIndx
		StrTbl.Strings[ StrTbl.LastIndx ] = string.format('%q', str )
		Idx = StrTbl.LastIndx
	end
	return 'Y:'..Idx
end

-- does the opposite of string.format("%q", s)
local function unquote(s)
	if s:len() < 2 then
		return s:sub(2,-2)
	end
	if s:sub(1,1) ~= '"' then
		return s:sub(2,-2)
	end
	if s:sub(-1,-1) ~= '"' then
		return s:sub(2,-2)
	end
	
	local ret = ""
	local lastpos=1
	local pos = string.find(s, '[\\"]', lastpos+1)
	if (pos == nil) then -- syntax error: missing closing quote
		return s:sub(2,-2)
	end
	-- condition: pos points to a \ or a "
	while (pos and (string.sub(s, pos, pos) == '\\')) do
		-- condition: pos points to a \ -> skip it
		ret = ret .. string.sub(s, lastpos+1, pos-1)
		lastpos=pos
		pos = string.find(s, '[\\"]', pos+2)
		-- condition: pos points to a \ or a " or nil
		if (pos == nil) then -- syntax error: missing closing quote
			return s:sub(2,-2)
		end
		-- condition: pos points to a \ or a "
	end
	return ret .. string.sub(s, lastpos+1, pos-1)
end

// Helper function for table.serialise
local function SerialiseChunk( chunk, tables, StrTbl, dontpoolstrings )
	
	// get the data type
	local ctype = type( chunk )
	
	//see what data type this chunk represents and return the proper value
	if     ctype == "number"  then return 'N:'..chunk
	elseif ctype == "string"  then return MakeStringCommon(chunk, StrTbl, dontpoolstrings) //string.format('S:%q', chunk )
	elseif ctype == "boolean" then return 'B:'..tostring( chunk ):sub( 1,1 )
	--elseif ctype == "Entity"  then if chunk == GetWorldEntity() then return 'E:W' elseif chunk == NULL then return 'E:N' else return 'E:'..chunk:EntIndex()  end
	elseif ctype == "Vector"  then return string.format( "V:%g,%g,%g", chunk.x, chunk.y, chunk.z )
	elseif ctype == "Angle"   then return string.format( "A:%g,%g,%g", chunk.pitch, chunk.yaw, chunk.roll )
	elseif ctype == "Player"  then return 'P:'..chunk:UniqueID()
	elseif ctype == "table"   then
		
		local ID = tostring( chunk ):sub( 8 )
		
		// tables[ID] must exist before the table is serialised else we could end up with an infinite loop.
		if !tables[ID] then tables[ID] = true tables[ID] = Serialiser.SerialiseTableKeyValues( chunk, tables, StrTbl, dontpoolstrings ) end
		
		return 'T:'..ID
	end
	
end

// Helper function for table.serialise
local function DeSerialiseChunk( chunk, tables, StrTbl )
	
	// get the data type and value
	local ctype,val = chunk:match("(.):(.+)")
	
	//see what data type this chunk represents and return the proper value
	if     ctype == "N" then return tonumber(val)
	elseif ctype == "S" then return string.gsub(unquote(val),"»",";")
	elseif ctype == "Z" then return StrTbl[ unquote(val) ]
	elseif ctype == "Y" then return StrTbl[ val ]
	elseif ctype == "B" then return val == "t"
	--elseif ctype == "E" then if val == "W" then return GetWorldEntity() elseif val == "N" then return NULL else return Entity( val )  end
	elseif ctype == "V" then
		local a,b,c = val:match("(.-),(.-),(.+)")
		return Vector( tonumber(a), tonumber(b), tonumber(c) )
	elseif ctype == "A" then
		local a,b,c = val:match("(.-),(.-),(.+)")
		return Angle( tonumber(a), tonumber(b), tonumber(c) )
	elseif ctype == "P" then return player.GetByUniqueID( val )
	elseif ctype == "T" then 
		local t = {}
		if !tables[ val ] then tables[ val ] = {} end
		table.insert( tables[ val ], t )
		return t
	end

end

// Helper function for table.serialise
function Serialiser.SerialiseTableKeyValues( tbl, tables, StrTbl, dontpoolstrings )
	
	local temp = {}
	local DoKeys = !table.IsSequential( tbl )   // we don't need to save table keys if the table is sequential
	
	for k,v in pairs( tbl ) do
		
		local str = SerialiseChunk( v, tables, StrTbl, dontpoolstrings )
		if DoKeys && str then str = SerialiseChunk( k, tables, StrTbl, dontpoolstrings ) .."=".. str end
		
		table.insert( temp, str )
		
	end
	
	return temp
	
end	

function Serialiser.SerialiseWithHeaders( Header, ExtraHeader, t, dontpoolstrings )
	
	local tables	= {}
	local str		= ""
	
	local StrTbl = {}
	StrTbl.Strings = {} --keyed with string indexes
	StrTbl.StringIndx = {} --keyed with strings
	StrTbl.LastIndx = 0 --the index last used
	StrTbl.Saved = 0 --number of strings we didn't have to save
	
	local headID = tostring(t):sub(8)
	local head	 = Serialiser.SerialiseTableKeyValues( t, tables, StrTbl, dontpoolstrings )
	
	// distinguish the main table from nested tables
	tables[headID] = nil
	tables["H"..headID] = head
	
	for k,v in pairs( tables ) do
		// concat key values for each table
		str = str..k.."{".. table.concat( v, ";" ) ..";}"
	end
	
	for idx,cstr in pairs(StrTbl.Strings) do
		str = table.concat( {str, "\n", idx, ":", cstr} )
	end
	str = str .. "\nSaved:" .. StrTbl.Saved
	
	return table.concat(
		{
			"[Information]",
			table.concat( Header, "\n" ),
			"[More Information]",
			table.concat( ExtraHeader, "\n" ),
			"[Save]",
			str
		}, "\n"
	)
end


function Serialiser.DeserialiseBlock( block, StrTbl )

	local tables	= {}
	local subtables	= {}
	local head		= nil
	
	// I'm not too good at regex, so there's probably a more efficient way of doing lines 120,127,129
	for ID,chunk in block:gmatch('(%w+){(.-)}') do  // Get each table chunk
		
		// check if this table is the trunk
		if ID:sub(1,1)== "H" then ID = ID:sub(2); head = ID end
		
		tables[ID] = {}
		
		for kv in chunk:gmatch('(.-);') do			// Split each table block into k/v pairs
			
			local k,v = kv:match('(.-)=(.+)')		// deserialise each k/v pair and add to the new table
			
			// if the table keys are sequential digits they won't be included in the string, so check for that.
			if !k then
				v = DeSerialiseChunk( kv, subtables, StrTbl )
				table.insert( tables[ID], v)
			else
				k = DeSerialiseChunk( k, subtables, StrTbl )
				v = DeSerialiseChunk( v, subtables, StrTbl )
				
				tables[ID][k] = v
			end
			
		end
	end
	
	// Restore table references
	for ID,tbls in pairs( subtables ) do
		for _,tbl in pairs( tbls ) do
			table.Merge( tbl, tables[ID] )
		end
	end
	
	// Remove any rogue keyvalues for vehicles to prevent exploiting
	// This makes exploits like the lua_run one silently fail
	for id, entInfo in pairs( tables[head] ) do
		if ( entInfo.VehicleTable and entInfo.VehicleTable.KeyValues ) then
			for key, value in pairs( entInfo.VehicleTable.KeyValues ) do
				if ( key != "limitview" and key != "vehiclescript" ) then
					entInfo.VehicleTable.KeyValues[key] = nil
				end
			end
		end
	end
	
	return tables[ head ]
	
end



local function OnFailFunc( pl, mode )
	local errormsg = "Failed "..mode.." file"
	AdvDupe.SendClientError(pl, errormsg)
	AdvDupe.SetPercent(pl, -1)
end


// Pass this function the output from the previous one
function Serialiser.DeserialiseWithHeaders( InData, CallBack, pl, filepath, tool )
	
	local Header, ExtraHeader, DataBlock, DictBlock
	
	if ( InData:sub(1,10) == "[zlib_b64]" ) then
		if !dupeshare.ZLib_Installed then
			ErrorNoHalt("zlib_b64 not installed, cannot open compressed file: ",filepath)
			return
		end
		--MsgN("Serialiser open compressed file")
		InData = dupeshare.DeCompress(InData:sub(11), false, true)
	end
	
	if ( InData:sub(1,13) == "[Information]" ) then
		Header, ExtraHeader, DataBlock = InData:match("%[Information%]\n(.+)\n%[More Information%]\n(.+)\n%[Save%]\n(.+)")
	elseif ( InData:sub(1,6) == "[Info]" ) then
		Header, ExtraHeader, DataBlock, DictBlock = InData:match("%[Info%]\n(.+)\n%[More Information%]\n(.+)\n%[Save%]\n(.+)\n%[Dict%]\n(.+)")
		
	else
		Msg("====Deserialise_ERROR:Pattern failed to load file. Attempting to find the data block now.====\n")
		DataBlock = InData
	end
	
	local function DWH1( Header, ExtraHeader, DataBlock, DictBlock, CallBack, pl, filepath, tool )
		
		local HeaderTbl = {}
		
		for k,v in pairs(string.Explode("\n", Header)) do
			local key,cstr = v:match("(.-):(.+)")
			--Msg("v= "..v.." key= "..(key or "nil").." cstr= "..(cstr or "nil").."\n")
			if (!cstr) then
				HeaderTbl[ v:sub(1,-2) ] = ""
			else
				HeaderTbl[ key ] = cstr
			end
		end
		
		local function DWH2( HeaderTbl, ExtraHeader, DataBlock, DictBlock, CallBack, pl, filepath, tool )
			
			local ExtraHeaderTbl = {}
			
			for k,v in pairs(string.Explode("\n", ExtraHeader)) do
				local key,cstr = v:match("(.-):(.+)")
				--Msg("v= "..v.." key= "..(key or "nil").." cstr= "..(cstr or "nil").."\n")
				if (!cstr) then
					ExtraHeaderTbl[ v:sub(1,-2) ] = ""
				else
					ExtraHeaderTbl[ key ] = cstr
				end
			end
			
			local function DWH3( HeaderTbl, ExtraHeaderTbl, DataBlock, DictBlock, CallBack, pl, filepath, tool )
				
				local blocks, block
				if (!DictBlock) then
					
					blocks = string.Explode("\n", DataBlock)
					
					local StrTbl = {}
					
					if HeaderTbl.Type == "Contraption Saver File" then
						for i = 2, (#blocks - 1) do
							local key,cstr = blocks[i]:match("(.-):(.+)")
							StrTbl[ key ] = cstr
						end
					else
						for i = 2, (#blocks - 1) do
							local key,cstr = blocks[i]:match("(.-):(.+)")
							StrTbl[ key ] = unquote(cstr)
						end
					end
					
					block = blocks[1]
					
					local function DWH3( HeaderTbl, ExtraHeaderTbl, block, StrTbl, CallBack, pl, filepath, tool )
						local OutputTable = Serialiser.DeserialiseBlock( block, StrTbl )
						CallBack( pl, filepath, tool, HeaderTbl, ExtraHeaderTbl, OutputTable )
					end
					
					AdvDupe.MakeTimer(.1, DWH3, {HeaderTbl, ExtraHeaderTbl, block, StrTbl, CallBack, pl, filepath, tool}, OnFailFunc, {pl, "Loading"} )
					
				else
					
					local StrTbl = {}
					for k,line in pairs(string.Explode("\n", DictBlock)) do
						local key,cstr = line:match("(.-):(.+)")
						if ( cstr ) then
							StrTbl[ key ] = unquote(cstr)
						end
					end
					
					local function DWH3( HeaderTbl, ExtraHeaderTbl, DataBlock, StrTbl, CallBack, pl, filepath, tool )
						
						local OutputTable = {}
						local delay = .1
						
						for k,line in pairs(string.Explode("\n", DataBlock)) do
							local key,block = line:match("(.-):(.+)")
							--Msg("DeserialiseBlock "..key.."\n")
							
							local function DWH4(block, StrTbl, OutputTable, k)
								AdvDupe.SetPercent(pl, 60 + (k * 10) )
								OutputTable[key] = Serialiser.DeserialiseBlock( block, StrTbl )
							end
							AdvDupe.MakeTimer( delay, DWH4, {block, StrTbl, OutputTable, k}, OnFailFunc, {pl, "Loading"} )
							delay = delay + .1
						end
						
						AdvDupe.SetPercent(pl, 60)
						AdvDupe.MakeTimer( delay, CallBack, {pl, filepath, tool, HeaderTbl, ExtraHeaderTbl, OutputTable}, OnFailFunc, {pl, "Loading"} )
						
						
					end
					
					AdvDupe.SetPercent(pl, 50)
					AdvDupe.MakeTimer(.1, DWH3, {HeaderTbl, ExtraHeaderTbl, DataBlock, StrTbl, CallBack, pl, filepath, tool}, OnFailFunc, {pl, "Loading"} )
					
				end
				
			end
			
			AdvDupe.SetPercent(pl, 40)
			AdvDupe.MakeTimer(.1, DWH3, {HeaderTbl, ExtraHeaderTbl, DataBlock, DictBlock, CallBack, pl, filepath, tool}, OnFailFunc, {pl, "Loading"} )
		end
		
		AdvDupe.SetPercent(pl, 30)
		AdvDupe.MakeTimer(.1, DWH2, {HeaderTbl, ExtraHeader, DataBlock, DictBlock, CallBack, pl, filepath, tool}, OnFailFunc, {pl, "Loading"} )
	end
	
	AdvDupe.SetPercent(pl, 20)
	AdvDupe.MakeTimer(.1, DWH1, {Header, ExtraHeader, DataBlock, DictBlock, CallBack, pl, filepath, tool}, OnFailFunc, {pl, "Loading"} )
	
end




function Serialiser.SingleTable( t, StrTbl, dontpoolstrings )
	
	local tables	= {}
	local headID = tostring(t):sub(8)
	local head	 = Serialiser.SerialiseTableKeyValues( t, tables, StrTbl, dontpoolstrings )
	
	// distinguish the main table from nested tables
	tables[headID] = nil
	tables["H"..headID] = head
	
	local str = ""
	for k,v in pairs( tables ) do
		// concat key values for each table
		str = str..k.."{".. table.concat( v, ";" ) ..";}"
	end
	
	return str
end




function Serialiser.SaveTablesToFile( pl, FileName, Header, ExtraHeader, NumOfEnts, EntTables, NumOfConst, ConstsTable, dontpoolstrings )
	
	local StrTbl = {}
	StrTbl.Strings = {} --keyed with string indexes
	StrTbl.StringIndx = {} --keyed with strings
	StrTbl.LastIndx = 0 --the index last used
	StrTbl.Saved = 0 --number of strings we didn't have to save
	
	--Msg("save0\n")
	local function save1( pl, FileName, Header, ExtraHeader, NumOfEnts, EntTables, NumOfConst, ConstsTable, StrTbl, dontpoolstrings )
		--Msg("save1\n")
		local EntsStr = Serialiser.SingleTable( EntTables, StrTbl, dontpoolstrings )
		
		local function save2( pl, FileName, Header, ExtraHeader, EntsStr, NumOfConst, ConstsTable, StrTbl, dontpoolstrings )
			--Msg("save2\n")
			local ConstsStr = Serialiser.SingleTable( ConstsTable, StrTbl, dontpoolstrings )
			
			local function save3( pl, FileName, Header, ExtraHeader, EntsStr, ConstsStr, StrTbl )
				--Msg("save3\n")
				//	save dict
				local Dict = {}
				for idx,cstr in pairs(StrTbl.Strings) do
					table.insert(Dict, table.concat( {idx, ":", cstr} ))
				end
				local DictStr = table.concat( Dict, "\n" ) .. "\nSaved:" .. StrTbl.Saved
				
				local function save4( pl, FileName, Header, ExtraHeader, EntsStr, ConstsStr, DictStr )
					--Msg("save4\n")
					local output = table.concat(
						{
							"[Info]",
							table.concat( Header, "\n" ),
							"[More Information]",
							table.concat( ExtraHeader, "\n" ),
							"[Save]",
							"Entities:"..EntsStr,
							"Constraints:"..ConstsStr,
							"[Dict]",
							DictStr
						}, "\n"
					)
					
					if Serialiser.SaveCompressed:GetBool() then
						if !dupeshare.ZLib_Installed then
							ErrorNoHalt("zlib_b64 not installed, cannot compresse file: ",filepath)
						else
							--MsgN("Serialiser save compressed file")
							output = "[zlib_b64]"..dupeshare.Compress(output, false, true)
						end
					end
					
					file.Write( FileName, output )
					
					AdvDupe.UpdateList(pl)
					AdvDupe.SetPercent(pl, 100)
					timer.Simple(.1, function() AdvDupe.SetPercent(pl, -1 ) end) -- hide progress bar
				end
				
				AdvDupe.SetPercent(pl, 75)
				AdvDupe.MakeTimer(.1, save4, {pl, FileName, Header, ExtraHeader, EntsStr, ConstsStr, DictStr}, OnFailFunc, {pl, "Saving"} )
			end
			
			AdvDupe.SetPercent(pl, 50)
			AdvDupe.MakeTimer(.1, save3, {pl, FileName, Header, ExtraHeader, EntsStr, ConstsStr, StrTbl}, OnFailFunc, {pl, "Saving"} )
		end
		
		AdvDupe.SetPercent(pl, 25)
		AdvDupe.MakeTimer(.1, save2, {pl, FileName, Header, ExtraHeader, EntsStr, NumOfConst, ConstsTable, StrTbl, dontpoolstrings}, OnFailFunc, {pl, "Saving"} )
	end
	
	AdvDupe.MakeTimer(.1, save1, {pl, FileName, Header, ExtraHeader, NumOfEnts, EntTables, NumOfConst, ConstsTable, StrTbl, false}, OnFailFunc, {pl, "Saving"} )
end
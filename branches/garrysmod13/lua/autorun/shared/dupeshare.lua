
dupeshare = {}
dupeshare.Version = 1.72

dupeshare.BaseDir		= "adv_duplicator"
dupeshare.PublicDirs	= { "=Public Folder=" }

//TODO
dupeshare.UsePWSys = false //don't change this

-- TODO get this to not print an error
dupeshare.ZLib_Installed = (pcall(function() require("zlib_b64") end))

if CLIENT then
	local i
	if dupeshare.ZLib_Installed then i = "1" else i = "0" end
	CreateClientConVar("ZLib_Installed", i, false, true)

	hook.Add("OnEntityCreated", "ZLib_Installed", function(ent)
		if ent ~= LocalPlayer() then return end

		RunConsoleCommand("ZLib_Installed",i)
	end)

	local function initplayer(um)
		dupeshare.ZLib_Installed_SV = um:ReadBool()
		--MsgN("AdvDupeShared: Server Compression: ",dupeshare.ZLib_Installed_SV)
	end
	usermessage.Hook( "adsh_initplayer", initplayer )
elseif SERVER then
	local function initplayer(ply)
		umsg.Start( "adsh_initplayer", ply )
			umsg.Bool(dupeshare.ZLib_Installed)
		umsg.End()
	end
	hook.Add( "PlayerInitialSpawn", "AdvDupeShPlayerInitSpawn", initplayer )
end


//this is only usfull for old saves, it doesn't do much for new ones.
dupeshare.DictionaryStart = 71
dupeshare.DictionarySize = 116
dupeshare.Dictionary = {
	[1]		= {"|MCl", "\"\n\t\t\t}\n\t\t\t\"class\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Class\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[2]		= {"|Mfz", "\"\n\t\t\t}\n\t\t\t\"frozen\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"frozen\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[3]		= {"|Mre", "\"\n\t\t\t}\n\t\t\t\"resistance\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"resistance\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[4]		= {"|Msp", "\"\n\t\t\t}\n\t\t\t\"speed\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"speed\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[5]		= {"|Mkd", "\"\n\t\t\t}\n\t\t\t\"key_d\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"key_d\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[6]		= {"|Mnc", "\"\n\t\t\t}\n\t\t\t\"NoCollide\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"nocollide\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[7]		= {"|Mdm", "\"\n\t\t\t}\n\t\t\t\"damageable\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"damageable\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[8]		= {"|Mkb", "\"\n\t\t\t}\n\t\t\t\"key_bck\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"key_bck\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[9]		= {"|Mfr", "\"\n\t\t\t}\n\t\t\t\"force\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"force\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[10]	= {"|Mky", "\"\n\t\t\t}\n\t\t\t\"key\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"key\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[11]	= {"|Mmd", "\"\n\t\t\t}\n\t\t\t\"model\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"model\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[12]	= {"|Mtg", "\"\n\t\t\t}\n\t\t\t\"toggle\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"toggle\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[13]	= {"|Mef", "\"\n\t\t\t}\n\t\t\t\"effect\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"effect\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[14]	= {"|ME1", "\"\n\t\t\t}\n\t\t\t\"Ent1\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Ent1\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[15]	= {"|ME2", "\"\n\t\t\t}\n\t\t\t\"Ent2\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Ent2\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[16]	= {"|MB1", "\"\n\t\t\t}\n\t\t\t\"Bone1\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Bone1\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[17]	= {"|MB2", "\"\n\t\t\t}\n\t\t\t\"Bone2\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Bone2\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[18]	= {"|Mtl", "\"\n\t\t\t}\n\t\t\t\"torquelimit\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"torquelimit\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[19]	= {"|Mty", "\"\n\t\t\t}\n\t\t\t\"type\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Type\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[20]	= {"|Mfl", "\"\n\t\t\t}\n\t\t\t\"forcelimit\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"forcelimit\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[21]	= {"|Mln", "\"\n\t\t\t}\n\t\t\t\"length\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"length\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[22]	= {"|MCI", "\"\n\t\t\t}\n\t\t\t\"ConstID\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"ConstID\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[23]	= {"|Mwd", "\"\n\t\t\t}\n\t\t\t\"width\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"width\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[24]	= {"|Mrg", "\"\n\t\t\t}\n\t\t\t\"rigid\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"rigid\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[25]	= {"|Mmt", "\"\n\t\t\t}\n\t\t\t\"material\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"material\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[26]	= {"|Mal", "\"\n\t\t\t}\n\t\t\t\"addlength\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"addlength\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[27]	= {"|MFI", "\"\n\t\t\t}\n\t\t\t\"FileInfo\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"FileInfo\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[28]	= {"|MND", "\"\n\t\t\t}\n\t\t\t\"NumOfDupeInfo\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"NumOfDupeInfo\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[29]	= {"|MNE", "\"\n\t\t\t}\n\t\t\t\"NumOfEnts\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"NumOfEnts\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[30]	= {"|MNC", "\"\n\t\t\t}\n\t\t\t\"NumOfConst\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"NumOfConst\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[31]	= {"|MCr", "\"\n\t\t\t}\n\t\t\t\"Creator\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Creator\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[32]	= {"|MDc", "\"\n\t\t\t}\n\t\t\t\"Desc\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Desc\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[33]	= {"|Mop", "\"\n\t\t\t}\n\t\t\t\"out_pos\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"out_pos\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[34]	= {"|Miw", "\"\n\t\t\t}\n\t\t\t\"ignore_world\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"ignore_world\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[35]	= {"|Mdz", "\"\n\t\t\t}\n\t\t\t\"default_zero\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"default_zero\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[36]	= {"|Msb", "\"\n\t\t\t}\n\t\t\t\"show_beam\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"show_beam\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[37]	= {"|Moa", "\"\n\t\t\t}\n\t\t\t\"out_ang\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"out_ang\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[38]	= {"|Mtw", "\"\n\t\t\t}\n\t\t\t\"trace_water\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"trace_water\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[39]	= {"|Mov", "\"\n\t\t\t}\n\t\t\t\"out_vel\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"out_vel\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[40]	= {"|Moc", "\"\n\t\t\t}\n\t\t\t\"out_col\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"out_col\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[41]	= {"|Moa", "\"\n\t\t\t}\n\t\t\t\"out_val\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"out_val\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[42]	= {"|Mod", "\"\n\t\t\t}\n\t\t\t\"out_dist\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"out_dist\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[43]	= {"|Mbd", "\"\n\t\t\t}\n\t\t\t\"doblastdamage\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"doblastdamage\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[44]	= {"|Mra", "\"\n\t\t\t}\n\t\t\t\"removeafter\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"removeafter\"\n\t\t\t\t\"__type\"\t\t\"Bool\"\n\t\t\t\t\"V\"\t\t\""},
	[45]	= {"|Mrd", "\"\n\t\t\t}\n\t\t\t\"radius\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"radius\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[46]	= {"|Mat", "\"\n\t\t\t}\n\t\t\t\"action\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"action\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[47]	= {"|Mkg", "\n\t\t\t\"keygroup\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"keygroup\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[48]	= {"|Mvo", "\"\n\t\t\t}\n\t\t\t\"value_off\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"value_off\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[49]	= {"|Mvn", "\"\n\t\t\t}\n\t\t\t\"value_on\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"value_on\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[50]	= {"|MAa", "\"\n\t\t\t}\n\t\t\t\"A\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"a\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[51]	= {"|MBb", "\"\n\t\t\t}\n\t\t\t\"B\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"b\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[52]	= {"|Mab", "\"\n\t\t\t}\n\t\t\t\"ab\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"ab\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[53]	= {"|Maa", "\"\n\t\t\t}\n\t\t\t\"aa\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"aa\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[54]	= {"|Mag", "\"\n\t\t\t}\n\t\t\t\"ag\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"ag\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[55]	= {"|Mbg", "\"\n\t\t\t}\n\t\t\t\"bg\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"bg\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[56]	= {"|Mba", "\"\n\t\t\t}\n\t\t\t\"ba\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"ba\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[57]	= {"|Mbb", "\"\n\t\t\t}\n\t\t\t\"bb\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"bb\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[58]	= {"|Mar", "\"\n\t\t\t}\n\t\t\t\"ar\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"ar\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[59]	= {"|Mbr", "\"\n\t\t\t}\n\t\t\t\"br\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"br\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[60]	= {"|MVe", "\"\n\t\t\t}\n\t\t\t\"Vel\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Vel\"\n\t\t\t\t\"__type\"\t\t\"Vector\"\n\t\t\t\t\"V\"\t\t\""},
	[61]	= {"|MaV", "\"\n\t\t\t}\n\t\t\t\"aVel\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"aVel\"\n\t\t\t\t\"__type\"\t\t\"Vector\"\n\t\t\t\t\"V\"\t\t\""},
	[62]	= {"|MSm", "\"\n\t\t\t}\n\t\t\t\"Smodel\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"Smodel\"\n\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\"V\"\t\t\""},
	[63]	= {"|MWw", "\"\n\t\t\t\t\t\t}\n\t\t\t\t\t\t\"width\"\n\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\"__name\"\t\t\"Width\"\n\t\t\t\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\t\t\t\"V\"\t\t\""},
	[64]	= {"|MWS", "\"\n\t\t\t\t\t\t}\n\t\t\t\t\t\t\"Src\"\n\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\"__name\"\t\t\"Src\"\n\t\t\t\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\t\t\t\"V\"\t\t\""},
	[65]	= {"|MWI", "\"\n\t\t\t\t\t\t}\n\t\t\t\t\t\t\"SrcId\"\n\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\"__name\"\t\t\"SrcId\"\n\t\t\t\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\t\t\t\"V\"\t\t\""},
	[66]	= {"|MWm", "\"\n\t\t\t\t\t\t}\n\t\t\t\t\t\t\"material\"\n\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\"__name\"\t\t\"material\"\n\t\t\t\t\t\t\t\"__type\"\t\t\"String\"\n\t\t\t\t\t\t\t\"V\"\t\t\""},
	[67]	= {"|MWD", "\"\n\t\t\t}\n\t\t\t\"DupeInfo\"\n\t\t\t{\n\t\t\t\t\"__name\"\t\t\"DupeInfo\"\n\t\t\t\t\"Wires\"\n\t\t\t\t{\n\t\t\t\t\t\"A\"\n\t\t\t\t\t{\n\t\t\t\t\t\t\"__name\"\t\t\"A\"\n\t\t\t\t\t\t\"SrcPos\"\n\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\"Y\"\t\t\""},
	[68]	= {"|MWB", "\"\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\t\"B\"\n\t\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\t\"__name\"\t\t\"b\"\n\t\t\t\t\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\t\t\t\t\"V\"\t\t\""},
	[69]	= {"|MWg", "\"\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\t\"g\"\n\t\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\t\"__name\"\t\t\"g\"\n\t\t\t\t\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\t\t\t\t\"V\"\t\t\""},
	[70]	= {"|MWr", "\"\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t\t\"r\"\n\t\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\t\"__name\"\t\t\"r\"\n\t\t\t\t\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\t\t\t\t\"V\"\t\t\""},
	[71]	= {"|mn", "\t\t\"__name\"\t\t"},
	[72]	= {"|mt", "\t\t\"__type\"\t\t"},
	[73]	= {"|mv", "\t\t\t\"V\"\t\t"},
	[74]	= {"|mD", "\t\t\t\"DupeInfo\""},
	[75]	= {"|mN", "\"Number\"\n"},
	[76]	= {"|mS", "\"String\"\n"},
	[77]	= {"|mA", "\"Angle\"\n"},
	[78]	= {"|mV", "\"Vector\"\n"},
	[79]	= {"|mB", "\"Bool\"\n"},
	[80]	= {"|mC", "\"Class\""},
	[81]	= {"|mm", "\"material\""},
	[82]	= {"|mp", "\"prop_physics\""},
	[83]	= {"|VI", "\t\t\"VersionInfo\"\n\t\t\"FileVersion\"\n\t\t{\n\t\t\t\t\"__name\"\t\t\"FileVersion\"\n\t\t\t\t\"__type\"\t\t\"Number\"\n\t\t\t\t\"V\"\t\t\""},
	[84]	= {"|wm", "\"models"},
	[85]	= {"|nC", "\n\t\t\t\"NoCollide\"\n\t\t\t{\n\t"},
	[86]	= {"|nc", "\"nocollide\"\n"},
	[87]	= {"|HE", "\"HeadEntID\"\n"},
	[88]	= {"|ha", "\n\t}\n\t\"holdangle\"\n\t{\n"},
	[89]	= {"|qY", "\t\t\"Y\"\t\t\""},
	[90]	= {"|qz", "\t\t\"z\"\t\t\""},
	[91]	= {"|qx", "\t\t\"x\"\t\t\""},
	[92]	= {"|qA", "\t\t\"A\"\t\t\""},
	[93]	= {"|qB", "\t\t\"B\"\t\t\""},
	[94]	= {"|qg", "\t\t\"g\"\t\t\""},
	[95]	= {"|qr", "\t\t\"r\"\t\t\""},
	[96]	= {"|qp", "\t\t\"p\"\t\t\""},
	[97]	= {"|HA", "\"HoldAngle\"\n"},
	[98]	= {"Ωth", "\t\t{\n\t\t\t\"^Class\"\t\t\"Sgmod_thruster\"\n\t\t\t\"nocollide\"\t\t\"Btrue\"\n\t\t\t\"effect\"\t\t"},
	[99]	= {"Ωpp", "\t\t{\n\t\t\t\"^Class\"\t\t\"Sprop_physics\"\n\t\t\t\"^Model\"\t\t\"S"},
	[100]	= {"ΩLA", "\t\t\t\"^Local^Angle\"\t\t\"A"},
	[101]	= {"ΩLP", "\t\t\t\"^Local^Pos\"\t\t\"V"},
	[102]	= {"Ωpo", "\t\t\t\"^Physics^Objects\""},
	[103]	= {"ΩPs", "\t\t\t\"^Pos\"\t\t\"V"},
	[104]	= {"ΩAn", "\t\t\t\"^Angle\"\t\t\"A"},
	[105]	= {"ΩEM", "\t\t\t\"^Entity^Mods\""},
	[106]	= {"ΩCl", "\t\t\t\"^Class\"\t\t\"S"},
	[107]	= {"ΩCG", "\t\t\t\t\"^Collision^Group^Mod\"\t\t\"N"},
	[108]	= {"ΩRD", "\t\t\t\t\"^R^D^Dupe^Info\""},
	[109]	= {"|8", "\t\t\t\t\t\t\t\t"},
	[110]	= {"|7", "\t\t\t\t\t\t\t"},
	[111]	= {"|6", "\t\t\t\t\t\t"},
	[112]	= {"|5", "\t\t\t\t\t"},
	[113]	= {"|4", "\t\t\t\t"},
	[114]	= {"|3", "\t\t\t"},
	[115]	= {"|2", "\t\t"},
	[116]	= {"|N", "name"},
}

local char_map = {
	["\n"] = "É",
	["\t"] = "Ü",
	["\""] = "•",
	["'"]  = "§"
}

local inv_char_map = {
	["É"] = "\n",
	["Ü"] = "\t",
	["•"] = "\"",
	["á"] = "\"",
	["§"] = "'"
}

function dupeshare.Compress(str, ForConCommand, usezlib)

	local beforelen = string.len(str)

	if usezlib and dupeshare.ZLib_Installed then

		if ( str:sub(1,10) == "[zlib_b64]" ) then
			--MsgN("dupeshare.Compress file compressed already")
			str = str:sub(11)
		else
			str = zlib.Compress(str, 9):Encode()
		end

	else
		if ( str:sub(1,10) == "[zlib_b64]" ) then
			if !dupeshare.ZLib_Installed then
				ErrorNoHalt("zlib_b64 not installed, cannot uncompresse file\n")
				return
			end
			--MsgN("dupeshare.Compress uncompressed file")
			str = dupeshare.DeCompress(str:sub(11), false, true)
		end

		if ( string.Left(str, 5) == "\"Out\"") then
			for k = dupeshare.DictionaryStart,dupeshare.DictionarySize do
				local entry = dupeshare.Dictionary[k]
				str = string.gsub(str, entry[2], entry[1])
			end
		end

		if (ForConCommand) then //ÑÖàâäãåçéèêëíìîïñóòôöõúùûü†°¢£§¶ß®©™ unused special chars
			for k, _ in pairs (inv_char_map) do
				str = string.gsub (str, k, "|" .. k)
			end
			for k, v in pairs (char_map) do
				str = string.gsub (str, k, v)
			end
		end
	end

	--local afterlen = string.len(str)
	--MsgN("String Compressed: ",afterlen," / ",beforelen," ( ",(math.Round((afterlen / beforelen) * 10000) / 100),"% )")

	return str
end

function dupeshare.DeCompress(str, FormConCommand, usezlib)

	local afterlen = string.len(str)

	if usezlib and dupeshare.ZLib_Installed then

		str = b64.Decode(str):Decompress()

	else
		for k=dupeshare.DictionarySize,dupeshare.DictionaryStart,-1 do
			local entry = dupeshare.Dictionary[k]
			str = string.gsub(str, entry[1], entry[2])
		end

		if (FormConCommand) then
			for k, v in pairs (inv_char_map) do
				str = string.gsub (str, "(." .. k .. ")", function (s)
					if s:sub (1, 1) == "|" then
						return k
					end
					return s:sub (1, 1) .. v
				end)
			end
		end
	end

	--local beforelen = string.len(str)
	--MsgN("String Decompressed: ",afterlen," / ",beforelen," ( ",(math.Round((afterlen / beforelen) * 10000) / 100),"% )")

	return str
end


//removes illegal characters from file names
dupeshare.BadChars = {"\\", "/", ":", "*", "?", "\"", "<", ">", "¶", "|", "'"}

function dupeshare.ReplaceBadChar(str)
	for _,entry in pairs(dupeshare.BadChars) do
		str = string.gsub(str, entry, "_")
	end
	return str
end

function dupeshare.GetPlayerName(pl)
	local name = pl:GetName() or "unknown"
	name = dupeshare.ReplaceBadChar(name)
	return name
end


function dupeshare.NamedLikeAPublicDir(dir)
	dir = string.lower(dir)
	for k, v in pairs(dupeshare.PublicDirs) do
		if dir == string.lower(v) then return true end
	end
	return false
end


//checks if the player's active weapon is a duplicator
function dupeshare.CurrentToolIsDuplicator(tool)
	if (tool) and (tool:GetClass() == "gmod_tool" ) and ( tool:GetTable():GetToolObject() )
	and (tool:GetTable():GetToolObject().Name == "#AdvancedDuplicator") then
		return true
	else
		return false
	end
end




/*---------------------------------------------------------
	table util functions
---------------------------------------------------------*/

/*---------------------------------------------------------
   Name: dupeshare.RebuildTableFromLoad( table )
   Desc: Removes the protection added by PrepareTableToSave
		after table is loaded with KeyValuesToTable
---------------------------------------------------------*/
function dupeshare.RebuildTableFromLoad_Old( t, done )

	local done = done or {}
	local tbl = {}

	for k, v in pairs ( t ) do
		if ( type( v ) == "table" and !done[ v ] ) then
			done[ v ] = true
			if ( v.__type ) then
				if ( v.__type == "Vector" ) then
					tbl[ v.__name ] = Vector( v.x, v.y, v.z )
				elseif ( v.__type == "Angle" ) then
					tbl[ v.__name ] = Angle( v.p, v.y, v.r )
				elseif ( v.__type == "Bool" ) then
					tbl[ v.__name ] = util.tobool( v.v )
				elseif ( v.__type == "Number" ) then
					tbl[ v.__name ] = tonumber( v.v )
				elseif ( v.__type == "String" ) then
					tbl[ v.__name ] = tostring( v.v )
				end
			else
				tbl[ v.__name ] = dupeshare.RebuildTableFromLoad_Old ( v, done )
			end
		else
			if k != "__name" then //don't add the table names to output
				tbl[ k ] = v
			end
		end
	end

	return tbl

end
function dupeshare.RebuildTableFromLoad( t, done, StrTbl )

	local done = done or {}
	local tbl = {}
	local StrTbl = StrTbl or {}

	for k, v in pairs ( t ) do
		local CaseKey = dupeshare.UnprotectCase(k, StrTbl)
		if ( type( v ) == "table" and !done[ v ] ) then
			done[ v ] = true
			tbl[ CaseKey ] = dupeshare.RebuildTableFromLoad( v, done, StrTbl )
		else
			local t = string.sub(v,1,1)
			local d = string.sub(v,2)
			if ( t == "V" ) then
				d = string.Explode(" ", d)
				--Msg("Vector: "..tostring(Vector( tonumber(d[1]), tonumber(d[2]), tonumber(d[3]) )).."\n")
				tbl[ CaseKey ] = Vector( tonumber(d[1]), tonumber(d[2]), tonumber(d[3]) )
			elseif (t == "A" ) then
				d = string.Explode(" ", d)
				--Msg("Angle: "..tostring(Angle( d[1], d[2], d[3] )).."\n")
				tbl[ CaseKey ] = Angle( tonumber(d[1]), tonumber(d[2]), tonumber(d[3]) )
			elseif ( t == "B" ) then
				tbl[ CaseKey ] = util.tobool( d )
			elseif ( t == "T" ) then //bool true
				tbl[ CaseKey ] = true
			elseif ( t == "F" ) then //bool false
				tbl[ CaseKey ] = false
			elseif ( t == "N" ) then
				tbl[ CaseKey ] = tonumber( d )
			elseif ( t == "&" ) then //pooled comon strngs
				tbl[ CaseKey ] = tostring( dupeshare.StringDictionary[ tonumber(d) ] )
			elseif ( t == "*" ) then //pooled comon strngs
				tbl[ CaseKey ] = tostring( StrTbl[ d ] )
			elseif ( t == "S" ) then
				tbl[ CaseKey ] = tostring( d )
			else
				tbl[ CaseKey ] = v
			end
		end
	end

	return tbl

end

function dupeshare.UnprotectCase(str, StrTbl)
	local str2 = ""

	//index was a number, make it so and return
	local k = string.sub(str,1,1)
	if (k == "#") then
		return tonumber(string.sub(str,2))
	elseif (k == "&") then
		return dupeshare.StringDictionary[ tonumber(string.sub(str,2)) ]
	elseif (k == "*") then
		return StrTbl[ string.sub(str,2) ]
	end

	//make char fallowing a carrot a capatical
	for i = 1, string.len(str) do
		local chr = string.sub(str, i, i)
		if (string.sub(str, i-1, i-1) == "^") then chr = string.upper(chr) end
		if chr != "^" then str2 = str2..chr end
	end
	--Msg("  str= "..str.." > "..str2)
	return str2
end



//from http://lua-users.org/wiki/StringRecipes
function dupeshare.split(str, pat)
   local t = {}
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end


/*---------------------------------------------------------
	file and folder util functions
---------------------------------------------------------*/
/*---------------------------------------------------------
	Check if dir and filename exist and if so renames
	returns filepath (dir.."/"..filename..".txt")
---------------------------------------------------------*/
function dupeshare.FileNoOverWriteCheck( dir, filename )

	if !file.Exists(dir, "DATA") then
		file.CreateDir(dir, "DATA")
	elseif !file.IsDir(dir, "DATA") then
		local x = 0
		while x ~= nil do
			x = x + 1
			if not file.Exists(dir.."_"..tostring(x), "DATA") then
				dir = dir.."_"..tostring(x)
				file.CreateDir(dir, "DATA")
				x = nil
			end
		end
	end

	if file.Exists(dir .. "/" .. filename .. ".txt", "DATA") then
		local x = 0
		while x ~= nil do
			x = x + 1
			if not file.Exists(dir.."/"..filename.."_"..tostring(x)..".txt", "DATA") then
				filename = filename.."_"..tostring(x)
				x = nil
			end
		end
	end

	local filepath = dir .. "/" .. filename .. ".txt"

	return filepath, filename, dir
end

function dupeshare.GetFileFromFilename(path)

	for i = string.len(path), 1, -1 do
		local str = string.sub(path, i, i)
		if str == "/" or str == "\\" then path = string.sub(path, (i + 1)) end
	end

	//removed .txt from the end if its there.
	if (string.sub(path, -4) == ".txt") then
		path = string.sub(path, 1, -5)
	end

	return path
end

function dupeshare.UpDir(path)

	for i = string.len(path), 1, -1 do
		local str = string.sub(path, i, i)
		if str == "/" then
			return string.sub(path, 1, (i - 1))
		end
	end

	return "" //if path/.. is root
end

function dupeshare.ParsePath(path)
	path = string.gsub(path,"/","\\")

	local gpath = ""
	local tpath = ""

	for i=1,string.len(path) do
		local chr = string.byte(path,i) //FIXME
		if ((chr >= 32) and (chr <= 126)) then
			tpath = tpath .. string.char(chr)
			if (chr ~= 32) then
				gpath = gpath .. string.char(chr)
			end
		end
	end

	if ((string.find(gpath,"\\%.%.") ~= nil) ||
	    (string.find(gpath,"%.%.\\") ~= nil) ||
	    (string.find(gpath,"%.\\") ~= nil) ||
	    (string.find(gpath,"\\%.") ~= nil)) then
		return "adv_duplicator\\_"
	else
		return tpath
	end
end



--Msg("==== Advanced Duplicator v."..dupeshare.Version.." shared module installed! ====\n")
if (!duplicator.EntityClasses) then Msg("=== Error: Your gmod is out of date! ===\n=== You'll want to fix that or the Advanced Duplicator is not going to work. ===\n") end

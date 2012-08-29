if (SERVER) then return end

AdvDupeClient={}

include( "autorun/shared/dupeshare.lua" )

AdvDupeClient.version = 1.741

//
//	Upload settings
//
local MaxUploadLength = 180
local UploadPiecesPerSend = 4
local UploadSendDelay = 0.15
local MaxUploadSize = 0
local CanDownload = true

local function RcvUploadSettings( um )
	MaxUploadLength = um:ReadShort()
	UploadPiecesPerSend = um:ReadShort()
	UploadSendDelay = um:ReadShort() / 100
end
usermessage.Hook("AdvDupeUploadSettings", RcvUploadSettings)

local function RcvMaxUploadSize( um )
	MaxUploadSize = um:ReadShort()
end
usermessage.Hook("AdvDupeMaxUploadSize", RcvMaxUploadSize)
function AdvDupeClient.CanUpload()
	if (MaxUploadSize >= 0 ) then return true end
end
local function GetMaxUpload()
	return MaxUploadSize * 1024
end

local function RcvCanDownload( um )
	CanDownload = um:ReadBool()
end
usermessage.Hook("AdvDupeCanDownload", RcvCanDownload)
function AdvDupeClient.CanDownload()
	return CanDownload
end
//
//	Upload functions
//
//function AdvDupeClient.SendSaveDataToServer(offset, last)
local function SendSaveDataToServer(offset, last)
	if ( !AdvDupeClient.temp2 ) then return end
	
	for i = 1,UploadPiecesPerSend do
		if (offset <= last) then
			if ( AdvDupeClient.PercentText == "Uploading" ) then
				AdvDupeClient.UpdatePercent( math.ceil( offset / last * 100 ) )
			end
			
			local SubStrStart = (offset - 1) * MaxUploadLength
			
			local str = ""
			if (offset == last) then
				str = AdvDupeClient.temp2:sub( SubStrStart )
				
				--Msg("sending last string\n")
				AdvDupeClient.UpdatePercent( 100 )
				timer.Simple(.2, AdvDupeClient.UpdatePercent, -1)
			else
				str = AdvDupeClient.temp2:sub( SubStrStart, SubStrStart + MaxUploadLength - 1 )
			end
			
			RunConsoleCommand("_DFC", tostring(offset), str)
		end
		offset = offset + 1
	end
	
	if (offset > last) then
		timer.Simple( 1, function() RunConsoleCommand("DupeRecieveFileContentFinish") end )
	else
		timer.Simple( UploadSendDelay, SendSaveDataToServer, offset, last )
	end
	
end

local function HaltUpload( um )
	AdvDupeClient.temp2 = nil
	AdvDupeClient.sending = false
	AdvDuplicator_UpdateControlPanel()
end
usermessage.Hook("AdvDupeHaltUpload", HaltUpload)

function AdvDupeClient.UpLoadFile( pl, filepath )
	
	if (AdvDupeClient.sending) or (!AdvDupeClient.CanUpload()) then return end
	if !file.Exists(filepath, "DATA")then print("File not found") return end
	
	local filename = dupeshare.GetFileFromFilename(filepath)
	
	//load from file
	AdvDupeClient.temp2 = file.Read(filepath)
	
	local compress = dupeshare.ZLib_Installed_SV and dupeshare.ZLib_Installed
	
	AdvDupeClient.temp2 = dupeshare.Compress(AdvDupeClient.temp2, true, compress)	
	
	//this is where we send the data to the serer
	local len = string.len(AdvDupeClient.temp2)
	local last = math.ceil(len / MaxUploadLength)
	
	if ( GetMaxUpload() > 0 and (last - 1) * MaxUploadLength > GetMaxUpload() ) then
		AdvDupeClient.Error( "File is larger than server limit ("..GetMaxUpload().."K)" )
		AdvDupeClient.temp2 = nil
		return
	end
	AdvDupeClient.temp2last = last
	
	--pl:ConCommand("DupeRecieveFileContentStart "..tostring(last).." \""..string.gsub(filename,".txt","").."\"")
	RunConsoleCommand("DupeRecieveFileContentStart", tostring(last), string.gsub(filename,".txt",""))
end
	
	
local function SendOK(um)
	AdvDupeClient.SetPercentText( "Uploading" )
	
	timer.Simple( 0.2, SendSaveDataToServer, 1, AdvDupeClient.temp2last ) --TODO: wait from server ok to start uploading
	
	AdvDupeClient.sending = true
	AdvDuplicator_UpdateControlPanel()
end
usermessage.Hook("AdvDupeClientSendOK", SendOK)


local function SendFinished( um )
	AdvDupeClient.temp2 = nil
	AdvDupeClient.temp2last = nil
	AdvDupeClient.sending = false
	AdvDuplicator_UpdateControlPanel()
end
usermessage.Hook("AdvDupeClientSendFinished", SendFinished)

local function SendFinishedFailed( um )
	--i don' think this did any good
	/*if (UploadSendDelay < .5) then
		UploadSendDelay = UploadSendDelay + 0.05
		Msg("AdvDupe: increasing UploadSendDelay to "..UploadSendDelay.."\n")
	elseif (UploadPiecesPerSend > 1) then
		UploadPiecesPerSend = UploadPiecesPerSend - 1
		Msg("AdvDupe: decreasing UploadPiecesPerSend to "..UploadPiecesPerSend.."\n")
	else
		Msg("AdvDupeERROR: UploadSendDelay and UploadPiecesPerSend maxed to .5 and 1, there's a problem if it's failed this many times.\n")
	end*/
	AdvDupeClient.temp2 = nil
	AdvDupeClient.sending = false
	AdvDuplicator_UpdateControlPanel()
end
usermessage.Hook("AdvDupeClientSendFinishedFailed", SendFinishedFailed)



//
//	Download functions
//
local RecieveBuffer = {}
local function ClientRecieveSaveStart( um )
	--Msg("=========  ClientRecieveSaveStart  ==========\n")
	RecieveBuffer = {}
	RecieveBuffer.pieces = {}
	
	RecieveBuffer.numofpieces	= um:ReadShort()
	RecieveBuffer.filename		= um:ReadString()
	RecieveBuffer.compress		= um:ReadBool()
	RecieveBuffer.dir			= AdvDupeClient.CLcdir
	
	RecieveBuffer.recievedpieces = 0
	AdvDupeClient.downloading = true
	AdvDuplicator_UpdateControlPanel()
	
	--Msg("AdvDupeClient: Clear to recieve file \""..RecieveBuffer.filename.."\" in "..RecieveBuffer.numofpieces.." pieces\n")
	--Msg("NumToRecieve= "..AdvDupeClient.temp.numofpieces.."\n==========\n")
	AdvDupeClient.SetPercentText( "Downloading" )
end
usermessage.Hook("AdvDupeRecieveSaveStart", ClientRecieveSaveStart)

local function ClientRecieveSaveData( um )
	local piece	= um:ReadShort()
	local temp	= um:ReadString()
	RecieveBuffer.recievedpieces = RecieveBuffer.recievedpieces + 1
	
	--Msg("getting file data, piece: "..piece.." of "..RecieveBuffer.numofpieces.."\n")
	if ( AdvDupeClient.PercentText == "Downloading" ) then
		AdvDupeClient.UpdatePercent( math.ceil( piece / RecieveBuffer.numofpieces * 100 ) )
	end
	
	RecieveBuffer.pieces[piece] = temp
	
	if (RecieveBuffer.recievedpieces >= RecieveBuffer.numofpieces) then
		--MsgN("recieved last piece")
		AdvDupeClient.UpdatePercent( 100 )
		timer.Simple(.5, AdvDupeClient.UpdatePercent, -1)
		AdvDupeClient.ClientSaveRecievedFile()
	end
end
usermessage.Hook("AdvDupeRecieveSaveData", ClientRecieveSaveData)

function AdvDupeClient.ClientSaveRecievedFile()
	
	local filepath, filename = dupeshare.FileNoOverWriteCheck( RecieveBuffer.dir, RecieveBuffer.filename )
	
	//reassemble the pieces
	local temp = table.concat(RecieveBuffer.pieces)
	
	if Serialiser.SaveCompressed:GetBool() and dupeshare.ZLib_Installed then
		--MsgN("AdvDupe, ClientSaveRecievedFile: save compressed file")
		if RecieveBuffer.compress then
			temp = "[zlib_b64]"..temp
		else
			temp = "[zlib_b64]"..dupeshare.Compress(temp, false, true)
		end
	else
		temp = dupeshare.DeCompress(temp, false, RecieveBuffer.compress)
	end
	
	file.Write(filepath, temp)
	
	AdvDupeClient.Error( "Your file: \""..filepath.."\" was downloaded from the server", false, true )
	MsgN("Your file: \""..filepath.."\" was downloaded from the server")
	
	RunConsoleCommand("adv_duplicator_updatelist")
	
end

local function DownloadFinished( um )
	AdvDupeClient.downloading = false
	AdvDuplicator_UpdateControlPanel()
end
usermessage.Hook("AdvDupeClientDownloadFinished", DownloadFinished)




	
local function FileOptsCommand(pl, cmd, args)
	if ( !pl:IsValid() ) or ( !pl:IsPlayer() ) or ( !args[1] ) then return end
	
	local action = args[1]
	local filename = dupeshare.GetFileFromFilename(pl:GetInfo( "adv_duplicator_load_filename_cl" ))..".txt"
	//local filename2 = pl:GetInfo( "adv_duplicator_open_cl2" )
	local dir	= AdvDupeClient.CLcdir
	local dir2	= AdvDupeClient.CLcdir2
	
	AdvDupeClient.FileOpts(action, filename, dir, dir2)
	
end
concommand.Add("adv_duplicator_cl_fileopts", FileOptsCommand)

function AdvDupeClient.FileOpts(action, filename, dir, dir2)
	if ( !action ) or ( !filename ) or ( !dir ) then return end
	
	local file1 = dir.."/"..filename
	--Msg("action= "..action.."  filename= "..filename.."  dir= "..dir.."  dir2= "..(dir2 or "none").."\n")
	
	if (action == "delete") then
		
		file.Delete(file1, "DATA")
		LocalPlayer():ConCommand("adv_duplicator_updatelist")
		
	elseif (action == "copy") then
		
		local file2 = dir2.."/"..filename
		if file.Exists(file2, "DATA") then
			local filename2 = ""
			file2, filename2 = dupeshare.FileNoOverWriteCheck(dir2, filename)
			AdvDupeClient.Error("File Exists at Destination, Renamed to: "..filename2)
		end
		file.Write(file2, file.Read(file1))
		LocalPlayer():ConCommand("adv_duplicator_updatelist")
		
	elseif action == "move" then
		
		AdvDupeClient.FileOpts("copy", filename, dir, dir2)
		AdvDupeClient.FileOpts("delete", filename, dir)
		
	elseif (action == "makedir") then
		
		if file.Exists(file1, "DATA") and file.IsDir(file1) then 
			AdvDupeClient.Error("Folder Already Exists!")
			return
		end
		
		file.CreateDir(file1, "DATA")
		LocalPlayer():ConCommand("adv_duplicator_updatelist")
		
	elseif action == "rename" then
		
		AdvDupeClient.FileOpts("duplicate", filename, dir, dir2)
		AdvDupeClient.FileOpts("delete", filename, dir)
		
	elseif action == "duplicate" then
		
		local file2 = dir.."/"..dir2 //using dir2 to hold the new filename
		if file.Exists(file2, "DATA") then
			local filename2 = ""
			file2, filename2 = dupeshare.FileNoOverWriteCheck(dir, dir2)
			AdvDupeClient.Error("File Exists With That Name Already, Renamed as: "..filename2)
		end
		file.Write(file2, file.Read(file1))
		LocalPlayer():ConCommand("adv_duplicator_updatelist")
		
	else
		AdvDupeClient.Error( "FileOpts: Unknown Action!")
	end
	
end





//simple error msg display
function AdvDupeClient.Error( errormsg, NoSound, NotError )
	if !errormsg then return end
	if (NotError) then
		GAMEMODE:AddNotify( "AdvDupe: "..tostring(errormsg), NOTIFY_GENERIC, 10 );
	else
		GAMEMODE:AddNotify( "AdvDupe-ERROR: "..tostring(errormsg), NOTIFY_ERROR, 10 );
	end
	if (!NoSound) then
		if (NotError) then
			surface.PlaySound("ambient/water/drip"..math.random(1, 4)..".wav")
		else
			surface.PlaySound( "buttons/button10.wav" )
		end
	end
end

local function AdvDupeCLError( um )
	AdvDupeClient.Error( um:ReadString(), um:ReadBool() )
end
usermessage.Hook("AdvDupeCLError", AdvDupeCLError)

local function AdvDupeCLInfo( um )
	AdvDupeClient.Error( um:ReadString(), um:ReadBool(), true )
end
usermessage.Hook("AdvDupeCLInfo", AdvDupeCLInfo)




local function SetPasting( um )
	AdvDupeClient.Pasting = um:ReadBool()
end
usermessage.Hook("AdvDupeSetPasting", SetPasting)






//HUD progress bar stuff
//kinda based on wired HUD indicators (TheApathic), but most everything was replaced to make it work as a single centered progress bar
//TODO: this is a mess, needs clean up
AdvDupeClient.Factor = 0
surface.SetFont("Default")
local pwidth, pheight = surface.GetTextSize("NoColliding: 100%")
pheight = pheight + 16
local halfpwidth = pwidth / 2
local halfpheight = pheight / 2
local bw1 = halfpwidth + 6
local bw2 = pwidth + 12
local fh1 = 3
local fh2 = pheight - 6
local bcolor = Color(150, 150, 255, 190)
local fcolor = Color(150, 255, 150, 240)
local txtcolor = Color(0, 0, 0, 255)

local function DrawProgressBar()
	if (AdvDupeClient.Done) and (AdvDupeClient.Done > -1) then
		local w1 = AdvDupeClient.hudx - math.floor(AdvDupeClient.Factor * halfpwidth) - 4
		local w2 = math.floor(AdvDupeClient.Factor * pwidth) + 8
		draw.RoundedBox(6, (AdvDupeClient.hudx - bw1), AdvDupeClient.hudy, bw2, pheight, bcolor)
		draw.RoundedBox(4, w1, (AdvDupeClient.hudy + fh1), w2, fh2, fcolor)
		local txt
		if ( AdvDupeClient.PercentText == "Copying..." ) then
			txt = AdvDupeClient.PercentText
		else
			txt = AdvDupeClient.PercentText..": "..AdvDupeClient.Done.."%"
		end
		draw.SimpleText(txt, "Default", AdvDupeClient.hudx, (AdvDupeClient.hudy + halfpheight), txtcolor, 1, 1)
	end
end
hook.Add("HUDPaint", "AdvDupeProgressBar", DrawProgressBar)


function AdvDupeClient.UpdatePercent( Percent )
	AdvDupeClient.Done = Percent
	AdvDupeClient.Factor = AdvDupeClient.Done / 100
end

local function UpdatePercent( um )
	AdvDupeClient.UpdatePercent( um:ReadShort() )
end
usermessage.Hook("AdvDupe_Update_Percent", UpdatePercent)

function AdvDupeClient.SetPercentText( PercentText )
	AdvDupeClient.PercentText = PercentText
	AdvDupeClient.Done = 0
	AdvDupeClient.Factor = 0
	
	AdvDupeClient.hudx = ScrW() / 2
	AdvDupeClient.hudy = ScrH() / 1.8
	
	surface.SetFont("Default")
	pwidth, pheight = surface.GetTextSize(AdvDupeClient.PercentText..": 100%")
	pheight = pheight + 16
	halfpwidth = pwidth / 2
	halfpheight = pheight / 2
	bw1 = halfpwidth + 6
	bw2 = pwidth + 12
	fh2 = pheight - 6
end

local function StartPercent( um ) 
	AdvDupeClient.SetPercentText( um:ReadString() )
end
usermessage.Hook("AdvDupe_Start_Percent", StartPercent)






AdvDupeClient.res = {}
-- vgui code partly adapted from Night-Eagle's HUD Module
AdvDupeClient.res.Basic = [[
"basic.res"
{
	"basic"
	{
		"ControlName"		"Frame"
		"fieldName"		"basic"
		"xpos"		"475"
		"ypos"		"355"
		"zpos"		"290"
		"wide"		"400"
		"tall"		"66"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"settitlebarvisible"		"1"
		"title"		"%TITLE%"
		"sizable"		"0"
	}
	"frame_topGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_topGrip"
		"xpos"		"8"
		"ypos"		"0"
		"wide"		"384"
		"tall"		"5"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
}
]]

function AdvDupeClient.res.gengui(caption)
	return string.gsub(AdvDupeClient.res.Basic,"%%TITLE%%",caption)
end

AdvDupeClient.gui = {}

function AdvDupeClient.SaveGUI( pl, command, args )
	if (!AdvDupeClient.Copied) then return end
	
	RunConsoleCommand("adv_duplicator_hideghost", 1)
	
	if !AdvDupeClient.gui.save or !AdvDupeClient.gui.save.frame then
		AdvDupeClient.gui.save = {}
		AdvDupeClient.gui.save.frame = vgui.Create( "DFrame" )
		AdvDupeClient.gui.save.frame:SetTitle("AdvDupe Save:")
		AdvDupeClient.gui.save.frame:SetDeleteOnClose(false)
		AdvDupeClient.gui.save.frame:SetSize(320,135)
		AdvDupeClient.gui.save.frame:Center()
		
		AdvDupeClient.gui.save.lblFile = vgui.Create("DLabel",AdvDupeClient.gui.save.frame,"lblFile")
		AdvDupeClient.gui.save.lblFile:SetPos(6,25)
		AdvDupeClient.gui.save.lblFile:SetSize(185,25)
		AdvDupeClient.gui.save.lblFile:SetText("Filename:")
		
		AdvDupeClient.gui.save.lblDesc = vgui.Create("DLabel",AdvDupeClient.gui.save.frame,"lblDesc")
		AdvDupeClient.gui.save.lblDesc:SetPos(6,65)
		AdvDupeClient.gui.save.lblDesc:SetSize(185,25)
		AdvDupeClient.gui.save.lblDesc:SetText("Description:")
		
		AdvDupeClient.gui.save.btnSave = vgui.Create("DButton",AdvDupeClient.gui.save.frame,"btnSave")
		AdvDupeClient.gui.save.btnSave:SetPos(184,110)
		AdvDupeClient.gui.save.btnSave:SetSize(110,20)
		AdvDupeClient.gui.save.btnSave:SetText("Save")
		function AdvDupeClient.gui.save.btnSave:DoClick()
			local filename	= AdvDupeClient.gui.save.txtFile:GetValue()
			local desc		= AdvDupeClient.gui.save.txtDesc:GetValue()
			
			LocalPlayer():ConCommand("adv_duplicator_save \""..filename.."\" \""..desc.."\"")
			
			AdvDupeClient.gui.save.frame:Close()
		end
		
		AdvDupeClient.gui.save.txtFile = vgui.Create("DTextEntry",AdvDupeClient.gui.save.frame,"txtFile")
		AdvDupeClient.gui.save.txtFile:SetPos(6,45)
		AdvDupeClient.gui.save.txtFile:SetWide(290)
		
		AdvDupeClient.gui.save.txtDesc = vgui.Create("DTextEntry",AdvDupeClient.gui.save.frame,"txtDesc")
		AdvDupeClient.gui.save.txtDesc:SetPos(6,85)
		AdvDupeClient.gui.save.txtDesc:SetWide(290)
		
		function AdvDupeClient.gui.save.txtFile:OnEnter()
			AdvDupeClient.gui.save.btnSave:DoClick()
		end
	end
	
	AdvDupeClient.gui.save.txtFile:SetText("")
	AdvDupeClient.gui.save.txtDesc:SetText("")
	
	AdvDupeClient.gui.save.frame:MakePopup()
	AdvDupeClient.gui.save.frame:SetKeyBoardInputEnabled( true )
	AdvDupeClient.gui.save.frame:SetMouseInputEnabled( true )
	AdvDupeClient.gui.save.frame:SetVisible( true )
	
end
concommand.Add( "adv_duplicator_save_gui", AdvDupeClient.SaveGUI )

function AdvDupeClient.MakeDir( pl, command, args )
	if !args or !args[1] then return end
	
	LocalPlayer():ConCommand("adv_duplicator_hideghost 1")
	
	if !AdvDupeClient.gui.makedir or !AdvDupeClient.gui.makedir.frame then
		AdvDupeClient.gui.makedir = {}
		AdvDupeClient.gui.makedir.frame = vgui.Create( "DFrame" )
		AdvDupeClient.gui.makedir.frame:SetTitle("Make Folder:")
		AdvDupeClient.gui.makedir.frame:SetDeleteOnClose(false)
		AdvDupeClient.gui.makedir.frame:SetSize(320,135)
		AdvDupeClient.gui.makedir.frame:Center()
		
		AdvDupeClient.gui.makedir.btnMakeDir = vgui.Create("DButton",AdvDupeClient.gui.makedir.frame,"btnMakeDir")
		AdvDupeClient.gui.makedir.btnMakeDir:SetPos(184,110)
		AdvDupeClient.gui.makedir.btnMakeDir:SetSize(110,20)
		AdvDupeClient.gui.makedir.btnMakeDir:SetText("Make Folder")
		function AdvDupeClient.gui.makedir.btnMakeDir:DoClick()
			if AdvDupeClient.gui.makedir.key == "MakeDirServer" then
				local dir = tostring(AdvDupeClient.gui.makedir.txtDir:GetValue())
				
				if (dupeshare.UsePWSys) and (!SinglePlayer()) then
					local pass	= AdvDupeClient.gui.makedir.txtPass:GetValue()
					LocalPlayer():ConCommand("adv_duplicator_makedir \""..dir.."\" \""..pass.."\"")
				else
					LocalPlayer():ConCommand("adv_duplicator_makedir \""..dir.."\"")
				end
				
				AdvDupeClient.gui.makedir.frame:SetVisible(false)
			elseif AdvDupeClient.gui.makedir.key == "MakeDirClient" then
				local newdir = dupeshare.ReplaceBadChar( AdvDupeClient.gui.makedir.txtDir:GetValue() )
				local dir	= AdvDupeClient.CLcdir
				
				AdvDupeClient.FileOpts("makedir", newdir, dir)
				
				AdvDupeClient.gui.makedir.frame:SetVisible(false)
			end
			
			AdvDupeClient.gui.makedir.frame:Close()
		end
		
		AdvDupeClient.gui.makedir.lblDir = vgui.Create("Label",AdvDupeClient.gui.makedir.frame,"lblDir")
		AdvDupeClient.gui.makedir.lblDir:SetPos(6,65)
		AdvDupeClient.gui.makedir.lblDir:SetSize(185,25)
		
		AdvDupeClient.gui.makedir.txtDir = vgui.Create("DTextEntry",AdvDupeClient.gui.makedir.frame,"txtDir")
		AdvDupeClient.gui.makedir.txtDir:SetPos(6,45)
		AdvDupeClient.gui.makedir.txtDir:SetWide(290)
		function AdvDupeClient.gui.makedir.txtDir:OnEnter()
			AdvDupeClient.gui.makedir.btnMakeDir:DoClick()
		end
	end
	
	AdvDupeClient.gui.makedir.txtDir:SetText("")
	
	if args[1] == "client" then
		AdvDupeClient.gui.makedir.key = "MakeDirClient"
		AdvDupeClient.gui.makedir.lblDir:SetText("Name for new folder in \""..string.gsub(AdvDupeClient.CLcdir, dupeshare.BaseDir, "").."\"")
	else
		AdvDupeClient.gui.makedir.key = "MakeDirServer"
		AdvDupeClient.gui.makedir.lblDir:SetText("Name for new folder in \""..string.gsub(AdvDupeClient.SScdir, dupeshare.BaseDir, "").."\"")
	end
	
	AdvDupeClient.gui.makedir.frame:MakePopup()
	AdvDupeClient.gui.makedir.frame:SetKeyBoardInputEnabled( true )
	AdvDupeClient.gui.makedir.frame:SetMouseInputEnabled( true )
	AdvDupeClient.gui.makedir.frame:SetVisible( true )
end
concommand.Add( "adv_duplicator_makedir_gui", AdvDupeClient.MakeDir )

function AdvDupeClient.RenameFile( pl, cmd, args )
	if !args or !args[1] then return end
	
	LocalPlayer():ConCommand("adv_duplicator_hideghost 1")
	
	if !AdvDupeClient.gui.rename or !AdvDupeClient.gui.rename.frame then
		AdvDupeClient.gui.rename = {}
		AdvDupeClient.gui.rename.frame = vgui.Create( "DFrame" )
		AdvDupeClient.gui.rename.frame:SetTitle("Rename File:")
		AdvDupeClient.gui.rename.frame:SetDeleteOnClose(false)
		AdvDupeClient.gui.rename.frame:SetSize(320,135)
		AdvDupeClient.gui.rename.frame:Center()
		
		AdvDupeClient.gui.rename.btnRename = vgui.Create("DButton",AdvDupeClient.gui.rename.frame,"btnRename")
		AdvDupeClient.gui.rename.btnRename:SetPos(184,110)
		AdvDupeClient.gui.rename.btnRename:SetSize(110,20)
		AdvDupeClient.gui.rename.btnRename:SetText("Rename")
		function AdvDupeClient.gui.rename.btnRename:DoClick()
			if AdvDupeClient.gui.rename.key == "RenameServer" then
				local newname = AdvDupeClient.gui.rename.txtNewName:GetValue()
				Msg("newname= "..newname.."\n")
				
				LocalPlayer():ConCommand("adv_duplicator_fileoptsrename \""..newname.."\"")
				
				AdvDupeClient.gui.rename.frame:SetVisible(false)
			elseif AdvDupeClient.gui.rename.key == "RenameClient" then
				local newname	= dupeshare.ReplaceBadChar(dupeshare.GetFileFromFilename(AdvDupeClient.gui.rename.txtNewName:GetValue()))..".txt"
				local filename = dupeshare.GetFileFromFilename(pl:GetInfo( "adv_duplicator_load_filename_cl" ))..".txt"
				local dir	= AdvDupeClient.CLcdir
				
				AdvDupeClient.FileOpts("rename", filename, dir, newname)
				
				AdvDupeClient.gui.rename.frame:SetVisible(false)
			end
			
			AdvDupeClient.gui.rename.frame:Close()
		end
		
		AdvDupeClient.gui.rename.lblNewName = vgui.Create("Label",AdvDupeClient.gui.rename.frame,"lblNewName")
		AdvDupeClient.gui.rename.lblNewName:SetPos(6,65)
		AdvDupeClient.gui.rename.lblNewName:SetSize(185,25)
		
		AdvDupeClient.gui.rename.txtNewName = vgui.Create("DTextEntry",AdvDupeClient.gui.rename.frame,"txtNewName")
		AdvDupeClient.gui.rename.txtNewName:SetPos(6,45)
		AdvDupeClient.gui.rename.txtNewName:SetWide(290)
		function AdvDupeClient.gui.rename.txtNewName:OnEnter()
			AdvDupeClient.gui.rename.btnRename:DoClick()
		end
	end
	
	if args[1] == "client" then
		AdvDupeClient.gui.rename.key = "RenameClient"
		
		local oldfilename = dupeshare.GetFileFromFilename(pl:GetInfo( "adv_duplicator_load_filename_cl" ))
		AdvDupeClient.gui.rename.lblNewName:SetText("New name for \""..oldfilename..".txt\" in \""..string.gsub(AdvDupeClient.CLcdir, dupeshare.BaseDir, "").."/ ")
		AdvDupeClient.gui.rename.txtNewName:SetText(oldfilename)
	else
		AdvDupeClient.gui.rename.key = "RenameServer"
		
		local oldfilename = dupeshare.GetFileFromFilename(pl:GetInfo( "adv_duplicator_load_filename" ))
		AdvDupeClient.gui.rename.lblNewName:SetText("New name for \""..oldfilename..".txt\" in \""..string.gsub(AdvDupeClient.SScdir, dupeshare.BaseDir, "").."/ ")
		AdvDupeClient.gui.rename.txtNewName:SetText(oldfilename)
	end
	
	AdvDupeClient.gui.rename.frame:MakePopup()
	AdvDupeClient.gui.rename.frame:SetKeyBoardInputEnabled( true )
	AdvDupeClient.gui.rename.frame:SetMouseInputEnabled( true )
	AdvDupeClient.gui.rename.frame:SetVisible( true )
end
concommand.Add( "adv_duplicator_renamefile_gui", AdvDupeClient.RenameFile )

function AdvDupeClient.ConfirmDelete( pl, cmd, args )
	if !args or !args[1] then return end
	
	LocalPlayer():ConCommand("adv_duplicator_hideghost 1")
	
	if !AdvDupeClient.gui.delete or !AdvDupeClient.gui.delete.frame then
		AdvDupeClient.gui.delete = {}
		AdvDupeClient.gui.delete.frame = vgui.Create( "DFrame" )
		AdvDupeClient.gui.delete.frame:SetTitle("Delete File?")
		AdvDupeClient.gui.delete.frame:SetDeleteOnClose(false)
		AdvDupeClient.gui.delete.frame:SetSize(320,135)
		AdvDupeClient.gui.delete.frame:Center()
		
		AdvDupeClient.gui.delete.btnDelete = vgui.Create("DButton",AdvDupeClient.gui.delete.frame,"btnDelete")
		AdvDupeClient.gui.delete.btnDelete:SetPos(20,110)
		AdvDupeClient.gui.delete.btnDelete:SetSize(110,20)
		AdvDupeClient.gui.delete.btnDelete:SetText("Delete!")
		function AdvDupeClient.gui.delete.btnDelete:DoClick()
			if AdvDupeClient.gui.delete.key == "DeleteServer" then
				LocalPlayer():ConCommand("adv_duplicator_fileopts delete")
				AdvDupeClient.gui.delete.frame:SetVisible(false)
			elseif AdvDupeClient.gui.delete.key == "DeleteClient" then
				local filename = pl:GetInfo( "adv_duplicator_open_cl" )
				local dir	= AdvDupeClient.CLcdir
				AdvDupeClient.FileOpts("delete", filename, dir)
				AdvDupeClient.gui.delete.frame:SetVisible(false)
			elseif key == "Cancel" then
				AdvDupeClient.gui.delete.frame:SetVisible(false)
			end
			AdvDupeClient.gui.delete.frame:Close()
		end
		
		AdvDupeClient.gui.delete.btnCancel = vgui.Create("DButton",AdvDupeClient.gui.delete.frame,"btnCancel")
		AdvDupeClient.gui.delete.btnCancel:SetPos(184,110)
		AdvDupeClient.gui.delete.btnCancel:SetSize(110,20)
		AdvDupeClient.gui.delete.btnCancel:SetText("Cancel")
		AdvDupeClient.gui.delete.btnCancel:SetCommand("Cancel")
		function AdvDupeClient.gui.delete.btnCancel:DoClick()
			AdvDupeClient.gui.delete.frame:Close()
		end
		
		AdvDupeClient.gui.delete.lblFileName = vgui.Create("Label",AdvDupeClient.gui.delete.frame,"lblFileName")
		AdvDupeClient.gui.delete.lblFileName:SetPos(6,25)
		AdvDupeClient.gui.delete.lblFileName:SetSize(185,25)
	end
	
	if args[1] == "client" then
		AdvDupeClient.gui.delete.key = "DeleteClient"
		
		local oldfilename = dupeshare.GetFileFromFilename(pl:GetInfo( "adv_duplicator_load_filename_cl" ))
		AdvDupeClient.gui.delete.lblFileName:SetText("Delete this file \""..oldfilename..".txt\" from \""..string.gsub(AdvDupeClient.CLcdir, dupeshare.BaseDir, "").."/ ?")
	else
		AdvDupeClient.gui.delete.key = "DeleteServer"
		
		local oldfilename = dupeshare.GetFileFromFilename(pl:GetInfo( "adv_duplicator_load_filename" ))
		AdvDupeClient.gui.delete.lblFileName:SetText("Delete this file \""..oldfilename..".txt\" from \""..string.gsub(AdvDupeClient.SScdir, dupeshare.BaseDir, "").."/ ?")
	end
	
	AdvDupeClient.gui.delete.frame:MakePopup()
	AdvDupeClient.gui.delete.frame:SetKeyBoardInputEnabled( true )
	AdvDupeClient.gui.delete.frame:SetMouseInputEnabled( true )
	AdvDupeClient.gui.delete.frame:SetVisible( true )
	
end
concommand.Add( "adv_duplicator_confirmdelete_gui", AdvDupeClient.ConfirmDelete )


--Msg("==== Advanced Duplicator v."..AdvDupeClient.version.." client module installed! ====\n")


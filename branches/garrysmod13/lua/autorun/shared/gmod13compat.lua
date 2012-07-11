local libs = {
	"file",
	"datastream",
	"language"
}

if VERSION < 150 then
	if not datastream then require("datastream") end
	function datastream.__prepareStream(streamID) end

	-- gmod 12 => use installed lib
	for _,libName in pairs(libs) do
		local lib12Name = libName.."12"

		local lib = _G[libName]
		_G[lib12Name] = lib
	end

	return
end
-- gmod 13 => use compatibility lib
for _,libName in pairs(libs) do
	local lib12Name = libName.."12"

	local lib = _G[libName]
	if _G[lib12Name] then return end -- Already loaded
	-- make copies of everything and override some of them
	_G[lib12Name] = lib and table.Copy(lib) or {}
end

function file12.Exists(path, useBaseDir)
	return file.Exists(path, useBaseDir and "GAME" or "DATA")
end

function file12.FindInLua(path)
	return file.Find(path, LUA_PATH)
end

function file12.Find(path, useBaseDir)
	return file.Find(path, useBaseDir and "GAME" or "DATA")
end

function file12.FindDir(path, useBaseDir)
	local files,folders = file12.Find(path, useBaseDir and "GAME" or "DATA")
	return folders
end

function file12.IsDir(path, useBaseDir)
	return file.IsDir(path, useBaseDir and "GAME" or "DATA")
end

utilx = util or {}

if SERVER then
	function datastream12.__prepareStream(streamID)
		util.AddNetworkString("ds12_"..streamID)
	end

	function datastream12.Hook(streamID, callback)
		net.Receive("ds12_" .. streamID, function(len, ply)
			local tbl = net.ReadTable()
			callback(ply, streamID, "", glon.encode(tbl), tbl)
		end)
	end
	function datastream12.StreamToClients(player, streamID, data)
		net.Start("ds12_"..streamID)
			net.WriteTable(data)
		net.Send(player)
	end
else
	language12.OAdd = language12.Add
	function language12.Add(phrase, text)
		if phrase:find("^Tool_") then
			local alsoadd = phrase:gsub("^Tool_(.*)_(.*)$", "tool.%1.%2")
			language12.OAdd(alsoadd, text)
		end
		return language12.OAdd(phrase, text)
	end
	function datastream12.StreamToServer(streamID, data)
		net.Start("ds12_" .. streamID)
			net.WriteTable(data)
		net.SendToServer()
	end
	function datastream12.Hook(streamID, callback)
		net.Receive("ds12_"..streamID, function(len) callback( streamID, id, nil, net.ReadTable() ) end )
	end
	cam.StartMaterialOverride = render.MaterialOverride
	SetMaterialOverride = render.MaterialOverride
	surface.CreateFont("defaultbold", 12, 700, true, false, "DefaultBold")
end

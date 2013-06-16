TOOL.Category		= "Render"
TOOL.Name			= "#Tool.colmat.name"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar[ "spawned" ]	= 0
TOOL.ClientConVar[ "material" ]	= "models/debug/debugwhite"
TOOL.ClientConVar[ "r" ]		= 255
TOOL.ClientConVar[ "g" ]		= 255
TOOL.ClientConVar[ "b" ]		= 255
TOOL.ClientConVar[ "a" ]		= 255
TOOL.ClientConVar[ "mode" ]		= 0
TOOL.ClientConVar[ "fx" ]		= 0
TOOL.ClientConVar[ "LastMatList" ]		= "OverrideMaterialsDefault"

if ( CLIENT ) then
	language.Add( "Tool.colmat.name",	"ColorMater" )
	language.Add( "Tool.colmat.desc",	"Changes color and material in one" )
	language.Add( "Tool.colmat.0", " Left: apply material and color, Right: to remove, Reload: copy" )
	language.Add( "Tool_colmat_material", "Material:" )
	language.Add( "Tool_colmat_materiallist", "Material List:" )
	language.Add( "Tool_colmat_spawned", "Apply to spawned props:" )
end

local LastMatList = "OverrideMaterialsDefault"
local Lists = {}

local function SetMaterial( Player, Entity, Data )
	if string.lower( Data.MaterialOverride ) == "pp/copy" then return end
	Entity:SetMaterial( Data.MaterialOverride )
	if ( SERVER ) then duplicator.StoreEntityModifier( Entity, "material", Data ) end
	return true
end

local function SetColour( Player, Entity, Data )
	if ( Data.Color ) then 
		Entity:SetColor( Data.Color )
		if Data.Color.a != 255 and Data.RenderMode == 0 then Data.RenderMode = 1 end
	end
	if ( Data.RenderMode ) then Entity:SetRenderMode( Data.RenderMode ) end
	if ( Data.RenderFX ) then Entity:SetKeyValue( "renderfx", Data.RenderFX ) end
	if ( SERVER ) then duplicator.StoreEntityModifier( Entity, "colour", Data ) end
end


function TOOL:LeftClick( trace )
	if ( trace.Entity:IsWorld() ) then return false end
	if (CLIENT) then return true end

	local mat 	= self:GetClientInfo( "material" )
	local r		= self:GetClientNumber( "r", 0 )
	local g		= self:GetClientNumber( "g", 0 )
	local b		= self:GetClientNumber( "b", 0 )
	local a		= self:GetClientNumber( "a", 0 )
	local mode	= self:GetClientNumber( "mode", 0 )
	local fx	= self:GetClientNumber( "fx", 0 )

	SetMaterial( self:GetOwner(), trace.Entity, { MaterialOverride = mat } )

	SetColour( self:GetOwner(), trace.Entity, { Color = Color( r, g, b, a ), RenderMode = mode, RenderFX = fx } )

	return true

end


function TOOL:RightClick( trace )
	if ( trace.Entity:IsWorld() ) then return false end
	if (CLIENT) then return true end

	SetMaterial( self:GetOwner(), trace.Entity, { MaterialOverride = "" } )

	SetColour( self:GetOwner(), trace.Entity, { Color = Color( 255, 255, 255, 255 ), RenderMode = 0, RenderFX = 0 } )

	return true
end


function TOOL:Reload( trace )
	if ( trace.Entity:IsWorld() ) then return false end
	if (CLIENT) then return true end

	local mat = trace.Entity:GetMaterial()
	local col = trace.Entity:GetColor()
	local fx = trace.Entity:GetKeyValues().renderfx or 0

	self:GetOwner():ConCommand("colmat_material "..mat)
	self:GetOwner():ConCommand("colmat_r "..col.r)
	self:GetOwner():ConCommand("colmat_g "..col.g)
	self:GetOwner():ConCommand("colmat_b "..col.b)
	self:GetOwner():ConCommand("colmat_a "..col.a)
	self:GetOwner():ConCommand("colmat_mode ".."0") --we can't get render mode so reset it to 0
	self:GetOwner():ConCommand("colmat_fx "..fx)

	return true
end


if ( CLIENT ) then
	function ColMat_UpdateControlPanel( ListName , CPanel )
		if (!CPanel) then CPanel = controlpanel.Get( "colmat" ) end
		if (!CPanel) then return end

		LastMatList = ListName

		CPanel:ClearControls()

		CPanel:AddControl( "Header", { Text = "#Tool.colmat.name", Description	= "#Tool.colmat.desc" }  )


		CPanel:AddControl("ComboBox", {
			Label = "#Tool_colmat_materiallist",
			Options = list.Get( "MaterialsLists" )
		} )


		CPanel:AddControl( "MatSelect", {
			Height = "3",
			Label = "#Tool_colmat_material",
			ItemWidth = 84,
			ItemHeight = 84,
			ConVar = "colmat_material",
			Options = list.Get( ListName )
		} )


		if (!Lists[ListName]) then
			Lists[ListName] = {}
			for _,mat in pairs(list.Get( ListName )) do
				Lists[ListName]["\""..mat.."\""] = { colmat_material = mat }
			end
		end

		CPanel:AddControl("ComboBox", {
			Label = "#Tool_colmat_material",
			MenuButton = 0,
			Options={},
			CVars = "colmat_material",
			Options = Lists[ListName]
		} )


		CPanel:AddControl( "Color", {
			Label = "#Tool_colour_colour",
			Red = "colmat_r",
			Green = "colmat_g",
			Blue = "colmat_b",
			Alpha = "colmat_a",
			ShowAlpha = 1,
			ShowHSV = 1,
			ShowRGB = 1,
			Multiplier = 255
		} )


		local Options = {}
		Options["#Normal"]			= { ID = "0", colmat_mode = "0" }
		Options["#TransColor"]		= { ID = "1", colmat_mode = "1" }
		Options["#TransTexture"]	= { ID = "2", colmat_mode = "2" }
		Options["#Glow"]			= { ID = "3", colmat_mode = "3" }
		Options["#TransAlpha"]		= { ID = "4", colmat_mode = "4" }
		Options["#TransAdd"]		= { ID = "5", colmat_mode = "5" }
		Options["#TransAlphaAdd"]	= { ID = "8", colmat_mode = "8" }
		Options["#WorldGlow"]		= { ID = "9", colmat_mode = "9" }

		CPanel:AddControl("ComboBox", {
			Label		= "#Tool_colour_mode",
			MenuButton	= "0",
			Command		= "colmat_mode",
			Options		= Options
		} )


		local Options = {}
		Options["#None"]			= { ID = "0", colmat_fx = 0 }
		Options["#PulseSlow"]		= { ID = "1", colmat_fx = 1 }
		Options["#PulseFast"]		= { ID = "2", colmat_fx = 2 }
		Options["#PulseSlowWide"]	= { ID = "3", colmat_fx = 3 }
		Options["#PulseFastWide"]	= { ID = "4", colmat_fx = 4 }
		Options["#FadeSlow"]		= { ID = "5", colmat_fx = 5 }
		Options["#FadeFast"]		= { ID = "6", colmat_fx = 6 }
		Options["#SolidSlow"]		= { ID = "7", colmat_fx = 7 }
		Options["#SolidFast"]		= { ID = "8", colmat_fx = 8 }
		Options["#StrobeSlow"]		= { ID = "9", colmat_fx = 9 }
		Options["#StrobeFast"]		= { ID = "10", colmat_fx = 10 }
		Options["#StrobeFaster"]	= { ID = "11", colmat_fx = 11 }
		Options["#FlickerSlow"]		= { ID = "12", colmat_fx = 12 }
		Options["#FlickerFast"]		= { ID = "13", colmat_fx = 13 }
		Options["#Distort"]			= { ID = "15", colmat_fx = 15 }
		Options["#Hologram"]		= { ID = "16", colmat_fx = 16 }
		Options["#PulseFastWider"]	= { ID = "25", colmat_fx = 25 }

		CPanel:AddControl("ComboBox", {
			Label		= "#Tool_colour_fx",
			MenuButton	= "0",
			Command		= "colmat_fx",
			Options		= Options
		} )


		CPanel:AddControl( "CheckBox", {
			Label = "#Tool_colmat_spawned",
			Command = "colmat_spawned"
		} )

	end


	local function SetMaterialList( pl, command, args )
		--Msg("matlistchnage\n")
		if !args[1] then return end

		for k,v in pairs(list.Get( "MaterialsLists" ) ) do
			--Msg("checking "..k.."\n")
			if ( args[1] == v.colmat_materiallist  ) then
				ColMat_UpdateControlPanel( args[1] )
				return
			end
		end

	end
	concommand.Add( "colmat_materiallist", SetMaterialList )

end


function TOOL.BuildCPanel( CPanel )

	CPanel:AddControl( "Header", { Text = "#Tool.colmat.name", Description	= "#Tool.colmat.desc" }  )

	ColMat_UpdateControlPanel( LastMatList, CPanel )

end



//Special crap
if ( SERVER ) then
	function ApplyColMatSpawned( pl, model, ent )
		if pl:GetInfoNum( "colmat_spawned", 0 ) == 1 then

			local mat 	= pl:GetInfo( "colmat_material" )
			local r		= pl:GetInfoNum( "colmat_r", 0 )
			local g		= pl:GetInfoNum( "colmat_g", 0 )
			local b		= pl:GetInfoNum( "colmat_b", 0 )
			local a		= pl:GetInfoNum( "colmat_a", 0 )
			local mode	= pl:GetInfoNum( "colmat_mode", 0 )
			local fx	= pl:GetInfoNum( "colmat_fx", 0 )

			SetMaterial( pl, ent, { MaterialOverride = mat } )

			SetColour( pl, ent, { Color = Color( r, g, b, math.Clamp( a, 100, 255 ) ), RenderMode = mode, RenderFX = fx } )

		end
	end
	hook.Add( "PlayerSpawnedProp", "ApplyColMatSpawned", ApplyColMatSpawned )
	hook.Add( "PlayerSpawnedRagdoll", "ApplyColMatSpawned", ApplyColMatSpawned )
end


//
//	The extra materials lists
//	235 more materials! Plus the default 37 = 272!!!
//	List were filtered to remove duplicates

//list of the lists of materials
list.Set( "MaterialsLists", "Default",				{ colmat_LastMatList = "OverrideMaterialsDefault", colmat_materiallist = "OverrideMaterialsDefault" })
list.Set( "MaterialsLists", "Extra Materials 3.0",	{ colmat_LastMatList = "OverrideMaterialsMore", colmat_materiallist = "OverrideMaterialsMore" })
list.Set( "MaterialsLists", "PHX",					{ colmat_LastMatList = "OverrideMaterialsPHX", colmat_materiallist = "OverrideMaterialsPHX" })
list.Set( "MaterialsLists", "Material EX",			{ colmat_LastMatList = "OverrideMaterialsEX", colmat_materiallist = "OverrideMaterialsEX" })
list.Set( "MaterialsLists", "Extras",				{ colmat_LastMatList = "OverrideMaterialsExtra", colmat_materiallist = "OverrideMaterialsExtra" })
list.Set( "MaterialsLists", "All",					{ colmat_LastMatList = "OverrideMaterials", colmat_materiallist = "OverrideMaterials" })


//Default ones so we can list them with out any others that may have added
list.Add( "OverrideMaterialsDefault", "models/wireframe" )
list.Add( "OverrideMaterialsDefault", "debug/env_cubemap_model" )
list.Add( "OverrideMaterialsDefault", "models/shadertest/shader3" )
list.Add( "OverrideMaterialsDefault", "models/shadertest/shader4" )
list.Add( "OverrideMaterialsDefault", "models/shadertest/shader5" )
list.Add( "OverrideMaterialsDefault", "models/shiny" )
list.Add( "OverrideMaterialsDefault", "models/debug/debugwhite" )
list.Add( "OverrideMaterialsDefault", "Models/effects/comball_sphere" )
list.Add( "OverrideMaterialsDefault", "Models/effects/comball_tape" )
list.Add( "OverrideMaterialsDefault", "Models/effects/splodearc_sheet" )
list.Add( "OverrideMaterialsDefault", "Models/effects/vol_light001" )
list.Add( "OverrideMaterialsDefault", "models/props_combine/stasisshield_sheet" )
list.Add( "OverrideMaterialsDefault", "models/props_combine/portalball001_sheet" )
list.Add( "OverrideMaterialsDefault", "models/props_combine/com_shield001a" )
list.Add( "OverrideMaterialsDefault", "models/props_c17/frostedglass_01a" )
list.Add( "OverrideMaterialsDefault", "models/props_lab/Tank_Glass001" )
list.Add( "OverrideMaterialsDefault", "models/props_combine/tprings_globe" )
list.Add( "OverrideMaterialsDefault", "models/rendertarget" )
list.Add( "OverrideMaterialsDefault", "models/screenspace" )
list.Add( "OverrideMaterialsDefault", "brick/brick_model" )
list.Add( "OverrideMaterialsDefault", "models/props_pipes/GutterMetal01a" )
list.Add( "OverrideMaterialsDefault", "models/props_pipes/Pipesystem01a_skin3" )
list.Add( "OverrideMaterialsDefault", "models/props_wasteland/wood_fence01a" )
list.Add( "OverrideMaterialsDefault", "models/props_foliage/tree_deciduous_01a_trunk" )
list.Add( "OverrideMaterialsDefault", "models/props_c17/FurnitureFabric003a" )
list.Add( "OverrideMaterialsDefault", "models/props_c17/FurnitureMetal001a" )
list.Add( "OverrideMaterialsDefault", "models/props_c17/paper01" )
list.Add( "OverrideMaterialsDefault", "models/flesh" )


//Extra Materials 3.0
list.Add( "OverrideMaterialsMore", "models/props_c17/metalladder001" )
list.Add( "OverrideMaterialsMore", "models/props_c17/metalladder002" )
list.Add( "OverrideMaterialsMore", "models/props_c17/metalladder003" )
list.Add( "OverrideMaterialsMore", "models/props_debris/metalwall001a" )
list.Add( "OverrideMaterialsMore", "models/props_canal/metalwall005b" )
list.Add( "OverrideMaterialsMore", "models/props_combine/metal_combinebridge001" )
list.Add( "OverrideMaterialsMore", "models/props_interiors/metalfence007a" )
list.Add( "OverrideMaterialsMore", "models/props_pipes/pipeset_metal02" )
list.Add( "OverrideMaterialsMore", "models/props_pipes/pipeset_metal" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/metal_tram001a" )
list.Add( "OverrideMaterialsMore", "models/props_canal/metalcrate001d" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/rockcliff02b" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/rockcliff02c" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/rockcliff04a" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/rockcliff02a" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/dirtwall001a" )
list.Add( "OverrideMaterialsMore", "models/props_foliage/oak_tree01" )
list.Add( "OverrideMaterialsMore", "models/props_combine/combinethumper002" )
list.Add( "OverrideMaterialsMore", "models/props_combine/tprotato1_sheet" )
list.Add( "OverrideMaterialsMore", "models/props_combine/pipes01" )
list.Add( "OverrideMaterialsMore", "models/combine_advisor/body9" )
list.Add( "OverrideMaterialsMore", "models/props_c17/furniturefabric002a" )
list.Add( "OverrideMaterialsMore", "models/props_debris/plasterwall021a" )
list.Add( "OverrideMaterialsMore", "models/props_debris/plasterwall009d" )
list.Add( "OverrideMaterialsMore", "models/props_debris/plasterwall034a" )
list.Add( "OverrideMaterialsMore", "models/props_debris/plasterwall039c" )
list.Add( "OverrideMaterialsMore", "models/props_debris/plasterwall040c" )
list.Add( "OverrideMaterialsMore", "models/props_debris/concretefloor013a" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/concretefloor010a" )
list.Add( "OverrideMaterialsMore", "models/props_debris/concretewall019a" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/concretewall064b" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/concretewall066a" )
list.Add( "OverrideMaterialsMore", "models/props_lab/warp_sheet" )
list.Add( "OverrideMaterialsMore", "models/combine_scanner/scanner_eye" )
list.Add( "OverrideMaterialsMore", "models/props_debris/building_template012d" )
list.Add( "OverrideMaterialsMore", "models/props_combine/tprings_sheet" )
list.Add( "OverrideMaterialsMore", "models/weapons/v_crowbar/crowbar_cyl" )
list.Add( "OverrideMaterialsMore", "models/weapons/v_stunbaton/w_shaft01a" )
list.Add( "OverrideMaterialsMore", "models/props_wasteland/lighthouse_stairs" )
list.Add( "OverrideMaterialsMore", "models/props_c17/frostedglass_01a_dx60" )
list.Add( "OverrideMaterialsMore", "models/props_canal/rock_riverbed01a" )
list.Add( "OverrideMaterialsMore", "models/props_canal/canalmap_sheet" )
list.Add( "OverrideMaterialsMore", "models/props_canal/coastmap_sheet" )
list.Add( "OverrideMaterialsMore", "models/effects/slimebubble_sheet" )
list.Add( "OverrideMaterialsMore", "models/props_lab/generatorconsole_disp" )
list.Add( "OverrideMaterialsMore", "models/props_combine/combine_interface_disp" )
list.Add( "OverrideMaterialsMore", "models/props_combine/health_charger_glass" )
list.Add( "OverrideMaterialsMore", "models/props_lab/xencrystal_sheet" )
list.Add( "OverrideMaterialsMore", "models/weapons/v_crossbow/rebar_glow" )
list.Add( "OverrideMaterialsMore", "models/props_combine/prtl_sky_sheet" )
list.Add( "OverrideMaterialsMore", "models/vortigaunt/pupil" )
list.Add( "OverrideMaterialsMore", "models/combine_advisor/mask" )


//PHX Materials
list.Add( "OverrideMaterialsPHX", "phoenix_storms/Airboat" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/Blue_steel" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/FuturisticTrackRamp_1-2" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/Indenttiles2" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/Indenttiles_1-2" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/MetalSet_1-2" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/Metalfloor_2-3" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/OfficeWindow_1-1" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/airboat_blur02" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/amraam" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/barrel" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/barrel_fps" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/black_chrome" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/bluemetal" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/bomb" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/camera" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/cannon" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/car_tire" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/chrome" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/cigar" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/cube" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/dome" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/dome_side" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/egg" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/explo_barrel" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/fender" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/fender_chrome" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/fender_white" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/fender_wood" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/future_vents" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/gear" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/gear_top" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/glass" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/grey_chrome" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/grey_steel" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/heli" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/iron_rails" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/lag_sign" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/metal" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/metal_plate" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/metal_wheel" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/metalbox" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/metalbox2" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/metalfence004a" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/middle" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/mrref2" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/mrtire" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/output_jack" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/plastic" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/point1" )
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/black")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/bluelight")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/chrome")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/darkblue")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/darkgrey")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/glass")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/interior_sides")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/interior_top")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/metalbox2")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/panel")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/redlight")
list.Add( "OverrideMaterialsPHX", "phoenix_storms/pack2/train_floor")


//Even more materials from Material EX
//HL2
list.Add( "OverrideMaterialsEX", "models/airboat/airboat_blur02" )
list.Add( "OverrideMaterialsEX", "models/alyx/emptool_glow" )
list.Add( "OverrideMaterialsEX", "models/antlion/antlion_innards" )
list.Add( "OverrideMaterialsEX", "models/barnacle/roots" )
list.Add( "OverrideMaterialsEX", "models/dog/eyeglass" )
list.Add( "OverrideMaterialsEX", "models/effects/comball_glow1" )
list.Add( "OverrideMaterialsEX", "models/effects/comball_glow2" )
list.Add( "OverrideMaterialsEX", "models/effects/portalrift_sheet" )
list.Add( "OverrideMaterialsEX", "models/effects/splode1_sheet" )
list.Add( "OverrideMaterialsEX", "models/effects/splode_sheet" )
list.Add( "OverrideMaterialsEX", "models/error/new light1" )
list.Add( "OverrideMaterialsEX", "models/gibs/woodgibs/woodgibs01" )
list.Add( "OverrideMaterialsEX", "models/gibs/woodgibs/woodgibs02" )
list.Add( "OverrideMaterialsEX", "models/gibs/woodgibs/woodgibs03" )
list.Add( "OverrideMaterialsEX", "models/gibs/metalgibs/metal_gibs" )
list.Add( "OverrideMaterialsEX", "models/items/boxsniperrounds" )
list.Add( "OverrideMaterialsEX", "models/player/player_chrome1" )
list.Add( "OverrideMaterialsEX", "models/props_animated_breakable/smokestack/brickwall002a" )
list.Add( "OverrideMaterialsEX", "models/props_building_details/courtyard_template001c_bars" )
list.Add( "OverrideMaterialsEX", "models/props_buildings/destroyedbuilldingwall01a" )
list.Add( "OverrideMaterialsEX", "models/props_c17/furniturefabric001a" )
list.Add( "OverrideMaterialsEX", "models/props_c17/gate_door02a" )
list.Add( "OverrideMaterialsEX", "models/props_canal/canal_bridge_railing_01a" )
list.Add( "OverrideMaterialsEX", "models/props_canal/canal_bridge_railing_01b" )
list.Add( "OverrideMaterialsEX", "models/props_canal/canal_bridge_railing_01c" )
list.Add( "OverrideMaterialsEX", "models/props_combine/citadel_cable" )
list.Add( "OverrideMaterialsEX", "models/props_combine/citadel_cable_b" )
list.Add( "OverrideMaterialsEX", "models/props_combine/combine_monitorbay_disp" )
list.Add( "OverrideMaterialsEX", "models/props_combine/pipes03" )
list.Add( "OverrideMaterialsEX", "models/props_combine/stasisfield_beam" )
list.Add( "OverrideMaterialsEX", "models/props_debris/building_template010a" )
list.Add( "OverrideMaterialsEX", "models/props_debris/building_template022j" )
list.Add( "OverrideMaterialsEX", "models/props_debris/composite_debris" )
list.Add( "OverrideMaterialsEX", "models/props_debris/concretefloor020a" )
list.Add( "OverrideMaterialsEX", "models/props_debris/plasterceiling008a" )
list.Add( "OverrideMaterialsEX", "models/props_debris/plasterwall034d" )
list.Add( "OverrideMaterialsEX", "models/props_debris/tilefloor001c" )
list.Add( "OverrideMaterialsEX", "models/props_foliage/driftwood_01a" )
list.Add( "OverrideMaterialsEX", "models/props_junk/plasticcrate01a" )
list.Add( "OverrideMaterialsEX", "models/props_junk/plasticcrate01b" )
list.Add( "OverrideMaterialsEX", "models/props_junk/plasticcrate01c" )
list.Add( "OverrideMaterialsEX", "models/props_junk/plasticcrate01d" )
list.Add( "OverrideMaterialsEX", "models/props_junk/plasticcrate01e" )
list.Add( "OverrideMaterialsEX", "models/props_lab/cornerunit_cloud" )
list.Add( "OverrideMaterialsEX", "models/props_lab/door_klab01" )
list.Add( "OverrideMaterialsEX", "models/props_lab/security_screens" )
list.Add( "OverrideMaterialsEX", "models/props_lab/security_screens2" )
list.Add( "OverrideMaterialsEX", "models/props_pipes/destroyedpipes01a" )
list.Add( "OverrideMaterialsEX", "models/props_pipes/pipemetal001a" )
list.Add( "OverrideMaterialsEX", "models/props_pipes/pipesystem01a_skin1" )
list.Add( "OverrideMaterialsEX", "models/props_pipes/pipesystem01a_skin2" )
list.Add( "OverrideMaterialsEX", "models/props_vents/borealis_vent001" )
list.Add( "OverrideMaterialsEX", "models/props_vents/borealis_vent001b" )
list.Add( "OverrideMaterialsEX", "models/props_vents/borealis_vent001c" )
list.Add( "OverrideMaterialsEX", "models/props_wasteland/quarryobjects01" )
list.Add( "OverrideMaterialsEX", "models/props_wasteland/rockgranite02a" )
list.Add( "OverrideMaterialsEX", "models/props_wasteland/tugboat01" )
list.Add( "OverrideMaterialsEX", "models/props_wasteland/tugboat02" )
list.Add( "OverrideMaterialsEX", "models/props_wasteland/wood_fence01a_skin2" )
list.Add( "OverrideMaterialsEX", "models/roller/rollermine_glow" )
list.Add( "OverrideMaterialsEX", "models/weapons/v_grenade/grenade body" )
list.Add( "OverrideMaterialsEX", "models/weapons/v_smg1/texture5" )
list.Add( "OverrideMaterialsEX", "models/weapons/w_smg1/smg_crosshair" )
list.Add( "OverrideMaterialsEX", "models/weapons/v_slam/new light1" )
//Counter-Strike Source
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/dollar" )
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/fireescapefloor" )
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/metal_stairs1" )
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/moneywrap" )
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/moneywrap02" )
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/moneytop" )
list.Add( "OverrideMaterialsEX", "models/props/cs_assault/pylon" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/boulder01" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/milceil001" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/militiarock" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/militiarockb" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/milwall006" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/rocks01" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/roofbeams01" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/roofbeams02" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/roofbeams03" )
list.Add( "OverrideMaterialsEX", "models/props/CS_militia/RoofEdges" )
list.Add( "OverrideMaterialsEX", "models/props/cs_office/clouds" )
list.Add( "OverrideMaterialsEX", "models/props/cs_office/file_cabinet2" )
list.Add( "OverrideMaterialsEX", "models/props/cs_office/file_cabinet3" )
list.Add( "OverrideMaterialsEX", "models/props/cs_office/screen" )
list.Add( "OverrideMaterialsEX", "models/props/cs_office/snowmana" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/de_inferno_boulder_03" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/infflra" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/infflrd" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/inftowertop" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/offwndwb_break" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/roofbits" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/tileroof01" )
list.Add( "OverrideMaterialsEX", "models/props/de_inferno/woodfloor008a" )
list.Add( "OverrideMaterialsEX", "models/props/de_nuke/nukconcretewalla" )
list.Add( "OverrideMaterialsEX", "models/props/de_nuke/nukecardboard" )
list.Add( "OverrideMaterialsEX", "models/shadertest/predator" )

//some more
//COMBINE
list.Add( "OverrideMaterialsExtra", "models/props_combine/masterinterface01c" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/tpballglow" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/combine_door01_glass" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/Combine_Citadel001" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/combine_fenceglow" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/combine_intmonitor001_disp" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/masterinterface_alert" )
list.Add( "OverrideMaterialsExtra", "models/props_combine/weaponstripper_sheet" )
list.Add( "OverrideMaterialsExtra", "models/Combine_Helicopter/helicopter_bomb01" )
//STUFF
list.Add( "OverrideMaterialsExtra", "models/dav0r/hoverball" )
list.Add( "OverrideMaterialsExtra", "models/props_junk/ravenholmsign_sheet" )
list.Add( "OverrideMaterialsExtra", "models/props_junk/TrafficCone001a" )
list.Add( "OverrideMaterialsExtra", "models/Items/boxart1" )
list.Add( "OverrideMaterialsExtra", "models/props/de_tides/clouds" )
list.Add( "OverrideMaterialsExtra", "models/props_c17/fisheyelens" )
list.Add( "OverrideMaterialsExtra", "models/props/cs_office/offinspa" )
list.Add( "OverrideMaterialsExtra", "models/props/cs_office/offinspb" )
list.Add( "OverrideMaterialsExtra", "models/props/cs_office/offinspc" )
list.Add( "OverrideMaterialsExtra", "models/props/cs_office/offinspd" )
list.Add( "OverrideMaterialsExtra", "models/props/cs_office/offinspf" )
list.Add( "OverrideMaterialsExtra", "models/props/cs_office/offinspg" )
list.Add( "OverrideMaterialsExtra", "models/balloon/balloon_hl2" )
list.Add( "OverrideMaterialsExtra", "models/balloon/balloon_nips" )
list.Add( "OverrideMaterialsExtra", "models/balloon/balloon_milfman" )


//Put my list in to the normal one but don't put in duplicates
local AllMats = {}
for _,mat in pairs(list.Get( "OverrideMaterials" ) ) do
	AllMats[ mat ] = mat
end
for k,v in pairs(list.Get( "MaterialsLists" ) ) do
	if (v.colmat_materiallist != nil and v.colmat_materiallist != "OverrideMaterials") then
		for _,mat in pairs( list.Get( v.colmat_materiallist ) ) do
			if (!AllMats[ mat ]) then
				list.Add( "OverrideMaterials", mat )
				AllMats[ mat ] = mat
			end
		end
	end
end

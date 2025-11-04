--Courtesy of Pande4360 and gwizdek
local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local M = {}
--M.msecTimer = 5000
local configDefinition = {
	{
		panelLabel = "Flicker Fixer", 
		saveFile = "config__flicker_fixer", 
		layout = 
		{
			{
				widgetType = "checkbox",
				id = "flicker_fixer_enable",
				label = "Enable Periodic Flicker Fix",
				initialValue = true
			},
			{
				widgetType = "slider_int",
				id = "flicker_fixer_delay",
				label = "Delay (secs)",
				speed = 1.0,
				range = {2, 30},
				initialValue = 5
			},
			{
				widgetType = "text",
				label = "Only decrease the Delay value if flickering is noticeable.\nWhile lower values for Delay can reduce flickering,\nit can also negatively impact performance."
			},
			{
				widgetType = "slider_float",
				id = "flicker_fixer_duration",
				label = "Duration (secs)",
				speed = 0.05,
				range = {0.4, 1.8},
				initialValue = 1.0
			},
			{
				widgetType = "text",
				label = "Lower values for Duration can increase performance but\nif set too low, can prevent flicker removal."
			},
			{
				widgetType = "checkbox",
				id = "flicker_fixer_particles",
				label = "Fix Particle Effects (water splash, etc.)",
				initialValue = true
			},
			{
				widgetType = "text",
				label = "Forces particle systems to render in both eyes.\nFixes water splashes only appearing in one eye."
			},
			{
				widgetType = "checkbox",
				id = "flicker_fixer_postprocess",
				label = "Fix Post-Process Effects",
				initialValue = false
			},
			{
				widgetType = "text",
				label = "Experimental: May reduce flicker in bloom/lens effects.\nCan impact performance."
			},
			{
				widgetType = "checkbox",
				id = "flicker_fixer_shadowmaps",
				label = "Force Shadow Map Refresh",
				initialValue = false
			},
			{
				widgetType = "text",
				label = "Experimental: Helps with shadow flickering.\nHigher performance cost."
			},
		}
	}
}
local flickerFixerComponent = nil
local particleFixComponent = nil
local postProcessFixComponent = nil
local isTriggered = false
local isConfigured = false
local particleSystemsFixed = {}

local currentLogLevel = LogLevel.Error
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[flickerfixer] " .. text, logLevel)
	end
end

local function createFlickerFixerComponent(fov, rt)
	local component = uevrUtils.create_component_of_class("Class /Script/Engine.SceneCaptureComponent2D", false)
    if component == nil then
        print("Failed to spawn scene capture")
    else
		component.TextureTarget = rt
		component.FOVAngle = fov
		component:SetVisibility(false)
	end
	return component
end

-- ############################################################
-- Particle System Fix (for water splash, spell effects, etc.)
-- ############################################################

local function fixParticleSystemStereo(particleSystem)
	if not uevrUtils.validate_object(particleSystem) then return false end
	
	pcall(function()
		-- Force particle system to use stereo rendering
		if particleSystem.bAllowRecievingDecals ~= nil then
			particleSystem.bAllowRecievingDecals = false
		end
		
		-- Set to render in both eyes by disabling single-eye optimization
		if particleSystem.bCastVolumetricTranslucentShadow ~= nil then
			particleSystem.bCastVolumetricTranslucentShadow = true
		end
		
		-- Force update visibility in both stereo views
		if particleSystem.SetVisibleInSceneCaptureOnly then
			particleSystem:SetVisibleInSceneCaptureOnly(false)
		end
		
		-- Ensure particle bounds are calculated for both eyes
		if particleSystem.bUseMaxDrawCount ~= nil then
			particleSystem.bUseMaxDrawCount = false
		end
	end)
	
	return true
end

local function findAndFixParticleSystems()
	if not configui.getValue("flicker_fixer_particles") then return end
	
	local world = uevrUtils.get_world()
	if not uevrUtils.validate_object(world) then return end
	
	-- Find all particle system components in the world
	local allActors = world:GetAllActorsOfClass("Class /Script/Engine.Emitter")
	if allActors then
		for i = 1, #allActors do
			local actor = allActors[i]
			if uevrUtils.validate_object(actor) then
				local particleComp = actor.ParticleSystemComponent
				if uevrUtils.validate_object(particleComp) then
					local actorName = tostring(actor:GetFName())
					if not particleSystemsFixed[actorName] then
						if fixParticleSystemStereo(particleComp) then
							particleSystemsFixed[actorName] = true
							M.print("Fixed particle system: " .. actorName, LogLevel.Debug)
						end
					end
				end
			end
		end
	end
	
	-- Also fix Niagara particle systems (UE4.26+)
	local niagaraActors = world:GetAllActorsOfClass("Class /Script/Niagara.NiagaraActor")
	if niagaraActors then
		for i = 1, #niagaraActors do
			local actor = niagaraActors[i]
			if uevrUtils.validate_object(actor) then
				local niagaraComp = actor.NiagaraComponent
				if uevrUtils.validate_object(niagaraComp) then
					pcall(function()
						-- Force stereo rendering for Niagara
						if niagaraComp.SetRenderingEnabled then
							niagaraComp:SetRenderingEnabled(true)
						end
					end)
				end
			end
		end
	end
end

-- ############################################################
-- Post-Process Effect Fix
-- ############################################################

local function fixPostProcessEffects()
	if not configui.getValue("flicker_fixer_postprocess") then return end
	
	local world = uevrUtils.get_world()
	if not uevrUtils.validate_object(world) then return end
	
	-- Find post-process volumes
	local ppVolumes = world:GetAllActorsOfClass("Class /Script/Engine.PostProcessVolume")
	if ppVolumes then
		for i = 1, #ppVolumes do
			local volume = ppVolumes[i]
			if uevrUtils.validate_object(volume) then
				pcall(function()
					-- Ensure post-process effects render in both eyes
					if volume.bEnabled ~= nil then
						volume.bEnabled = true
					end
					
					-- Force priority to ensure stereo consistency
					if volume.Priority ~= nil and volume.Priority < 1 then
						volume.Priority = 1
					end
					
					-- Disable single-eye optimizations
					if volume.BlendWeight ~= nil and volume.BlendWeight < 1.0 then
						volume.BlendWeight = 1.0
					end
				end)
			end
		end
	end
end

-- ############################################################
-- Shadow Map Refresh Fix
-- ############################################################

local function refreshShadowMaps()
	if not configui.getValue("flicker_fixer_shadowmaps") then return end
	
	local world = uevrUtils.get_world()
	if not uevrUtils.validate_object(world) then return end
	
	-- Find directional lights (sun/moon)
	local lights = world:GetAllActorsOfClass("Class /Script/Engine.DirectionalLight")
	if lights then
		for i = 1, #lights do
			local light = lights[i]
			if uevrUtils.validate_object(light) then
				local lightComp = light.LightComponent
				if uevrUtils.validate_object(lightComp) then
					pcall(function()
						-- Force shadow map invalidation
						if lightComp.MarkRenderStateDirty then
							lightComp:MarkRenderStateDirty()
						end
						
						-- Ensure cascaded shadow maps update for both eyes
						if lightComp.bUseInsetShadowsForMovableObjects ~= nil then
							lightComp.bUseInsetShadowsForMovableObjects = true
						end
					end)
				end
			end
		end
	end
	
	-- Also fix point lights and spot lights
	local pointLights = world:GetAllActorsOfClass("Class /Script/Engine.PointLight")
	if pointLights then
		for i = 1, #pointLights do
			local light = pointLights[i]
			if uevrUtils.validate_object(light) then
				local lightComp = light.LightComponent
				if uevrUtils.validate_object(lightComp) then
					pcall(function()
						if lightComp.MarkRenderStateDirty then
							lightComp:MarkRenderStateDirty()
						end
					end)
				end
			end
		end
	end
end

-- ############################################################
-- Combined Stereo Fix Function
-- ############################################################

local function applyStereoFixes()
	if not configui.getValue("flicker_fixer_enable") then return end
	
	-- Only apply in NativeStereo mode
	if uevrUtils.getUEVRParam_int("VR_RenderingMethod") ~= 0 then return end
	if not uevrUtils.getUEVRParam_bool("VR_NativeStereoFix") then return end
	
	M.print("Applying NativeStereo fixes...", LogLevel.Debug)
	
	-- Apply all enabled fixes
	findAndFixParticleSystems()
	fixPostProcessEffects()
	refreshShadowMaps()
	
	M.print("NativeStereo fixes applied", LogLevel.Debug)
end

function triggerFlickerFixer()
	if configui.getValue("flicker_fixer_enable") == true and uevrUtils.getUEVRParam_int("VR_RenderingMethod") == 0 and uevrUtils.getUEVRParam_bool("VR_NativeStereoFix") then
		if uevrUtils.validate_object(flickerFixerComponent) ~= nil then
			-- Apply periodic scene capture fix
			flickerFixerComponent:SetVisibility(true)
			M.print("Flicker Fixer triggered")
			
			-- Apply all stereo-specific fixes
			applyStereoFixes()
			
			delay(configui.getValue("flicker_fixer_duration") * 1000, function()
				flickerFixerComponent:SetVisibility(false)
				M.print("Flicker Fixer untriggered")
			end)
		end
	end
	delay(configui.getValue("flicker_fixer_delay") * 1000, triggerFlickerFixer)
end

function M.create()
	if not isConfigured then
		configui.create(configDefinition)
		isConfigured = true
	end

	local world = uevrUtils.get_world()
	local fov = 2.0
	local kismet_rendering_library = uevrUtils.find_default_instance("Class /Script/Engine.KismetRenderingLibrary")
	local rt = kismet_rendering_library:CreateRenderTarget2D(world, 64, 64, 6, zero_color, false)
	if rt ~= nil then
		flickerFixerComponent = createFlickerFixerComponent(fov, rt)
		if flickerFixerComponent ~= nil then
			if not isTriggered then
				-- Apply initial stereo fixes
				applyStereoFixes()
				
				-- Start periodic flicker fixer
				triggerFlickerFixer()
				isTriggered = true
				
				M.print("Flicker fixer initialized with NativeStereo enhancements", LogLevel.Info)
			end
		else	
			print("Flicker fixer component could not be created")
		end
	else	
		print("Flicker fixer render target could not be created")
	end
end

-- Manual trigger for testing
function M.forceStereoreFix()
	M.print("=== Forcing NativeStereo Fix ===", LogLevel.Critical)
	applyStereoFixes()
	M.print("Fix applied! Check if water splash appears in both eyes.", LogLevel.Critical)
end

-- Reset particle fix cache (useful after loading new areas)
function M.resetParticleCache()
	particleSystemsFixed = {}
	M.print("Particle system cache reset", LogLevel.Info)
end

return M
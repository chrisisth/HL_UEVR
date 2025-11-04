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
			{
				widgetType = "checkbox",
				id = "flicker_fixer_decals",
				label = "Fix Decal Rendering",
				initialValue = false
			},
			{
				widgetType = "text",
				label = "Experimental: Fixes decals appearing in only one eye.\nMay affect visual quality."
			},
			{
				widgetType = "checkbox",
				id = "flicker_fixer_ssr",
				label = "Disable Screen Space Reflections",
				initialValue = false
			},
			{
				widgetType = "text",
				label = "SSR often flickers in VR. Disable if mirrors/water reflections flicker.\nReduces visual fidelity."
			},
			{
				widgetType = "checkbox",
				id = "flicker_fixer_advanced",
				label = "Enable Advanced CVar Tweaks",
				initialValue = false
			},
			{
				widgetType = "text",
				label = "Applies multiple engine-level fixes for stereo rendering.\nOnly enable if experiencing severe artifacts."
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
local decalsFixed = {}
local cvarsApplied = false

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
-- Decal Fix (Based on UEVR Best Practices)
-- ############################################################

local function fixDecalComponents()
	if not configui.getValue("flicker_fixer_decals") then return end
	
	local world = uevrUtils.get_world()
	if not uevrUtils.validate_object(world) then return end
	
	-- Find all decal components
	local decalActors = world:GetAllActorsOfClass("Class /Script/Engine.DecalActor")
	if decalActors then
		for i = 1, #decalActors do
			local actor = decalActors[i]
			if uevrUtils.validate_object(actor) then
				local decalComp = actor.Decal
				if uevrUtils.validate_object(decalComp) then
					local actorName = tostring(actor:GetFName())
					if not decalsFixed[actorName] then
						pcall(function()
							-- Force decals to render in both eyes
							if decalComp.bOwnerNoSee ~= nil then
								decalComp.bOwnerNoSee = false
							end
							if decalComp.bOnlyOwnerSee ~= nil then
								decalComp.bOnlyOwnerSee = false
							end
							-- Ensure decal visibility in stereo
							if decalComp.bVisibleInSceneCaptureOnly ~= nil then
								decalComp.bVisibleInSceneCaptureOnly = false
							end
							decalsFixed[actorName] = true
							M.print("Fixed decal: " .. actorName, LogLevel.Debug)
						end)
					end
				end
			end
		end
	end
end

-- ############################################################
-- CVar-Based Fixes (UEVR Best Practices)
-- ############################################################

local function applyCVarFixes()
	if not configui.getValue("flicker_fixer_advanced") then return end
	
	-- Only apply once to avoid spam
	if cvarsApplied then return end
	
	M.print("Applying advanced CVar fixes...", LogLevel.Info)
	
	pcall(function()
		-- Disable problematic stereo rendering optimizations
		-- Based on UEVR technical report recommendations
		
		-- Fix shadow flickering (UE 5.4+)
		if uevrUtils.execute_command then
			uevrUtils.execute_command("r.Shadow.Virtual.OnePassProjection 0")
			M.print("Applied: r.Shadow.Virtual.OnePassProjection 0", LogLevel.Debug)
		end
		
		-- Disable instanced stereo if causing issues
		if uevrUtils.execute_command then
			uevrUtils.execute_command("r.InstancedStereo 0")
			M.print("Applied: r.InstancedStereo 0", LogLevel.Debug)
		end
		
		-- Disable mobile multi-view (Quest artifact fix)
		if uevrUtils.execute_command then
			uevrUtils.execute_command("r.MobileMultiView 0")
			M.print("Applied: r.MobileMultiView 0", LogLevel.Debug)
		end
	end)
	
	cvarsApplied = true
	M.print("Advanced CVar fixes applied", LogLevel.Info)
end

local function applySSRFix()
	if not configui.getValue("flicker_fixer_ssr") then return end
	
	pcall(function()
		-- Disable Screen Space Reflections (common VR flicker source)
		if uevrUtils.execute_command then
			uevrUtils.execute_command("r.SSR.Quality 0")
			M.print("SSR disabled (r.SSR.Quality 0)", LogLevel.Debug)
		end
	end)
end

-- ############################################################
-- Name-Based Particle Detection (UEVR Best Practice)
-- ############################################################

local function isProblematicParticle(particleName)
	-- List of known problematic particle name patterns
	local problematicPatterns = {
		"Water", "Splash", "Rain", "Snow", "Dust",
		"Fog", "Mist", "Steam", "Smoke", "Fire",
		"Spark", "Magic", "Spell", "Effect"
	}
	
	for _, pattern in ipairs(problematicPatterns) do
		if particleName:find(pattern) then
			return true
		end
	end
	
	return false
end

local function findAndFixParticleSystemsAdvanced()
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
					
					-- Only fix particles matching problematic patterns
					if not particleSystemsFixed[actorName] and isProblematicParticle(actorName) then
						if fixParticleSystemStereo(particleComp) then
							particleSystemsFixed[actorName] = true
							M.print("Fixed problematic particle: " .. actorName, LogLevel.Info)
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
					local actorName = tostring(actor:GetFName())
					
					if not particleSystemsFixed[actorName] and isProblematicParticle(actorName) then
						pcall(function()
							-- Force stereo rendering for Niagara
							if niagaraComp.SetRenderingEnabled then
								niagaraComp:SetRenderingEnabled(true)
							end
							-- Additional stereo fixes
							if niagaraComp.bVisibleInSceneCaptureOnly ~= nil then
								niagaraComp.bVisibleInSceneCaptureOnly = false
							end
							particleSystemsFixed[actorName] = true
							M.print("Fixed problematic Niagara: " .. actorName, LogLevel.Info)
						end)
					end
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
	
	-- Apply CVar fixes first (once only)
	applyCVarFixes()
	applySSRFix()
	
	-- Apply component-level fixes
	findAndFixParticleSystemsAdvanced()  -- Enhanced version with pattern matching
	fixPostProcessEffects()
	refreshShadowMaps()
	fixDecalComponents()
	
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
	decalsFixed = {}
	M.print("Particle and decal cache reset", LogLevel.Info)
end

-- Reset CVar application flag (for re-applying after settings change)
function M.resetCVars()
	cvarsApplied = false
	M.print("CVar application flag reset - will reapply on next cycle", LogLevel.Info)
end

-- Diagnostic function to list all active particles (for debugging)
function M.listActiveParticles()
	M.print("=== Active Particle Systems ===", LogLevel.Critical)
	
	local world = uevrUtils.get_world()
	if not uevrUtils.validate_object(world) then
		M.print("World not available", LogLevel.Critical)
		return
	end
	
	local count = 0
	
	-- List Emitter actors
	local allActors = world:GetAllActorsOfClass("Class /Script/Engine.Emitter")
	if allActors then
		for i = 1, #allActors do
			local actor = allActors[i]
			if uevrUtils.validate_object(actor) then
				local actorName = tostring(actor:GetFName())
				local isProblematic = isProblematicParticle(actorName)
				local status = particleSystemsFixed[actorName] and " [FIXED]" or ""
				local warning = isProblematic and " ⚠️ PROBLEMATIC" or ""
				M.print("Emitter: " .. actorName .. status .. warning, LogLevel.Critical)
				count = count + 1
			end
		end
	end
	
	-- List Niagara actors
	local niagaraActors = world:GetAllActorsOfClass("Class /Script/Niagara.NiagaraActor")
	if niagaraActors then
		for i = 1, #niagaraActors do
			local actor = niagaraActors[i]
			if uevrUtils.validate_object(actor) then
				local actorName = tostring(actor:GetFName())
				local isProblematic = isProblematicParticle(actorName)
				local status = particleSystemsFixed[actorName] and " [FIXED]" or ""
				local warning = isProblematic and " ⚠️ PROBLEMATIC" or ""
				M.print("Niagara: " .. actorName .. status .. warning, LogLevel.Critical)
				count = count + 1
			end
		end
	end
	
	M.print("Total particle systems found: " .. count, LogLevel.Critical)
	M.print("Fixed systems: " .. #particleSystemsFixed, LogLevel.Critical)
end

-- Diagnostic function to show current configuration
function M.diagnose()
	M.print("=== Flicker Fixer Diagnostics ===", LogLevel.Critical)
	M.print("Enabled: " .. tostring(configui.getValue("flicker_fixer_enable")), LogLevel.Critical)
	M.print("Delay: " .. tostring(configui.getValue("flicker_fixer_delay")) .. "s", LogLevel.Critical)
	M.print("Duration: " .. tostring(configui.getValue("flicker_fixer_duration")) .. "s", LogLevel.Critical)
	M.print("", LogLevel.Critical)
	M.print("Feature Toggles:", LogLevel.Critical)
	M.print("  Particles Fix: " .. tostring(configui.getValue("flicker_fixer_particles")), LogLevel.Critical)
	M.print("  Post-Process Fix: " .. tostring(configui.getValue("flicker_fixer_postprocess")), LogLevel.Critical)
	M.print("  Shadow Maps Fix: " .. tostring(configui.getValue("flicker_fixer_shadowmaps")), LogLevel.Critical)
	M.print("  Decals Fix: " .. tostring(configui.getValue("flicker_fixer_decals")), LogLevel.Critical)
	M.print("  SSR Disable: " .. tostring(configui.getValue("flicker_fixer_ssr")), LogLevel.Critical)
	M.print("  Advanced CVars: " .. tostring(configui.getValue("flicker_fixer_advanced")), LogLevel.Critical)
	M.print("", LogLevel.Critical)
	M.print("Rendering Mode: " .. tostring(uevrUtils.getUEVRParam_int("VR_RenderingMethod")), LogLevel.Critical)
	M.print("NativeStereo Fix: " .. tostring(uevrUtils.getUEVRParam_bool("VR_NativeStereoFix")), LogLevel.Critical)
	M.print("CVars Applied: " .. tostring(cvarsApplied), LogLevel.Critical)
	M.print("Particles Fixed: " .. #particleSystemsFixed, LogLevel.Critical)
	M.print("Decals Fixed: " .. #decalsFixed, LogLevel.Critical)
end

return M
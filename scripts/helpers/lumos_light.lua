-- ############################################################
-- Lumos Wand Light for VR
-- Attaches dynamic light source to wand tip position
-- Enhances immersion by making Lumos spell actually illuminate
-- ############################################################

local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local M = {}

-- Configuration state
local isLumosLightEnabled = true
local lightIntensity = 3000.0 -- Unreal units (default flashlight ~2000-5000)
local lightRadius = 1500.0 -- cm (15 meters)
local lightColor = {r = 255, g = 240, b = 200} -- Warm white/yellow
local enableDynamicShadows = false -- Performance intensive

-- Runtime state
local lumosActive = false
local wandLightComponent = nil
local lastWandPosition = {x = 0, y = 0, z = 0}

local currentLogLevel = LogLevel.Info
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[lumos_light] " .. text, logLevel)
	end
end

-- ############################################################
-- Configuration Functions
-- ############################################################

function M.setLumosEnabled(enabled)
	isLumosLightEnabled = enabled
	configui.setValue("lumos_enableLight", enabled)
	M.print("Lumos light " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
	
	if not enabled and lumosActive then
		M.deactivateLumos()
	end
end

function M.setLightIntensity(intensity)
	lightIntensity = intensity
	configui.setValue("lumos_intensity", intensity)
	
	-- Update live if active
	if wandLightComponent and lumosActive then
		M.updateLightProperties()
	end
end

function M.setLightRadius(radius)
	lightRadius = radius
	configui.setValue("lumos_radius", radius)
	
	if wandLightComponent and lumosActive then
		M.updateLightProperties()
	end
end

function M.setLightColor(r, g, b)
	lightColor = {r = r, g = g, b = b}
	configui.setValue("lumos_colorR", r)
	configui.setValue("lumos_colorG", g)
	configui.setValue("lumos_colorB", b)
	
	if wandLightComponent and lumosActive then
		M.updateLightProperties()
	end
end

function M.setDynamicShadows(enabled)
	enableDynamicShadows = enabled
	configui.setValue("lumos_shadows", enabled)
	
	if wandLightComponent and lumosActive then
		M.updateLightProperties()
	end
end

-- ############################################################
-- Light Management
-- ############################################################

-- Update light properties without recreating
function M.updateLightProperties()
	if not wandLightComponent then return end
	
	-- TODO: Set light properties when UE4 component API is available
	-- Example structure:
	-- wandLightComponent:SetIntensity(lightIntensity)
	-- wandLightComponent:SetAttenuationRadius(lightRadius)
	-- wandLightComponent:SetLightColor(lightColor.r, lightColor.g, lightColor.b)
	-- wandLightComponent:SetCastShadows(enableDynamicShadows)
	
	M.print("Light properties updated", LogLevel.Debug)
end

-- Activate Lumos light
function M.activateLumos()
	if not isLumosLightEnabled then return end
	if lumosActive then return end
	
	M.print("Activating Lumos light...", LogLevel.Info)
	
	-- TODO: Create point light component and attach to wand
	-- Example structure (when UE4SS/UEVR component API is discovered):
	-- local player = uevrUtils.getPlayerCharacter()
	-- if player then
	-- 	local wandTool = player.WandTool
	-- 	if wandTool then
	-- 		wandLightComponent = ConstructObject("PointLightComponent", wandTool)
	-- 		wandLightComponent:AttachToComponent(wandTool:GetRootComponent(), "WandTip")
	-- 		M.updateLightProperties()
	-- 		wandLightComponent:SetVisibility(true)
	-- 		wandLightComponent:RegisterComponent()
	-- 	end
	-- end
	
	lumosActive = true
	M.print("Lumos activated!", LogLevel.Info)
end

-- Deactivate Lumos light
function M.deactivateLumos()
	if not lumosActive then return end
	
	M.print("Deactivating Lumos light...", LogLevel.Info)
	
	-- TODO: Destroy or hide light component
	-- if wandLightComponent then
	-- 	wandLightComponent:SetVisibility(false)
	-- 	wandLightComponent:DestroyComponent()
	-- 	wandLightComponent = nil
	-- end
	
	lumosActive = false
	M.print("Lumos deactivated", LogLevel.Info)
end

-- Toggle Lumos on/off
function M.toggleLumos()
	if lumosActive then
		M.deactivateLumos()
	else
		M.activateLumos()
	end
end

-- Update light position to follow wand (called every frame)
function M.updateLightPosition(wandPosition)
	if not isLumosLightEnabled or not lumosActive then return end
	if not wandLightComponent then return end
	
	-- TODO: Update light position when component API available
	-- wandLightComponent:SetWorldLocation(wandPosition.x, wandPosition.y, wandPosition.z)
	
	lastWandPosition = {x = wandPosition.x, y = wandPosition.y, z = wandPosition.z}
end

-- Check if Lumos is currently active
function M.isActive()
	return lumosActive
end

-- ############################################################
-- Hook Registration
-- ############################################################

function M.registerHooks()
	M.print("Registering Lumos light hooks...", LogLevel.Info)
	
	-- TODO: Hook into Lumos spell cast when spell system found
	-- hook_function("Class /Script/Phoenix.WandTool", "CastSpell", false,
	-- 	nil,
	-- 	function(fn, obj, locals, result)
	-- 		local spellName = locals.SpellName or ""
	-- 		if spellName:find("Lumos") then
	-- 			M.activateLumos()
	-- 		elseif spellName:find("Nox") then
	-- 			M.deactivateLumos()
	-- 		end
	-- 	end,
	-- 	true
	-- )
	
	-- TODO: Hook into spell end to auto-deactivate if needed
	-- hook_function("Class /Script/Phoenix.WandTool", "EndSpell", false,
	-- 	nil,
	-- 	function(fn, obj, locals, result)
	-- 		local spellName = locals.SpellName or ""
	-- 		if spellName:find("Lumos") then
	-- 			-- Optional: auto-deactivate after duration
	-- 			-- M.deactivateLumos()
	-- 		end
	-- 	end,
	-- 	true
	-- )
	
	M.print("Lumos light hooks registered (placeholder mode)", LogLevel.Info)
end

-- Reset state when player dies/loads
function M.reset()
	if lumosActive then
		M.deactivateLumos()
	end
	lastWandPosition = {x = 0, y = 0, z = 0}
	M.print("Lumos light reset", LogLevel.Debug)
end

-- ############################################################
-- Configuration UI
-- ############################################################

local configDefinition = {
	{
		panelLabel = "Lumos Wand Light",
		saveFile = "config_lumoslight",
		layout = {
			{
				widgetType = "checkbox",
				id = "lumos_enableLight",
				label = "Enable Lumos Light",
				initialValue = true
			},
			{
				widgetType = "slider_float",
				id = "lumos_intensity",
				label = "Light Intensity",
				speed = 100,
				range = {500, 10000},
				initialValue = 3000
			},
			{
				widgetType = "slider_float",
				id = "lumos_radius",
				label = "Light Radius (cm)",
				speed = 50,
				range = {300, 3000},
				initialValue = 1500
			},
			{
				widgetType = "slider_int",
				id = "lumos_colorR",
				label = "Color Red (0-255)",
				speed = 5,
				range = {0, 255},
				initialValue = 255
			},
			{
				widgetType = "slider_int",
				id = "lumos_colorG",
				label = "Color Green (0-255)",
				speed = 5,
				range = {0, 255},
				initialValue = 240
			},
			{
				widgetType = "slider_int",
				id = "lumos_colorB",
				label = "Color Blue (0-255)",
				speed = 5,
				range = {0, 255},
				initialValue = 200
			},
			{
				widgetType = "checkbox",
				id = "lumos_shadows",
				label = "Dynamic Shadows (Performance Impact)",
				initialValue = false
			},
			{
				widgetType = "text",
				label = "Cast Lumos to illuminate dark areas!\nLight follows your wand tip automatically."
			}
		}
	}
}

function M.initConfig()
	configui.create(configDefinition)
	
	-- Set up callbacks
	configui.onUpdate("lumos_enableLight", function(value)
		M.setLumosEnabled(value)
	end)
	
	configui.onUpdate("lumos_intensity", function(value)
		M.setLightIntensity(value)
	end)
	
	configui.onUpdate("lumos_radius", function(value)
		M.setLightRadius(value)
	end)
	
	configui.onUpdate("lumos_colorR", function(value)
		lightColor.r = value
		if wandLightComponent and lumosActive then
			M.updateLightProperties()
		end
	end)
	
	configui.onUpdate("lumos_colorG", function(value)
		lightColor.g = value
		if wandLightComponent and lumosActive then
			M.updateLightProperties()
		end
	end)
	
	configui.onUpdate("lumos_colorB", function(value)
		lightColor.b = value
		if wandLightComponent and lumosActive then
			M.updateLightProperties()
		end
	end)
	
	configui.onUpdate("lumos_shadows", function(value)
		M.setDynamicShadows(value)
	end)
	
	-- Load saved values
	local savedEnabled = configui.getValue("lumos_enableLight")
	if savedEnabled ~= nil then
		isLumosLightEnabled = savedEnabled
	end
	
	local savedIntensity = configui.getValue("lumos_intensity")
	if savedIntensity ~= nil then
		lightIntensity = savedIntensity
	end
	
	local savedRadius = configui.getValue("lumos_radius")
	if savedRadius ~= nil then
		lightRadius = savedRadius
	end
	
	local savedR = configui.getValue("lumos_colorR")
	if savedR ~= nil then
		lightColor.r = savedR
	end
	
	local savedG = configui.getValue("lumos_colorG")
	if savedG ~= nil then
		lightColor.g = savedG
	end
	
	local savedB = configui.getValue("lumos_colorB")
	if savedB ~= nil then
		lightColor.b = savedB
	end
	
	local savedShadows = configui.getValue("lumos_shadows")
	if savedShadows ~= nil then
		enableDynamicShadows = savedShadows
	end
	
	M.print("Lumos light configuration initialized", LogLevel.Info)
end

-- ############################################################
-- Manual Control (for testing)
-- ############################################################

function M.testLumos()
	M.print("=== Testing Lumos Light ===", LogLevel.Critical)
	M.print("Activating for 5 seconds...", LogLevel.Critical)
	
	M.activateLumos()
	
	uevrUtils.delay(5000, function()
		M.print("Deactivating test light", LogLevel.Critical)
		M.deactivateLumos()
	end)
end

function M.diagnose()
	M.print("=== Lumos Light Diagnostics ===", LogLevel.Critical)
	M.print("Enabled: " .. tostring(isLumosLightEnabled), LogLevel.Critical)
	M.print("Active: " .. tostring(lumosActive), LogLevel.Critical)
	M.print("Intensity: " .. lightIntensity, LogLevel.Critical)
	M.print("Radius: " .. lightRadius .. "cm", LogLevel.Critical)
	M.print("Color: RGB(" .. lightColor.r .. ", " .. lightColor.g .. ", " .. lightColor.b .. ")", LogLevel.Critical)
	M.print("Shadows: " .. tostring(enableDynamicShadows), LogLevel.Critical)
	M.print("Light Component: " .. tostring(wandLightComponent ~= nil), LogLevel.Critical)
	M.print("Last Wand Pos: (" .. lastWandPosition.x .. ", " .. lastWandPosition.y .. ", " .. lastWandPosition.z .. ")", LogLevel.Critical)
end

return M

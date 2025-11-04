-- ############################################################
-- Haptic Feedback System for VR
-- Provides controller vibration for spell cooldowns and events
-- ############################################################

local uevrUtils = require("libs/uevr_utils")
local controllers = require("libs/controllers")
local configui = require("libs/configui")

local M = {}

-- Configuration state
local isHapticFeedbackEnabled = true
local cooldownIntensity = 0.5
local cooldownDuration = 200 -- milliseconds
local spellCastIntensity = 0.3
local spellCastDuration = 100

local currentLogLevel = LogLevel.Info
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[haptic_feedback] " .. text, logLevel)
	end
end

-- ############################################################
-- Configuration Functions
-- ############################################################

function M.setHapticFeedbackEnabled(enabled)
	isHapticFeedbackEnabled = enabled
	configui.setValue("haptic_enableFeedback", enabled)
	M.print("Haptic feedback " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.setCooldownIntensity(intensity)
	cooldownIntensity = intensity
	configui.setValue("haptic_cooldownIntensity", intensity)
end

function M.setSpellCastIntensity(intensity)
	spellCastIntensity = intensity
	configui.setValue("haptic_spellCastIntensity", intensity)
end

-- ############################################################
-- Haptic Trigger Functions
-- ############################################################

-- Vibrate controller with specified intensity and duration
local function vibrateController(controllerIndex, intensity, duration)
	if not isHapticFeedbackEnabled then return end
	
	local success, _ = pcall(function()
		-- Use controller vibration if available
		-- Note: This is a simplified implementation
		-- Actual haptic feedback may require direct controller API access
		controllers.setVibration(controllerIndex, intensity, duration)
	end)
	
	if not success then
		M.print("Failed to trigger haptic feedback", LogLevel.Debug)
	end
end

-- Pulse pattern for spell ready notification
function M.pulseSpellReady(wandHand)
	if not isHapticFeedbackEnabled then return end
	
	M.print("Spell ready pulse", LogLevel.Debug)
	
	-- Double pulse pattern
	vibrateController(wandHand, cooldownIntensity, cooldownDuration)
	
	-- Second pulse after short delay
	uevrUtils.delay(cooldownDuration + 50, function()
		vibrateController(wandHand, cooldownIntensity * 0.7, cooldownDuration * 0.7)
	end)
end

-- Single pulse for spell cast
function M.pulseSpellCast(wandHand)
	if not isHapticFeedbackEnabled then return end
	
	M.print("Spell cast pulse", LogLevel.Debug)
	vibrateController(wandHand, spellCastIntensity, spellCastDuration)
end

-- Subtle pulse for item pickup
function M.pulseItemPickup(hand)
	if not isHapticFeedbackEnabled then return end
	
	M.print("Item pickup pulse", LogLevel.Debug)
	vibrateController(hand, 0.2, 80)
end

-- Strong pulse for damage taken
function M.pulseDamageTaken()
	if not isHapticFeedbackEnabled then return end
	
	M.print("Damage pulse", LogLevel.Debug)
	-- Vibrate both controllers
	vibrateController(0, 0.8, 150)
	vibrateController(1, 0.8, 150)
end

-- Continuous vibration for Revelio proximity (distance-based)
function M.pulseRevealProximity(distance, maxDistance)
	if not isHapticFeedbackEnabled then return end
	
	-- Calculate intensity based on proximity (closer = stronger)
	local normalizedDistance = math.max(0, math.min(1, distance / maxDistance))
	local intensity = (1 - normalizedDistance) * 0.4
	
	if intensity > 0.1 then
		M.print("Revelio proximity pulse: " .. string.format("%.2f", intensity), LogLevel.Debug)
		vibrateController(0, intensity, 50) -- Left hand
		vibrateController(1, intensity, 50) -- Right hand
	end
end

-- ############################################################
-- Hook Registration (Placeholder for future spell system hooks)
-- ############################################################

function M.registerHooks()
	M.print("Registering haptic feedback hooks...", LogLevel.Info)
	
	-- TODO: Hook into spell cooldown system when found
	-- Example structure:
	-- hook_function("Class /Script/Phoenix.SpellCooldownManager", "OnCooldownComplete", false,
	-- 	nil,
	-- 	function(fn, obj, locals, result)
	-- 		M.pulseSpellReady(wandHand)
	-- 	end,
	-- 	true
	-- )
	
	-- TODO: Hook into spell cast system
	-- hook_function("Class /Script/Phoenix.WandTool", "CastSpell", false,
	-- 	nil,
	-- 	function(fn, obj, locals, result)
	-- 		M.pulseSpellCast(wandHand)
	-- 	end,
	-- 	true
	-- )
	
	M.print("Haptic feedback hooks registered (placeholder mode)", LogLevel.Info)
end

-- ############################################################
-- Configuration UI
-- ############################################################

local configDefinition = {
	{
		panelLabel = "Haptic Feedback",
		saveFile = "config_haptic",
		layout = {
			{
				widgetType = "checkbox",
				id = "haptic_enableFeedback",
				label = "Enable Haptic Feedback",
				initialValue = true
			},
			{
				widgetType = "slider_float",
				id = "haptic_cooldownIntensity",
				label = "Spell Ready Intensity",
				speed = 0.05,
				range = {0.0, 1.0},
				initialValue = 0.5
			},
			{
				widgetType = "slider_float",
				id = "haptic_spellCastIntensity",
				label = "Spell Cast Intensity",
				speed = 0.05,
				range = {0.0, 1.0},
				initialValue = 0.3
			}
		}
	}
}

function M.initConfig()
	configui.create(configDefinition)
	
	-- Set up callbacks
	configui.onUpdate("haptic_enableFeedback", function(value)
		M.setHapticFeedbackEnabled(value)
	end)
	
	configui.onUpdate("haptic_cooldownIntensity", function(value)
		M.setCooldownIntensity(value)
	end)
	
	configui.onUpdate("haptic_spellCastIntensity", function(value)
		M.setSpellCastIntensity(value)
	end)
	
	-- Load saved values
	local savedEnabled = configui.getValue("haptic_enableFeedback")
	if savedEnabled ~= nil then
		isHapticFeedbackEnabled = savedEnabled
	end
	
	local savedCooldown = configui.getValue("haptic_cooldownIntensity")
	if savedCooldown ~= nil then
		cooldownIntensity = savedCooldown
	end
	
	local savedCast = configui.getValue("haptic_spellCastIntensity")
	if savedCast ~= nil then
		spellCastIntensity = savedCast
	end
	
	M.print("Haptic feedback configuration initialized", LogLevel.Info)
end

-- ############################################################
-- Test Function (for manual testing)
-- ############################################################

function M.testHaptics()
	M.print("Testing haptic feedback patterns...", LogLevel.Info)
	
	-- Test spell ready
	M.pulseSpellReady(1)
	
	-- Test spell cast after delay
	uevrUtils.delay(1000, function()
		M.pulseSpellCast(1)
	end)
	
	-- Test damage taken
	uevrUtils.delay(2000, function()
		M.pulseDamageTaken()
	end)
end

return M

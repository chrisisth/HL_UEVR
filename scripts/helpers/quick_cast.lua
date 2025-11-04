-- ############################################################
-- Enhanced Quick-Cast for VR
-- Improves wrist flick gesture detection for spell casting
-- Adds visual/haptic feedback for successful gesture recognition
-- ############################################################

local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local M = {}

-- Configuration state
local isQuickCastEnabled = true
local flickSensitivity = 1.0 -- Multiplier for gesture threshold
local enableHapticFeedback = true
local enableVisualFeedback = true
local cooldownDuration = 0.3 -- seconds between casts

-- Runtime state
local lastCastTime = 0
local gestureReady = true
local lastControllerVelocity = {x = 0, y = 0, z = 0}

local currentLogLevel = LogLevel.Info
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[quick_cast] " .. text, logLevel)
	end
end

-- ############################################################
-- Configuration Functions
-- ############################################################

function M.setQuickCastEnabled(enabled)
	isQuickCastEnabled = enabled
	configui.setValue("quickcast_enableQuickCast", enabled)
	M.print("Quick-cast " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.setSensitivity(sensitivity)
	flickSensitivity = sensitivity
	configui.setValue("quickcast_sensitivity", sensitivity)
	M.print("Sensitivity set to " .. sensitivity, LogLevel.Debug)
end

function M.setHapticFeedback(enabled)
	enableHapticFeedback = enabled
	configui.setValue("quickcast_haptics", enabled)
end

function M.setVisualFeedback(enabled)
	enableVisualFeedback = enabled
	configui.setValue("quickcast_visual", enabled)
end

function M.setCooldown(duration)
	cooldownDuration = duration
	configui.setValue("quickcast_cooldown", duration)
end

-- ############################################################
-- Gesture Detection Enhancement
-- ############################################################

-- Calculate velocity magnitude
local function calculateVelocity(velocity)
	return math.sqrt(velocity.x*velocity.x + velocity.y*velocity.y + velocity.z*velocity.z)
end

-- Check if gesture qualifies as quick-cast
local function isQuickCastGesture(velocity, acceleration)
	if not isQuickCastEnabled then return false end
	if not gestureReady then return false end
	
	-- Base thresholds (can be tuned)
	local baseVelocityThreshold = 2.0 -- m/s
	local baseAccelerationThreshold = 5.0 -- m/s²
	
	-- Apply sensitivity multiplier (lower sensitivity = higher threshold)
	local adjustedVelThreshold = baseVelocityThreshold / flickSensitivity
	local adjustedAccelThreshold = baseAccelerationThreshold / flickSensitivity
	
	local velocityMag = calculateVelocity(velocity)
	local accelerationMag = calculateVelocity(acceleration)
	
	-- Check if flick meets thresholds
	if velocityMag >= adjustedVelThreshold and accelerationMag >= adjustedAccelThreshold then
		M.print("Quick-cast gesture detected! V=" .. string.format("%.2f", velocityMag) .. " A=" .. string.format("%.2f", accelerationMag), LogLevel.Info)
		return true
	end
	
	return false
end

-- Trigger quick-cast spell
local function triggerQuickCast()
	M.print("Triggering quick-cast!", LogLevel.Info)
	
	-- Haptic feedback
	if enableHapticFeedback then
		M.provideHapticFeedback()
	end
	
	-- Visual feedback
	if enableVisualFeedback then
		M.provideVisualFeedback()
	end
	
	-- Set cooldown
	lastCastTime = os.clock()
	gestureReady = false
	
	uevrUtils.delay(cooldownDuration * 1000, function()
		gestureReady = true
		M.print("Quick-cast ready", LogLevel.Debug)
	end)
	
	-- TODO: Trigger actual spell cast when spell system found
	-- Example:
	-- local player = uevrUtils.getPlayerCharacter()
	-- if player and player.WandTool then
	-- 	player.WandTool:CastSelectedSpell()
	-- end
end

-- Provide haptic feedback on successful gesture
function M.provideHapticFeedback()
	-- TODO: Integrate with haptic_feedback.lua or controllers.lua
	-- Example:
	-- local controllers = require("libs/controllers")
	-- controllers.vibrate(1, 0.3, 100) -- Right hand, 30% intensity, 100ms
	
	M.print("Haptic feedback triggered", LogLevel.Debug)
end

-- Provide visual feedback on successful gesture
function M.provideVisualFeedback()
	-- TODO: Create particle effect or glow on wand tip
	-- Example:
	-- local player = uevrUtils.getPlayerCharacter()
	-- if player and player.WandTool then
	-- 	player.WandTool:PlayEffect("SpellReadyEffect")
	-- end
	
	M.print("Visual feedback triggered", LogLevel.Debug)
end

-- Update gesture tracking (called every frame)
function M.updateGestureTracking(controllerVelocity, controllerAcceleration)
	if not isQuickCastEnabled then return end
	
	-- Check for quick-cast gesture
	if isQuickCastGesture(controllerVelocity, controllerAcceleration) then
		triggerQuickCast()
	end
	
	-- Update tracking
	lastControllerVelocity = {
		x = controllerVelocity.x,
		y = controllerVelocity.y,
		z = controllerVelocity.z
	}
end

-- Check if currently on cooldown
function M.isOnCooldown()
	return not gestureReady
end

-- Get remaining cooldown time
function M.getCooldownRemaining()
	if gestureReady then return 0 end
	
	local elapsed = os.clock() - lastCastTime
	local remaining = cooldownDuration - elapsed
	return math.max(0, remaining)
end

-- ############################################################
-- Hook Registration
-- ############################################################

function M.registerHooks()
	M.print("Registering quick-cast hooks...", LogLevel.Info)
	
	-- TODO: Hook into existing gesture system to enhance detection
	-- This module is designed to work alongside existing gesture recognition
	-- May need to integrate with scripts/gestures/ modules
	
	-- TODO: Hook into spell cast to prevent spam
	-- hook_function("Class /Script/Phoenix.WandTool", "CastSpell", false,
	-- 	function(fn, obj, locals, result)
	-- 		if M.isOnCooldown() then
	-- 			M.print("Quick-cast on cooldown, blocking cast", LogLevel.Debug)
	-- 			return false -- Block execution
	-- 		end
	-- 	end,
	-- 	nil,
	-- 	true
	-- )
	
	-- TODO: Hook into controller input for velocity tracking
	-- hook_function("Class /Script/Phoenix.PlayerController", "UpdateControllerInput", false,
	-- 	nil,
	-- 	function(fn, obj, locals, result)
	-- 		local velocity = locals.ControllerVelocity
	-- 		local acceleration = locals.ControllerAcceleration
	-- 		if velocity and acceleration then
	-- 			M.updateGestureTracking(velocity, acceleration)
	-- 		end
	-- 	end,
	-- 	true
	-- )
	
	M.print("Quick-cast hooks registered (placeholder mode)", LogLevel.Info)
end

-- Reset state when player dies/loads
function M.reset()
	lastCastTime = 0
	gestureReady = true
	lastControllerVelocity = {x = 0, y = 0, z = 0}
	M.print("Quick-cast reset", LogLevel.Debug)
end

-- ############################################################
-- Configuration UI
-- ############################################################

local configDefinition = {
	{
		panelLabel = "Quick-Cast Enhancement",
		saveFile = "config_quickcast",
		layout = {
			{
				widgetType = "checkbox",
				id = "quickcast_enableQuickCast",
				label = "Enable Enhanced Quick-Cast",
				initialValue = true
			},
			{
				widgetType = "slider_float",
				id = "quickcast_sensitivity",
				label = "Gesture Sensitivity",
				speed = 0.1,
				range = {0.3, 3.0},
				initialValue = 1.0
			},
			{
				widgetType = "slider_float",
				id = "quickcast_cooldown",
				label = "Cooldown Duration (seconds)",
				speed = 0.05,
				range = {0.1, 1.0},
				initialValue = 0.3
			},
			{
				widgetType = "checkbox",
				id = "quickcast_haptics",
				label = "Haptic Feedback on Cast",
				initialValue = true
			},
			{
				widgetType = "checkbox",
				id = "quickcast_visual",
				label = "Visual Feedback on Cast",
				initialValue = true
			},
			{
				widgetType = "text",
				label = "Flick your wrist to quick-cast!\nHigher sensitivity = easier to trigger."
			}
		}
	}
}

function M.initConfig()
	configui.create(configDefinition)
	
	-- Set up callbacks
	configui.onUpdate("quickcast_enableQuickCast", function(value)
		M.setQuickCastEnabled(value)
	end)
	
	configui.onUpdate("quickcast_sensitivity", function(value)
		M.setSensitivity(value)
	end)
	
	configui.onUpdate("quickcast_cooldown", function(value)
		M.setCooldown(value)
	end)
	
	configui.onUpdate("quickcast_haptics", function(value)
		M.setHapticFeedback(value)
	end)
	
	configui.onUpdate("quickcast_visual", function(value)
		M.setVisualFeedback(value)
	end)
	
	-- Load saved values
	local savedEnabled = configui.getValue("quickcast_enableQuickCast")
	if savedEnabled ~= nil then
		isQuickCastEnabled = savedEnabled
	end
	
	local savedSensitivity = configui.getValue("quickcast_sensitivity")
	if savedSensitivity ~= nil then
		flickSensitivity = savedSensitivity
	end
	
	local savedCooldown = configui.getValue("quickcast_cooldown")
	if savedCooldown ~= nil then
		cooldownDuration = savedCooldown
	end
	
	local savedHaptics = configui.getValue("quickcast_haptics")
	if savedHaptics ~= nil then
		enableHapticFeedback = savedHaptics
	end
	
	local savedVisual = configui.getValue("quickcast_visual")
	if savedVisual ~= nil then
		enableVisualFeedback = savedVisual
	end
	
	M.print("Quick-cast configuration initialized", LogLevel.Info)
end

-- ############################################################
-- Integration with Existing Gesture System
-- ############################################################

-- Call this from main gesture detection to enhance existing system
function M.enhanceGestureDetection(gestureData)
	if not isQuickCastEnabled then return gestureData end
	
	-- Apply sensitivity multiplier to existing thresholds
	if gestureData.thresholds then
		gestureData.thresholds.velocity = (gestureData.thresholds.velocity or 2.0) / flickSensitivity
		gestureData.thresholds.acceleration = (gestureData.thresholds.acceleration or 5.0) / flickSensitivity
	end
	
	-- Add cooldown check
	gestureData.onCooldown = not gestureReady
	gestureData.cooldownRemaining = M.getCooldownRemaining()
	
	return gestureData
end

-- ############################################################
-- Diagnostic Function
-- ############################################################

function M.diagnose()
	M.print("=== Quick-Cast Diagnostics ===", LogLevel.Critical)
	M.print("Enabled: " .. tostring(isQuickCastEnabled), LogLevel.Critical)
	M.print("Sensitivity: " .. flickSensitivity, LogLevel.Critical)
	M.print("Cooldown Duration: " .. cooldownDuration .. "s", LogLevel.Critical)
	M.print("Haptic Feedback: " .. tostring(enableHapticFeedback), LogLevel.Critical)
	M.print("Visual Feedback: " .. tostring(enableVisualFeedback), LogLevel.Critical)
	M.print("Gesture Ready: " .. tostring(gestureReady), LogLevel.Critical)
	M.print("Cooldown Remaining: " .. string.format("%.2f", M.getCooldownRemaining()) .. "s", LogLevel.Critical)
	M.print("Last Velocity: (" .. lastControllerVelocity.x .. ", " .. lastControllerVelocity.y .. ", " .. lastControllerVelocity.z .. ")", LogLevel.Critical)
end

-- Test quick-cast manually
function M.testQuickCast()
	M.print("=== Testing Quick-Cast ===", LogLevel.Critical)
	
	if gestureReady then
		triggerQuickCast()
		M.print("Quick-cast triggered! Cooldown: " .. cooldownDuration .. "s", LogLevel.Critical)
	else
		M.print("Quick-cast on cooldown! Remaining: " .. string.format("%.2f", M.getCooldownRemaining()) .. "s", LogLevel.Critical)
	end
end

return M

-- ############################################################
-- Physical Dodge Detection for VR
-- Rewards actual ducking/leaning movements in VR space
-- Detects rapid head movement to trigger dodge mechanics
-- ############################################################

local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local M = {}

-- Configuration state
local isPhysicalDodgeEnabled = true
local dodgeThresholdVertical = 0.3 -- meters (about 1 foot)
local dodgeThresholdHorizontal = 0.4 -- meters
local dodgeTimeWindow = 0.5 -- seconds to detect movement
local damagReductionPercent = 50 -- percentage damage reduction on successful dodge

-- Tracking variables
local lastHeadPosition = {x = 0, y = 0, z = 0}
local lastUpdateTime = 0
local isDodging = false
local dodgeCooldown = false

local currentLogLevel = LogLevel.Info
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[physical_dodge] " .. text, logLevel)
	end
end

-- ############################################################
-- Configuration Functions
-- ############################################################

function M.setPhysicalDodgeEnabled(enabled)
	isPhysicalDodgeEnabled = enabled
	configui.setValue("dodge_enablePhysicalDodge", enabled)
	M.print("Physical dodge " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.setDodgeThreshold(vertical, horizontal)
	dodgeThresholdVertical = vertical
	dodgeThresholdHorizontal = horizontal
	configui.setValue("dodge_thresholdVertical", vertical)
	configui.setValue("dodge_thresholdHorizontal", horizontal)
end

function M.setDamageReduction(percent)
	damagReductionPercent = percent
	configui.setValue("dodge_damageReduction", percent)
end

-- ############################################################
-- Dodge Detection Logic
-- ############################################################

-- Calculate distance between two 3D points
local function calculateDistance3D(p1, p2)
	local dx = p2.x - p1.x
	local dy = p2.y - p1.y
	local dz = p2.z - p1.z
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Check if head movement qualifies as a dodge
local function checkDodgeMovement(currentPos, deltaTime)
	if not isPhysicalDodgeEnabled then return false end
	if dodgeCooldown then return false end
	
	-- Calculate movement distance
	local verticalMovement = math.abs(currentPos.y - lastHeadPosition.y)
	local dx = currentPos.x - lastHeadPosition.x
	local dz = currentPos.z - lastHeadPosition.z
	local horizontalDistance = math.sqrt(dx*dx + dz*dz)
	
	-- Check if movement exceeds thresholds within time window
	if deltaTime <= dodgeTimeWindow then
		if verticalMovement >= dodgeThresholdVertical then
			M.print("Vertical dodge detected! Movement: " .. string.format("%.2f", verticalMovement) .. "m", LogLevel.Info)
			return true
		end
		
		if horizontalDistance >= dodgeThresholdHorizontal then
			M.print("Horizontal dodge detected! Movement: " .. string.format("%.2f", horizontalDistance) .. "m", LogLevel.Info)
			return true
		end
	end
	
	return false
end

-- Activate dodge state
local function activateDodge()
	isDodging = true
	dodgeCooldown = true
	
	M.print("Dodge activated! Damage reduction: " .. damagReductionPercent .. "%", LogLevel.Info)
	
	-- Dodge state lasts for short duration
	uevrUtils.delay(300, function()
		isDodging = false
	end)
	
	-- Cooldown to prevent spam
	uevrUtils.delay(1000, function()
		dodgeCooldown = false
	end)
end

-- Update head position tracking (called every frame)
function M.updateHeadTracking(position, deltaTime)
	if not isPhysicalDodgeEnabled then return end
	
	local currentTime = os.clock()
	local timeDelta = currentTime - lastUpdateTime
	
	-- Check for dodge movement
	if checkDodgeMovement(position, timeDelta) then
		activateDodge()
	end
	
	-- Update tracking
	lastHeadPosition = {x = position.x, y = position.y, z = position.z}
	lastUpdateTime = currentTime
end

-- Check if currently dodging (for damage calculation hooks)
function M.isDodging()
	return isDodging
end

-- Get damage reduction multiplier
function M.getDamageReduction()
	if isDodging then
		return 1.0 - (damagReductionPercent / 100.0)
	end
	return 1.0
end

-- ############################################################
-- Hook Registration
-- ############################################################

function M.registerHooks()
	M.print("Registering physical dodge hooks...", LogLevel.Info)
	
	-- TODO: Hook into damage calculation system when found
	-- Example structure:
	-- hook_function("Class /Script/Phoenix.Biped_Player", "TakeDamage", false,
	-- 	function(fn, obj, locals, result)
	-- 		if isDodging then
	-- 			local originalDamage = locals.Damage
	-- 			locals.Damage = originalDamage * M.getDamageReduction()
	-- 			M.print("Dodge successful! Reduced damage from " .. originalDamage .. " to " .. locals.Damage, LogLevel.Info)
	-- 		end
	-- 	end,
	-- 	nil,
	-- 	true
	-- )
	
	-- TODO: Hook into attack indicator for visual feedback
	-- hook_function("Class /Script/Phoenix.Player_AttackIndicator", "ReceiveIndicatorStart", false,
	-- 	nil,
	-- 	function(fn, obj, locals, result)
	-- 		-- Could trigger visual effect when dodge is ready
	-- 	end,
	-- 	true
	-- )
	
	M.print("Physical dodge hooks registered (placeholder mode)", LogLevel.Info)
end

-- Reset tracking when player dies/loads
function M.reset()
	lastHeadPosition = {x = 0, y = 0, z = 0}
	lastUpdateTime = 0
	isDodging = false
	dodgeCooldown = false
	M.print("Physical dodge tracking reset", LogLevel.Debug)
end

-- ############################################################
-- Configuration UI
-- ############################################################

local configDefinition = {
	{
		panelLabel = "Physical Dodge",
		saveFile = "config_physicaldodge",
		layout = {
			{
				widgetType = "checkbox",
				id = "dodge_enablePhysicalDodge",
				label = "Enable Physical Dodge",
				initialValue = true
			},
			{
				widgetType = "slider_float",
				id = "dodge_thresholdVertical",
				label = "Vertical Dodge Threshold (m)",
				speed = 0.05,
				range = {0.1, 1.0},
				initialValue = 0.3
			},
			{
				widgetType = "slider_float",
				id = "dodge_thresholdHorizontal",
				label = "Horizontal Dodge Threshold (m)",
				speed = 0.05,
				range = {0.1, 1.0},
				initialValue = 0.4
			},
			{
				widgetType = "slider_int",
				id = "dodge_damageReduction",
				label = "Damage Reduction %",
				speed = 5,
				range = {0, 100},
				initialValue = 50
			},
			{
				widgetType = "text",
				label = "Duck or lean to dodge incoming attacks!\nMovement must be quick and deliberate."
			}
		}
	}
}

function M.initConfig()
	configui.create(configDefinition)
	
	-- Set up callbacks
	configui.onUpdate("dodge_enablePhysicalDodge", function(value)
		M.setPhysicalDodgeEnabled(value)
	end)
	
	configui.onUpdate("dodge_thresholdVertical", function(value)
		dodgeThresholdVertical = value
	end)
	
	configui.onUpdate("dodge_thresholdHorizontal", function(value)
		dodgeThresholdHorizontal = value
	end)
	
	configui.onUpdate("dodge_damageReduction", function(value)
		M.setDamageReduction(value)
	end)
	
	-- Load saved values
	local savedEnabled = configui.getValue("dodge_enablePhysicalDodge")
	if savedEnabled ~= nil then
		isPhysicalDodgeEnabled = savedEnabled
	end
	
	local savedVertical = configui.getValue("dodge_thresholdVertical")
	if savedVertical ~= nil then
		dodgeThresholdVertical = savedVertical
	end
	
	local savedHorizontal = configui.getValue("dodge_thresholdHorizontal")
	if savedHorizontal ~= nil then
		dodgeThresholdHorizontal = savedHorizontal
	end
	
	local savedReduction = configui.getValue("dodge_damageReduction")
	if savedReduction ~= nil then
		damagReductionPercent = savedReduction
	end
	
	M.print("Physical dodge configuration initialized", LogLevel.Info)
end

-- ############################################################
-- Diagnostic Function
-- ############################################################

function M.diagnose()
	M.print("=== Physical Dodge Diagnostics ===", LogLevel.Critical)
	M.print("Enabled: " .. tostring(isPhysicalDodgeEnabled), LogLevel.Critical)
	M.print("Vertical Threshold: " .. dodgeThresholdVertical .. "m", LogLevel.Critical)
	M.print("Horizontal Threshold: " .. dodgeThresholdHorizontal .. "m", LogLevel.Critical)
	M.print("Damage Reduction: " .. damagReductionPercent .. "%", LogLevel.Critical)
	M.print("Currently Dodging: " .. tostring(isDodging), LogLevel.Critical)
	M.print("Cooldown Active: " .. tostring(dodgeCooldown), LogLevel.Critical)
	M.print("Last Head Position: (" .. lastHeadPosition.x .. ", " .. lastHeadPosition.y .. ", " .. lastHeadPosition.z .. ")", LogLevel.Critical)
end

return M

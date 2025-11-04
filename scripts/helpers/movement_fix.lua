-- ############################################################
-- Hogwarts Legacy VR Movement Fix
-- 1. Blocks "noMoving" context + RootMotion for player only
--    Prevents unwanted movement locks and forward steps during spell casting
-- 2. Optional: Makes Merlin Gazebo cutscene instantly skippable
-- 3. Optional: Removes world boundaries to allow flying anywhere
--    Destroys NoMountZone, NoDismountZone, MountHeightLimit, and MountSpeedLimit volumes
-- ############################################################

local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local M = {}

-- Configuration state variables
local isNoMovingFixEnabled = true
local isRootMotionFixEnabled = true
local isSkipGazeboEnabled = false
local isRemoveWorldBoundariesEnabled = false
local worldBoundariesRemoved = false

local currentLogLevel = LogLevel.Info
function M.setLogLevel(val)
	currentLogLevel = val
end
function M.print(text, logLevel)
	if logLevel == nil then logLevel = LogLevel.Debug end
	if logLevel <= currentLogLevel then
		uevrUtils.print("[movement_fix] " .. text, logLevel)
	end
end

-- ############################################################
-- Configuration Functions
-- ############################################################

function M.setNoMovingFixEnabled(enabled)
	isNoMovingFixEnabled = enabled
	configui.setValue("movementfix_enableNoMovingFix", enabled)
	M.print("NoMoving fix " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.setRootMotionFixEnabled(enabled)
	isRootMotionFixEnabled = enabled
	configui.setValue("movementfix_enableRootMotionFix", enabled)
	M.print("Root motion fix " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.getNoMovingFixEnabled()
	return isNoMovingFixEnabled
end

function M.getRootMotionFixEnabled()
	return isRootMotionFixEnabled
end

-- Author: VTLI#9513 (Discord: Hogwarts Legacy Modding)
function M.setSkipGazeboEnabled(enabled)
	isSkipGazeboEnabled = enabled
	configui.setValue("movementfix_enableSkipGazebo", enabled)
	M.print("Skip Gazebo cutscene " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.getSkipGazeboEnabled()
	return isSkipGazeboEnabled
end

function M.setRemoveWorldBoundariesEnabled(enabled)
	isRemoveWorldBoundariesEnabled = enabled
	configui.setValue("movementfix_enableRemoveWorldBoundaries", enabled)
	M.print("Remove World Boundaries " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
	
	if enabled and not worldBoundariesRemoved then
		M.destroyBlockingVolumes()
	end
end

function M.getRemoveWorldBoundariesEnabled()
	return isRemoveWorldBoundariesEnabled
end

function M.setDebugMode(enabled)
	if enabled then
		M.setLogLevel(LogLevel.Debug)
	else
		M.setLogLevel(LogLevel.Info)
	end
end

-- ############################################################
-- Helper: Check if owner is the player
-- ############################################################
local function isPlayer(owner)
	-- Use project's standard validation pattern
	if uevrUtils.validate_object(owner) == nil then return false end
	
	local success, result = pcall(function()
		local fullName = owner:get_full_name()
		return fullName ~= nil and string.find(fullName, "Biped_Player") ~= nil
	end)
	
	return success and result
end

-- ############################################################
-- ABL blacklist for root motion blocking
-- ############################################################
local blockedRootMotion = {
	"ABL_Combat2CombatCasual",
	"ABL_CombatCasual2Idle",
	"ABL_CombatCasualIdle",
	"ABL_CombatCasualIdleBreak",
	"ABL_CombatIdle",
	"ABL_CombatIdleBreak",
	"ABL_CombatIdle_LF2RF",
	"ABL_CriticalFinish_",
	"ABL_DuelCombatIdle",
	"ABL_Finisher_AMBossKiller",
	"ABL_Idle2CombatIdle",
	"ABL_Idle2CombatIdle_Flourish",
	"ABL_Incendio_AOE",
	"ABL_Reparo_AOE",
	"ABL_Reparo_End",
	"ABL_SpellImpact_",
	"ABL_StealthKnockdown",
	"ABL_Unforgivable_",
	"ABL_WandCast",
	"ABL_WandFlourish",
}

-- Helper: Check if ability name matches blocked list
local function isBlockedAbility(name)
	if name == nil then return false end
	for _, ab in ipairs(blockedRootMotion) do
		if string.find(name, ab) then 
			return true 
		end
	end
	return false
end

-- ############################################################
-- Hook Registration
-- ############################################################
function M.registerHooks()
	M.print("Registering movement fix hooks...", LogLevel.Info)
	
	-- ############################################################
	-- 1) Block noMoving context for player
	-- ############################################################
	
	-- Hook: SetContextValue - force noMoving to false for player
	-- NOTE: Using pre-hook (false parameter) to allow parameter modification
	-- Function signature: void SetContextValue(FName ContextName, bool Value)
	hook_function("Class /Script/AbleCore.AblAbilityContext", "SetContextValue", false,
		function(fn, obj, locals, result)
			if not isNoMovingFixEnabled then return end  -- Check if fix is enabled
			
			local success, _ = pcall(function()
				if obj == nil then return end
				
				-- IMPORTANT: Assuming locals contains ContextName and Value based on UE function signature
				-- This may need verification through debug logging
				local contextName = locals.ContextName
				if contextName == nil then return end
				
				local nameStr = contextName:to_string()
				if nameStr and string.find(nameStr, "noMoving") then
					local owner = obj.Owner
					if isPlayer(owner) then
						M.print("Blocking noMoving context for player (was: " .. tostring(locals.Value) .. ")", LogLevel.Debug)
						-- Modify the parameter before function executes
						locals.Value = false
					end
				end
			end)
			if not success then
				M.print("Error in SetContextValue hook", LogLevel.Warning)
			end
		end,
		nil, -- No post-hook needed
		true  -- Execute original function with modified parameters
	)
	
	-- Hook: GetContextByName - return false for noMoving when player
	-- NOTE: This hook attempts to override return value in post-hook
	-- WARNING: Return value override mechanism (result:set) is unverified
	-- If this doesn't work, consider using a pre-hook that prevents the call entirely
	hook_function("Class /Script/AbleCore.AblAbilityContext", "GetContextByName", false,
		function(fn, obj, locals, result)
			-- Pre-hook: check if we should intercept
		end,
		function(fn, obj, locals, result)
			if not isNoMovingFixEnabled then return end  -- Check if fix is enabled
			
			local success, _ = pcall(function()
				if obj == nil or result == nil then return end
				
				local contextName = locals.ContextName
				if contextName == nil then return end
				
				local nameStr = contextName:to_string()
				if nameStr and string.find(nameStr, "noMoving") then
					local owner = obj.Owner
					if isPlayer(owner) then
						M.print("Returning false for noMoving context query", LogLevel.Debug)
						-- UNVERIFIED: result:set() may not exist in UEVR
						-- Alternative: May need to use different mechanism
						-- TODO: Test and verify this actually works
						if result.set then
							result:set(false)
						else
							M.print("WARNING: result:set() not available, hook may not work", LogLevel.Warning)
						end
					end
				end
			end)
			if not success then
				M.print("Error in GetContextByName hook", LogLevel.Warning)
			end
		end,
		true
	)
	
	-- ############################################################
	-- 2) Block root motion for specific ABLs
	-- ############################################################
	
	-- Hook: PlayAnimation Start - disable root motion for blocked abilities
	hook_function("Class /Script/Phoenix.AblAbilityTask_PlayAnimation", "Start", false,
		function(fn, obj, locals, result)
			if not isRootMotionFixEnabled then return end  -- Check if fix is enabled
			
			local success, _ = pcall(function()
				if obj == nil then return end
				
				-- Check if owner is player
				local owner = obj.Owner
				if not isPlayer(owner) then return end
				
				-- Get ability name
				local abilityName = obj:get_full_name()
				if not isBlockedAbility(abilityName) then return end
				
				M.print("Disabling root motion for: " .. abilityName, LogLevel.Debug)
				
				-- Disable root motion flags
				local disabled = false
				if pcall(function() return obj.bUseRootMotion end) then
					obj.bUseRootMotion = false
					disabled = true
				end
				
				if pcall(function() return obj.VerticalRootMotionAmount end) then
					obj.VerticalRootMotionAmount = 0.0
					disabled = true
				end
				
				if pcall(function() return obj.HorizontalRootMotionAmount end) then
					obj.HorizontalRootMotionAmount = 0.0
					disabled = true
				end
				
				if disabled then
					M.print("Root motion neutralized for player", LogLevel.Debug)
				end
			end)
			if not success then
				M.print("Error in PlayAnimation Start hook", LogLevel.Warning)
			end
		end,
		nil, true
	)
	
	M.print("Movement fix hooks registered successfully", LogLevel.Info)
end

-- ############################################################
-- Remove World Boundaries Feature
-- ############################################################

-- Destroy blocking volumes to allow flying anywhere
function M.destroyBlockingVolumes()
	if not isRemoveWorldBoundariesEnabled then return end
	if worldBoundariesRemoved then
		M.print("World boundaries already removed", LogLevel.Info)
		return
	end
	
	M.print("Removing world boundaries...", LogLevel.Info)
	local totalDestroyed = 0
	
	-- Destroy NoMountZoneVolume (prevents mounting in certain areas)
	local success, blockingVolumes = pcall(function()
		return uevrUtils.find_all_of("NoMountZoneVolume", false)
	end)
	if success and blockingVolumes then
		for _, volume in pairs(blockingVolumes) do
			local destroySuccess, _ = pcall(function()
				if uevrUtils.validate_object(volume) then
					M.print("Destroying NoMountZoneVolume: " .. (volume:get_full_name() or "unknown"), LogLevel.Debug)
					volume:K2_DestroyActor()
					totalDestroyed = totalDestroyed + 1
				end
			end)
			if not destroySuccess then
				M.print("Failed to destroy NoMountZoneVolume", LogLevel.Warning)
			end
		end
	end
	
	-- Destroy NoDismountZoneVolume (prevents dismounting in certain areas)
	local success, dismountVolumes = pcall(function()
		return uevrUtils.find_all_of("NoDismountZoneVolume", false)
	end)
	if success and dismountVolumes then
		for _, volume in pairs(dismountVolumes) do
			local destroySuccess, _ = pcall(function()
				if uevrUtils.validate_object(volume) then
					M.print("Destroying NoDismountZoneVolume: " .. (volume:get_full_name() or "unknown"), LogLevel.Debug)
					volume:K2_DestroyActor()
					totalDestroyed = totalDestroyed + 1
				end
			end)
			if not destroySuccess then
				M.print("Failed to destroy NoDismountZoneVolume", LogLevel.Warning)
			end
		end
	end
	
	-- Destroy MountHeightLimitVolume (limits flying height)
	local success, heightVolumes = pcall(function()
		return uevrUtils.find_all_of("MountHeightLimitVolume", false)
	end)
	if success and heightVolumes then
		for _, volume in pairs(heightVolumes) do
			local destroySuccess, _ = pcall(function()
				if uevrUtils.validate_object(volume) then
					M.print("Destroying MountHeightLimitVolume: " .. (volume:get_full_name() or "unknown"), LogLevel.Debug)
					volume:K2_DestroyActor()
					totalDestroyed = totalDestroyed + 1
				end
			end)
			if not destroySuccess then
				M.print("Failed to destroy MountHeightLimitVolume", LogLevel.Warning)
			end
		end
	end
	
	-- Destroy MountSpeedLimitVolume (limits mount speed)
	local success, speedVolumes = pcall(function()
		return uevrUtils.find_all_of("MountSpeedLimitVolume", false)
	end)
	if success and speedVolumes then
		for _, volume in pairs(speedVolumes) do
			local destroySuccess, _ = pcall(function()
				if uevrUtils.validate_object(volume) then
					M.print("Destroying MountSpeedLimitVolume: " .. (volume:get_full_name() or "unknown"), LogLevel.Debug)
					volume:K2_DestroyActor()
					totalDestroyed = totalDestroyed + 1
				end
			end)
			if not destroySuccess then
				M.print("Failed to destroy MountSpeedLimitVolume", LogLevel.Warning)
			end
		end
	end
	
	worldBoundariesRemoved = true
	M.print("World boundaries removed! Destroyed " .. totalDestroyed .. " blocking volumes", LogLevel.Info)
	M.print("You can now fly anywhere without restrictions!", LogLevel.Info)
end

-- ############################################################
-- Gazebo Skip Cutscene Feature
-- ############################################################

local gazeboHookRegistered = false

-- Check if Merlin Gazebo is loaded and register hook
local function checkGazeboLoaded()
	if not isSkipGazeboEnabled then return end
	if gazeboHookRegistered then return end
	
	local success, gazeboClass = pcall(function()
		return uevr.api:find_uobject("/Game/Gameplay/SphinxPuzzles/Blueprints/BP_Merlin_Gazebo.BP_Merlin_Gazebo_C:ActivationSRFinished")
	end)
	
	if not success or not gazeboClass or not gazeboClass:IsValid() then
		M.print("Gazebo not loaded yet, will retry...", LogLevel.Debug)
		return false
	end
	
	-- Register the hook to make cutscene instantly skippable
	hook_function("/Game/Gameplay/SphinxPuzzles/Blueprints/BP_Merlin_Gazebo.BP_Merlin_Gazebo_C", "ActivationSRFinished", false,
		nil,
		function(fn, obj, locals, result)
			local success, _ = pcall(function()
				if obj and obj.GazeboSR then
					obj.GazeboSR.bInstantlySkippable = true
					M.print("Merlin Gazebo cutscene made instantly skippable", LogLevel.Info)
				end
			end)
			if not success then
				M.print("Error in Gazebo hook", LogLevel.Warning)
			end
		end,
		true
	)
	
	gazeboHookRegistered = true
	M.print("Gazebo skip cutscene hook registered", LogLevel.Info)
	return true
end

-- Hook into PlayerController to detect when player respawns/loads
function M.registerGazeboHooks()
	if not isSkipGazeboEnabled then return end
	
	M.print("Registering Gazebo skip cutscene hooks...", LogLevel.Info)
	
	-- Hook PlayerController ClientRestart to check when player loads
	hook_function("Class /Script/Engine.PlayerController", "ClientRestart", false,
		nil,
		function(fn, obj, locals, result)
			if isSkipGazeboEnabled then
				checkGazeboLoaded()
			end
		end,
		true
	)
	
	-- Try to register immediately in case already loaded
	checkGazeboLoaded()
	
	M.print("Gazebo hooks registered", LogLevel.Info)
end

-- ############################################################
-- Configuration UI
-- ############################################################

-- Config definition for movement fix panel
local configDefinition = {
	{
		panelLabel = "Movement Fix",
		saveFile = "config_movementfix",
		layout = {
			{
				widgetType = "checkbox",
				id = "movementfix_enableNoMovingFix",
				label = "Enable NoMoving Fix",
				initialValue = true
			},
			{
				widgetType = "checkbox",
				id = "movementfix_enableRootMotionFix",
				label = "Enable Root Motion Fix",
				initialValue = true
			},
			{
				widgetType = "checkbox",
				id = "movementfix_enableSkipGazebo",
				label = "Skip Merlin Gazebo Cutscene",
				initialValue = false
			},
			{
				widgetType = "checkbox",
				id = "movementfix_enableRemoveWorldBoundaries",
				label = "Remove World Boundaries (Fly Anywhere)",
				initialValue = false
			},
			{
				widgetType = "checkbox",
				id = "movementfix_debugMode",
				label = "Debug Mode",
				initialValue = false
			}
		}
	}
}

-- Initialize configuration UI
function M.initConfig()
	configui.create(configDefinition)
	
	-- Set up callbacks for config changes
	configui.onUpdate("movementfix_enableNoMovingFix", function(value)
		M.setNoMovingFixEnabled(value)
	end)
	
	configui.onUpdate("movementfix_enableRootMotionFix", function(value)
		M.setRootMotionFixEnabled(value)
	end)
	
	configui.onUpdate("movementfix_enableSkipGazebo", function(value)
		M.setSkipGazeboEnabled(value)
		if value then
			M.registerGazeboHooks()
		end
	end)
	
	configui.onUpdate("movementfix_enableRemoveWorldBoundaries", function(value)
		M.setRemoveWorldBoundariesEnabled(value)
	end)
	
	configui.onUpdate("movementfix_debugMode", function(value)
		M.setDebugMode(value)
	end)
	
	-- Load saved values
	local savedNoMoving = configui.getValue("movementfix_enableNoMovingFix")
	if savedNoMoving ~= nil then
		isNoMovingFixEnabled = savedNoMoving
	end
	
	local savedRootMotion = configui.getValue("movementfix_enableRootMotionFix")
	if savedRootMotion ~= nil then
		isRootMotionFixEnabled = savedRootMotion
	end
	
	local savedSkipGazebo = configui.getValue("movementfix_enableSkipGazebo")
	if savedSkipGazebo ~= nil then
		isSkipGazeboEnabled = savedSkipGazebo
		if isSkipGazeboEnabled then
			M.registerGazeboHooks()
		end
	end
	
	local savedRemoveBoundaries = configui.getValue("movementfix_enableRemoveWorldBoundaries")
	if savedRemoveBoundaries ~= nil then
		isRemoveWorldBoundariesEnabled = savedRemoveBoundaries
		if isRemoveWorldBoundariesEnabled then
			M.destroyBlockingVolumes()
		end
	end
	
	local savedDebugMode = configui.getValue("movementfix_debugMode")
	if savedDebugMode then
		M.setLogLevel(LogLevel.Debug)
	end
	
	M.print("Movement fix configuration initialized", LogLevel.Info)
end

-- ############################################################
-- Diagnostic and Testing Functions
-- ############################################################

-- Print diagnostic information
function M.diagnose()
	M.print("=== Movement Fix Diagnostics ===", LogLevel.Critical)
	M.print("Module Loaded: true", LogLevel.Critical)
	M.print("NoMoving Fix Enabled: " .. tostring(isNoMovingFixEnabled), LogLevel.Critical)
	M.print("Root Motion Fix Enabled: " .. tostring(isRootMotionFixEnabled), LogLevel.Critical)
	M.print("Skip Gazebo Enabled: " .. tostring(isSkipGazeboEnabled), LogLevel.Critical)
	M.print("Gazebo Hook Registered: " .. tostring(gazeboHookRegistered), LogLevel.Critical)
	M.print("Remove World Boundaries Enabled: " .. tostring(isRemoveWorldBoundariesEnabled), LogLevel.Critical)
	M.print("World Boundaries Removed: " .. tostring(worldBoundariesRemoved), LogLevel.Critical)
	M.print("Blocked Animations Count: " .. #blockedRootMotion, LogLevel.Critical)
	M.print("Current Log Level: " .. currentLogLevel, LogLevel.Critical)
	M.print("", LogLevel.Critical)
	M.print("To test if hooks are working:", LogLevel.Critical)
	M.print("1. Set log level to Debug: movementFix.setLogLevel(LogLevel.Debug)", LogLevel.Critical)
	M.print("2. Cast a spell and watch console for hook messages", LogLevel.Critical)
	M.print("3. Check for 'Blocking noMoving context' messages", LogLevel.Critical)
	M.print("4. Check for 'Disabling root motion' messages", LogLevel.Critical)
	M.print("5. Visit Merlin's Gazebo to test skip cutscene feature", LogLevel.Critical)
	M.print("6. Enable world boundaries removal to fly anywhere", LogLevel.Critical)
end

-- Test parameter access (call this during gameplay to debug)
function M.testParameterAccess(obj, locals)
	M.print("=== Testing Parameter Access ===", LogLevel.Critical)
	if obj then
		M.print("Object: " .. (obj:get_full_name() or "unknown"), LogLevel.Critical)
	end
	if locals then
		M.print("Locals table:", LogLevel.Critical)
		for k, v in pairs(locals) do
			M.print("  " .. tostring(k) .. " = " .. tostring(v), LogLevel.Critical)
		end
	else
		M.print("Locals is nil", LogLevel.Critical)
	end
end

return M

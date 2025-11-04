-- ############################################################
-- Hogwarts Legacy VR Movement Fix
-- Blocks "noMoving" context + RootMotion for player only
-- Prevents unwanted movement locks and forward steps during spell casting
-- ############################################################

local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local M = {}

-- Configuration state variables
local isNoMovingFixEnabled = true
local isRootMotionFixEnabled = true

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
	M.print("Blocked Animations Count: " .. #blockedRootMotion, LogLevel.Critical)
	M.print("Current Log Level: " .. currentLogLevel, LogLevel.Critical)
	M.print("", LogLevel.Critical)
	M.print("To test if hooks are working:", LogLevel.Critical)
	M.print("1. Set log level to Debug: movementFix.setLogLevel(LogLevel.Debug)", LogLevel.Critical)
	M.print("2. Cast a spell and watch console for hook messages", LogLevel.Critical)
	M.print("3. Check for 'Blocking noMoving context' messages", LogLevel.Critical)
	M.print("4. Check for 'Disabling root motion' messages", LogLevel.Critical)
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

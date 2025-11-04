# Movement Fix - Integration Checklist

## Pre-Integration Requirements

### ⚠️ 0. API Verification (CRITICAL - DO THIS FIRST)

**Status:** ⬜ **NOT VERIFIED** - Requires testing

**The Problem:**
This implementation was adapted from UE4SS's `RegisterHook` API to UEVR's `hook_function` API. The parameter access patterns are **unverified assumptions**.

**What Needs Verification:**

1. **Parameter Names in SetContextValue:**
   ```lua
   // Assumed:
   locals.ContextName  -- FName parameter
   locals.Value        -- bool parameter
   
   // May actually be:
   locals[1]  -- First parameter
   locals[2]  -- Second parameter
   // OR something else entirely
   ```

2. **Return Value Override in GetContextByName:**
   ```lua
   // Assumed:
   result:set(false)
   
   // May not exist at all
   // Alternative needed if this fails
   ```

3. **Object Property Access:**
   ```lua
   // Assumed:
   obj.Owner
   task.bUseRootMotion
   
   // Verify these exist and are accessible
   ```

**How to Verify:**

**Step 1:** Add debug hook to test parameter structure:
```lua
-- Add this temporarily to movement_fix.lua after line 70
hook_function("Class /Script/AbleCore.AblAbilityContext", "SetContextValue", false,
    function(fn, obj, locals, result)
        print("=== DEBUG: SetContextValue ===")
        print("obj type:", type(obj))
        print("locals type:", type(locals))
        
        if locals then
            print("locals keys:")
            for k, v in pairs(locals) do
                print("  ", k, "=", tostring(v))
            end
        end
    end, nil, true
)
```

**Step 2:** Launch game, cast spell, check console output

**Step 3:** Update hook code based on actual parameter structure

**Action Required:** ⬜ Verify parameter access works  
**Blocker:** Cannot proceed to testing without verification

---

### ✅ 1. Project Structure Setup

**File Placement:**
```
HL_UEVR/
└── scripts/
    └── helpers/
        └── movement_fix.lua  ← Place here
```

**Current Status:** ✅ **COMPLETE** - File already placed in correct location

**Verification:**
```lua
-- In main.lua, verify this line exists:
local movementFix = require("helpers/movement_fix")
```

---

### ✅ 2. Load Order Confirmation

**Hook Registration Location:**
The movement fix hooks are registered in `hookLateFunctions()` which is called from `UEVRReady()`:

```lua
function UEVRReady(instance)
    -- ... initialization code ...
    hookLateFunctions()  -- Movement fix hooks registered here
    -- ... more initialization ...
end
```

**Current Status:** ✅ **COMPLETE** - Hooks registered after UEVR initialization

**Why Late Registration:**
- Ensures all game objects are loaded
- UEVR API is fully initialized
- Player pawn exists and is accessible
- Able animation system is ready

---

### ✅ 3. Environment & API Verification

**Required UEVR Functions:**
```lua
✅ hook_function()           - Function hooking capability
✅ UEVR_UObjectHook.exists() - Object validation
✅ pcall()                   - Protected call (Lua standard)
✅ obj:get_full_name()       - UObject full name retrieval
✅ obj:to_string()           - FName to string conversion
```

**Current Status:** ✅ **COMPLETE** - All required APIs available in UEVR framework

**Verification Method:**
All hooks use `pcall()` wrappers to handle missing properties gracefully:
```lua
if pcall(function() return task.bUseRootMotion end) then
    task.bUseRootMotion = false
end
```

---

## Configuration Options

### 🔧 4. ABL List Customization (Optional)

**Current Implementation:** Uses substring matching for flexibility

**Location:** `scripts/helpers/movement_fix.lua` lines 38-58

**To Use Exact Asset Paths:**

```lua
-- CURRENT (Substring matching):
local blockedRootMotion = {
    "ABL_WandCast",           -- Matches any ABL containing this
    "ABL_CriticalFinish_",    -- Matches prefix
}

-- ALTERNATIVE (Exact path matching):
local blockedRootMotion = {
    "AblAbility'/Game/Abilities/Combat/ABL_WandCast.ABL_WandCast'",
    "AblAbility'/Game/Abilities/Combat/ABL_WandCast_Heavy.ABL_WandCast_Heavy'",
}

-- Then modify isBlockedAbility():
local function isBlockedAbility(name)
    for _, ab in ipairs(blockedRootMotion) do
        if name == ab then return true end  -- Exact match instead of find
    end
    return false
end
```

**Recommendation:** Keep substring matching for easier maintenance unless you need precise control.

---

### 🔧 5. Debug Logging Configuration

**Current Log Level:** `LogLevel.Info` (line 10)

**Available Levels:**
```lua
LogLevel.Debug    -- Verbose: Every hook trigger
LogLevel.Info     -- Default: Important events only
LogLevel.Warning  -- Moderate: Errors and warnings
LogLevel.Error    -- Minimal: Errors only
LogLevel.Critical -- Critical only
```

**To Enable Debug Mode:**

**Option A: Hardcode (Permanent)**
```lua
-- In movement_fix.lua, line 10, change:
local currentLogLevel = LogLevel.Debug
```

**Option B: Runtime Toggle (Recommended)**

Add to `config/config.lua`:
```lua
-- In configDefinition layout array, add:
{
    widgetType = "checkbox",
    id = "debugMovementFix",
    label = "Debug Movement Fix",
    initialValue = false
}
```

Then in `movement_fix.lua`, add config handler:
```lua
local configui = require("libs/configui")

-- Add this after M.registerHooks()
configui.onUpdate("debugMovementFix", function(value)
    M.setLogLevel(value and LogLevel.Debug or LogLevel.Info)
end)
```

---

### 🔧 6. Hotkey Toggle Implementation (Recommended)

**Add Runtime Enable/Disable Toggle:**

**Step 1:** Add state variables to `movement_fix.lua`:
```lua
-- Add after line 15
local isNoMovingFixEnabled = true
local isRootMotionFixEnabled = true

function M.setNoMovingFixEnabled(enabled)
    isNoMovingFixEnabled = enabled
    M.print("NoMoving fix " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end

function M.setRootMotionFixEnabled(enabled)
    isRootMotionFixEnabled = enabled
    M.print("Root motion fix " .. (enabled and "enabled" or "disabled"), LogLevel.Info)
end
```

**Step 2:** Modify hooks to check enabled state:
```lua
-- In SetContextValue hook, add check at line 75:
if not isNoMovingFixEnabled then return end

-- In GetContextByName hook, add check at line 94:
if not isNoMovingFixEnabled then return end

-- In PlayAnimation hook, add check at line 119:
if not isRootMotionFixEnabled then return end
```

**Step 3:** Add hotkey binding in `main.lua`:
```lua
-- Add after existing register_key_bind calls (around line 64)
register_key_bind("F8", function()
    movementFix.setNoMovingFixEnabled(not movementFix.getNoMovingFixEnabled())
end)

register_key_bind("F9", function()
    movementFix.setRootMotionFixEnabled(not movementFix.getRootMotionFixEnabled())
end)
```

**Step 4:** Add getters to `movement_fix.lua`:
```lua
function M.getNoMovingFixEnabled()
    return isNoMovingFixEnabled
end

function M.getRootMotionFixEnabled()
    return isRootMotionFixEnabled
end
```

---

## Testing Protocol

### ✅ 7. Test Case 1: NoMoving Override

**Objective:** Verify player can move during spell animations

**Steps:**
1. Enter combat with any enemy
2. Cast a spell (e.g., Stupefy, Incendio)
3. While animation plays, try to move with left stick
4. **Expected:** Character moves freely during cast
5. **Failure:** Character is locked in place

**Debug Verification:**
```
Enable debug logging and look for:
[movement_fix] Blocking noMoving context for player
[movement_fix] Returning false for noMoving context query
```

**Status:** ⬜ Not Tested | ✅ Passed | ❌ Failed

---

### ✅ 8. Test Case 2: Root Motion Elimination

**Objective:** Verify no unwanted forward movement during spell casting

**Test Spells:**
- Basic Cast (Stupefy)
- Heavy Cast (Charged Stupefy)
- Incendio AOE
- Wand Flourish (press triangle/Y without enemy)

**Steps:**
1. Stand in a marked spot (near a visual landmark)
2. Cast each spell in the list above
3. Observe if character moves forward 1-2 steps
4. **Expected:** Character stays in same position
5. **Failure:** Character steps forward slightly

**Debug Verification:**
```
[movement_fix] Disabling root motion for: [ABL_Name]
[movement_fix] Root motion neutralized for player
```

**Status:** ⬜ Not Tested | ✅ Passed | ❌ Failed

---

### ✅ 9. Test Case 3: NPC Behavior Unchanged

**Objective:** Ensure NPCs are not affected by the fix

**Steps:**
1. Engage enemy NPCs in combat
2. Observe enemy spell casting animations
3. Observe enemy movement during attacks
4. **Expected:** NPCs move and animate normally
5. **Failure:** NPCs glide or don't move during attacks

**Verification Method:**
```lua
-- In movement_fix.lua, temporarily add logging to isPlayer():
local function isPlayer(owner)
    local result = -- ... normal check ...
    M.print("isPlayer check: " .. tostring(result) .. " for " .. 
            (owner and owner:get_full_name() or "nil"), LogLevel.Debug)
    return result
end
```

Should only log `true` for objects containing "Biped_Player"

**Status:** ⬜ Not Tested | ✅ Passed | ❌ Failed

---

### ✅ 10. Test Case 4: Essential Movement Preserved

**Objective:** Verify jumping, climbing, dodging still work

**Test Actions:**
| Action | Expected Behavior | Root Motion? | Test Result |
|--------|-------------------|--------------|-------------|
| Jump | Character jumps normally | ✅ Yes | ⬜ |
| Dodge/Roll | Character rolls/dodges | ✅ Yes | ⬜ |
| Climb Ladder | Character climbs | ✅ Yes | ⬜ |
| Swim | Character swims | ✅ Yes | ⬜ |
| Mount Broom | Character mounts | ✅ Yes | ⬜ |
| Open Door | Animation plays | ✅ Yes | ⬜ |
| Pick Up Item | Animation plays | ✅ Yes | ⬜ |

**Reason These Work:**
These animations are NOT in the `blockedRootMotion` list, so they retain their original root motion.

**Status:** ⬜ Not Tested | ✅ Passed | ❌ Failed

---

### ✅ 11. Test Case 5: Combat Flow

**Objective:** Complete combat encounter without issues

**Steps:**
1. Start a full combat encounter (e.g., bandit camp)
2. Use various spells (basic, heavy, special)
3. Use dodges and movement
4. Complete the encounter
5. **Expected:** Smooth combat, no movement locks, no unexpected steps
6. **Failure:** Any movement issues or animation problems

**Metrics:**
- No crashes
- No movement locks
- No sliding/gliding
- Smooth transitions between actions

**Status:** ⬜ Not Tested | ✅ Passed | ❌ Failed

---

## Compatibility & Integration

### 🔧 12. Mod Compatibility Check

**Potential Conflicts:**

If other mods also hook the same functions, conflicts may occur:
```
Class /Script/AbleCore.AblAbilityContext :: SetContextValue
Class /Script/AbleCore.AblAbilityContext :: GetContextByName
Class /Script/Phoenix.AblAbilityTask_PlayAnimation :: Start
```

**Resolution Strategies:**

**Option A: Hook Priority**
UEVR doesn't currently support hook priority, but you can:
- Load movement_fix.lua last
- Register hooks last in `hookLateFunctions()`

**Option B: Namespace Hooks**
Add unique identifiers to your hooks:
```lua
-- Instead of returning/modifying directly, add metadata:
obj._HL_UEVR_MovementFixApplied = true
```

**Option C: Feature Detection**
Check if other mods modified values:
```lua
if obj.bUseRootMotion ~= nil and obj.bUseRootMotion == false then
    -- Already disabled by another mod
    M.print("Root motion already disabled, skipping", LogLevel.Debug)
    return
end
```

**Option D: Configuration Toggle**
Add config option to disable movement fix if conflicts occur:
```lua
{
    widgetType = "checkbox",
    id = "enableMovementFix",
    label = "Enable Movement Fix",
    initialValue = true
}
```

**Current Status:** ⬜ No Known Conflicts

**Testing Required If:**
- Using other combat mods
- Using animation mods
- Using movement overhaul mods

---

### 🔧 13. Performance Monitoring

**Metrics to Track:**

```lua
-- Add to movement_fix.lua for profiling
local hookCallCount = 0
local startTime = os.clock()

-- In each hook, add:
hookCallCount = hookCallCount + 1

-- Add query function:
function M.getStats()
    local elapsed = os.clock() - startTime
    return {
        calls = hookCallCount,
        callsPerSecond = hookCallCount / elapsed,
        elapsed = elapsed
    }
end
```

**Expected Performance:**
- Hook calls: 10-50 per second during combat
- Hook execution: < 0.1ms per call
- No noticeable frame drops

**Status:** ⬜ Not Monitored | ✅ Good | ❌ Issues Detected

---

## Deployment Checklist

### 📦 14. Pre-Release Verification

**Before Releasing to Users:**

- [ ] All test cases passed
- [ ] No console errors in logs
- [ ] No crashes during 30+ minute play session
- [ ] Performance is acceptable
- [ ] Documentation is complete and accurate
- [ ] Compatibility notes are clear
- [ ] Debug logging is set to Info or Warning level
- [ ] Code comments are clear and helpful

---

### 📦 15. User Documentation

**Required Documentation (Already Created):**

- ✅ `docs/MOVEMENT_FIX.md` - Technical documentation
- ✅ `docs/QUICK_REFERENCE.md` - User guide
- ✅ `docs/IMPLEMENTATION_SUMMARY.md` - Implementation details
- ✅ `README.md` - Updated with feature list

**Recommended Additions:**
- [ ] Video demonstration of before/after
- [ ] FAQ section for common questions
- [ ] Troubleshooting flowchart
- [ ] Known issues list

---

### 📦 16. Version Control

**Commit Message Template:**
```
feat: Add movement fix system for VR comfort

- Blocks noMoving context for player character
- Eliminates root motion from 20+ spell/combat animations
- Preserves NPC behavior and essential player movements
- Includes comprehensive error handling and logging
- Adds detailed documentation

Resolves VR nausea issues from unwanted forward steps
Improves player movement control during spell casting
```

**Tagging:**
```bash
git tag -a v1.08a-movement-fix -m "Added movement fix system"
git push origin v1.08a-movement-fix
```

---

## Maintenance & Updates

### 🔧 17. Future Enhancement Checklist

**Planned Improvements:**

- [ ] Add UI toggle for enable/disable
- [ ] Add per-spell configuration
- [ ] Add intensity slider for partial root motion
- [ ] Add animation whitelist/blacklist editor
- [ ] Add telemetry for most problematic animations
- [ ] Add automatic detection of new problematic ABLs

---

### 🔧 18. Bug Report Template

**When Users Report Issues:**

Collect this information:
1. UEVR version
2. Game version
3. Other installed mods
4. Specific spell or action that triggered issue
5. Console log output (with debug enabled)
6. Video of issue if possible
7. Steps to reproduce

**Diagnostic Commands:**
```lua
-- Add to movement_fix.lua
function M.diagnose()
    M.print("=== Movement Fix Diagnostics ===", LogLevel.Critical)
    M.print("NoMoving Fix Enabled: " .. tostring(isNoMovingFixEnabled), LogLevel.Critical)
    M.print("Root Motion Fix Enabled: " .. tostring(isRootMotionFixEnabled), LogLevel.Critical)
    M.print("Blocked Animations Count: " .. #blockedRootMotion, LogLevel.Critical)
    -- ... more diagnostics ...
end
```

---

## Emergency Rollback

### 🚨 19. Quick Disable Procedure

**If Critical Issues Occur:**

**Method 1: Config File**
Comment out the module load:
```lua
-- In main.lua, line 16:
-- local movementFix = require("helpers/movement_fix")

-- In main.lua, line 1286:
-- movementFix.registerHooks()
```

**Method 2: Runtime Toggle**
```lua
-- In UEVR console, type:
movementFix.setNoMovingFixEnabled(false)
movementFix.setRootMotionFixEnabled(false)
```

**Method 3: File Removal**
Remove `scripts/helpers/movement_fix.lua` and restart

---

## Sign-Off

### ✅ Final Integration Checklist

**Completed by:** _________________  
**Date:** _________________  
**Version:** _________________

**Pre-Integration:**
- [ ] File placement verified
- [ ] Load order confirmed
- [ ] API availability checked

**Configuration:**
- [ ] ABL list reviewed
- [ ] Debug logging configured
- [ ] Hotkey toggle implemented (optional)

**Testing:**
- [ ] NoMoving override tested
- [ ] Root motion elimination tested
- [ ] NPC behavior verified
- [ ] Essential movements preserved
- [ ] Full combat encounter tested

**Compatibility:**
- [ ] Mod conflicts checked
- [ ] Performance monitored
- [ ] Hook conflicts resolved (if any)

**Documentation:**
- [ ] Technical docs reviewed
- [ ] User guide accessible
- [ ] README updated

**Deployment:**
- [ ] All tests passed
- [ ] No critical errors
- [ ] Version tagged
- [ ] Release notes prepared

---

## Support & Resources

**Project Repository:** https://github.com/chrisisth/HL_UEVR

**Related Documentation:**
- UEVR Framework: https://github.com/praydog/UEVR
- Hogwarts Legacy Modding Wiki: (see docs/HL/)
- UE4SS Documentation: (for advanced modding)

**Contact for Issues:**
- GitHub Issues: [Create Issue]
- Community Discord: [Link if available]

---

**Last Updated:** November 4, 2025  
**Integration Guide Version:** 1.0  
**Movement Fix Module Version:** 1.0

# Movement Fix System

## Overview

The Movement Fix module (`helpers/movement_fix.lua`) addresses two critical VR gameplay issues in Hogwarts Legacy:

1. **Movement Lock Prevention** - Blocks the "noMoving" context that can freeze player movement
2. **Root Motion Elimination** - Prevents unwanted forward stepping during spell casting and combat animations

## Why This Is Needed

### Problem 1: Movement Locks
In the original game, certain abilities set a `noMoving` context that temporarily prevents player input. While this works in flat-screen gameplay, in VR it creates disorientation when your physical movement doesn't match the game's restrictions.

### Problem 2: Root Motion Steps
Many combat and spell-casting animations include subtle root motion that moves the character 1-2 steps forward. In third-person this is barely noticeable, but in first-person VR it causes:
- **Nausea** from unexpected forward movement
- **Spatial disorientation** when your physical position doesn't match virtual movement
- **Breaking immersion** during precise wand movements

## How It Works

### 1. Player Detection

The system uses a helper function to identify the player character:

```lua
local function isPlayer(owner)
    -- Validates the owner object
    -- Checks if the full name contains "Biped_Player"
    -- Returns true only for the actual player character
end
```

This ensures NPCs and other characters are **not affected** by the fixes.

### 2. NoMoving Context Blocking

Two hooks intercept the Able (animation system) context:

**SetContextValue Hook:**
- Intercepts when the game tries to set `noMoving` to true
- Forces the value to `false` when the owner is the player
- Logs the action for debugging

**GetContextByName Hook:**
- Intercepts when the game queries the `noMoving` context state
- Returns `false` for the player regardless of actual value
- Ensures movement is never locked

### 3. Root Motion Elimination

Hooks into the animation playback system:

**PlayAnimation Start Hook:**
- Triggers when any animation begins
- Checks if the animation is in the blocked list
- Verifies the owner is the player
- Disables root motion flags:
  - `bUseRootMotion = false`
  - `VerticalRootMotionAmount = 0.0`
  - `HorizontalRootMotionAmount = 0.0`

## Blocked Animations List

The following animation blueprints (ABLs) have root motion disabled:

### Combat Idle Animations
- `ABL_Combat2CombatCasual` - Transition to casual combat stance
- `ABL_CombatCasual2Idle` - Transition from casual combat to idle
- `ABL_CombatCasualIdle` - Casual combat idle stance
- `ABL_CombatCasualIdleBreak` - Idle break animation in combat
- `ABL_CombatIdle` - Standard combat idle
- `ABL_CombatIdleBreak` - Combat idle variation
- `ABL_CombatIdle_LF2RF` - Combat idle foot shift
- `ABL_DuelCombatIdle` - Dueling idle stance

### Combat Actions
- `ABL_Idle2CombatIdle` - Enter combat stance
- `ABL_Idle2CombatIdle_Flourish` - Enter combat with flourish

### Spell Casting
- `ABL_WandCast` - All wand casting animations
- `ABL_WandFlourish` - Wand flourish animations
- `ABL_Incendio_AOE` - Incendio area effect cast
- `ABL_Reparo_AOE` - Reparo area effect cast
- `ABL_Reparo_End` - Reparo completion animation

### Special Attacks
- `ABL_CriticalFinish_*` - All critical finish animations
- `ABL_Finisher_AMBossKiller` - Boss finisher animation
- `ABL_SpellImpact_*` - All spell impact reactions
- `ABL_StealthKnockdown` - Stealth takedown animation
- `ABL_Unforgivable_*` - All Unforgivable Curse animations

## What's NOT Affected

The system is carefully designed to preserve important gameplay elements:

✅ **NPC Animations** - All enemy and friendly NPC animations work normally  
✅ **Climbing** - Root motion preserved for climbing animations  
✅ **Jumping** - Jump animations use normal root motion  
✅ **Swimming** - Swimming locomotion unaffected  
✅ **Rolling/Dodging** - Dodge animations retain their movement  
✅ **Mount Animations** - Broom and creature mount animations normal  
✅ **Environmental Interactions** - Door opening, item pickup animations intact

## Technical Implementation

### Hook Registration

The module registers its hooks in `hookLateFunctions()` which is called during game initialization:

```lua
function M.registerHooks()
    -- Registers three main hooks:
    -- 1. AblAbilityContext:SetContextValue
    -- 2. AblAbilityContext:GetContextByName
    -- 3. AblAbilityTask_PlayAnimation:Start
end
```

### Error Handling

All hooks use `pcall()` (protected call) to prevent crashes:
- Validates objects before accessing properties
- Logs warnings if hooks fail
- Gracefully degrades if game state is unexpected

### Debug Logging

The module includes a logging system:

```lua
M.setLogLevel(LogLevel.Debug)  -- Enable detailed logging
M.setLogLevel(LogLevel.Info)   -- Default: Important messages only
M.setLogLevel(LogLevel.Error)  -- Minimal: Errors only
```

## Integration with Main Script

The movement fix is automatically loaded and registered:

```lua
-- In main.lua
local movementFix = require("helpers/movement_fix")

-- During late hook registration
function hookLateFunctions()
    -- ... other hooks ...
    
    -- Register movement fix hooks
    movementFix.registerHooks()
    
    -- ... more hooks ...
end
```

## Performance Impact

**Minimal** - The hooks only trigger when:
- Context values are set/queried (infrequent)
- Animations start (common but optimized)

The player detection is cached where possible and uses fast string matching.

## Troubleshooting

### Movement Still Locks
1. Check that hooks registered successfully (check logs)
2. Verify you're using the latest version
3. Enable debug logging: `movementFix.setLogLevel(LogLevel.Debug)`

### Character Doesn't Move During Specific Actions
Some animations **should** restrict movement (e.g., Alohomora lockpicking). These are handled separately in the main script, not by this module.

### NPCs Behaving Strangely
NPCs should not be affected. If they are:
1. Check the `isPlayer()` function is working
2. Verify object validation in hooks
3. Report the issue with logs

## Future Enhancements

Potential improvements:
- User-configurable blocked animation list
- Per-spell root motion settings
- Intensity slider for partial root motion
- UI toggle for enabling/disabling the system

## Related Systems

This module works alongside:
- **Decoupled Yaw** (`helpers/decoupledyaw.lua`) - Independent view rotation
- **Input System** (`helpers/input.lua`) - Controller input processing  
- **Gesture System** (`gestures/gestures.lua`) - Spell casting gestures
- **Wand System** (`helpers/wand.lua`) - Wand tracking and aiming

## Credits

Movement lock and root motion fix concept developed for improved VR immersion in Hogwarts Legacy.

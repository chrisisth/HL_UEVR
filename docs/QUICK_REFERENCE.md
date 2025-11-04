# Movement Fix - Quick Reference

## ⚠️ Before Using: Verification Required

**This mod requires API verification before use.** The implementation was adapted from a different hook system and needs testing.

**Quick Verification:**
1. Enable debug logging in `movement_fix.lua` (line 14): `local currentLogLevel = LogLevel.Debug`
2. Cast a spell in combat
3. Check console for `[movement_fix]` messages
4. If you see hook messages → Working ✓
5. If no messages → Parameter names need correction (see DEVELOPER_HANDOFF.md)

---

## What Does It Do?

**Prevents two major VR comfort issues:**

1. ❌ **Blocks movement locks** - You can always move, even during spell animations
2. ❌ **Stops unwanted forward steps** - No more surprise 1-2 step movements during combat

## How to Use

**Nothing!** It's automatic once the mod is loaded.

## Affected Actions

### ✅ Fixed (No More Unwanted Movement)
- Wand casting animations
- Combat idle stances
- Spell flourishes
- Critical finishers
- Unforgivable curses
- Reparo/Incendio area effects
- Stealth takedowns
- Entering/exiting combat mode

### ✅ Still Works Normally
- Dodging/rolling
- Jumping
- Climbing
- Swimming
- Riding brooms
- Riding creatures
- Opening doors
- Picking up items
- All NPC animations

## Troubleshooting

### "I'm still getting locked in place!"
- Check console logs for errors
- Verify the mod loaded correctly
- Some intentional locks (like Alohomora) are handled separately

### "My character won't move during [X]"
- This might be intentional game design
- Check if it happens without the mod
- Report if it's a new issue

### "NPCs are acting weird"
- NPCs should be unaffected
- If they are affected, please report with logs

## Technical Info

**Module:** `scripts/helpers/movement_fix.lua`  
**Hooks Used:** 3 (AblAbilityContext x2, AblAbilityTask_PlayAnimation x1)  
**Performance:** Minimal impact  
**Compatibility:** Works with all other HL_UEVR features

## Debug Commands

**Run Diagnostics:**
```lua
movementFix.diagnose()
```
Shows module status and testing instructions.

**Enable Detailed Logging:**
```lua
movementFix.setLogLevel(LogLevel.Debug)
```

**Verify Hooks Are Working:**
Cast a spell and look for these messages:
```
[movement_fix] Movement fix hooks registered successfully
[movement_fix] Blocking noMoving context for player (was: true)
[movement_fix] Disabling root motion for: [animation name]
```

**If you see NO messages:**
- Hooks may not be firing
- Parameter names may be incorrect
- See DEVELOPER_HANDOFF.md "API Verification Required" section

---

Enable detailed logging in `movement_fix.lua`:

```lua
-- Change line 14 from:
local currentLogLevel = LogLevel.Info

-- To:
local currentLogLevel = LogLevel.Debug
```

This will show when movements are blocked in the console.

## For Developers

### Adding More Blocked Animations

Edit the `blockedRootMotion` table in `movement_fix.lua`:

```lua
local blockedRootMotion = {
    "ABL_YourAnimationName",
    "ABL_AnotherAnimation",
    -- ... existing entries ...
}
```

### Checking If Animation Should Be Blocked

Use substring matching. For example:
- `"ABL_WandCast"` blocks all animations containing "ABL_WandCast"
- `"ABL_CriticalFinish_"` blocks all variations starting with that prefix

### Player Detection

The system only affects the player character identified by:
- Valid UObject
- Full name contains `"Biped_Player"`

## Related Features

- **Decoupled Yaw:** Independent head rotation
- **Gesture System:** Draw spells in 3D space
- **Locomotion Modes:** Head/Hand/Game direction movement
- **Wand Tracking:** VR controller-based spell aiming

## Version History

**v1.0** (Nov 4, 2025)
- Initial implementation
- 20+ blocked animations
- NPC-safe filtering
- Comprehensive error handling

---

**Need Help?** Check `docs/MOVEMENT_FIX.md` for detailed documentation.

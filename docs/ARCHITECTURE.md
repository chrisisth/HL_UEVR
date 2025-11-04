# Movement Fix - System Architecture

## Visual Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOGWARTS LEGACY VR MOD                       │
│                         (HL_UEVR)                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         main.lua                                │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  function UEVRReady()                                      │ │
│  │    ├─ config.init()                                        │ │
│  │    ├─ initLevel()                                          │ │
│  │    ├─ hookLateFunctions()  ◄─── Movement Fix Registered   │ │
│  │    └─ checkStartPageIntro()                                │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              helpers/movement_fix.lua (NEW)                     │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  M.registerHooks()                                         │ │
│  │    ├─ Hook: AblAbilityContext::SetContextValue            │ │
│  │    ├─ Hook: AblAbilityContext::GetContextByName           │ │
│  │    └─ Hook: AblAbilityTask_PlayAnimation::Start           │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Helper Functions                                          │ │
│  │    ├─ isPlayer(owner) → bool                               │ │
│  │    └─ isBlockedAbility(name) → bool                        │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  GAME ANIMATION SYSTEM                          │
│                      (Able Framework)                           │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Flow 1: NoMoving Context Blocking

```
┌──────────────┐
│ Game Logic   │
│ Sets Context │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ AblAbilityContext::SetContextValue      │
│                                         │
│ Parameters:                             │
│  - ContextName: "noMoving"              │
│  - Value: true                          │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Movement Fix Hook (Pre-execution)       │
│                                         │
│ if (contextName contains "noMoving")    │
│    and isPlayer(owner):                 │
│      locals.Value = false  ◄─── OVERRIDE│
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Original Function Executes              │
│  - Sets context to FALSE (not true)     │
└──────┬──────────────────────────────────┘
       │
       ▼
┌──────────────┐
│ Player Never │
│    Locked    │ ✓
└──────────────┘
```

### Flow 2: Root Motion Elimination

```
┌──────────────┐
│ Spell Cast   │
│  Animation   │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ AblAbilityTask_PlayAnimation::Start     │
│                                         │
│ Animation: "ABL_WandCast_Fire"          │
│ Owner: Biped_Player_C                   │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Movement Fix Hook (Pre-execution)       │
│                                         │
│ Is Owner Player?                        │
│    YES ──┐                              │
│    NO ───┼──► Allow Normal ──► Exit     │
│          │                              │
│          ▼                              │
│ Is Animation Blocked?                   │
│    YES ──┐                              │
│    NO ───┼──► Allow Normal ──► Exit     │
│          │                              │
│          ▼                              │
│ Disable Root Motion:                    │
│  - bUseRootMotion = false               │
│  - VerticalRootMotionAmount = 0.0       │
│  - HorizontalRootMotionAmount = 0.0     │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Animation Plays                         │
│  - No Forward Movement                  │
│  - Visual Animation Only                │
└──────┬──────────────────────────────────┘
       │
       ▼
┌──────────────┐
│  Character   │
│ Stays Still  │ ✓
└──────────────┘
```

### Flow 3: NPC Safety Check

```
┌──────────────┐
│  NPC Casts   │
│    Spell     │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ AblAbilityTask_PlayAnimation::Start     │
│                                         │
│ Owner: BP_Enemy_Bandit_C                │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Movement Fix Hook                       │
│                                         │
│ isPlayer(owner) ?                       │
│    Check: "BP_Enemy_Bandit_C"           │
│    Contains "Biped_Player"? NO          │
│                                         │
│    return false ──► Exit Hook           │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ Original Function Executes              │
│  - Root Motion ENABLED                  │
│  - Normal NPC Behavior                  │
└──────┬──────────────────────────────────┘
       │
       ▼
┌──────────────┐
│ NPC Animates │
│   Normally   │ ✓
└──────────────┘
```

## Component Interaction Map

```
┌─────────────────────────────────────────────────────────────┐
│                         UEVR FRAMEWORK                      │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ hook_function│  │ UObjectHook  │  │ Game Engine API │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬────────┘  │
│         │                  │                    │           │
└─────────┼──────────────────┼────────────────────┼───────────┘
          │                  │                    │
          ▼                  ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                   MOVEMENT FIX MODULE                       │
│                                                             │
│  ┌─────────────────────┐      ┌──────────────────────┐    │
│  │  Hook Registrations │      │   Helper Functions    │    │
│  │  ─────────────────  │      │  ──────────────────   │    │
│  │  - SetContextValue  │◄────►│  - isPlayer()         │    │
│  │  - GetContextByName │      │  - isBlockedAbility() │    │
│  │  - PlayAnimation    │      │  - Logging            │    │
│  └─────────────────────┘      └──────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Configuration                                       │  │
│  │  ─────────────                                       │  │
│  │  blockedRootMotion[] = {                            │  │
│  │    "ABL_WandCast",                                  │  │
│  │    "ABL_CriticalFinish_",                           │  │
│  │    ... 20+ entries ...                              │  │
│  │  }                                                   │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          │                  │                    │
          ▼                  ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│              HOGWARTS LEGACY GAME ENGINE                    │
│  ┌──────────────────┐  ┌──────────────────────────────┐   │
│  │  Able Animation  │  │    Character Movement        │   │
│  │     System       │  │         System               │   │
│  │  ──────────────  │  │  ─────────────────────────   │   │
│  │  - Contexts      │  │  - Root Motion               │   │
│  │  - ABL Tasks     │  │  - Character Controller      │   │
│  │  - Animations    │  │  - Physics                   │   │
│  └──────────────────┘  └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## State Machine: Player Movement Control

```
                    ┌─────────────────┐
                    │  Idle / Moving  │
                    └────────┬────────┘
                             │
                   Player Casts Spell
                             │
                             ▼
            ┌────────────────────────────────┐
            │  WITHOUT Movement Fix          │    │  WITH Movement Fix      │
            ├────────────────────────────────┤    ├─────────────────────────┤
            │                                │    │                         │
            │  1. noMoving = true            │    │  1. noMoving = false ✓  │
            │     └► Player LOCKED 🔒        │    │     └► Player FREE ✓    │
            │                                │    │                         │
            │  2. Root Motion Active         │    │  2. Root Motion = 0 ✓   │
            │     └► Steps Forward ❌        │    │     └► Stays Still ✓    │
            │                                │    │                         │
            │  RESULT: Disorienting          │    │  RESULT: Comfortable    │
            └────────────────────────────────┘    └─────────────────────────┘
                             │                                 │
                             └─────────────┬─────────────────┘
                                           │
                                Animation Completes
                                           │
                                           ▼
                                  ┌─────────────────┐
                                  │  Idle / Moving  │
                                  └─────────────────┘
```

## Module Dependencies

```
movement_fix.lua
    │
    ├── require("libs/uevr_utils")
    │       │
    │       ├── UEVR API wrappers
    │       ├── Object validation
    │       └── Logging utilities
    │
    └── Uses (Direct UEVR API):
            ├── hook_function()
            ├── UEVR_UObjectHook.exists()
            ├── UObject methods
            └── Lua standard library (pcall, string, etc.)
```

## Hook Execution Timeline

```
T=0ms    Player Presses Spell Cast Button
│
├─ T=10ms   Game Begins Animation Setup
│           └── Creates AblAbilityTask_PlayAnimation
│
├─ T=12ms   Task.Start() Called
│           │
│           ├─► Movement Fix Hook Intercepts ◄───┐
│           │   ├─ Check: isPlayer(owner)        │
│           │   ├─ Check: isBlockedAbility()     │ < 1ms
│           │   └─ Modify: root motion flags     │
│           │                                     │
│           └─► Original Function Continues ◄────┘
│
├─ T=15ms   Animation Begins Playing
│           └── With Modified Root Motion (disabled)
│
├─ T=500ms  Animation Plays (no movement)
│
└─ T=520ms  Animation Completes
            └── Player Free to Move
```

## Error Handling Flow

```
┌──────────────────────┐
│   Hook Triggered     │
└──────┬───────────────┘
       │
       ▼
┌────────────────────────────────────┐
│  pcall(function()                  │
│    ... hook logic ...              │
│  end)                              │
└──────┬─────────────────────┬───────┘
       │                     │
   Success               Failure
       │                     │
       ▼                     ▼
┌──────────────┐    ┌────────────────────┐
│ Continue     │    │ Log Warning        │
│ Normal       │    │ Return Early       │
│ Execution    │    │ Prevent Crash      │
└──────────────┘    └────────────────────┘
```

## Performance Profile

```
Activity                    Frequency       Impact
─────────────────────────────────────────────────────
Hook Registration           Once (startup)  Negligible
isPlayer() Check           Per hook call    ~0.001ms
String Pattern Match       Per blocked ABL  ~0.005ms
Property Access            Per ABL blocked  ~0.002ms
Total per Spell Cast                        ~0.01ms

Expected Hook Calls During Combat:
├── Idle Animations:      5-10/sec
├── Spell Casts:          1-3/sec
├── Context Changes:      2-5/sec
└── TOTAL:               ~10-20/sec

Frame Time Impact: < 0.1ms per frame (negligible)
```

## Code Organization

```
scripts/helpers/movement_fix.lua (180 lines)
│
├─ Lines 1-15:    Module setup, logging
├─ Lines 16-36:   Helper: isPlayer()
├─ Lines 38-58:   Config: blockedRootMotion[]
├─ Lines 60-63:   Helper: isBlockedAbility()
├─ Lines 65-68:   M.registerHooks() declaration
├─ Lines 70-111:  Hook: noMoving context blocking
├─ Lines 113-145: Hook: root motion elimination
├─ Lines 147-149: Success logging
└─ Lines 151-180: Return module
```

---

**Legend:**
- ✓ = Success/Desired Behavior
- ✗ = Problem/Undesired Behavior  
- ─► = Data Flow
- ◄─ = Hook Intercept
- 🔒 = Locked State

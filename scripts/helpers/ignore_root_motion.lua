local uevrUtils = require("libs/uevr_utils")
local configui = require("libs/configui")

local PANEL = {
    panelLabel = "Mods / Fixes",
    saveFile = "config_mods",
    layout = {
        {
            widgetType = "checkbox",
            id = "enable_force_root_lock",
            label = "Enable IgnoreRootMotion for combat animations",
            initialValue = true,
        }
        ,{
            widgetType = "checkbox",
            id = "use_movement_toggle",
            label = "Use CharacterMovement toggle instead of asset root-lock",
            initialValue = false,
        }
    }
}

configui.create({PANEL})

local abilityAssets = setmetatable({}, { __mode = "k" }) -- ability -> {asset = true}

local function valid(o) return uevrUtils.validate_object(o) ~= nil end

local function set_lock(asset, v)
    if not valid(asset) then return end
    pcall(function() asset.bForceRootLock = v end)
end

local function handle_start(fn, obj, locals, result)
    pcall(function()
        if not valid(obj) then return end
        local use_asset_lock = configui.getValue("enable_force_root_lock")
        local use_movement_toggle = configui.getValue("use_movement_toggle")
        if not use_asset_lock and not use_movement_toggle then return end
        local pawn = uevrUtils.get_local_pawn()
        if pawn == nil then return end

        -- check owner or locals for pawn
        local isPlayer = false
        if obj.GetOwner ~= nil then
            local ok, owner = pcall(function() return obj:GetOwner() end)
            if ok and owner == pawn then isPlayer = true end
        end
        if not isPlayer then
            for k, v in pairs(locals or {}) do
                if v == pawn then isPlayer = true; break end
                if type(v) == "table" then
                    for _, sub in pairs(v) do if sub == pawn then isPlayer = true; break end end
                    if isPlayer then break end
                end
            end
        end
        if not isPlayer then return end

        local mesh = uevrUtils.getValid(pawn, {"Mesh"})
        if mesh == nil then return end
        local animInst = nil
        pcall(function() animInst = mesh:GetAnimInstance() end)
        if animInst == nil then return end

        local montages = {}
        pcall(function()
            local ok, m = pcall(function() return animInst:GetCurrentActiveMontage() end)
            if ok and m ~= nil then table.insert(montages, m) end
            if #montages == 0 and animInst.ActiveMontages ~= nil then
                for _, am in ipairs(animInst.ActiveMontages) do table.insert(montages, am) end
            end
        end)

        -- If using movement-toggle, don't touch assets: disable CharacterMovement and store pawn for restore
        if use_movement_toggle then
            local aset = { __movement = true, pawn = pawn }
            abilityAssets[obj] = aset
            pcall(function()
                if pawn.CharacterMovement ~= nil then
                    pawn.CharacterMovement:SetActive(false, false)
                    pawn.CharacterMovement:SetComponentTickEnabled(false)
                end
            end)
            return
        end

        local aset = {}
        for _, montage in ipairs(montages) do
            pcall(function()
                local slots = montage.SlotAnimTracks or {}
                for _, slot in ipairs(slots) do
                    local track = slot.AnimTrack or slot.Track or slot.Anim
                    if track and track.AnimSegments then
                        for _, seg in ipairs(track.AnimSegments) do
                            local asset = seg.AnimReference or seg.Anim or seg.Animation or seg.AnimToPlay or seg.AnimSequence
                            if asset and valid(asset) then
                                set_lock(asset, true)
                                aset[asset] = true
                            end
                        end
                    end
                end
            end)
        end
        if next(aset) ~= nil then abilityAssets[obj] = aset end
    end)
    return true
end

local function handle_end(fn, obj, locals, result)
    pcall(function()
        if not valid(obj) then return end
        local aset = abilityAssets[obj]
        if aset == nil then return end
        if aset.__movement and aset.pawn ~= nil then
            pcall(function()
                local pawn = aset.pawn
                if pawn.CharacterMovement ~= nil then
                    pawn.CharacterMovement:SetActive(true, false)
                    pawn.CharacterMovement:SetComponentTickEnabled(true)
                end
            end)
        else
            for asset, _ in pairs(aset) do set_lock(asset, false) end
        end
        abilityAssets[obj] = nil
    end)
    return true
end

local function install_hooks()
    local classStr = "Class /Script/AbleCore.AblAbilityBlueprintGeneratedClass"
    local instances = uevrUtils.find_all_of(classStr, true)
    for _, inst in ipairs(instances) do
        local ok, name = pcall(function() return inst:get_full_name() end)
        if ok and name and string.find(name, "ABL_Wand") then
            pcall(function()
                hook_function(name, "OnAbilityStart", false, handle_start, nil, false)
                hook_function(name, "OnAbilityEnd", false, handle_end, nil, false)
            end)
        end
    end
end

uevr.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
    local ok = pcall(install_hooks)
end)

-- restore all assets if user turns feature off
uevr.sdk.callbacks.on_pre_engine_tick(function(engine, delta)
    if configui.getValue("enable_force_root_lock") then return end
    for abilityObj, aset in pairs(abilityAssets) do
        if aset.__movement and aset.pawn ~= nil then
            pcall(function()
                local pawn = aset.pawn
                if pawn.CharacterMovement ~= nil then
                    pawn.CharacterMovement:SetActive(true, false)
                    pawn.CharacterMovement:SetComponentTickEnabled(true)
                end
            end)
        else
            for asset, _ in pairs(aset) do set_lock(asset, false) end
        end
        abilityAssets[abilityObj] = nil
    end
end)

local M = {}
return M


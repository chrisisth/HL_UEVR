local api = uevr.api
local vr = uevr.params.vr

local prevViewTarget = nil
local game_engine_class = uevr.api:find_uobject("Class /Script/Engine.GameEngine")

local classCache = {}
function get_class(name, clearCache)
	if clearCache or classCache[name] == nil then
		classCache[name] = uevr.api:find_uobject(name)
	end
    return classCache[name]
end


local config_filename = "cinematicszoom.txt"
local config_data = nil
local config_changed = false
local forward_offset_multiplier = 1
local up_offset_multiplier = 0
local fov_max_trigger = 200
local current_fov = 0
local enable_fov_zoom = true
local enable_conv_distance = true
local conversation_depth = 0.5
local conversation_size = 0.5
local conversation_y_offset = 0
local normal_depth = 2
local normal_size = 2
local normal_y_offset = 0
local fov_max_trigger_set = false

local function write_config()
	config_data = "forward_offset_multiplier=" .. tostring(forward_offset_multiplier) .. "\n"   
    config_data = config_data .. "up_offset_multiplier=" .. tostring(up_offset_multiplier) .. "\n"        
    config_data = config_data .. "enable_fov_zoom=" .. tostring(enable_fov_zoom) .. "\n"             
    config_data = config_data .. "fov_max_trigger=" .. tostring(fov_max_trigger) .. "\n"
    config_data = config_data .. "fov_max_trigger_set=" .. tostring(fov_max_trigger_set) .. "\n"
    config_data = config_data .. "enable_conv_distance=" .. tostring(enable_conv_distance) .. "\n"                 
    config_data = config_data .. "conversation_depth=" .. tostring(conversation_depth) .. "\n"             
    config_data = config_data .. "conversation_size=" .. tostring(conversation_size) .. "\n"          
    config_data = config_data .. "conversation_y_offset=" .. tostring(conversation_y_offset) .. "\n"          
    config_data = config_data .. "normal_depth=" .. tostring(normal_depth) .. "\n"             
    config_data = config_data .. "normal_size=" .. tostring(normal_size) .. "\n"          
    config_data = config_data .. "normal_y_offset=" .. tostring(normal_y_offset) .. "\n"          
                  
    fs.write(config_filename, config_data)
end

local function read_config()
    print("reading config")
    config_data = fs.read(config_filename)
    if config_data then -- Check if file was read successfully
        print("config read")
        for key, value in config_data:gmatch("([^=]+)=([^\n]+)\n?") do
            print("parsing key:", key, "value:", value)            
            if key == "forward_offset_multiplier" then
                forward_offset_multiplier = tonumber(value) or 1            
            end  
            if key == "up_offset_multiplier" then
                up_offset_multiplier = tonumber(value) or 0            
            end                   
            if key == "fov_max_trigger" then
                fov_max_trigger = tonumber(value) or 200            
            end      
            if key == "fov_max_trigger_set" then
                if value == "false" then
                    fov_max_trigger_set = false
                else
                    fov_max_trigger_set = true
                end                    
            end              
            if key == "enable_fov_zoom" then
                if value == "false" then
                    enable_fov_zoom = false
                else
                    enable_fov_zoom = true
                end                    
            end 
            if key == "enable_conv_distance" then
                if value == "false" then
                    enable_conv_distance = false
                else
                    enable_conv_distance = true
                end                    
            end             
            if key == "conversation_depth" then
                conversation_depth = tonumber(value) or 0.5
            end 
            if key == "conversation_size" then
                conversation_size = tonumber(value) or 0.5          
            end                   
            if key == "conversation_y_offset" then
                conversation_y_offset = tonumber(value) or 0          
            end                   
            if key == "normal_depth" then
                normal_depth = tonumber(value) or 2
            end 
            if key == "normal_size" then
                normal_size = tonumber(value) or 2
            end                   
            if key == "normal_y_offset" then
                normal_y_offset = tonumber(value) or 0          
            end                   
        end
    else
        print("Error: Could not read config file.")
    end
end

uevr.lua.add_script_panel("Cinematics Zoom", function()
    imgui.text("Cinematics Zoom")    
    imgui.text("")
    imgui.text("Set variables to control zoom levels of cinematics")    
    imgui.text("")
    imgui.text(string.format("Current FOV: %.2f", current_fov))    
    imgui.text("")
    local needs_save = false
    local changed, new_value        

    changed, new_value = imgui.checkbox("Manually set FOV Trigger", fov_max_trigger_set)
    if changed then
        needs_save = true
        fov_max_trigger_set = new_value -- Correctly use new_value                
    end  

    imgui.text("Uncheck above to auto detect the normal FOV used in game")

    changed, new_value = imgui.slider_float("FOV Trigger Value", fov_max_trigger, 0, 150)
    if changed then
        needs_save = true
        fov_max_trigger = new_value -- Correctly use new_value                
        fov_max_trigger_set = true
    end        

    imgui.text("")

    changed, new_value = imgui.checkbox("Enable Zoom", enable_fov_zoom)
    if changed then
        needs_save = true
        enable_fov_zoom = new_value -- Correctly use new_value                
    end  

    changed, new_value = imgui.slider_float("Forward Offset Multiplier", forward_offset_multiplier, 0, 5)
    if changed then
        needs_save = true
        forward_offset_multiplier = new_value -- Correctly use new_value                
    end     

    changed, new_value = imgui.slider_float("Up Offset Multiplier", up_offset_multiplier, 0, 10)
    if changed then
        needs_save = true
        up_offset_multiplier = new_value -- Correctly use new_value                
    end  

    imgui.text("")
    
    changed, new_value = imgui.checkbox("Enable Conversation UI Change", enable_conv_distance)
    if changed then
        needs_save = true
        enable_conv_distance = new_value -- Correctly use new_value                
        if enable_conv_distance == false then
            uevr.params.vr.set_mod_value("UI_Distance",normal_depth)
            uevr.params.vr.set_mod_value("UI_Size",normal_size) 
            uevr.params.vr.set_mod_value("UI_Y_Offset",normal_y_offset)                                 
        end
    end

    changed, new_value = imgui.slider_float("Conversation UI Depth", conversation_depth, 0, 10)
    if changed then
        needs_save = true
        conversation_depth = new_value -- Correctly use new_value                        
    end  

    changed, new_value = imgui.slider_float("Conversation UI Size", conversation_size, 0, 10)
    if changed then
        needs_save = true
        conversation_size = new_value -- Correctly use new_value                
    end   

    changed, new_value = imgui.slider_float("Conversation Y Offset", conversation_y_offset, -0.5, 0.5)
    if changed then
        needs_save = true
        conversation_y_offset = new_value -- Correctly use new_value                
    end
    
    changed, new_value = imgui.slider_float("Normal UI Depth", normal_depth, 0, 10)
    if changed then
        needs_save = true
        normal_depth = new_value -- Correctly use new_value                
    end  

    changed, new_value = imgui.slider_float("Normal UI Size", normal_size, 0, 10)
    if changed then
        needs_save = true
        normal_size = new_value -- Correctly use new_value                
    end   

    changed, new_value = imgui.slider_float("Normal Y Offset", normal_y_offset, -0.5, 0.5)
    if changed then
        needs_save = true
        normal_y_offset = new_value -- Correctly use new_value                
    end

    if needs_save then
        config_changed = true
        write_config()
    end
end)

read_config()

-- run this every engine tick, *after* the world has been updated
uevr.sdk.callbacks.on_post_engine_tick(function(engine, delta)   	    
    local game_engine       = UEVR_UObjectHook.get_first_object_by_class(game_engine_class)
    local player            = uevr.api:get_player_controller(0)
    if player then                       
        local pawn = uevr.api:get_local_pawn(0)
        if pawn then
            local playerController = pawn.Controller
            if playerController ~= nil then	
                local cameraManager = playerController.PlayerCameraManager
                if cameraManager ~= nil then
                    local target = cameraManager.ViewTarget.Target
                    current_fov = 0
                    if (cameraManager and cameraManager.ViewTarget and cameraManager.ViewTarget.POV and cameraManager.ViewTarget.POV.FOV) then
                        current_fov = cameraManager.ViewTarget.POV.FOV                        
                        if fov_max_trigger_set == false and (current_fov >= fov_max_trigger or fov_max_trigger == 200) then
                            fov_max_trigger = current_fov
                            write_config()
                        end
                    end                                                   
                end
            end
        end
        if enable_fov_zoom and current_fov>1 and current_fov<fov_max_trigger then                                                                    
            local forward = (fov_max_trigger-current_fov)*forward_offset_multiplier                            
            if (forward > 0) then
                uevr.params.vr.set_mod_value("VR_CameraForwardOffset",forward)
            end

            local up = (fov_max_trigger-current_fov)
            if (up>0) then
                up=up*up_offset_multiplier                                
                uevr.params.vr.set_mod_value("VR_CameraUpOffset",up)
            end                                      
            
            if enable_conv_distance then
                uevr.params.vr.set_mod_value("UI_Distance",conversation_depth)
                uevr.params.vr.set_mod_value("UI_Size",conversation_size)   
                uevr.params.vr.set_mod_value("UI_Y_Offset",conversation_y_offset)                   
            end
        else
            uevr.params.vr.set_mod_value("VR_CameraForwardOffset",0)
            uevr.params.vr.set_mod_value("VR_CameraUpOffset",0)       
               
            if enable_conv_distance then
                uevr.params.vr.set_mod_value("UI_Distance",normal_depth)
                uevr.params.vr.set_mod_value("UI_Size",normal_size)     
                uevr.params.vr.set_mod_value("UI_Y_Offset",normal_y_offset)                                 
            end
        end             
    end        
end)


--------------------------------------------------------
-- CopyRight (C) 2024, tidusmd. All rights reserved.
-- This mod is under the MIT License.
-- https://opensource.org/licenses/mit-license.php
--------------------------------------------------------

local Cron = require('External/Cron.lua')
local GameUI = require('External/GameUI.lua')

Type = {
    Bottom = 1,
    Top = 2,
}

VehicleDurabilityDisplay = {
	description = "Vehicle Durability Display",
	version = "1.1.0",
    type = Type.Bottom,
    -- System
    is_ready = false,
    is_hud_initialized = false,
    is_active_hp_display = false,
    cet_required_version = 32.1, -- 1.32.1
    cet_recommended_version = 32.3, -- 1.32.3
    codeware_required_version = 8.2, -- 1.8.2
    codeware_recommended_version = 9.2, -- 1.9.2
}

VehicleInfo = {
    vehicle_hp = 100,
    entity_id = nil,
    hud_car_controller = nil,
    ink_horizontal_panel = nil,
    ink_hp_title = nil,
    ink_hp_text = nil,
}

-- Table for caching HP values
HPCache = {}

ExceptionVehicle = {
    "None"
}

registerForEvent('onInit', function()

    if not VehicleDurabilityDisplay:CheckDependencies() then
        print('[VehicleDurabilityDisplay][Error] Drive an Aerial Vehicle Mod failed to load due to missing dependencies.')
        return
    end

    GameUI.Observe("SessionStart", function()
        local mounted_vehicle = Game.GetPlayer():GetMountedVehicle()
        if mounted_vehicle ~= nil then
            for _, vehicle in ipairs(ExceptionVehicle) do
                if mounted_vehicle:GetRecordID() == TweakDBID.new(vehicle) then
                    return
                end
            end
            VehicleInfo.entity_id = mounted_vehicle:GetEntityID()
            Cron.Every(0.1, {tick=1}, function(timer)
                timer.tick = timer.tick + 1
                if VehicleDurabilityDisplay.is_hud_initialized then
                    VehicleDurabilityDisplay:Show(true)
                end
                if timer.tick >= 30 then
                    Cron.Halt(timer)
                end
            end)
        end
    end)

    GameUI.Observe("SessionEnd", function()
        VehicleInfo.entity_id = nil
        VehicleDurabilityDisplay.is_hud_initialized = false
        VehicleDurabilityDisplay:Show(false)
        VehicleDurabilityDisplay:Fluff(true)
        -- Clear HP cache
        HPCache = {}
    end)

    Observe("hudCarController", "OnInitialize", function(this)
        VehicleInfo.hud_car_controller = this
        VehicleDurabilityDisplay:CreateHPDisplay()
        local mounted_vehicle = Game.GetPlayer():GetMountedVehicle()
        if mounted_vehicle ~= nil then
            VehicleInfo.entity_id = mounted_vehicle:GetEntityID()
            -- Get the latest HP value from cache
            local hash_key = tostring(VehicleInfo.entity_id.hash)  -- Convert to string
            local cached_hp = HPCache[hash_key]
            if cached_hp ~= nil then
                VehicleInfo.vehicle_hp = cached_hp
                VehicleDurabilityDisplay:SetHPDisplay()
            else
                VehicleInfo.vehicle_hp = 100  -- Default value
            end
        else
            VehicleInfo.entity_id = nil
        end
        VehicleDurabilityDisplay.is_hud_initialized = true
    end)

    Observe("hudCarController", "OnMountingEvent", function(this, evt)
        VehicleInfo.hud_car_controller = this

        VehicleInfo.entity_id = evt.request.lowLevelMountingInfo.parentId

        -- Get the latest HP value from cache (using string key)
        local hash_key = tostring(VehicleInfo.entity_id.hash)
        local cached_hp = HPCache[hash_key]
        if cached_hp ~= nil then
            VehicleInfo.vehicle_hp = cached_hp
        else
            VehicleInfo.vehicle_hp = 100  -- Default value
        end

        for _, vehicle in ipairs(ExceptionVehicle) do
            if Game.FindEntityByID(VehicleInfo.entity_id):GetRecordID() == TweakDBID.new(vehicle) then
                VehicleDurabilityDisplay:Show(false)
                VehicleDurabilityDisplay:Fluff(true)
                return
            end
        end
        VehicleDurabilityDisplay:SetHPDisplay()
        VehicleDurabilityDisplay:Show(true)
        VehicleDurabilityDisplay:Fluff(false)
    end)

    Observe("hudCarController", "OnUnmountingEvent", function(this, evt)
        VehicleInfo.hud_car_controller = this
        VehicleDurabilityDisplay:Show(false)
        VehicleDurabilityDisplay:Fluff(true)
    end)

    Observe("VehicleComponent", "ReactToHPChange", function(this, destruction)
        local entity_id = this:GetEntity():GetEntityID()
        local hash = entity_id.hash

        -- Convert hash value to string and use as key
        local hash_key = tostring(hash)
        HPCache[hash_key] = destruction

        -- Only update display if the currently mounted vehicle's HP is updated
        if VehicleInfo.entity_id ~= nil and tostring(VehicleInfo.entity_id.hash) == hash_key then
            VehicleInfo.vehicle_hp = destruction
            VehicleDurabilityDisplay:SetHPDisplay()
        end
    end)

    VehicleDurabilityDisplay.is_ready = true

     print("[VehicleDurabilityDisplay][Info] Ready to Display Vehicle Durability.")

end)

function VehicleDurabilityDisplay:CreateHPDisplay()

    if VehicleInfo.hud_car_controller == nil then
        print("[VehicleDurabilityDisplay][Error] HUD Car Controller not found.")
        VehicleDurabilityDisplay.is_active_hp_display = false
        return
    end
    local parent = VehicleInfo.hud_car_controller:GetRootCompoundWidget():GetWidget("maindashcontainer")
    if parent == nil then
        print("[VehicleDurabilityDisplay][Error] Main Dash Container not found.")
        VehicleDurabilityDisplay.is_active_hp_display = false
        return
    elseif parent:GetWidget("ap") ~= nil then
        VehicleDurabilityDisplay.is_active_hp_display = true
        return
    end

    VehicleInfo.ink_horizontal_panel = inkHorizontalPanel.new()
    VehicleInfo.ink_horizontal_panel:SetName(CName.new("ap"))
    VehicleInfo.ink_horizontal_panel:SetAnchor(inkEAnchor.CenterRight)
    VehicleInfo.ink_horizontal_panel:SetFitToContent(false)
    if VehicleDurabilityDisplay.type == Type.Bottom then
        VehicleInfo.ink_horizontal_panel:SetMargin(0, 0, -41, 13)
    elseif VehicleDurabilityDisplay.type == Type.Top then
        VehicleInfo.ink_horizontal_panel:SetMargin(0, 0, -36, 85)
    end
    VehicleInfo.ink_horizontal_panel:Reparent(parent)

    VehicleInfo.ink_hp_title = inkText.new()
    VehicleInfo.ink_hp_title:SetName(CName.new("title"))
    VehicleInfo.ink_hp_title:SetText(GetLocalizedText("LocKey#91867"))
    VehicleInfo.ink_hp_title:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
    VehicleInfo.ink_hp_title:SetFontStyle("Medium")
    VehicleInfo.ink_hp_title:SetFontSize(15)
    VehicleInfo.ink_hp_title:SetOpacity(0.4)
    VehicleInfo.ink_hp_title:SetMargin(0, 13, 0, 0)
    VehicleInfo.ink_hp_title:SetFitToContent(true)
    VehicleInfo.ink_hp_title:SetJustificationType(textJustificationType.Right)
    VehicleInfo.ink_hp_title:SetHorizontalAlignment(textHorizontalAlignment.Right)
    VehicleInfo.ink_hp_title:SetVerticalAlignment(textVerticalAlignment.Center)
    VehicleInfo.ink_hp_title:SetStyle(ResRef.FromName("base\\gameplay\\gui\\common\\main_colors.inkstyle"))
    VehicleInfo.ink_hp_title:BindProperty("tintColor", "MainColors.Red")
    VehicleInfo.ink_hp_title:Reparent(VehicleInfo.ink_horizontal_panel)

    VehicleInfo.ink_hp_text = inkText.new()
    VehicleInfo.ink_hp_text:SetName(CName.new("text"))
    VehicleInfo.ink_hp_text:SetText("100")
    VehicleInfo.ink_hp_text:SetFontFamily("base\\gameplay\\gui\\fonts\\digital_readout\\digitalreadout.inkfontfamily")
    VehicleInfo.ink_hp_text:SetFontStyle("Regular")
    VehicleInfo.ink_hp_text:SetMargin(0, 13, 0, 0)
    VehicleInfo.ink_hp_text:SetFitToContent(true)
    VehicleInfo.ink_hp_text:SetJustificationType(textJustificationType.Left)
    VehicleInfo.ink_hp_text:SetHorizontalAlignment(textHorizontalAlignment.Left)
    VehicleInfo.ink_hp_text:SetVerticalAlignment(textVerticalAlignment.Center)
    VehicleInfo.ink_hp_text:SetStyle(ResRef.FromName("base\\gameplay\\gui\\common\\main_colors.inkstyle"))
    VehicleInfo.ink_hp_text:BindProperty("tintColor", "MainColors.Blue")
    if VehicleDurabilityDisplay.type == Type.Bottom then
        VehicleInfo.ink_hp_text:SetFontSize(20)
    elseif VehicleDurabilityDisplay.type == Type.Top then
        VehicleInfo.ink_hp_text:SetFontSize(25)
    end
    VehicleInfo.ink_hp_text:Reparent(VehicleInfo.ink_horizontal_panel)

    VehicleDurabilityDisplay.is_active_hp_display = true

    VehicleDurabilityDisplay:Fluff(false)

end

function VehicleDurabilityDisplay:SetHPDisplay()

    if not VehicleDurabilityDisplay.is_active_hp_display then
        return
    end

    local hp_value = VehicleInfo.vehicle_hp
    hp_value = math.floor(hp_value)
    local hp_text
    if hp_value < 100 and hp_value >= 10 then
        hp_text = " " .. tostring(hp_value)
    elseif hp_value < 10 then
        hp_text = "  " .. tostring(hp_value)
    else
        hp_text = tostring(hp_value)
    end
    if VehicleInfo.ink_hp_text == nil then
        return
    end
    VehicleInfo.ink_hp_text:SetText(hp_text)

end

function VehicleDurabilityDisplay:Show(on)

    if not VehicleDurabilityDisplay.is_active_hp_display then
        return
    end
    VehicleInfo.ink_horizontal_panel:SetVisible(on)

end

function VehicleDurabilityDisplay:Fluff(on)

    if not VehicleDurabilityDisplay.is_active_hp_display then
        return
    end
    if VehicleDurabilityDisplay.type == Type.Top then
        local fluff_text = VehicleInfo.hud_car_controller:GetRootCompoundWidget():GetWidget("maindashcontainer"):GetWidget("flufftext")
        if fluff_text ~= nil then
            fluff_text:SetVisible(on)
        end
    end

end

function VehicleDurabilityDisplay:CheckDependencies()

    -- Check Cyber Engine Tweaks Version
    local cet_version_str = GetVersion()
    local cet_version_major, cet_version_minor = cet_version_str:match("1.(%d+)%.*(%d*)")
    VehicleDurabilityDisplay.cet_version_num = tonumber(cet_version_major .. "." .. cet_version_minor)

    -- Check CodeWare Version
    local code_version_str = Codeware.Version()
    local code_version_major, code_version_minor = code_version_str:match("1.(%d+)%.*(%d*)")
    VehicleDurabilityDisplay.codeware_version_num = tonumber(code_version_major .. "." .. code_version_minor)

    if VehicleDurabilityDisplay.cet_version_num < VehicleDurabilityDisplay.cet_required_version then
        print("[VehicleDurabilityDisplay][Error] requires Cyber Engine Tweaks version 1." .. VehicleDurabilityDisplay.cet_required_version .. " or higher.")
        return false
    elseif VehicleDurabilityDisplay.codeware_version_num < VehicleDurabilityDisplay.codeware_required_version then
        print("[VehicleDurabilityDisplay][Error] requires CodeWare version 1." .. VehicleDurabilityDisplay.codeware_required_version .. " or higher.")
        return false
    end

    return true

end

function VehicleDurabilityDisplay:Version()
    return VehicleDurabilityDisplay.version
end

return VehicleDurabilityDisplay
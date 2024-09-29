--------------------------------------------------------
-- CopyRight (C) 2024, tidusmd. All rights reserved.
-- This mod is under the MIT License.
-- https://opensource.org/licenses/mit-license.php
--------------------------------------------------------

local Cron = require('External/Cron.lua')
local GameUI = require('External/GameUI.lua')

VehicleDurabilityDisplay = {
	description = "Vehicle Durability Display",
	version = "1.0.1",
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

ExceptionVehicle = {
    "Vehicle.av_rayfield_excalibur_dav",
    "Vehicle.av_militech_manticore_dav",
    "Vehicle.av_zetatech_atlus_dav",
    "Vehicle.av_zetatech_surveyor_dav",
    "Vehicle.q000_nomad_border_patrol_heli_dav",
    "Vehicle.q000_nomad_border_patrol_heli_mayhem_dav",
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
    end)

    Observe("hudCarController", "OnInitialize", function(this)
        VehicleInfo.hud_car_controller = this
        VehicleInfo.vehicle_hp = 100
        VehicleDurabilityDisplay:CreateHPDisplay()
        VehicleDurabilityDisplay.is_hud_initialized = true
    end)

    Observe("hudCarController", "OnMountingEvent", function(this, evt)
        VehicleInfo.hud_car_controller = this
        if VehicleInfo.entity_id ~= nil and VehicleInfo.entity_id.hash ~= evt.request.lowLevelMountingInfo.parentId.hash then
            VehicleInfo.vehicle_hp = 100
        end
        VehicleInfo.entity_id = evt.request.lowLevelMountingInfo.parentId
        for _, vehicle in ipairs(ExceptionVehicle) do
            if Game.FindEntityByID(VehicleInfo.entity_id):GetRecordID() == TweakDBID.new(vehicle) then
                VehicleDurabilityDisplay:Show(false)
                return
            end
        end
        VehicleDurabilityDisplay:SetHPDisplay()
        VehicleDurabilityDisplay:Show(true)
    end)

    Observe("hudCarController", "OnUnmountingEvent", function(this, evt)
        VehicleInfo.hud_car_controller = this
        VehicleDurabilityDisplay:Show(false)
    end)

    Observe("VehicleComponent", "EvaluateDamageLevel", function(this, destruction)
        if VehicleInfo.entity_id == nil then
            return
        end
        if this:GetEntity():GetEntityID().hash == VehicleInfo.entity_id.hash then
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
    VehicleInfo.ink_horizontal_panel:SetMargin(0, 0, -35, 13)
    VehicleInfo.ink_horizontal_panel:SetFitToContent(false)
    VehicleInfo.ink_horizontal_panel:Reparent(parent)

    VehicleInfo.ink_hp_title = inkText.new()
    VehicleInfo.ink_hp_title:SetName(CName.new("title"))
    VehicleInfo.ink_hp_title:SetText(GetLocalizedText("LocKey#91867"))
    VehicleInfo.ink_hp_title:SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily")
    VehicleInfo.ink_hp_title:SetFontStyle("Medium")
    VehicleInfo.ink_hp_title:SetFontSize(15)
    VehicleInfo.ink_hp_title:SetOpacity(0.4)
    VehicleInfo.ink_hp_title:SetMargin(0, 15, 0, 0)
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
    VehicleInfo.ink_hp_text:SetFontSize(25)
    VehicleInfo.ink_hp_text:SetFitToContent(true)
    VehicleInfo.ink_hp_text:SetJustificationType(textJustificationType.Left)
    VehicleInfo.ink_hp_text:SetHorizontalAlignment(textHorizontalAlignment.Left)
    VehicleInfo.ink_hp_text:SetStyle(ResRef.FromName("base\\gameplay\\gui\\common\\main_colors.inkstyle"))
    VehicleInfo.ink_hp_text:BindProperty("tintColor", "MainColors.Blue")
    VehicleInfo.ink_hp_text:Reparent(VehicleInfo.ink_horizontal_panel)

    VehicleDurabilityDisplay.is_active_hp_display = true

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
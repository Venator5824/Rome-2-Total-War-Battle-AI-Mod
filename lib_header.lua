force_require("lua_scripts.battle_logger") -- lib_header.lua . file path:script/lib/
out.ting("***")
out.ting("***")
out.ting("***")
if __game_mode == __lib_type_battle then
    out.ting("Lib_Header.lua :: script libraries reloaded in battle configuration")
elseif __game_mode == __lib_type_campaign then
    out.ting("Lib_Header.lua :: script libraries reloaded in campaign configuration")
elseif __game_mode == __lib_type_frontend then
    out.ting("Lib_Header.lua :: script libraries reloaded in frontend configuration")
end

math.randomseed(os.time() + os.clock() * 1000) -- set up the random seed
math.random()
math.random()
math.random()
math.random()
math.random()
time_increment_ms = 100
TYPE_TIMER_MANAGER = "timer_manager"
TYPE_BATTLE_MANAGER = "battle_manager"
TYPE_CAMPAIGN_MANAGER = "campaign_manager"
TYPE_ITERATOR = "iterator"
TYPE_CUTSCENE_MANAGER = "cutscene_manager"
TYPE_CONVEX_AREA = "convex_area"
TYPE_FIRESTORM_MANAGER = "firestorm_manager"
TYPE_SCRIPT_UNIT = "scripted_unit"
TYPE_HURT_AREA = "hurt_area"
TYPE_ZONE_MANAGER = "zone_manager"
TYPE_ZONE_CONTROLLER = "zone_controller"
TYPE_HIDING_PLACE = "hiding_place"
TYPE_TELEPORT_SQUAD = "teleport_squad"
TYPE_DECISION_POINT = "decision_point"
TYPE_ESCAPE_ROUTE = "escape_route"
TYPE_ESCAPE_MANAGER = "escape_manager"
TYPE_WAYPOINT = "waypoint"
TYPE_EVENT_HANDLER = "event_handler"
TYPE_SCRIPT_AI_PLANNER = "script_ai_planner"
TYPE_FE_HB_SEQUENCE = "fe_hb_sequence"
TYPE_UI_OVERRIDE = "ui_override"
TYPE_BARRICADE_ATTACK_GROUP = "barricade_attack_group"
TYPE_FACTION_START = "faction_start"
TYPE_CAMPAIGN_CUTSCENE = "campaign_cutscene"
TYPE_CAMPAIGN_DEFENSE = "campaign_defense"
TYPE_SCRIPT_MESSAGER = "script_messager"
TYPE_GENERATED_BATTLE = "generated_battle"
TYPE_GENERATED_ARMY = "generated_army"
VOLUME_TYPE_MUSIC = 0
VOLUME_TYPE_SFX = 1
VOLUME_TYPE_ADVISOR = 2
VOLUME_TYPE_VO = 3
VOLUME_TYPE_INTERFACE = 1
VOLUME_TYPE_MOVIE = 5
VOLUME_TYPE_VOICE_CHAT = 6
VOLUME_TYPE_MASTER = 7
force_require("Lib_Common") -- common libs
force_require("Lib_Event_Handler")
force_require("Lib_Script_Messager")

local function secure_require(path)
    local status, err = pcall(require, path)
    if status then
        dev.log("Lade " .. path .. " ... ERFOLG")
    else
        dev.log("Lade " .. path .. " ... FEHLER! Grund: " .. tostring(err))
    end
end

dev.log("SCRIPT LOADED, SUBFILES LOADING ....")

if __game_mode == __lib_type_battle then
  --  force_require("Lib_Campaign_Manager")
  --  cm:add_custom_battlefield()
    force_require("Lib_Misc_Battle") -- battle libs	
    force_require("Lib_Timer_Manager")
    force_require("Lib_Battlemanager")
    force_require("Lib_Script_Unit")
    force_require("Lib_Convex_Area")
    force_require("Lib_Cutscenes")
    force_require("Lib_Objectives")
    force_require("battle_start")
    force_require("Lib_Patrol_Manager")
    force_require("Lib_Script_AI_Planner")
    force_require("Lib_Generated_Battle")
    force_require("Lib_Zone_Manager")
    force_require("Lib_Firestorm_Manager")
    force_require("Lib_Teleport_Manager")
    force_require("Lib_Escape_Manager")
    secure_require("battle_ai_planner_data/ai_strategy_evaluator")
    secure_require("battle_ai_planner_data/ai_tactics_data")
    secure_require("battle_ai_planner_data/ai_unit_intelligence")
    secure_require("battle_ai_planner_data/ai_cultures_battle_data")
    secure_require("battle_ai_planner_data/ai_formations")
    secure_require("battle_ai_planner_data/ai_cavalry_override")
    secure_require("battle_ai_planner_data/ai_update_limiter")
    secure_require("battle_ai_planner_data/battle_ai_data")
end
    
    
    
    
if __game_mode == __lib_type_campaign then
    force_require("Lib_Misc_Campaign")  --force_require("script/lib/siege_equipment_campaign.lua")            --- FIXES CAMPAIGN --force_require("script/lib/siege_equipment_manager.lua")               ---- FIXES CAMPAIGN -- campaign libs
    force_require("Lib_Campaign_Cleanup")
    force_require("Lib_Campaign_Manager")
    force_require("Lib_Campaign_Cutscene")
    force_require("Lib_Campaign_Faction_Start")
    force_require("Lib_Objectives")
    force_require("Lib_Campaign_UI")
    force_require("Lib_Campaign_Defense") --   force_require("Lib_Script_AI_Planner");
    force_require("script/lib/siege_equipment_campaign.lua") --force_require("supply_lines_data/supply_lines_ai");       -- SUPPLY LINE MOD --force_require("supply_lines_data/supply_lines_manager");           -- SUPPLY LINE MOD --force_require("script/lib/cai_campaign_planner_execution.lua")         -- AI CAMPAIGN MOD --force_require("script/lib/cai_campaign_planner_header.lua")        -- AI CAMPAIGN MOD --force_require("script/lib/cai_campaign_planner_strategy_analysis.lua")         -- AI CAMPAIGN MOD --force_require("script/lib/cai_taks_generator.lua")                         -- AI CAMPAIGN MOD -- FIXES CAMPAIGN
    force_require("script/lib/siege_equipment_manager.lua") -- FIXES CAMPAIGN
end 

if __game_mode == __lib_type_frontend then
    force_require("Lib_Timer_Manager") -- frontend libs
    force_require("Lib_FE_Sequence")
end
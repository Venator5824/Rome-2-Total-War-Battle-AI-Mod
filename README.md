# Rome-2-Total-War-Battle-AI-Mod

An LUA open-source mod that aims to overhaul the **Rome II: Total War** AI by using native files and overriding them with new functions, as well as adding new Lua documents.  

**Code:** LUA  
**Tokens:** Around 100,000 so far  
**Newly created files:** 9  

---

### 📚 References

- [Rome II Total War API list](https://bukowa.github.io/twr2docs/lua/api/interface/)  
- [Total War Battle Script Documentation](https://wiki.totalwar.com/w/Battle_Script_Documentation)

---

### ⚙️ Main Info


This mod is required and called by the main file: lib_script_ai_planner.lua

This mod still got logical and other problems.
The log is not printing properly.


### Files included:

packfile/script/lib:
- lib_script_ai_planner.lua
- lib_battlemanager.lua
- lib_header.lua
- lib_patrol_manager.lua
- lib_script_unit.lua
  
##all native files that are edited

packfile/script/lib/battle_ai_planner_data:
- ai_battle_data.lua
- ai_cavalry_override.lua
- ai_cultures_battle_data.lua
- ai_formations.lua
- ai_strategy_evaluator.lua
- ai_tactical_grid.lua
- ai_tactics_data.lua
- ai_unit_intelligence.lua
- ai_update_limiter.lua
  
#all newly created files

@VenatorMods

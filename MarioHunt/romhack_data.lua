ROMHACK = {}
function setup_hack_data()
  local romhack_data = {

  vanilla = {
      default_stars = 70, -- stars in a glitchless run
      max_stars = 120, -- maximum stars collectible
      requirements = {
        [LEVEL_BITDW] = 8,
        [LEVEL_DDD] = 31, -- 1 gets subtracted in code
        [LEVEL_BITFS] = 31,
        [LEVEL_BITS] = 70,
        [LEVEL_BOWSER_3] = 120, -- NOTE: This is overridden by the default star run
      },
      ddd = true, -- pretty much only relevant for vanilla

      special_run = function(m)
        local np = gNetworkPlayers[m.playerIndex]
        if m.playerIndex == 0 and np.currLevelNum == LEVEL_DDD and gGlobalSyncTable.starRun == 0 then
          warp_to_level(LEVEL_BITFS, 1, 0)
        end
      end,

      -- star count for secret courses (only ones with more than 1 star)
      starCount = {
        [LEVEL_PSS] = 2, -- this is the only one lol
      },

      runner_victory = function(m)
        return m.action == ACT_JUMBO_STAR_CUTSCENE
      end,

      start_level = LEVEL_CASTLE_GROUNDS, -- level to start runners and hunters
      start_node = 4, -- node to start runners and hunters
  },

  ["Star Road"] = {
      default_stars = 80,
      max_stars = 130,
      requirements = {
        [LEVEL_BITDW] = 20,
        [LEVEL_BITFS] = 40,
        [LEVEL_BITS] = 80,
        [LEVEL_BOWSER_3] = 119, -- 120th is for bowser
        [LEVEL_WMOTR] = 120, -- hidden palace
      },

      special_run = deleteStarRoadStuff,

      starCount = {
        [LEVEL_PSS] = 2, -- Mushroom Mountain Town
        [LEVEL_SA] = 2, -- Sandy Slide Secret
      },
      replica_start = 121, -- replicas are considered at this star count

      runner_victory = function(m)
        if gGlobalSyncTable.bowserBeaten and m.numStars >= gGlobalSyncTable.starRun then
          return true
        elseif m.playerIndex == 0 then
          local np = gNetworkPlayers[0]
          if np.currLevelNum == LEVEL_ENDING then
            gGlobalSyncTable.bowserBeaten = true
          end
        end
        return false
      end,

      start_level = LEVEL_CASTLE_GROUNDS,
      start_node = 128,
  },

  ["Super Mario 74 (+EE)"] = {
      default_stars = 110,
      max_stars = 157, -- only one version, sorry
      requirements = {
        [LEVEL_BITDW] = 10,
        [LEVEL_BITFS] = 50,
        [LEVEL_BITS] = 110,
        [LEVEL_BOWSER_3] = 157,
      },

      starCount = {
        [LEVEL_COTMC] = 5, -- Toxic-Switch of Danger
        [LEVEL_BITDW] = 4, -- Bowser's Badlands-Battlefield
        [LEVEL_WMOTR] = 0, -- Tower of the East (done so player can always leave)
        [LEVEL_TOTWC] = 3, -- Lava-Switch of Eruption
        [LEVEL_VCUTM] = 6, -- Dust-Switch of Identity
        [LEVEL_PSS] = 4, -- Frozen Slide
        [LEVEL_BITFS] = 5, -- Bowser's Aquatic Castle
        [LEVEL_SA] = 2, -- Champion's Challenge
        [LEVEL_BITS] = 6, -- Bowser's Crystal Palace
      },
      -- EE has some different counts
      starCount_ee = {
        [LEVEL_COTMC] = 6, -- Toxic Terrace
        [LEVEL_SA] = 7, -- Triarc-Bridge
      },

      runner_victory = function(m)
        return m.action == ACT_JUMBO_STAR_CUTSCENE
      end,

      -- prevent swap except by host
      special_run = function(m)
        if m.playerIndex ~= 0 then return end
        local np = gNetworkPlayers[m.playerIndex]
        if (np.currAreaIndex == 1) == gGlobalSyncTable.ee then
          if network_is_server() then
            gGlobalSyncTable.ee = (np.currAreaIndex ~= 1)
            return
          else
            if gGlobalSyncTable.ee then
              djui_chat_message_create(trans("using_ee"))
            else
              djui_chat_message_create(trans("not_using_ee"))
            end
            warp_to_level(np.currLevelNum, np.currAreaIndex ~ 3, np.currActNum)
            return
          end
        end
      end,

      start_level = LEVEL_CASTLE_COURTYARD,
      start_node = 0x40,
      start_area = "special", -- start in right spot for EE
  },

  default = {
      default_stars = -1,
      max_stars = 255,
      requirements = {[LEVEL_BOWSER_3] = 255}, -- block off Bowser 3 until needed stars are collected

      starCount = {}, -- assume every secret stage has 1 star

      runner_victory = function(m)
        return m.action == ACT_JUMBO_STAR_CUTSCENE
      end,

      -- just use the Exit Castle values
      start_level = gLevelValues.exitCastleLevel,
      start_area = gLevelValues.exitCastleArea,
      start_node = gLevelValues.exitCastleWarpNode,
  },

  }

  local romhack_name = "vanilla"
  for i,mod in ipairs(gActiveMods) do
    if mod.incompatible ~= nil and string.find(mod.incompatible,"romhack") then -- is a romhack
      romhack_name = mod.name
    end
  end
  ROMHACK = romhack_data[romhack_name]
  if ROMHACK == nil then
    ROMHACK = romhack_data["default"]
    print("Not compatible!")
    djui_popup_create("WARNING: Hack does not have compatibility!",2)
  elseif romhack_name ~= "vanilla" then
    djui_popup_create("Hack set to "..romhack_name,2)
  end
  if network_is_server() then
    gGlobalSyncTable.starRun = ROMHACK.default_stars
  end
end

function warp_beginning()
  local start_area = ROMHACK.start_area or 1
  if start_area == "special" then
    if gGlobalSyncTable.ee then
      start_area = 2
    else
      start_area = 1
    end
  end
  if ROMHACK.start_node ~= nil then
    warp_to_warpnode(ROMHACK.start_level or LEVEL_CASTLE_GROUNDS, start_area, ROMHACK.start_act or 0, ROMHACK.start_node)
  else
    warp_to_level(ROMHACK.start_level or LEVEL_CASTLE_GROUNDS, start_area, ROMHACK.start_act or 0)
  end
end

-- deletes all surfaces with certain values in hub worlds, to erase star doors and the cannon grate
-- it probably also erases some other stuff but oh well
function deleteStarRoadStuff(m)
    local starsNeeded = gGlobalSyncTable.starRun
    if starsNeeded == nil or starsNeeded == -1 or starsNeeded > m.numStars then return end -- only if have enough for run
    local np = gNetworkPlayers[0]
    if m.playerIndex ~= 0 or (np.currLevelNum ~= LEVEL_CASTLE_COURTYARD and np.currLevelNum ~= LEVEL_CASTLE_GROUNDS and np.currLevelNum ~= LEVEL_CASTLE) then return end

    local obj = obj_get_first(OBJ_LIST_SURFACE)

    while obj ~= nil do
        local objID = get_id_from_behavior(obj.behavior)
        if objID > id_bhv_max_count then
          print("deleted",objID,(obj.oBehParams >> 24))
          obj_mark_for_deletion(obj)
          return
        end
        obj = obj_get_next(obj)
    end
end
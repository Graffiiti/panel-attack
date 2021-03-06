--sets the volume of a single source or table of sources
supported_sound_formats = {".mp3",".ogg", ".it"}
function set_volume(source, new_volume)
  if type(source) == "table" then
    for _,v in pairs(source) do
      set_volume(v, new_volume)
    end
  elseif type(source) ~= "number" then
    source:setVolume(new_volume)
  end
end

-- returns a new sound effect if it can be found, else returns nil
function find_sound(sound_name, dirs_to_check)
  local found_source
  for k,dir in ipairs(dirs_to_check) do
    found_source = check_supported_extensions(dir..sound_name)
    if found_source then
      return found_source
    end
  end
  return nil
end

function find_generic_SFX(SFX_name)
  local dirs_to_check = {"sounds/"..sounds_dir.."/SFX/",
                         "sounds/"..default_sounds_dir.."/SFX/"}
  return find_sound(SFX_name, dirs_to_check)
end

function find_character_SFX(character, SFX_name)
  local dirs_to_check = {"sounds/"..sounds_dir.."/characters/",
                         "sounds/"..default_sounds_dir.."/characters/"}
  local cur_dir_contains_chain
  for k,current_dir in ipairs(dirs_to_check) do
    --Note: if there is a chain or a combo, but not the other, return the same SFX for either inquiry.
    --This way, we can always depend on a character having a combo and a chain SFX.
    --If they are missing others, that's fine.
    --(ie. some characters won't have "match_garbage" or a fancier "chain-x6")
    local cur_dir_chain = check_supported_extensions(current_dir.."/"..character.."/chain")
    if SFX_name == "chain" and cur_dir_chain then 
      if config.debug_mode then print("loaded "..SFX_name.." for "..character) end
      return cur_dir_chain
    end
    local cur_dir_combo = check_supported_extensions(current_dir.."/"..character.."/combo")
    if SFX_name == "combo" and cur_dir_combo then 
      if config.debug_mode then print("loaded "..SFX_name.." for "..character) end
      return cur_dir_combo
    elseif SFX_name == "combo" and cur_dir_chain then
      if config.debug_mode then print("substituted found chain SFX for "..SFX_name.." for "..character) end
      return cur_dir_chain --in place of the combo SFX
    end
    if SFX_name == "chain" and cur_dir_combo then
      if config.debug_mode then print("substituted found combo SFX for "..SFX_name.." for "..character) end
      return cur_dir_combo
    end
    
    local other_requested_SFX = check_supported_extensions(current_dir.."/"..character.."/"..SFX_name)
    if other_requested_SFX then
      if config.debug_mode then print("loaded "..SFX_name.." for "..character) end
      return other_requested_SFX
    else
      if config.debug_mode then print("did not find "..SFX_name.." for "..character.." in current directory: "..current_dir) end
    end
    if cur_dir_chain or cur_dir_combo --[[and we didn't find the requested SFX in this dir]] then
      if config.debug_mode then print("chain or combo was provided, but "..SFX_name.." was not.") end
      return nil --don't continue looking in other fallback directories,
  --else
    --keep looking
    end
  end
  --if not found in above directories:
  return nil
end

--returns audio source based on character and music_type (normal_music, danger_music, normal_music_start, or danger_music_start)
function find_music(character, music_type)
  local found_source
  local character_music_overrides_stage_music = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/normal_music")
  if character_music_overrides_stage_music then
    found_source = check_supported_extensions("sounds/"..sounds_dir.."/characters/"..character.."/"..music_type)
    if found_source then
      if config.debug_mode then print("In selected sound directory, found "..music_type.." for "..character) end
    else
      if config.debug_mode then print("In selected sound directory, did not find "..music_type.." for "..character) end
    end
    return found_source
  else
    if stages[character] then
      sound_set_overrides_default_sound_set = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/normal_music")
      if sound_set_overrides_default_sound_set then
        found_source = check_supported_extensions("sounds/"..sounds_dir.."/music/"..stages[character].."/"..music_type)
        if found_source then
          if config.debug_mode then print("In selected sound directory stages, found "..music_type.." for "..character) end
          
        else
          if config.debug_mode then print("In selected sound directory stages, did not find "..music_type.." for "..character) end
        end
        return found_source
      else
        found_source = check_supported_extensions("sounds/"..default_sounds_dir.."/music/"..stages[character].."/"..music_type)
        if found_source then
          if config.debug_mode then print("In default sound directory stages, found "..music_type.." for "..character) end
        else
          if config.debug_mode then print("In default sound directory stages, did not find "..music_type.." for "..character) end
        end
        return found_source
      end
    end
    return found_source
  end
  return nil
end

--returns a source, or nil if it could not find a file
function check_supported_extensions(path_and_filename)
  for k, extension in ipairs(supported_sound_formats) do
    if love.filesystem.getInfo(path_and_filename..extension) then
      if string.find(path_and_filename, "music") then
        return love.audio.newSource(path_and_filename..extension, "stream")
      else
        return love.audio.newSource(path_and_filename..extension, "static")
      end
    end
  end
  return nil
end

function assert_requirements_met()
  --assert we have all required generic sound effects
  local SFX_requirements =  {"cur_move", "swap", "fanfare1", "fanfare2", "fanfare3", "game_over", "countdown", "go"}
  for k,v in ipairs(SFX_requirements) do
    assert(sounds.SFX[v], "SFX \""..v.."\"was not loaded")
  end
  local NUM_REQUIRED_GARBAGE_THUDS = 3
  for i=1, NUM_REQUIRED_GARBAGE_THUDS do
    assert(sounds.SFX.garbage_thud[i], "SFX garbage_thud "..i.."was not loaded")
  end
  --assert we have the required SFX and music for each character
  for i,name in ipairs(characters) do
    --assert for each required_char_SFX
    assert(sounds.SFX.characters[name].others["chain"], "Character SFX chain for "..name.." was not loaded.")
    assert(sounds.SFX.characters[name].combo_count ~= 0, "Character SFX combo for "..name.." was not loaded.")
    for k, music_type in ipairs(required_char_music) do
      assert(sounds.music.characters[name][music_type], music_type.." for "..name.." was not loaded.")
    end
  end
  --assert pops have been loaded
  for popLevel=1,4 do
      for popIndex=1,10 do
          assert(sounds.SFX.pops[popLevel][popIndex], "SFX pop"..popLevel.."-"..popIndex.." was not loaded")
      end
  end
end

function stop_character_sounds(character)
  music_t = {}

  -- SFX
  for k, sound_table in ipairs(sounds.SFX.characters[character]) do
    if type(sound_table) == "table" then
      for _,sound in pairs(sound_table) do
        sound:stop()
      end
    end
  end

  -- music
  for k, music_type in ipairs(allowed_char_music) do
    if sounds.music.characters[character][music_type] then
      sounds.music.characters[character][music_type]:stop()
    end
  end
end

function init_variations_sfx(character, sfx_table, sfx_name, first_sound)
  local sound = sfx_name..1
  if first_sound then
    -- "combo" in others will be stored in "combo1" in combos
    sfx_table[sound] = first_sound
    first_sound = nil
  else
    sfx_table[sound] = find_character_SFX(character, sound)
  end

  -- search for all variations
  local sfx_count = 0
  while sfx_table[sound] do
    sfx_count = sfx_count+1
    sound = sfx_name..(sfx_count+1)
    sfx_table[sound] = find_character_SFX(character, sound)
  end
  -- print(character.." has "..sfx_count.." variation(s) of "..sfx_name)
  return sfx_count
end

function play_optional_sfx(sfx)
  if not SFX_mute and sfx ~= nil then
    sfx:stop()
    sfx:play()
  end
end

function play_selection_sfx(character)
  if not SFX_mute and sounds.SFX.characters[character].selection_count ~= 0 then
    sounds.SFX.characters[character].selections["selection" .. math.random(sounds.SFX.characters[character].selection_count)]:play()
  end
end

function sound_init()
  sounds_dir = config.sounds_dir or default_sounds_dir
  --sounds: SFX, music
  SFX_Fanfare_Play = 0
  SFX_GameOver_Play = 0
  SFX_GarbageThud_Play = 0
  sounds = {
    SFX = {
      cur_move = find_generic_SFX("move"),
      swap = find_generic_SFX("swap"),
      land = find_generic_SFX("land"),
      fanfare1 = find_generic_SFX("fanfare1"),
      fanfare2 = find_generic_SFX("fanfare2"),
      fanfare3 = find_generic_SFX("fanfare3"),
      game_over = find_generic_SFX("gameover"),
      countdown = find_generic_SFX("countdown"),
      go = find_generic_SFX("go"),
      menu_move = find_generic_SFX("menu_move"),
      menu_validate = find_generic_SFX("menu_validate"),
      menu_cancel = find_generic_SFX("menu_cancel"),
      garbage_thud = {
        find_generic_SFX("thud_1"),
        find_generic_SFX("thud_2"),
        find_generic_SFX("thud_3")
      },
      characters = {},
      pops = {}
    },
    music = {
      characters = {},
    }
  }
  zero_sound = check_supported_extensions("zero_music")
  required_char_SFX = {"chain", "combo"}
  -- @CardsOfTheHeart says there are 4 chain sfx: --x2/x3, --x4, --x5 is x2/x3 with an echo effect, --x6+ is x4 with an echo effect
  -- combo sounds, on the other hand, can have multiple variations, hence combo, combo2, combo3 (...) and combo_echo, combo_echo2...
  allowed_char_SFX = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match", "selection", "win"}
  required_char_music = {"normal_music", "danger_music"}
  allowed_char_music = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
  for i,name in ipairs(characters) do

    -- SFX
    sounds.SFX.characters[name] = { combos = {}, combo_count = 0, combo_echos = {}, combo_echo_count = 0, selections = {}, selection_count = 0, wins = {}, win_count = 0, others = {} }
    for k, sound in ipairs(allowed_char_SFX) do
      sounds.SFX.characters[name].others[sound] = find_character_SFX(name, sound)
      if not sounds.SFX.characters[name].others[sound] then
        if string.find(sound, "chain") then
          sounds.SFX.characters[name].others[sound] = find_character_SFX(name, "chain")
        elseif string.find(sound, "combo") then 
          sounds.SFX.characters[name].others[sound] = find_character_SFX(name, "combo")
        end
      end
    end
    sounds.SFX.characters[name].combo_count = init_variations_sfx(name, sounds.SFX.characters[name].combos, "combo", sounds.SFX.characters[name].others["combo"])
    sounds.SFX.characters[name].combo_echo_count = init_variations_sfx(name, sounds.SFX.characters[name].combo_echos, "combo_echo", sounds.SFX.characters[name].others["combo_echo"])
    sounds.SFX.characters[name].selection_count = init_variations_sfx(name, sounds.SFX.characters[name].selections, "selection", sounds.SFX.characters[name].others["selection"])
    sounds.SFX.characters[name].win_count = init_variations_sfx(name, sounds.SFX.characters[name].wins, "win", sounds.SFX.characters[name].others["win"])
    
    -- music
    sounds.music.characters[name] = {}
    for k, music_type in ipairs(allowed_char_music) do
      sounds.music.characters[name][music_type] = find_music(name, music_type)
      -- Set looping status for music.
      -- Intros won't loop, but other parts should.
      if sounds.music.characters[name][music_type] then
        if not string.find(music_type, "start") then
          sounds.music.characters[name][music_type]:setLooping(true)
        else
          sounds.music.characters[name][music_type]:setLooping(false)
        end
      end
    end
  end
  for popLevel=1,4 do
    sounds.SFX.pops[popLevel] = {}
    for popIndex=1,10 do
      sounds.SFX.pops[popLevel][popIndex] = find_generic_SFX("pop"..popLevel.."-"..popIndex)
    end
  end
  assert_requirements_met()
  
  love.audio.setVolume(config.master_volume/100)
  set_volume(sounds.SFX, config.SFX_volume/100)
  set_volume(sounds.music, config.music_volume/100) 
end


-- New music engine stuff here

music_t = {}
currently_playing_tracks = {} -- needed because we clone the tracks below
function stop_the_music()
  for k, v in pairs(currently_playing_tracks) do
    v:stop()
    currently_playing_tracks[k] = nil
  end
  music_t = {}
end

function find_and_add_music(character, musicType)
  local start_music = sounds.music.characters[character][musicType .. "_start"] or zero_sound
  local loop_music = sounds.music.characters[character][musicType]
  music_t[love.timer.getTime()] = make_music_t(
          start_music
  )
  music_t[love.timer.getTime() + start_music:getDuration()] = make_music_t(
          loop_music, true
  )
end

function make_music_t(source, loop)
    return {t = source, l = loop or false}
end

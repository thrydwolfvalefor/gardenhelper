_addon.name = 'GardenHelper'
_addon.author = 'Shadowhammer'
_addon.version = '2.32.0'
_addon.language = 'english'
_addon.commands = {'gardenhelper', 'gh'}

-- v2.27.0: targeting by entity id is built in (state.set_target, the same
-- 0x058 packet the SetTarget addon injects) - SetTarget is no longer needed.
require('logger')
require('coroutine')
local res = require('resources')
-- Aliased to winconfig because this addon's own table is called config.
-- data/settings.xml has a <global> section plus one section per
-- character, so saved_status is per character.
local winconfig = require('config')
-- 'pack' (string:pack) builds the NPC trade packet for crystal trading.
require('pack')

-- Loads a Lua file next to this one and returns what it returns if that
-- is of want_type ('table' for entities.lua / characters.lua, 'function'
-- for the modules), else nil + a chat error.
local function load_sibling(filename, want_type)
    local chunk, load_err = loadfile(windower.addon_path .. filename)
    local ok, result = false, load_err
    if chunk then
        ok, result = pcall(chunk)
    end
    if not ok or type(result) ~= (want_type or 'table') then
        windower.add_to_chat(167, 'GardenHelper: [ERROR] Could not load ' .. filename .. ' (' .. tostring(result) .. ').')
        return nil
    end
    return result
end

-- characters.lua is re-read whenever it changes (refresh_character_file,
-- start of every //gh command and on login), so edits apply without
-- //lua r. The table keeps its identity (modules hold a reference to it).
local CHARACTER_FILE_LOADED = load_sibling('characters.lua')
local CHARACTER_FILE = CHARACTER_FILE_LOADED or {}
local ENTITY_LIST = load_sibling('entities.lua') or {}

-- Configuration
local config = {
    default_seed = "Revival Root",
    use_fertilizer = false,	
    default_fertilizer = "Miracle Mulch",
    harvest_time = 3600, -- 1 hour in seconds
    fertilize_wait_time = 1800, -- 30 minutes in seconds
    reminder_intervals = {3000, 2400, 1800, 1200, 600}, -- 50, 40, 30, 20, 10 minutes
    fertilize_reminder_intervals = {1200, 600, 300}, -- 20, 10, 5 minutes
    debug_mode = false,
    -- Seconds reconcile_furrow_data() reuses its last existence probe when
    -- called with skip_status_probe (loop/full/duecheck).
    existence_cache_seconds = 90,
    -- Seconds after the latest login/zone-in before any command touches a
    -- garden entity; then wait_for_entities_settled() polls for the Green
    -- Thumb Moogle (arrival_* below). //gh furrowconfig arrivalwait changes it.
    min_seconds_since_arrival = 45,
    -- Lock-On walking (fallback when an entity has no X/Y): tap the Lock On
    -- key (approach_lock_on_key - set it to YOUR Lock On key; with nothing
    -- targeted that key must do nothing harmful) and hold Forward
    -- until within approach_target_distance. Windower key-map names.
    approach_target_distance = 2.0,
    -- Interact distance for vein/pond/grove/ephemeral moogle/flotsam/net.
    node_approach_distance = 5.0,
    approach_lock_on_key = 'numpad*',
    approach_forward_key = 'w',
    approach_timeout_seconds = 25,
    approach_poll_interval = 0.25,
    -- Distance not closed by approach_stuck_epsilon_yalms after
    -- approach_stuck_check_seconds = Lock On didn't engage: retarget, retry once.
    approach_stuck_check_seconds = 2.0,
    approach_stuck_epsilon_yalms = 0.3,
    -- Max wait per Enter for new text in harvest_furrow's key sequence.
    harvest_max_wait_per_press = 3,
    -- Same for plant_seed's confirm sequence.
    plant_max_wait_per_press = 3,
    -- Extra pause before harvest_furrow's final confirm Enter (the Yes/No
    -- prompt can lag after several harvests in a row).
    harvest_confirm_extra_wait = 1.5,
    -- Fertilized furrow with no seed ("...as fertilizer, but is devoid of
    -- seeds."): pause after picking "Absolutely nothing" before planting.
    fertilized_empty_settle_seconds = 1.5,
    -- Multi-harvest seeds (e.g. arborfruit): after "...should sprout about
    -- N more times." one more Enter opens "What will you do?"; wait this
    -- long for it before pressing Right to "Absolutely nothing".
    sprout_menu_settle_seconds = 1.0,
    -- Multi-harvest seed still growing (a "should sprout about N more
    -- times." line was seen): false = don't try to fertilize it (the
    -- game may refuse); set true if fertilizing it works.
    multi_harvest_fertilize = true,
    -- After an Enter's first new line, keep listening until text has been
    -- quiet this long (a reply can arrive in more than one chunk).
    text_settle_seconds = 0.5,
    -- Furrow inspect (Enter, Enter): a planted furrow answers in two
    -- messages - the rank line, then "has matured!" or "...harvest ... in
    -- about N minutes". Rank line only = listen this much longer for the
    -- second one, then press Enter once more (on a laggy connection the
    -- first press can be eaten while the rank line is still printing).
    furrow_detect_second_line_wait = 2.5,
    -- No text at all from a furrow's inspect (still busy with the last
    -- furrow's planting, or just logged in): wait furrow_detect_retry_wait
    -- seconds, target it again and retry this many times.
    furrow_detect_no_text_retries = 1,
    furrow_detect_retry_wait = 2.0,
    -- End of a furrow pass: a furrow left ready / unknown (or empty with
    -- seeds in inventory) gets one more try right away, instead of being
    -- pushed to a later login and off the other furrows' timing.
    furrow_retry_missed = true,
    -- true = in a normal pass a ready furrow waits while another unlocked
    -- furrow is still growing (less than harvest_time away), so all of
    -- them are harvested and replanted together on one login. force and
    -- single-furrow commands (//gh furrow inspect 2 ...) ignore it.
    furrow_sync_hold = true,

    -- Sell to the Green Thumb Moogle (sell_junk_to_moogle): what is sold
    -- comes from ItemTable.lua (action "sell", and "save" above min_save) -
    -- inv.lua sells it itself (no other sell addon is needed).
    -- //gh furrowconfig selljunk toggles it for the session.
    sell_junk_enabled = true,
    -- Ephemeral Moogle crystal trading (harvest_crystals).
    process_crystals = true,

    -- After the final sell of //gh full/force, send //findall (FindAll's
    -- "update" command) so its offline inventory database is current.
    refresh_findall_after_pass = false,
    -- Pause after //findall before the pass reports complete.
    findall_wait_seconds = 3,

    -- How often //gh full/force sells mid-pass. Every level also sells at
    -- the end, after Net: through inv's sell step when inventory_after_full
    -- is on (no separate sell), otherwise a plain sell:
    --   1 - only at the end
    --   2 - after Pond and at the end (default)
    --   3 - after Furrow, Pond, Grove and at the end
    --   4 - after every module
    -- A checkpoint only sells if something was harvested since the last one.
    sell_level = 2,
    sell_checkpoints_by_level = {
        [1] = {},
        [2] = {pond = true},
        [3] = {furrow = true, pond = true, grove = true},
        [4] = {furrow = true, vein = true, pond = true, grove = true, crystals = true, flotsam = true},
    },
    -- Safety net: sell at any checkpoint (even ones the level skips, even on
    -- furrow-only passes) once main inventory is this full (0-1).
    sell_inventory_full_threshold = 0.75,
    -- Entity id of the Green Thumb Moogle (junk shop).
    sell_junk_moogle_id = 17924125,
    -- Waypoint NPC (Mandragora Assistant) used as a one-time detour when the
    -- direct walk to the Green Thumb Moogle gets stuck
    -- (walk_to_moogle_with_waypoint_fallback).
    moogle_waypoint_id = 17924240,
    moogle_waypoint_approach_distance = 2.5,
    -- Walking from the Coastal Fishing Net to the moogle cuts through the
    -- tables: when a moogle walk starts within
    -- net_to_moogle_strafe_trigger_yalms of the Net, side-step first
    -- (net_to_moogle_strafe_side relative to the moogle's direction).
    net_to_moogle_strafe_enabled = true,
    net_to_moogle_strafe_yalms = 10,
    net_to_moogle_strafe_side = 'left',
    net_to_moogle_strafe_trigger_yalms = 8,
    net_to_moogle_strafe_timeout_seconds = 5,

    -- ---- Inventory: //gh inv / sell / drop / pop / send / rec / org (inv.lua) ----
    -- Items (action per item) and the dry-run switches are in ItemTable.lua;
    -- mail tracking in Mail.lua (both in this folder).
    inventory_after_full = true,           -- run inv (sell, drop, pop, send, rec, org) after Net in //gh full - it is also the end-of-pass sell
    -- Memory check at the end of //gh full: NOT set here. It lives in data/memory_check.lua
    -- (return {enabled = true/false}), changed with //gh memory on|off (default off).
    -- memory_check_in_full = false,
    gc_at_end_of_full = true,              -- full Lua garbage collection (GardenHelper's own memory) at the end of every //gh full and before //gh memory; noted as a GC: line in memory_report.lua
    gc_step_kb = 1024,                     -- v2.21.0: GC is done in small steps; KB of work per step (smaller = smoother, takes longer)
    gc_step_wait_seconds = 0.05,           -- pause between GC steps (lets the game draw frames in between)
    gc_min_garbage_kb = 8192,              -- skip the end-of-full GC if less than this has built up since the last one
    gc_max_seconds = 15,                   -- stop stepping after this long; Lua's normal background GC finishes the rest
    memory_check_game_total = true,        -- also read pol.exe's own memory (whole game incl. plugins) via Windows; false = addons only
    memory_check_game_wait_seconds = 10,   -- max wait for Windows' answer
    mail_debug = false,                    -- print every Delivery Box packet (v4.9.1: raw server replies + GH/GAME outgoing packets too)
    mail_response_timeout_seconds = 5,     -- max wait for the server's reply to each Delivery Box step
    mail_open_timeout_seconds = 10,        -- max wait for the Delivery Box to open (a failed open is closed anyway, in case it opens late)
    mail_step_delay_seconds = 1,           -- pause between Delivery Box steps (raise on slow PCs/connections)
    mail_after_send_wait_seconds = 3,      -- after each Send, let the stack clear before the next one
    mail_after_confirm_wait_seconds = 3,   -- after clearing received stacks from the outbox, before reading free slots
    mail_before_close_wait_seconds = 5,    -- before closing a box that sent something (and before a logout after it)
    mail_outbox_clear_timeout_seconds = 60, -- max wait for received stacks to really leave the outbox before filling it
    mail_outbox_clear_poll_seconds = 1,    -- how often the outbox is re-read while they leave
    mail_outbox_stable_seconds = 5,        -- slots still in use that haven't changed for this long = sent mail not picked up yet (stop waiting)
    mail_set_retries = 3,                  -- a stack the outbox refuses (slot still clearing) is retried this many times...
    mail_set_retry_wait_seconds = 3,       -- ...after this wait + another outbox clear
    mail_send_retries = 3,                 -- a Send the server refuses (EF "Communications seem to be congested") is retried this many times (same wait)
    mail_open_retries = 2,                 -- a Delivery Box that won't open ("Please try again in a little while") is tried again this many times...
    mail_open_retry_wait_seconds = 5,      -- ...after this wait
    mail_open_settle_seconds = 3,          -- after the box opens, let the game's own window finish its reads (max wait)
    mail_open_quiet_seconds = 1,           -- ...but move on once no box packet has come in for this long (raise on slow connections)
    mail_receive_after_send_wait_seconds = 10, -- the game needs 5-10s after sending before you can receive
    mail_receive_round_wait_seconds = 5,   -- pause between 8-slot receive rounds
    mail_receive_max_rounds = 12,          -- safety limit: rec checks again while the box is full, up to 12 x 8 = 96 stacks
    mail_stale_misses = 2,                 -- a tracked stack missing from a fully emptied box this many receives = a mistake, removed from tracking
    mail_stale_min_age_minutes = 10,       -- only stacks sent at least this long ago count a miss
    inventory_sort_wait_seconds = 2,       -- after sorting main inventory (merges split stacks) before planning mail
    inventory_step_gap_seconds = 2,        -- pause between the inv steps
    org_move_delay_seconds = 0.8,          -- pause between item moves
    org_move_verify_seconds = 4,           -- wait for a move to show up before calling that bag unusable here
    sell_shop_open_timeout_seconds = 8,    -- after the menu keys, max wait for the moogle's shop to open
    sell_item_delay_seconds = 1,           -- pause between sold stacks (raise on slow PCs/connections)
    drop_item_delay_seconds = 0.5,         -- pause between dropped stacks (//gh drop)
    auto_drop_refresh_seconds = 30,        -- auto_drop re-reads ItemTable.lua's drop list at most this often
    -- Max wait for text after interacting with the moogle.
    sell_junk_max_wait_per_press = 3,
    -- Part of the moogle's shop greeting; anything else = quest reminder or
    -- cutscene, cleared before retrying.
    sell_junk_standard_greeting = 'Whatever would you want',
    -- Retarget/re-interact attempts before giving up on selling this pass.
    sell_junk_max_attempts = 5,
    -- If Escape x3 doesn't clear a stuck moogle cutscene, alternate
    -- Enter/Escape until the target releases, up to this long; still stuck =
    -- stop all GardenHelper operations.
    sell_junk_cutscene_timeout_seconds = 300,
    -- Keys from the moogle's greeting to the Buy/Sell menu (inv.lua sells from there).
    sell_junk_menu_sequence = {'enter', 'down', 'enter', 'enter'},
    -- The game refuses an /item on a furrow/node with this (e.g. "There is
    -- no need to fertilize ... ready to harvest!").
    item_use_reject_phrase = 'There is no need to',

    -- ---- Vein / Pond / Grove / Flotsam / Net ----

    -- The daily reset is Japanese midnight, computed from UTC (see
    -- get_garden_day_string) - no DST setting needed.

    -- Seconds to wait after each Enter, in order (press_enter_cycle). Vein
    -- confirmed live: 5, 3, 8 (several excavations print late).
    vein_press_waits = {5, 3, 8},
    grove_press_waits = {5, 3, 8},
    pond_press_waits = {5, 3, 3},
    flotsam_press_waits = {5, 3, 3},
    net_press_waits = {5, 3, 3},
    -- Double check while walking to a garden object: it must be loaded
    -- and targetable before the walk starts, is re-checked every
    -- double_check_seconds on the way (gone = stop, pick the next one
    -- from where you are) and once more on arrival, at least
    -- double_check_seconds after it was first targeted. Catches objects
    -- that flicker into the entity list (e.g. Vein #4 seen, then only #2
    -- there). false for a module = old behavior.
    double_check_before_walk = {vein = true, grove = true, pond = true, net = true, flotsam = true, crystals = true, furrow = true},
    double_check_seconds = 1,
    -- Safety cap on vein/grove repeat-until-stop loops.
    node_max_attempts = 20,

    -- Vein/Grove success line; press_enter_cycle stops waiting once it shows.
    harvest_success_phrase = 'You have successfully performed that action',

    -- Vein has nothing left today.
    vein_stop_phrase = 'It would probably be best to stop for now.',
    -- Pond / Net already harvested today.
    pond_already_done_phrase = 'It seems too light to have anything caught in it.',
    net_already_done_phrase = 'It seems too light to have anything caught in it.',
    -- Extra wait for the Net's cutscene after its last press.
    net_cutscene_extra_wait_seconds = 5,
    -- Grove fully done for the day (prune + weeds).
    grove_done_phrase = 'There seems to be no reason to work on this grove',

    -- Flotsam refused because a Rare/Ex copy is already held: the press
    -- cycle stops, the duplicate is discarded with Up, Enter.
    flotsam_cant_receive_phrases = {'cannot obtain', "can't obtain"},
    flotsam_disposed_phrase = 'You dispose of the',
    -- Pause before Up; max wait for "You dispose of"; pause after it; wait
    -- for a possible inventory-full line after "cannot obtain".
    flotsam_dispose_prompt_wait_seconds = 1.0,
    flotsam_dispose_confirm_seconds = 5,
    flotsam_dispose_settle_seconds = 2.0,
    flotsam_cant_receive_settle_seconds = 1.5,
    -- Flotsam is harvested again after each item/discard (campaigns can give
    -- double items) until it stops answering - at most this many rounds.
    flotsam_max_rounds = 4,

    -- A fertilized node prints one extra line before its confirm prompt
    -- (pond: "A super baitball is being used as bait.", vein: "...poured
    -- on it.", grove: "...is fertilized with grove worm."), so the press
    -- cycle needs one more Enter. press_enter_cycle presses an extra Enter
    -- whenever a press's new text matches one of these.
    fertilizer_extra_press_phrases = {
        'is being used as bait',
        'poured on it',
        'is fertilized with',
    },
    fertilizer_extra_press_wait_seconds = 3,

    -- Vein/Pond/Grove/Net fertilizer, used only AFTER that node's harvest
    -- for the current garden day, once per day. '' = off. Fallbacks only -
    -- set them in characters.lua (defaults, or overrides per character).
    vein_fertilizer = '',
    pond_fertilizer = '',
    grove_fertilizer = '',
    net_fertilizer = '',
    -- Enters pressed one at a time after '/item "<fertilizer>" <t>' until
    -- the item count drops or a done phrase shows up, then Escape.
    node_fertilize_max_enters = 3,
    node_fertilize_daily_attempts = 3,     -- failed tries per garden day before giving up (so automation can't loop on it)
    node_fertilize_enter_wait_seconds = 3,
    -- The game's "You baited the net with ..." / "...poured on it." line
    -- waits for Enter to close. Enters pressed after a use (more could
    -- re-open the node's own menu; the Escapes after it close anything left).
    node_fertilize_close_enters = 1,
    node_fertilize_close_wait_seconds = 2,
    node_fertilize_done_phrases = {
        'You baited',
        'is being used as bait',
        'poured on it',
        'You pour',
        'is fertilized with',
        'You fertilize',
    },

    -- ---- Arrival, navigation, alerts ----

    -- Arrival (v2.18.0, Mark): after min_seconds_since_arrival, poll for
    -- the Green Thumb Moogle: settarget him, the target must hold for
    -- arrival_target_hold_seconds (1); Escape drops the cursor, settarget
    -- again RIGHT away and it must hold another arrival_target_hold_seconds
    -- -> garden is loaded. Then poll for the first node.
    arrival_poll_interval = 1,
    arrival_poll_max_seconds = 60,
    -- Keep polling for the moogle until this long after login/zone-in
    -- (misses are debug-only until then). arrival_poll_max_seconds is used
    -- only when the arrival time is unknown.
    -- v2.22.0: 180 (was 60) - slower PCs / connections can take longer.
    arrival_give_up_seconds = 180,
    -- v2.22.0: arrival_skip_check_after_seconds is gone - the check is
    -- never skipped; every arrival must pass it once before any garden
    -- work (it is remembered for that arrival after it passes).
    -- Green Thumb Moogle loaded but over 50 yalms away (targeting can't
    -- reach him): walk to within this many yalms of him, then check.
    arrival_walk_to_moogle_yalms = 30,
    -- A check started late (or //gh loaded long after arriving) still
    -- polls at least this long before giving up.
    arrival_min_poll_seconds = 20,
    -- The target won't release this many times in a row = cutscene: Enter,
    -- Escape, check, repeat until it releases (max arrival_cutscene_max_seconds).
    arrival_release_fail_limit = 3,
    arrival_cutscene_max_seconds = 300,
    arrival_cutscene_key_wait_seconds = 1.0,   -- wait after each Enter / Escape
    arrival_release_check_seconds = 1.0,       -- how long to watch for the target to drop
    arrival_target_hold_seconds = 1,
    -- v2.27.0: targeting is built in (state.set_target). true = go back to
    -- 'settarget <id>' through the SetTarget addon (must be loaded).
    use_settarget_addon = false,
    arrival_node_poll_max_seconds = 15,

    -- 'xy' walks to entities.lua X/Y with windower.ffxi.run(); 'lockon' is
    -- the Lock-On + W fallback (also used for entities with no X/Y).
    navigation_mode = 'xy',
    xy_arrive_tolerance = 1.0,     -- yalms from the X/Y spot that counts as "arrived"
    xy_poll_interval = 0.1,
    xy_stuck_check_seconds = 1.5,  -- how often to check we're actually making progress
    xy_stuck_epsilon_yalms = 0.3,  -- less progress than this in one check = stuck
    xy_max_stuck_checks = 3,       -- give up after this many stuck checks in a row
    -- Inside xy_near_zone_yalms the walk ends once the distance stops
    -- dropping for xy_plateau_seconds (bumped into the node). Stalls farther
    -- out get the sidestep/stuck handling.
    xy_near_zone_yalms = 6.0,
    xy_plateau_seconds = 0.6,       -- no closer than this long = done (inside the near zone)
    xy_plateau_epsilon_yalms = 0.1, -- must get at least this much closer to count as progress
    -- The game allows interaction under 6 yalms; 5.5 leaves margin.
    interact_distance = 5.5,

    -- "Target out of range." on an interaction's first press (or an /item)
    -- = walk closer (next distance in out_of_range_walk_distances, then
    -- straight at it) and start the interaction over, up to
    -- out_of_range_max_retries times.
    out_of_range_phrases = {'Target out of range'},
    out_of_range_max_retries = 2,
    out_of_range_walk_distances = {3.0, 1.5},
    out_of_range_retry_settle_seconds = 0.5,

    -- //gh furrow inspect / full inspect also harvest/plant/fertilize what
    -- the live check finds. An explicit key list is always look-only.
    inspect_takes_action = true,

    -- Alert when a vein/grove variant appears out of reach after harvesting
    -- started (and the //gh emp extend prompt): alert_chat_command + message +
    -- alert_call_tag ('/p': call sounds do not play in /echo). alert_sound_file = a .wav to play too ('' = none).
    alert_chat_command = '/p',            -- <call> sounds only play in party chat, not /echo (Mark 2026-09-27)
    alert_call_tag = '<call0>',
    alert_sound_file = '',

    -- After the first "Obtained" line, keep listening until none for
    -- obtained_settle_seconds (max obtained_max_wait_seconds).
    obtained_phrase = 'Obtained:',
    obtained_settle_seconds = 2,
    obtained_max_wait_seconds = 30,
    -- Pond/Flotsam/Net keep listening this long after their last press for
    -- a late "Obtained"/already-done line (Net's cutscene wait is folded in).
    obtained_late_wait_seconds = 10,
    -- Flotsam already taken today answers nothing; seconds to watch for that.
    flotsam_no_response_seconds = 4,

    -- "Come back after sorting your inventory." = inventory full.
    inventory_full_phrases = {'after sorting your inventory'},
    inventory_full_max_restarts = 2,   -- sell + restart this many times per node before giving up

    -- //gh full trades crystals when holding AT LEAST this many of any
    -- crystal/cluster (1 = trade whenever any are held, Mark 2026-10-14);
    -- //gh crystals always trades. 8 stacks per trade.
    crystals_full_threshold = 1,
    crystal_trade_max_rounds = 10,
    crystal_trade_confirm_phrase = 'hold onto these',
    crystal_trade_done_phrase = "That's all there is to it",
    crystal_trade_stored_phrase = 'You have stored',
    crystal_trade_wait_seconds = 8,

    -- Books from the Skipper Moogle: //gh full checks once per garden day as
    -- its FIRST step (before any harvesting); //gh duecheck reports them as due. books = false in
    -- characters.lua skips a character.
    books_in_full = true,
    -- Failed book trips allowed per garden day before giving up until reset.
    books_daily_attempts = 2,
    -- Wait for a menu (no chat line) to open before the next key.
    menu_open_wait_seconds = 3,
    books_reply_wait_seconds = 8,       -- max wait for each Skipper Moogle chat reply
    -- The Skipper's greeting can lag 10s+ after zone-in; menu keys only after
    -- "Heigh-ho". No answer -> Escape, retarget, ask again.
    books_greeting_wait_seconds = 20,
    books_ask_attempts = 2,
    books_max_purchases = 10,            -- safety cap on the buy loop
    skipper_greeting_phrase = 'Heigh-ho',
    books_available_phrase = 'tantalizing tomes',
    books_none_phrase = "can't sell them",
    books_price_phrase = 'is it, kupo',
    books_obtained_phrase = 'Obtained key item',
    books_no_gil_phrase = 'You do not have enough gil',
    -- Port zones: poll for the Skipper Moogle (no fixed wait), confirm the
    -- target holds port_confirm_rounds times, then check books.
    port_poll_interval = 0.5,
    port_arrival_max_seconds = 60,
    port_target_hold_seconds = 1,
    port_confirm_rounds = 2,
    -- Starting in a Port zone with books due: do the books there first.
    books_first_from_port = true,

    -- Entering the garden from a Port zone (Mog Dinghy within
    -- port_dinghy_max_distance) or the Mog House.
    zone_change_wait_seconds = 60,
    port_dinghy_max_distance = 30,
    -- Mog House -> Mog Garden needs a one-time key mapping (the exit menu
    -- depends on quests): mog_house_exit_keys = e.g. {'down','down','enter'},
    -- mog_house_exit_door_xy = {[zone] = {x = , y = }}. Empty = not set up.
    mog_house_exit_keys = {},
    mog_house_exit_door_xy = {},

    -- Garden assistants (assistants.lua; settings per character in
    -- characters.lua assistants = {...}). Seconds.
    assistant_text_wait_seconds = 8,      -- wait for each line of theirs after Enter
    assistant_line_settle_seconds = 1.5,  -- after a line of theirs shows up, before the next Enter (a line still being written eats Enter)
    assistant_menu_settle_seconds = 1.5,  -- after the Enter that opens the node menu
    assistant_submenu_settle_seconds = 2.0, -- after choosing the node, before moving in the task menu
    assistant_down_settle_seconds = 0.7,  -- after each Down in their menus
    assistant_move_wait_seconds = 12,     -- black screen + reappearing at the new node
    assistant_after_move_seconds = 1.0,   -- extra pause once they are back

    -- Assistant contracts (employment.lua - //gh emp, and the start of
    -- every full run). Weeks per hire/extension: rehire_weeks in
    -- characters.lua (per assistant, per character); off for a character:
    -- modules = {<name> = {employment = false}} in characters.lua.
    employment_enabled = true,
    employment_extend_below_days = 30,    -- under this many contract days = "extension needed" (//gh status, MuleLogger A x) and the //gh emp extend default
    employment_trade_spare_items = true,  -- unlock item for an assistant you already have -> trade it (+7 days, free)
    employment_notify_retry_days = 7,     -- no daily contract line: set "Always notify me" again at most this often
    employment_notify_nav = 'bottom',     -- to reach "Set contract expiration notification.": 'count' = Down x recruited assistants, 'bottom' = Right Right Up
    employment_notify_always_keys = {'left', 'left', 'left'},  -- in the "how many days in advance" box: to "Always notify me."
    employment_text_wait_seconds = 8,     -- wait for each moogle line after a key
    employment_line_settle_seconds = 1.5, -- after a line shows up, before the next key
    employment_menu_settle_seconds = 1.5, -- after the Enter that opens a menu / the number box
    employment_key_settle_seconds = 0.7,  -- after each Down / digit / Left
    employment_menu_id = 1016,            -- the Green Thumb Moogle's event (Menu ID) - its data carries every contract's time
    employment_manual_wait_seconds = 300, -- //gh emp extend / //ml extend: how long to wait for you to type the weeks + Enter
    employment_alert_lead_seconds = 0.4,  -- v2.21.1: //gh emp extend / //ml extend: sound -> weeks box opens after this long (was 1s)
    employment_max_weeks_per_hire = 9,    -- v2.23.0: most weeks the box takes at once (//gh emp extend target: more = another round)
    employment_event_idle_enter_seconds = 5, -- scenes: Enter after this long with no new line (menu top option / silent part)
    employment_event_end_seconds = 3,     -- scenes: over once no event for this long
    employment_event_max_seconds = 420,   -- scenes: give up after this (Monster Rearing is ~5 min)
    employment_retry_wait_seconds = 5,    -- after a scene, before talking to the moogle again
}

-- Seed/fertilizer defaults come from characters.lua (defaults = {...});
-- the values above are only fallbacks (kept in CONFIG_FALLBACKS so a
-- field removed from characters.lua goes back to them on a re-read).
local CHARACTER_DEFAULT_FIELDS = {seed = 'default_seed', fertilizer = 'default_fertilizer', harvest_time = 'harvest_time',
    use_fertilizer = 'use_fertilizer', fertilize_wait_time = 'fertilize_wait_time',
    vein_fertilizer = 'vein_fertilizer', pond_fertilizer = 'pond_fertilizer',
    grove_fertilizer = 'grove_fertilizer', net_fertilizer = 'net_fertilizer'}
local CONFIG_FALLBACKS = {}
for _, cfg in pairs(CHARACTER_DEFAULT_FIELDS) do CONFIG_FALLBACKS[cfg] = config[cfg] end
local function apply_character_defaults()
    local d = type(CHARACTER_FILE.defaults) == 'table' and CHARACTER_FILE.defaults or {}
    for key, cfg in pairs(CHARACTER_DEFAULT_FIELDS) do
        if d[key] ~= nil then config[cfg] = d[key] else config[cfg] = CONFIG_FALLBACKS[cfg] end
    end
end
apply_character_defaults()

-- config fields //gh furrowconfig can change at runtime. config is shared
-- by every character you log in as this session, so the 'login' event
-- restores these defaults.
local config_defaults = {
    sell_junk_enabled = config.sell_junk_enabled,
    default_seed = config.default_seed,
    default_fertilizer = config.default_fertilizer,
    use_fertilizer = config.use_fertilizer,
    fertilize_wait_time = config.fertilize_wait_time,
    sell_level = config.sell_level,
    min_seconds_since_arrival = config.min_seconds_since_arrival
}

-- Per-character overrides (characters.lua overrides = {<name> = {...}});
-- missing fields fall back to config. Read through eff() / get_effective().
local character_overrides = {}

-- Current character's lowercase name, or nil before login finishes.
local function get_character_key()
    local player = windower.ffxi.get_player()
    if not player or not player.name then
        return nil
    end
    return player.name:lower()
end

local function get_character_override()
    local key = get_character_key()
    return key and character_overrides[key]
end

-- Per-character module switches (characters.lua modules = {...}). Only
-- an explicit false turns a module off: furrow, vein, pond, grove,
-- crystals, flotsam, net, books.
-- Also the non-garden switches: sell, process_inv, send_mail,
-- receive_mail (recieve_mail works too), org_inv. Other keys are kept for
-- addons that read characters.lua. Names and keys are case-insensitive.
local character_module_overrides = {}
-- (Re)builds character_overrides / character_module_overrides from CHARACTER_FILE.
local function index_character_file()
    character_overrides = (type(CHARACTER_FILE.overrides) == 'table') and CHARACTER_FILE.overrides or {}
    for k in pairs(character_module_overrides) do character_module_overrides[k] = nil end
    for name, switches in pairs(type(CHARACTER_FILE.modules) == 'table' and CHARACTER_FILE.modules or {}) do
        local t = {}
        for key, value in pairs(type(switches) == 'table' and switches or {}) do
            key = tostring(key):lower()
            t[key == 'recieve_mail' and 'receive_mail' or key] = value
        end
        character_module_overrides[tostring(name):lower()] = t
    end
end
index_character_file()

-- Re-reads characters.lua when its text changed since the last read. A
-- file with an error (e.g. saved mid-edit) is reported once and the last
-- good copy stays in use. The furrowconfig runtime values that come from
-- it (seed, fertilizer, ...) are reset to the file's values on a change.
local character_file_text, character_file_bad_text
do
    local f = io.open(windower.addon_path .. 'characters.lua', 'r')
    if f then
        local text = f:read('*a')
        f:close()
        -- Loaded fine at startup = this text is current; a broken file is
        -- remembered as bad (already reported by load_sibling).
        if CHARACTER_FILE_LOADED then character_file_text = text else character_file_bad_text = text end
    end
end
local function refresh_character_file()
    local f = io.open(windower.addon_path .. 'characters.lua', 'r')
    if not f then return end
    local text = f:read('*a') or ''
    f:close()
    if text == character_file_text or text == character_file_bad_text then return end
    local chunk, err = loadstring(text, '@characters.lua')
    local ok, result = false, err
    if chunk then ok, result = pcall(chunk) end
    if not ok or type(result) ~= 'table' then
        character_file_bad_text = text
        windower.add_to_chat(167, 'GardenHelper: [ERROR] characters.lua changed but has an error (' .. tostring(result) ..
            ') - still using the last good copy.')
        return
    end
    character_file_text, character_file_bad_text = text, nil
    for k in pairs(CHARACTER_FILE) do CHARACTER_FILE[k] = nil end
    for k, v in pairs(result) do CHARACTER_FILE[k] = v end
    apply_character_defaults()
    for key in pairs(config_defaults) do
        for _, cfg in pairs(CHARACTER_DEFAULT_FIELDS) do
            if cfg == key then config_defaults[key] = config[key] end
        end
    end
    index_character_file()
    windower.add_to_chat(200, 'GardenHelper: characters.lua changed - re-read.')
end

local function is_module_enabled(module_key)
    local key = get_character_key()
    local overrides = key and character_module_overrides[key]
    if overrides and overrides[module_key] == false then
        return false
    end
    return true
end

-- Override value (~= nil, so false works) or config[default_field].
local function get_effective(default_field, override_field)
    local override = get_character_override()
    if override and override[override_field] ~= nil then
        return override[override_field]
    end
    return config[default_field]
end

-- This character's value for a furrow setting: seed, fertilizer,
-- use_fertilizer, harvest_time, fertilize_wait_time, reminder_intervals,
-- fertilize_reminder_intervals.
local function eff(field)
    return get_effective((field == 'seed' or field == 'fertilizer') and ('default_' .. field) or field, field)
end

-- Sorted names of the fields this character overrides (furrowstatus/config show).
local function get_active_override_fields()
    local override = get_character_override()
    if not override then
        return {}
    end
    local fields = {}
    for field in pairs(override) do
        table.insert(fields, field)
    end
    table.sort(fields)
    return fields
end

-- entities.lua indexed by friendly name and by id (X/Y navigation).
local ENTITIES = {}
local ENTITIES_BY_ID = {}
for _, e in ipairs(ENTITY_LIST) do
    if e.friendly then ENTITIES[e.friendly] = e end
    if e.id then ENTITIES_BY_ID[e.id] = e end
end

-- An NPC's entity id encodes its zone (0x1000000 + zone*4096 + index);
-- warn about entities.lua entries with a missing/wrong zone.
local function zone_from_entity_id(id)
    if type(id) ~= 'number' or id < 0x1000000 then return nil end
    return math.floor((id - 0x1000000) / 4096)
end
for _, e in ipairs(ENTITY_LIST) do
    local id_zone = zone_from_entity_id(e.id)
    local label = tostring(e.friendly or e.name or e.id)
    if e.zone == nil then
        windower.add_to_chat(167, 'GardenHelper: [WARN] entities.lua: ' .. label .. ' has no zone' ..
            (id_zone and (' (its id says zone ' .. id_zone .. ')') or '') .. '.')
    elseif id_zone and id_zone ~= e.zone then
        windower.add_to_chat(167, 'GardenHelper: [WARN] entities.lua: ' .. label .. ' says zone ' .. e.zone ..
            ' but its id ' .. e.id .. ' belongs to zone ' .. id_zone .. '.')
    end
end

local FURROWS = {
    {name = "Garden Furrow", number = 1, id = 17924128, key = 'Furrow 1'},
    {name = "Garden Furrow #2", number = 2, id = 17924129, key = 'Furrow 2'},
    {name = "Garden Furrow #3", number = 3, id = 17924130, key = 'Furrow 3'}
}

-- ---- Mog Garden entities ----
-- Fixed entity ids, targeted with SetTarget. What's unlocked (rank) is
-- found at runtime with find_entity(); nothing is assumed here.

-- Mineral Veins: harvest the HIGHEST rank. Two ids per rank are two
-- instances of the same vein - only one is targetable at a time; a
-- depleted one is replaced by the other (harvest_ranked).
local VEINS = {
    {rank = 1, variants = {
        {name = 'Mineral Vein', id = 17924139, key = 'Vein 1a'},
        {name = 'Mineral Vein', id = 17924140, key = 'Vein 1b'}
    }},
    {rank = 2, variants = {
        {name = 'Mineral Vein #2', id = 17924141, key = 'Vein 2a'},
        {name = 'Mineral Vein #2', id = 17924142, key = 'Vein 2b'}
    }},
    {rank = 3, variants = {
        {name = 'Mineral Vein #3', id = 17924143, key = 'Vein 3a'},
        {name = 'Mineral Vein #3', id = 17924144, key = 'Vein 3b'}
    }},
    {rank = 4, variants = {
        {name = 'Mineral Vein #4', id = 17924145, key = 'Vein 4a'},
        {name = 'Mineral Vein #4', id = 17924146, key = 'Vein 4b'}
    }}
}

local POND = {name = 'Pond Dredger', id = 17924147, key = 'Pond'}

-- Arboreal Groves: two tasks per rank (Prune / Remove weeds), one
-- targetable at a time; both must be done for the rank to be finished.
-- Harvest the HIGHEST rank.
local GROVES = {
    {rank = 1, variants = {
        {name = 'Arboreal Grove', action = 'Prune the trees', id = 17924131, key = 'Grove 1a'},
        {name = 'Arboreal Grove', action = 'Remove weeds', id = 17924132, key = 'Grove 1b'}
    }},
    {rank = 2, variants = {
        {name = 'Arboreal Grove #2', action = 'Prune the trees', id = 17924133, key = 'Grove 2a'},
        {name = 'Arboreal Grove #2', action = 'Remove weeds', id = 17924134, key = 'Grove 2b'}
    }},
    {rank = 3, variants = {
        {name = 'Arboreal Grove #3', action = 'Prune the trees', id = 17924135, key = 'Grove 3a'},
        {name = 'Arboreal Grove #3', action = 'Remove weeds', id = 17924136, key = 'Grove 3b'}
    }},
    {rank = 4, variants = {
        {name = 'Arboreal Grove #4', action = 'Prune the trees', id = 17924137, key = 'Grove 4a'},
        {name = 'Arboreal Grove #4', action = 'Remove weeds', id = 17924138, key = 'Grove 4b'}
    }}
}

-- Green Thumb Moogle - junk shop and the garden's "home base".
local GREEN_THUMB_MOOGLE = {name = 'Green Thumb Moogle', id = config.sell_junk_moogle_id, key = 'GreenThumb'}

-- Stuck-recovery waypoint (walk_to_moogle_with_waypoint_fallback).
local MOOGLE_WAYPOINT = {name = 'Mandragora Assistant', id = config.moogle_waypoint_id, key = 'Assistant'}

-- Ephemeral Moogle - crystal/cluster trading.
local EPHEMERAL_MOOGLE = {name = 'Ephemeral Moogle', id = 17924238, key = 'Ephem'}

-- Flotsam disappears once harvested for the day.
local FLOTSAM = {name = 'Flotsam', id = 17924150, key = 'Flotsam'}

local NET = {name = 'Coastal Fishing Net', id = 17924149, key = 'Net'}

local state = {
    running = false,
    current_action = nil,
    start_time = nil,
    fertilize_time = nil,
    furrows_found = {false, false, false},
    -- Furrows already announced with "Found ..." this command run (later
    -- finds are debug only). Reset by reconcile_furrow_data().
    furrows_announced = {false, false, false},
    -- Text capture for furrow/node interactions.
    capturing_text = false,
    captured_lines = {},
    -- {furrow_number = true} for furrows that exist, set once per command by
    -- reconcile_furrow_data(); cleared on login/logout/zone change.
    available_furrows = nil,
    -- When that was last probed (config.existence_cache_seconds).
    available_furrows_checked_at = nil,
    -- Latest login / zone-change epoch (config.min_seconds_since_arrival).
    last_arrival_epoch = nil,
    -- True while GardenHelper zones on purpose (Dinghy trips), so the zone
    -- change handler doesn't stop everything.
    expecting_zone = false,
    zone_changed_epoch = 0,
    zone_changed_to = nil,
    -- Set when "inventory full" shows up mid-harvest (run_with_inventory_restart).
    inventory_full_hit = false,
    zone_change_count = 0,
    -- last_arrival_epoch the Green Thumb Moogle arrival check last passed for.
    arrival_confirmed_for = nil
}

-- Modules in this folder (books.lua, crystals.lua, inv.lua, Set_RoE.lua),
-- loaded at the end of this file.
local BOOKS, CRYSTALS, INV, ROE, MEMCHECK, ASSIST

-- Saved per character in data/settings.xml (Windower config library).
local status_defaults = {
    crystals_missing = false,     -- Ephemeral Moogle not found in this garden (not unlocked)
    -- Shining Stars in the GPS crystal (v2.25.0), from the game's line on
    -- the first garden visit of the day; -1 = not seen yet.
    shining_stars = -1, shining_stars_at = '',
    -- Storage bag size (v2.26.0): Storage slots this character has
    -- (0-80; 0 = none), read from the client; -1 = not read yet.
    storage_slots = -1, storage_slots_at = '',
    -- Kitron Macarons held (v2.28.0), all item bags added up; -1 = not counted yet.
    kitron_macarons = -1, kitron_macarons_at = '',
    -- Ephemeral Moogle stock (v2.29.0, crystals.lua): crystals stored per
    -- element "fire,ice,wind,earth,lightning,water,light,dark"; '' = not
    -- read yet. MuleLogger's //ml eph / Tier 12 reads it.
    eph_crystals = '', eph_crystals_at = '',
    -- Skipper Moogle books: result 'checked' / 'purchased' / 'broke', valid
    -- for books_last_checked_date's garden day. attempt_* = failed //gh
    -- full trips today; gave_up_date = the day they ran out; books_auto =
    -- config.books_in_full (other addons reading settings.xml only count
    -- books as due when true).
    books_last_checked_date = '', books_last_checked_at = '', books_last_checked_epoch = 0,
    books_last_result = '', books_last_purchased = '', books_disabled = false, books_unknown = false,
    books_attempt_date = '', books_attempt_count = 0, books_gave_up_date = '', books_auto = false,
    -- Node fertilizer: garden day it is still due (read by //gh duecheck)
    -- and failed tries today (node_fertilize_daily_attempts).
    node_fert_due_date = '', node_fert_tries_date = '', node_fert_tries = 0,
    -- Last seed count (record_seed_inventory, run by duecheck).
    last_seed_name = '', last_seed_count = 0, last_seed_checked_at = '', last_seed_checked_epoch = 0,
    -- Set_RoE.lua: last time the RoE objectives were set / the Unity chat line sent.
    roe_last_set_at = '', roe_last_set_epoch = 0, unity_chat_last_at = '', unity_chat_last_epoch = 0,
    -- Last completed //gh full / force.
    last_full_pass_at = '', last_full_pass_epoch = 0,
    furrow_disabled = false,
    -- Seed error (v2.17.0): no seed in any bag when planting. Set = no
    -- automated furrow runs (//gh full, duecheck, MuleLogger) until
    -- //ml furrow recheck / //gh furrow recheck clears it or a manual
    -- //gh furrow plants successfully.
    furrow_seed_error = '', furrow_seed_error_at = '',
    -- Soonest furrow ETA ('READY' if any furrow needs a look now).
    furrow_next_ready_at = '', furrow_next_ready_epoch = 0,
}
-- furrow_N_*: last recorded state, when it was checked, rank, seed,
-- fertilizer, harvest time and harvests left (multi-harvest seeds: the
-- N in "...should sprout about N more times.", counting the crop that is
-- growing / ready now; 0 = normal seed or not known).
for n = 1, 3 do
    for field, value in pairs({state = 'unknown', checked_at = '', checked_epoch = 0, rank = 0,
            seed = '', fertilizer = '', harvest_at = '', harvest_epoch = 0, harvests_left = 0}) do
        status_defaults['furrow_' .. n .. '_' .. field] = value
    end
end
-- Per module: last harvest (garden day, time, epoch), UNKNOWN flag (set by
-- //gh <module> reset or an unconfirmed attempt), and the status
-- snapshots (sync_module_status_flags). Daily nodes also keep their rank,
-- and all but Flotsam their fertilizer (garden day used, time, item).
for _, m in ipairs({'vein', 'pond', 'grove', 'flotsam', 'net', 'crystals'}) do
    for field, value in pairs({last_harvested_date = '', last_harvested_at = '', last_harvested_epoch = 0,
            unknown = false, disabled = false}) do
        status_defaults[m .. '_' .. field] = value
    end
    if m ~= 'crystals' then
        status_defaults[m .. '_last_rank'] = 0
        status_defaults[m .. '_done_today'] = false
    end
    if m ~= 'crystals' and m ~= 'flotsam' then
        status_defaults[m .. '_fertilized_date'] = ''
        status_defaults[m .. '_fertilized_at'] = ''
        status_defaults[m .. '_fertilizer'] = ''
    end
end
-- Garden assistants (assistants.lua): node they were last seen on
-- ('' = not checked, 'missing' = not in this garden), the task
-- GardenHelper last set there ('' = unknown - the game never shows it),
-- when it was set and when last checked.
for _, a in ipairs({'kuyin', 'susuroon', 'yeestog'}) do
    for field, value in pairs({node = '', task = '', set_at = '', checked_at = ''}) do
        status_defaults['assistant_' .. a .. '_' .. field] = value
    end
end
-- Assistant contracts (employment.lua): recruited ('' / y / n), days
-- left as read on days_date (-1 = never read) and where from, expiry,
-- last hire/trade; count recruited, last check, error, the garden day
-- the game's daily contract line was seen and notices were set.
for _, a in ipairs({'kuyin', 'susuroon', 'yeestog'}) do
    for field, value in pairs({recruited = '', hire_pending = '', days = -1, days_date = '', days_seen_at = '', source = '', expires = '', last_action = '', last_action_at = ''}) do
        status_defaults['employ_' .. a .. '_' .. field] = value
    end
end
for field, value in pairs({count = 0, checked_date = '', checked_at = '', error = '', error_date = '', notice_date = '', notify_set_date = '', extend_due = ''}) do
    status_defaults['employ_' .. field] = value
end
local saved_status = winconfig.load(status_defaults)

local function log(message, color)
    color = color or 200
    windower.add_to_chat(color, 'GardenHelper: ' .. message)
end

local function debug_log(message)
    if config.debug_mode then
        log('[DEBUG] ' .. message, 8)
    end
end

local function error_log(message)
    log('[ERROR] ' .. message, 167)
end


-- winconfig.save() rewrites every character's section from a snapshot
-- taken at load, which would overwrite edits made to the file by
-- another character/client or by hand. persist_status() reloads the file first, puts this character's
-- live values back on top, then saves.
-- read_global_status_from_disk: the <global> section, typed like
-- status_defaults (missing keys = defaults).
local function read_global_status_from_disk()
    local out = {}
    for k, v in pairs(status_defaults) do out[k] = v end
    local f = io.open(windower.addon_path .. 'data/settings.xml', 'r')
    if not f then return out end
    local text = f:read('*a') or ''
    f:close()
    local g = text:match('<global>(.-)</global>')
    if not g then return out end
    local function unescape(v)
        return (v:gsub('&lt;', '<'):gsub('&gt;', '>'):gsub('&quot;', '"'):gsub('&apos;', "'"):gsub('&amp;', '&'))
    end
    local function typed(key, raw)
        local d = status_defaults[key]
        if type(d) == 'number' then return tonumber(raw) or d end
        if type(d) == 'boolean' then return raw == 'true' end
        return unescape(raw)
    end
    for key, raw in g:gmatch('<([%w_]+)>(.-)</%1>') do
        if status_defaults[key] ~= nil then out[key] = typed(key, raw) end
    end
    for key in g:gmatch('<([%w_]+)%s*/>') do
        if status_defaults[key] ~= nil then out[key] = typed(key, '') end
    end
    return out
end

-- winconfig.reload builds every character's snapshot from the LIVE table
-- plus that character's section, and sections omit keys equal to
-- <global> - so this character's values leaked into everyone else's.
-- Put the <global> values in the live table first.
local function reload_status_from_disk()
    local base = read_global_status_from_disk()
    for key, value in pairs(base) do
        saved_status[key] = value
    end
    return pcall(winconfig.reload, saved_status)
end

local function persist_status()
    local snapshot = {}
    for key in pairs(status_defaults) do
        snapshot[key] = saved_status[key]
    end
    reload_status_from_disk()
    for key, value in pairs(snapshot) do
        saved_status[key] = value
    end
    winconfig.save(saved_status)
end

-- Storage bag size (v2.26.0): 0-80 slots (bag 2). nil = the client has
-- not loaded the bags yet (just logged in / zoning). Saved only when it
-- changes; MuleLogger shows it as |Str80| / |Str 5| / |Str 0|.
-- (Fields on state, not locals: main chunk is at the 200-local limit.)
state.storage = {BAG_ID = 2, MAX_SLOTS = 80}
function state.storage.read()
    local main = windower.ffxi.get_items(0)
    if type(main) ~= 'table' or (tonumber(main.max) or 0) <= 0 then
        return nil
    end
    local bag = windower.ffxi.get_items(state.storage.BAG_ID)
    if type(bag) ~= 'table' then
        return nil
    end
    local n = math.floor(tonumber(bag.max) or 0)
    return math.min(math.max(n, 0), state.storage.MAX_SLOTS)
end

function state.storage.record()
    local n = state.storage.read()
    if n ~= nil and tonumber(saved_status.storage_slots) ~= n then
        saved_status.storage_slots = n
        saved_status.storage_slots_at = os.date('%Y-%m-%d %H:%M:%S')
        pcall(persist_status)
        debug_log('Storage: ' .. n .. ' slots - saved.')
    end
    state.km.record()   -- v2.28.0: same moments (login, zone, load, status)
    if state.eph then pcall(state.eph.request) end   -- v2.29.0: Ephemeral Moogle stock (0x113)
    return n
end

-- Kitron Macarons (v2.28.0): total held across every item bag (inventory,
-- Mog Safe/Safe 2, Storage, Locker, Satchel, Sack, Case). nil = bags not
-- loaded yet. Saved only when it changes; MuleLogger shows |KM14|.
state.km = {ITEM_ID = 5781, BAGS = {'inventory', 'safe', 'safe2', 'storage', 'locker', 'satchel', 'sack', 'case'}}
function state.km.read()
    local all = windower.ffxi.get_items()
    if type(all) ~= 'table' or type(all.inventory) ~= 'table' or (tonumber(all.inventory.max) or 0) <= 0 then
        return nil
    end
    local total = 0
    for _, bag_name in ipairs(state.km.BAGS) do
        local bag = all[bag_name]
        if type(bag) == 'table' then
            for _, item in ipairs(bag) do
                if type(item) == 'table' and item.id == state.km.ITEM_ID then
                    total = total + (tonumber(item.count) or 0)
                end
            end
        end
    end
    return total
end

function state.km.record()
    local n = state.km.read()
    if n ~= nil and tonumber(saved_status.kitron_macarons) ~= n then
        saved_status.kitron_macarons = n
        saved_status.kitron_macarons_at = os.date('%Y-%m-%d %H:%M:%S')
        pcall(persist_status)
        debug_log('Kitron Macarons: ' .. n .. ' - saved.')
    end
    return n
end

-- Recount shortly after a Kitron Macaron is added / removed / moved
-- (one recount per burst of item events).
function state.km.item_event(bag, index, id)
    if id ~= state.km.ITEM_ID or state.km.pending then
        return
    end
    state.km.pending = true
    local p = windower.ffxi.get_player()
    local who = p and p.name
    coroutine.schedule(function()
        state.km.pending = false
        local now_p = windower.ffxi.get_player()
        if who and now_p and now_p.name == who then
            state.km.record()
        end
    end, 2)
end

-- Reads Storage after a delay, only if the same character is still on.
function state.storage.record_later(seconds)
    local p = windower.ffxi.get_player()
    local who = p and p.name
    if not who then
        return
    end
    coroutine.schedule(function()
        local now_p = windower.ffxi.get_player()
        if now_p and now_p.name == who then
            state.storage.record()
        end
    end, seconds)
end

-- Save used after a live observation that may have slept: skipped when
-- state.running is false, because login/logout/zone change/stop clear it
-- before saved_status can be swapped for another character - a late
-- save would otherwise land on the wrong character. Commands that save
-- synchronously (status, resets) call persist_status() directly.
local function save_status()
    if not state.running then
        debug_log('save_status: not running (stopped, or another character since) - skipping a possibly stale save.')
        return
    end
    persist_status()
end

-- Global debug flag (all characters, survives reloads) in a plain text
-- file: data/global_debug.txt holds 'true' or 'false'.
local debug_flag_path = windower.addon_path .. 'data/global_debug.txt'
do
    local f = io.open(debug_flag_path, 'r')
    config.debug_mode = f ~= nil and (f:read('*a') or ''):find('true') ~= nil
    if f then f:close() end
end

-- Forward declaration (defined near the module functions, called earlier).
local sync_module_status_flags

-- First capture of pattern in any line, or nil.
local function first_match(lines, pattern)
    for _, line in ipairs(lines or {}) do
        local m = line:match(pattern)
        if m then return m end
    end
    return nil
end

-- Real remaining grow time from "...harvest the <seed> you planted in
-- about N hour(s) [and N minute(s)]..." or nil.
local function parse_remaining_seconds(lines)
    for _, line in ipairs(lines or {}) do
        local h, m = line:match('in about (%d+) hours? and (%d+) minutes?')
        if h then return tonumber(h) * 3600 + tonumber(m) * 60 end
    end
    local h = first_match(lines, 'in about (%d+) hours?')
    if h then return tonumber(h) * 3600 end
    local m = first_match(lines, 'in about (%d+) minutes?')
    return m and tonumber(m) * 60 or nil
end

-- Multi-harvest seed (e.g. arborfruit): "You also conclude that the seed
-- you planted should sprout about N more times." -> N = harvests left,
-- counting the crop growing / ready now. nil = not a multi-harvest line.
local function parse_harvests_left(lines)
    return tonumber(first_match(lines, 'should sprout about (%d+) more'))
end

-- ", N harvests left" for status lines ('' when 0 / not known).
local function harvests_left_suffix(furrow_number)
    local n = tonumber(saved_status['furrow_' .. furrow_number .. '_harvests_left']) or 0
    if n <= 0 then return '' end
    return ', ' .. n .. ' harvest' .. (n == 1 and '' or 's') .. ' left'
end

-- true = don't fertilize this furrow: it holds a multi-harvest seed and
-- config.multi_harvest_fertilize is false.
local function skip_fertilize_multi_harvest(furrow_number)
    return not config.multi_harvest_fertilize and (tonumber(saved_status['furrow_' .. furrow_number .. '_harvests_left']) or 0) > 0
end

-- a + b as a new list (either can be nil).
local function concat_lines(a, b)
    local out = {}
    for _, line in ipairs(a or {}) do table.insert(out, line) end
    for _, line in ipairs(b or {}) do table.insert(out, line) end
    return out
end

-- Records a furrow's state (+ checked time). Rank, seed and fertilizer
-- come from the args or the captured text. harvest_at is locked in here
-- (the game's remaining time if given, else the configured wait) so a
-- config change doesn't move the ETA of a furrow that's already growing.
local function record_furrow_state(furrow_number, classified_state, lines, seed_name, fertilizer_name)
    local now = os.time()
    local key = 'furrow_' .. furrow_number .. '_'
    saved_status[key .. 'state'] = classified_state
    saved_status[key .. 'checked_at'] = os.date('%Y-%m-%d %H:%M:%S', now)
    saved_status[key .. 'checked_epoch'] = now

    -- All furrows share one rank (a book ranks them all up).
    local rank = tonumber(first_match(lines, 'rank (%d+)'))
    if rank then
        for n = 1, 3 do
            if n == furrow_number or saved_status['furrow_' .. n .. '_state'] ~= 'not_found' then
                saved_status['furrow_' .. n .. '_rank'] = rank
            end
        end
    end

    local harvest_epoch
    if classified_state == 'empty' then
        saved_status[key .. 'seed'] = ''
        saved_status[key .. 'fertilizer'] = ''
        saved_status[key .. 'harvest_at'] = ''
        saved_status[key .. 'harvest_epoch'] = 0
        saved_status[key .. 'harvests_left'] = 0
    elseif classified_state == 'fertilized_empty' then
        saved_status[key .. 'harvests_left'] = 0
        -- Fertilizer already in, no seed: needs planting only.
        saved_status[key .. 'seed'] = ''
        local fert = fertilizer_name or first_match(lines, 'using an? (.-) as fertilizer') or first_match(lines, 'fertilized with an? (.-)%.')
        if fert then saved_status[key .. 'fertilizer'] = fert end
        saved_status[key .. 'harvest_at'] = ''
        saved_status[key .. 'harvest_epoch'] = 0
    elseif classified_state == 'growing_unfertilized' or classified_state == 'growing_fertilized' then
        local fertilized = classified_state == 'growing_fertilized'
        -- A live detect of a furrow we never saw planted recovers the seed too.
        local seed = seed_name or ((not fertilized or saved_status[key .. 'seed'] == '') and first_match(lines, 'has an? (.-) planted'))
        if seed then saved_status[key .. 'seed'] = seed end
        if fertilized then
            local fert = fertilizer_name or first_match(lines, 'using an? (.-) as fertilizer')
            if fert then saved_status[key .. 'fertilizer'] = fert end
        else
            saved_status[key .. 'fertilizer'] = ''
        end
        harvest_epoch = now + (parse_remaining_seconds(lines) or eff(fertilized and 'fertilize_wait_time' or 'harvest_time'))
    elseif classified_state == 'ready' then
        harvest_epoch = now
    end
    if harvest_epoch then
        saved_status[key .. 'harvest_epoch'] = harvest_epoch
        saved_status[key .. 'harvest_at'] = os.date('%Y-%m-%d %H:%M:%S', harvest_epoch)
    end
    -- Multi-harvest seed: harvests left, as the game states it.
    local left = parse_harvests_left(lines)
    if left and (classified_state == 'ready' or classified_state == 'growing_unfertilized' or classified_state == 'growing_fertilized') then
        saved_status[key .. 'harvests_left'] = left
    end

    save_status()
end

-- Opens the furrow menu and picks "Inspect" (first item) - read-only,
-- safe on a furrow in any state.
local DETECT_SEQUENCE = {'enter', 'enter'}

-- Keys that back out of the menu for the state DETECT_SEQUENCE found
-- (no entry for 'unknown' - left for a human). The final Enter lands on
-- "Absolutely nothing", which prints nothing, so it doesn't wait for text.
local EXIT_SEQUENCES = {
    empty = {{'down', pre_wait = 0.4}, {'enter', wait = false}},
    -- "What will you do?": Inspect the garden. / Absolutely nothing.
    fertilized_empty = {{'down', pre_wait = 0.4}, {'enter', wait = false}},
    growing_unfertilized = {'enter', {'down', pre_wait = 0.4}, 'down', {'enter', wait = false}},
    growing_fertilized = {'enter', {'down', pre_wait = 0.4}, 'down', {'enter', wait = false}},
    ready = {'enter', {'down', pre_wait = 0.4}, {'enter', wait = false}}
}

-- Current furrow state from recorded data only (no interaction):
-- growing_* becomes 'ready' once its harvest time passes. nil = not
-- enough data (caller does a live check).
local function infer_furrow_state(furrow_number)
    local key = 'furrow_' .. furrow_number .. '_'
    local last_state = saved_status[key .. 'state']
    if last_state == 'empty' or last_state == 'ready' or last_state == 'fertilized_empty' then
        return last_state
    end
    local checked_epoch = tonumber(saved_status[key .. 'checked_epoch']) or 0
    if checked_epoch <= 0 or (last_state ~= 'growing_unfertilized' and last_state ~= 'growing_fertilized') then
        return nil
    end
    -- Stored harvest_epoch (the game's real time); flat estimate only for
    -- old data without one.
    local ready_at = tonumber(saved_status[key .. 'harvest_epoch']) or 0
    if ready_at <= 0 then
        ready_at = checked_epoch + eff(last_state == 'growing_fertilized' and 'fertilize_wait_time' or 'harvest_time')
    end
    return (os.time() >= ready_at) and 'ready' or last_state
end

-- "YYYY-MM-DD HH:MM:SS" -> "M/D h:mmam" (unchanged if it doesn't match).
local function format_short_datetime(s)
    if not s or s == '' then
        return 'unknown'
    end
    local month, day, hour, minute = s:match('^%d%d%d%d%-(%d%d)%-(%d%d) (%d%d):(%d%d)')
    if not month then
        return s
    end
    local h = tonumber(hour)
    return tonumber(month) .. '/' .. tonumber(day) .. ' ' .. ((h % 12 == 0) and 12 or h % 12) .. ':' .. minute .. ((h < 12) and 'am' or 'pm')
end

-- Stored harvest time of a furrow ("YYYY-MM-DD HH:MM:SS"), or checked
-- time + the configured wait for old data, or 'unknown'.
local function furrow_harvest_at(n, fertilized)
    local stored = saved_status['furrow_' .. n .. '_harvest_at']
    if stored and stored ~= '' then
        return stored
    end
    local checked = tonumber(saved_status['furrow_' .. n .. '_checked_epoch']) or 0
    if checked <= 0 then
        return 'unknown'
    end
    return os.date('%Y-%m-%d %H:%M:%S', checked + eff(fertilized and 'fertilize_wait_time' or 'harvest_time'))
end

-- "<seed> growing & fertilized with <fertilizer>, harvest at <time>" (or
-- "growing (no fertilizer)") from stored values, else the configured ones.
local function describe_growing_furrow_value(n, classified_state, seed_name, fertilizer_name)
    local fertilized = (classified_state == 'growing_fertilized')
    local seed = saved_status['furrow_' .. n .. '_seed']
    if not seed or seed == '' then seed = seed_name or eff('seed') end
    local text = seed .. ' growing (no fertilizer)'
    if fertilized then
        local fert = saved_status['furrow_' .. n .. '_fertilizer']
        if not fert or fert == '' then fert = fertilizer_name or eff('fertilizer') end
        text = seed .. ' growing & fertilized with ' .. fert
    end
    return text .. ', harvest at ' .. furrow_harvest_at(n, fertilized) .. harvests_left_suffix(n)
end

-- //gh status line: "Furrow #N: <seed>, <fertilizer or none>, <status>,
-- H@ <M/D h:mmam> (rank N)".
local function describe_furrow_status_line(n, classified_state)
    local seed = saved_status['furrow_' .. n .. '_seed']
    local fert = saved_status['furrow_' .. n .. '_fertilizer']
    if not seed or seed == '' then seed = eff('seed') end
    if not fert or fert == '' then fert = 'none' end
    return 'Furrow #' .. n .. ': ' .. seed .. ', ' .. fert .. ', ' .. ((classified_state == 'ready') and 'ready' or 'growing') ..
        ', H@ ' .. format_short_datetime(furrow_harvest_at(n, fert ~= 'none')) .. harvests_left_suffix(n) .. ' (rank ' .. (saved_status['furrow_' .. n .. '_rank'] or 0) .. ')'
end

-- Sets debug mode and saves it to data/global_debug.txt (all characters).
local function set_debug_mode(on)
    config.debug_mode = on
    local f = io.open(debug_flag_path, 'w')
    if f then
        f:write(on and 'true' or 'false')
        f:close()
        log('Debug mode: ' .. (on and 'ON' or 'OFF') .. ' (saved - stays this way across reloads and on every character until changed again)')
    else
        error_log('Debug mode set to ' .. (on and 'ON' or 'OFF') .. ' for THIS session only - could not open ' .. debug_flag_path .. ' to save it.')
    end
end

-- //gh furrow reset [all|1|2|3]: clears the recorded state so the next
-- command checks the furrow live (furrows have no done-today concept).
local function reset_furrow_status(furrow_arg)
    local only_number = (furrow_arg ~= 'all') and tonumber(furrow_arg) or nil
    if furrow_arg ~= 'all' and not (only_number and FURROWS[only_number]) then
        error_log('//gh furrow reset needs "all" or a furrow number (1, 2, or 3). Example: //gh furrow reset 2')
        return
    end
    for i = 1, 3 do
        if not only_number or only_number == i then
            saved_status['furrow_' .. i .. '_state'] = 'unknown'
            saved_status['furrow_' .. i .. '_checked_at'] = ''
            saved_status['furrow_' .. i .. '_checked_epoch'] = 0
        end
    end
    saved_status.furrow_next_ready_at = ''
    saved_status.furrow_next_ready_epoch = 0
    persist_status()
    sync_module_status_flags()
    log((only_number and ('Furrow ' .. only_number) or 'All furrows') .. ': recorded status cleared - the next command will check live before acting.')
end

-- Presses a key (Windower key-map name) and waits settle seconds.
local CURSOR_SETTLE_SECONDS = 1.0
local function press_key(key, settle)
    windower.send_command('setkey ' .. key .. ' down')
    coroutine.sleep(0.1)
    windower.send_command('setkey ' .. key .. ' up')
    coroutine.sleep(settle or CURSOR_SETTLE_SECONDS)
end

-- Escape x2 to close any leftover menu/cursor before interacting.
local function clear_cursor_state()
    press_key('escape', 0.3)
    press_key('escape', 0.3)
end

-- True once nothing is targeted (watched arrival_release_check_seconds).
local function target_released()
    local waited = 0
    while true do
        if windower.ffxi.get_mob_by_target('t') == nil then
            return true
        end
        if waited >= (config.arrival_release_check_seconds or 1.0) or not state.running then
            return false
        end
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
end

-- A cutscene keeps the target through Escape: press Enter, Escape and
-- check, until the target releases (= cutscene over) or max_seconds pass.
local function press_until_target_released(max_seconds)
    local started = os.time()
    local rounds = 0
    while state.running and os.time() - started < max_seconds do
        press_key('enter', config.arrival_cutscene_key_wait_seconds)
        press_key('escape', config.arrival_cutscene_key_wait_seconds)
        rounds = rounds + 1
        if target_released() then
            log('Cutscene over - target released after ' .. (os.time() - started) .. 's (' .. rounds .. ' Enter/Escape round(s)).')
            return true
        end
        if rounds % 15 == 0 then
            debug_log('Still in the cutscene after ' .. (os.time() - started) .. 's (' .. rounds .. ' rounds)...')
        end
    end
    return false
end

-- v2.27.0: built-in SetTarget. Does what Windower's SetTarget addon does
-- ('settarget <id>'): injects an incoming 0x058 (target lock) packet for
-- the entity, so SetTarget no longer has to be loaded. Skips (false) an
-- entity that isn't loaded or is over 50 yalms away, like SetTarget.
-- Unlike SetTarget (queued command) the packet goes in immediately.
-- config.use_settarget_addon = true goes back to the addon.
-- A field on state, not a local: the main chunk is at the 200-local limit.
state.set_target = function(entity_id)
    entity_id = tonumber(entity_id)
    if not entity_id then
        return false
    end
    if config.use_settarget_addon then
        windower.send_command('settarget ' .. entity_id)
        return true
    end
    local target = windower.ffxi.get_mob_by_id(entity_id)
    if not target or not target.id or not target.index or target.index == 0 then
        debug_log('set_target: id ' .. entity_id .. ' is not loaded - not targeting it')
        return false
    end
    if not target.distance or target.distance > 2500 then   -- squared: 50 yalms
        debug_log('set_target: ' .. tostring(target.name) .. ' (id ' .. entity_id .. ') is over 50 yalms away - not targeting it')
        return false
    end
    local player = windower.ffxi.get_player()
    if not player or not player.id or not player.index then
        return false
    end
    local ok, err = pcall(function()
        local packets = require('packets')
        packets.inject(packets.new('incoming', 0x058, {
            ['Player'] = player.id,
            ['Target'] = target.id,
            ['Player Index'] = player.index,
        }))
    end)
    if not ok then
        error_log('set_target: could not inject the target packet for ' .. tostring(target.name) .. ' (' .. tostring(err) .. ')')
        return false
    end
    return true
end

-- Clears the target, settargets entity_id and polls (up to 3s) until the
-- target's NAME matches (right after settarget the previous target can
-- still be reported). Returns matched (true/false) and the last target.
local function settarget_confirm(entity_id, expected_name)
    windower.send_command('target clear')
    coroutine.sleep(0.2)
    state.set_target(entity_id)
    local target
    for _ = 1, 15 do
        if not state.running then break end
        coroutine.sleep(0.2)
        target = windower.ffxi.get_mob_by_target('t')
        if target and target.name == expected_name then
            return true, target
        end
    end
    return false, target
end

-- Why settarget_confirm failed, for a log line.
local function target_miss_text(entity_id, expected_name, target)
    if target == nil then
        return 'could not target "' .. expected_name .. '" (id ' .. entity_id .. ')'
    end
    return 'id ' .. entity_id .. ' targeted "' .. tostring(target.name) .. '" instead of "' .. expected_name .. '"'
end

-- Targets a furrow by entity id (state.set_target). The target's name must
-- match, else the furrow is treated as not existing. quiet = existence
-- probe (debug lines only). Only the first find per command run is logged.
local function find_furrow(furrow_name, furrow_number, quiet)
    local furrow = FURROWS[furrow_number]
    debug_log('Targeting ' .. furrow_name .. ' by id ' .. furrow.id)
    local ok, target = settarget_confirm(furrow.id, furrow_name)
    state.furrows_found[furrow_number] = ok
    if not state.running then
        return false
    end
    if ok then
        if quiet or state.furrows_announced[furrow_number] then
            debug_log('Found ' .. furrow_name)
        else
            log('Found ' .. furrow_name)
            state.furrows_announced[furrow_number] = true
        end
        return true
    end
    (quiet and debug_log or error_log)(target_miss_text(furrow.id, furrow_name, target) .. ' - assuming ' .. furrow_name .. ' does not exist')
    return false
end

-- Targets the Green Thumb Moogle and confirms the name. quiet = arrival
-- polling (misses are debug only).
local function find_moogle(quiet)
    local ok, target = settarget_confirm(GREEN_THUMB_MOOGLE.id, GREEN_THUMB_MOOGLE.name)
    if not ok and state.running then
        (quiet and debug_log or error_log)(target_miss_text(GREEN_THUMB_MOOGLE.id, GREEN_THUMB_MOOGLE.name, target))
    end
    return ok and state.running
end

-- settarget + name check. false = not targetable right now (not unlocked
-- / not resolved) - debug only, since find_highest_ranked expects misses.
local function find_entity(entity_id, expected_name)
    local ok, target = settarget_confirm(entity_id, expected_name)
    if not ok and state.running then
        debug_log('find_entity: ' .. target_miss_text(entity_id, expected_name, target))
    end
    return ok and state.running
end

-- Distance in yalms to an entity (mob.distance is squared), or nil.
local function distance_to_id(entity_id)
    local mob = windower.ffxi.get_mob_by_id(entity_id)
    return mob and mob.distance and math.sqrt(mob.distance) or nil
end

-- True if the current target is entity_id (and has expected_name, if given).
local function current_target_is(entity_id, expected_name)
    local t = windower.ffxi.get_mob_by_target('t')
    return t ~= nil and t.id == entity_id and (expected_name == nil or t.name == expected_name)
end

-- True if the entity is loaded and flagged as a valid target.
local function entity_present(entity_id)
    local mob = windower.ffxi.get_mob_by_id(entity_id)
    return mob ~= nil and mob.valid_target ~= false
end

-- Re-targets entity_id and waits up to 3s for it (id + name) to stick.
local function retarget_entity(entity_id, expected_name)
    windower.send_command('target clear')
    coroutine.sleep(0.2)
    state.set_target(entity_id)
    for _ = 1, 15 do
        if current_target_is(entity_id, expected_name) or not state.running then break end
        coroutine.sleep(0.2)
    end
    return current_target_is(entity_id, expected_name)
end

-- Lock-On walk to within target_distance (default
-- approach_target_distance). The target is confirmed by id + name first:
-- the distance read doesn't check targeting. expected_name defaults to
-- label (groves pass the real name).
local function walk_to_entity(entity_id, label, target_distance, expected_name)
    target_distance = target_distance or config.approach_target_distance
    expected_name = expected_name or label

    if not current_target_is(entity_id, expected_name) and not retarget_entity(entity_id, expected_name) then
        debug_log('walk_to_entity: could not confirm ' .. label .. ' as the current target - not walking toward it')
        return false
    end

    local distance = distance_to_id(entity_id)
    if not distance then
        debug_log('walk_to_entity: could not read distance to ' .. label .. ' after targeting - skipping')
        return false
    end
    if distance <= target_distance then
        debug_log('Already ' .. string.format('%.1f', distance) .. ' yalms from ' .. label .. ' - no need to walk over')
        return true
    end

    log('Walking to ' .. label .. ' (' .. string.format('%.1f', distance) .. ' yalms away)...')

    -- Lock On Sits when nothing is targeted - re-confirm the target right
    -- before pressing it.
    if not current_target_is(entity_id, expected_name) and not retarget_entity(entity_id, expected_name) then
        error_log('walk_to_entity: could not re-target ' .. label .. ' right before Lock On - not walking (would sit down instead)')
        return false
    end

    local lock_key, forward_key = config.approach_lock_on_key, config.approach_forward_key
    press_key(lock_key, 0.3)
    windower.send_command('setkey ' .. forward_key .. ' down')

    local waited = 0
    local distance_at_start = distance
    local checked_stuck = false

    while distance and distance > target_distance and waited < config.approach_timeout_seconds and state.running do
        coroutine.sleep(config.approach_poll_interval)
        waited = waited + config.approach_poll_interval
        distance = distance_to_id(entity_id)

        -- Once, a couple of seconds in: no progress = Lock On didn't engage.
        -- Release Forward, tap Lock On (stands up if sitting), retarget, retry.
        if not checked_stuck and waited >= config.approach_stuck_check_seconds then
            checked_stuck = true
            if distance and (distance_at_start - distance) < config.approach_stuck_epsilon_yalms then
                log('Not closing distance to ' .. label .. ' after ' .. waited .. 's - Lock On may not have engaged (sitting down instead?) - recovering and retrying...')
                windower.send_command('setkey ' .. forward_key .. ' up')
                coroutine.sleep(0.2)
                press_key(lock_key, 0.3)
                if not retarget_entity(entity_id, expected_name) then
                    error_log('walk_to_entity: could not re-target ' .. label .. ' during recovery - giving up on this walk')
                    break
                end
                press_key(lock_key, 0.3)
                windower.send_command('setkey ' .. forward_key .. ' down')
            end
        end
    end

    windower.send_command('setkey ' .. forward_key .. ' up')
    coroutine.sleep(0.2)
    press_key(lock_key, 0) -- release Lock On

    if not state.running then
        debug_log('walk_to_entity: stop requested mid-walk to ' .. label)
        return false
    end
    if not distance then
        error_log('Lost track of ' .. label .. ' while walking over')
        return false
    elseif distance > target_distance then
        error_log('Still ' .. string.format('%.1f', distance) .. ' yalms from ' .. label .. ' after ' .. config.approach_timeout_seconds .. 's - giving up on walking over')
        return false
    end
    log('Reached ' .. label .. ' (' .. string.format('%.1f', distance) .. ' yalms)')
    return true
end

-- Forward-declared; defined after walk_to_xy.
local navigate_to_entity, walk_confirmed

local function approach_furrow(furrow_number)
    local furrow = FURROWS[furrow_number]
    -- X/Y navigation when the furrow has a spot in entities.lua.
    if config.navigation_mode == 'xy' and furrow.key and ENTITIES[furrow.key] and ENTITIES[furrow.key].x then
        walk_confirmed('furrow', furrow.key, furrow.id, furrow.name, furrow.name)
        return
    end
    local distance = distance_to_id(furrow.id)
    if distance and distance <= config.approach_target_distance then
        debug_log('Already ' .. string.format('%.1f', distance) .. ' yalms from ' .. furrow.name .. ' - no need to walk over')
        return
    end
    if not find_furrow(furrow.name, furrow.number) then
        error_log(furrow.name .. ' not found - cannot walk over to it')
        return
    end
    walk_to_entity(furrow.id, furrow.name)
end

-- How many of item_name are in main inventory (nil = not a real item name).
local function get_item_count(item_name)
    local item = res.items:with('name', item_name)
    if not item then
        return nil
    end
    local count = 0
    for _, slot in ipairs(windower.ffxi.get_items(0) or {}) do -- ipairs: skips the 'max' field
        if slot.id == item.id then
            count = count + slot.count
        end
    end
    return count
end

-- Saves the seed count in settings.xml (duecheck calls this on every visit).
local function record_seed_inventory(seed_name)
    local have = get_item_count(seed_name)
    if not have then
        debug_log('record_seed_inventory: "' .. tostring(seed_name) .. '" is not a recognized item name - skipping')
        return
    end
    saved_status.last_seed_name = seed_name
    saved_status.last_seed_count = have
    saved_status.last_seed_checked_at = os.date('%Y-%m-%d %H:%M:%S')
    saved_status.last_seed_checked_epoch = os.time()
    save_status()
end

-- ---- X/Y navigation ----
-- Walks to known-good X/Y spots from entities.lua with
-- windower.ffxi.run(dx, dy) (client movement, re-aimed every
-- xy_poll_interval; run(false) stops). Avoids Lock-On running into tables.

-- Chat line + call sound (config.alert_*).
local function alert(message)
    log('[ALERT] ' .. message, 167)
    if config.alert_chat_command and config.alert_chat_command ~= '' then
        local call = (config.alert_call_tag and config.alert_call_tag ~= '') and (' ' .. config.alert_call_tag) or ''
        windower.chat.input(config.alert_chat_command .. ' GardenHelper: ' .. message .. call)
    end
    if config.alert_sound_file and config.alert_sound_file ~= '' then
        pcall(windower.play_sound, config.alert_sound_file)
    end
end

-- Player's X/Y (nil mid-zone).
local function player_xy()
    local me = windower.ffxi.get_mob_by_target('me')
    if me and me.x and me.y then
        return me.x, me.y
    end
    return nil, nil
end

-- Walks to (x, y). opts: tolerance (default xy_arrive_tolerance),
-- stop_check() -> true to stop early, timeout (default
-- approach_timeout_seconds). Stuck (less than xy_stuck_epsilon_yalms
-- progress per xy_stuck_check_seconds): sidestep left/right; after
-- xy_max_stuck_checks in a row, arrived if within interact_distance.
-- Inside xy_near_zone_yalms: finished as soon as the distance stops
-- dropping (spots are often node centers). Returns true = arrived.
local function walk_to_xy(x, y, label, opts)
    opts = opts or {}
    local tolerance = opts.tolerance or config.xy_arrive_tolerance
    local timeout = opts.timeout or config.approach_timeout_seconds

    local px, py = player_xy()
    if not px then
        error_log('walk_to_xy: could not read your own position - cannot walk to ' .. label)
        return false
    end
    local dist = math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
    if dist <= tolerance or (opts.stop_check and opts.stop_check()) then
        debug_log('Already at ' .. label .. ' (' .. string.format('%.1f', dist) .. ' yalms from its X/Y)')
        return true
    end

    log('Walking to ' .. label .. ' (' .. string.format('%.1f', dist) .. ' yalms, by X/Y)...')

    local waited = 0
    local since_check = 0
    local dist_at_check = dist
    local stuck_checks = 0
    local nudge_side = 1
    local arrived = false
    local near_zone = config.xy_near_zone_yalms or 6.0
    local best_dist = dist
    local plateau_t = 0

    while state.running and waited < timeout do
        px, py = player_xy()
        if not px then break end
        local dx, dy = x - px, y - py
        dist = math.sqrt(dx * dx + dy * dy)
        if dist <= tolerance or (opts.stop_check and opts.stop_check()) then
            arrived = true
            break
        end

        -- Near zone: stop once the distance stops dropping.
        if dist < best_dist - (config.xy_plateau_epsilon_yalms or 0.1) then
            best_dist = dist
            plateau_t = 0
        elseif dist <= near_zone then
            plateau_t = plateau_t + config.xy_poll_interval
            if plateau_t >= (config.xy_plateau_seconds or 0.6) then
                debug_log('walk_to_xy: ' .. string.format('%.1f', dist) .. ' yalms from ' .. label .. '\'s X/Y and no longer getting closer - finishing the walk here')
                arrived = true
                break
            end
        end

        windower.ffxi.run(dx, dy)
        coroutine.sleep(config.xy_poll_interval)
        waited = waited + config.xy_poll_interval
        since_check = since_check + config.xy_poll_interval

        if since_check >= config.xy_stuck_check_seconds and dist <= near_zone then
            -- inside the near zone the plateau watch above decides - no sidesteps
            since_check = 0
            stuck_checks = 0
            dist_at_check = dist
        elseif since_check >= config.xy_stuck_check_seconds then
            since_check = 0
            if (dist_at_check - dist) < config.xy_stuck_epsilon_yalms then
                stuck_checks = stuck_checks + 1
                debug_log('walk_to_xy: little progress toward ' .. label .. ' (' .. string.format('%.1f', dist) .. ' yalms left) - stuck check ' .. stuck_checks .. '/' .. config.xy_max_stuck_checks)
                if stuck_checks >= config.xy_max_stuck_checks then
                    break
                end
                -- Sidestep perpendicular to the direction of travel, then re-aim.
                windower.ffxi.run(-dy * nudge_side, dx * nudge_side)
                coroutine.sleep(0.4)
                waited = waited + 0.4
                nudge_side = -nudge_side
            else
                stuck_checks = 0
            end
            dist_at_check = dist
        end
    end

    windower.ffxi.run(false)
    coroutine.sleep(0.2)

    if not state.running then
        debug_log('walk_to_xy: stop requested mid-walk to ' .. label)
        return false
    end

    if arrived then
        debug_log('Reached ' .. label .. ' X/Y (' .. string.format('%.1f', dist) .. ' yalms from the spot)')
        return true
    end

    if dist and dist <= math.max(config.interact_distance, near_zone) then
        debug_log('walk_to_xy: stopped ' .. string.format('%.1f', dist) .. ' yalms short of ' .. label .. '\'s X/Y (probably bumped into it) - close enough to interact, treating as arrived')
        return true
    end

    error_log('Could not reach ' .. label .. ' by X/Y - still ' .. string.format('%.1f', dist or -1) .. ' yalms away after ' .. string.format('%.0f', waited) .. 's. Check the X/Y in entities.lua (a straight run from where you were may be blocked).')
    return false
end

-- Gets within interact_distance of entity_id, walking toward the
-- entity's own position if needed (alert_label: also alert() about it).
local function ensure_in_interact_range(entity_id, label, alert_label)
    local d = distance_to_id(entity_id)
    if not d then
        return false
    end
    if d <= config.interact_distance then
        return true
    end

    local px, py = player_xy()
    if alert_label then
        alert(alert_label .. ' is ' .. string.format('%.1f', d) .. ' yalms away after harvesting started - moving to it. Standing at X: ' ..
            string.format('%.3f', px or 0) .. ', Y: ' .. string.format('%.3f', py or 0) .. ' - consider a new X/Y in entities.lua.')
    end

    local mob = windower.ffxi.get_mob_by_id(entity_id)
    if not mob then return false end
    walk_to_xy(mob.x, mob.y, label, {
        tolerance = 1.0,
        stop_check = function()
            local dd = distance_to_id(entity_id)
            return dd ~= nil and dd <= (config.interact_distance - 1.0)
        end
    })
    d = distance_to_id(entity_id)
    return d ~= nil and d <= config.interact_distance
end

-- Walks to an entities.lua entry (friendly key or entry table) so that
-- target_id (default: the entry's id) is in reach. Lock-On walk when
-- navigation_mode isn't 'xy' or there's no X/Y. Leaves nothing targeted.
navigate_to_entity = function(key_or_entry, target_id, label, walk_opts)
    local e = (type(key_or_entry) == 'table') and key_or_entry or ENTITIES[key_or_entry]
    if not e then
        error_log('navigate_to_entity: "' .. tostring(key_or_entry) .. '" is not in entities.lua')
        return false
    end
    target_id = target_id or e.id
    label = label or e.friendly or e.name

    if config.navigation_mode ~= 'xy' or e.x == nil or e.y == nil then
        if not find_entity(target_id, e.name) then
            return false
        end
        return walk_to_entity(target_id, label, config.node_approach_distance, e.name)
    end

    local info = windower.ffxi.get_info()
    if e.zone and info and info.zone ~= e.zone then
        error_log(label .. ' is in zone ' .. e.zone .. ' but you are in zone ' .. tostring(info and info.zone) .. ' - not walking there.')
        return false
    end

    -- Already close enough to the actual target - no need to move.
    local d = distance_to_id(target_id)
    if d and d <= config.interact_distance then
        local px, py = player_xy()
        local spot_d = px and math.sqrt((e.x - px) ^ 2 + (e.y - py) ^ 2) or 999
        if spot_d <= config.interact_distance then
            debug_log('Already within reach of ' .. label .. ' (' .. string.format('%.1f', d) .. ' yalms)')
            return true
        end
    end

    -- Waypoints (entities.lua "via"): walk each one first, in order, to
    -- steer around walls. One is skipped when you're already closer to
    -- the destination than it is (already past it / coming from the
    -- other side). A waypoint that can't be reached isn't fatal - the
    -- walk carries on toward the next point.
    -- v2.20.0: a waypoint can name an entities.lua entry ({key = 'Flotsam'})
    -- instead of x/y. via_from = {keys} limits the route to walks that
    -- START within via_from_radius of one of those entries' X/Y; such a
    -- route is walked in full, in order (no "already past it" skip).
    local via_forced = false
    local via_ok = type(e.via) == 'table'
    if via_ok and type(e.via_from) == 'table' then
        via_ok = false
        local px, py = player_xy()
        local r = e.via_from_radius or 6
        if px then
            for _, k in ipairs(e.via_from) do
                local o = ENTITIES[k]
                if o and o.x and o.y and math.sqrt((o.x - px) ^ 2 + (o.y - py) ^ 2) <= r then
                    via_ok = true
                    via_forced = true
                    debug_log(label .. ': starting near ' .. k .. ' - taking the via route')
                    break
                end
            end
        end
        if not via_ok then debug_log(label .. ': not starting near a via_from spot - walking straight') end
    end
    if via_ok then
        for i, wp in ipairs(e.via) do
            local wpx, wpy = wp.x, wp.y
            if wp.key and ENTITIES[wp.key] then wpx, wpy = ENTITIES[wp.key].x, ENTITIES[wp.key].y end
            if wpx and wpy then
                local px, py = player_xy()
                local me_to_dest = px and math.sqrt((e.x - px) ^ 2 + (e.y - py) ^ 2) or 999
                local wp_to_dest = math.sqrt((e.x - wpx) ^ 2 + (e.y - wpy) ^ 2)
                if via_forced or me_to_dest > wp_to_dest then
                    local wp_label = label .. ' waypoint ' .. i .. (wp.key and (' (' .. wp.key .. ')') or '')
                    debug_log('Walking via ' .. wp_label .. ' (X: ' .. wpx .. ', Y: ' .. wpy .. ')')
                    local wp_opts = {tolerance = wp.tolerance or config.xy_arrive_tolerance}
                    if walk_opts and walk_opts.stop_check then wp_opts.stop_check = walk_opts.stop_check end
                    if not walk_to_xy(wpx, wpy, wp_label, wp_opts) then
                        debug_log('Could not reach ' .. wp_label .. ' - carrying on to ' .. label)
                    end
                    if not state.running then return false end
                    if walk_opts and walk_opts.stop_check and walk_opts.stop_check() then return false end
                else
                    debug_log('Skipping ' .. label .. ' waypoint ' .. i .. ' - already past it')
                end
            end
        end
    end

    local ok = walk_to_xy(e.x, e.y, label, walk_opts)
    if not state.running then return false end

    if not ok then
        -- Last resort: the old Lock-On walk straight at the target.
        debug_log('navigate_to_entity: X/Y walk to ' .. label .. ' failed - trying the Lock-On walk instead')
        if find_entity(target_id, e.name) then
            return walk_to_entity(target_id, label, config.node_approach_distance, e.name)
        end
        return false
    end

    -- At the spot - if the target itself resolves but is still out of
    -- reach (the X/Y needs tuning), close the gap toward it.
    d = distance_to_id(target_id)
    if d and d > config.interact_distance then
        debug_log(label .. ' is ' .. string.format('%.1f', d) .. ' yalms from its X/Y spot - moving closer')
        return ensure_in_interact_range(target_id, label, nil)
    end
    return true
end

-- navigate_to_entity with the double check (config.double_check_before_walk
-- [kind]; off or kind nil = plain navigate_to_entity): the object must be
-- loaded + targetable to start, is re-checked every double_check_seconds
-- while walking (gone = the walk stops right there) and once more on
-- arrival, no sooner than double_check_seconds after the first check.
-- Returns true, or false + 'missing' (not there to start) / 'gone'
-- (vanished on the way or on arrival) / nil (walk failed).
walk_confirmed = function(kind, key, entity_id, entity_name, label)
    if not (kind and (config.double_check_before_walk or {})[kind]) then
        return navigate_to_entity(key, entity_id, label)
    end
    local interval = config.double_check_seconds or 1
    if not (entity_present(entity_id) and find_entity(entity_id, entity_name)) then
        debug_log(kind .. ': ' .. label .. ' is not there / not targetable - not walking to it')
        return false, 'missing'
    end
    local w = {elapsed = 0, last = 0, lost = false}
    local poll = config.xy_poll_interval or 0.1
    local walk_opts = {stop_check = function()
        w.elapsed = w.elapsed + poll
        if w.elapsed - w.last >= interval then
            w.last = w.elapsed
            if not entity_present(entity_id) then
                w.lost = true
                return true
            end
        end
        return false
    end}
    local ok = navigate_to_entity(key, entity_id, label, walk_opts)
    if not state.running then return false end
    local function gone(when)
        log(label .. ' disappeared ' .. when .. ' - not using it.')
        windower.send_command('target clear')
        return false, 'gone'
    end
    if w.lost then
        return gone('on the way (stopped walking)')
    end
    if not ok then return false end
    if w.elapsed < interval then
        coroutine.sleep(interval - w.elapsed)
        if not state.running then return false end
    end
    if entity_present(entity_id) and (current_target_is(entity_id, entity_name) or find_entity(entity_id, entity_name)) then
        debug_log(kind .. ': ' .. label .. ' still there on arrival - confirmed')
        return true
    end
    return gone('by the time you got there')
end

-- True if any line (from from_index on) contains the phrase, or any of a
-- list of phrases (plain substring).
local function lines_contain(lines, phrases, from_index)
    if type(phrases) ~= 'table' then phrases = {phrases} end
    for i = from_index or 1, #lines do
        for _, phrase in ipairs(phrases) do
            if lines[i]:find(phrase, 1, true) then
                return true
            end
        end
    end
    return false
end

-- ---- "Target out of range." -> walk closer, retry ----
-- True if every line is "Target out of range" (nothing happened in game).
local function lines_all_out_of_range(lines)
    for _, line in ipairs(lines) do
        if not lines_contain({line}, config.out_of_range_phrases) then
            return false
        end
    end
    return #lines > 0
end

-- {id, name} of the current target, taken when an interaction starts.
local function current_interaction_target()
    local t = windower.ffxi.get_mob_by_target('t')
    if t and t.id and t.name then
        return {id = t.id, name = t.name}
    end
    return nil
end

-- Walks toward a refused target until within the next
-- out_of_range_walk_distances step (or straight at it), re-targets it by
-- id + name and logs the standing X/Y. true = retry the interaction.
local function walk_closer_after_out_of_range(target, attempt)
    if not state.running then
        return false
    end
    if not target then
        error_log('"Target out of range" - but nothing was targeted when the interaction started, so there is nothing to walk to.')
        return false
    end
    local mob = windower.ffxi.get_mob_by_id(target.id)
    if not mob or not mob.x or not mob.y then
        error_log('"Target out of range" from ' .. target.name .. ', and it can no longer be found - cannot walk closer.')
        return false
    end

    local d = distance_to_id(target.id) or 0
    local goal = nil
    for _, g in ipairs(config.out_of_range_walk_distances or {}) do
        if g < d - 0.3 then
            goal = g
            break
        end
    end

    local px, py = player_xy()
    log('"Target out of range" from ' .. target.name .. ' at ' .. string.format('%.1f', d) .. ' yalms (standing at X: ' ..
        string.format('%.3f', px or 0) .. ', Y: ' .. string.format('%.3f', py or 0) .. ') - walking closer' ..
        (goal and (' (to ' .. string.format('%.1f', goal) .. ' yalms)') or ' (straight at it)') ..
        ', then trying again (' .. attempt .. '/' .. config.out_of_range_max_retries .. ')...', 167)

    local opts = {tolerance = 0.5}
    if goal then
        opts.stop_check = function()
            local dd = distance_to_id(target.id)
            return dd ~= nil and dd <= goal
        end
    end
    walk_to_xy(mob.x, mob.y, target.name, opts)
    if not state.running then
        return false
    end

    local after = distance_to_id(target.id)
    if not retarget_entity(target.id, target.name) then
        error_log('Walked closer to ' .. target.name .. ' but could not re-target it - not retrying.')
        return false
    end
    debug_log('Now ' .. string.format('%.1f', after or -1) .. ' yalms from ' .. target.name .. ' - retrying the interaction')
    coroutine.sleep(config.out_of_range_retry_settle_seconds or 0.5)
    return true
end

local function out_of_range_give_up(target, why)
    state.out_of_range_failed = true
    local px, py = player_xy()
    error_log('"Target out of range" from ' .. ((target and target.name) or 'the target') .. ' - ' .. why ..
        ' Standing at X: ' .. string.format('%.3f', px or 0) .. ', Y: ' .. string.format('%.3f', py or 0) ..
        ' - check its X/Y in entities.lua.')
end

-- Vein/pond/grove/flotsam/net interaction: press Enter once per entry in
-- waits (seconds to wait after each), capturing text; returns the lines.
--   extra_wait_after   - extra wait after the last press (Net's cutscene)
--   early_exit_phrases - phrase or list; stop pressing once one shows up
--   settle_on_obtained - Pond/Flotsam/Net: stop at the first "Obtained:"
--                        and keep listening until the lines stop
-- Inventory full stops the cycle, presses Enter + Escape and sets
-- state.inventory_full_hit (the caller must not mark anything done).
-- "Target out of range" on the first press walks closer and restarts.
local function wait_for_obtained_to_settle()
    local last_count = #state.captured_lines
    local quiet = 0
    local total = 0
    while state.running and quiet < config.obtained_settle_seconds and total < config.obtained_max_wait_seconds do
        coroutine.sleep(0.2)
        total = total + 0.2
        if #state.captured_lines > last_count then
            local got_obtained = false
            for i = last_count + 1, #state.captured_lines do
                if state.captured_lines[i]:find(config.obtained_phrase, 1, true) then
                    got_obtained = true
                end
            end
            last_count = #state.captured_lines
            if got_obtained then
                quiet = 0
            else
                quiet = quiet + 0.2
            end
        else
            quiet = quiet + 0.2
        end
    end
end

local function acknowledge_inventory_full()
    press_key('enter', 1.0)
    press_key('escape', 1.0)
end

local function press_enter_cycle(waits, extra_wait_after, early_exit_phrases, settle_on_obtained)
    extra_wait_after = extra_wait_after or 0

    local exit_phrases = {}
    if early_exit_phrases then
        for _, phrase in ipairs((type(early_exit_phrases) == 'table') and early_exit_phrases or {early_exit_phrases}) do
            table.insert(exit_phrases, phrase)
        end
    end
    for _, phrase in ipairs(config.inventory_full_phrases) do
        table.insert(exit_phrases, phrase)
    end
    if settle_on_obtained then
        table.insert(exit_phrases, config.obtained_phrase)
    end

    state.captured_lines = {}
    state.capturing_text = true
    state.out_of_range_failed = false

    local range_target = current_interaction_target()
    local range_attempt = 0

    local stopped_early = false
    while true do
    local out_of_range_press = nil
    for press_index, wait_seconds in ipairs(waits) do
        if not state.running then
            stopped_early = true
            break
        end

        local lines_before_this_press = #state.captured_lines

        press_key('enter', wait_seconds)

        if lines_contain(state.captured_lines, config.out_of_range_phrases, lines_before_this_press + 1) then
            out_of_range_press = press_index
            stopped_early = true
            break
        end

        -- A fertilized node prints one extra line: press one more Enter
        -- (only this press's new lines are checked).
        local new_lines = {}
        for i = lines_before_this_press + 1, #state.captured_lines do
            table.insert(new_lines, state.captured_lines[i])
        end
        if lines_contain(new_lines, config.fertilizer_extra_press_phrases) then
            debug_log('press_enter_cycle: fertilizer/bait line detected - pressing one extra Enter to absorb it')
            press_key('enter', config.fertilizer_extra_press_wait_seconds)
        end

        if lines_contain(state.captured_lines, exit_phrases) then
            stopped_early = true
            break
        end
    end

    if not out_of_range_press or not state.running then
        break
    end
    if out_of_range_press ~= 1 and not lines_all_out_of_range(state.captured_lines) then
        out_of_range_give_up(range_target, 'partway through, after the game had already responded - not retrying.')
        break
    end
    if range_attempt >= config.out_of_range_max_retries then
        out_of_range_give_up(range_target, 'still refused after ' .. range_attempt .. ' walk(s) closer - giving up on it for now.')
        break
    end
    range_attempt = range_attempt + 1
    state.capturing_text = false
    if not walk_closer_after_out_of_range(range_target, range_attempt) then
        state.out_of_range_failed = true
        state.capturing_text = true
        break
    end
    state.captured_lines = {}
    state.capturing_text = true
    stopped_early = false
    end

    -- Late "Obtained" wait (obtained_late_wait_seconds), ends as soon as the
    -- result shows up.
    if settle_on_obtained and not stopped_early then
        local window = math.max(extra_wait_after, config.obtained_late_wait_seconds or 0)
        local waited = 0
        while state.running and waited < window and not lines_contain(state.captured_lines, exit_phrases) do
            coroutine.sleep(0.2)
            waited = waited + 0.2
        end
        if waited > 0 then
            debug_log('press_enter_cycle: waited ' .. string.format('%.1f', waited) .. 's after the last press for the result')
        end
        extra_wait_after = 0
    end

    if lines_contain(state.captured_lines, config.inventory_full_phrases) then
        log('Inventory is full - stopping this harvest (not marking it done).', 167)
        state.inventory_full_hit = true
        acknowledge_inventory_full()
        state.capturing_text = false
        return state.captured_lines
    end

    if settle_on_obtained and lines_contain(state.captured_lines, config.obtained_phrase) then
        wait_for_obtained_to_settle()
        -- A late inventory-full line can still arrive while settling.
        if lines_contain(state.captured_lines, config.inventory_full_phrases) then
            log('Inventory is full - stopping this harvest (not marking it done).', 167)
            state.inventory_full_hit = true
            acknowledge_inventory_full()
        end
    elseif extra_wait_after > 0 and not stopped_early then
        coroutine.sleep(extra_wait_after)
    end

    state.capturing_text = false
    return state.captured_lines
end

-- Garden day label. The garden resets at Japanese midnight = 15:00 UTC
-- (no DST in Japan), so shift UTC back 15h and take the date. Independent
-- of the PC's timezone.
local JST_RESET_UTC_OFFSET_SECONDS = 15 * 3600
local function get_garden_day_string(epoch)
    return os.date('!%Y-%m-%d', (epoch or os.time()) - JST_RESET_UTC_OFFSET_SECONDS)
end

-- Epoch of the next Japanese-midnight reset strictly after now.
local function next_garden_reset_epoch()
    local now = os.time()
    local day_start = now - ((now - JST_RESET_UTC_OFFSET_SECONDS) % 86400)
    return day_start + 86400
end

-- True if the module (vein/pond/grove/flotsam/net/crystals) is recorded
-- as done for the current garden day (flips back at the reset).
local function node_done_today(prefix)
    if saved_status[prefix .. '_unknown'] == true then
        return false
    end
    return saved_status[prefix .. '_last_harvested_date'] == get_garden_day_string()
end

-- 'done' / 'not_done' / 'unknown' for //gh status.
local function node_status(prefix)
    if saved_status[prefix .. '_unknown'] == true then
        return 'unknown'
    end
    if saved_status[prefix .. '_last_harvested_date'] == get_garden_day_string() then
        return 'done'
    end
    local rank = tonumber(saved_status[prefix .. '_last_rank']) or 0
    local at = saved_status[prefix .. '_last_harvested_at']
    if rank == 0 and (not at or at == '') then
        return 'unknown'
    end
    return 'not_done'
end

-- Records a module as done for today (+ time, epoch, rank if known) or,
-- done = false, clears it and marks it UNKNOWN. by_hand (//gh <module>
-- done / reset) saves even when nothing is running and logs it.
local function set_module_done(prefix, done, rank, by_hand)
    local now = os.time()
    saved_status[prefix .. '_last_harvested_date'] = done and get_garden_day_string(now) or ''
    saved_status[prefix .. '_last_harvested_at'] = done and os.date('%Y-%m-%d %H:%M:%S', now) or ''
    saved_status[prefix .. '_last_harvested_epoch'] = done and now or 0
    saved_status[prefix .. '_unknown'] = not done
    if rank and saved_status[prefix .. '_last_rank'] ~= nil then
        saved_status[prefix .. '_last_rank'] = rank
    end
    if not by_hand then
        return save_status()
    end
    persist_status()
    sync_module_status_flags()
    log(prefix:sub(1, 1):upper() .. prefix:sub(2) .. (done and (': marked done for today (garden day ' .. get_garden_day_string(now) .. ').') or ': status reset to UNKNOWN for this character.'))
end

-- Unconfirmed attempt (no result, no already-done line): flag UNKNOWN so
-- status shows it and the next run retries. Date/rank untouched.
local function mark_node_unknown(prefix)
    saved_status[prefix .. '_unknown'] = true
    save_status()
end

-- Node fertilizer for today: nil = none configured, 'used' (already
-- today), 'waiting' (not harvested since the reset - fertilizing before
-- the day's harvest would waste it), 'due', 'none' (none in inventory),
-- 'gave_up' (failed node_fertilize_daily_attempts times today),
-- 'bad_name'. Second value = the item name.
local function node_fert_state(prefix)
    if prefix == 'flotsam' or prefix == 'crystals' then return nil end
    local fert = get_effective(prefix .. '_fertilizer', prefix .. '_fertilizer')
    if type(fert) ~= 'string' or fert == '' then return nil end
    local today = get_garden_day_string()
    if saved_status[prefix .. '_fertilized_date'] == today then return 'used', fert end
    -- Harvested today: the date AND the epoch must be after the reset.
    if not node_done_today(prefix) or (tonumber(saved_status[prefix .. '_last_harvested_epoch']) or 0) < next_garden_reset_epoch() - 86400 then
        return 'waiting', fert
    end
    if saved_status.node_fert_tries_date == today and (tonumber(saved_status.node_fert_tries) or 0) >= config.node_fertilize_daily_attempts then
        return 'gave_up', fert
    end
    local have = get_item_count(fert)
    if have == nil then return 'bad_name', fert end
    return (have < 1) and 'none' or 'due', fert
end

-- Captures text until phrase shows up (or, with no phrase, any line), up
-- to max_wait. action() (optional) runs once capture is on, so a fast
-- reply can't be missed. Returns found, lines.
local function capture_until(max_wait, phrase, action)
    state.captured_lines = {}
    state.capturing_text = true
    if action then action() end
    local function seen()
        if phrase then return lines_contain(state.captured_lines, phrase) end
        return #state.captured_lines > 0
    end
    local waited = 0
    while waited < max_wait and state.running and not seen() do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    state.capturing_text = false
    return seen(), state.captured_lines
end

-- Forward declarations (defined further down).
local plant_seed, fertilize_furrow, harvest_furrow, live_probe_furrow, sell_junk_to_moogle

local check_furrow_states, reconcile_furrow_data, handle_furrow_for_start, get_active_furrows

-- //gh furrowplant / furrowfertilize / furrowharvest: a fresh status
-- check (check_furrow_states), then act(furrow) on every furrow in
-- wanted_state. act returns ok, lines, seed, fertilizer, state_override,
-- recorded; on success it is recorded as state_override or new_state
-- (skipped when recorded = true - act already recorded it).
local function furrow_cycle(verb, wanted_state, new_state, act)
    state.current_action = verb
    state.furrows_found = {false, false, false}
    log('Checking fresh status of all furrows before ' .. verb .. '...')
    local fresh_states = check_furrow_states(nil)
    local count = 0
    for _, furrow in ipairs(FURROWS) do
        if not state.running then break end
        local fresh = fresh_states[furrow.number]  -- nil = this character doesn't have it
        if fresh == 'not_found' then
            error_log(furrow.name .. ' not found - stopping')
            break
        elseif fresh == 'unknown' then
            log(furrow.name .. ' - could not determine its status, skipping. Check the screen and //gh furrowinspect ' .. furrow.number .. ' by hand.')
        elseif fresh and not (fresh == wanted_state or (type(wanted_state) == 'table' and wanted_state[fresh])) then
            log(furrow.name .. ' is "' .. fresh .. '" - skipping')
        elseif fresh then
            if not find_furrow(furrow.name, furrow.number) then
                error_log(furrow.name .. ' not found - stopping')
                break
            end
            coroutine.sleep(1)
            local ok, lines, seed, fert, state_override, recorded = act(furrow, fresh)
            if ok then
                count = count + 1
                if not recorded then
                    record_furrow_state(furrow.number, state_override or new_state, lines, seed, fert)
                end
            end
            coroutine.sleep(2)
        end
    end
    state.current_action = nil
    log('Done ' .. verb .. ': ' .. count .. ' furrow(s).')
    return count > 0
end

-- Waits wait_seconds, logging a reminder as the remaining time passes
-- each reminder_intervals entry (descending). Returns state.running.
local function wait_with_reminders(wait_seconds, reminder_intervals, context_label)
    local elapsed = 0
    local next_reminder_index = 1
    local poll_interval = 2 -- seconds - keeps //gh stop/abort responsive during a long wait

    while elapsed < wait_seconds and state.running do
        coroutine.sleep(poll_interval)
        elapsed = elapsed + poll_interval
        local remaining = wait_seconds - elapsed

        if next_reminder_index <= #reminder_intervals and
           remaining <= reminder_intervals[next_reminder_index] then
            local remaining_minutes = math.floor(remaining / 60)
            log('Reminder: Harvest will begin in ' .. remaining_minutes .. ' minutes ' .. context_label .. '. Use //gh stop to cancel.')
            next_reminder_index = next_reminder_index + 1
        end
    end

    return state.running
end

-- One pass over every active furrow, taking the next step for each in
-- the same menu (handle_furrow_for_start): harvest + replant when ready,
-- plant when empty, fertilize right after planting when use_fertilizer is on.
-- Used by //gh furrowloop (main_loop) and //gh furrow / full. Returns
-- true if anything was harvested. Selling is separate (sell_junk_to_moogle).
-- True when this furrow pass may harvest: forced, or a furrow (only_number
-- = just that one) is recorded ready or has no usable data.
-- Furrow timing as a group (v2.10.0), from recorded data only:
--   needs_visit - a furrow is empty / fertilized_empty / has no usable data
--   eta         - when the LAST unlocked furrow is ready (the soonest one's
--                 time instead when they are more than harvest_time apart,
--                 e.g. a slow multi-harvest seed next to a normal one)
--   latest      - the latest ready time when the group is in sync, else nil
-- One login at eta harvests every furrow, so they stay on the same timing.
-- (One table for the v2.10.0 furrow-sync helpers: the main chunk is at
-- Lua's 200-local limit.)
local FURROW_SYNC = {}

-- Seed error (v2.17.0): the seed wasn't in main inventory or any other
-- bag. seed_error() = the saved text, or nil when there is none.
function FURROW_SYNC.seed_error()
    local e = saved_status.furrow_seed_error
    return (e and e ~= '') and e or nil
end

function FURROW_SYNC.set_seed_error(seed_name)
    saved_status.furrow_seed_error = 'No ' .. tostring(seed_name) .. ' in any bag'
    saved_status.furrow_seed_error_at = os.date('%Y-%m-%d %H:%M:%S')
    save_status()
    error_log('SEED ERROR: no ' .. tostring(seed_name) .. ' in inventory or any other bag - furrows on this character are skipped by //gh full and MuleLogger until you restock and run //ml furrow recheck (or //gh furrow recheck here).')
end

-- quiet = no chat line (a successful plant clears it by itself).
function FURROW_SYNC.clear_seed_error(quiet)
    if not FURROW_SYNC.seed_error() then
        if not quiet then log('Furrows: no seed error recorded for this character.') end
        return false
    end
    saved_status.furrow_seed_error = ''
    saved_status.furrow_seed_error_at = ''
    save_status()
    log('Furrows: seed error cleared - furrows will be worked again.')
    return true
end

function FURROW_SYNC.group_timing()
    local needs_visit, earliest, latest = false, nil, nil
    for _, furrow in ipairs(get_active_furrows()) do
        local inferred = infer_furrow_state(furrow.number)
        if inferred == nil or inferred == 'empty' or inferred == 'fertilized_empty' then
            needs_visit = true
        else
            local key = 'furrow_' .. furrow.number .. '_'
            local ready_at = tonumber(saved_status[key .. 'harvest_epoch']) or 0
            if ready_at <= 0 then
                ready_at = (tonumber(saved_status[key .. 'checked_epoch']) or 0) +
                    eff(inferred == 'growing_fertilized' and 'fertilize_wait_time' or 'harvest_time')
            end
            if not earliest or ready_at < earliest then earliest = ready_at end
            if not latest or ready_at > latest then latest = ready_at end
        end
    end
    if latest and earliest and latest - earliest > eff('harvest_time') then
        return needs_visit, earliest, nil
    end
    return needs_visit, latest, latest
end

-- furrow_sync_hold: while another unlocked furrow is still growing (group
-- in sync), returns the time it is ready - ready furrows wait until then.
-- nil = no hold (off, force, a single-furrow command, or nothing growing).
function FURROW_SYNC.hold_epoch(force, only_number)
    if force or only_number or not config.furrow_sync_hold then
        return nil
    end
    local _, _, latest = FURROW_SYNC.group_timing()
    if latest and latest > os.time() then
        return latest
    end
    return nil
end

local function furrow_harvest_expected(force, only_number)
    for _, furrow in ipairs(get_active_furrows()) do
        if not only_number or furrow.number == only_number then
            local inferred = infer_furrow_state(furrow.number)
            if force or inferred == nil or inferred == 'ready' then
                return true
            end
        end
    end
    return false
end

local function run_single_furrow_pass(seed_name, fertilizer_name, force, only_number)
    -- only_number: just that furrow (//gh furrow inspect 2).
    -- Assistants set to the furrows go in place before any harvest
    -- (skipped when this command already checked them).
    if furrow_harvest_expected(force, only_number) then
        ASSIST.before_harvest('furrow')
        if not state.running then return false end
    end
    log('Checking each furrow and taking the next step for it...')
    local any_harvested = false
    -- Worked out once, before anything is replanted this pass.
    local hold_epoch = FURROW_SYNC.hold_epoch(force, only_number)
    local held, no_retry = {}, {}

    local function do_furrow(furrow)
        -- Furrows 2/3 are usually reachable from furrow 1's spot.
        local d = distance_to_id(furrow.id)
        if d and d > config.interact_distance then
            approach_furrow(furrow.number)
        end
        -- Inventory full mid-harvest: sell, walk back, redo this furrow.
        for attempt = 1, config.inventory_full_max_restarts + 1 do
            state.inventory_full_hit = false
            if handle_furrow_for_start(furrow, seed_name, fertilizer_name, force) then
                any_harvested = true
            end
            state.furrow_retry_after_full = nil
            if not state.inventory_full_hit or not state.running then
                break
            end
            state.inventory_full_hit = false
            if attempt > config.inventory_full_max_restarts or not config.sell_junk_enabled or not is_module_enabled('sell') then
                error_log(furrow.name .. ': inventory still full - skipping this furrow for now (not marked harvested).')
                no_retry[furrow.number] = true
                break
            end
            log(furrow.name .. ': inventory full - selling junk, then coming back to harvest it...')
            sell_junk_to_moogle()
            if not state.running then break end
            approach_furrow(furrow.number)
            -- The first Enter after selling can hand over the rest of the
            -- crop straight away (harvest_furrow counts that as done).
            state.furrow_retry_after_full = furrow.number
        end
        state.furrow_retry_after_full = nil
        coroutine.sleep(0.3)
    end

    for _, furrow in ipairs(get_active_furrows()) do
        if not state.running then break end
        if not only_number or furrow.number == only_number then
            if hold_epoch and infer_furrow_state(furrow.number) == 'ready' then
                held[furrow.number] = true
                log(furrow.name .. ': ready, but held until the other furrow(s) are ready at ' ..
                    format_short_datetime(os.date('%Y-%m-%d %H:%M:%S', hold_epoch)) ..
                    ' so all of them are harvested together (furrow_sync_hold).')
            else
                do_furrow(furrow)
            end
        end
    end

    -- One more try right away for a furrow that didn't get done (no reply,
    -- unreadable text, planting failed): leaving it for a later login is
    -- what put it on a different timing from the others.
    if config.furrow_retry_missed and state.running then
        local seed_count = get_item_count(seed_name or eff('seed')) or 0
        for _, furrow in ipairs(get_active_furrows()) do
            if not state.running then break end
            if (not only_number or furrow.number == only_number) and not held[furrow.number] and not no_retry[furrow.number] then
                local inferred = infer_furrow_state(furrow.number)
                if inferred == nil or inferred == 'ready' or
                    ((inferred == 'empty' or inferred == 'fertilized_empty') and seed_count > 0) then
                    log(furrow.name .. ': still "' .. (inferred or 'unknown') ..
                        '" after its turn - one more try now so it stays on the same timing as the other furrows.', 167)
                    coroutine.sleep(config.furrow_detect_retry_wait)
                    clear_cursor_state()
                    windower.send_command('target clear')
                    coroutine.sleep(0.5)
                    do_furrow(furrow)
                end
            end
        end
    end
    return any_harvested
end

local function main_loop(seed_name, fertilizer_name, force)
    log('Starting automated gardening cycle')
    state.start_time = os.time()
    -- state.available_furrows was set by the furrowloop command and carries
    -- over across the wait/recurse.
    while state.running do
        run_single_furrow_pass(seed_name, fertilizer_name, force)
        if not state.running then return end
        local fert = eff('use_fertilizer')
        local wait_time = eff(fert and 'fertilize_wait_time' or 'harvest_time')
        local reminders = eff(fert and 'fertilize_reminder_intervals' or 'reminder_intervals')
        local context_label = fert and 'after fertilizing' or 'after planting'
        if fert then state.fertilize_time = os.time() end
        -- Wait the full growth time before the next pass.
        log('Waiting ' .. math.floor(wait_time / 60) .. ' minutes ' .. context_label .. ' before the next check')
        if not wait_with_reminders(wait_time, reminders, context_label) then
            log('Cycle cancelled by user')
            return
        end
        ASSIST.begin_run()  -- the next cycle checks the furrow assistants again
        log('Full cycle completed!')
        coroutine.sleep(5)
    end
end

-- //gh furrowstatus
local function show_status()
    if state.running then
        log('Status: RUNNING')
        log('Current action: ' .. (state.current_action or 'waiting'))
        if state.start_time then
            local elapsed = os.time() - state.start_time
            log('Total elapsed time: ' .. math.floor(elapsed / 60) .. ' minutes')
        end
        if state.fertilize_time then
            local fertilize_elapsed = os.time() - state.fertilize_time
            log('Time since fertilizing: ' .. math.floor(fertilize_elapsed / 60) .. ' minutes')
        end
    else
        log('Status: STOPPED')
    end

    do
        local hours = eff('harvest_time') / 3600
        local hours_display = (hours == math.floor(hours)) and tostring(math.floor(hours)) or string.format('%.1f', hours)
        local active_line = 'Active - seed: ' .. eff('seed') .. '  fertilizer: ' .. eff('fertilizer') .. ' (' .. (eff('use_fertilizer') and 'ON' or 'OFF') .. ')  growth: ' .. hours_display .. 'h'
        local overridden = get_active_override_fields()
        if #overridden > 0 then
            active_line = active_line .. '  [override: ' .. table.concat(overridden, ', ') .. ']'
        end
        log(active_line)
    end

    local furrow_names = {'Garden Furrow', 'Garden Furrow #2', 'Garden Furrow #3'}
    for i, was_found in ipairs(state.furrows_found) do
        log('  ' .. (furrow_names[i] or ('Furrow ' .. i)) .. ': ' .. (was_found and 'found' or 'not found / not yet checked'))
    end
    
    log('Last known status (from //gh furrowinspect, saved per character):')
    for i, furrow_name in ipairs(furrow_names) do
        local saved_state = saved_status['furrow_' .. i .. '_state']
        local checked_at = saved_status['furrow_' .. i .. '_checked_at']
        if checked_at and checked_at ~= '' then
            log('  ' .. furrow_name .. ': ' .. saved_state .. ' (checked ' .. checked_at .. ')')
        else
            log('  ' .. furrow_name .. ': ' .. saved_state .. ' (never inspected)')
        end
    end

    if saved_status.last_seed_checked_at and saved_status.last_seed_checked_at ~= '' then
        log('Last seed count: ' .. saved_status.last_seed_name .. ' x' .. saved_status.last_seed_count .. ' (checked ' .. saved_status.last_seed_checked_at .. ')')
    else
        log('Last seed count: not checked yet (runs on every //gh furrowduecheck)')
    end
end

-- //gh status: one line per module, from saved data only (instant).
local function show_garden_status()
    sync_module_status_flags()
    state.storage.record()
    local last_full = (saved_status.last_full_pass_at ~= '') and saved_status.last_full_pass_at or 'never'
    log('Mog Garden status (last full pass: ' .. last_full .. '):')

    if FURROW_SYNC.seed_error() then
        error_log('Furrows: SEED ERROR - ' .. FURROW_SYNC.seed_error() .. ' (since ' .. saved_status.furrow_seed_error_at .. ') - //gh furrow recheck clears it.')
    end
    -- Furrows: one compact line each (describe_furrow_status_line).
    for i = 1, 3 do
        local saved_state = saved_status['furrow_' .. i .. '_state']
        if saved_state == 'not_found' then
            log('Furrow #' .. i .. ': not found')
        elseif saved_state == 'growing_unfertilized' or saved_state == 'growing_fertilized' or saved_state == 'ready' then
            log(describe_furrow_status_line(i, saved_state))
        elseif saved_state == 'fertilized_empty' then
            local fert = saved_status['furrow_' .. i .. '_fertilizer']
            log('Furrow #' .. i .. ': no seed, fertilized with ' .. ((fert and fert ~= '') and fert or 'fertilizer') ..
                ' - needs planting (rank ' .. (saved_status['furrow_' .. i .. '_rank'] or 0) .. ')')
        else
            local rank = saved_status['furrow_' .. i .. '_rank']
            log('Furrow #' .. i .. ': rank ' .. (rank or 0) .. ', ' .. (saved_state or 'unknown'))
        end
    end

    -- Module rows, printed with the values lined up in one column.
    local rows = {}

    local function node_row(label, prefix)
        if not is_module_enabled(prefix) then
            table.insert(rows, {label = label, value = 'skipped per character config'})
            return
        end

        local st = node_status(prefix)
        local rank = tonumber(saved_status[prefix .. '_last_rank']) or 0
        local rank_display = (rank > 0) and (' (rank ' .. rank .. ')') or ''
        local text = (st == 'done' and 'done today') or (st == 'unknown' and 'UNKNOWN') or 'NOT done today'
        -- Node fertilizer (vein/pond/grove/net).
        local fstate, fert = node_fert_state(prefix)
        local fert_display = ''
        if fstate == 'used' then
            fert_display = ', fertilized with ' .. tostring(saved_status[prefix .. '_fertilizer'])
        elseif fstate then
            fert_display = ', ' .. fert .. ({due = ' due now (next //gh full)', waiting = ' after harvest',
                none = ' - none in inventory', gave_up = ' - failed today', bad_name = ' - not an item name'})[fstate]
        end
        table.insert(rows, {label = label, value = text .. rank_display .. fert_display})
    end

    node_row('Mineral Vein', 'vein')
    node_row('Pond Dredger', 'pond')
    node_row('Arboreal Grove', 'grove')
    node_row('Flotsam', 'flotsam')
    node_row('Coastal Fishing Net', 'net')
    do
        local at = saved_status.crystals_last_harvested_at
        local crystals_text
        if not is_module_enabled('crystals') then
            crystals_text = 'skipped per character config'
        elseif saved_status.crystals_missing == true or saved_status.crystals_missing == 'true' then
            crystals_text = 'Ephemeral Moogle Missing'
        else
            crystals_text = (at and at ~= '') and ('last traded ' .. format_short_datetime(at)) or 'never traded'
        end
        table.insert(rows, {label = 'Crystals', value = crystals_text})
        do
            -- Shining Stars (v2.25.0): last count the GPS crystal line showed.
            local stars = tonumber(saved_status.shining_stars) or -1
            local seen = saved_status.shining_stars_at
            table.insert(rows, {label = 'Shining Stars', value = (stars < 0)
                and 'not seen yet (GPS crystal line on the first garden visit of the day)'
                or (math.floor(stars) .. ((seen and seen ~= '') and (' (seen ' .. format_short_datetime(seen) .. ')') or ''))})
        end
        do
            -- Storage bag size (v2.26.0).
            local slots = tonumber(saved_status.storage_slots) or -1
            table.insert(rows, {label = 'Storage', value = (slots < 0) and 'not read yet'
                or (math.floor(slots) .. ' of ' .. state.storage.MAX_SLOTS .. ' slots')})
        end
        do
            -- Kitron Macarons (v2.28.0), all item bags.
            local km = tonumber(saved_status.kitron_macarons) or -1
            table.insert(rows, {label = 'Kitron Macarons', value = (km < 0) and 'not counted yet' or tostring(math.floor(km))})
        end
        -- Ephemeral Moogle stock (v2.29.0).
        table.insert(rows, {label = 'Ephemeral Moogle', value = state.eph and state.eph.status_text() or 'crystals.lua not loaded'})
        table.insert(rows, {label = 'Books', value = is_module_enabled('books') and BOOKS.status_text() or 'skipped per character config'})
        table.insert(rows, {label = 'RoE / Unity', value = ROE.status_text() or 'Set_RoE.lua not loaded'})
        for _, row in ipairs(ASSIST.status_rows() or {}) do
            table.insert(rows, row)
        end
        for _, row in ipairs(ASSIST.emp.status_rows() or {}) do
            table.insert(rows, row)
        end
        local inv_data, inv_err = INV.load()
        local me = INV.character_label()
        local mail = inv_data and INV.pending_mail_count(inv_data, me) or 0
        table.insert(rows, {label = 'Mail in Inbox', value = not inv_data and ('unknown (' .. tostring(inv_err) .. ')')
            or (mail > 0 and ('Y (' .. mail .. ' stack' .. (mail == 1 and '' or 's') .. ' tracked)')) or 'N'})
        local code = INV.status_code(inv_data, me)
        table.insert(rows, {label = 'Inventory', value = ({D = 'last inv steps OK', U = 'never run', S = 'skipped (skip_characters)'})[code]
            or ('ERROR - ' .. tostring(INV.error_text(inv_data, me)))})
    end

    local max_label_len = 0
    for _, row in ipairs(rows) do
        max_label_len = math.max(max_label_len, #row.label + 1) -- +1 for the trailing colon
    end

    for _, row in ipairs(rows) do
        local label_with_colon = row.label .. ':'
        local padding = string.rep(' ', max_label_len - #label_with_colon + 2)
        log('  ' .. label_with_colon .. padding .. row.value)
    end
end


-- Classifies a furrow from its inspect text:
--   "...devoid of both seeds and fertilizer."          -> empty
--   "...has a <seed> planted, but is devoid of fertilizer." -> growing_unfertilized
--   "...is using a <fertilizer> as fertilizer, but is devoid of seeds."
--                                                      -> fertilized_empty
--   "...is using a <fertilizer> as fertilizer."        -> growing_fertilized
--   "Your <seed> has matured!" / "ready to harvest"    -> ready
-- 'ready' is checked first (a matured furrow also has the fertilizer line).
local function classify_furrow_text(lines)
    for _, line in ipairs(lines) do
        if line:find('has matured', 1, true) or line:find('ready to harvest', 1, true) then
            return 'ready'
        end
    end
    for _, line in ipairs(lines) do
        if line:find('devoid of both seeds and fertilizer', 1, true) then
            return 'empty'
        elseif line:find('devoid of seeds', 1, true) then
            return 'fertilized_empty'
        elseif line:find('is using', 1, true) and line:find('as fertilizer', 1, true) then
            return 'growing_fertilized'
        elseif line:find('devoid of fertilizer', 1, true) then
            return 'growing_unfertilized'
        end
    end
    return 'unknown'
end

-- //gh furrowinspect key aliases and per-state presets. Escape doesn't
-- close these menus; an extra Enter on a ready furrow can harvest it, so
-- each preset is only safe for its own state.
local KEY_ALIASES = {
    e = 'enter', enter = 'enter',
    d = 'down', down = 'down',
    u = 'up', up = 'up',
    l = 'left', left = 'left',
    r = 'right', right = 'right',
    x = 'escape', escape = 'escape', esc = 'escape'
}

local FURROW_SEQUENCES = {
    empty = {'enter', 'enter', 'down', 'enter'},
    planted = {'enter', 'enter', 'enter', 'down', 'down', 'enter'},
    -- Multi-harvest seed (extra "should sprout about N more times." line).
    sprouting = {'enter', 'enter', 'enter', 'enter', 'right', 'enter'},
    -- Ready multi-harvest seed: rank, "has matured!", sprout line, menu
    -- ("Harvest crop." highlighted), Down, Enter. Down + Enter is a guess
    -- (same as a normal ready furrow) - not seen live yet.
    sprouting_ready = {'enter', 'enter', 'enter', 'enter', 'down', 'enter'},
    ready = {'enter', 'enter', 'enter', 'down', 'enter'}
}

-- A preset name or a comma list of keys ("e,e,d,e"). nil = none given
-- (the command then picks the preset from the recorded state).
local function parse_sequence(arg)
    if not arg or arg == '' then
        return nil
    end
    
    local preset = FURROW_SEQUENCES[arg:lower()]
    if preset then
        return preset
    end
    
    local steps = {}
    for token in arg:gmatch('[^,]+') do
        local key = KEY_ALIASES[token:lower()]
        if not key then
            return nil, 'Unknown key "' .. token .. '" - use enter/e, down/d, up/u, right/r, left/l, escape/x, or a preset (empty, planted, sprouting, ready, sprouting_ready)'
        end
        table.insert(steps, key)
    end
    return steps
end

-- Steps list -> "enter, down, ..." (steps can be {key, wait = ...} tables).
local function describe_sequence(steps)
    local names = {}
    for i, step in ipairs(steps) do
        names[i] = (type(step) == 'table') and step[1] or step
    end
    return table.concat(names, ', ')
end

-- Normalizes a line for duplicate checks: strips Windower colour codes
-- (\30 + 1 byte, \31 + 3 bytes), control bytes, "[HH:MM:SS]" stamps and
-- surrounding spaces.
local function strip_timestamp_prefix(line)
    local no_color = line:gsub('.', ''):gsub('...', ''):gsub('.', '')
    local no_control = no_color:gsub('%c', '')
    local no_timestamp = no_control:gsub('%[%d%d:%d%d:%d%d%]%s*', '')
    return no_timestamp:match('^%s*(.-)%s*$')
end

-- Prints captured lines, skipping repeats (the client sometimes re-fires
-- a line with a timestamp added).
local function print_captured_lines(printer, indent, lines)
    local seen = {}
    for _, line in ipairs(lines) do
        local normalized = strip_timestamp_prefix(line)
        if not seen[normalized] then
            printer(indent .. line)
            seen[normalized] = true
        end
    end
end

-- Presses each key in steps and returns the captured lines. A step is a
-- key name or {key, wait = true/false, pre_wait = s}. By default only
-- 'enter' waits for new text (up to max_wait_per_press, then until
-- quiet for text_settle_seconds); other keys - and {'enter', wait =
-- false} - just pause CURSOR_SETTLE_SECONDS so the client registers the
-- press before the next key. {key, if_text = 'phrase'} is only pressed
-- if a line captured so far in this sequence contains phrase (e.g. the
-- extra Enter after a multi-harvest seed's "should sprout about" line).
-- "Target out of range" on the first key walks closer and restarts the
-- sequence.

local function run_key_sequence(steps, max_wait_per_press)
    local range_target = current_interaction_target()
    local range_attempt = 0
    state.out_of_range_failed = false

    while true do
    state.captured_lines = {}
    state.capturing_text = true
    local out_of_range_step = nil

    -- Distinct lines captured so far. A repeat of a line already seen in
    -- this sequence (the client re-fires lines with a [HH:MM:SS] stamp,
    -- sometimes a moment later) is not a reply: counting it ended an
    -- Enter's wait before the real reply ("has matured!") came in.
    local seen_text, scanned, distinct = {}, 0, 0
    local function distinct_count()
        for idx = scanned + 1, #state.captured_lines do
            local norm = strip_timestamp_prefix(state.captured_lines[idx])
            if norm ~= '' and not seen_text[norm] then
                seen_text[norm] = true
                distinct = distinct + 1
            end
        end
        scanned = #state.captured_lines
        return distinct
    end

    for i, step in ipairs(steps) do
        if not state.running then break end

        local key, expect_text, pre_wait, if_text
        if type(step) == 'table' then
            key = step[1]
            expect_text = step.wait
            pre_wait = step.pre_wait
            if_text = step.if_text
        else
            key = step
        end

        local skip_step = if_text and not lines_contain(state.captured_lines, if_text)
        if skip_step then
            debug_log('  Step ' .. i .. ' (' .. key .. ') skipped - no "' .. if_text .. '" text')
        else
            if expect_text == nil then
                expect_text = (key == 'enter')
            end

            if pre_wait and pre_wait > 0 then
                coroutine.sleep(pre_wait)
            end

            local lines_before = #state.captured_lines
            local distinct_before = distinct_count()
        
            windower.send_command('setkey ' .. key .. ' down')
            coroutine.sleep(0.1)
            windower.send_command('setkey ' .. key .. ' up')
        
            if expect_text then
                local waited = 0
                while distinct_count() == distinct_before and waited < max_wait_per_press and state.running do
                    coroutine.sleep(0.2)
                    waited = waited + 0.2
                end
            
                if distinct_count() == distinct_before then
                    debug_log('No new text within ' .. max_wait_per_press .. 's of "' .. key .. '" (step ' .. i .. ')')
                else
                    -- A reply can come in several chunks: wait until quiet.
                    local quiet = 0
                    local seen = distinct_count()
                    while quiet < config.text_settle_seconds and waited < max_wait_per_press and state.running do
                        coroutine.sleep(0.2)
                        waited = waited + 0.2
                        if distinct_count() > seen then
                            seen = distinct_count()
                            quiet = 0
                        else
                            quiet = quiet + 0.2
                        end
                    end
                end
            else
                coroutine.sleep(CURSOR_SETTLE_SECONDS)
            end

            if lines_contain(state.captured_lines, config.out_of_range_phrases, lines_before + 1) then
                out_of_range_step = i
                break
            end
        end
    end

    state.capturing_text = false

    if not out_of_range_step or not state.running then
        break
    end
    if out_of_range_step ~= 1 and not lines_all_out_of_range(state.captured_lines) then
        out_of_range_give_up(range_target, 'partway through a menu, after the game had already responded - not retrying.')
        break
    end
    if range_attempt >= config.out_of_range_max_retries then
        out_of_range_give_up(range_target, 'still refused after ' .. range_attempt .. ' walk(s) closer - giving up on it for now.')
        break
    end
    range_attempt = range_attempt + 1
    if not walk_closer_after_out_of_range(range_target, range_attempt) then
        state.out_of_range_failed = true
        break
    end
    end

    return state.captured_lines
end

-- Backs out of a detected furrow's menu (EXIT_SEQUENCES). Growing
-- furrows: normal seed -> Enter opens the menu, Down, Down, Enter.
-- Multi-harvest seed (e.g. arborfruit): that Enter shows "You also
-- conclude that the seed you planted should sprout about N more times."
-- instead, so Enter once more to open "What will you do?" (Inspect the
-- garden. / Absolutely nothing.), then Right, Enter. Ready furrows: normal
-- seed -> Enter opens the menu, Down, Enter; multi-harvest seed -> the
-- sprout line first, Enter opens the menu ("Harvest crop."), Down, Enter
-- (the Down is a guess - not seen live yet). Returns the lines captured
-- by the exit (can hold the sprout line).
local function run_exit_sequence(state_name, max_wait_per_press)
    local growing = (state_name == 'growing_unfertilized' or state_name == 'growing_fertilized')
    if not growing and state_name ~= 'ready' then
        return run_key_sequence(EXIT_SEQUENCES[state_name], max_wait_per_press)
    end
    local lines = concat_lines(run_key_sequence({'enter'}, max_wait_per_press))
    if lines_contain(lines, 'should sprout about') then
        local left = parse_harvests_left(lines)
        local what = left and (left .. ' harvest' .. (left == 1 and '' or 's') .. ' left') or 'harvests left not read'
        if growing then
            debug_log('  Multi-harvest seed (' .. what .. ') - Enter, Right, Enter')
            run_key_sequence({{'enter', wait = false}, {'right', pre_wait = config.sprout_menu_settle_seconds}, {'enter', wait = false}}, max_wait_per_press)
        else
            debug_log('  Multi-harvest seed, ready (' .. what .. ') - Enter, Down, Enter')
            run_key_sequence({{'enter', wait = false}, {'down', pre_wait = config.sprout_menu_settle_seconds}, {'enter', wait = false}}, max_wait_per_press)
        end
        return lines
    end
    if growing then
        run_key_sequence({{'down', pre_wait = 0.4}, 'down', {'enter', wait = false}}, max_wait_per_press)
    else
        run_key_sequence({{'down', pre_wait = 0.4}, {'enter', wait = false}}, max_wait_per_press)
    end
    return lines
end

-- A planted furrow answers the inspect keys (Enter, Enter) in two
-- messages: the rank line ("...has a <seed> planted..."), then "has
-- matured!" or "Your agrarian experience tells you ... in about N
-- minutes" (or a multi-harvest seed's sprout line).
do
local FURROW_SECOND_LINE_PHRASES = {'has matured', 'ready to harvest', 'grarian experience', 'should sprout about'}

local function furrow_text_incomplete(lines)
    if lines_contain(lines, FURROW_SECOND_LINE_PHRASES) then
        return false
    end
    for _, line in ipairs(lines) do
        if line:find('rank', 1, true) and line:find('planted', 1, true) then
            return true
        end
    end
    return false
end

-- DETECT_SEQUENCE on the targeted furrow, safe for lag (v2.10.0). Returns
-- lines, state (classify_furrow_text; 'unknown' when it can't be sure).
--  * Rank line but no second message: listen furrow_detect_second_line_wait
--    longer, then press Enter once more. Before, this read a READY furrow
--    as growing; its growing exit keys (Enter, Down, Down, Enter) then left
--    the harvest prompt open, the NEXT furrow's first Enter harvested it,
--    and that next furrow was never touched ("could not be classified") -
--    so it was harvested a login later and drifted off the others.
--  * No text at all (still busy with the last furrow's planting, or just
--    logged in): wait furrow_detect_retry_wait, target it again, retry
--    (furrow_detect_no_text_retries).
function FURROW_SYNC.detect(furrow, max_wait_per_press)
    local name = furrow and furrow.name or 'Furrow'
    local retries = config.furrow_detect_no_text_retries or 0
    local lines = {}
    for attempt = 1, retries + 1 do
        lines = run_key_sequence(DETECT_SEQUENCE, max_wait_per_press)
        if #lines > 0 or state.out_of_range_failed or not state.running or not furrow or attempt > retries then
            break
        end
        log(name .. ': no reply to the inspect keys - waiting ' .. config.furrow_detect_retry_wait .. 's, then trying it again...', 167)
        coroutine.sleep(config.furrow_detect_retry_wait)
        if not find_furrow(furrow.name, furrow.number, true) then
            break
        end
        coroutine.sleep(1)
    end
    if state.running and not state.out_of_range_failed and furrow_text_incomplete(lines) then
        debug_log(name .. ': rank line only so far - listening ' .. config.furrow_detect_second_line_wait .. 's more for the second line...')
        local _, more = capture_until(config.furrow_detect_second_line_wait, FURROW_SECOND_LINE_PHRASES)
        lines = concat_lines(lines, more)
        if furrow_text_incomplete(lines) and state.running then
            log(name .. ': the game only showed the rank line - pressing Enter once more for the second line (lag).', 167)
            lines = concat_lines(lines, run_key_sequence({'enter'}, max_wait_per_press))
        end
        if furrow_text_incomplete(lines) then
            return lines, 'unknown'
        end
    end
    return lines, classify_furrow_text(lines)
end
end

-- Near the Net, side-step (perpendicular to the Net -> moogle direction)
-- before walking to the Green Thumb Moogle so the walk doesn't clip the
-- tables. Stops after net_to_moogle_strafe_yalms, when blocked, or on
-- timeout.
local function sidestep_from_net_before_moogle()
    if not config.net_to_moogle_strafe_enabled then return end
    local d_net = distance_to_id(NET.id)
    if not d_net or d_net > (config.net_to_moogle_strafe_trigger_yalms or 8) then return end

    local px, py = player_xy()
    if not px then return end
    local mx, my
    local moogle = windower.ffxi.get_mob_by_id(config.sell_junk_moogle_id)
    if moogle and moogle.x and moogle.y then
        mx, my = moogle.x, moogle.y
    elseif ENTITIES[GREEN_THUMB_MOOGLE.key] then
        mx, my = ENTITIES[GREEN_THUMB_MOOGLE.key].x, ENTITIES[GREEN_THUMB_MOOGLE.key].y
    end
    if not mx or not my then return end

    local dx, dy = mx - px, my - py
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.1 then return end
    dx, dy = dx / len, dy / len
    -- Left of the travel direction = rotate 90 degrees counter-clockwise.
    local side = (config.net_to_moogle_strafe_side == 'right') and -1 or 1
    local sx, sy = -dy * side, dx * side

    local want = config.net_to_moogle_strafe_yalms or 10
    local timeout = config.net_to_moogle_strafe_timeout_seconds or 5
    log('Side-stepping ' .. want .. ' yalms ' .. (side == 1 and 'left' or 'right') .. ' from the ' .. NET.name .. ' before walking to the ' .. GREEN_THUMB_MOOGLE.name .. '...')

    local waited, since_check, moved, moved_at_check = 0, 0, 0, 0
    while state.running and waited < timeout do
        local cx, cy = player_xy()
        if not cx then break end
        moved = math.sqrt((cx - px) ^ 2 + (cy - py) ^ 2)
        if moved >= want then break end
        windower.ffxi.run(sx, sy)
        coroutine.sleep(config.xy_poll_interval)
        waited = waited + config.xy_poll_interval
        since_check = since_check + config.xy_poll_interval
        if since_check >= 1.0 then
            since_check = 0
            if (moved - moved_at_check) < (config.xy_stuck_epsilon_yalms or 0.3) then
                debug_log('Net side-step: blocked after ' .. string.format('%.1f', moved) .. ' yalms - carrying on to the moogle from here')
                break
            end
            moved_at_check = moved
        end
    end
    windower.ffxi.run(false)
    coroutine.sleep(0.2)
    debug_log('Net side-step done: moved ' .. string.format('%.1f', moved) .. ' yalms')
end

local function walk_to_moogle_with_waypoint_fallback()
    sidestep_from_net_before_moogle()
    if not state.running then return false end
    -- X/Y first, then the tighter Lock-On distance the moogle's menu needs;
    -- if the direct walk fails, detour via MOOGLE_WAYPOINT and try again.
    if config.navigation_mode == 'xy' and ENTITIES[GREEN_THUMB_MOOGLE.key] then
        if navigate_to_entity(GREEN_THUMB_MOOGLE.key, config.sell_junk_moogle_id, GREEN_THUMB_MOOGLE.name) then
            local d = distance_to_id(config.sell_junk_moogle_id)
            if d and d <= config.interact_distance then
                if find_moogle() then
                    return true
                end
            end
        end
    end

    if walk_to_entity(config.sell_junk_moogle_id, GREEN_THUMB_MOOGLE.name) then
        return true
    end

    debug_log('Could not walk straight to ' .. GREEN_THUMB_MOOGLE.name .. ' - trying the ' .. MOOGLE_WAYPOINT.name .. ' waypoint detour...')

    if not find_entity(MOOGLE_WAYPOINT.id, MOOGLE_WAYPOINT.name) then
        error_log('Moogle waypoint detour: could not find/target ' .. MOOGLE_WAYPOINT.name)
        return false
    end

    if not walk_to_entity(MOOGLE_WAYPOINT.id, MOOGLE_WAYPOINT.name, config.moogle_waypoint_approach_distance) then
        error_log('Moogle waypoint detour: could not walk to ' .. MOOGLE_WAYPOINT.name)
        return false
    end

    if not state.running then
        return false
    end

    if not find_moogle() then
        error_log('Moogle waypoint detour: reached ' .. MOOGLE_WAYPOINT.name .. ' but could not re-target ' .. GREEN_THUMB_MOOGLE.name)
        return false
    end

    return walk_to_entity(config.sell_junk_moogle_id, GREEN_THUMB_MOOGLE.name)
end

-- //gh sell and the full-pass checkpoints: inv.lua works out what to sell
-- from ItemTable.lua (and pulls "save" extras out of the other bags) -
-- nothing to sell = no walk. Otherwise walk to the Green Thumb Moogle,
-- Enter, and on the standard greeting run sell_junk_menu_sequence into the
-- Buy/Sell menu; inv.lua sells once the shop opens. Escape, then inv.lua's
-- drop (action "drop" items). Anything but the greeting (quest text /
-- cutscene) is cleared and retried, up to sell_junk_max_attempts; a
-- cutscene that never clears stops everything. true = sold (or nothing to sell).
sell_junk_to_moogle = function()
    if not config.sell_junk_enabled then
        return false
    end
    if not is_module_enabled('sell') then
        log('Selling is off for this character (sell = false in characters.lua) - not selling.')
        return false
    end
    clear_cursor_state()

    local to_sell, sell_err = INV.sell_prepare()
    if to_sell == nil then
        error_log('Sell: ' .. tostring(sell_err or 'inv.lua is not loaded') .. ' - not selling.')
        return false
    end
    if not state.running then return false end
    if to_sell == 0 then
        log('Sell: nothing to sell in main inventory (ItemTable.lua action "sell" / "save" above min_save) - not visiting the moogle.')
        INV.drop_now()
        return true
    end

    for attempt = 1, config.sell_junk_max_attempts do
        if not state.running then return false end
        if not find_moogle() then
            debug_log('Could not find the moogle on attempt ' .. attempt .. '/' .. config.sell_junk_max_attempts .. ' - retrying')
        else
            walk_to_moogle_with_waypoint_fallback()
            debug_log('Talking to the moogle (attempt ' .. attempt .. '/' .. config.sell_junk_max_attempts .. ')...')
            INV.sell_arm()
            local lines = run_key_sequence({'enter'}, config.sell_junk_max_wait_per_press)

            if lines_contain(lines, config.sell_junk_standard_greeting) then
                log('Got the standard greeting - entering the Buy/Sell menu...')
                run_key_sequence(config.sell_junk_menu_sequence, config.sell_junk_max_wait_per_press)
                local sold_ok, sold_err = INV.sell_at_shop()
                if not sold_ok then
                    error_log('Sell: ' .. tostring(sold_err))
                end
                log('Closing the Buy/Sell menu...')
                press_key('escape')
                INV.drop_now()
                windower.send_command('target clear')
                log('Closed out of the moogle shop.')
                return sold_ok and true or false
            end

            if #lines == 0 then
                debug_log('No text on attempt ' .. attempt .. ' - assuming nothing opened, retrying')
            else
                debug_log('Got something other than the standard greeting (quest reminder/cutscene?) - clearing it before retrying.')
                print_captured_lines(debug_log, '  ', lines)
                for _ = 1, 3 do
                    press_key('escape')
                end
                -- Target still there after Escape = a cutscene.
                if windower.ffxi.get_mob_by_target('t') and not press_until_target_released(config.sell_junk_cutscene_timeout_seconds) then
                    if not state.running then return false end
                    error_log('Still targeting something ' .. config.sell_junk_cutscene_timeout_seconds .. 's after a cutscene/quest-text screen appeared at the moogle - something looks stuck. Stopping all GardenHelper operations. Check the screen by hand.')
                    state.running = false
                    return false
                end
            end
        end
    end

    error_log('Could not get the moogle to the standard shop greeting after ' .. config.sell_junk_max_attempts .. ' attempts - skipping junk sell this pass. Check the screen by hand.')
    return false
end

-- ---- Modules: vein / pond / grove / crystals / flotsam / net ----

-- Walks to the node's X/Y, targets it (name confirmed) and makes sure it
-- is in reach. kind = double-check it on the way (walk_confirmed); nil =
-- no double check (books' dinghy/skipper). true = targeted and reachable.
local function position_at_node(key, entity_id, entity_name, label, kind)
    label = label or entity_name
    if not walk_confirmed(kind, key, entity_id, entity_name, label) then
        return false
    end
    if not state.running then return false end
    if not find_entity(entity_id, entity_name) then
        return false
    end
    if not ensure_in_interact_range(entity_id, label, nil) then
        return false
    end
    if not current_target_is(entity_id, entity_name) then
        return find_entity(entity_id, entity_name)
    end
    return true
end

-- Vein/Grove: highest-rank nodes (two variants per rank, one targetable
-- at a time), harvested until the stop phrase. Pond/Net: one entity, one
-- press cycle, "Obtained:" lines = success.
local NODES = {
    -- rank_pattern: the real garden rank from the game's own line ("This
    -- mineral vein is rank 7."). The entity rank (#1-#4) is only which
    -- of the four objects is showing - several garden ranks share one.
    vein = {label = 'Vein', full = 'Mineral Vein', ranks = VEINS, waits = 'vein_press_waits', stop = 'vein_stop_phrase', rank_pattern = 'mineral vein is rank (%d+)'},
    grove = {label = 'Grove', full = 'Arboreal Grove', ranks = GROVES, waits = 'grove_press_waits', stop = 'grove_done_phrase', rank_pattern = 'grove of trees is rank (%d+)'},
    pond = {label = 'Pond', entity = POND, waits = 'pond_press_waits', done = 'pond_already_done_phrase'},
    net = {label = 'Net', entity = NET, waits = 'net_press_waits', done = 'net_already_done_phrase', extra = 'net_cutscene_extra_wait_seconds'},
}

local function variant_label(v)
    return v.key .. (v.action and (' (' .. v.action .. ')') or '')
end

-- Highest rank with a targetable variant that is still there after the
-- walk_confirmed double check and reachable. A variant that vanishes on
-- the way stops the walk; the next variant / rank down is picked from
-- wherever you are. Returns rank entry, variant.
local function find_highest_ranked(prefix)
    local ranks = NODES[prefix].ranks
    for i = #ranks, 1, -1 do
        for _, v in ipairs(ranks[i].variants) do
            if not state.running then return nil end
            if entity_present(v.id) and find_entity(v.id, v.name) then
                if position_at_node(v.key, v.id, v.name, variant_label(v), prefix) then
                    return ranks[i], v
                end
                debug_log(prefix .. ': ' .. v.key .. ' (rank #' .. ranks[i].rank .. ') targetable but not reachable - trying the next rank down')
            end
        end
    end
    return nil
end

-- Whichever variant at this rank is targetable now (the current one can
-- vanish mid-harvest and the other appear).
local function find_current_variant(rank_entry, current)
    if current and find_entity(current.id, current.name) then
        return current
    end
    for _, candidate in ipairs(rank_entry.variants) do
        if candidate ~= current and find_entity(candidate.id, candidate.name) then
            return candidate
        end
    end
    return nil
end

-- Walks to and targets the node (true = ready to interact).
local function locate_node(prefix)
    local node = NODES[prefix]
    if node.ranks then
        return find_highest_ranked(prefix) ~= nil
    end
    return position_at_node(node.entity.key, node.entity.id, node.entity.name, node.entity.name, prefix)
end

-- /item "<name>" <t> on the current target, with the "Target out of
-- range" walker. Returns the lines and true if still out of range (then
-- no item menu is open - the caller must not press Enter).
local function use_item_on_target(item_name, max_wait)
    local range_target = current_interaction_target()
    local lines = {}
    for attempt = 0, config.out_of_range_max_retries do
        local _
        _, lines = capture_until(max_wait, nil, function() windower.chat.input('/item "' .. item_name .. '" <t>') end)
        coroutine.sleep(0.3)
        if not lines_contain(lines, config.out_of_range_phrases) then
            return lines, false
        end
        if attempt >= config.out_of_range_max_retries then
            out_of_range_give_up(range_target, 'using ' .. item_name .. ' was still refused after ' .. attempt .. ' walk(s) closer.')
            break
        end
        if not walk_closer_after_out_of_range(range_target, attempt + 1) then
            state.out_of_range_failed = true
            break
        end
    end
    return lines, true
end

-- Uses the node's fertilizer (characters.lua <node>_fertilizer) ONLY
-- when node_fert_state says 'due': the node was harvested since today's
-- reset and not fertilized yet today. Before the day's harvest it would
-- be wasted. '/item', then Enter one at a time until the count drops or
-- a done phrase shows up. "There is no need to..." = already fertilized.
-- A failed try counts toward node_fertilize_daily_attempts.
local function fertilize_node_after_harvest(prefix)
    local fstate, fert = node_fert_state(prefix)
    local label = NODES[prefix].label
    if fstate == 'none' then
        log(label .. ': no ' .. fert .. ' in inventory - not fertilized.')
    elseif fstate == 'bad_name' then
        error_log(label .. ': "' .. fert .. '" is not a recognized item name - check ' .. prefix .. '_fertilizer in characters.lua.')
    elseif fstate == 'waiting' then
        debug_log(label .. ': not harvested today - ' .. fert .. ' waits until after the harvest.')
    end
    if fstate ~= 'due' or not state.running or state.inventory_full_hit then
        return false
    end
    local have = get_item_count(fert)
    local today = get_garden_day_string()

    local function finish(result, message)
        clear_cursor_state()
        windower.send_command('target clear')
        if result then
            saved_status[prefix .. '_fertilized_date'] = today
            saved_status[prefix .. '_fertilized_at'] = os.date('%Y-%m-%d %H:%M:%S')
            saved_status[prefix .. '_fertilizer'] = fert
            log(label .. ': ' .. message)
        else
            if saved_status.node_fert_tries_date ~= today then
                saved_status.node_fert_tries_date = today
                saved_status.node_fert_tries = 0
            end
            saved_status.node_fert_tries = (tonumber(saved_status.node_fert_tries) or 0) + 1
            error_log(label .. ': ' .. message .. ' (failed try ' .. saved_status.node_fert_tries .. ' of ' .. config.node_fertilize_daily_attempts .. ' today)')
        end
        save_status()
        return result == 'used'
    end

    clear_cursor_state()
    if not locate_node(prefix) then
        return finish(nil, 'could not reach/target it to use ' .. fert .. ' - not fertilized.')
    end
    log(label .. ': harvested today - using ' .. fert .. ' (have ' .. have .. ').')

    local all_lines, out_of_range = use_item_on_target(fert, 5)
    if out_of_range then
        return finish(nil, '"Target out of range" using ' .. fert .. ' - not fertilized.')
    end
    local function outcome()
        if lines_contain(all_lines, config.item_use_reject_phrase) then return 'already' end
        local now_have = get_item_count(fert)
        if (now_have and now_have < have) or lines_contain(all_lines, config.node_fertilize_done_phrases) then return 'used' end
        return nil
    end
    coroutine.sleep(1)
    local presses = 0
    while not outcome() and presses < config.node_fertilize_max_enters and state.running do
        presses = presses + 1
        for _, l in ipairs(run_key_sequence({'enter'}, config.node_fertilize_enter_wait_seconds)) do
            table.insert(all_lines, l)
        end
        coroutine.sleep(0.5)
    end
    local result = outcome()
    if result == 'used' then
        -- Close the game's confirmation message (it waits for Enter).
        coroutine.sleep(0.5)
        for _ = 1, config.node_fertilize_close_enters do
            if not state.running then break end
            local more = run_key_sequence({'enter'}, config.node_fertilize_close_wait_seconds)
            if #more == 0 then break end
        end
        return finish('used', 'fertilized with ' .. fert .. '.')
    elseif result == 'already' then
        return finish('already', 'game says it is already fertilized - recording as done for today.')
    end
    return finish(nil, 'used ' .. fert .. ' but saw no confirmation and the count did not drop (' .. presses .. ' Enter(s)). Text: ' .. (all_lines[#all_lines] or 'none'))
end

-- Vein/Grove pass: press cycles until the stop phrase, switching between
-- the rank's two variants as they swap. A variant that appears out of
-- reach after harvesting started is walked to with an alert (better X/Y
-- wanted). Inventory full bails out without recording anything; no
-- confirmation at all = UNKNOWN.
local function harvest_ranked(prefix)
    local node = NODES[prefix]
    local rank_entry, variant = find_highest_ranked(prefix)
    if not rank_entry then
        error_log(node.label .. ': could not find/reach any ' .. node.full .. ' from here - not marking done.')
        mark_node_unknown(prefix)
        return false
    end
    log('Highest available ' .. prefix .. ': rank #' .. rank_entry.rank .. '. Harvesting ' .. variant_label(variant) .. '...')

    local stop_phrase = config[node.stop]
    local stopped, any_success = false, false
    local game_rank = nil
    for attempt = 1, config.node_max_attempts do
        if not state.running then return any_success end
        if not current_target_is(variant.id, variant.name) then
            find_entity(variant.id, variant.name)
        end
        local lines = press_enter_cycle(config[node.waits], nil, {stop_phrase, config.harvest_success_phrase})
        if state.inventory_full_hit then
            windower.send_command('target clear')
            return any_success
        end
        any_success = any_success or lines_contain(lines, config.harvest_success_phrase)
        game_rank = game_rank or tonumber(first_match(lines, node.rank_pattern))
        if lines_contain(lines, stop_phrase) then
            stopped = true
            break
        end
        local next_variant = find_current_variant(rank_entry, variant)
        if not next_variant then
            debug_log(prefix .. ': no rank #' .. rank_entry.rank .. ' variant targetable any more - stopping')
            break
        end
        if next_variant ~= variant then
            debug_log(prefix .. ': ' .. variant.key .. ' is gone after attempt ' .. attempt .. ' - switching to ' .. variant_label(next_variant))
        end
        variant = next_variant
        if not ensure_in_interact_range(variant.id, variant.key, variant_label(variant) .. ' (' .. node.full .. ' rank ' .. rank_entry.rank .. ')') then
            error_log(node.label .. ': could not get within reach of ' .. variant.key .. ' - stopping this pass.')
            break
        end
        if not current_target_is(variant.id, variant.name) then
            find_entity(variant.id, variant.name)
        end
    end

    if stopped or any_success then
        -- Real rank from the game's line; not seen = keep the saved rank
        -- (object # only when nothing was ever saved).
        local saved_rank = tonumber(saved_status[prefix .. '_last_rank']) or 0
        local record_rank = game_rank or (saved_rank == 0 and rank_entry.rank or nil)
        if not game_rank then
            debug_log(prefix .. ': no "' .. node.rank_pattern .. '" line seen - garden rank not updated' .. (record_rank and (' (saved object #' .. record_rank .. ')') or ''))
        end
        set_module_done(prefix, true, record_rank)
        log(node.full .. (game_rank and (' rank ' .. game_rank) or '') .. ' harvest complete (object #' .. rank_entry.rank .. ').')
    else
        error_log(node.label .. ': no harvest confirmation seen this pass - marking UNKNOWN (not done), will retry next time.')
        mark_node_unknown(prefix)
    end
    windower.send_command('target clear')
    return any_success
end

-- Pond/Net pass: one press cycle. "Obtained:" lines = harvested, the
-- already-done phrase = done today, neither = UNKNOWN.
local function harvest_simple(prefix)
    local node, e = NODES[prefix], NODES[prefix].entity
    if not position_at_node(e.key, e.id, e.name, e.name, prefix) then
        error_log(node.label .. ': could not reach/target the ' .. e.name .. ' - not marking done.')
        mark_node_unknown(prefix)
        return false
    end
    log('Harvesting ' .. e.name .. '...')
    local done_phrase = config[node.done]
    local lines = press_enter_cycle(config[node.waits], node.extra and config[node.extra], {done_phrase}, true)
    if state.inventory_full_hit then
        windower.send_command('target clear')
        return false
    end
    local already_done = lines_contain(lines, done_phrase)
    local obtained = lines_contain(lines, {config.obtained_phrase, config.harvest_success_phrase})
    if already_done or obtained then
        log(already_done and (node.label .. ': already done for today (confirmed live) - recording as done.') or (e.name .. ' harvest complete.'))
        set_module_done(prefix, true, tonumber(first_match(lines, 'rank (%d+)')))
    else
        error_log(node.label .. ': no "Obtained" or "already done" message seen - marking UNKNOWN (not done), will retry next time.')
        mark_node_unknown(prefix)
    end
    windower.send_command('target clear')
    return obtained and not already_done
end

-- One vein/pond/grove/net pass (force = even if done today), then its
-- fertilizer if due. Returns true if something was harvested.
local function harvest_node(prefix, force)
    local result = false
    if not force and node_done_today(prefix) then
        log(NODES[prefix].label .. ': already harvested today - skipping.')
    else
        -- Assistants set to this node go in place first (assistants.lua).
        ASSIST.before_harvest(prefix)
        if not state.running then return result end
        clear_cursor_state()
        result = (NODES[prefix].ranks and harvest_ranked or harvest_simple)(prefix)
        if not state.running or state.inventory_full_hit then
            return result
        end
    end
    fertilize_node_after_harvest(prefix)
    return result
end

-- Keeps capturing for `seconds` more, appended to lines.
local function flotsam_listen_more(lines, seconds)
    state.captured_lines = {}
    for _, l in ipairs(lines) do table.insert(state.captured_lines, l) end
    state.capturing_text = true
    local waited = 0
    while state.running and waited < seconds do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    state.capturing_text = false
    return state.captured_lines
end

-- Escape, re-target the Flotsam, one Enter, listen
-- flotsam_no_response_seconds. Returns the lines (empty = cleared for
-- today) or nil if it can't be targeted.
local function flotsam_probe()
    press_key('escape')
    if not find_entity(FLOTSAM.id, FLOTSAM.name) then
        return nil
    end
    state.captured_lines = {}
    state.capturing_text = true
    press_key('enter', 0.1)
    local waited = 0.1
    while state.running and waited < config.flotsam_no_response_seconds and #state.captured_lines == 0 do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    coroutine.sleep(0.3)
    state.capturing_text = false
    return state.captured_lines
end

-- Up, Enter on the "Dispose of..." prompt; true once "You dispose of" shows.
local function flotsam_dispose_duplicate()
    coroutine.sleep(config.flotsam_dispose_prompt_wait_seconds)
    state.captured_lines = {}
    state.capturing_text = true
    press_key('up')
    press_key('enter', 0.1)
    local waited = 0.1
    while state.running and waited < config.flotsam_dispose_confirm_seconds
        and not lines_contain(state.captured_lines, config.flotsam_disposed_phrase) do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    state.capturing_text = false
    local ok = lines_contain(state.captured_lines, config.flotsam_disposed_phrase)
    if ok then
        coroutine.sleep(config.flotsam_dispose_settle_seconds)
    end
    return ok
end

-- Flotsam: once harvested it stays targetable but answers nothing, so
-- the first Enter decides - no text = done today. "You cannot obtain"
-- (a Rare/Ex copy held) = discard with Up, Enter. After every round the
-- Flotsam is tried again (campaigns can give double items) until it stops
-- answering, up to flotsam_max_rounds. Not targetable = UNKNOWN.
local function harvest_flotsam(force)
    if not force and node_done_today('flotsam') then
        log('Flotsam: already harvested today - skipping.')
        return false
    end

    clear_cursor_state()

    local _, why = walk_confirmed('flotsam', FLOTSAM.key, FLOTSAM.id, FLOTSAM.name, FLOTSAM.name)
    if not state.running then return false end
    if why then
        error_log('Flotsam: ' .. (why == 'gone' and 'disappeared before it could be used' or 'not there / not targetable') .. ' - marking UNKNOWN (not done).')
        mark_node_unknown('flotsam')
        return false
    end

    if not find_entity(FLOTSAM.id, FLOTSAM.name) then
        error_log('Flotsam: could not target it at all - marking UNKNOWN (not done).')
        mark_node_unknown('flotsam')
        return false
    end
    ensure_in_interact_range(FLOTSAM.id, FLOTSAM.name, nil)
    if not current_target_is(FLOTSAM.id, FLOTSAM.name) then
        find_entity(FLOTSAM.id, FLOTSAM.name)
    end

    log('Harvesting ' .. FLOTSAM.name .. '...')

    local rest = {}
    for i = 2, #config.flotsam_press_waits do
        table.insert(rest, config.flotsam_press_waits[i])
    end
    local first_wait = config.flotsam_press_waits[1] or 3
    local cant = config.flotsam_cant_receive_phrases

    local obtained_any = false   -- at least one item actually kept
    local handled_any = false    -- at least one round finished (kept or discarded)
    local last_rank = nil

    for round = 1, config.flotsam_max_rounds do
        if not state.running then return obtained_any end

        -- First Enter on its own: does it respond at all?
        local first_lines, waited
        if round == 1 then
            local range_target = {id = FLOTSAM.id, name = FLOTSAM.name}
            for range_attempt = 0, config.out_of_range_max_retries do
                state.captured_lines = {}
                state.capturing_text = true
                press_key('enter', 0.1)
                waited = 0.1
                while state.running and waited < config.flotsam_no_response_seconds and #state.captured_lines == 0 do
                    coroutine.sleep(0.2)
                    waited = waited + 0.2
                end
                coroutine.sleep(0.3)
                state.capturing_text = false
                first_lines = state.captured_lines
                if not lines_all_out_of_range(first_lines) or not state.running then
                    break
                end
                if range_attempt >= config.out_of_range_max_retries
                    or not walk_closer_after_out_of_range(range_target, range_attempt + 1) then
                    out_of_range_give_up(range_target, 'Flotsam could not be reached - marking UNKNOWN (not done).')
                    mark_node_unknown('flotsam')
                    windower.send_command('target clear')
                    return false
                end
            end
        else
            log('Flotsam: trying it once more (campaign double items)...')
            first_lines = flotsam_probe()
            waited = config.flotsam_no_response_seconds
            if first_lines == nil then
                -- Can't target it any more = gone for the day.
                log('Flotsam: no longer targetable - cleared for today (recording as done).')
                set_module_done('flotsam', true, last_rank)
                return obtained_any
            end
        end

        if #first_lines == 0 then
            if round == 1 then
                local still_targeted = current_target_is(FLOTSAM.id, FLOTSAM.name)
                log('Flotsam: no response to Enter' .. (still_targeted and '' or ' and the cursor dropped off it') .. ' - already harvested today (recording as done).')
            else
                log('Flotsam: no more items - cleared for today (recording as done).')
            end
            set_module_done('flotsam', true, last_rank)
            windower.send_command('target clear')
            return obtained_any
        end

        -- It answered: finish the first press's wait, then the rest of the cycle.
        if waited < first_wait then
            coroutine.sleep(first_wait - waited)
        end

        local lines = {}
        for _, l in ipairs(first_lines) do table.insert(lines, l) end
        if not lines_contain(first_lines, config.obtained_phrase)
            and not lines_contain(first_lines, config.inventory_full_phrases)
            and not lines_contain(first_lines, cant) and #rest > 0 then
            for _, l in ipairs(press_enter_cycle(rest, nil, cant, true)) do
                table.insert(lines, l)
            end
        elseif lines_contain(first_lines, config.obtained_phrase) then
            state.captured_lines = lines
            state.capturing_text = true
            wait_for_obtained_to_settle()
            state.capturing_text = false
            lines = state.captured_lines
        end

        -- "cannot obtain" also starts the inventory-full message - give its
        -- second line a moment.
        if lines_contain(lines, cant) and not lines_contain(lines, config.inventory_full_phrases) then
            lines = flotsam_listen_more(lines, config.flotsam_cant_receive_settle_seconds)
        end

        if lines_contain(lines, config.inventory_full_phrases) and not state.inventory_full_hit then
            log('Inventory is full - stopping this harvest (not marking it done).', 167)
            state.inventory_full_hit = true
            acknowledge_inventory_full()
        end
        if state.inventory_full_hit then
            windower.send_command('target clear')
            return obtained_any
        end

        local rank = tonumber(first_match(lines, 'rank (%d+)'))
        if rank then last_rank = rank end

        if lines_contain(lines, config.obtained_phrase) or lines_contain(lines, config.harvest_success_phrase) then
            obtained_any = true
            handled_any = true
            log(FLOTSAM.name .. ': item obtained' .. (round > 1 and (' (round ' .. round .. ')') or '') .. '.')
        elseif lines_contain(lines, cant) then
            log('Flotsam: could not be received (already holding one) - discarding the duplicate (Up, Enter).')
            if flotsam_dispose_duplicate() then
                handled_any = true
                log('Flotsam: duplicate discarded.')
            else
                -- No confirmation - the next round shows whether it's still there.
                error_log('Flotsam: no "' .. config.flotsam_disposed_phrase .. '" message after Up, Enter - re-checking.')
            end
        else
            if handled_any then
                error_log('Flotsam: extra round answered but gave no item - recording done for today.')
                print_captured_lines(debug_log, '  ', lines)
                set_module_done('flotsam', true, last_rank)
            else
                error_log('Flotsam: it responded but no "Obtained" message was seen - marking UNKNOWN (not done), will retry next time.')
                print_captured_lines(debug_log, '  ', lines)
                mark_node_unknown('flotsam')
            end
            windower.send_command('target clear')
            return obtained_any
        end
    end

    -- Ran out of rounds while it was still answering.
    if handled_any then
        log('Flotsam: stopped after ' .. config.flotsam_max_rounds .. ' rounds - recording done for today.')
        set_module_done('flotsam', true, last_rank)
    else
        error_log('Flotsam: still "cannot obtain" after ' .. config.flotsam_max_rounds .. ' rounds (discard never confirmed) - marking UNKNOWN (not done).')
        mark_node_unknown('flotsam')
    end
    windower.send_command('target clear')
    return obtained_any
end

-- Does the furrow step need a visit this pass? False only when every
-- active furrow is recorded as still growing (nothing due) - then the
-- walk-over is skipped entirely.
local function furrow_pass_needed(force)
    if force then
        return true
    end
    -- furrow_sync_hold: a ready furrow waiting for a growing one isn't due.
    local hold_epoch = FURROW_SYNC.hold_epoch(force)
    for _, furrow in ipairs(get_active_furrows()) do
        local inferred = infer_furrow_state(furrow.number)
        if inferred == nil or (inferred == 'ready' and not hold_epoch) or inferred == 'empty' or inferred == 'fertilized_empty' then
            return true
        end
        -- v2.19.0: a growing, unfertilized furrow no longer needs a visit -
        -- fertilizer only goes in right after planting.
    end
    return false
end

-- Last completed //gh full/force (top of //gh status).
local function record_full_pass_complete()
    saved_status.last_full_pass_at = os.date('%Y-%m-%d %H:%M:%S')
    saved_status.last_full_pass_epoch = os.time()
    save_status()
end

-- //findall (FindAll's "update") so its offline inventory is current
-- before you log out. Harmless if FindAll isn't loaded.
local function refresh_findall_inventory()
    if not config.refresh_findall_after_pass then
        return
    end
    debug_log('Refreshing FindAll\'s offline inventory database (//findall)...')
    windower.send_command('findall')
    coroutine.sleep(config.findall_wait_seconds)
end

-- Furrows from recorded data (FURROW_SYNC.group_timing): actionable = a furrow
-- is empty / has no usable data, or the LAST unlocked furrow is ready now;
-- eta = when the last one is ready. v2.10.0: was the SOONEST furrow, so
-- MuleLogger logged in for furrow 1 while furrow 2 was still growing and
-- the furrows drifted apart. furrow = false for this character -> nothing
-- is due.
local function furrow_due_info()
    if not is_module_enabled('furrow') or FURROW_SYNC.seed_error() then
        return false, nil
    end
    local needs_visit, eta = FURROW_SYNC.group_timing()
    local actionable = needs_visit or (eta ~= nil and eta <= os.time())
    return actionable, eta
end

-- Nodes whose fertilizer is due right now (see node_fert_state).
local function nodes_fert_due()
    local due = {}
    for _, prefix in ipairs({'vein', 'pond', 'grove', 'net'}) do
        if is_module_enabled(prefix) and node_fert_state(prefix) == 'due' then
            table.insert(due, prefix)
        end
    end
    return due
end

-- Refreshes the snapshot fields saved in settings.xml (for tools that
-- read it, e.g. multi-character rotation scripts): *_disabled, *_done_today, books_auto, the
-- furrow ETA (when the LAST furrow is ready) and node_fert_due_date (today when a node's
-- fertilizer is due). No interaction; called by duecheck, full/force,
-- status and after any command.
sync_module_status_flags = function()
    for _, key in ipairs({'furrow', 'vein', 'pond', 'grove', 'crystals', 'flotsam', 'net', 'books'}) do
        saved_status[key .. '_disabled'] = not is_module_enabled(key)
    end
    saved_status.books_auto = (config.books_in_full == true)
    for _, key in ipairs({'vein', 'pond', 'grove', 'flotsam', 'net'}) do
        saved_status[key .. '_done_today'] = node_done_today(key)
    end
    saved_status.node_fert_due_date = (#nodes_fert_due() > 0) and get_garden_day_string() or ''

    local actionable, earliest = furrow_due_info()
    saved_status.furrow_next_ready_at = actionable and 'READY' or (earliest and os.date('%Y-%m-%d %H:%M:%S', earliest)) or ''
    saved_status.furrow_next_ready_epoch = (not actionable and earliest) or 0
    persist_status()
end

-- Runs fn() only if module_key is on for this character (full/force
-- only - //gh <module> typed by hand always runs).
local function run_module_if_enabled(module_key, label, fn)
    if not is_module_enabled(module_key) then
        log(label .. ': disabled for this character (character_module_overrides) - skipping.')
        return false
    end
    return fn()
end

-- True if module_key has a mid-pass sell checkpoint at config.sell_level.
local function sell_checkpoint_active(module_key)
    local checkpoints = config.sell_checkpoints_by_level[config.sell_level]
    return checkpoints ~= nil and checkpoints[module_key] == true
end

-- Used share of main inventory slots (0-1); 0 if unreadable.
local function inventory_fill_ratio()
    local items = windower.ffxi.get_items()
    if not items or not items.inventory or not items.inventory.max or items.inventory.max <= 0 then
        return 0
    end
    local used = 0
    for _, slot in ipairs(items.inventory) do
        if slot.id and slot.id > 0 then
            used = used + 1
        end
    end
    return used / items.inventory.max
end

local function inventory_getting_full()
    return inventory_fill_ratio() >= config.sell_inventory_full_threshold
end

-- Runs a module's harvest; if it stopped on a full inventory, sells and
-- runs it again (up to inventory_full_max_restarts). Modules never mark
-- done on an inventory-full stop.
local function run_with_inventory_restart(label, fn)
    for attempt = 1, config.inventory_full_max_restarts + 1 do
        state.inventory_full_hit = false
        local result = fn()
        if not state.inventory_full_hit or not state.running then
            return result
        end
        state.inventory_full_hit = false
        if attempt > config.inventory_full_max_restarts then
            error_log(label .. ': inventory still full after ' .. config.inventory_full_max_restarts .. ' sell-and-restart attempt(s) - giving up on ' .. label .. ' this pass (NOT marked done).')
            return false
        end
        if not config.sell_junk_enabled then
            error_log(label .. ': inventory full, but selling is turned off (config.sell_junk_enabled) - stopping ' .. label .. ' (NOT marked done).')
            return false
        end
        log(label .. ': inventory full - selling (and dropping), then restarting ' .. label .. '...')
        sell_junk_to_moogle()
        if not state.running then return false end
        coroutine.sleep(1)
    end
    return false
end

-- Harvest function per module (//gh <module>, full, full inspect).
-- Crystals takes a mode instead ('all' by hand, 'full' in //gh full).
local MODULE_HARVESTERS = {
    vein = {label = 'Vein', fn = function(force) return harvest_node('vein', force) end},
    pond = {label = 'Pond', fn = function(force) return harvest_node('pond', force) end},
    grove = {label = 'Grove', fn = function(force) return harvest_node('grove', force) end},
    crystals = {label = 'Crystals', fn = function(force, mode) return CRYSTALS.harvest(force, mode or 'all') end},
    flotsam = {label = 'Flotsam', fn = function(force) return harvest_flotsam(force) end},
    net = {label = 'Net', fn = function(force) return harvest_node('net', force) end},
}
local DAILY_NODE_MODULES = {'vein', 'pond', 'grove', 'flotsam', 'net'}

-- //gh full / force: Books (daily check) -> Furrow -> Vein -> Pond ->
-- Grove -> Crystals -> Flotsam -> Net, with sell checkpoints per
-- config.sell_level, then inv (inventory_after_full - its sell step is the
-- end-of-pass sell; otherwise a plain sell), RoE, memory check. force =
-- ignore the done-today data (live "already done" text still counts).
local function run_full_garden_pass(force)
    clear_cursor_state()
    windower.send_command('target clear')
    coroutine.sleep(0.2)
    state.running = true
    state.furrows_found = {false, false, false}
    sync_module_status_flags()
    log('Starting full Mog Garden pass' .. (force and ' (forced)' or '') .. ' (sell level ' .. config.sell_level .. ')...')
    ASSIST.begin_run()

    -- pending = harvested since the last sell; non_furrow = by a module
    -- other than furrow (a furrow-only pass never walks to the moogle
    -- unless inventory is getting full).
    local pending, non_furrow = false, false
    local function maybe_sell(checkpoint)
        local forced = pending and inventory_getting_full()
        if not forced and checkpoint ~= 'final' and not sell_checkpoint_active(checkpoint) then
            return
        end
        local relevant = non_furrow
        if checkpoint == 'furrow' then relevant = pending end
        if forced or relevant then
            if forced then
                log('Inventory at ' .. string.format('%.0f', inventory_fill_ratio() * 100) .. '% (threshold ' ..
                    string.format('%.0f', config.sell_inventory_full_threshold * 100) .. '%) - selling now.')
            end
            sell_junk_to_moogle()
            pending, non_furrow = false, false
        else
            debug_log('Sell checkpoint (' .. checkpoint .. '): nothing harvested since the last sell - skipping.')
        end
    end

    -- Books first: the trip sails to the Port zone and back, so it is done
    -- before harvesting (nothing picked up yet to carry around).
    if BOOKS.due() then
        BOOKS.buy(false)
        if not state.running then return end
        if not BOOKS.done_today() then
            BOOKS.note_failed()
        end
        local info = windower.ffxi.get_info()
        if not info or info.zone ~= 280 then
            error_log('Books: not back in the Mog Garden after the book trip - stopping the pass (run //gh full again from the garden).')
            state.running = false
            return
        end
    end

    -- Every garden assistant is checked (and set up) at the start of a full
    -- run; all match = nothing to do. The node steps then skip their check.
    -- Assistant contracts first (recruiting puts a new assistant in the
    -- garden for the check below); most runs only look at the data.
    ASSIST.emp.run(false)
    if not state.running then return end
    ASSIST.check_all()
    if not state.running then return end

    if not is_module_enabled('furrow') then
        log('Furrow: disabled for this character (characters.lua) - skipping.')
    elseif FURROW_SYNC.seed_error() then
        error_log('Furrows: skipped - ' .. FURROW_SYNC.seed_error() .. ' (since ' .. saved_status.furrow_seed_error_at ..
            '). Restock, then //ml furrow recheck (or //gh furrow recheck here).')
    else
        reconcile_furrow_data(true)
        if not furrow_pass_needed(force) then
            local hold_epoch = FURROW_SYNC.hold_epoch(force)
            log('Furrows: not due yet - ' .. (hold_epoch and ('waiting until ' .. format_short_datetime(os.date('%Y-%m-%d %H:%M:%S', hold_epoch)) ..
                ' so every furrow is harvested together (furrow_sync_hold).') or 'all recorded as still growing.'))
        else
            approach_furrow(1)
            pending = run_single_furrow_pass(eff('seed'), eff('fertilizer'), force) or pending
        end
    end
    sync_module_status_flags()  -- fresh furrow ETA in settings.xml
    if not state.running then return end
    maybe_sell('furrow')

    for _, key in ipairs({'vein', 'pond', 'grove', 'crystals', 'flotsam', 'net'}) do
        if not state.running then return end
        local h = MODULE_HARVESTERS[key]
        if run_module_if_enabled(key, h.label, function()
            if key == 'crystals' then return h.fn(force, 'full') end
            return run_with_inventory_restart(h.label, function() return h.fn(force) end)
        end) then
            pending, non_furrow = true, true
        end
        if not state.running then return end
        if key == 'net' then
            -- End-of-pass sell: inv's sell step does it when inv runs next.
            if not config.inventory_after_full then maybe_sell('final') end
        else
            maybe_sell(key)
        end
    end
    if not state.running then return end

    local inventory_ran = false
    if config.inventory_after_full then
        INV.run(nil, true)
        inventory_ran = true
        if not state.running then return end
    end
    if config.roe_in_full then
        ROE.run(false)
        if not state.running then return end
    end
    -- Last step before "pass complete" (so a script waiting for that line
    -- logs out only after it): garbage collection (gc_at_end_of_full), then
    -- the memory check when turned on.
    MEMCHECK.in_full()

    refresh_findall_inventory()
    sync_module_status_flags()  -- this pass's results in settings.xml
    record_full_pass_complete()
    state.running = false
    -- "(inventory done)" tells MuleLogger not to run //gh inv auto again.
    log('Full Mog Garden pass complete' .. (inventory_ran and ' (inventory done)' or '') .. '.')
end

-- /item a seed or fertilizer on the targeted furrow and confirm its menu
-- (Enter x3, Escape). A refusal ("There is no need to...") means the
-- recorded state was stale: the real state is read from the text and
-- recorded. Returns ok, captured lines (they can hold the grow time).
local function use_item_on_furrow(item_name, furrow_number, verb, max_wait_per_press)
    local have = get_item_count(item_name)
    if have == nil then
        error_log('"' .. item_name .. '" is not a recognized item name - check characters.lua (seed / fertilizer) or the name you passed in')
        return false
    elseif have < 1 then
        -- v2.17.0: take it out of the other bags (satchel, sack, case,
        -- wardrobes, Mog House bags when reachable) - enough for every furrow.
        log('No ' .. item_name .. ' in inventory - looking in the other bags...')
        have = INV.pull_item(item_name, math.max(#get_active_furrows(), 1)) or 0
        if have < 1 then
            if verb == 'plant' and FURROW_SYNC.seed_error() then
                error_log('No ' .. item_name .. ' in any bag (seed error already recorded) - not planting.')
            elseif verb == 'plant' then
                FURROW_SYNC.set_seed_error(item_name)
            else
                error_log('No ' .. item_name .. ' in inventory or any other bag - cannot ' .. verb .. '. Restock and try again.')
            end
            return false
        end
        log('Took ' .. item_name .. ' out of the other bags - now x' .. have .. ' in inventory.')
    end
    log((verb == 'plant' and 'Planting ' or 'Fertilizing with ') .. item_name)
    debug_log('Have ' .. have .. ' of ' .. item_name .. ' in inventory')
    local lines, out_of_range = use_item_on_target(item_name, 5)
    if out_of_range then
        error_log(item_name .. ': "Target out of range" - could not ' .. verb .. '.')
        return false
    end
    if lines_contain(lines, config.item_use_reject_phrase) then
        error_log('Could not ' .. verb .. ' - the recorded status was stale: ' .. (lines[1] or 'no message captured'))
        local real_state = classify_furrow_text(lines)
        if furrow_number and real_state ~= 'unknown' then
            record_furrow_state(furrow_number, real_state, lines)
            log('Corrected recorded status for furrow ' .. furrow_number .. ' to ' .. real_state .. ' based on the rejection message.')
        end
        return false
    end
    return true, run_key_sequence({'enter', 'enter', 'enter', 'escape'}, max_wait_per_press)
end

plant_seed = function(seed_name, furrow_number)
    local ok, lines = use_item_on_furrow(seed_name or eff('seed'), furrow_number, 'plant', config.plant_max_wait_per_press)
    if ok then FURROW_SYNC.clear_seed_error(true) end
    return ok, lines
end

fertilize_furrow = function(fertilizer_name, furrow_number)
    return use_item_on_furrow(fertilizer_name or eff('fertilizer'), furrow_number, 'fertilize', 3)
end

-- Harvests the targeted furrow. already_in_menu = DETECT_SEQUENCE already
-- opened the menu and read "has matured!" (handle_furrow_for_start), so
-- only the rest runs. Otherwise (recorded data says ready) it never
-- harvests blind: DETECT_SEQUENCE first, and unless the game text says
-- ready it backs out of the menu, records the real state and returns
-- false - same key count as before when it is ready.
-- Keys: Enter (rank line), Enter ("has matured!"), Enter (menu opens,
-- "Harvest crop."), Enter ("Harvest this crop?" Yes), Enter (confirm).
-- Multi-harvest seed: the 3rd Enter shows "...should sprout about N more
-- times." instead, so one extra Enter (only when that line was seen)
-- opens the menu. Success = an "Obtained:" line. No confirmation +
-- furrow given = inspect it live and record the real state. Returns
-- success, lines (furrow_after_harvest reads the sprout line from them).
harvest_furrow = function(already_in_menu, furrow)
    -- Recorded data can be stale (e.g. harvested by hand): read the
    -- furrow's own text before pressing any harvest keys.
    local detect_lines = {}
    if not already_in_menu then
        local real
        detect_lines, real = FURROW_SYNC.detect(furrow, config.harvest_max_wait_per_press)
        if state.out_of_range_failed then
            error_log((furrow and furrow.name or 'Furrow') .. ': harvest refused ("Target out of range") - not marking it empty, will retry next pass.')
            return false, detect_lines
        end
        -- Back after an inventory-full sell: the first Enter can hand over
        -- the rest of the crop with no rank line. That IS the harvest (it
        -- used to read as "could not be classified" and the furrow wasn't
        -- replanted until a later login).
        if real == 'unknown' and furrow and state.furrow_retry_after_full == furrow.number and
            lines_contain(detect_lines, config.obtained_phrase) then
            if lines_contain(detect_lines, config.inventory_full_phrases) then
                log(furrow.name .. ': inventory is full again - harvest not finished (not marking it empty).', 167)
                state.inventory_full_hit = true
                acknowledge_inventory_full()
                return false, detect_lines
            end
            log(furrow.name .. ': the rest of the crop came on the first Enter after selling - harvest done.')
            return true, detect_lines
        end
        if real ~= 'ready' then
            local name = furrow and furrow.name or 'Furrow'
            if real == 'unknown' then
                error_log(name .. ': recorded status said ready, but its text could not be classified - not harvesting. The menu may still be open - please check the screen.')
                return false, detect_lines
            end
            -- Exit first: a growing furrow's first exit Enter can hold the sprout line.
            local extra = run_exit_sequence(real, config.harvest_max_wait_per_press)
            local all = concat_lines(detect_lines, extra)
            if furrow then record_furrow_state(furrow.number, real, all) end
            press_key('escape', 0.3)
            local when = ''
            if furrow and (real == 'growing_unfertilized' or real == 'growing_fertilized') then
                when = ' - next harvest at ' .. format_short_datetime(saved_status['furrow_' .. furrow.number .. '_harvest_at'])
            end
            log(name .. ': recorded status said ready, but the game says "' .. real .. '"' .. when .. ' - not harvesting (recorded the real state).', 167)
            return false, all
        end
    end
    log('Harvesting furrow')

    -- The last Enter confirms the Yes/No prompt - give it extra settle time.
    local confirm_enter = {'enter', pre_wait = config.harvest_confirm_extra_wait}

    -- Pressed only after a multi-harvest seed's sprout line.
    local sprout_enter = {'enter', if_text = 'should sprout about'}

    -- The menu is open on "has matured!" either way now (detected here or by the caller).
    local menu_steps = {'enter', sprout_enter, 'enter', confirm_enter, 'escape'}

    local lines = concat_lines(detect_lines, run_key_sequence(menu_steps, config.harvest_max_wait_per_press))
    if config.debug_mode and #lines > 0 then
        debug_log('Harvest captured text:')
        print_captured_lines(debug_log, '  ', lines)
    end

    -- Still out of range after the walker: nothing happened.
    if state.out_of_range_failed then
        error_log((furrow and furrow.name or 'Furrow') .. ': harvest refused ("Target out of range") - not marking it empty, will retry next pass.')
        return false, lines
    end

    -- Inventory full: the crop is still there; run_single_furrow_pass sells
    -- and comes back.
    if lines_contain(lines, config.inventory_full_phrases) then
        log((furrow and furrow.name or 'Furrow') .. ': inventory is full - harvest did not happen (not marking it empty).', 167)
        state.inventory_full_hit = true
        acknowledge_inventory_full()
        return false, lines
    end

    local success = lines_contain(lines, config.obtained_phrase) or lines_contain(lines, config.harvest_success_phrase)

    if not success and furrow then
        -- No confirmation text (lag?): inspect the furrow and record what it
        -- really is, instead of leaving stale data for the next pass.
        error_log('Furrow harvest: no confirmation text seen (expected "' .. config.obtained_phrase .. '") - inspecting ' .. furrow.name .. ' directly to find its real state instead of guessing.')
        coroutine.sleep(1)
        local inspected = live_probe_furrow(furrow)
        if inspected == 'empty' then
            log(furrow.name .. ': inspection confirms it harvested successfully after all (just missed the confirmation text) - treating as a success.')
            success = true
        else
            log(furrow.name .. ': inspection says its real state is "' .. tostring(inspected) .. '" - recorded accordingly, will be handled correctly next pass instead of retried blind.')
        end
    elseif not success then
        error_log('Furrow harvest: no confirmation text seen (expected "' .. config.obtained_phrase .. '") - not marking this furrow empty, will retry next pass.')
    end

    return success, lines
end

-- Interacts with one furrow to learn its real state: DETECT_SEQUENCE,
-- classify, then the matching EXIT_SEQUENCES entry (override_sequence =
-- an explicit key list from //gh furrowinspect instead). Records and
-- returns the state, or 'not_found'.
live_probe_furrow = function(furrow, override_sequence, max_wait_per_press)
    max_wait_per_press = max_wait_per_press or 3

    if not find_furrow(furrow.name, furrow.number) then
        log(furrow.name .. ' not found - skipping')
        return 'not_found'
    end

    log('--- ' .. furrow.name .. ' ---')
    if not windower.ffxi.get_mob_by_target('t') then
        error_log(furrow.name .. ' was targeted but get_mob_by_target returned nothing')
    end

    local guessed
    local lines

    if override_sequence then
        debug_log('  Running (explicit): ' .. table.concat(override_sequence, ', '))
        lines = run_key_sequence(override_sequence, max_wait_per_press)
        if #lines == 0 then
            debug_log('  (no new chat/system text appeared)')
        else
            debug_log('  Captured text:')
            print_captured_lines(debug_log, '    ', lines)
        end
        guessed = classify_furrow_text(lines)
    else
        debug_log('  Detecting (enter, enter)...')
        lines, guessed = FURROW_SYNC.detect(furrow, max_wait_per_press)
        if #lines == 0 then
            debug_log('  (no new chat/system text appeared)')
        else
            debug_log('  Captured text:')
            print_captured_lines(debug_log, '    ', lines)
        end

        local exit_sequence = EXIT_SEQUENCES[guessed]
        if exit_sequence then
            debug_log('  Exiting (' .. guessed .. '): ' .. describe_sequence(exit_sequence))
            local extra = run_exit_sequence(guessed, max_wait_per_press)
            for _, line in ipairs(extra or {}) do table.insert(lines, line) end
        else
            error_log(furrow.name .. ' - could not classify its state from the captured text, so there\'s no safe exit to pick. The menu may still be open - please check the screen and close it by hand.')
        end
    end

    -- Record first so the summary can show the new harvest time.
    record_furrow_state(furrow.number, guessed, lines)

    local summary = '  Guessed state: ' .. guessed
    if guessed == 'growing_unfertilized' or guessed == 'growing_fertilized' or guessed == 'ready' then
        summary = summary .. ', H@ ' .. format_short_datetime(saved_status['furrow_' .. furrow.number .. '_harvest_at'])
    end
    log(summary)

    -- Escape here is only cursor hygiene (it doesn't close these menus).
    press_key('escape', 0.3)
    windower.send_command('target clear')

    return guessed
end

-- After a successful furrow harvest (harvest_lines = its captured text).
-- Normal seed: records empty -> the caller plants. Multi-harvest seed
-- ("...should sprout about N more times." - N counts the crop just
-- harvested): N = 1 was the last harvest -> empty, plant. N > 1 (or N not
-- read): the plant stays and regrows, so no planting or fertilizing -
-- inspect it live to record the next harvest time and harvests left.
-- Returns the recorded state ('empty' / 'fertilized_empty' = plant now).
local function furrow_after_harvest(furrow, harvest_lines)
    local key = 'furrow_' .. furrow.number .. '_'
    if not lines_contain(harvest_lines or {}, 'should sprout about') then
        record_furrow_state(furrow.number, 'empty', harvest_lines)
        return 'empty'
    end
    local left = parse_harvests_left(harvest_lines)
    local after = left and (left - 1) or nil
    if after and after <= 0 then
        log(furrow.name .. ': multi-harvest seed - that was its last harvest, the furrow is empty now.')
        record_furrow_state(furrow.number, 'empty', harvest_lines)
        return 'empty'
    end
    log(furrow.name .. ': multi-harvest seed - ' ..
        (after and (after .. ' more harvest' .. (after == 1 and '' or 's') .. ' to come') or 'harvests left not read') ..
        '. Not planting or fertilizing - inspecting it for the next harvest time...')
    coroutine.sleep(2)
    local real = live_probe_furrow(furrow)
    if real == 'empty' or real == 'fertilized_empty' then
        log(furrow.name .. ': inspection says ' .. real .. ' - the seed is done after all, planting.')
        return real
    elseif real == 'growing_unfertilized' or real == 'growing_fertilized' or real == 'ready' then
        local n = tonumber(saved_status[key .. 'harvests_left']) or 0
        log(furrow.name .. ': ' .. (saved_status[key .. 'seed'] ~= '' and saved_status[key .. 'seed'] or 'seed') ..
            ' regrowing - next harvest at ' .. format_short_datetime(saved_status[key .. 'harvest_at']) ..
            (n > 0 and (', ' .. n .. ' harvest' .. (n == 1 and '' or 's') .. ' left (incl. that one)') or ''))
        return real
    end
    -- Inspect failed: record it as regrowing (flat estimate) so it isn't
    -- replanted blind; the next pass sees it ready and inspects again.
    record_furrow_state(furrow.number, 'growing_unfertilized', {})
    if after then
        saved_status[key .. 'harvests_left'] = after
        save_status()
    end
    error_log(furrow.name .. ': could not inspect it after the harvest (' .. tostring(real) .. ') - recorded as regrowing, next harvest estimated at ' ..
        format_short_datetime(saved_status[key .. 'harvest_at']) .. '. Check it with //gh furrowinspect ' .. furrow.number .. '.')
    return 'growing_unfertilized'
end

-- Detect-and-act in ONE menu visit (//gh furrowloop / furrow / full):
--   ready     -> harvest, plant, fertilize (if use_fertilizer); a
--                multi-harvest seed that regrows is only re-inspected
--                (furrow_after_harvest)
--   empty     -> plant (+ fertilize)
--   growing_* -> log it only (v2.19.0: fertilizer goes in ONLY right
--                after this pass planted the seed - never on a furrow
--                that was already growing, which may really be ready)
-- Recorded data is trusted first (infer_furrow_state); only a furrow
-- with no usable data is detected live, continuing straight into the
-- harvest from the detect menu when it's ready. Returns true if harvested.
handle_furrow_for_start = function(furrow, seed_name, fertilizer_name, force)
    local harvested = false

    local function plant_and_maybe_fertilize()
        if not find_furrow(furrow.name, furrow.number) then
            error_log(furrow.name .. ' not found when trying to plant - skipping')
            return
        end
        coroutine.sleep(1)

        -- Already fertilized, no seed: plant only; the seed grows fertilized,
        -- so harvest time = now + fertilize_wait_time (or the game's time).
        local key = 'furrow_' .. furrow.number .. '_'
        if saved_status[key .. 'state'] == 'fertilized_empty' then
            local fert = saved_status[key .. 'fertilizer']
            if fert == '' then fert = nil end
            local planted, plant_lines = plant_seed(seed_name, furrow.number)
            if planted then
                record_furrow_state(furrow.number, 'growing_fertilized', plant_lines, seed_name, fert or fertilizer_name or eff('fertilizer'))
                log(furrow.name .. ': planted into the fertilized furrow - harvest at ' .. format_short_datetime(saved_status[key .. 'harvest_at']))
            end
            return
        end

        local planted, plant_lines = plant_seed(seed_name, furrow.number)
        if planted then
            record_furrow_state(furrow.number, 'growing_unfertilized', plant_lines, seed_name)
            coroutine.sleep(2)

            -- v2.19.0: the only place furrows are fertilized automatically -
            -- right after planting, while the seed is surely growing (never
            -- ready to harvest). Skipped if the planting text corrected the
            -- recorded state to anything else.
            if eff('use_fertilizer') and saved_status[key .. 'state'] ~= 'growing_unfertilized' then
                log(furrow.name .. ': recorded as "' .. tostring(saved_status[key .. 'state']) .. '" after planting, not growing unfertilized - not fertilizing.', 167)
            elseif eff('use_fertilizer') then
                if find_furrow(furrow.name, furrow.number) then
                    coroutine.sleep(1)
                    local fertilized, fertilize_lines = fertilize_furrow(fertilizer_name, furrow.number)
                    if fertilized then
                        record_furrow_state(furrow.number, 'growing_fertilized', fertilize_lines, nil, fertilizer_name)
                    end
                else
                    error_log(furrow.name .. ' not found when trying to fertilize - leaving it recorded as growing_unfertilized for now')
                end
            end
        end
    end

    local function exit_menu_hygiene()
        press_key('escape', 0.3)
        windower.send_command('target clear')
    end

    -- force: ignore recorded data and detect live (still reads the real
    -- state before acting - it never harvests blind).
    local inferred = (not force) and infer_furrow_state(furrow.number) or nil

    if inferred then
        if inferred ~= saved_status['furrow_' .. furrow.number .. '_state'] then
            record_furrow_state(furrow.number, inferred) -- e.g. growing -> ready by elapsed time
        end

        if inferred == 'growing_unfertilized' or inferred == 'growing_fertilized' then
            log('Garden Furrow #' .. furrow.number .. ': ' ..
                describe_growing_furrow_value(furrow.number, inferred, seed_name, fertilizer_name))
        elseif inferred == 'ready' then
            log(furrow.name .. ': recorded status says ready - harvesting')
            if find_furrow(furrow.name, furrow.number) then
                coroutine.sleep(1)
                local harvest_ok, harvest_lines = harvest_furrow(nil, furrow)
                if harvest_ok then
                    harvested = true
                    local after = furrow_after_harvest(furrow, harvest_lines)
                    if after == 'empty' or after == 'fertilized_empty' then
                        coroutine.sleep(2)
                        plant_and_maybe_fertilize()
                    end
                elseif saved_status['furrow_' .. furrow.number .. '_state'] == 'fertilized_empty' then
                    -- Inspection found fertilizer but no seed: plant it now.
                    log(furrow.name .. ': fertilized but no seed planted - planting')
                    coroutine.sleep(config.fertilized_empty_settle_seconds)
                    plant_and_maybe_fertilize()
                elseif saved_status['furrow_' .. furrow.number .. '_state'] == 'empty' then
                    -- Pre-harvest check found it empty (e.g. harvested by hand): plant it.
                    log(furrow.name .. ': empty - planting')
                    coroutine.sleep(2)
                    plant_and_maybe_fertilize()
                end
            else
                error_log(furrow.name .. ' not found when trying to harvest - skipping')
            end
        elseif inferred == 'empty' then
            log(furrow.name .. ': recorded status says empty - planting')
            plant_and_maybe_fertilize()
        elseif inferred == 'fertilized_empty' then
            log(furrow.name .. ': recorded status says fertilized but no seed - planting')
            plant_and_maybe_fertilize()
        end

        windower.send_command('target clear')
        return harvested
    end

    -- No usable data: detect live and act in the same menu.
    if not find_furrow(furrow.name, furrow.number) then
        log(furrow.name .. ' not found - skipping')
        return harvested
    end

    log('--- ' .. furrow.name .. ' ---')
    log('  Detecting (enter, enter)...')
    local lines, guessed = FURROW_SYNC.detect(furrow, 3)
    log('  Guessed state: ' .. guessed)

    if guessed == 'ready' then
        local harvest_ok, harvest_lines = harvest_furrow(true, furrow)
        if harvest_ok then
            harvested = true
            local after = furrow_after_harvest(furrow, concat_lines(lines, harvest_lines))
            if after == 'empty' or after == 'fertilized_empty' then
                coroutine.sleep(2)
                plant_and_maybe_fertilize()
            end
        elseif saved_status['furrow_' .. furrow.number .. '_state'] == 'fertilized_empty' then
            log(furrow.name .. ': fertilized but no seed planted - planting')
            coroutine.sleep(config.fertilized_empty_settle_seconds)
            plant_and_maybe_fertilize()
        end
    elseif guessed == 'fertilized_empty' then
        -- Enter already opened "What will you do?": Down to "Absolutely
        -- nothing", Enter, wait, then plant (no fertilizer - it's in).
        record_furrow_state(furrow.number, 'fertilized_empty', lines)
        run_key_sequence(EXIT_SEQUENCES.fertilized_empty, 3)
        exit_menu_hygiene()
        log(furrow.name .. ': fertilized but no seed planted - planting')
        coroutine.sleep(config.fertilized_empty_settle_seconds)
        plant_and_maybe_fertilize()
    elseif guessed == 'empty' then
        record_furrow_state(furrow.number, 'empty', lines)
        run_key_sequence(EXIT_SEQUENCES.empty, 3)
        exit_menu_hygiene()
        plant_and_maybe_fertilize()
    elseif guessed == 'growing_unfertilized' then
        -- Recorded after the exit: its first Enter can hold the sprout line.
        local extra = run_exit_sequence('growing_unfertilized', 3)
        record_furrow_state(furrow.number, 'growing_unfertilized', concat_lines(lines, extra))
        exit_menu_hygiene()
    elseif guessed == 'growing_fertilized' then
        local extra = run_exit_sequence('growing_fertilized', 3)
        record_furrow_state(furrow.number, 'growing_fertilized', concat_lines(lines, extra))
        exit_menu_hygiene()
    else
        error_log(furrow.name .. ' - could not classify its state from the captured text, so there\'s no safe exit to pick. The menu may still be open - please check the screen and close it by hand.')
    end

    windower.send_command('target clear')
    return harvested
end

-- Run at the top of every furrow command: finds which furrows exist
-- right now (settarget probe). Without skip_status_probe, a mismatch
-- between existing furrows and ones with recorded status triggers a live
-- probe of each. skip_status_probe (loop/full/duecheck) only does the
-- existence check - handle_furrow_for_start detects and acts in one visit.
reconcile_furrow_data = function(skip_status_probe)
    state.furrows_announced = {false, false, false}

    local function probe_existence()
        local found = {}
        local count = 0
        for _, furrow in ipairs(FURROWS) do
            if not state.running then break end
            if find_furrow(furrow.name, furrow.number, true) then
                found[furrow.number] = true
                count = count + 1
            end
            coroutine.sleep(0.3)
        end
        windower.send_command('target clear')
        return found, count
    end

    local function highest_found_number(found)
        local highest = 0
        for number, _ in pairs(found) do
            if number > highest then highest = number end
        end
        return highest
    end

    local available, available_count

    -- Back-to-back skip_status_probe calls (duecheck then full) reuse a
    -- fresh probe (existence_cache_seconds). Reset on login/logout/zone change.
    local cache_age = state.available_furrows_checked_at and (os.time() - state.available_furrows_checked_at) or nil
    local can_reuse_existence = skip_status_probe
        and state.available_furrows ~= nil
        and cache_age ~= nil
        and cache_age < config.existence_cache_seconds

    if can_reuse_existence then
        available = state.available_furrows
        available_count = 0
        for _ in pairs(available) do
            available_count = available_count + 1
        end
        log('Reusing the furrow list checked ' .. cache_age .. 's ago instead of re-checking (avoids re-poking furrows already confirmed this login).')
    else
        available, available_count = probe_existence()

        -- Furrows unlock in order: a gap (#3 found, #2 not) means entities are
        -- still loading - retry.
        local retries = 0
        while state.running and retries < 4 do
            local highest = highest_found_number(available)
            if highest == 0 then break end

            local inconsistent = false
            for n = 1, highest - 1 do
                if not available[n] then
                    inconsistent = true
                    break
                end
            end
            if not inconsistent then break end

            retries = retries + 1
            debug_log('Furrow ' .. highest .. ' was found but a lower-numbered one was not - entities may still be loading in, retrying (' .. retries .. '/4)...')
            coroutine.sleep(3)
            available, available_count = probe_existence()
        end

        -- The highest found furrow can be a stale entity from the previous
        -- character's garden (fast relogs): re-target #1, then re-confirm it.
        local highest = highest_found_number(available)
        if highest > 1 and state.running then
            find_furrow(FURROWS[1].name, 1, true)
            coroutine.sleep(0.3)
            local reconfirmed = find_furrow(FURROWS[highest].name, highest, true)
            if not reconfirmed then
                debug_log('Garden Furrow ' .. highest .. ' did not re-confirm after a flush re-check - most likely a stale entity left over from a previous character, not real. Removing it from this run.')
                available[highest] = nil
                available_count = available_count - 1
            end
            windower.send_command('target clear')
        end

        state.available_furrows_checked_at = os.time()
    end

    -- Save not_found for missing furrows (//gh status shows it); a furrow
    -- found again goes back to 'unknown' so it gets a live probe.
    for _, furrow in ipairs(FURROWS) do
        local state_key = 'furrow_' .. furrow.number .. '_state'
        if available[furrow.number] then
            if saved_status[state_key] == 'not_found' then
                saved_status[state_key] = 'unknown'
                saved_status['furrow_' .. furrow.number .. '_checked_at'] = ''
                saved_status['furrow_' .. furrow.number .. '_checked_epoch'] = 0
                save_status()
            end
        elseif saved_status[state_key] ~= 'not_found' then
            saved_status[state_key] = 'not_found'
            saved_status['furrow_' .. furrow.number .. '_checked_at'] = os.date('%Y-%m-%d %H:%M:%S')
            saved_status['furrow_' .. furrow.number .. '_checked_epoch'] = os.time()
            save_status()
        end
    end

    if not skip_status_probe then
        local known_count = 0
        for number, _ in pairs(available) do
            if saved_status['furrow_' .. number .. '_state'] ~= 'unknown' then
                known_count = known_count + 1
            end
        end

        if known_count ~= available_count then
            log('Furrow count/data mismatch (' .. available_count .. ' furrow(s) available, ' .. known_count .. ' have recorded status) - refreshing all of them...')
            for _, furrow in ipairs(FURROWS) do
                if not state.running then break end
                if available[furrow.number] then
                    live_probe_furrow(furrow)
                    coroutine.sleep(0.5)
                end
            end
        end
    end

    state.available_furrows = available
    log('Furrows available this run: ' .. (available[1] and '1 ' or '') .. (available[2] and '2 ' or '') .. (available[3] and '3' or ''))

    return available
end

-- FURROWS entries that exist (from reconcile_furrow_data). Before any
-- reconcile this run: every furrow not recorded as not_found.
get_active_furrows = function()
    if not state.available_furrows then
        local active = {}
        for _, furrow in ipairs(FURROWS) do
            if saved_status['furrow_' .. furrow.number .. '_state'] ~= 'not_found' then
                table.insert(active, furrow)
            end
        end
        return active
    end

    local active = {}
    for _, furrow in ipairs(FURROWS) do
        if state.available_furrows[furrow.number] then
            table.insert(active, furrow)
        end
    end
    return active
end

check_furrow_states = function(only_number)
    local fresh_states = {}

    for _, furrow in ipairs(get_active_furrows()) do
        if not state.running then break end
        if not only_number or only_number == furrow.number then
            local inferred = infer_furrow_state(furrow.number)
            if inferred then
                log(furrow.name .. ': using recorded status (' .. inferred .. ') - no live check needed')
                if inferred ~= saved_status['furrow_' .. furrow.number .. '_state'] then
                    record_furrow_state(furrow.number, inferred) -- e.g. growing -> ready by elapsed time
                end
                fresh_states[furrow.number] = inferred
            else
                fresh_states[furrow.number] = live_probe_furrow(furrow)
            end
            coroutine.sleep(0.2)
        end
    end

    return fresh_states
end

-- Pulls 'force' out of args (any position from start_index on); returns
-- force, remaining args in order.
local function extract_force_arg(args, start_index)
    local remaining = {}
    local force = false
    for i = start_index, #args do
        if args[i] and args[i]:lower() == 'force' then
            force = true
        else
            table.insert(remaining, args[i])
        end
    end
    return force, remaining
end

-- ---- Zones, arrival, garden entry, books ----
local MOG_GARDEN_ZONE_ID = 280
-- Port zone id -> entities.lua keys for that zone's Mog Dinghy/Skipper.
local PORT_DINGHY_KEYS = {[232] = 'SandyDinghy', [236] = 'BastokDinghy', [240] = 'WindyDinghy'}
local PORT_SKIPPER_KEYS = {[232] = 'SandySkipper', [236] = 'BastokSkipper', [240] = 'WindySkipper'}

local function current_zone()
    local info = windower.ffxi.get_info()
    return info and info.zone, info and info.mog_house
end

local function in_mog_garden()
    local zone = current_zone()
    return zone == MOG_GARDEN_ZONE_ID
end

local function zone_name(zone_id)
    local z = zone_id and res.zones[zone_id]
    return z and z.en or ('zone ' .. tostring(zone_id))
end

-- Waits for the 'zone change' event (count past since_count). Returns
-- the new zone id, or nil on timeout/stop.
local function wait_for_zone_change(since_count, timeout)
    local waited = 0
    while state.running and waited < timeout do
        if state.zone_change_count > since_count then
            return state.zone_changed_to
        end
        coroutine.sleep(0.5)
        waited = waited + 0.5
    end
    return nil
end

-- Polls until entity_id is loaded, up to max_wait. true/false.
local function poll_for_entity(entity_id, max_wait)
    local waited = 0
    while state.running and waited <= max_wait do
        if windower.ffxi.get_mob_by_id(entity_id) then
            return true
        end
        coroutine.sleep(config.arrival_poll_interval)
        waited = waited + config.arrival_poll_interval
    end
    return false
end

-- The Green Thumb Moogle's target won't release = cutscene. true = released.
local function wait_out_green_thumb_cutscene()
    log('Target on the ' .. GREEN_THUMB_MOOGLE.name .. ' will not release (' .. config.arrival_release_fail_limit ..
        'x in a row) - assuming a cutscene. Pressing Enter, Escape until it ends (up to ' ..
        math.floor(config.arrival_cutscene_max_seconds / 60) .. ' min)...')
    local released = press_until_target_released(config.arrival_cutscene_max_seconds)
    if not released and state.running then
        error_log('Target on the ' .. GREEN_THUMB_MOOGLE.name .. ' still has not released after ' .. config.arrival_cutscene_max_seconds .. 's of Enter/Escape - carrying on anyway. Check the screen.')
    end
    return released
end

-- force (//gh loaded, v2.18.0): always do the Green Thumb Moogle check,
-- even if this arrival was already confirmed or the garden has been
-- loaded a while. Returns ok (false = stopped) and loaded (the moogle
-- check passed, or was not needed).
local function wait_for_entities_settled(first_node_id, force)
    if state.last_arrival_epoch then
        local elapsed = os.time() - state.last_arrival_epoch
        local remaining = config.min_seconds_since_arrival - elapsed
        if remaining > 0 then
            log('Only ' .. elapsed .. 's since the last login/zone change - waiting ' .. remaining .. 's more for the Mog Garden to finish loading...')
            coroutine.sleep(remaining)
        end
    end

    if not in_mog_garden() then
        return true, true
    end

    -- v2.22.0 (Mark): the check is never skipped - not after the garden
    -- has been loaded a while (was arrival_skip_check_after_seconds 60s),
    -- not after an addon reload. Each arrival must pass it once; a pass is
    -- remembered for that arrival (force = do it again anyway).
    local need_moogle = force or state.arrival_confirmed_for ~= (state.last_arrival_epoch or 0)
    local need_node = first_node_id ~= nil and windower.ffxi.get_mob_by_id(first_node_id) == nil
    if not need_moogle and not need_node then
        return true, true
    end

    local set_running_here = false
    if not state.running then
        state.running = true
        set_running_here = true
    end

    local ok = true
    local confirmed = not need_moogle
    local miss_note = ''
    if need_moogle then
        -- Poll until arrival_give_up_seconds after arrival; misses are debug only.
        local deadline
        if state.last_arrival_epoch then
            deadline = state.last_arrival_epoch + config.arrival_give_up_seconds
        else
            deadline = os.time() + config.arrival_poll_max_seconds
        end
        deadline = math.max(deadline, os.time() + (config.arrival_min_poll_seconds or 20))
        local release_failures = 0
        local cutscene_done = false
        local hold = config.arrival_target_hold_seconds or 1
        debug_log('Arrival: polling for ' .. GREEN_THUMB_MOOGLE.name .. '...')
        while state.running and not confirmed do
            local gtm = windower.ffxi.get_mob_by_id(GREEN_THUMB_MOOGLE.id)
            if gtm then
                -- 1. settarget, must hold for 1s.
                if find_moogle(true) then
                    coroutine.sleep(hold)
                    if current_target_is(GREEN_THUMB_MOOGLE.id, GREEN_THUMB_MOOGLE.name) and state.running then
                        -- 2. Escape drops the cursor; a target that won't drop = cutscene.
                        press_key('escape', 0)
                        if not target_released() then
                            release_failures = release_failures + 1
                            debug_log('Arrival: Escape did not drop the target (' .. release_failures .. '/' .. config.arrival_release_fail_limit .. ' in a row)')
                            if release_failures >= config.arrival_release_fail_limit then
                                cutscene_done = true
                            end
                        else
                            release_failures = 0
                            -- 3. settarget again RIGHT away, must hold another 1s.
                            state.set_target(GREEN_THUMB_MOOGLE.id)
                            local w = 0
                            while w < 1.5 and state.running and not current_target_is(GREEN_THUMB_MOOGLE.id, GREEN_THUMB_MOOGLE.name) do
                                coroutine.sleep(0.1)
                                w = w + 0.1
                            end
                            if current_target_is(GREEN_THUMB_MOOGLE.id, GREEN_THUMB_MOOGLE.name) then
                                coroutine.sleep(hold)
                                if current_target_is(GREEN_THUMB_MOOGLE.id, GREEN_THUMB_MOOGLE.name) then
                                    confirmed = true
                                else
                                    debug_log('Arrival: second target on ' .. GREEN_THUMB_MOOGLE.name .. ' did not hold ' .. hold .. 's - polling again...')
                                end
                            else
                                debug_log('Arrival: re-target on ' .. GREEN_THUMB_MOOGLE.name .. ' after Escape did not stick - polling again...')
                            end
                        end
                    else
                        debug_log('Arrival: target on ' .. GREEN_THUMB_MOOGLE.name .. ' did not hold ' .. hold .. 's - polling again...')
                    end
                elseif gtm.distance and gtm.distance > 2500 then
                    -- Targeting ignores anything over 50 yalms away.
                    miss_note = string.format(' - he is %.0f yalms away and targeting only reaches 50', math.sqrt(gtm.distance))
                    -- v2.22.0: he is loaded, so walk closer and check again.
                    if gtm.x and gtm.y and state.running then
                        log(string.format('The %s is %.0f yalms away (targeting only reaches 50) - walking closer, then checking again...', GREEN_THUMB_MOOGLE.name, math.sqrt(gtm.distance)))
                        walk_to_xy(gtm.x, gtm.y, GREEN_THUMB_MOOGLE.name, {tolerance = config.arrival_walk_to_moogle_yalms or 30, timeout = 45})
                    end
                end
                if cutscene_done then
                    wait_out_green_thumb_cutscene()
                    confirmed = true
                    break
                end
            else
                miss_note = ' - he is not loaded (not in range / garden still loading)'
                debug_log('Arrival: ' .. GREEN_THUMB_MOOGLE.name .. ' not loaded yet...')
            end
            if confirmed or os.time() >= deadline then
                break
            end
            coroutine.sleep(config.arrival_poll_interval)
        end
        windower.send_command('target clear')
        if confirmed then
            log(GREEN_THUMB_MOOGLE.name .. ' detected - garden is loaded, moving on.')
            state.arrival_confirmed_for = state.last_arrival_epoch or 0
        elseif state.running then
            error_log('Could not target the ' .. GREEN_THUMB_MOOGLE.name .. ' (id ' .. GREEN_THUMB_MOOGLE.id .. ') and have it hold ' .. hold .. 's, Escape, re-target and hold again' .. miss_note .. ' - the garden is not confirmed loaded.')
        end
    end

    if state.running and first_node_id then
        if not poll_for_entity(first_node_id, config.arrival_node_poll_max_seconds) and state.running then
            error_log('Arrival: the first node to work on (id ' .. first_node_id .. ') never showed up - carrying on anyway.')
        end
    end

    if not state.running then
        ok = false
    end
    if set_running_here then
        state.running = false
    end
    return ok, confirmed
end

-- Port zone -> Mog Garden: walk to/target the Mog Dinghy, Enter ("Move
-- to a Mog Garden?"), Enter ("Most definitely!"), wait for the zone and
-- the arrival check. Needs state.running.
local function enter_garden_from_port(zone)
    local key = PORT_DINGHY_KEYS[zone]
    local e = key and ENTITIES[key]
    if not e then
        error_log('No Mog Dinghy listed in entities.lua for ' .. zone_name(zone) .. '.')
        return false
    end

    clear_cursor_state()
    if not state.running then return false end
    if not position_at_node(key, e.id, e.name, key) then
        if state.running then
            error_log('Could not reach/target the Mog Dinghy in ' .. zone_name(zone) .. '.')
        end
        return false
    end

    log('Boarding the Mog Dinghy to the Mog Garden...')
    state.expecting_zone = true
    local before = state.zone_change_count
    press_key('enter', config.menu_open_wait_seconds) -- "Move to a Mog Garden?"
    press_key('enter', 0.5)                            -- "Most definitely!"
    local new_zone = wait_for_zone_change(before, config.zone_change_wait_seconds)
    state.expecting_zone = false

    if new_zone ~= MOG_GARDEN_ZONE_ID then
        error_log('Did not zone into the Mog Garden after using the Dinghy (' .. (new_zone and ('landed in ' .. zone_name(new_zone)) or 'no zone change') .. ').')
        clear_cursor_state()
        return false
    end
    log('In the Mog Garden - waiting for it to load...')
    local ok, loaded = wait_for_entities_settled(nil)
    return ok and loaded
end

-- Mog House -> Mog Garden with config.mog_house_exit_keys (one-time
-- mapping). Needs state.running.
local function enter_garden_from_mog_house(zone)
    if #config.mog_house_exit_keys == 0 then
        error_log('In the Mog House - getting from here to the Mog Garden is not set up yet (config.mog_house_exit_keys is empty). Walk out the door and pick Mog Garden by hand, or set config.mog_house_exit_keys to the menu keys your Mog House exit needs.')
        return false
    end
    clear_cursor_state()
    local door = config.mog_house_exit_door_xy[zone]
    if door then
        walk_to_xy(door.x, door.y, 'Mog House door', {tolerance = 0.5, timeout = 15})
    end
    state.expecting_zone = true
    local before = state.zone_change_count
    coroutine.sleep(config.menu_open_wait_seconds)
    for _, key in ipairs(config.mog_house_exit_keys) do
        press_key(key)
    end
    local new_zone = wait_for_zone_change(before, config.zone_change_wait_seconds)
    state.expecting_zone = false
    if new_zone ~= MOG_GARDEN_ZONE_ID then
        error_log('Mog House exit did not land in the Mog Garden (' .. (new_zone and zone_name(new_zone) or 'no zone change') .. ') - check config.mog_house_exit_keys.')
        return false
    end
    log('In the Mog Garden - waiting for it to load...')
    local ok, loaded = wait_for_entities_settled(nil)
    return ok and loaded
end

-- Gets into the Mog Garden if not there: from a Port zone within
-- port_dinghy_max_distance of the Dinghy (ignore_distance for //gh
-- enter), or the Mog House. Needs state.running.
local function ensure_in_mog_garden(ignore_distance)
    local zone, mog_house = current_zone()
    if zone == MOG_GARDEN_ZONE_ID then
        return true
    end
    if mog_house then
        return enter_garden_from_mog_house(zone)
    end
    local key = PORT_DINGHY_KEYS[zone]
    if key and ENTITIES[key] then
        local d = distance_to_id(ENTITIES[key].id)
        if ignore_distance or (d and d <= config.port_dinghy_max_distance) then
            -- Books due and already in a Port zone: do them here first.
            if config.books_first_from_port and PORT_SKIPPER_KEYS[zone] and BOOKS.due() then
                log('Books: already in ' .. zone_name(zone) .. ' and today\'s book check is due - doing it here before entering the Mog Garden.')
                BOOKS.buy(false)
                if not state.running then return false end
                if not BOOKS.done_today() then
                    BOOKS.note_failed()
                end
                if in_mog_garden() then
                    return true
                end
            end
            return enter_garden_from_port(zone)
        end
        error_log('In ' .. zone_name(zone) .. ' but ' .. (d and (string.format('%.0f', d) .. ' yalms') or 'too far') .. ' from the Mog Dinghy (auto-entry limit ' .. config.port_dinghy_max_distance .. ' yalms). Get closer, or use //gh enter.')
        return false
    end
    error_log('Not in the Mog Garden (in ' .. zone_name(zone) .. ') - this command needs the Mog Garden, a Port zone next to the Mog Dinghy, or the Mog House.')
    return false
end

-- //gh furrow done: record every existing furrow as just planted with the
-- active seed (fertilized if on), harvest at now + growth time.
local function mark_furrows_done()
    local now = os.time()
    local seed = eff('seed')
    local use_fert = eff('use_fertilizer')
    local wait = use_fert and eff('fertilize_wait_time') or eff('harvest_time')
    local count = 0
    for i = 1, 3 do
        if saved_status['furrow_' .. i .. '_state'] ~= 'not_found' then
            saved_status['furrow_' .. i .. '_state'] = use_fert and 'growing_fertilized' or 'growing_unfertilized'
            saved_status['furrow_' .. i .. '_checked_at'] = os.date('%Y-%m-%d %H:%M:%S', now)
            saved_status['furrow_' .. i .. '_checked_epoch'] = now
            saved_status['furrow_' .. i .. '_seed'] = seed
            saved_status['furrow_' .. i .. '_fertilizer'] = use_fert and eff('fertilizer') or ''
            saved_status['furrow_' .. i .. '_harvest_epoch'] = now + wait
            saved_status['furrow_' .. i .. '_harvest_at'] = os.date('%Y-%m-%d %H:%M:%S', now + wait)
            count = count + 1
        end
    end
    persist_status()
    sync_module_status_flags()
    log('Furrows: ' .. count .. ' marked done - ' .. seed .. ', harvest at ' .. format_short_datetime(os.date('%Y-%m-%d %H:%M:%S', now + wait)) .. '.')
end

-- //gh full done / reset: every node, crystals, books and furrow.
local function set_full_done(done)
    for _, prefix in ipairs({'vein', 'pond', 'grove', 'flotsam', 'net', 'crystals'}) do
        set_module_done(prefix, done, nil, true)
    end
    BOOKS.set_done(done)
    if done then mark_furrows_done() else reset_furrow_status('all') end
end

-- //gh full inspect: furrows checked live (and acted on when
-- inspect_takes_action), every daily node tried with force.
local function run_full_inspect()
    state.running = true
    ASSIST.begin_run()
    ASSIST.emp.run(false)
    if not state.running then return end
    ASSIST.check_all()
    if not state.running then return end
    reconcile_furrow_data(true)
    approach_furrow(1)
    if config.inspect_takes_action then
        run_single_furrow_pass(eff('seed'), eff('fertilizer'), true)
    else
        for _, furrow in ipairs(get_active_furrows()) do
            if not state.running then break end
            live_probe_furrow(furrow)
            coroutine.sleep(1)
        end
    end
    for _, prefix in ipairs(DAILY_NODE_MODULES) do
        if not state.running then break end
        local h = MODULE_HARVESTERS[prefix]
        run_module_if_enabled(prefix, h.label, function()
            return run_with_inventory_restart(h.label, function() return h.fn(true) end)
        end)
    end
    sync_module_status_flags()
    if state.running then
        log('Full inspect complete - see //gh status.')
    end
    state.running = false
end

-- ---- Modules ----
-- books.lua, crystals.lua and inv.lua each return function(gh) -> API.
-- gh is what they may use from this file; saved_status goes through a
-- proxy because the 'login' event replaces the table.
local GH = {
    config = config, state = state, ENTITIES = ENTITIES, EPHEMERAL_MOOGLE = EPHEMERAL_MOOGLE,
    MOG_GARDEN_ZONE_ID = MOG_GARDEN_ZONE_ID, PORT_DINGHY_KEYS = PORT_DINGHY_KEYS, PORT_SKIPPER_KEYS = PORT_SKIPPER_KEYS,
    saved_status = setmetatable({}, {
        __index = function(_, k) return saved_status[k] end,
        __newindex = function(_, k, v) saved_status[k] = v end,
    }),
    log = log, debug_log = debug_log, error_log = error_log, alert = alert,
    persist_status = persist_status, save_status = save_status, set_module_done = set_module_done,
    get_garden_day_string = get_garden_day_string, is_module_enabled = is_module_enabled,
    character_file = CHARACTER_FILE,
    character_key = get_character_key, get_character_override = get_character_override,
    navigate_to_entity = navigate_to_entity, entity_present = entity_present, capture_until = capture_until,
    press_key = press_key, clear_cursor_state = clear_cursor_state, lines_contain = lines_contain,
    print_captured_lines = print_captured_lines, strip_timestamp_prefix = strip_timestamp_prefix,
    find_entity = find_entity, current_target_is = current_target_is, retarget_entity = retarget_entity,
    position_at_node = position_at_node, ensure_in_interact_range = ensure_in_interact_range,
    current_zone = current_zone, zone_name = zone_name, in_mog_garden = in_mog_garden,
    wait_for_zone_change = wait_for_zone_change, enter_garden_from_port = enter_garden_from_port,
    sell = sell_junk_to_moogle,
    walk_to_moogle = walk_to_moogle_with_waypoint_fallback,
    -- "Target out of range." for the modules (employment, assistants,
    -- crystals, books): range_retry(id, name, try) runs try() - the
    -- interaction's first Enter or trade plus its wait - and if the game
    -- said "Target out of range." meanwhile, walks closer (next step of
    -- out_of_range_walk_distances, then straight at it), re-targets and
    -- runs try() again, up to out_of_range_max_retries times. Returns
    -- try()'s results, or false once it gives up. out_of_range_count() =
    -- how many "Target out of range." lines have been seen so far.
    out_of_range_count = function() return state.out_of_range_count or 0 end,
    range_retry = function(target_id, target_name, try)
        local target = {id = target_id, name = target_name}
        for attempt = 0, config.out_of_range_max_retries do
            local before = state.out_of_range_count or 0
            local a, b, c = try()
            if (state.out_of_range_count or 0) == before or not state.running then
                return a, b, c
            end
            if attempt >= config.out_of_range_max_retries then
                out_of_range_give_up(target, 'still refused after ' .. attempt .. ' walk(s) closer - giving up on it for now.')
                return false
            end
            if not walk_closer_after_out_of_range(target, attempt + 1) then
                state.out_of_range_failed = true
                return false
            end
        end
        return false
    end,
    assistant_present = function(key) return ASSIST.present(key) end,
    -- The item table file INV reads and writes (v2.31.0): characters.lua
    -- item_table = 'ItemTable_<name>.lua' (a file in this folder), or
    -- 'ItemTable.lua' when it is blank / missing / not a plain .lua name.
    item_table_file = function()
        local f = CHARACTER_FILE.item_table
        if type(f) == 'string' then
            f = f:match('^%s*(.-)%s*$')
            if f ~= '' and not f:find('[/\\:]') and f:lower():sub(-4) == '.lua' then return f end
        end
        return 'ItemTable.lua'
    end,
    -- Items this character keeps in main inventory (INV never mails or
    -- moves them): furrow fertilizer, node fertilizers. The active seed is
    -- NOT protected (v2.30.0) - ItemTable.lua decides (e.g. action "save",
    -- min_save 99 keeps 99 and sells the rest).
    protected_item_names = function()
        local names = {eff('fertilizer')}
        for _, prefix in ipairs({'vein', 'pond', 'grove', 'net'}) do
            local fert = get_effective(prefix .. '_fertilizer', prefix .. '_fertilizer')
            if type(fert) == 'string' and fert ~= '' then table.insert(names, fert) end
        end
        return names
    end,
}

-- Loads a module; a missing or broken one is replaced by a stand-in
-- whose every call returns nil (that feature is off, the rest works).
local function load_module(filename)
    local init = load_sibling(filename, 'function')
    local ok, mod = false, 'not loaded'
    if init then
        ok, mod = pcall(init, GH)
    end
    if ok and type(mod) == 'table' then
        return mod
    end
    error_log(filename .. ' did not start (' .. tostring(mod) .. ') - its commands are off until it loads.')
    return setmetatable({}, {__index = function() return function() return nil end end})
end
BOOKS = load_module('books.lua')
CRYSTALS = load_module('crystals.lua')
INV = load_module('inv.lua')
ROE = load_module('Set_RoE.lua')
MEMCHECK = load_module('memcheck.lua')
ASSIST = load_module('assistants.lua')
-- employment.lua hangs off ASSIST (the main chunk is at Lua's 200-local limit).
ASSIST.emp = load_module('employment.lua')
-- v2.32.0: //gh update (Update.lua) hangs off GH for the same reason.
GH.update = load_module('Update.lua')

-- Commands that never touch a garden entity: no arrival wait, no "must
-- be in the Mog Garden" check. Same for these first arguments.
local ARRIVAL_WAIT_EXEMPT_COMMANDS = {
    stop = true, abort = true, debug = true, furrowstatus = true, furrowconfig = true, status = true,
    help = true, pos = true, reloadstatus = true, enter = true, books = true, [''] = true,
    inv = true, inventory = true, pop = true, send = true, rec = true, receive = true, org = true, organize = true,
    drop = true, roe = true, memory = true, memprobe = true, loaded = true,
    ephstock = true, ephcapture = true,   -- v2.29.0 (crystals.lua)
    update = true,                        -- v2.32.0 (Update.lua)
}
-- v2.22.0 (Mark): these work outside the garden too, so they never walk
-- you in - but used IN the Mog Garden they wait for it to load (the
-- Green Thumb Moogle check) like every other garden command.
ARRIVAL_WAIT_EXEMPT_COMMANDS.garden_check_if_there = {  -- (a field, not a local: main chunk is at the 200-local limit)
    books = true, inv = true, inventory = true, pop = true, send = true, rec = true, receive = true,
    org = true, organize = true, drop = true, roe = true,
}
local DATA_ONLY_SUBCOMMANDS = {done = true, reset = true, recheck = true, status = true, config = true, list = true, help = true, capture = true, unstick = true}

-- //gh furrow <sub> -> furrow<sub>.
local FURROW_SUBCOMMANDS = {
    loop = 'furrowloop', full = 'furrowfull', duecheck = 'furrowduecheck', plant = 'furrowplant',
    fertilize = 'furrowfertilize', harvest = 'furrowharvest', inspect = 'furrowinspect',
    status = 'furrowstatus', config = 'furrowconfig',
}

-- True (and a chat line) when another operation is running.
local function busy()
    if state.running then
        log('Another operation is running. Use //gh stop first.')
        return true
    end
    return false
end

-- Start of a furrow command: close any leftover menu (a stray self-menu
-- would eat the first Enter; 'target clear' alone doesn't close menus)
-- and mark running.
local function begin_furrow_command()
    clear_cursor_state()
    windower.send_command('target clear')
    coroutine.sleep(0.2)
    state.running = true
    state.furrows_found = {false, false, false}
end

-- duecheck / furrowduecheck (for scripts/other addons): read-only check (existence
-- probe, no menus) of whether anything needs doing now. whole_garden
-- adds the daily nodes, books and due node fertilizer. Ends with
-- "DueCheckResult: ACTION_NEEDED" or "DueCheckResult: NOT_DUE next_epoch=N".
local function due_check(whole_garden)
    state.running = true
    reconcile_furrow_data(true)
    sync_module_status_flags()
    record_seed_inventory(eff('seed'))
    local actionable, earliest = furrow_due_info()
    local pending = {}
    if whole_garden then
        for _, prefix in ipairs(DAILY_NODE_MODULES) do
            if is_module_enabled(prefix) and not node_done_today(prefix) then
                table.insert(pending, prefix)
            end
        end
        if BOOKS.due() then
            table.insert(pending, 'books')
        end
        for _, prefix in ipairs(nodes_fert_due()) do
            table.insert(pending, prefix .. ' fertilizer')
        end
        local emp_due = ASSIST.emp.due()
        if emp_due then
            table.insert(pending, emp_due)
        end
    end
    if actionable or #pending > 0 then
        log('Action needed - ' .. (#pending > 0 and (table.concat(pending, ', ') .. ' not done yet today') or 'every furrow is ready, or one is empty / has no usable recorded data') .. '.')
        log('DueCheckResult: ACTION_NEEDED')
    else
        log('Nothing to do yet - next furrow check due around ' .. (earliest and os.date('%Y-%m-%d %H:%M:%S', earliest) or 'unknown') .. '.')
        log('DueCheckResult: NOT_DUE next_epoch=' .. (earliest or 0))
    end
    state.running = false
end

local function show_help()
    for _, line in ipairs({
        '=== Garden Furrows ===',
        '  furrow [seed] [fertilizer] [force] - one pass: harvest what is ready, plant what is empty, fertilize (if use_fertilizer). force = check every furrow live',
        '  furrowloop [seed] [fertilizer] [force] - the same, then wait the full growth time and repeat',
        '  furrow inspect [1|2|3|all] [preset|keys] - live check of each furrow (and act on it when inspect_takes_action); a preset/key list needs one furrow number',
        '  furrow done|reset [1|2|3|all] - done = record planted now with this character\'s seed; reset = UNKNOWN (checked live next time)',
        '  furrow recheck - clear this character\'s seed error (no seed in any bag; furrows skipped by //gh full and MuleLogger until cleared)',
        '  furrowplant [seed] / furrowfertilize [fertilizer] / furrowharvest - one action on every furrow in the right state',
        '  furrowstatus - detailed furrow status;  furrowconfig - runtime settings (no args lists them)',
        '  furrowduecheck - read-only: does a furrow need attention? (DueCheckResult line)',
        '=== Full Mog Garden ===',
        '  full [force|inspect|done|reset] - books, then furrows, vein, pond, grove, crystals (when holding ' .. config.crystals_full_threshold .. '+ of one), flotsam, net, with sells, then inv, RoE, memory check. force = ignore done-today data; inspect = live check of everything; done/reset = mark everything done / UNKNOWN',
        '  vein|pond|grove|flotsam|net [force|inspect|done|reset] - one node (and its fertilizer, when due after the harvest)',
        '  crystals [done|reset] - trade ALL crystals/clusters to the Ephemeral Moogle',
        '  ephstock - read and save the Ephemeral Moogle\'s stock (crystals stored per element; also shown in //gh status). Ends with EphStockResult',
        '  ephwithdraw <element> [stacks] - take full stacks of clusters (144 crystals = 12 clusters each) out of the Ephemeral Moogle (MuleLogger //ml eph). Ends with EphWithdrawResult',
        '  ephcapture on|off - log the Ephemeral Moogle\'s packets to data/ephemeral_packets.log (to check a withdrawal done by hand)',
        '  books [force|done|reset] - daily Skipper Moogle book check (sails to the Port and back); books = false in characters.lua skips it',
        '  sell - sell ItemTable.lua action "sell" items (and "save" above min_save), then drop. Mog Garden: walks to the Green Thumb Moogle. Anywhere else: preps them and sells at the next NPC vendor shop you open (sell cancel = call it off)',
        '  loaded - garden-loaded check now (arrival wait, target the Green Thumb Moogle, hold 1s, Escape, re-target, hold 1s); ends with GardenLoadedResult',
        '  enter - into the Mog Garden from a Port zone (Mog Dinghy) or the Mog House (needs config.mog_house_exit_keys)',
        '  duecheck - read-only: does anything need doing now? (for scripts/other addons)',
        '  status - one-line-per-module status;  pos - your X/Y and your target\'s, with an entities.lua line',
        '  assistants [force|status|list|done|reset|help] [kuyin|susuroon|yeestog] - put the garden assistants on the node/task characters.lua says (also: all of them at the start of every full run; the ones on that node for a single node/furrow command)',
        '  emp / employment [force|notify|extend|status|reset|capture|unstick|help] - assistant contracts: recruit with the unlock item (Kuyin Dragoneye, Susuroon Rusted Coin, Yeestog Fat Burrow Worm), spare items = +7 days, contract notices on, contract days read + flagged under ' .. (config.employment_extend_below_days or 30) .. ' days (also at the start of every full run); extend [days=30] = menus up to the weeks box, you type the weeks + Enter, it finishes (//ml extend = every character); extend target <days> = you are told the weeks for each assistant so all end within 7 days of <days>',
        '  roe [force|set|chat|list|status|help] - daily RoE objectives (characters.lua roe_objectives) + Unity chat line (unity_chat_message); also at the end of full',
        '=== Inventory (inv.lua) ===',
        '  inv - sell, drop, pop, send, rec, org;  drop / pop / send / rec / org - one step;  inv rebuild - re-sort ItemTable.lua after edits;  inv help - details',
        '=== Shared ===',
        '  memory [on|off|reset|status|gc|mark <note>] - memory used by every loaded addon (most on top, % vs. the oldest run), saved to memory_report.lua; on/off = also at the end of every full (saved); reset = clear memory_report.lua; gc = free GardenHelper\'s unused Lua memory now; mark <note> = marker line (per-character average starts over)',
        '  update [check|force] [major|minor] - download the newest GardenHelper from GitHub (thrydwolfvalefor/gardenhelper), back up the old files in backup/ and reload. major = full tested releases, minor = smaller changes sooner (default: characters.lua update_branch, else major); check = only compare versions; force = install even if not newer. Never touches characters.lua, ItemTable*.lua, Mail.lua or data/',
        '  stop (or abort) - stops after the current step (never mid-menu);  debug on|off - global, saved',
        'Active for this character: seed ' .. eff('seed') .. ', fertilizer ' .. eff('fertilizer') .. ' (' .. (eff('use_fertilizer') and 'ON' or 'OFF') .. '), wait ' .. math.floor(eff('fertilize_wait_time') / 60) .. ' min',
    }) do
        log(line)
    end
end

local function furrow_config_command(args)
    local opt, val = args[2] and args[2]:lower(), args[3]
    local override = get_character_override() or {}
    local function note(field)
        if override[field] ~= nil then
            log('  Note: this character has its own ' .. field .. ' in characters.lua, which still wins.')
        end
    end
    if opt == 'debug' then
        set_debug_mode(not config.debug_mode)
    elseif opt == 'selljunk' then
        config.sell_junk_enabled = not config.sell_junk_enabled
        log('Sell junk to moogle: ' .. (config.sell_junk_enabled and 'ON' or 'OFF') .. ' (until the next login/reload)')
    elseif opt == 'selllevel' and tonumber(val) and config.sell_checkpoints_by_level[tonumber(val)] then
        config.sell_level = tonumber(val)
        log('Sell level: ' .. val .. ' (until the next login/reload)')
    elseif opt == 'arrivalwait' and tonumber(val) and tonumber(val) >= 0 and tonumber(val) <= 120 then
        config.min_seconds_since_arrival = tonumber(val)
        log('Minimum wait since login/zone change: ' .. val .. 's (until the next login/reload)')
    elseif opt == 'seed' and val then
        config.default_seed = val
        log('Global default seed: ' .. val)
        note('seed')
    elseif opt == 'fertilizer' and val then
        config.default_fertilizer = val
        log('Global default fertilizer: ' .. val)
        note('fertilizer')
    elseif opt == 'usefertilizer' then
        config.use_fertilizer = not config.use_fertilizer
        log('Global use fertilizer: ' .. (config.use_fertilizer and 'ON' or 'OFF'))
        note('use_fertilizer')
    elseif opt == 'waittime' and tonumber(val) and tonumber(val) > 0 and tonumber(val) <= 180 then
        config.fertilize_wait_time = tonumber(val) * 60
        log('Global wait time: ' .. val .. ' minutes')
        note('fertilize_wait_time')
    elseif opt == 'show' then
        log('Global: seed ' .. config.default_seed .. ', fertilizer ' .. config.default_fertilizer .. ' (' .. (config.use_fertilizer and 'ON' or 'OFF') ..
            '), wait ' .. math.floor(config.fertilize_wait_time / 60) .. ' min, debug ' .. (config.debug_mode and 'ON' or 'OFF'))
        log('Sell junk ' .. (config.sell_junk_enabled and 'ON' or 'OFF') .. ', sell level ' .. config.sell_level ..
            ' (1 = end only, 2 = after Pond + end, 3 = after Furrow/Pond/Grove + end, 4 = after every module), arrival wait ' .. config.min_seconds_since_arrival .. 's')
        log('This character: seed ' .. eff('seed') .. ', fertilizer ' .. eff('fertilizer') .. ' (' .. (eff('use_fertilizer') and 'ON' or 'OFF') .. ')')
        local overridden = get_active_override_fields()
        if #overridden > 0 then
            log('  (characters.lua override for: ' .. table.concat(overridden, ', ') .. ')')
        end
    else
        log('furrowconfig options (until the next login/reload - edit the file to make them stick):')
        log('  debug | selljunk | usefertilizer - toggles;  seed <name> | fertilizer <name> | waittime <1-180 min>')
        log('  selllevel <1-4> | arrivalwait <0-120 s> | show')
    end
end

local function furrow_inspect_command(args)
    local furrow_arg = args[2] and args[2]:lower() or nil
    local only_number = (furrow_arg and furrow_arg ~= 'all') and tonumber(furrow_arg) or nil
    if furrow_arg and furrow_arg ~= 'all' and not (only_number and FURROWS[only_number]) then
        error_log('Furrow number must be 1, 2, 3, or "all" - got "' .. args[2] .. '".')
        return
    end
    local explicit_sequence, seq_err = parse_sequence(args[3])
    if seq_err then
        error_log(seq_err)
        return
    end
    if explicit_sequence and not only_number then
        error_log('A preset/key list needs one furrow number (1, 2 or 3) - on a furrow in another state it could pick the wrong option. Example: //gh furrowinspect 1 empty')
        return
    end
    begin_furrow_command()
    reconcile_furrow_data(true)
    ASSIST.begin_run()
    ASSIST.before_harvest('furrow')
    if not state.running then return end
    approach_furrow(1)
    if config.inspect_takes_action and not explicit_sequence then
        log('Inspecting live - anything ready gets harvested and replanted, anything empty gets planted.')
        run_single_furrow_pass(eff('seed'), eff('fertilizer'), true, only_number)
    else
        for _, furrow in ipairs(get_active_furrows()) do
            if not only_number or only_number == furrow.number then
                live_probe_furrow(furrow, explicit_sequence, tonumber(args[4]) or 3)
                coroutine.sleep(1)
            end
        end
    end
    sync_module_status_flags()
    state.running = false
    log('Inspect complete - see //gh furrowstatus.')
end

local function show_pos()
    local me = windower.ffxi.get_mob_by_target('me')
    local t = windower.ffxi.get_mob_by_target('t')
    local zone = current_zone()
    log('Zone ID: ' .. tostring(zone) .. ' (' .. tostring(zone_name(zone)) .. ')')
    if me then
        log('You (stand here): X: ' .. string.format('%.3f', me.x) .. ', Y: ' .. string.format('%.3f', me.y))
    end
    if not (t and t.id and t.id > 0) then
        log('No target (target something to also get its entities.lua line).')
        return
    end
    log('Target: ' .. t.name .. ' [' .. t.id .. ']  X: ' .. string.format('%.3f', t.x) .. ', Y: ' .. string.format('%.3f', t.y) ..
        (t.distance and ('  (' .. string.format('%.1f', math.sqrt(t.distance)) .. ' yalms away)') or ''))
    local known = ENTITIES_BY_ID[t.id]
    if known then
        log('  entities.lua has it as \'' .. tostring(known.friendly) .. '\' (zone ' .. tostring(known.zone) .. ', X: ' ..
            (known.x and string.format('%.3f', known.x) or 'nil') .. ', Y: ' .. (known.y and string.format('%.3f', known.y) or 'nil') .. ')')
        if known.zone ~= zone then
            error_log('  entities.lua zone for ' .. tostring(known.friendly) .. ' is ' .. tostring(known.zone) .. ' but you are in zone ' .. tostring(zone) .. ' - fix its zone.')
        end
    else
        log('  Not in entities.lua yet.')
    end
    if me then
        log("entities.lua: {friendly = '" .. t.name .. "', name = '" .. t.name .. "', zone = " .. tostring(zone) .. ', id = ' .. t.id .. ', x = ' .. string.format('%.3f', me.x) .. ', y = ' .. string.format('%.3f', me.y) .. '},')
    end
end

-- v2.22.0 (Mark): garden work only starts once the garden has loaded -
-- the normal arrival wait + the Green Thumb Moogle 2x check (once per
-- arrival). Not confirmed = the command does NOT run; prints
-- "GardenLoadedResult: FAILED" so MuleLogger stops waiting for it.
function ARRIVAL_WAIT_EXEMPT_COMMANDS.garden_loaded_gate(command, first_node_id)
    local ok, loaded = wait_for_entities_settled(first_node_id)
    if not ok then
        log('Stopped while waiting for the garden to load.')
        return false
    end
    if not loaded then
        error_log('The Mog Garden is not confirmed loaded - not running //gh ' .. tostring(command) .. '. Try again once it has loaded (//gh loaded checks it).')
        log('GardenLoadedResult: FAILED')
        return false
    end
    return true
end

local function garden_command(...)
    local args = {...}
    refresh_character_file()
    local command = args[1] and args[1]:lower() or ''
    local sub = args[2] and args[2]:lower() or nil

    -- //gh sell outside the Mog Garden is a vendor sale (prep now, sell at
    -- the next NPC shop), and //gh sell cancel never needs the garden - so
    -- neither goes through the garden-entry check. In the garden it still
    -- gets the arrival wait before walking to the Green Thumb Moogle.
    local vendor_sell = command == 'sell' and (not in_mog_garden() or sub == 'cancel' or sub == 'clear' or sub == 'stop')

    -- Garden commands: get into the Mog Garden first, then the arrival wait.
    if not ARRIVAL_WAIT_EXEMPT_COMMANDS[command] and not (sub and DATA_ONLY_SUBCOMMANDS[sub]) and not vendor_sell then
        if not in_mog_garden() then
            if busy() then return end
            state.running = true
            local entered = ensure_in_mog_garden(false)
            state.running = false
            if not entered then return end
        end
        local furrow_work = command:sub(1, 6) == 'furrow' or command == 'full' or command == 'force' or command == 'duecheck'
        if not ARRIVAL_WAIT_EXEMPT_COMMANDS.garden_loaded_gate(command, furrow_work and FURROWS[1].id or nil) then return end
    elseif ARRIVAL_WAIT_EXEMPT_COMMANDS.garden_check_if_there[command] and not (sub and DATA_ONLY_SUBCOMMANDS[sub]) and in_mog_garden() and not state.running then
        if not ARRIVAL_WAIT_EXEMPT_COMMANDS.garden_loaded_gate(command, nil) then return end
    end

    if command == 'furrowloop' or command == 'furrowfull' then
        if busy() then return end
        local force, rest = extract_force_arg(args, 2)
        local seed_name, fertilizer_name = rest[1] or eff('seed'), rest[2] or eff('fertilizer')
        begin_furrow_command()
        log('Starting ' .. (command == 'furrowloop' and 'automated cycle' or 'single pass') .. ' with ' .. seed_name ..
            (eff('use_fertilizer') and (' and ' .. fertilizer_name) or ' (fertilizer is OFF)') .. (force and ' (forced)' or ''))
        -- Existence only: handle_furrow_for_start detects and acts in one
        -- visit, and furrowloop reuses the list every cycle.
        reconcile_furrow_data(true)
        ASSIST.begin_run()
        ASSIST.before_harvest('furrow')
        if not state.running then return end
        approach_furrow(1)
        if command == 'furrowloop' then
            main_loop(seed_name, fertilizer_name, force)
        else
            run_single_furrow_pass(seed_name, fertilizer_name, force)
            state.running = false
            log('Single pass complete.')
        end

    elseif command == 'furrowduecheck' or command == 'duecheck' then
        if busy() then return end
        due_check(command == 'duecheck')

    elseif command == 'stop' or command == 'abort' then
        windower.ffxi.run(false)
        state.expecting_zone = false
        if state.running then
            log('Stopping all operations...')
            state.running = false
            state.current_action = nil
            coroutine.sleep(1)
            log('Stopped successfully')
        else
            log('No operations running')
        end

    elseif command == 'debug' then
        if sub == 'on' or sub == 'off' then
            set_debug_mode(sub == 'on')
        else
            log('Debug mode is ' .. (config.debug_mode and 'ON' or 'OFF') .. ' - use //gh debug on or //gh debug off')
        end

    elseif command == 'furrowplant' or command == 'furrowfertilize' or command == 'furrowharvest' then
        if busy() then return end
        begin_furrow_command()
        reconcile_furrow_data()
        ASSIST.begin_run()
        if command == 'furrowharvest' then
            ASSIST.before_harvest('furrow')
        end
        approach_furrow(1)
        if command == 'furrowplant' then
            local seed_name = args[2] or eff('seed')
            furrow_cycle('planting', {empty = true, fertilized_empty = true}, 'growing_unfertilized', function(f, fresh)
                if fresh == 'fertilized_empty' then
                    -- Fertilizer already in: planted = growing_fertilized.
                    local fert = saved_status['furrow_' .. f.number .. '_fertilizer']
                    local ok, lines = plant_seed(seed_name, f.number)
                    return ok, lines, seed_name, (fert ~= '' and fert or nil), 'growing_fertilized'
                end
                local ok, lines = plant_seed(seed_name, f.number)
                return ok, lines, seed_name
            end)
        elseif command == 'furrowfertilize' then
            local fertilizer_name = args[2] or eff('fertilizer')
            furrow_cycle('fertilizing', 'growing_unfertilized', 'growing_fertilized', function(f)
                local ok, lines = fertilize_furrow(fertilizer_name, f.number)
                return ok, lines, nil, fertilizer_name
            end)
        else
            -- Multi-harvest seeds that regrow are re-inspected, not left
            -- recorded as empty (furrowharvest never plants).
            furrow_cycle('harvesting', 'ready', 'empty', function(f)
                local ok, lines = harvest_furrow(nil, f)
                if ok then
                    return ok, lines, nil, nil, furrow_after_harvest(f, lines), true
                end
                return ok, lines
            end)
        end
        state.running = false

    elseif command == 'furrowinspect' then
        if busy() then return end
        furrow_inspect_command(args)

    elseif command == 'furrowstatus' then
        show_status()

    elseif command == 'furrowconfig' then
        furrow_config_command(args)

    elseif command == 'full' or command == 'force' then
        if command == 'force' then sub = 'force' end
        if busy() then return end
        if sub == 'done' or sub == 'reset' then
            set_full_done(sub == 'done')
        elseif sub == 'inspect' then
            log('Full inspect: checking every furrow and node live...')
            run_full_inspect()
        else
            if sub == 'force' then
                log('Force mode: ignoring "already done today" data for every module (furrows are checked live).')
            end
            run_full_garden_pass(sub == 'force')
        end

    elseif command == 'furrow' then
        -- //gh furrow [seed] [fertilizer] [force] = furrowfull; //gh furrow
        -- <sub> forwards to furrow<sub> (so "inspect" etc. are never taken
        -- as a seed name); reset/done are handled here.
        log('//gh furrow' .. (sub and (' ' .. sub) or '') .. ' is running')
        if sub == 'reset' or sub == 'done' then
            if busy() then return end
            if sub == 'reset' then reset_furrow_status(args[3] and args[3]:lower() or 'all') else mark_furrows_done() end
        elseif sub == 'recheck' then
            -- v2.17.0: clear the seed error (//ml furrow recheck does this
            -- for every character with one, then logs into each).
            FURROW_SYNC.clear_seed_error(false)
            sync_module_status_flags()
        elseif sub and FURROW_SUBCOMMANDS[sub] then
            garden_command(FURROW_SUBCOMMANDS[sub], unpack(args, 3))
        else
            garden_command('furrowfull', unpack(args, 2))
        end

    elseif command == 'sell' then
        -- Mog Garden: walk to the Green Thumb Moogle and sell. Anywhere
        -- else: prep the sale and sell at the next NPC shop opened. Ends with "SellResult: DONE / FAILED / BUSY / DISABLED /
        -- READY (waiting for a shop) / CANCELLED".
        if sub == 'cancel' or sub == 'clear' or sub == 'stop' then
            if INV.vendor_cancel() then
                log('Vendor sell cancelled - nothing will be sold when a shop opens.')
            else
                log('No vendor sell was waiting.')
            end
            log('SellResult: CANCELLED')
        elseif busy() then
            log('SellResult: BUSY')
        elseif not config.sell_junk_enabled or not is_module_enabled('sell') then
            log('Selling is off (config.sell_junk_enabled, or sell = false in characters.lua).')
            log('SellResult: DISABLED')
        elseif not in_mog_garden() then
            state.running = true
            local units, err = INV.vendor_prepare()
            state.running = false
            if units == nil then
                error_log('Sell: ' .. tostring(err))
                log('SellResult: FAILED')
            elseif units == 0 then
                log('Sell: nothing to sell in main inventory (ItemTable.lua action "sell" / "save" above min_save).')
                log('SellResult: DONE')
            else
                log('SellResult: READY')
            end
        else
            state.running = true
            local sold = sell_junk_to_moogle()
            state.running = false
            log('SellResult: ' .. (sold and 'DONE' or 'FAILED'))
        end

    elseif MODULE_HARVESTERS[command] then
        -- //gh <module> [force|inspect|done|reset]: force = even if done
        -- today; inspect = go and interact (harvests it if not done);
        -- done / reset = record done today / UNKNOWN.
        if busy() then return end
        local h = MODULE_HARVESTERS[command]
        if sub == 'reset' or sub == 'done' then
            set_module_done(command, sub == 'done', nil, true)
            return
        end
        if sub and sub ~= 'force' and sub ~= 'inspect' then
            error_log('Unrecognized argument "' .. args[2] .. '" - expected force, inspect, done or reset. Running a normal pass.')
        end
        local force = (sub == 'force' or sub == 'inspect')
        state.running = true
        -- Assistants set to this node, even when it's already done today.
        ASSIST.begin_run()
        ASSIST.before_harvest(command)
        if not state.running then return end
        run_with_inventory_restart(h.label, function() return h.fn(force) end)
        sync_module_status_flags()
        state.running = false
        if sub == 'inspect' then
            log(h.label .. ': ' .. node_status(command):gsub('_', ' '):upper())
        end

    elseif command == 'ephwithdraw' or command == 'ephw' then
        -- //gh ephwithdraw <element> [stacks] (v2.29.0, crystals.lua): full
        -- stacks of clusters (144 crystals = 12 clusters each) out of the
        -- Ephemeral Moogle into main inventory. Ends with
        -- "EphWithdrawResult: DONE / PARTIAL / FAILED / BUSY got=<clusters>" (MuleLogger).
        if busy() then
            log('EphWithdrawResult: BUSY got=0')
            return
        end
        local E = state.eph
        local elem = E and E.element(args[2])
        local stacks = math.floor(tonumber(args[3] or '') or 1)
        if not elem or stacks < 1 then
            error_log('Usage: //gh ephwithdraw <fire|ice|wind|earth|lightning|water|light|dark> [stacks] - each stack = 144 crystals (12 clusters).'
                .. (E and '' or ' (crystals.lua is not loaded)'))
            log('EphWithdrawResult: FAILED got=0')
            return
        end
        state.running = true
        local got, asked, why = E.withdraw(elem, stacks)
        state.running = false
        if why then error_log('Ephemeral Moogle: ' .. why .. '.') end
        local result = (got > 0 and not why) and 'DONE' or (got > 0 and 'PARTIAL' or 'FAILED')
        log('EphWithdrawResult: ' .. result .. ' got=' .. got .. ' asked=' .. ((asked or 0) * 12) .. ' element=' .. elem)

    elseif command == 'ephstock' then
        -- //gh ephstock (v2.29.0): asks the game for the Ephemeral Moogle
        -- stock and saves it. Ends with "EphStockResult: OK f,i,w,e,l,wa,li,d / FAILED".
        local E = state.eph
        local stock = E and E.fresh_stock(5)
        if stock then
            log('Ephemeral Moogle stock: ' .. E.text(stock) .. '.')
            log('EphStockResult: OK ' .. table.concat(stock, ','))
        else
            error_log('Ephemeral Moogle stock: no answer from the game' .. (E and '' or ' (crystals.lua is not loaded)') .. '.')
            log('EphStockResult: FAILED')
        end

    elseif command == 'ephcapture' then
        -- //gh ephcapture on|off (v2.29.0): log the Ephemeral Moogle's
        -- packets (talk, menu, choice, stock) to data/ephemeral_packets.log.
        if not state.eph then error_log('crystals.lua is not loaded.') return end
        if sub == 'on' or sub == 'off' then state.eph.capture = (sub == 'on') end
        log('Ephemeral Moogle packet capture is ' .. (state.eph.capture and 'ON' or 'OFF') .. ' (data/ephemeral_packets.log) - //gh ephcapture on|off.')

    elseif command == 'books' then
        if busy() then return end
        if sub == 'done' or sub == 'reset' then
            BOOKS.set_done(sub == 'done')
            sync_module_status_flags()
            return
        end
        state.running = true
        BOOKS.buy(sub == 'force')
        sync_module_status_flags()
        state.running = false
        log('Books pass complete.')

    elseif command == 'loaded' then
        -- //gh loaded (v2.18.0): the normal arrival wait, then the Green
        -- Thumb Moogle check (target, hold 1s, Escape, re-target, hold 1s)
        -- even if this arrival was checked before. Prints
        -- "GardenLoadedResult: OK / FAILED / NOTGARDEN / BUSY" (MuleLogger).
        if state.running then
            log('GardenLoadedResult: BUSY')
            return
        end
        if not in_mog_garden() then
            log('GardenLoadedResult: NOTGARDEN')
            return
        end
        state.running = true
        local ok, loaded = wait_for_entities_settled(nil, true)
        state.running = false
        log('GardenLoadedResult: ' .. ((ok and loaded) and 'OK' or 'FAILED'))

    elseif command == 'enter' then
        -- Prints "EnterGardenResult: OK/FAILED" (for scripts/other addons).
        if busy() then return end
        state.running = true
        local ok = ensure_in_mog_garden(true)
        state.running = false
        log('EnterGardenResult: ' .. (ok and 'OK' or 'FAILED'))

    elseif command == 'pos' then
        show_pos()

    elseif command == 'reloadstatus' then
        -- Re-read data/settings.xml (after another tool or you edited the file).
        local snapshot = {}
        for key in pairs(status_defaults) do snapshot[key] = saved_status[key] end
        if not reload_status_from_disk() then
            for key, value in pairs(snapshot) do saved_status[key] = value end
            error_log('Could not reload data/settings.xml - kept the in-memory status.')
        else
            log('Status data reloaded from data/settings.xml.')
        end

    elseif command == 'status' then
        show_garden_status()

    elseif INV.is_command(command) then
        -- //gh inv / pop / send / rec / org (inv.lua). 'auto' (scripts)
        -- = the automatic run (characters.lua step switches apply) and
        -- ends with "InvResult: DONE / FAILED / BUSY".
        local auto = INV.has_word(args, 'auto')
        if INV.is_help(args) then
            INV.help()
        elseif busy() then
            if command == 'gil' then
                log('GilResult: BUSY')
            elseif command == 'mailitem' then
                log('MailItemResult: BUSY sent=none')
            elseif auto then
                log('InvResult: BUSY')
            end
        else
            state.running = true
            local ok = INV.command(args)
            state.running = false
            sync_module_status_flags()
            if auto and command ~= 'gil' and command ~= 'mailitem' then log('InvResult: ' .. (ok and 'DONE' or 'FAILED')) end
        end

    elseif command == 'assistants' or command == 'assistant' or command == 'assist' then
        -- //gh assistants [force|status|list|done|reset|help] [name] (assistants.lua).
        local data_only = sub and DATA_ONLY_SUBCOMMANDS[sub]
        if not data_only and busy() then return end
        if data_only then
            ASSIST.command(args)
        else
            state.running = true
            ASSIST.command(args)
            state.running = false
        end

    elseif command == 'employment' or command == 'emp' or command == 'employ' then
        -- //gh emp [force|notify|status|reset|help] (employment.lua).
        local data_only = sub and DATA_ONLY_SUBCOMMANDS[sub]
        if not data_only and busy() then return end
        if data_only then
            ASSIST.emp.command(args)
        else
            state.running = true
            ASSIST.emp.command(args)
            state.running = false
            sync_module_status_flags()
        end

    elseif command == 'roe' then
        -- //gh roe (Set_RoE.lua). 'auto' ends with "RoEResult: ..." (BUSY if another operation runs).
        if busy() then
            for i = 2, #args do if args[i]:lower() == 'auto' then log('RoEResult: BUSY') end end
            return
        end
        state.running = true
        ROE.command(args)
        state.running = false

    elseif command == 'memory' or command == 'memprobe' then
        -- //gh memory [on|off|reset|status|gc|mark <note>] (memcheck.lua) - allowed during a run.
        MEMCHECK.command(args)

    elseif command == 'update' then
        -- //gh update [check|force] (Update.lua) - download the newest release from GitHub and reload.
        GH.update.command(args)

    elseif command == 'help' or command == '' then
        show_help()

    else
        error_log('Unknown command: ' .. command .. '. Use //gh help for available commands.')
    end
end

-- Chat lines from these addons never count as a menu response (they
-- print through the same 'incoming text' event).
local IGNORED_CAPTURE_PREFIXES = {'GardenHelper:', 'MuleLogger:', 'ROE Notice:'}  -- other addons' own lines, never game text

-- Player chat is never a menu response either: Unity "{Name} ...",
-- linkshell "<Name> ..." / "[1]<Name> ...", party "(Name) ...", tells
-- "Name>> ..." / ">>Name ...". A Unity line arriving mid-sequence used to
-- end an Enter's wait early (v2.10.0). Kept on the prefix table (.chat,
-- skipped by ipairs) - the main chunk is at Lua's 200-local limit.
IGNORED_CAPTURE_PREFIXES.chat = {'^{[%a]+}', '^<[%a]+>', '^%[%d%]<[%a]+>', '^%([%a]+%)', '^[%a]+>>', '^>>[%a]+'}

local function is_ignored_capture_line(text_line)
    for _, prefix in ipairs(IGNORED_CAPTURE_PREFIXES) do
        if text_line:find(prefix, 1, true) then
            return true
        end
    end
    local plain = strip_timestamp_prefix(text_line)
    for _, pattern in ipairs(IGNORED_CAPTURE_PREFIXES.chat) do
        if plain:find(pattern) then
            return true
        end
    end
    return false
end

-- Captures text only while state.capturing_text is on; never alters or
-- blocks chat.
windower.register_event('incoming text', function(original, modified, original_mode, modified_mode, blocked)
    if state.capturing_text then
        local text_line = modified or original or ''
        if not is_ignored_capture_line(text_line) then
            table.insert(state.captured_lines, text_line)
        end
    end
    -- Every "Target out of range." is counted, captured or not, so any
    -- interaction can tell it was refused (GH.range_retry).
    if lines_contain({original or ''}, config.out_of_range_phrases) then
        state.out_of_range_count = (state.out_of_range_count or 0) + 1
    end
    -- The game's daily "There are N days left on X's contract." (employment.lua).
    pcall(ASSIST.emp.on_text, original or '')
    -- Shining Stars (v2.25.0): first login / garden visit of the day -
    -- "1 star on your GPS crystal has come aglow.<BEL>A total of 25 stars
    -- twinkle softly inside your GPS crystal." Saved 2s later and only if
    -- the same character is still logged in (the login event swaps
    -- saved_status to the new character first).
    local star_line = original or ''
    local stars = star_line:find('GPS crystal', 1, true) and star_line:match('A total of (%d+) stars?')
    if stars then
        local p = windower.ffxi.get_player()
        local who = p and p.name
        coroutine.schedule(function()
            local now_p = windower.ffxi.get_player()
            if not who or not now_p or now_p.name ~= who then
                return
            end
            saved_status.shining_stars = tonumber(stars)
            saved_status.shining_stars_at = os.date('%Y-%m-%d %H:%M:%S')
            pcall(persist_status)
            log('Shining Stars: ' .. stars .. ' (GPS crystal) - saved.')
        end, 2)
    end
end)

windower.register_event('addon command', garden_command)

-- Releases every key GardenHelper presses with setkey, so a run stopped
-- between 'down' and 'up' (//gh stop, //lua r, zoning) can't leave one
-- held (2026-09-27: Enter stuck down after a stopped employment run).
-- (A field on state: the main chunk is at Lua's 200-local limit.)
state.release_keys = function()
    for _, k in ipairs({'enter', 'escape', 'up', 'down', 'left', 'right', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}) do
        windower.send_command('setkey ' .. k .. ' up')
    end
end
state.release_keys()

windower.register_event('unload', function()
    state.release_keys()
    windower.ffxi.run(false)
    if state.running then
        log('Addon unloading - stopping all operations')
        state.running = false
    end
end)

-- A new character logging in keeps this addon's Lua state: reset run
-- state, reload saved_status and restore the furrowconfig defaults.
windower.register_event('login', function(name)
    refresh_character_file()
    state.running = false
    state.current_action = nil
    state.start_time = nil
    state.fertilize_time = nil
    state.furrows_found = {false, false, false}
    state.capturing_text = false
    state.captured_lines = {}
    state.available_furrows = nil
    state.available_furrows_checked_at = nil
    state.last_arrival_epoch = os.time()
    state.expecting_zone = false
    state.inventory_full_hit = false
    saved_status = winconfig.load(status_defaults)

    for key, default_value in pairs(config_defaults) do
        config[key] = default_value
    end

    debug_log('State reset on login: ' .. tostring(name))
    state.storage.record_later(15)   -- v2.26.0: bags load after login
end)

-- Logging out stops whatever is running.
windower.register_event('logout', function()
    if state.running then
        log('Logging out - stopping all operations')
        state.running = false
        state.current_action = nil
    end
    state.available_furrows = nil
    state.available_furrows_checked_at = nil
end)

-- Leaving the garden stops whatever is running (unless GardenHelper
-- zoned on purpose - state.expecting_zone) and clears the furrow list.
windower.register_event('zone change', function(new_zone_id, old_zone_id)
    if state.running and not state.expecting_zone then
        log('Zone changed - stopping all operations')
        state.running = false
        state.current_action = nil
    end
    state.zone_change_count = (state.zone_change_count or 0) + 1
    state.zone_changed_to = new_zone_id
    state.zone_changed_epoch = os.time()
    state.available_furrows = nil
    state.available_furrows_checked_at = nil
    state.last_arrival_epoch = os.time()
    state.storage.record_later(10)   -- v2.26.0
end)

-- v2.28.0: Kitron Macaron count follows item changes.
windower.register_event('add item', state.km.item_event)
windower.register_event('remove item', state.km.item_event)

log('GardenHelper v' .. _addon.version .. ' loaded. Use //gh help for commands.')
state.storage.record_later(3)   -- v2.26.0: already logged in when loaded

--[[ Recent changes (full history: CHANGELOG.md)
  v1.92.0 (2026-09-24) - Node fertilizer (vein/pond/grove/net_fertilizer in
    characters.lua), used once a day after that node's harvest.
  v2.0.0 (2026-09-24) - Inventory (//gh inv/pop/send/rec/org, inv auto ->
    InvResult) built in; ItemTable.lua and Mail.lua live in this folder.
    Books and crystals split into books.lua / crystals.lua. Node
    fertilizer is used on the next pass after an earlier harvest, counted
    as due in duecheck, never before the day's harvest, max
    node_fertilize_daily_attempts failed tries a day. //gh debug no longer
    resets on login. Code cleaned up (~12,600 -> ~4,800 lines).
  v2.0.1 (2026-09-24) - Node fertilizer: Enter closes the game's "You
    baited the net with ..." message box (node_fertilize_close_enters),
    which was left open and stalled //gh net.
  v2.0.2 (2026-09-25) - A furrow fertilized but with no seed ("...as
    fertilizer, but is devoid of seeds.") is its own state,
    fertilized_empty: the pass picks "Absolutely nothing", plants the seed
    (no second fertilize) and records a harvest time.
  v2.1.0 (2026-09-25) - Selling and dropping come from ItemTable.lua
    (inv.lua v4.0.0) - no separate sell/drop addon needed. New //gh drop;
    //gh inv = sell, drop, pop, send, rec, org.
  v2.1.1 (2026-09-25) - //gh help lists //gh inv rebuild (re-sorts
    ItemTable.lua by action, type, name after hand edits).
  v2.2.0 (2026-09-25) - //gh sell at any NPC vendor: outside the Mog
    Garden it preps the items, logs "SellResult: READY" and sells as soon
    as a vendor's shop opens, then drops action "drop" items.
    //gh sell cancel calls a waiting sale off.
  v2.2.1 (2026-09-25) - Fix: //gh sell outside the Mog Garden stopped
    with "[ERROR] Not in the Mog Garden" before the vendor prep.
  v2.3.0 (2026-09-26) - First public release. Personal references removed
    from comments, help and messages; companion-addon notes made generic
    (duecheck / EnterGardenResult / InvResult / SellResult lines are still
    printed for anyone scripting around GardenHelper). Shipped with a
    starter characters.lua and ItemTable.lua (mail dry run ON, auto_drop
    OFF; inv.lua v4.3.0: a NEW ItemTable.lua defaults auto_drop to off).
    No other behaviour changes.
  v2.4.0 (2026-09-26) - RoE objectives + Unity chat built in (new module
    Set_RoE.lua, no RoE addon needed). characters.lua roe_objectives =
    {ids} (defaults or per character) are accepted once per garden day
    with the RoE packets (0-progress objectives outside the list are
    cancelled if slots run out), then unity_chat_message goes to /u -
    max 1 per 10 min per character, only while a Unity Communique is
    active. Switches set_roe / unity_chat in characters.lua modules.
    //gh roe [force|set|chat|list|status|help|auto] (auto -> RoEResult),
    runs at the end of //gh full (config.roe_in_full), //gh status row
    "RoE / Unity".
  v2.4.1 (2026-09-26) - Set_RoE.lua v1.1.0: the Unity chat limit is
    unity_chat_min_interval_seconds in characters.lua (defaults, or per
    character in overrides; 600 if not set, never below 60) instead of
    a config value in Set_RoE.lua.
  v2.4.2 (2026-09-26) - Multi-harvest seeds (e.g. arborfruit): inspecting
    a growing furrow can show a 3rd line "...should sprout about N more
    times." - the exit now reads it and presses Enter (opens "What will
    you do?"), Right to "Absolutely nothing", Enter, instead of Down,
    Down, Enter. Normal seeds unchanged. //gh furrowinspect preset
    "sprouting"; config.sprout_menu_settle_seconds (1.0).
  v2.5.0 (2026-09-26) - Memory check on all loaded addons (new module
    memcheck.lua): runs //lua memory, hides its lines, prints the addons
    sorted by memory used (most on top) with % vs. the addon's value in
    the oldest run in memory.lua, and appends the run to memory.lua (a
    blank line between runs). //gh memory [on|off|reset|status]; runs as
    the last step of //gh full while config.memory_check_in_full is on
    (//gh memory on/off saves the choice in data/memory_check.lua).
  v2.5.1 (2026-09-26) - Memory check also reads pol.exe's memory (the
    whole game: addons + plugins + overlays + FFXI) - private MB, RAM
    and virtual, % on private vs. the oldest run - through a small
    memcheck_pol.vbs (written by memcheck.lua, run by Windows Script
    Host, no console window). config.memory_check_game_total (true).
  v2.5.2 (2026-09-26) - Memory report: every row (Total Lua, pol.exe,
    each addon) shows Memory, Growth (amount, KB or MB) and Growth %
    vs. the oldest run, in chat and in memory.lua (column header row).
  v2.6.0 (2026-09-26) - Multi-harvest seeds (e.g. arborfruit) when READY:
    the harvest presses one extra Enter only after the "...should sprout
    about N more times." line (Enter rank, Enter matured, Enter sprout
    line, Enter menu, Enter Yes/No, Enter confirm). N counts the crop
    being harvested: N = 1 -> last harvest, furrow empty, plant as
    usual; N > 1 -> the plant regrows, so no planting/fertilizing - the
    furrow is inspected live to record the next harvest time and the
    harvests left (new furrow_N_harvests_left, shown in //gh status and
    the furrow lines). Inspect exit of a ready multi-harvest furrow:
    Enter (sprout), Enter (menu), Down, Enter (Down not seen live yet);
    preset "sprouting_ready". config.multi_harvest_fertilize (false) =
    don't fertilize a growing multi-harvest seed (also left out of the
    due check). Live-detected growing furrows now record the sprout line.
  v2.6.1 (2026-09-26) - Vein double check: before deciding the highest
    rank, each candidate vein is targeted, then checked again 1s later
    (still loaded, valid target, still targeted). A vein that flickers
    in (e.g. #4 seen, "Walking to 4a", then only #2 there) is skipped
    before walking. config.ranked_double_check = {vein = true, grove =
    false}, ranked_double_check_seconds = 1.
  v2.7.0 (2026-09-26) - Double check on the way, for every garden
    object (vein, grove, pond, net, flotsam, Ephemeral Moogle, furrows):
    no 1s stall before walking - the object must be targetable to
    start, is re-checked every 1s while walking (gone = stop walking
    and pick the next variant / rank from where you are) and once more
    on arrival, at least 1s after the first check. New walk_confirmed;
    position_at_node takes a 5th arg (module key) to use it;
    navigate_to_entity passes walk options to walk_to_xy.
    config.double_check_before_walk (per module, all on) and
    double_check_seconds (1) replace ranked_double_check(_seconds).
  v2.7.1 (2026-09-26) - Memory check fix: "lua memory" sent from the
    addon printed nowhere GardenHelper could read (live: "No reply" on
    Fishvf/Seedsvf, so memory.lua was never written). Now it retries as
    typed chat input (//lua memory); memory.lua is created on load and
    every run is written, even with only the pol.exe row.
  v2.7.2 (2026-09-26) - The memory check report file is now
    memory_report.lua (only the reports go there); an existing
    memory.lua report is renamed to it on load.
  v2.7.3 (2026-09-26) - Memory check gets every addon's numbers:
    //lua memory prints only to the Windower console, so they are read
    from console.log (Windower's console log) - or, when that has
    nothing, from memprobe.lua run inside each addon via "lua invoke
    <addon> dofile" (it answers with //gh memprobe <KB> <name>).
  v2.8.0 (2026-09-26) - //gh full reordered (Mark): Books -> Furrow ->
    Vein -> Pond (sell at sell_level 2) -> Grove -> Crystals -> Flotsam
    -> Net -> inv -> RoE -> memory check. Books run first (stops the
    pass if the trip doesn't end back in the garden).
    inventory_after_full now defaults to true and its sell step is the
    end-of-pass sell (no separate sell after Net while it's on). The
    last line reads "Full Mog Garden pass complete (inventory done)."
    when inv ran, so MuleLogger skips its own //gh inv auto.
    entities.lua: new standing X/Y for Pond, Ephemeral Moogle, Mog
    Dinghy (garden) and Coastal Fishing Net (from GenPopVF //gh pos).
  v2.8.1 (2026-09-26) - Garbage collection (Mark): at the end of every
    //gh full, GardenHelper runs collectgarbage('collect') on its own Lua
    memory (config.gc_at_end_of_full, default true); a manual //gh memory
    does it first too. memory_report.lua gets a "GC:" line per run
    (before -> after, freed), "GC freed" in the run header, and a
    one-time ">>>>> From Run N on" marker above the first run with it.
    New row "pol.exe virtual (address space)" with growth vs. the oldest
    run (base taken from the old runs' pol.exe detail line).
    //gh memory gc = collect now and show what it freed.
  v2.8.2 (2026-09-26) - Memory report "Per character:" line (Mark):
    average pol.exe growth (private and virtual MB) per //gh full run -
    one per character - since the last ">>>>>" marker and since the
    oldest run (needs 2+ runs). //gh memory mark <note> writes a marker
    line (e.g. which addons were unloaded) so each test gets its own
    average.
  v2.8.3 (2026-09-26) - Faster //gh rec / send (inv.lua v4.4.0, Mark):
    no more waiting as if a full box were loading. After the box opens,
    the wait ends once no box packet has come in for
    mail_open_quiet_seconds (new, 1; mail_open_settle_seconds 3 is now
    the max). rec stops pulling at the first pull that brings nothing
    (nothing queued) instead of trying every empty slot, and the slot
    read stops once replies stop coming in.
  v2.8.4 (2026-09-26) - No more blind furrow harvests (Mark): when the
    recorded data says a furrow is ready, the harvest now inspects it
    first (Enter, Enter) and only goes on if the game says "has
    matured!". Otherwise it backs out, records the real state and time
    ("in about N hours...") and skips it. Seen on SeedsVF: an arborfruit
    harvested by hand kept its old "ready at 9:05am" record, so the next
    pass pressed the whole harvest sequence on a growing furrow. Same
    number of key presses as before when the furrow really is ready.
    Covers //gh full / furrow / furrowloop and //gh furrowharvest. Found
    empty instead -> the full/furrow pass plants it.
  v2.9.3 (2026-09-27) - Memory check on/off has one home (Mark): the
    memory_check_in_full line in the config above is commented out -
    it was silently overridden by data/memory_check.lua. That file
    (written by //gh memory on|off, created as off if missing) is now
    the only on/off for the memory check at the end of //gh full.
  v2.10.0 (2026-09-27) - Furrows stay on the same timing (Mark: furrow 3
    kept getting harvested/planted a login later than 1 and 2). Logs
    showed three causes, all fixed:
    - A late or repeated chat line (the client re-fires lines with a
      [HH:MM:SS] stamp; Unity chat "{Name} ...") ended an Enter's wait
      before "has matured!" came in, so a READY furrow read as growing.
      Its growing exit keys then left the harvest prompt open, the NEXT
      furrow's first Enter harvested it, and that next furrow was never
      touched ("could not be classified"). Repeats and player chat no
      longer count as a reply; a planted furrow's inspect now waits for
      its second line (has matured / agrarian experience), pressing
      Enter once more if only the rank line came
      (furrow_detect_second_line_wait).
    - No reply at all to the inspect keys right after planting the
      previous furrow (or just after login): the furrow is targeted again
      and retried (furrow_detect_no_text_retries, _retry_wait).
    - After an inventory-full sell, the first Enter hands over the rest
      of the crop with no rank line - now counted as the harvest, so the
      furrow is replanted right away.
    Plus: any furrow still ready / unknown / empty at the end of the pass
    gets one more try at once (furrow_retry_missed). The furrow ETA saved
    for MuleLogger is now when the LAST furrow is ready (was the soonest),
    and in a normal pass a ready furrow waits for a still-growing one
    (furrow_sync_hold), so every furrow is harvested on one login. Furrows
    more than harvest_time apart (e.g. a 48h seed) aren't held.
  v2.10.1 (2026-09-27) - A Delivery Box that opened late stayed open
    (inv.lua v4.4.2). rec gave up after 5s ("the Delivery Box (receive)
    did not open"), the box opened a moment later, and MuleLogger's
    /logout was refused with the box still up (Woodvf 9/26 18:25, 9/27
    15:38). The open now waits up to mail_open_timeout_seconds (new, 10)
    and a failed open sends Close anyway. Pairs with MuleLogger v2.8.1.
  v2.11.0 (2026-09-27) - Assistant contracts (new employment.lua, Mark):
    //gh emp / employment [force|notify|status|reset|help], and at the
    start of every full run (before the assistant check). Recruits an
    assistant whose unlock item is in any bag (Kuyin Dragoneye, Susuroon
    Rusted Coin, Yeestog Fat Burrow Worm - pulled into inventory, traded
    to the Green Thumb Moogle, scene pressed through) and hires it right
    away for rehire_weeks (characters.lua, default 9). Spare unlock items
    are traded for +7 free days. The game's daily "There are N days left
    on X's contract." line is read whenever it shows; none today = the
    notices are set to "Always notify me". Contracts under 7 days (or
    never read) are extended by rehire_weeks after a gil check. Data in
    settings.xml (employ_...), every hire/trade in
    data/employment_history.log, rows in //gh status, and //gh duecheck
    reports employment work. Pairs with MuleLogger v2.9.0 (|A1 y|).
  v2.11.1 (2026-09-27) - Weeks box (Genpopvf 18:09): the 9 never showed,
    the box got Enter 2.3s after the "Hire" line with nothing in it and
    went back to the assistant list. Now waits
    employment_number_box_settle_seconds (2.5) for the box, holds the
    digit employment_digit_hold_seconds (0.25), waits
    employment_after_digit_seconds (1.5) before Enter.
    employment_weeks_input = 'up' presses Up once per week instead.
    notify nav default is now 'bottom' (Right Right Up). A first hire
    that failed is retried at the next run (employ_<name>_hire_pending).
    Typing the digit with setkey never reaches the box (18:12 retry,
    same empty box), so employment_weeks_input now defaults to 'up'
    (Up once per week), and the quote's week count must match or it
    backs out without buying.
  v2.12.0 (2026-09-27) - Hires go by packet (employment.lua). The weeks
    box only takes real typing and is client-side: packet captures
    (Genpopvf 19:28-19:34, //gh emp capture) show one choice per hire,
    weeks * 256 + 28 + assistant (Kuyin 0, Susuroon 1, Yeestog 2), after
    27 (list opened) and before 1, 11, 11 (end). GardenHelper now talks to
    the moogle with the menu window held back and sends exactly those,
    then checks the new contract time the server sends back and the gil.
    Every talk to the Green Thumb Moogle (sells too) also updates every
    assistant's contract days from the menu data (exact seconds), so the
    menu is only opened to read them when nothing fresh is saved.
    Removed: the weeks-box key settings. New: employment_menu_id (1016),
    employment_packet_wait_seconds (5).
  v2.12.1 (2026-09-27) - Hire fix (Cookvf 20:42: "hire was not confirmed",
    then the Dragoneye pull failed and the next talk showed a scene):
    holding the moogle's menu window back got no answer from the server
    and left the talk open. The menu now opens normally (scenes pressed
    through first), the hire choices are sent while it is on screen, and
    the talk is closed with Escape if still open. Every hire's packets go
    to data/employment_packets.log; the error says which step got no
    answer. Item pulls/trades wait for any open talk to end first.
  v2.13.0 (2026-09-27) - Contract extensions by hand, with help (Mark).
    Nothing GardenHelper can send reaches the weeks box (setkey digits,
    Up, Windower's typed text - goes to /say - and injected menu
    packets, which the server ignores: Cookvf 21:03), so automatic
    hires are gone, including the first hire after recruiting.
    //gh emp extend [days=30] [auto]: for each recruited assistant under
    that many days, the menus are opened up to the empty weeks box, a
    chat prompt asks you to type the weeks + Enter, then GardenHelper
    confirms "Is this sufficient?" and records the new contract; next
    assistant. auto ends with "ExtendResult: DONE|NONE|FAILED" for
    MuleLogger's //ml extend. The full-run step now only flags
    contracts with employment_extend_below_days (7) or fewer days left
    (employ_extend_due, //gh status row, MuleLogger A x). New
    employment_manual_wait_seconds (300); removed the packet-hire
    settings and //gh emp test.
  v2.13.1 (2026-09-27) - Added employ_extend_due = '' to the status
    defaults. Without a default, the empty <employ_extend_due /> in the
    global settings block loaded as a table, and each character's
    string value then logged "Mismatched setting types for key
    'employ_extend_due': table string" on load.
  v2.14.0 (2026-09-27) - "Target out of range." -> walk closer and try
    again, everywhere in the garden (Mark). Fishvf 22:04: the Green
    Thumb Moogle refused three Enters at 4.5 yalms (the X/Y walk stops
    anywhere inside interact_distance, 5.5) and employment gave up with
    "did not open its menu after 3 tries". Nodes, furrows, flotsam,
    fertilizer /item and the sell talk already walked closer; now the
    rest do too, through the new shared GH.range_retry: employment's
    moogle talk and item trades, the assistant talks, the Ephemeral
    Moogle crystal trades, and the Mog Dinghy / Skipper Moogle (books).
    Each refusal walks to 3.0 yalms, then 1.5, then gives up
    (out_of_range_walk_distances / out_of_range_max_retries). Every
    "Target out of range." line is now counted whether or not text is
    being captured (state.out_of_range_count).
  v2.15.0 (2026-09-27) - //gh gil <name> <amount> (inv.lua v4.5.0):
    mails gil through the Delivery Box to a character on the same
    account (1m / 500k / 250000) and ends with "GilResult: SENT /
    FAILED / BUSY". //gh rec takes gil even when main inventory is
    full. Used by MuleLogger's //ml cash.
  v2.15.1 (2026-09-28) - Waypoints for the X/Y walker (Mark). A
    character got stuck on a wall near the grove walking to the
    Ephemeral Moogle. entities.lua entries can now list via = {{x, y},
    ...}: each point is walked first, in order, and skipped when you're
    already closer to the destination than it is. Ephem gets one at
    X -11.275, Y -13.051 (//gh pos, Bonevf).
  v2.16.0 (2026-09-28) - //gh mailitem <item> <name>:<count> ...
    (inv.lua v4.6.0): mails exact amounts of one item to several
    characters in one Delivery Box visit until the list is done or the
    outbox is full. Ends with "MailItemResult: DONE / FULL / FAILED /
    BUSY sent=name:count,... free=N". Used by MuleLogger's //ml humus.
  v2.16.1 (2026-09-28) - Longer mail waits (inv.lua v4.6.1, Mark: errors
    in //ml humus while previous sent stacks were still clearing): new
    config mail_after_send_wait_seconds (3), mail_after_confirm_wait_seconds
    (3), mail_before_close_wait_seconds (5). Applies to all sending.
  v2.16.2 (2026-09-28) - The outbox really clears before it is filled
    (inv.lua v4.6.2, Mark: //ml humus on Woodvf put new stacks in while
    the rest of the received ones were still leaving). After Confirm,
    the outbox is re-read until every received stack is gone (max
    mail_outbox_clear_timeout_seconds, 30), and a stack the outbox
    refuses is retried after mail_set_retry_wait_seconds (3), up to
    mail_set_retries (3). Applies to all sending.
  v2.16.3 (2026-09-28) - Waits for ALL 8 received stacks to leave the
    outbox (inv.lua v4.6.3, Mark: //ml smart on Woodvf - the game had
    already confirmed them itself, so v2.16.2 read the slots once and
    put the Arborscent Seed in while the rest were still leaving; Send
    got EF "Communications seem to be congested"). The outbox is
    re-read until all slots are empty or unchanged for
    mail_outbox_stable_seconds (new, 5); mail_outbox_clear_timeout_seconds
    now 60. New: mail_send_retries (3) - a refused Send is retried;
    mail_open_retries (2) / mail_open_retry_wait_seconds (5) - a box
    that won't open ("try again in a little while") is tried again.
  v2.17.0 (2026-09-30) - Missing seeds (Mark): when the seed isn't in
    main inventory at planting time it is taken out of the other bags
    (inv.lua v4.7.0 INV.pull_item - case, satchel, sack, wardrobes, Mog
    House bags when reachable), enough for every furrow. Same for
    fertilizer. Seed in no bag at all = SEED ERROR saved in settings.xml
    (furrow_seed_error / furrow_seed_error_at): //gh full skips the
    furrows, duecheck and the furrow ETA don't count them (MuleLogger
    won't log in for them), //gh status shows it. Cleared by
    //ml furrow recheck (MuleLogger v2.20.0), //gh furrow recheck, or a
    manual //gh furrow that plants successfully.
  v2.18.0 (2026-10-01) - Garden-loaded check (Mark): after the normal
    arrival wait (min_seconds_since_arrival) the Green Thumb Moogle check
    is now: settarget him, the target must hold 1s
    (arrival_target_hold_seconds), Escape drops the cursor, settarget
    again right away, it must hold another 1s -> garden is loaded. (Was
    3 target/hold 2s/target clear rounds; arrival_confirm_rounds is
    gone.) A failed check now says why (not loaded, or more than 50
    yalms away - SetTarget's limit) and is not remembered as passed.
    A late check still polls at least arrival_min_poll_seconds (20).
    New //gh loaded: the check on demand, even if already passed, ends
    with "GardenLoadedResult: OK / FAILED / NOTGARDEN / BUSY" - used by
    MuleLogger v2.26.0 after every login and before every humus send.
    inv.lua v4.9.0: "Delivery Box did not open" says whether the box
    answered (and its result code) or sent no reply at all.
    inv.lua v4.9.1: mail_debug (on for now) prints every Delivery Box
    packet raw - server replies even when not listening, and every
    0x04D marked GH (injected) or GAME (box opened by hand).
  v2.20.0 (2026-10-01) - Net route (Mark): the walk to the Coastal
    Fishing Net got stuck on the stable and chairs. Starting from the
    Green Thumb Moogle, a furrow, a vein or the pond, it now goes
    Green Thumb Moogle -> Flotsam -> Net. entities.lua: via waypoints
    can name an entry ({key = 'Flotsam'}); new via_from (list of
    entries) + via_from_radius (6) limit the route to walks starting
    near one of them, walked in full and in order. Notes in CHANGELOG.md.
  v2.21.0 (2026-10-03) - Smoother garbage collection (Mark): the
    end-of-full GC froze the game, longer and longer as more characters
    were done (turned off for now: gc_at_end_of_full = false). memcheck.lua
    now collects in small steps (gc_step_kb, gc_step_wait_seconds) in the
    background, so "pass complete" and the logout after it aren't held
    up; skipped when less than gc_min_garbage_kb has built up; stops
    after gc_max_seconds. GC: lines (debug, //gh memory gc, memory_report)
    now show steps, total ms and the longest step. Notes in CHANGELOG.md.
  v2.21.1 (2026-10-03) - //ml extend / //gh emp extend (Mark): the sound
    came 1-2s before GardenHelper started watching, so 9 + Enter typed
    right away was never seen (it sat out the 300s wait). It now starts
    watching before the sound, and the box opens 0.4s after it
    (employment_alert_lead_seconds, was 1s). Notes in CHANGELOG.md.
  v2.22.0 (2026-10-03) - Garden must be loaded first, always (Mark):
    every garden command waits for the normal load time + the Green
    Thumb Moogle 2x check (target, hold 1s, Escape, re-target, hold 1s)
    before doing anything. Never skipped any more (the "loaded 60s+
    ago" and "addon reloaded" skips are gone); a pass is remembered for
    that arrival only. Not confirmed = the command does NOT run (was
    "carrying on anyway") and prints GardenLoadedResult: FAILED.
    inv / pop / send / rec / org / drop / roe / books now do the check
    too when used in the garden. Moogle loaded but over 50 yalms away =
    walk closer and check again. arrival_give_up_seconds 60 -> 180;
    new arrival_walk_to_moogle_yalms (30). //gh enter only answers OK
    once the garden has loaded. Notes in CHANGELOG.md.
  v2.23.0 (2026-10-03) - //gh emp extend target <days> (Mark): for
    //ml extend lining all assistants up to end at about the same time.
    Each assistant gets the whole weeks that bring it within 7 days of
    <days> without going past (assistants already within 7 days are
    left alone); the prompt and the sound say the number to type
    ("TYPE 6 AND PRESS ENTER NOW"). A different number typed is backed
    out before sealing (nothing paid) and the box opens once more. Over
    9 weeks = another round (employment_max_weeks_per_hire, 9). Plain
    //gh emp extend [days] unchanged. Notes in CHANGELOG.md.
  v2.24.0 (2026-10-09) - Vein/Grove rank fix (Mark): V and G in
    //gh status / //ml status showed which of the 4 vein/grove objects
    was harvested (#1-#4), not the garden rank - Shadowhammer showed V4
    with a rank 7 vein. The rank is now read from the game's own line
    ("This mineral vein is rank 7." / "This grove of trees is rank
    7."). Not seen = the saved rank is kept. Harvesting is unchanged.
    Each character's V/G corrects itself on its next harvest. Notes in
    CHANGELOG.md.
  v2.25.0 (2026-10-09) - Shining Stars tracking (Mark): the GPS crystal
    line on the first login / garden visit of the day ("A total of 25
    stars twinkle softly inside your GPS crystal.") is read and saved
    per character (shining_stars, shining_stars_at in data/settings.xml).
    //gh status has a new "Shining Stars" row; MuleLogger v2.36.0 shows
    it as |S  25| after the M column. Not seen yet = -1 / "not seen
    yet". Notes in CHANGELOG.md.
  v2.26.0 (2026-10-09) - Storage bag tracking (Mark): each character's
    Storage size (0-80 slots; 0 = none) is read from the client 15s
    after login, 10s after every zone change, on load and on //gh
    status, and saved per character when it changes (storage_slots,
    storage_slots_at in data/settings.xml). //gh status has a new
    "Storage" row ("80 of 80 slots" / "not read yet"); MuleLogger
    v2.37.0 shows it as |Str80| / |Str 5| / |Str 0| after the S column.
    Notes in CHANGELOG.md.
  v2.27.0 (2026-10-11) - Built-in targeting (Mark): GardenHelper no
    longer needs the SetTarget addon. New state.set_target(id) does what
    SetTarget does - injects the incoming 0x058 target-lock packet for
    the entity (skips one that isn't loaded or is over 50 yalms away).
    All three 'settarget <id>' calls (settarget_confirm, retarget_entity,
    the Green Thumb Moogle re-target in the arrival check) use it; the
    packet now goes in immediately instead of through the command queue
    - the existing waits/name checks are unchanged. New config
    use_settarget_addon (default false): true = back to SetTarget.
    Notes in CHANGELOG.md.
  v2.27.1 (2026-10-14) - Crystals always traded (Mark): //gh full now
    trades crystals to the Ephemeral Moogle when holding AT LEAST
    crystals_full_threshold of one type (was MORE than). With the
    threshold at 1, any crystal/cluster in inventory gets traded.
  v2.28.0 (2026-10-21) - Kitron Macaron tracking (Mark): each
    character's Kitron Macarons (item 5781) are counted across every
    item bag (inventory, Mog Safe/Safe 2, Storage, Locker, Satchel,
    Sack, Case) at the same moments as Storage (15s after login, 10s
    after zone change, on load, on //gh status) and 2s after any
    Kitron Macaron is added/removed/moved; saved per character when it
    changes (kitron_macarons, kitron_macarons_at in data/settings.xml).
    //gh status has a new "Kitron Macarons" row; MuleLogger v2.39.0
    shows it as |KM14| after the Str column. Not counted yet = -1.
    Notes in CHANGELOG.md. Backup: backup/GardenHelper v2.27.1 2026-10-21.lua.
  v2.29.0 (2026-10-26) - Ephemeral Moogle stock + withdrawals (Mark: for
    MuleLogger's new //ml eph / //ml smart Tier 12, which sends full
    cluster stacks from the non-crafting mules to the crafters).
    crystals.lua reads the moogle's stock from the game's currency
    packet (0x113, asked for with 0x10F - same offsets as the craft
    addon) at login, zone, load, //gh status and after every trade or
    withdrawal, and saves it per character (eph_crystals,
    eph_crystals_at in data/settings.xml). New //gh ephstock (reads it
    now, EphStockResult), //gh ephwithdraw <element> [stacks] (144
    crystals = 12 clusters per stack, EphWithdrawResult) and
    //gh ephcapture on|off (packet log). //gh status has a new
    "Ephemeral Moogle" row. Notes in CHANGELOG.md. Backup:
    backup/GardenHelper v2.28.0 2026-10-26.lua, backup/crystals v2.28.0 2026-10-26.lua.
  v2.29.1 (2026-10-26) - //gh ephwithdraw fixed from Mark's retail packet
    capture (144 Earth by hand on Fishvf): the 0x05B option needs the
    0x4000 flag in its high word - (0x4000 + element) * 65536 + crystals
    (the client sent 0x40040090; v2.29.0 sent 0x00040090 and got
    nothing). The moogle's menu packet (0x034) also carries the stock
    (8 ushorts from offset 8), now saved on every talk to it, and the
    stock is read again after a talk by hand ends, so hand withdrawals
    are counted too. Backup: backup/GardenHelper v2.29.0 2026-10-26.lua,
    backup/crystals v2.29.0 2026-10-26.lua.
  v2.30.0 (2026-10-27) - The active seed is no longer on the protected
    list (Mark): INV sell / send / drop / org now treat it like any other
    item, so its ItemTable.lua line decides - e.g. Arborfruit Seed
    action "save", min_save 99, PullFromBags true: every character keeps
    99 (all bags counted) and //gh sell sells the rest. Furrow and node
    fertilizers stay protected. inv.lua v4.16.0. Backup:
    backup/GardenHelper v2.29.1 2026-10-27.lua, backup/inv v4.15.0 2026-10-27.lua.
  v2.31.0 (2026-11-03) - Personal item table + clean shipped ItemTable.lua
    (Mark: other players shouldn't get his item logic). New characters.lua
    setting item_table = 'ItemTable_<name>.lua' picks the item table file
    INV reads and writes (pop, rebuild, sell, send, drop, org, auto_drop);
    blank / missing = ItemTable.lua. Mark's populated table now lives in
    ItemTable_Shadowhammer.lua (his characters.lua points at it) and
    ItemTable.lua is a clean starter (no items, mail_dry_run ON, auto_drop
    OFF) - the one every release ships. Releases leave out ItemTable_*.lua.
    inv.lua v4.17.0, MuleLogger v2.41.1 (reads the same setting). Backup:
    backup/GardenHelper v2.30.0 2026-11-03.lua, backup/inv v4.16.0 2026-11-03.lua,
    backup/characters v2.30.0 2026-11-03.lua, backup/ItemTable_Shadowhammer 2026-11-03.lua.
  v2.32.0 (2026-11-21) - //gh update [check|force] (Mark): new module
    Update.lua downloads the newest release from GitHub
    (thrydwolfvalefor/gardenhelper, manifest.txt = version + file sizes),
    checks every file (size, .lua compiles, GardenHelper.lua has the
    manifest version), backs the old ones up to backup/<name> v<old>
    pre-update <date>, writes, then reloads; after the reload one line
    says "Updated and reloaded - GardenHelper vX (was vY)". Never touches
    characters.lua, ItemTable*.lua, Mail.lua, memory_report.lua or data/.
    Two branches: major (full releases, fully tested and validated - the
    default) and minor (smaller changes, sooner); characters.lua
    update_branch picks yours, //gh update major|minor overrides it once.
    Refused while a run is going. Also inv.lua v4.17.1: //gh org only
    gathers items out of the other bags when PullFromBags = true. Backup:
    backup/GardenHelper v2.31.0 2026-11-21.lua, backup/inv v4.17.0 2026-11-21.lua,
    backup/characters v2.31.0 2026-11-21.lua.
]]

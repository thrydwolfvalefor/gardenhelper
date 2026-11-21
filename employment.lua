-- =====================================================================
-- employment.lua - GardenHelper module: the garden assistants' contracts
-- (Kuyin Hathdenna, Susuroon, Yeestog) with the Green Thumb Moogle.
--   * //gh employment (//gh emp) [force|notify|extend|status|reset|
--     capture|unstick|help]
--   * run: the employment step at the start of every full garden run
--     (//gh full / force / full inspect), before the assistant check.
--   * on_text: every chat line (GardenHelper's 'incoming text' event) -
--     picks up the game's daily "There are N days left on X's contract."
--     and "X's contract has expired." lines, whatever is running.
--   * due: for //gh duecheck (MuleLogger) - is there employment work?
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
-- Returns {run, on_text, due, command, status_rows}.
--
-- What one run does (most runs: nothing but a look at the data):
--   1. Which assistants are in this garden (their entity is loaded =
--      recruited; an expired contract does NOT remove them).
--   2. Not recruited yet + its unlock item in any bag -> the item is
--      pulled into inventory, traded to the Green Thumb Moogle and the
--      recruiting scene is pressed through (7 free days).
--   3. Spare unlock items for assistants already recruited are traded
--      too: +7 contract days each, free (employment_trade_spare_items).
--   4. No daily contract line seen today -> the notification setting is
--      probably off: set to "Always notify me" (at most once every
--      employment_notify_retry_days).
--   5. Contract days: read from the moogle's menu data on EVERY talk to
--      it (sells too); unknown ones get one talk. Assistants with
--      fewer than employment_extend_below_days (30) days left are flagged
--      (employ_extend_due, MuleLogger 'A x').
--   Extending is by hand: nothing GardenHelper can send reaches the weeks
--   box. //gh emp extend (and //ml extend on every character) opens the
--   menus up to the box, you type the weeks + Enter, it finishes.
--   v2.23.0: //gh emp extend target <days> (what //ml extend sends) works
--   out the weeks for each assistant so its contract ends within 7 days
--   of <days> (the longest contract on any character) and tells you the
--   number to type; assistants already within 7 days are left alone.
-- Everything read or done is saved in data/settings.xml (employ_...)
-- and every hire / trade / expiry is appended to
-- data/employment_history.log.
--
-- Menus (captured 2026-09-27 on Fishvf and Cookvf):
--   Moogle: Enter -> "Whatever would you want..." -> Enter -> menu:
--   Down Down Enter "Check on my assistants." -> "Which ardently
--   allegiant assistant, kupo?" -> Enter -> list of the RECRUITED
--   assistants in unlock order (Kuyin, Susuroon, Yeestog), then "Set
--   contract expiration notification.".
--   Assistant: Enter -> "<name> can still toil tirelessly for a total of
--   N days" (or "... has yet to consent to a contract" = none) -> Enter
--   -> menu "What about this assistant?" Enter (Employ.) -> "Hire this
--   helper?..." -> Enter -> number box: type weeks (0-9), Enter ->
--   "<name> for W weeks, kupo?... T-day contract costing G gil." ->
--   Enter -> menu "Is this sufficient?" Enter (Yes! Seal the deal!) ->
--   "Contract: complete!..." -> Enter -> short black screen.
--   Notification: list -> Down x recruited -> Enter -> "Even the most
--   agreeable assistant..." -> Enter -> "Enter how many days in
--   advance..." -> Left x3 ("Always notify me.") Enter -> "You will now
--   always be notified..." -> back in the list -> Escape.
--   Recruiting: trade the item -> scene lines, each needs Enter, one
--   menu whose TOP option recruits. After Susuroon (20+ node ranks) the
--   next talk to the moogle starts a long Monster Rearing scene
--   ("Hidey ho, <name>!") - pressed through the same way.
-- =====================================================================
return function(gh)

local config, state, saved_status = gh.config, gh.state, gh.saved_status
local log, debug_log, error_log = gh.log, gh.debug_log, gh.error_log

-- Unlock order = the order of the moogle's assistant list.
local EMPLOYEES = {
    {key = 'kuyin',    name = 'Kuyin Hathdenna', label = 'Kuyin',    item = 'Dragoneye',       item_id = 4048},
    {key = 'susuroon', name = 'Susuroon',        label = 'Susuroon', item = 'Rusted Coin',     item_id = 4049},
    {key = 'yeestog',  name = 'Yeestog',         label = 'Yeestog',  item = 'Fat Burrow Worm', item_id = 4050},
}
local BY_NAME = {}
for _, e in ipairs(EMPLOYEES) do
    BY_NAME[e.key] = e
    BY_NAME[e.name:lower()] = e
end

local WEEK_COST = 10000          -- gil per week of contract
local SPARE_TRADES_MAX = 20      -- safety cap per assistant per run
local HISTORY_FILE = windower.addon_path .. 'data/employment_history.log'

-- Bags an unlock item is pulled out of (inventory first, Mog House bags
-- work from the Mog Garden too).
local SEARCH_BAGS = {
    {id = 5, name = 'satchel'}, {id = 6, name = 'sack'}, {id = 7, name = 'case'},
    {id = 9, name = 'safe2'}, {id = 1, name = 'safe'}, {id = 2, name = 'storage'}, {id = 4, name = 'locker'},
}

local function cfgv(key, default)
    local v = config[key]
    if v == nil then return default end
    return v
end

-- ---- Saved data (data/settings.xml, per character) ----
local function sget(e, field, default)
    local v = saved_status['employ_' .. e.key .. '_' .. field]
    if v == nil or v == '' then return default end
    return v
end
local function sset(e, field, value)
    saved_status['employ_' .. e.key .. '_' .. field] = value
end
local function gget(field, default)
    local v = saved_status['employ_' .. field]
    if v == nil or v == '' then return default end
    return v
end
local function gset(field, value)
    saved_status['employ_' .. field] = value
end

local function stamp(epoch)
    return os.date('%Y-%m-%d %H:%M:%S', epoch or os.time())
end

-- 'YYYY-MM-DD' (garden day) -> whole day number, for day differences.
local function day_num(day_string)
    local y, m, d = tostring(day_string or ''):match('^(%d+)%-(%d+)%-(%d+)$')
    if not y then return nil end
    return math.floor(os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12}) / 86400 + 0.5)
end

local function today()
    return gh.get_garden_day_string()
end

local function history(e, text)
    local f = io.open(HISTORY_FILE, 'a')
    if f then
        f:write(stamp() .. '  ' .. tostring(gh.character_key() or '?') .. '  ' .. (e and e.label or '-') .. '  ' .. text .. '\n')
        f:close()
    end
    if e then
        sset(e, 'last_action', text)
        sset(e, 'last_action_at', stamp())
    end
end

-- Days left as read (from the game) on a garden day.
local function record_days(e, days, source)
    local now = os.time()
    days = math.max(0, math.floor(tonumber(days) or 0))
    sset(e, 'days', days)
    sset(e, 'days_date', today())
    sset(e, 'days_seen_at', stamp(now))
    sset(e, 'source', source)
    sset(e, 'expires', os.date('%Y-%m-%d', now + days * 86400))
end

-- Days left today: the last reading minus the garden days since. nil =
-- never read.
local function days_left(e)
    local d = tonumber(sget(e, 'days', -1)) or -1
    if d < 0 then return nil end
    local seen, now = day_num(sget(e, 'days_date', '')), day_num(today())
    if not seen or not now then return nil end
    return math.max(0, d - math.max(0, now - seen))
end

-- rehire_weeks from characters.lua: assistants.<name>.rehire_weeks in
-- this character's overrides, then in defaults, then defaults.rehire_weeks,
-- then config.employment_default_rehire_weeks (9). 0 = never pay.
local function rehire_weeks(e)
    local function from(block)
        local a = type(block) == 'table' and type(block.assistants) == 'table' and block.assistants[e.key] or nil
        if type(a) == 'table' and tonumber(a.rehire_weeks) then return tonumber(a.rehire_weeks) end
        if type(block) == 'table' and tonumber(block.rehire_weeks) then return tonumber(block.rehire_weeks) end
        return nil
    end
    local cf = gh.character_file or {}
    local w = from(gh.get_character_override()) or from(cf.defaults) or tonumber(cfgv('employment_default_rehire_weeks', 9)) or 9
    return math.max(0, math.min(9, math.floor(w)))
end

local function threshold()
    return tonumber(cfgv('employment_extend_below_days', 30)) or 30
end

-- ---- Items ----
local function inventory_slots()
    local items = windower.ffxi.get_items(0)
    local free, found = 0, nil
    if not items then return 0, nil, items end
    for i = 1, (tonumber(items.max) or 0) do
        local it = items[i]
        if not it or not it.id or it.id == 0 then free = free + 1 end
    end
    return free, nil, items
end

-- Count in main inventory (tradeable stacks) and in every bag together.
local function held(e)
    local in_inv, total = 0, 0
    local inv = windower.ffxi.get_items(0)
    if inv then
        for i = 1, (tonumber(inv.max) or 0) do
            local it = inv[i]
            if it and it.id == e.item_id then
                total = total + (it.count or 0)
                if (it.status or 0) == 0 then in_inv = in_inv + (it.count or 0) end
            end
        end
    end
    for _, b in ipairs(SEARCH_BAGS) do
        local items = windower.ffxi.get_items(b.id)
        if items and items.enabled ~= false then
            for i = 1, (tonumber(items.max) or 0) do
                local it = items[i]
                if it and it.id == e.item_id then total = total + (it.count or 0) end
            end
        end
    end
    return in_inv, total
end

-- Main-inventory slot holding the item (pulled out of another bag when
-- needed), or nil + a reason.
local function item_slot(e)
    local function inv_slot()
        local inv = windower.ffxi.get_items(0)
        if not inv then return nil end
        for i = 1, (tonumber(inv.max) or 0) do
            local it = inv[i]
            if it and it.id == e.item_id and (it.status or 0) == 0 and (it.count or 0) > 0 then return i end
        end
        return nil
    end
    local slot = inv_slot()
    if slot then return slot end
    if inventory_slots() <= 0 then
        return nil, 'main inventory is full - cannot pull the ' .. e.item .. ' out'
    end
    for _, b in ipairs(SEARCH_BAGS) do
        local items = windower.ffxi.get_items(b.id)
        if items and items.enabled ~= false then
            for i = 1, (tonumber(items.max) or 0) do
                local it = items[i]
                if it and it.id == e.item_id and (it.status or 0) == 0 and (it.count or 0) > 0 then
                    windower.ffxi.get_item(b.id, i, 1)
                    local waited = 0
                    while waited < 5 do
                        coroutine.sleep(0.25)
                        waited = waited + 0.25
                        slot = inv_slot()
                        if slot then
                            log('Employment: pulled 1 ' .. e.item .. ' out of ' .. b.name .. '.')
                            return slot
                        end
                    end
                    return nil, 'could not pull the ' .. e.item .. ' out of ' .. b.name
                end
            end
        end
    end
    return nil, 'no ' .. e.item .. ' found'
end

-- One item to an NPC with the outgoing 0x036 trade packet (as crystals.lua
-- / TradeNPC by Ivaar). The NPC must be within 6 yalms.
local function trade_one(npc, slot)
    local qty = {1, 0, 0, 0, 0, 0, 0, 0, 0}
    local ind = {slot, 0, 0, 0, 0, 0, 0, 0, 0}
    local packet = ('C4I11C10HI'):pack(0x36, 0x20, 0x00, 0x00, npc.id,
        qty[1], qty[2], qty[3], qty[4], qty[5], qty[6], qty[7], qty[8], qty[9], 0x00,
        ind[1], ind[2], ind[3], ind[4], ind[5], ind[6], ind[7], ind[8], ind[9], 0x00,
        npc.index, 1)
    windower.packets.inject_outgoing(0x36, packet)
end

-- ---- Conversation helpers ----
local function wait_s() return cfgv('employment_text_wait_seconds', 8) end
local function line_settle() return cfgv('employment_line_settle_seconds', 1.5) end
local function menu_settle() return cfgv('employment_menu_settle_seconds', 1.5) end
local function key_settle() return cfgv('employment_key_settle_seconds', 0.7) end

local function in_event()
    local p = windower.ffxi.get_player()
    return p ~= nil and p.status == 4
end

local function begin_capture()
    state.captured_lines = {}
    state.capturing_text = true
end
local function end_capture()
    state.capturing_text = false
end
local function mark()
    return #(state.captured_lines or {})
end

-- True once a line after index `from` contains one of phrases.
local function wait_for(phrases, max_wait, from)
    local waited = 0
    while state.running do
        if gh.lines_contain(state.captured_lines, phrases, (from or 0) + 1) then return true end
        if waited >= max_wait then return false end
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    return false
end

-- First line after `from` containing phrase (timestamp stripped), or nil.
local function line_with(phrase, from)
    local lines = state.captured_lines or {}
    for i = (from or 0) + 1, #lines do
        if lines[i]:find(phrase, 1, true) then return gh.strip_timestamp_prefix(lines[i]) end
    end
    return nil
end

local function wait_event_end(max_wait)
    local waited, out_for = 0, 0
    while waited < max_wait do
        if in_event() then out_for = 0 else out_for = out_for + 0.25 end
        if out_for >= 1 then return true end
        coroutine.sleep(0.25)
        waited = waited + 0.25
    end
    return not in_event()
end

-- Leaves the conversation with Escape (never Enter: it would pick the
-- highlighted menu option) and clears the target.
local function leave()
    for _ = 1, 6 do
        if not in_event() then break end
        gh.press_key('escape', 0.8)
    end
    windower.send_command('target clear')
    end_capture()
end

-- Presses Enter through a scene: after each new line has finished
-- showing, or after employment_event_idle_enter_seconds with no new line
-- (a menu is open - Enter takes its TOP option - or a silent stretch).
-- Done once the event has been over for employment_event_end_seconds.
-- The moogle's own "Whatever would you want" = the scene is over and a
-- new talk started by that last Enter: backed out of.
local function drive_event(what)
    local max_t = cfgv('employment_event_max_seconds', 420)
    local idle_enter = cfgv('employment_event_idle_enter_seconds', 5)
    local settle = line_settle()
    local end_after = cfgv('employment_event_end_seconds', 3)
    local start = mark()
    local waited, since_line, since_enter, out_for, presses = 0, 0, 0, 0, 0
    local last_count, lines_at_enter = start, start
    while state.running do
        coroutine.sleep(0.25)
        waited = waited + 0.25
        local n = mark()
        if n ~= last_count then
            last_count = n
            since_line = 0
        else
            since_line = since_line + 0.25
        end
        since_enter = since_enter + 0.25
        if gh.lines_contain(state.captured_lines, 'Whatever would you want', start + 1) then
            debug_log('Employment: ' .. what .. ' over (the moogle started a new talk) - backing out.')
            leave()
            return true
        end
        if in_event() then
            out_for = 0
            local new_text = last_count > lines_at_enter
            if (new_text and since_line >= settle and since_enter >= settle) or since_enter >= idle_enter then
                if in_event() then
                    gh.press_key('enter', 0.1)
                    presses = presses + 1
                    since_enter = 0
                    lines_at_enter = last_count
                end
            end
        else
            out_for = out_for + 0.25
            if out_for >= end_after and (presses > 0 or waited >= 10) then
                debug_log('Employment: ' .. what .. ' over after ' .. string.format('%.0f', waited) .. 's (' .. presses .. ' Enter).')
                return true
            end
        end
        if waited >= max_t then
            error_log('Employment: ' .. what .. ' still going after ' .. max_t .. 's - stopping here. Check the screen.')
            return false
        end
    end
    return false
end

-- Walks to the Green Thumb Moogle and opens its talk ("Whatever would you
-- want..." shown and settled). A story scene first (e.g. Monster Rearing)
-- is pressed through and the talk tried again. Capture stays on.
local function open_moogle()
    for attempt = 1, 3 do
        if not state.running then return false end
        windower.send_command('target clear')
        coroutine.sleep(0.3)
        if not gh.walk_to_moogle() then
            if state.running then error_log('Employment: could not reach/target the Green Thumb Moogle.') end
            return false
        end
        begin_capture()
        -- "Target out of range." = walk closer and press Enter again.
        local from, seen = mark(), false
        local reached = gh.range_retry(config.sell_junk_moogle_id, 'Green Thumb Moogle', function()
            from = mark()
            gh.press_key('enter', 0.1)
            local phrases = {'Whatever would you want', 'try again in a little while'}
            for _, p in ipairs(config.out_of_range_phrases) do table.insert(phrases, p) end
            seen = wait_for(phrases, wait_s(), from)
            return true
        end)
        if not reached then
            end_capture()
            windower.send_command('target clear')
            if state.running then error_log('Employment: the Green Thumb Moogle stayed out of range even after walking closer - not talking to it this run.') end
            return false
        end
        if seen and gh.lines_contain(state.captured_lines, 'Whatever would you want', from + 1) then
            coroutine.sleep(line_settle())
            return true
        end
        if in_event() and not (seen and line_with('try again in a little while', from)) then
            log('Employment: the Green Thumb Moogle has a scene to show first - pressing Enter through it (can take a few minutes)...')
            drive_event('moogle scene')
        else
            leave()
        end
        end_capture()
        windower.send_command('target clear')
        coroutine.sleep(cfgv('employment_retry_wait_seconds', 5))
    end
    error_log('Employment: the Green Thumb Moogle did not open its menu after 3 tries.')
    return false
end

-- From the settled "Whatever would you want" line to the open assistant
-- list (cursor on the first recruited assistant).
local function open_assistant_list()
    gh.press_key('enter', menu_settle())
    gh.press_key('down', key_settle())
    gh.press_key('down', key_settle())
    local from = mark()
    gh.press_key('enter', 0.1)
    if not wait_for('Which ardently allegiant assistant', wait_s(), from) then
        error_log('Employment: no "Which ardently allegiant assistant" after "Check on my assistants." - backing out.')
        return false
    end
    coroutine.sleep(line_settle())
    gh.press_key('enter', menu_settle())
    return true
end

-- ---- Errors of this run ----
local run_errors = {}
local function fail(text)
    table.insert(run_errors, text)
    error_log('Employment: ' .. text)
end

-- ---- Presence ----
local function refresh_presence()
    local present, count = {}, 0
    for _, e in ipairs(EMPLOYEES) do
        present[e.key] = gh.assistant_present(e.key) and true or false
        sset(e, 'recruited', present[e.key] and 'y' or 'n')
        if present[e.key] then count = count + 1 end
    end
    gset('count', count)
    return present, count
end

-- Position of e in the moogle's list = recruited assistants before it.
local function list_pos(e, present)
    local pos = 0
    for _, o in ipairs(EMPLOYEES) do
        if o == e then return pos end
        if present[o.key] then pos = pos + 1 end
    end
    return pos
end

-- ---- Contracts by packet ----
-- The weeks box only takes real typing (setkey digits and Up never reach
-- it), and it is client-side anyway: nothing goes to the server until
-- "Yes! Seal the deal!". Captured 2026-09-27 (Genpopvf 19:28-19:34,
-- data/employment_packets.log), Green Thumb Moogle event (Menu ID 1016):
--   incoming 0x034 on talking: Menu Parameters uint32 [0] recruited
--     bitmask, [1] Kuyin / [2] Susuroon / [3] Yeestog contract SECONDS
--     left - read on EVERY talk to the moogle (GardenHelper's sells too).
--   outgoing 0x05B choices (all "automated" except the last):
--     27                       assistant list opened
--     weeks * 256 + 28 + n     hire/extend (n: 0 Kuyin, 1 Susuroon, 2
--                              Yeestog) -> 0x05C [1] = new contract seconds
--     1, 11, 11 (not automated = event over)
-- A hire = talk to the moogle with its menu window held back (0x034 not
-- passed to the client), send exactly those choices, check the new
-- contract time that comes back, and that the gil went down.
local function u16(data, pos)
    local a, b = data:byte(pos, pos + 1)
    return (a or 0) + (b or 0) * 256
end
local function u32(data, pos)
    return u16(data, pos) + u16(data, pos + 2) * 65536
end
local function le16(n)
    n = math.floor(n) % 65536
    return string.char(n % 256, math.floor(n / 256))
end
local function le32(n)
    return le16(n % 65536) .. le16(math.floor(n / 65536))
end

local function menu_id() return tonumber(cfgv('employment_menu_id', 1016)) or 1016 end

local last_talk = nil   -- {mask, secs = {kuyin, susuroon, yeestog}, at}
local talk_seq = 0      -- +1 on every moogle menu 0x034
local sess = nil        -- packet hire session (see extend)
local capture_session = false  -- log packets to data/employment_packets.log during a hire

local function days_from_secs(secs)
    return math.ceil((secs or 0) / 86400)
end

-- incoming 0x034 from the Green Thumb Moogle's assistant menu: contract
-- seconds for every assistant (always), held back from the client while a
-- packet hire is waiting for it. Returns true = block.
local function on_moogle_menu(data)
    if u32(data, 5) ~= config.sell_junk_moogle_id or u16(data, 0x2C + 1) ~= menu_id() then
        return false
    end
    local mask = u32(data, 9)
    local secs = {u32(data, 13), u32(data, 17), u32(data, 21)}
    last_talk = {mask = mask, secs = secs, at = os.time(),
        npc_index = u16(data, 0x28 + 1), zone = u16(data, 0x2A + 1), menu = u16(data, 0x2C + 1)}
    talk_seq = talk_seq + 1
    for i, e in ipairs(EMPLOYEES) do
        local bit = 2 ^ (i - 1)
        if secs[i] > 0 or (mask % (bit * 2)) >= bit then
            record_days(e, days_from_secs(secs[i]), 'moogle talk')
        end
    end
    pcall(gh.persist_status)
    if sess and sess.waiting034 then
        sess.waiting034 = false
        sess.got034 = true
        sess.npc_index = u16(data, 0x28 + 1)
        sess.zone = u16(data, 0x2A + 1)
        sess.menu = u16(data, 0x2C + 1)
        return true
    end
    return false
end

-- Every incoming chunk (see the event at the bottom). true = block.
local function packet_incoming(id, data)
    if id == 0x034 then
        return on_moogle_menu(data)
    end
    if sess and sess.got034 then
        if id == 0x05C then
            sess.n05C = sess.n05C + 1
            sess.last05C = data
            return true
        elseif id == 0x052 then
            sess.n052 = sess.n052 + 1
        end
    end
    return false
end

local function send_choice(option, automated)
    local pkt = string.char(0x5B, 0x0A, 0, 0) .. le32(config.sell_junk_moogle_id) .. le16(option) .. le16(0) ..
        le16(sess.npc_index) .. string.char(automated and 1 or 0, 0) .. le16(sess.zone) .. le16(sess.menu)
    windower.packets.inject_outgoing(0x5B, pkt)
end

-- Sends a choice and waits for the server's 0x05C (automated) or 0x052
-- (the last one). Returns true when it came.
local function choice(option, automated)
    local before05C, before052 = sess.n05C, sess.n052
    send_choice(option, automated)
    local waited = 0
    while waited < cfgv('employment_packet_wait_seconds', 5) do
        coroutine.sleep(0.1)
        waited = waited + 0.1
        if automated and sess.n05C > before05C then return true end
        if not automated and sess.n052 > before052 then return true end
    end
    return false
end

-- Talks to the moogle normally (menu shown), so 0x034 updates every
-- contract, then backs out. Scenes first (Monster Rearing) are pressed
-- through. true = fresh contract data.
local function read_contracts()
    local seq = talk_seq
    if not open_moogle() then return false end
    local waited = 0
    while talk_seq == seq and waited < 3 do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    leave()
    return talk_seq > seq
end

-- ---- Extending by hand (//gh emp extend, //ml extend) ----
-- Nothing GardenHelper can send reaches the weeks box: setkey digits, Up,
-- Windower's typed text (goes to /say) and injected menu packets (the
-- server ignores them - Cookvf 2026-09-27 20:42 / 21:03) all failed. So
-- GardenHelper opens the menus up to the empty weeks box, YOU type the
-- weeks (9) and Enter, and GardenHelper finishes: "Is this sufficient?"
-- Yes, "Contract: complete!", and records the new contract.

-- Keys from the moogle to the open weeks box for e (list entry pos).
-- true, or nil + why.
local function open_weeks_box(e, pos, want)
    if not open_moogle() then return nil, 'could not open the Green Thumb Moogle menu' end
    if not open_assistant_list() then leave() return nil, 'could not open the assistant list' end
    for _ = 1, pos do gh.press_key('down', key_settle()) end
    local from = mark()
    gh.press_key('enter', 0.1)
    if not wait_for({'can still toil tirelessly', 'has yet to consent'}, wait_s(), from) then
        leave()
        return nil, 'no contract line after list entry ' .. (pos + 1)
    end
    coroutine.sleep(line_settle())
    local line = line_with('can still toil tirelessly', from) or line_with('has yet to consent', from) or ''
    if not line:find(e.name, 1, true) then
        leave()
        return nil, 'expected ' .. e.name .. ' at list entry ' .. (pos + 1) .. ' but the moogle said "' .. line .. '"'
    end
    record_days(e, tonumber(line:match('for a total of (%d+) day')) or 0, 'moogle')
    gh.press_key('enter', menu_settle())        -- "What about this assistant?"
    from = mark()
    gh.press_key('enter', 0.1)                  -- Employ.
    if not wait_for('Hire this helper', wait_s(), from) then
        leave()
        return nil, 'no "Hire this helper?" after Employ.'
    end
    coroutine.sleep(line_settle())
    -- v2.21.1: start watching for the quote HERE, before the sound - you
    -- can type the weeks + Enter the moment you hear it, and the quote
    -- line is caught even if it shows up before the box "settles".
    local watch_from = mark()
    -- Sound first (party chat, before the box has focus), then the box
    -- opens right after (employment_alert_lead_seconds, was a fixed 1s).
    if gh.alert then
        pcall(gh.alert, want and ('type ' .. want .. ' for ' .. e.label .. ' + Enter')
            or ('type the weeks for ' .. e.label .. ' + Enter'))
        coroutine.sleep(cfgv('employment_alert_lead_seconds', 0.4))
    end
    gh.press_key('enter', 0.2)                  -- the weeks box opens
    return true, watch_from
end

-- One assistant: up to the weeks box, wait for you, then finish. true =
-- extended. want (v2.23.0) = the weeks you are asked to type; a different
-- number is backed out before sealing (one more try, then failed).
local function extend_by_hand(e, pos, want, attempt)
    attempt = attempt or 1
    local before = days_left(e)
    local ok, why = open_weeks_box(e, pos, want)
    if not ok then
        fail(e.label .. ': ' .. why)
        return false
    end
    -- v2.21.1: watch from before the sound (open_weeks_box's mark), not
    -- from here - typing right away used to be missed.
    local from = why
    local limit = cfgv('employment_manual_wait_seconds', 300)
    if want then
        log('>>> ' .. e.name .. ' (' .. tostring(sget(e, 'days', '?')) .. ' days left): TYPE ' .. want .. ' AND PRESS ENTER NOW <<<  (' ..
            want .. ' week' .. (want == 1 and '' or 's') .. ' -> about ' .. ((tonumber(sget(e, 'days', 0)) or 0) + want * 7) .. ' days)', 207)
    else
        log('>>> ' .. e.name .. ' (' .. tostring(sget(e, 'days', '?')) .. ' days left): TYPE THE WEEKS (9) AND PRESS ENTER NOW <<<', 207)
    end
    log('    (waiting up to ' .. limit .. 's; an empty box / 0 = skip this one)', 207)
    local waited, got = 0, nil
    while state.running and waited < limit do
        if gh.lines_contain(state.captured_lines, '-day contract costing', from + 1) then got = 'quote' break end
        if gh.lines_contain(state.captured_lines, 'Which ardently allegiant assistant', from + 1) then got = 'skip' break end
        coroutine.sleep(0.25)
        waited = waited + 0.25
    end
    if got ~= 'quote' then
        leave()
        if got == 'skip' then
            log('Employment: ' .. e.label .. ' - no weeks entered, skipped.')
        elseif state.running then
            fail(e.label .. ': no weeks typed within ' .. limit .. 's - not extended')
        end
        return false
    end
    coroutine.sleep(line_settle())
    local quote = line_with('-day contract costing', from) or ''
    local weeks = tonumber(quote:match('for (%d+) weeks?, kupo'))
    local total = tonumber(quote:match('(%d+)%-day contract costing'))
    local price = tonumber(((quote:match('costing ([%d,]+) gil') or ''):gsub(',', '')))
    if want and weeks and weeks ~= want then
        -- v2.23.0: wrong number typed - back out before sealing the deal.
        leave()
        if attempt < 2 then
            log('Employment: ' .. e.label .. ' - you typed ' .. weeks .. ' but it needs ' .. want .. ' - backed out (nothing paid), opening the box again...', 167)
            coroutine.sleep(cfgv('employment_retry_wait_seconds', 5))
            return extend_by_hand(e, pos, want, attempt + 1)
        end
        fail(e.label .. ': typed ' .. weeks .. ' weeks, needed ' .. want .. ' - backed out, not extended')
        return false
    end
    local gil = (windower.ffxi.get_items() or {}).gil or 0
    if price and price > gil then
        leave()
        fail('not enough gil to extend ' .. e.label .. ' (' .. price .. ' gil, have ' .. gil .. ')')
        history(e, 'NOT extended - not enough gil (need ' .. price .. ', have ' .. gil .. ')')
        return false
    end
    gh.press_key('enter', menu_settle())        -- "Is this sufficient?"
    from = mark()
    gh.press_key('enter', 0.1)                  -- Yes! Seal the deal!
    if not wait_for('Contract: complete', wait_s(), from) then
        leave()
        fail(e.label .. ': no "Contract: complete!" after sealing the deal - check it at the moogle')
        return false
    end
    coroutine.sleep(line_settle())
    gh.press_key('enter', 0.5)
    wait_event_end(15)
    windower.send_command('target clear')
    end_capture()
    total = total or ((before or 0) + (weeks or 0) * 7)
    record_days(e, total, 'hired')
    history(e, 'extended by hand ' .. tostring(weeks or '?') .. ' week(s): ' .. tostring(before or '?') .. ' -> ' .. total ..
        ' days (until ' .. sget(e, 'expires', '?') .. '), ' .. tostring(price or '?') .. ' gil')
    log('Employment: ' .. e.label .. ' - contract now ' .. total .. ' days (until ' .. sget(e, 'expires', '?') .. ').')
    coroutine.sleep(cfgv('employment_retry_wait_seconds', 5))
    return true
end

-- employ_extend_due: "Kuyin 5d, Susuroon 7d" - recruited assistants with
-- fewer than employment_extend_below_days (30) days left ('x' in MuleLogger).
local function update_extend_due(present)
    local parts = {}
    for _, e in ipairs(EMPLOYEES) do
        if present[e.key] then
            local d = days_left(e)
            if d ~= nil and d < threshold() then table.insert(parts, e.label .. ' ' .. d .. 'd') end
        end
    end
    gset('extend_due', table.concat(parts, ', '))
end

-- ---- Trades (recruit / spare item) ----
-- Trades one unlock item and presses through what follows. Returns true
-- when the item left the bags.
local function trade_item(e, what)
    -- Items can't be moved or traded while a talk is still open ("You
    -- cannot use that command"; Cookvf 20:42 Dragoneye pull).
    if not wait_event_end(5) then leave() wait_event_end(5) end
    local _, before = held(e)
    local slot, why = item_slot(e)
    if not slot then fail(e.label .. ': ' .. why) return false end
    windower.send_command('target clear')
    coroutine.sleep(0.3)
    if not gh.walk_to_moogle() then
        if state.running then fail(e.label .. ': could not reach the Green Thumb Moogle to trade the ' .. e.item) end
        return false
    end
    local npc = windower.ffxi.get_mob_by_id(config.sell_junk_moogle_id)
    if not npc or not npc.distance or math.sqrt(npc.distance) >= 6 then
        gh.ensure_in_interact_range(config.sell_junk_moogle_id, 'Green Thumb Moogle', nil)
        npc = windower.ffxi.get_mob_by_id(config.sell_junk_moogle_id)
    end
    if not npc then fail(e.label .. ': Green Thumb Moogle not found for the trade') return false end
    begin_capture()
    -- "Target out of range." = walk closer and trade again.
    gh.range_retry(config.sell_junk_moogle_id, 'Green Thumb Moogle', function()
        local n = windower.ffxi.get_mob_by_id(config.sell_junk_moogle_id) or npc
        local count = gh.out_of_range_count()
        trade_one(n, slot)
        local waited = 0
        while state.running and not in_event() and waited < wait_s() and gh.out_of_range_count() == count do
            coroutine.sleep(0.25)
            waited = waited + 0.25
        end
        return in_event()
    end)
    if not in_event() then
        end_capture()
        fail(e.label .. ': the moogle did not take the ' .. e.item .. ' (' .. what .. ')')
        return false
    end
    drive_event(what)
    windower.send_command('target clear')
    end_capture()
    coroutine.sleep(1)
    local _, after = held(e)
    if after >= before then
        fail(e.label .. ': the ' .. e.item .. ' is still in the bags after the ' .. what .. ' scene')
        return false
    end
    return true
end

local function recruit(e)
    log('Employment: ' .. e.label .. ' is not recruited yet and a ' .. e.item .. ' was found - trading it to the Green Thumb Moogle (the scene takes a minute)...')
    if not trade_item(e, 'recruiting scene') then return false end
    local waited = 0
    while not gh.assistant_present(e.key) and waited < 15 do
        coroutine.sleep(0.5)
        waited = waited + 0.5
    end
    if not gh.assistant_present(e.key) then
        fail(e.label .. ': the ' .. e.item .. ' was taken but ' .. e.label .. ' is not in the garden afterwards - check the screen')
        return false
    end
    record_days(e, 7, 'recruited')
    history(e, 'recruited (traded ' .. e.item .. ') - 7 days')
    log('Employment: ' .. e.label .. ' recruited!')
    coroutine.sleep(cfgv('employment_retry_wait_seconds', 5))
    return true
end

local function spare_trade(e)
    log('Employment: spare ' .. e.item .. ' - trading it for 7 more days of ' .. e.label .. '...')
    local est = days_left(e)
    local from = mark()
    if not trade_item(e, 'spare ' .. e.item .. ' trade') then return false end
    if est then
        record_days(e, est + 7, 'item')
        history(e, 'traded spare ' .. e.item .. ': +7 days -> ' .. (est + 7) .. ' days (until ' .. sget(e, 'expires', '?') .. ')')
    else
        history(e, 'traded spare ' .. e.item .. ': +7 days')
    end
    coroutine.sleep(2)
    return true
end

-- ---- Notification ----
local function set_notify_always(count)
    log('Employment: no daily contract line seen today - setting contract notices to "Always notify me"...')
    if not open_moogle() then fail('notification: could not open the Green Thumb Moogle menu') return false end
    if not open_assistant_list() then leave() fail('notification: could not open the assistant list') return false end
    if cfgv('employment_notify_nav', 'count') == 'bottom' then
        gh.press_key('right', key_settle())
        gh.press_key('right', key_settle())
        gh.press_key('up', key_settle())
    else
        for _ = 1, count do gh.press_key('down', key_settle()) end
    end
    local from = mark()
    gh.press_key('enter', 0.1)
    if not wait_for('Even the most agreeable assistant', wait_s(), from) then
        leave()
        fail('notification: "Set contract expiration notification." did not answer (list entry ' .. (count + 1) .. ')')
        return false
    end
    coroutine.sleep(line_settle())
    from = mark()
    gh.press_key('enter', 0.1)
    if not wait_for('how many days in advance', wait_s(), from) then
        leave()
        fail('notification: no "how many days in advance" line')
        return false
    end
    coroutine.sleep(menu_settle())
    for _, k in ipairs(cfgv('employment_notify_always_keys', {'left', 'left', 'left'})) do
        gh.press_key(k, key_settle())
    end
    from = mark()
    gh.press_key('enter', 0.1)
    local ok = wait_for('be notified of', wait_s(), from)
    local line = line_with('be notified of', from) or ''
    coroutine.sleep(line_settle())
    leave()
    if not ok or not line:find('always', 1, true) then
        fail('notification: expected "You will now always be notified", got "' .. line .. '"')
        return false
    end
    gset('notify_set_date', today())
    history(nil, 'contract notices set to "Always notify me"')
    log('Employment: contract notices set to "Always notify me".')
    return true
end

local function notify_due(count, force)
    if count == 0 then return false end
    if gget('notice_date', '') == today() then return false end
    if force then return true end
    local last = day_num(gget('notify_set_date', ''))
    local now = day_num(today())
    return not last or not now or (now - last) >= (tonumber(cfgv('employment_notify_retry_days', 7)) or 7)
end

-- ---- API ----
local M = {}

local function enabled()
    return cfgv('employment_enabled', true) ~= false and gh.is_module_enabled('employment')
end

-- A contract line from the game, whatever is running.
function M.on_text(line)
    if type(line) ~= 'string' or not line:find('contract', 1, true) then return end
    local days, who = line:match('(%d+) days? left on (.-)\'s contract')
    local expired = false
    if not days then
        who = line:match('([%a][%a ]-)\'s contract has expired')
        if not who then return end
        expired = true
    end
    local e = BY_NAME[(who:gsub('^%s+', ''):gsub('%s+$', '')):lower()]
    if not e or not windower.ffxi.get_player() then return end
    record_days(e, expired and 0 or tonumber(days), expired and 'expired notice' or 'daily notice')
    gset('notice_date', today())
    if expired then history(e, 'contract expired (game notice)') end
    gh.persist_status()
end

-- The employment step. force = read every recruited assistant's days at
-- the moogle (extending the ones that are due) and set the notices.
function M.run(force)
    if not enabled() then
        debug_log('Employment: off for this character - skipping.')
        return
    end
    if not gh.in_mog_garden() then return end
    run_errors = {}
    local present, count = refresh_presence()

    -- Recruit, in unlock order.
    for _, e in ipairs(EMPLOYEES) do
        if not state.running then break end
        if not present[e.key] then
            local _, total = held(e)
            if total > 0 then
                if recruit(e) then
                    present[e.key] = true
                    count = count + 1
                    sset(e, 'recruited', 'y')
                    gset('count', count)
                else
                    break
                end
            end
        end
    end
    -- Spare unlock items = free days.
    if cfgv('employment_trade_spare_items', true) then
        for _, e in ipairs(EMPLOYEES) do
            if present[e.key] then
                local n = 0
                while state.running and n < SPARE_TRADES_MAX and select(2, held(e)) > 0 do
                    if not spare_trade(e) then break end
                    n = n + 1
                end
            end
        end
    end
    -- Contract notices.
    if state.running and notify_due(count, force) then
        set_notify_always(count)
    end
    -- Contract days nobody has read yet: one talk to the moogle reads them all.
    local unknown = false
    for _, e in ipairs(EMPLOYEES) do
        if present[e.key] and days_left(e) == nil then unknown = true end
    end
    if state.running and (unknown or force) then read_contracts() end
    update_extend_due(present)
    local due = gget('extend_due', '')
    if due ~= '' then
        log('Employment: contract extension needed - ' .. due .. ' (//ml extend, or //gh emp extend here).')
    end

    if not state.running then
        gh.persist_status()
        return
    end
    gset('checked_at', stamp())
    if #run_errors > 0 then
        gset('error', table.concat(run_errors, '; '))
        gset('error_date', today())
    else
        gset('error', '')
        gset('checked_date', today())
    end
    gh.persist_status()
    local parts = {}
    for _, e in ipairs(EMPLOYEES) do
        if present[e.key] then
            local d = days_left(e)
            table.insert(parts, e.label .. ' ' .. (d and (d .. 'd') or '?'))
        end
    end
    log('Employment: ' .. count .. ' assistant' .. (count == 1 and '' or 's') .. ' recruited' ..
        (#parts > 0 and (' - ' .. table.concat(parts, ', ')) or '') .. (#run_errors > 0 and ' - ERRORS, see //gh status.' or '.'))
end

-- For //gh duecheck: a short reason when the employment step has work
-- (item to trade, notice missing, contract due / unknown), else nil.
function M.due()
    if not enabled() or not gh.in_mog_garden() then return nil end
    local present, count = refresh_presence()
    for _, e in ipairs(EMPLOYEES) do
        local _, total = held(e)
        if total > 0 and (not present[e.key] or cfgv('employment_trade_spare_items', true)) then
            return 'employment (' .. e.item .. ')'
        end
    end
    -- An error today (e.g. not enough gil) is not retried until tomorrow
    -- by duecheck - a //gh full still tries.
    if gget('error_date', '') == today() and gget('error', '') ~= '' then return nil end
    if notify_due(count, false) then return 'employment (contract notices)' end
    for _, e in ipairs(EMPLOYEES) do
        if present[e.key] and days_left(e) == nil then return 'employment (' .. e.label .. ' contract days)' end
    end
    return nil
end

-- //gh status rows.
function M.status_rows()
    local rows = {}
    local count = tonumber(gget('count', 0)) or 0
    local err = gget('error', '')
    local when
    if err ~= '' then
        when = 'ERROR: ' .. err
    elseif gget('checked_date', '') == today() then
        when = 'checked today'
    else
        when = 'not checked today' .. (gget('checked_at', '') ~= '' and (' (last ' .. gget('checked_at', '') .. ')') or '')
    end
    table.insert(rows, {label = 'Assistants recruited', value = count .. ' - ' .. when ..
        (gget('notice_date', '') == today() and ' (daily contract notice seen)' or '')})
    if gget('extend_due', '') ~= '' then
        table.insert(rows, {label = 'Contract extension needed', value = gget('extend_due', '') .. ' - //ml extend (or //gh emp extend here)'})
    end
    for _, e in ipairs(EMPLOYEES) do
        local r = sget(e, 'recruited', '')
        local text
        if r == 'n' then
            text = 'not recruited (unlock item: ' .. e.item .. ')'
        elseif r == '' then
            text = 'unknown (not checked yet)'
        else
            local d = days_left(e)
            if d == nil then
                text = 'contract days unknown (read at the next check)'
            else
                text = d .. ' days left' .. (d > 0 and (' (until ' .. sget(e, 'expires', '?') .. ')') or ' - NOT under contract') ..
                    ', read ' .. sget(e, 'days_date', '?') .. ' (' .. sget(e, 'source', '?') .. ')'
            end
            local la = sget(e, 'last_action', '')
            if la ~= '' then text = text .. '; last: ' .. la end
        end
        table.insert(rows, {label = e.name .. ' contract', value = text})
    end
    return rows
end

local function reset_data()
    for _, e in ipairs(EMPLOYEES) do
        for _, f in ipairs({'recruited', 'days_date', 'days_seen_at', 'source', 'expires', 'last_action', 'last_action_at'}) do
            sset(e, f, '')
        end
        sset(e, 'days', -1)
    end
    for _, f in ipairs({'checked_date', 'checked_at', 'error', 'error_date', 'notice_date', 'notify_set_date', 'extend_due'}) do
        gset(f, '')
    end
    gset('count', 0)
    gh.persist_status()
end

-- ---- Packet capture (//gh emp capture on|off) ----
-- Neither setkey digits nor Up reach the weeks box (Genpopvf 18:19,
-- 19:23: the box always sent 0 weeks). To find how the week count goes
-- to the server, this logs the event packets while you extend by hand:
-- outgoing 0x05B (menu choice / number) and incoming 0x032 / 0x034
-- (event start) / 0x05C (event update) / 0x052 (release), with every
-- field and the raw bytes, to data/employment_packets.log (+ chat).
local CAPTURE_FILE = windower.addon_path .. 'data/employment_packets.log'
local capture_on = false
local function hex(data)
    return (data:gsub('.', function(c) return string.format('%02X ', c:byte()) end))
end
local function capture_write(dir, id, data)
    local line = stamp() .. string.format('  %s 0x%03X  ', dir, id)
    local ok, packets = pcall(require, 'packets')
    if ok and packets then
        local ok2, p = pcall(packets.parse, dir, data)
        if ok2 and type(p) == 'table' then
            local parts = {}
            for k, v in pairs(p) do
                if type(k) == 'string' and k:sub(1, 1) ~= '_' or k == '_unknown1' or k == '_unknown2' then
                    if type(v) == 'string' then v = hex(v) end
                    table.insert(parts, tostring(k) .. '=' .. tostring(v))
                end
            end
            table.sort(parts)
            line = line .. table.concat(parts, ', ')
        end
    end
    line = line .. '\n    raw: ' .. hex(data)
    local f = io.open(CAPTURE_FILE, 'a')
    if f then f:write(line .. '\n') f:close() end
    if dir == 'outgoing' then
        log('[capture] ' .. line:gsub('\n.*', ''), 207)
    end
end
local CAPTURE_OUT = {[0x05B] = true}
local CAPTURE_IN = {[0x032] = true, [0x034] = true, [0x05C] = true, [0x052] = true}
windower.register_event('outgoing chunk', function(id, data)
    if (capture_on or capture_session) and CAPTURE_OUT[id] then pcall(capture_write, 'outgoing', id, data) end
end)
windower.register_event('incoming chunk', function(id, data)
    if (capture_on or capture_session) and CAPTURE_IN[id] then pcall(capture_write, 'incoming', id, data) end
    local ok, block = pcall(packet_incoming, id, data)
    if ok and block then return true end
end)

-- //gh employment|emp [force|notify|status|reset|capture|help]
function M.command(args)
    local sub = args[2] and args[2]:lower() or ''
    if sub == 'unstick' or sub == 'unstuck' or sub == 'reset_talk' then
        -- A Green Thumb Moogle talk left open (v2.12.0 hire, Cookvf 20:42):
        -- can't move / target / log out, the moogle doesn't answer. Sends
        -- the game's own "cancel this talk" (menu choice 0 with the cancel
        -- flag 0x4000, not automated) and then releases the client.
        local t = last_talk or {}
        local idx, zone, menu = t.npc_index or 29, t.zone or 280, t.menu or menu_id()
        local pkt = string.char(0x5B, 0x0A, 0, 0) .. le32(config.sell_junk_moogle_id) .. le16(0) .. le16(0x4000) ..
            le16(idx) .. string.char(0, 0) .. le16(zone) .. le16(menu)
        windower.packets.inject_outgoing(0x5B, pkt)
        log('Employment: sent "end talk" to the Green Thumb Moogle (menu ' .. menu .. ') - releasing the client...')
        coroutine.schedule(function()
            windower.packets.inject_incoming(0x052, string.char(0x52, 0x04, 0, 0, 0, 0, 0, 0))
            coroutine.sleep(0.5)
            windower.packets.inject_incoming(0x052, string.char(0x52, 0x04, 0, 0, 1, 0, 0, 0))
            coroutine.sleep(0.5)
            windower.send_command('target clear')
            local p = windower.ffxi.get_player()
            log('Employment: done - ' .. ((p and p.status == 4) and 'still in a talk; try //gh emp unstick once more, then Escape' or 'you should be able to move again') .. '.')
        end, 1.5)
        return
    end
    if sub == 'extend' then
        -- //gh emp extend [min_days=30] [auto]: every recruited assistant
        -- with fewer than min_days left, one after another: the menus are
        -- opened up to the weeks box, you type the weeks + Enter, the rest
        -- is done for you. auto (MuleLogger) = "ExtendResult: DONE|NONE|FAILED".
        -- v2.23.0: target <days> = line every assistant up within 7 days
        -- of that many contract days (//ml extend: the longest contract on
        -- any character); you are told the weeks to type for each one.
        local min_days, auto, target = threshold(), false, nil
        local i = 3
        while i <= #args do
            local a = args[i]:lower()
            if a == 'auto' then auto = true
            elseif a == 'target' and tonumber(args[i + 1] or '') then
                target = math.floor(tonumber(args[i + 1]))
                i = i + 1
            elseif tonumber(a) then min_days = tonumber(a) end
            i = i + 1
        end
        local max_weeks = tonumber(cfgv('employment_max_weeks_per_hire', 9)) or 9
        run_errors = {}
        local present, count = refresh_presence()
        local done, left = {}, {}
        if count > 0 then
            read_contracts()
            for _, e in ipairs(EMPLOYEES) do
                if not state.running then break end
                if present[e.key] and target then
                    -- v2.23.0: weeks = whole weeks that still fit under the
                    -- target (ends within 7 days of it, never past it); more
                    -- than one box's worth = another round.
                    local d = days_left(e)
                    if d == nil then
                        fail(e.label .. ': contract days unknown - cannot work out the weeks')
                        table.insert(left, e.label)
                    else
                        local need = math.floor((target - d) / 7)
                        if need <= 0 then
                            log('Employment: ' .. e.label .. ' - ' .. d .. ' days left, within 7 of the target (' .. target .. '), no extension needed.')
                        else
                            log('Employment: ' .. e.label .. ' - ' .. d .. ' days left, target ' .. target .. ' -> ' .. need .. ' week(s)' ..
                                (need > max_weeks and (' (' .. max_weeks .. ' per box, so more than one round)') or '') .. '.')
                            local rounds, extended, ok = 0, false, true
                            while need > 0 and rounds < 3 and state.running do
                                rounds = rounds + 1
                                local was = d
                                ok = extend_by_hand(e, list_pos(e, present), math.min(need, max_weeks))
                                if not ok then break end
                                extended = true
                                d = days_left(e)
                                if d == nil or d <= was then break end
                                need = math.floor((target - d) / 7)
                            end
                            if extended then table.insert(done, e.label) end
                            if not ok then table.insert(left, e.label) end
                        end
                    end
                elseif present[e.key] then
                    local d = days_left(e)
                    if d ~= nil and d >= min_days then
                        log('Employment: ' .. e.label .. ' - ' .. d .. ' days left (' .. min_days .. '+), no extension needed.')
                    elseif extend_by_hand(e, list_pos(e, present)) then
                        table.insert(done, e.label)
                    else
                        table.insert(left, e.label)
                    end
                end
            end
        end
        update_extend_due(present)
        if #run_errors > 0 then
            gset('error', table.concat(run_errors, '; '))
            gset('error_date', today())
        else
            gset('error', '')
        end
        gh.persist_status()
        local result = (#run_errors > 0) and 'FAILED' or (#done > 0 and 'DONE' or 'NONE')
        log('Employment: extend - ' .. (count == 0 and 'no assistants recruited' or
            ((#done > 0 and ('extended ' .. table.concat(done, ', ')) or 'nothing extended') ..
            (#left > 0 and ('; NOT extended: ' .. table.concat(left, ', ')) or ''))) .. '.')
        if auto then log('ExtendResult: ' .. result) end
        return
    end
    if sub == 'capture' then
        local what = args[3] and args[3]:lower() or (capture_on and 'off' or 'on')
        capture_on = (what == 'on')
        if capture_on then
            local f = io.open(CAPTURE_FILE, 'a')
            if f then f:write('==== capture on ' .. stamp() .. ' (' .. tostring(gh.character_key() or '?') .. ') ====\n') f:close() end
            log('Employment: packet capture ON - extend an assistant by hand now; //gh emp capture off when done. Log: data/employment_packets.log')
        else
            log('Employment: packet capture OFF.')
        end
        return
    end
    if sub == 'help' then
        log('//gh emp - recruit assistants whose unlock item you hold (Kuyin: Dragoneye, Susuroon: Rusted Coin, Yeestog: Fat Burrow Worm), trade spare items for +7 days, turn contract notices on, read every contract and flag the ones under ' .. threshold() .. ' days (extend them by hand: //gh emp extend). Also at the start of every //gh full.')
        log('//gh emp force - also read every contract at the moogle and set the notices')
        log('//gh emp extend [days=30] - for each assistant under that many days: menus up to the weeks box, YOU type the weeks + Enter, the rest is done for you (//ml extend does it on every character)')
        log('//gh emp extend target <days> - instead: each assistant gets the weeks that bring it within 7 days of <days> (you are told the number to type; a wrong number is backed out). //ml extend uses the longest contract on any character')
        log('//gh emp notify - set contract notices to "Always notify me" now')
        log('//gh emp status - saved contract data;  reset - forget it all (the next //gh emp checks everything again)')
        log('History: data/employment_history.log')
        return
    end
    if sub == 'status' then
        for _, row in ipairs(M.status_rows()) do log('  ' .. row.label .. ': ' .. row.value) end
        return
    end
    if sub == 'reset' then
        reset_data()
        log('Employment: saved contract data cleared - the next //gh emp (or //gh full) checks every assistant again.')
        return
    end
    if sub == 'notify' then
        run_errors = {}
        local _, count = refresh_presence()
        if count == 0 then log('Employment: no assistant recruited - nothing to be notified about.') return end
        set_notify_always(count)
        gh.persist_status()
        return
    end
    if sub ~= '' and sub ~= 'force' then
        error_log('Unknown //gh emp option "' .. sub .. '" - //gh emp help.')
        return
    end
    if not enabled() then
        log('Employment: switched off for this character (characters.lua employment = false / config.employment_enabled).')
        return
    end
    log('Checking assistant employment' .. (sub == 'force' and ' (force - reading every contract)' or '') .. '...')
    M.run(sub == 'force')
end

return M
end

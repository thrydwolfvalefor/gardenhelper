-- =====================================================================
-- Set_RoE.lua - GardenHelper module: daily Records of Eminence
-- objectives and the Unity chat line (no RoE addon needed).
--   //gh roe          - set this character's objectives (once per
--                       garden day), then the Unity chat line
--   //gh roe force    - set the objectives even if already done today
--   //gh roe set      - objectives only (even if set today);
--   //gh roe chat     - chat only
--   //gh roe list     - objectives active right now (id: progress)
--   //gh roe status / help
--   //gh roe auto     - same as //gh roe, ends with "RoEResult: ..."
-- Also run at the end of //gh full (config.roe_in_full).
-- characters.lua (defaults, or overrides per character):
--   roe_objectives     = {3000, 3009, ...}   {} = off
--   unity_chat_message = '.'                 '' = off
--   unity_chat_min_interval_seconds = 600    min seconds between chat lines
-- characters.lua modules: set_roe = false / unity_chat = false turn
-- either step off for one character.
-- Objectives are accepted with the same packets the RoE addon uses
-- (out 0x10C accept, 0x10D cancel; in 0x111 active list, 0x112
-- completed flags). One the server won't give you (e.g. a Unity
-- Communique from another week) is just not accepted - harmless.
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
-- =====================================================================
return function(gh)

local packets = require('packets')
local config, state, saved_status = gh.config, gh.state, gh.saved_status
local log, debug_log, error_log = gh.log, gh.debug_log, gh.error_log
local get_garden_day_string, is_module_enabled, persist_status = gh.get_garden_day_string, gh.is_module_enabled, gh.persist_status
local CHARACTER_FILE = gh.character_file or {}

local M = {version = '1.1.0'}

-- Config defaults (GardenHelper.lua's config wins if it sets any).
for key, value in pairs({
    roe_in_full = true,                     -- run //gh roe at the end of //gh full
    roe_packet_delay_seconds = 0.5,         -- pause between accept/cancel packets
    roe_set_wait_seconds = 2,               -- wait for the server's updated list before checking
    roe_clear_zero_progress = true,         -- slots full: cancel objectives with 0 progress that aren't in the list
    unity_chat_wait_seconds = 3,            -- after the chat line, before moving on
    unity_chat_only_for_communique = true,  -- only chat while a Unity Communique objective is active
}) do
    if config[key] == nil then config[key] = value end
end

local MAX_SLOTS = 30
-- Unity Communique A-F (UC) - completed by one Unity chat line.
local UNITY_COMMUNIQUE = {[3000] = 'A', [3009] = 'B', [3018] = 'C', [3027] = 'D', [3036] = 'E', [3045] = 'F'}

local active = {}          -- objective id -> progress (0x111)
local active_known = false -- a 0x111 has been seen
local complete = {}        -- objective id -> true (0x112)

local function read_active(data)
    active = {}
    for i = 1, MAX_SLOTS do
        local id, progress = data:unpack('b12b20', 5 + (i - 1) * 4)
        if id and id > 0 then active[id] = progress end
    end
    active_known = true
end

local function read_complete(data)
    local page = data:unpack('H', 133) or 0
    local bits = {data:unpack(('b1'):rep(1024), 4)}
    for k = 1, 1024 do
        complete[k + 1024 * page - 1] = (bits[k] == 1) or nil
    end
end

windower.register_event('incoming chunk', function(id, data)
    if id == 0x111 then
        read_active(data)
    elseif id == 0x112 then
        read_complete(data)
    end
end)

do
    local last = windower.packets.last_incoming(0x111)
    if last then read_active(last) end
    last = windower.packets.last_incoming(0x112)
    if last then read_complete(last) end
end

local function count_active()
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n
end

-- characters.lua value for the logged-in character: overrides, then defaults.
local function char_value(key)
    local player = windower.ffxi.get_player()
    local name = player and player.name and player.name:lower()
    local overrides = type(CHARACTER_FILE.overrides) == 'table' and name and CHARACTER_FILE.overrides[name]
    if type(overrides) == 'table' and overrides[key] ~= nil then return overrides[key] end
    return type(CHARACTER_FILE.defaults) == 'table' and CHARACTER_FILE.defaults[key] or nil
end

-- This character's objective ids (numbers, no duplicates), in order.
local function objective_list()
    local list, seen = {}, {}
    local raw = char_value('roe_objectives')
    if type(raw) == 'string' then
        local t = {}
        for part in raw:gmatch('[^,%s]+') do table.insert(t, part) end
        raw = t
    end
    for _, v in ipairs(type(raw) == 'table' and raw or {}) do
        local id = tonumber(v)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            table.insert(list, id)
        end
    end
    return list
end

local function chat_message()
    local msg = char_value('unity_chat_message')
    return type(msg) == 'string' and msg or ''
end

-- SAFETY LIMIT (Unity chat is public): characters.lua
-- unity_chat_min_interval_seconds, never below 60; 600 if not set.
local function chat_interval()
    local n = tonumber(char_value('unity_chat_min_interval_seconds')) or 600
    return math.max(n, 60)
end

local function set_today()
    return (tonumber(saved_status.roe_last_set_epoch) or 0) > 0
        and get_garden_day_string(tonumber(saved_status.roe_last_set_epoch)) == get_garden_day_string()
end

local function inject(packet_id, objective_id)
    packets.inject(packets.new('outgoing', packet_id, {['RoE Quest'] = objective_id}))
    coroutine.sleep(config.roe_packet_delay_seconds)
end

-- Objectives step. Returns 'set' / 'already' / 'off' / 'failed'.
local function set_objectives(force)
    if not is_module_enabled('set_roe') then
        log('RoE: set_roe = false for this character in characters.lua - skipped.')
        return 'off'
    end
    local list = objective_list()
    if #list == 0 then
        debug_log('RoE: no roe_objectives for this character in characters.lua - skipped.')
        return 'off'
    end
    if not force and set_today() then
        log('RoE: objectives already set this garden day (//gh roe force to set again).')
        return 'already'
    end

    -- Everything not active is sent - the server refuses what isn't
    -- available (done today, another week's objective), so a stale
    -- completed flag can never block one.
    local needed, in_list = {}, {}
    local already = 0
    for _, id in ipairs(list) do
        in_list[id] = true
        if active[id] then
            already = already + 1
        else
            table.insert(needed, id)
        end
    end

    -- Make room: cancel 0-progress objectives that aren't in the list.
    local free = MAX_SLOTS - count_active()
    if #needed > free and config.roe_clear_zero_progress then
        for id, progress in pairs(active) do
            if #needed <= free then break end
            if progress == 0 and not in_list[id] then
                inject(0x10D, id)
                free = free + 1
                log('RoE: cancelled objective ' .. id .. ' (no progress) to make room.')
            end
        end
    end
    if #needed > free then
        error_log('RoE: only ' .. free .. ' free objective slot(s) for ' .. #needed .. ' objective(s) - setting the first ' .. free .. '.')
    end

    local sent = {}
    for i, id in ipairs(needed) do
        if i > free or not state.running then break end
        inject(0x10C, id)
        table.insert(sent, id)
    end
    if #sent > 0 then coroutine.sleep(config.roe_set_wait_seconds) end

    local took, done, refused = {}, {}, {}
    for _, id in ipairs(sent) do
        table.insert(active[id] and took or (complete[id] and done or refused), tostring(id))
    end
    log('RoE: ' .. #took .. ' set' .. (#took > 0 and (' (' .. table.concat(took, ', ') .. ')') or '') ..
        ', ' .. already .. ' already active' ..
        (#done > 0 and (', ' .. #done .. ' already completed (' .. table.concat(done, ', ') .. ')') or '') ..
        (#refused > 0 and (', ' .. #refused .. ' not accepted (' .. table.concat(refused, ', ') .. ' - not available now)') or '') .. '.')

    local now = os.time()
    saved_status.roe_last_set_epoch = now
    saved_status.roe_last_set_at = os.date('%Y-%m-%d %H:%M:%S', now)
    persist_status()
    return 'set'
end

local function communique_active()
    for id in pairs(UNITY_COMMUNIQUE) do
        if active[id] then return true end
    end
    return false
end

-- Unity chat step. Returns 'sent' / 'limit' / 'off' / 'not_needed'.
local function unity_chat()
    if not is_module_enabled('unity_chat') then
        log('Unity chat: unity_chat = false for this character in characters.lua - skipped.')
        return 'off'
    end
    local msg = chat_message()
    if msg == '' then
        debug_log('Unity chat: no unity_chat_message in characters.lua - skipped.')
        return 'off'
    end
    if config.unity_chat_only_for_communique and active_known and not communique_active() then
        log('Unity chat: no Unity Communique objective active - not sent.')
        return 'not_needed'
    end
    local last = tonumber(saved_status.unity_chat_last_epoch) or 0
    local since = os.time() - last
    local interval = chat_interval()
    if last > 0 and since < interval then
        log('Unity chat safety limit: sent ' .. math.floor(since / 60) .. ' min ago (1 per ' ..
            math.floor(interval / 60) .. ' min per character) - not sent.')
        return 'limit'
    end
    log('Unity chat: sending "' .. msg .. '" (Unity Communique).')
    windower.chat.input('/u ' .. msg)
    coroutine.sleep(config.unity_chat_wait_seconds)
    local now = os.time()
    saved_status.unity_chat_last_epoch = now
    saved_status.unity_chat_last_at = os.date('%Y-%m-%d %H:%M:%S', now)
    persist_status()
    return 'sent'
end

-- Both steps (//gh roe, //gh full). Returns roe result, chat result.
function M.run(force)
    local roe = set_objectives(force)
    if not state.running then return roe, 'stopped' end
    local chat = unity_chat()
    return roe, chat
end

function M.status_text()
    if not is_module_enabled('set_roe') and not is_module_enabled('unity_chat') then
        return 'skipped per character config'
    end
    local list = objective_list()
    local parts = {}
    if #list == 0 or not is_module_enabled('set_roe') then
        table.insert(parts, 'objectives off')
    else
        local on = 0
        for _, id in ipairs(list) do if active[id] then on = on + 1 end end
        table.insert(parts, (set_today() and 'set today' or 'NOT set today') .. ' (' .. on .. ' of ' .. #list .. ' active)')
    end
    if chat_message() == '' or not is_module_enabled('unity_chat') then
        table.insert(parts, 'Unity chat off')
    else
        local at = saved_status.unity_chat_last_at
        table.insert(parts, 'Unity chat ' .. ((at and at ~= '') and ('last ' .. at) or 'never sent'))
    end
    return table.concat(parts, ', ')
end

function M.help()
    for _, line in ipairs({
        'RoE (Set_RoE.lua v' .. M.version .. ') - objectives from characters.lua roe_objectives, chat line from unity_chat_message:',
        '  //gh roe          - set the objectives (once per garden day), then the Unity chat line',
        '  //gh roe force    - set the objectives even if already set today',
        '  //gh roe set      - objectives only (even if set today);  //gh roe chat - Unity chat line only',
        '  //gh roe list     - objectives active right now (id: progress)',
        '  //gh roe status   - this character\'s RoE / Unity chat status',
        '  //gh roe auto     - //gh roe for scripts: ends with "RoEResult: DONE roe=<r> chat=<c> chat_at=<epoch of the last chat line>"',
        '  Also runs at the end of //gh full (roe_in_full). Unity chat: max 1 line per ' ..
            math.floor(chat_interval() / 60) .. ' min per character (unity_chat_min_interval_seconds)' ..
            (config.unity_chat_only_for_communique and ', only while a Unity Communique is active' or '') .. '.',
    }) do
        log(line)
    end
end

-- //gh roe [force|set|chat|list|status|help|auto]. GardenHelper sets
-- state.running around it.
function M.command(args)
    local sub = args[2] and args[2]:lower() or ''
    local auto = false
    for i = 2, #args do
        if args[i]:lower() == 'auto' then auto = true end
    end
    if sub == 'auto' then sub = '' end
    local roe, chat = '-', '-'
    if sub == '' or sub == 'force' then
        roe, chat = M.run(sub == 'force')
    elseif sub == 'set' then
        roe = set_objectives(true)
    elseif sub == 'chat' or sub == 'unity' then
        chat = unity_chat()
    elseif sub == 'list' then
        local ids = {}
        for id, progress in pairs(active) do table.insert(ids, id) end
        table.sort(ids)
        local shown = {}
        for _, id in ipairs(ids) do
            table.insert(shown, id .. ': ' .. active[id] .. (UNITY_COMMUNIQUE[id] and (' (Unity Communique ' .. UNITY_COMMUNIQUE[id] .. ')') or ''))
        end
        log('RoE: ' .. #ids .. ' of ' .. MAX_SLOTS .. ' slots used' .. (active_known and '' or ' (no RoE list from the server yet)') ..
            (#ids > 0 and (' - ' .. table.concat(shown, ', ')) or '.'))
    elseif sub == 'status' then
        log('RoE / Unity: ' .. M.status_text())
    else
        M.help()
    end
    if auto then
        log('RoEResult: ' .. ((roe == 'failed') and 'FAILED' or 'DONE') .. ' roe=' .. roe .. ' chat=' .. chat ..
            ' chat_at=' .. (tonumber(saved_status.unity_chat_last_epoch) or 0))
    end
end

return M
end

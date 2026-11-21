-- =====================================================================
-- assistants.lua - GardenHelper module: the Mog Garden assistants
-- (Kuyin Hathdenna, Susuroon, Yeestog).
--   * //gh assistants [force|status|list|done|reset] [name]
--   * check_all: every assistant, at the start of every full garden run
--     (//gh full / force / full inspect).
--   * before_harvest(node): "Preparing to harvest <node>, checking on
--     assistant settings" - single node / furrow commands, for the
--     assistants characters.lua puts on THAT node only.
--   Each node is checked at most once per command (begin_run clears).
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
-- Returns {begin_run, check_all, before_harvest, command, status_rows, present}.
--
-- Where an assistant is: each assistant has a different entity id for
-- each node it can work, and only the id for the node it is on right now
-- is loaded. So the NODE is read without talking to anyone, and neither
-- id loaded = assistant not in this garden (not unlocked).
-- What it is doing there (the TASK) is never shown by the game, so the
-- task GardenHelper last set is saved in data/settings.xml
-- (assistant_<name>_node / _task) and trusted. Changed an assistant by
-- hand? //gh assistants reset <name> (or force) so it gets set again.
-- =====================================================================
return function(gh)

local config, state, saved_status = gh.config, gh.state, gh.saved_status
local log, debug_log, error_log = gh.log, gh.debug_log, gh.error_log
local ENTITIES = gh.ENTITIES

-- Menus, counted in Down presses from the top line (the cursor always
-- starts on "Let me pet ..."). Talking: Enter (greeting, short black
-- screen) -> Enter (what they are doing now) -> Enter opens the node
-- menu -> Down x node.menu, Enter -> Down x task.menu, Enter -> their
-- "got it" line -> Enter closes it -> short black screen, and the
-- assistant reappears at the new node (new entity id).
--   duty    = text in the "what they are doing now" line for that node
--   confirm = text in the "got it" line ({} = not known: any line from
--             them after the task Enter counts, and it is printed)
--   entity  = entities.lua entry with the spot to stand on to talk
local ASSISTANTS = {
    {key = 'kuyin', name = 'Kuyin Hathdenna', label = 'Kuyin',
     confirm = {'I know what to do'},
     nodes = {
        furrow = {menu = 1, id = 17924202, entity = 'Kuyin Furrow', duty = 'growing in the furrows', tasks = {
            harvest = {menu = 0, text = 'Harvest a lot of crops.'},
            seeds   = {menu = 1, text = 'Look for seeds.'}}},
        pond = {menu = 2, id = 17924183, entity = 'Kuyin Pond', duty = 'in the pond', tasks = {
            catch   = {menu = 0, text = 'Catch something.'},
            whopper = {menu = 1, text = 'Go after a whopper.'},
            minnow  = {menu = 2, text = 'Aim for a minnow.'}}},
     }},
    {key = 'susuroon', name = 'Susuroon', label = 'Susuroon',
     confirm = {'Susuroon command'},
     nodes = {
        furrow = {menu = 1, id = 17924184, entity = 'Susuroon Furrow', duty = 'good with furrows', tasks = {
            harvest = {menu = 0, text = 'Harvest a lot of crops.'},
            good    = {menu = 1, text = 'Grow me something good.'}}},
        net = {menu = 2, id = 17924203, entity = 'Susuroon Net', duty = 'coast net', tasks = {
            catch   = {menu = 0, text = 'Catch something.'},
            whopper = {menu = 1, text = 'Go after a whopper.'},
            minnow  = {menu = 2, text = 'Aim for a minnow.'}}},
     }},
    {key = 'yeestog', name = 'Yeestog', label = 'Yeestog',
     confirm = {"gud day's woik"},
     nodes = {
        grove = {menu = 1, id = 17924204, entity = 'Yeestog Grove', duty = 'dat grove', tasks = {
            easier = {menu = 0, text = 'Make gathering easier.'},
            repair = {menu = 1, text = 'Repair the tools.'}}},
        vein = {menu = 2, id = 17924185, entity = 'Yeestog Vein', duty = "min'ral vein", tasks = {
            easier = {menu = 0, text = 'Make excavating easier.'},
            repair = {menu = 1, text = 'Repair the tools.'}}},
     }},
}
local BY_KEY = {}
for _, a in ipairs(ASSISTANTS) do BY_KEY[a.key] = a end
BY_KEY['kuyin hathdenna'] = BY_KEY.kuyin

local NODE_LABELS = {furrow = 'Furrows', vein = 'Vein', pond = 'Pond', grove = 'Grove', net = 'Net'}

local function cfgv(key, default)
    local v = config[key]
    if v == nil then return default end
    return v
end

local function blank(v)
    return v == nil or v == ''
end

-- Keys of t sorted by their .menu position.
local function by_menu(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys, function(x, y) return t[x].menu < t[y].menu end)
    return keys
end

local function sget(a, field)
    local v = saved_status['assistant_' .. a.key .. '_' .. field]
    if v == nil then return '' end
    return v
end

local function sset(a, field, value)
    saved_status['assistant_' .. a.key .. '_' .. field] = value
end

local function task_text(a, node, task)
    local n = a.nodes[node]
    local t = n and n.tasks[task]
    return t and ('"' .. t.text .. '"') or ('"' .. tostring(task) .. '"')
end

-- This character's setting from characters.lua: node, task (lowercase),
-- or nil + 'off' (not managed) / an error text (bad setting).
-- defaults.assistants.<name> = {node = ..., task = ...} or false;
-- overrides.<character>.assistants.<name> = the same. Left out (or '')
-- in the override = the default applies; false = don't manage it here.
-- An override that changes the node must give its task too.
local function configured(a)
    local cf = gh.character_file or {}
    local defaults = type(cf.defaults) == 'table' and cf.defaults.assistants or nil
    local d = type(defaults) == 'table' and defaults[a.key] or nil
    local override = gh.get_character_override()
    local ov_all = type(override) == 'table' and override.assistants or nil
    local ov = nil
    if type(ov_all) == 'table' then ov = ov_all[a.key] end
    if ov == false then return nil, 'off' end

    local node, task
    if type(d) == 'table' then node, task = d.node, d.task end
    if type(ov) == 'table' then
        if not blank(ov.node) then
            if tostring(ov.node):lower() ~= tostring(node or ''):lower() then task = nil end
            node = ov.node
        end
        if not blank(ov.task) then task = ov.task end
    end
    if blank(node) then return nil, 'off' end

    node = tostring(node):lower()
    local n = a.nodes[node]
    if not n then
        return nil, 'node "' .. node .. '" is not one ' .. a.label .. ' can work (' .. table.concat(by_menu(a.nodes), ', ') .. ')'
    end
    if blank(task) then
        return nil, 'no task for node "' .. node .. '" (an override that changes the node needs its task too: ' ..
            table.concat(by_menu(n.tasks), ', ') .. ')'
    end
    task = tostring(task):lower()
    if not n.tasks[task] then
        return nil, 'task "' .. task .. '" is not a ' .. node .. ' task for ' .. a.label .. ' (' .. table.concat(by_menu(n.tasks), ', ') .. ')'
    end
    return node, task
end

-- Node the assistant is on right now (from which entity id is loaded),
-- or nil = not in this garden.
local function live_node(a)
    for node, n in pairs(a.nodes) do
        if gh.entity_present(n.id) then
            return node
        end
    end
    return nil
end

-- Bad characters.lua settings are reported once per character per load.
local warned = {}
local function warn_config(a, why)
    local key = tostring(gh.character_key() or '') .. ':' .. a.key .. ':' .. why
    if not warned[key] then
        warned[key] = true
        error_log(a.label .. ': characters.lua assistants setting ignored - ' .. why .. '.')
    end
end

-- Leaves the conversation (if any) and clears the target.
local function back_out()
    gh.clear_cursor_state()
    windower.send_command('target clear')
end

-- Waits until the event (conversation / black screen) is over and the
-- assistant's id for want_node is loaded (and, when it moved, the old
-- one gone). Returns the node it is on afterwards.
local function wait_for_move(a, from_node, want_node)
    local limit = cfgv('assistant_move_wait_seconds', 12)
    local to_id, from_id = a.nodes[want_node].id, a.nodes[from_node].id
    local waited = 0
    -- Never press Enter here: if the conversation is still open, a menu
    -- may be too, and Enter would pick whatever the cursor is on.
    while waited < limit and state.running do
        local p = windower.ffxi.get_player()
        local in_event = p ~= nil and p.status == 4
        if not in_event and gh.entity_present(to_id) and (want_node == from_node or not gh.entity_present(from_id)) then
            break
        end
        coroutine.sleep(0.5)
        waited = waited + 0.5
    end
    coroutine.sleep(cfgv('assistant_after_move_seconds', 1.0))
    return live_node(a)
end

-- Walks to the assistant (on from_node), talks, and picks node / task.
-- Records the result. Returns true when the game confirmed it.
local function assign(a, from_node, node, task)
    local from, to = a.nodes[from_node], a.nodes[node]
    local t = to.tasks[task]
    local label = a.label .. ' (' .. from_node .. ')'
    back_out()
    coroutine.sleep(0.2)

    local entry = ENTITIES[from.entity] or {friendly = from.entity, name = a.name, zone = 280, id = from.id}
    if not gh.navigate_to_entity(entry, from.id, label) then
        if state.running then
            error_log(a.label .. ': could not walk to ' .. label .. ' - not changed this time.')
        end
        back_out()
        return false
    end
    if not state.running then return false end
    gh.ensure_in_interact_range(from.id, label, nil)
    if not (gh.current_target_is(from.id, a.name) or gh.find_entity(from.id, a.name)) then
        error_log(a.label .. ': could not target ' .. a.name .. ' (id ' .. from.id .. ') - not changed this time.')
        back_out()
        return false
    end

    local wait = cfgv('assistant_text_wait_seconds', 8)
    local line_settle = cfgv('assistant_line_settle_seconds', 1.5)
    local settle = cfgv('assistant_menu_settle_seconds', 1.5)
    local submenu_settle = cfgv('assistant_submenu_settle_seconds', 2.0)
    local down_settle = cfgv('assistant_down_settle_seconds', 0.7)
    -- Enter, wait for their next line, then let it finish showing: an
    -- Enter while a line is still being written only completes the line
    -- and does NOT advance (2026-09-26 19:33: the menu Enter was eaten,
    -- every later key landed one menu early).
    -- first = the talk's opening Enter: also stops on "Target out of
    -- range." (gh.range_retry then walks closer and presses again).
    local function enter_for_text(first)
        local phrases = {a.name}
        if first then
            for _, p in ipairs(config.out_of_range_phrases) do table.insert(phrases, p) end
        end
        local seen, lines = gh.capture_until(wait, phrases, function() gh.press_key('enter', 0.1) end)
        if seen and first and not gh.lines_contain(lines, a.name) then seen = false end
        if seen then coroutine.sleep(line_settle) end
        return seen, lines
    end

    -- 1) greeting, 2) what they are doing now.
    local seen = gh.range_retry(from.id, a.name, function() return enter_for_text(true) end)
    if not seen or not state.running then
        if state.running then
            error_log(a.label .. ': no answer after Enter (out of range, or a menu was already open?) - not changed this time.')
        end
        back_out()
        return false
    end
    local lines
    seen, lines = enter_for_text()
    if not seen or not state.running then
        if state.running then
            error_log(a.label .. ': the conversation stopped after the greeting - not changed this time.')
        end
        back_out()
        return false
    end
    for nk, n in pairs(a.nodes) do
        if gh.lines_contain(lines, n.duty) and nk ~= from_node then
            debug_log(a.label .. ': says it is on ' .. nk .. ' but its ' .. from_node .. ' id is loaded - going by the id.')
        end
    end

    -- 3) node menu, node, task.
    gh.press_key('enter', settle)
    for _ = 1, to.menu do gh.press_key('down', down_settle) end
    gh.press_key('enter', submenu_settle)
    for _ = 1, t.menu do gh.press_key('down', down_settle) end
    coroutine.sleep(0.3)
    if not state.running then back_out() return false end
    seen, lines = gh.capture_until(wait, a.name, function() gh.press_key('enter', 0.1) end)
    local said = ''
    for _, l in ipairs(lines or {}) do
        if l:find(a.name, 1, true) then said = gh.strip_timestamp_prefix(l) break end
    end
    local confirmed = seen and (#a.confirm == 0 or gh.lines_contain(lines, a.confirm))
    if #a.confirm == 0 and seen then
        log(a.label .. ' said: ' .. said .. '  (not seen before - please send this line so it can be checked for)')
    elseif seen and not confirmed then
        error_log(a.label .. ' answered "' .. said .. '" instead of the usual "got it" line - task NOT recorded.')
    elseif not seen then
        error_log(a.label .. ': no answer after choosing ' .. task_text(a, node, task) .. ' - task NOT recorded.')
    end
    -- 4) close the line; black screen; they reappear on the new node.
    -- No answer = a menu may still be open: back out with Escape (never
    -- Enter, which would pick the highlighted option).
    if seen then
        coroutine.sleep(line_settle)
        gh.press_key('enter', 0.5)
    else
        for _ = 1, 3 do gh.press_key('escape', 0.6) end
    end
    local now_on = wait_for_move(a, from_node, node)
    windower.send_command('target clear')

    local stamp = os.date('%Y-%m-%d %H:%M:%S')
    if confirmed and now_on == node then
        sset(a, 'node', node)
        sset(a, 'task', task)
        sset(a, 'set_at', stamp)
        log(a.label .. ': now on ' .. node .. ' - ' .. task_text(a, node, task) .. '.')
        return true
    end
    if confirmed then
        error_log(a.label .. ': the game took the order but ' .. a.label .. ' is ' .. (now_on and ('on ' .. now_on) or 'not found') ..
            ' afterwards (wanted ' .. node .. ') - task NOT recorded, will try again next time.')
    end
    sset(a, 'node', now_on or '')
    sset(a, 'task', '')
    back_out()
    return false
end

-- Checks one assistant against its setting (want_node / want_task) and
-- changes it when needed. force = talk to it even if the data matches.
local function check_one(a, want_node, want_task, force)
    local live = live_node(a)
    sset(a, 'checked_at', os.date('%Y-%m-%d %H:%M:%S'))
    local saved_node, saved_task = sget(a, 'node'), sget(a, 'task')
    if not live then
        log(a.label .. ': not in this Mog Garden (not unlocked yet?) - skipping; looked for again next time.')
        sset(a, 'node', 'missing')
        sset(a, 'task', '')
        return false
    end
    if saved_node ~= live then
        if saved_node == 'missing' then
            log(a.label .. ': is in the garden now (on ' .. live .. ').')
        elseif saved_node ~= '' then
            log(a.label .. ': found on ' .. live .. ' but the data said ' .. saved_node .. ' (changed by hand?) - its task there is unknown.')
        end
        sset(a, 'node', live)
        sset(a, 'task', '')
        saved_task = ''
    end
    if not force and live == want_node and saved_task == want_task then
        log(a.label .. ': already on ' .. want_node .. ' - ' .. task_text(a, want_node, want_task) .. ' - no change needed.')
        return true
    end
    local why
    if force then
        why = 'force'
    elseif live ~= want_node then
        why = 'on ' .. live .. ', setting says ' .. want_node
    elseif saved_task == '' then
        why = 'on ' .. live .. ', task not known yet'
    else
        why = 'task is ' .. task_text(a, live, saved_task) .. ', setting says ' .. task_text(a, want_node, want_task)
    end
    log(a.label .. ': ' .. why .. ' - setting ' .. want_node .. ' / ' .. task_text(a, want_node, want_task) .. '...')
    return assign(a, live, want_node, want_task)
end

local M = {}

-- Nodes already checked during the current command (state.assist_checked).
local function checked_set()
    if type(state.assist_checked) ~= 'table' then state.assist_checked = {} end
    return state.assist_checked
end

-- Start of a command (or of each furrowloop cycle): every node may be
-- checked again.
function M.begin_run()
    state.assist_checked = {}
end

-- Checks list (assistant tables) against characters.lua and changes the
-- ones that differ. force = set them again even if the data matches.
-- quiet_off = no line for assistants turned off on this character.
local function check_list(list, force, quiet_off)
    for _, a in ipairs(list) do
        if not state.running then break end
        local n, t = configured(a)
        if n then
            check_one(a, n, t, force)
        elseif t == 'off' then
            if not quiet_off then
                log(a.label .. ': not managed on this character (characters.lua) - left alone.')
            end
        else
            warn_config(a, t)
        end
    end
    gh.save_status()
end

-- Start of a full garden run: every assistant, whatever node it is set to.
function M.check_all(force)
    local done = checked_set()
    for node in pairs(NODE_LABELS) do done[node] = true end
    local any = false
    for _, a in ipairs(ASSISTANTS) do
        local n, t = configured(a)
        if n or t ~= 'off' then any = true end
    end
    if not any or not state.running then return end
    log('Preparing the garden run, checking on assistant settings...')
    check_list(ASSISTANTS, force, true)
end

-- Before harvesting node (furrow/vein/pond/grove/net): checks the
-- assistants characters.lua puts on that node (nothing when none, or
-- when this command already checked it).
function M.before_harvest(node)
    local done = checked_set()
    if done[node] then return end
    done[node] = true
    local list = {}
    for _, a in ipairs(ASSISTANTS) do
        if a.nodes[node] then
            local n, t = configured(a)
            if n == node then
                table.insert(list, {a = a, node = n, task = t})
            elseif n == nil and t ~= 'off' then
                warn_config(a, t)
            end
        end
    end
    if #list == 0 or not state.running then
        return
    end
    log('Preparing to harvest ' .. (NODE_LABELS[node] or node) .. ', checking on assistant settings...')
    for _, item in ipairs(list) do
        if not state.running then break end
        check_one(item.a, item.node, item.task, false)
    end
    gh.save_status()
end

-- Assistants named in args[from] (nil = all), or nil + error.
local function pick(args, from)
    local name = args[from] and args[from]:lower()
    if not name or name == '' or name == 'all' then
        return ASSISTANTS
    end
    local a = BY_KEY[name]
    if not a then
        return nil, 'Unknown assistant "' .. args[from] .. '" - kuyin, susuroon or yeestog.'
    end
    return {a}
end

-- //gh status rows: {label, value} per assistant.
function M.status_rows()
    local rows = {}
    for _, a in ipairs(ASSISTANTS) do
        local node, task = sget(a, 'node'), sget(a, 'task')
        local now
        if node == '' then
            now = 'unknown (not checked yet)'
        elseif node == 'missing' then
            now = 'not in this garden'
        else
            now = node .. ' / ' .. ((task ~= '') and task_text(a, node, task) or 'task unknown')
        end
        local want_node, want_task = configured(a)
        local extra = ''
        if want_node == nil and want_task == 'off' then
            extra = ' (not managed on this character)'
        elseif want_node == nil then
            extra = ' (characters.lua ERROR: ' .. want_task .. ')'
        elseif node ~= 'missing' and (want_node ~= node or want_task ~= task) then
            extra = ' -> setting: ' .. want_node .. ' / ' .. task_text(a, want_node, want_task) .. ' (at the next ' .. want_node .. ' harvest)'
        end
        table.insert(rows, {label = a.name, value = now .. extra})
    end
    return rows
end

-- //gh assistants list: every node / task each assistant can take.
local function show_list()
    log('Garden assistants - node / task names for characters.lua (assistants = {...}):')
    for _, a in ipairs(ASSISTANTS) do
        for _, nk in ipairs(by_menu(a.nodes)) do
            local parts = {}
            for _, tk in ipairs(by_menu(a.nodes[nk].tasks)) do
                table.insert(parts, tk .. ' = "' .. a.nodes[nk].tasks[tk].text .. '"')
            end
            log('  ' .. a.key .. ': node = \'' .. nk .. '\'  task: ' .. table.concat(parts, ', '))
        end
    end
end

-- //gh assistants [force|status|list|done|reset|help] [kuyin|susuroon|yeestog|all]
-- Returns true when it needs the garden (the walk-and-talk check).
function M.command(args)
    local sub = args[2] and args[2]:lower() or ''
    if sub == 'help' then
        log('//gh assistants [name] - check every assistant (or one) against characters.lua and change the ones that differ')
        log('//gh assistants force [name] - talk to them and set them again even if the data matches')
        log('//gh assistants status - saved node/task per assistant;  list - every node/task name they take')
        log('//gh assistants done [name] - record them as already set the way characters.lua says (you set them by hand)')
        log('//gh assistants reset [name] - forget the saved task (set again at the next check)')
        return
    end
    if sub == 'status' then
        for _, row in ipairs(M.status_rows()) do
            log('  ' .. row.label .. ': ' .. row.value)
        end
        return
    end
    if sub == 'list' then
        show_list()
        return
    end
    if sub == 'done' or sub == 'reset' then
        local list, err = pick(args, 3)
        if not list then error_log(err) return end
        for _, a in ipairs(list) do
            if sub == 'reset' then
                sset(a, 'node', '')
                sset(a, 'task', '')
                log(a.label .. ': saved node/task cleared - set again at the next check.')
            else
                local n, t = configured(a)
                if n then
                    sset(a, 'node', n)
                    sset(a, 'task', t)
                    sset(a, 'set_at', os.date('%Y-%m-%d %H:%M:%S'))
                    log(a.label .. ': recorded as on ' .. n .. ' - ' .. task_text(a, n, t) .. '.')
                else
                    log(a.label .. ': ' .. (t == 'off' and 'not managed on this character' or ('characters.lua ERROR: ' .. t)) .. ' - nothing recorded.')
                end
            end
        end
        gh.persist_status()
        return
    end

    local force = (sub == 'force')
    local list, err = pick(args, force and 3 or 2)
    if not list then error_log(err) return end
    log('Checking the garden assistants' .. (force and ' (force - setting every one again)' or '') .. '...')
    check_list(list, force, false)
    if state.running then
        log('Assistant check complete.')
    end
end

-- True when the assistant (kuyin/susuroon/yeestog) is in this garden
-- (recruited) - employment.lua.
function M.present(key)
    local a = BY_KEY[tostring(key or ''):lower()]
    return a ~= nil and live_node(a) ~= nil
end

M.KEYS = {}
for _, a in ipairs(ASSISTANTS) do table.insert(M.KEYS, a.key) end

return M
end

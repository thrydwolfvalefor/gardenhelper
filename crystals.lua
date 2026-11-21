-- =====================================================================
-- crystals.lua - GardenHelper module: Ephemeral Moogle crystal trading
-- (//gh crystals, and the crystals step of //gh full); v2.29.0 also the
-- moogle's stock (eph_crystals) and withdrawals (//gh ephstock,
-- //gh ephwithdraw, //gh ephcapture - MuleLogger //ml eph / Tier 12).
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
-- Returns {harvest = function(force, mode), eph = EPH}.
-- =====================================================================
return function(gh)

local config, state, saved_status = gh.config, gh.state, gh.saved_status
local log, debug_log, error_log = gh.log, gh.debug_log, gh.error_log
local EPHEMERAL_MOOGLE = gh.EPHEMERAL_MOOGLE
local clear_cursor_state, ensure_in_interact_range, find_entity = gh.clear_cursor_state, gh.ensure_in_interact_range, gh.find_entity
local position_at_node, press_key, lines_contain = gh.position_at_node, gh.press_key, gh.lines_contain
local print_captured_lines, strip_timestamp_prefix = gh.print_captured_lines, gh.strip_timestamp_prefix
local save_status, set_module_done = gh.save_status, gh.set_module_done

-- Crystals 4096-4103 and clusters 4104-4111.
local CRYSTAL_ITEM_IDS = {}
for id = 4096, 4111 do
    CRYSTAL_ITEM_IDS[id] = true
end

-- Tradeable crystal/cluster stacks in main inventory: {slot, id, count}
-- (status 0 = not equipped/bazaared/in a trade).
local function crystal_stacks()
    local stacks = {}
    local inventory = windower.ffxi.get_items(0)
    if not inventory then
        return stacks
    end
    for index, item in ipairs(inventory) do
        if item and item.id and CRYSTAL_ITEM_IDS[item.id] and (item.count or 0) > 0 and item.status == 0 then
            table.insert(stacks, {slot = index, id = item.id, count = item.count})
        end
    end
    return stacks
end

-- Highest total held of any single crystal/cluster type.
local function max_crystal_count()
    local totals = {}
    local best = 0
    for _, st in ipairs(crystal_stacks()) do
        totals[st.id] = (totals[st.id] or 0) + st.count
        if totals[st.id] > best then best = totals[st.id] end
    end
    return best
end

-- Trades up to 8 stacks to an NPC with the outgoing 0x036 packet (as
-- TradeNPC by Ivaar builds it). The NPC must be within 6 yalms.
local function trade_items_to_npc(npc, stacks)
    local ind, qty = {}, {}
    for i = 1, math.min(#stacks, 8) do
        ind[i] = stacks[i].slot
        qty[i] = stacks[i].count
    end
    local num = #ind
    if num == 0 then return false end
    for x = num + 1, 9 do
        ind[x] = 0
        qty[x] = 0
    end
    local packet = ('C4I11C10HI'):pack(0x36, 0x20, 0x00, 0x00, npc.id,
        qty[1], qty[2], qty[3], qty[4], qty[5], qty[6], qty[7], qty[8], qty[9], 0x00,
        ind[1], ind[2], ind[3], ind[4], ind[5], ind[6], ind[7], ind[8], ind[9], 0x00,
        npc.index, num)
    windower.packets.inject_outgoing(0x36, packet)
    return true
end

local function set_crystals_missing(missing)
    if saved_status.crystals_missing ~= missing then
        saved_status.crystals_missing = missing
        save_status()
    end
end

-- Trades crystals/clusters to the Ephemeral Moogle, up to 8 stacks per
-- trade, until none are left or a trade doesn't go through. mode 'all'
-- (//gh crystals) always trades; 'full' (//gh full) only when holding
-- AT LEAST crystals_full_threshold of one type (v2.27.1). Each trade: "hold onto
-- these, kupo?" (Enter), "That's all there is to it" (Enter), "You have
-- stored N ..." - each waited for. Returns false (never a reason to sell).
local function harvest_crystals(force, mode)
    mode = mode or 'all'
    if not config.process_crystals then
        debug_log('Crystals: config.process_crystals is false - skipping.')
        return false
    end

    -- Refresh the missing flag on every pass, even with nothing to trade.
    if not windower.ffxi.get_mob_by_id(EPHEMERAL_MOOGLE.id) then
        log('Crystals: Ephemeral Moogle Missing - not found in this garden, skipping.')
        set_crystals_missing(true)
        return false
    end

    local stacks = crystal_stacks()
    if #stacks == 0 then
        log('Crystals: none in inventory - nothing to trade.')
        return false
    end
    if mode == 'full' then
        local most = max_crystal_count()
        if most < config.crystals_full_threshold then
            log('Crystals: holding at most ' .. most .. ' of any one crystal/cluster (trades at ' .. config.crystals_full_threshold .. ' or more) - skipping.')
            return false
        end
    end

    clear_cursor_state()

    -- Loaded but not targetable = not unlocked.
    if not find_entity(EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name) then
        if not state.running then return false end
        log('Crystals: Ephemeral Moogle Missing - could not be targeted in this garden, skipping.')
        set_crystals_missing(true)
        return false
    end
    set_crystals_missing(false)

    if not position_at_node(EPHEMERAL_MOOGLE.key, EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name, EPHEMERAL_MOOGLE.name, 'crystals') then
        error_log('Crystals: could not reach/target the Ephemeral Moogle.')
        return false
    end

    local traded_any = false
    for round = 1, config.crystal_trade_max_rounds do
        if not state.running then break end
        stacks = crystal_stacks()
        if #stacks == 0 then break end

        local before = 0
        for _, st in ipairs(stacks) do before = before + st.count end

        local npc = windower.ffxi.get_mob_by_id(EPHEMERAL_MOOGLE.id)
        if not npc or not npc.distance or math.sqrt(npc.distance) >= 6 then
            if not ensure_in_interact_range(EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name, nil) then
                error_log('Crystals: the Ephemeral Moogle is out of trade range - stopping.')
                break
            end
            npc = windower.ffxi.get_mob_by_id(EPHEMERAL_MOOGLE.id)
        end

        local batch = {}
        for i = 1, math.min(#stacks, 8) do batch[i] = stacks[i] end
        log('Crystals: trade ' .. round .. ' - handing over ' .. #batch .. ' stack(s)...')

        state.captured_lines = {}
        state.capturing_text = true
        -- "Target out of range." = walk closer and trade again.
        gh.range_retry(EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name, function()
            local n = windower.ffxi.get_mob_by_id(EPHEMERAL_MOOGLE.id) or npc
            local range_count = gh.out_of_range_count()
            trade_items_to_npc(n, batch)

            local confirmed, finished, stored = false, false, false
            local waited = 0
            while state.running and waited < (config.crystal_trade_wait_seconds * 3) and not stored do
                if gh.out_of_range_count() ~= range_count then break end
                coroutine.sleep(0.2)
                waited = waited + 0.2
                if not confirmed and lines_contain(state.captured_lines, config.crystal_trade_confirm_phrase) then
                    confirmed = true
                    coroutine.sleep(0.5)
                    press_key('enter', 0.5)
                end
                if not finished and lines_contain(state.captured_lines, config.crystal_trade_done_phrase) then
                    finished = true
                    coroutine.sleep(0.5)
                    press_key('enter', 0.5)
                end
                if lines_contain(state.captured_lines, config.crystal_trade_stored_phrase) then
                    stored = true
                end
                if not confirmed and not finished and waited >= config.crystal_trade_wait_seconds then
                    break
                end
            end
            return confirmed, finished, stored
        end)
        -- Give any remaining "You have stored ..." lines a moment.
        coroutine.sleep(1.0)
        state.capturing_text = false

        local after = 0
        for _, st in ipairs(crystal_stacks()) do after = after + st.count end

        if after < before then
            traded_any = true
            for _, line in ipairs(state.captured_lines) do
                if line:find(config.crystal_trade_stored_phrase, 1, true) then
                    debug_log('  ' .. strip_timestamp_prefix(line))
                end
            end
        else
            error_log('Crystals: the trade did not go through (no crystals left inventory - storage may be full for that element, or the moogle refused). Stopping crystal trading.')
            if #state.captured_lines > 0 then
                print_captured_lines(debug_log, '  ', state.captured_lines)
            end
            clear_cursor_state()
            break
        end
        coroutine.sleep(1.0)
    end

    windower.send_command('target clear')
    if traded_any then
        set_module_done('crystals', true)
        log(EPHEMERAL_MOOGLE.name .. ': crystal trading complete' .. ((#crystal_stacks() > 0) and ' (some crystals were left over - see above)' or '') .. '.')
    end
    -- v2.29.0: the moogle's stock changed - read it again (MuleLogger Tier 12).
    if traded_any and state.eph then
        coroutine.sleep(1)
        state.eph.request(true)
    end
    -- Crystals free up inventory - never a reason to sell.
    return false
end

-- =====================================================================
-- v2.29.0 (Mark): Ephemeral Moogle STOCK and WITHDRAWALS, for
-- MuleLogger's //ml eph and //ml smart Tier 12, which move full cluster
-- stacks from the non-crafting mules to the crafters.
--
-- Stock: incoming 0x113 (the currency menu packet), 8 ushorts from 0xE8
-- in element order Fire, Ice, Wind, Earth, Lightning, Water, Light, Dark
-- (the same offsets the craft addon reads). The game sends it when asked
-- with outgoing 0x10F. Saved per character when it changes:
-- eph_crystals = "fire,ice,wind,earth,lightning,water,light,dark" and
-- eph_crystals_at in data/settings.xml (MuleLogger reads them).
-- Asked for at the same moments as Storage / Kitron Macarons (login,
-- zone, load, //gh status), after every crystal trade and withdrawal.
--
-- Withdraw: walk to the moogle and talk (Enter); its menu packet
-- (incoming 0x034 / 0x032) is held back from the client, then the talk
-- is ended with outgoing 0x05B, option = (0x4000 + element 1-8) * 65536
-- + crystals. The moogle gives one cluster per 12 crystals, so 144 = one
-- full stack of 12 clusters.
-- v2.29.1: retail capture (Mark, 2026-10-26, Fishvf, 144 Earth by hand -
-- data/ephemeral_packets.log): menu 1092, the client's 0x05B option is
-- 0x40040090 = flag 0x4000 + element 4 in the high word, 144 in the low
-- word (v2.29.0 sent 0x00040090 without the flag - the server ignored it).
-- The 0x034 menu parameters hold the stock too (8 ushorts from offset 8,
-- same element order: 95,112,140,161,... = "How many? (161 stored)").
-- =====================================================================
local EPH = {
    NAMES = {'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark'},
    CRYSTAL_ID = 4096,   -- + element - 1
    CLUSTER_ID = 4104,   -- + element - 1
    STACK = 144,         -- crystals in one full stack of clusters (12 x 12)
    stock = nil, stock_at = 0, seq = 0, last_req = 0,
    sess = nil, capture = false,
    CAPTURE_FILE = windower.addon_path .. 'data/ephemeral_packets.log',
}

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

-- Element number 1-8 from "3", "wind", "Wind Cluster", "lightning" / "thunder" / "ltng".
function EPH.element(text)
    local t = tostring(text or ''):lower():gsub('%s+cluster$', ''):gsub('%s+crystal$', '')
    local n = tonumber(t)
    if n and n >= 1 and n <= 8 and n == math.floor(n) then return n end
    if t == 'thunder' or t == 'ltng' or t == 'lightng.' then return 5 end
    for i, name in ipairs(EPH.NAMES) do
        if name:lower() == t then return i end
    end
    return nil
end

-- Saved stock {8 numbers} for the logged-in character, or nil.
function EPH.saved()
    local out = {}
    for v in tostring(saved_status.eph_crystals or ''):gmatch('[^,]+') do
        table.insert(out, tonumber(v) or 0)
    end
    return (#out == 8) and out or nil
end

-- "Fire 1234, Ice 0, ..." (only_nonzero = leave the 0s out).
function EPH.text(stock, only_nonzero)
    if not stock then return 'unknown' end
    local parts = {}
    for i, name in ipairs(EPH.NAMES) do
        if not only_nonzero or (stock[i] or 0) > 0 then
            table.insert(parts, name .. ' ' .. (stock[i] or 0))
        end
    end
    return #parts > 0 and table.concat(parts, ', ') or 'none'
end

-- //gh status row.
function EPH.status_text()
    local stock = EPH.saved()
    if not stock then return 'stock not read yet' end
    local at = tostring(saved_status.eph_crystals_at or '')
    return EPH.text(stock, true) .. (at ~= '' and (' (read ' .. at .. ')') or '')
end

-- Ask the game for the currency packet (0x113). At most once per 5s
-- unless force.
function EPH.request(force)
    local info = windower.ffxi.get_info()
    if not (info and info.logged_in) then return false end
    if not force and os.time() - EPH.last_req < 5 then return false end
    EPH.last_req = os.time()
    local ok = pcall(function()
        local packets = require('packets')
        packets.inject(packets.new('outgoing', 0x10F, {}))
    end)
    return ok
end

function EPH.on_113(data)
    if #data < 0xE8 + 16 then return end
    local stock = {}
    for i = 1, 8 do
        stock[i] = u16(data, 0xE8 + (i - 1) * 2 + 1)
    end
    EPH.stock, EPH.stock_at = stock, os.time()
    EPH.seq = EPH.seq + 1
    local p = windower.ffxi.get_player()
    if not (p and p.name) then return end
    local text = table.concat(stock, ',')
    if tostring(saved_status.eph_crystals or '') ~= text then
        saved_status.eph_crystals = text
        saved_status.eph_crystals_at = os.date('%Y-%m-%d %H:%M:%S')
        pcall(gh.persist_status)
        debug_log('Ephemeral Moogle stock: ' .. EPH.text(stock, true) .. ' - saved.')
    end
end

-- v2.29.1: the moogle's menu (0x034) parameters = the same 8 ushorts
-- (Fire, Ice, Wind, Earth, Lightning, Water, Light, Dark) from offset 8.
function EPH.on_034_stock(data)
    if #data < 8 + 16 then return end
    local fake = string.rep(string.char(0), 0xE8)
    EPH.on_113(fake .. data:sub(8 + 1, 8 + 16))
end

-- Fresh stock (asks and waits for the answer), or nil after timeout.
function EPH.fresh_stock(timeout)
    local seq = EPH.seq
    EPH.request(true)
    local waited = 0
    while EPH.seq == seq and waited < (timeout or 5) do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    return (EPH.seq ~= seq) and EPH.stock or nil
end

local function main_count(id)
    local n = 0
    for _, it in ipairs(windower.ffxi.get_items(0) or {}) do
        if type(it) == 'table' and it.id == id then n = n + (tonumber(it.count) or 0) end
    end
    return n
end

local function main_free_slots()
    local bag = windower.ffxi.get_items(0)
    if type(bag) ~= 'table' then return 0 end
    local max, used = tonumber(bag.max) or 0, 0
    for i = 1, max do
        local it = bag[i]
        if type(it) == 'table' and it.id and it.id ~= 0 then used = used + 1 end
    end
    return math.max(max - used, 0)
end

-- ---- //gh ephcapture on|off: log the moogle's packets ----
local CAPTURE_OUT = {[0x01A] = true, [0x05B] = true, [0x10F] = true}
local CAPTURE_IN = {[0x032] = true, [0x034] = true, [0x05C] = true, [0x052] = true, [0x113] = true}
local function hex(data)
    return (data:gsub('.', function(c) return string.format('%02X ', c:byte()) end))
end
function EPH.capture_write(dir, id, data)
    local line = os.date('%Y-%m-%d %H:%M:%S') .. string.format('  %s 0x%03X  ', dir, id)
    local ok, packets = pcall(require, 'packets')
    if ok and packets and id ~= 0x113 then
        local ok2, p = pcall(packets.parse, dir, data)
        if ok2 and type(p) == 'table' then
            local parts = {}
            for k, v in pairs(p) do
                if type(k) == 'string' and k:sub(1, 1) ~= '_' then
                    if type(v) == 'string' then v = hex(v) end
                    table.insert(parts, k .. '=' .. tostring(v))
                end
            end
            table.sort(parts)
            line = line .. table.concat(parts, ', ')
        end
    elseif id == 0x113 then
        local s = {}
        for i = 1, 8 do s[i] = u16(data, 0xE8 + (i - 1) * 2 + 1) end
        line = line .. 'moogle stock ' .. table.concat(s, ',')
    end
    if id ~= 0x113 then line = line .. '\n    raw: ' .. hex(data) end
    local f = io.open(EPH.CAPTURE_FILE, 'a')
    if f then f:write(line .. '\n') f:close() end
    if dir == 'outgoing' then log('[ephcapture] ' .. line:gsub('\n.*', ''), 207) end
end

windower.register_event('outgoing chunk', function(id, data)
    if EPH.capture and CAPTURE_OUT[id] then pcall(EPH.capture_write, 'outgoing', id, data) end
end)
windower.register_event('incoming chunk', function(id, data)
    if EPH.capture and CAPTURE_IN[id] then pcall(EPH.capture_write, 'incoming', id, data) end
    if id == 0x113 then pcall(EPH.on_113, data) end
    local s = EPH.sess
    if s and s.waiting and (id == 0x034 or id == 0x032) and u32(data, 5) == EPHEMERAL_MOOGLE.id then
        if id == 0x034 then
            s.npc_index, s.zone, s.menu = u16(data, 0x28 + 1), u16(data, 0x2A + 1), u16(data, 0x2C + 1)
            s.params = {u32(data, 9), u32(data, 13), u32(data, 17), u32(data, 21)}
            pcall(EPH.on_034_stock, data)
        else
            s.npc_index, s.zone, s.menu = u16(data, 0x08 + 1), u16(data, 0x0A + 1), u16(data, 0x0C + 1)
        end
        s.waiting, s.got = false, true
        return true   -- held back: the client never opens the menu
    end
    -- v2.29.1: a talk to the moogle by hand (or the trade menu) also
    -- carries the stock; read it again once that talk is over (0x052),
    -- so a withdrawal done by hand is saved too.
    if id == 0x034 and u32(data, 5) == EPHEMERAL_MOOGLE.id then
        pcall(EPH.on_034_stock, data)
        EPH.talk_open = true
    elseif id == 0x052 and EPH.talk_open and not EPH.sess then
        EPH.talk_open = false
        coroutine.schedule(function() EPH.request(true) end, 2)
    end
end)

-- Client still shows "in an event" after the moogle answered: release it
-- the way the game does (incoming 0x052), as //gh emp unstick does.
local function release_client()
    windower.packets.inject_incoming(0x052, string.char(0x52, 0x04, 0, 0, 0, 0, 0, 0))
    coroutine.sleep(0.5)
    windower.packets.inject_incoming(0x052, string.char(0x52, 0x04, 0, 0, 1, 0, 0, 0))
    coroutine.sleep(0.5)
end

-- Withdraws `stacks` full stacks of element elem's clusters (144 crystals
-- each). Fewer when the stock or main inventory's free slots don't allow
-- that many (at least one or it fails). Returns got (clusters that
-- arrived), asked (stacks asked for), why (on failure).
function EPH.withdraw(elem, stacks)
    local cname = EPH.NAMES[elem] .. ' Cluster'
    local cid = EPH.CLUSTER_ID + elem - 1
    if not windower.ffxi.get_mob_by_id(EPHEMERAL_MOOGLE.id) then
        return 0, 0, 'the Ephemeral Moogle is not in this garden'
    end
    local free = main_free_slots()
    if free <= 0 then return 0, 0, 'main inventory is full' end
    local stock = EPH.fresh_stock(5)
    if not stock then
        return 0, 0, 'the game did not send the moogle\'s stock (no 0x113 answer)'
    end
    local can = math.floor((stock[elem] or 0) / EPH.STACK)
    if can <= 0 then
        return 0, 0, 'only ' .. (stock[elem] or 0) .. ' ' .. EPH.NAMES[elem] .. ' crystals stored (a stack needs ' .. EPH.STACK .. ')'
    end
    local want = math.min(stacks, can, free)
    if want < stacks then
        log('Ephemeral Moogle: asked for ' .. stacks .. ' stack(s) of ' .. cname .. ' - taking ' .. want
            .. ' (' .. (stock[elem] or 0) .. ' stored, ' .. free .. ' free inventory slot(s)).')
    end

    clear_cursor_state()
    if not find_entity(EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name) then
        return 0, want, 'the Ephemeral Moogle could not be targeted'
    end
    if not position_at_node(EPHEMERAL_MOOGLE.key, EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name, EPHEMERAL_MOOGLE.name, 'crystals') then
        return 0, want, 'could not reach/target the Ephemeral Moogle'
    end

    local before = main_count(cid)
    local s = {waiting = true}
    EPH.sess = s
    gh.range_retry(EPHEMERAL_MOOGLE.id, EPHEMERAL_MOOGLE.name, function()
        local range_count = gh.out_of_range_count()
        s.waiting = true
        press_key('enter', 0.2)
        local waited = 0
        while state.running and not s.got and waited < 5 do
            if gh.out_of_range_count() ~= range_count then break end
            coroutine.sleep(0.2)
            waited = waited + 0.2
        end
        return s.got
    end)
    s.waiting = false
    if not s.got then
        EPH.sess = nil
        coroutine.sleep(0.5)
        local p = windower.ffxi.get_player()
        if p and p.status == 4 then press_key('escape', 0.8) end
        windower.send_command('target clear')
        return 0, want, 'the moogle did not answer the talk within 5s'
    end
    if s.params then
        debug_log(string.format('Ephemeral Moogle menu %d (index %d, zone %d), params %08X %08X %08X %08X', s.menu, s.npc_index, s.zone,
            s.params[1], s.params[2], s.params[3], s.params[4]))
    end

    local option = (0x4000 + elem) * 65536 + want * EPH.STACK   -- v2.29.1: 0x4000 flag (retail capture)
    local pkt = string.char(0x5B, 0x0A, 0, 0) .. le32(EPHEMERAL_MOOGLE.id) .. le32(option) ..
        le16(s.npc_index) .. le16(0) .. le16(s.zone) .. le16(s.menu)
    windower.packets.inject_outgoing(0x5B, pkt)
    log('Ephemeral Moogle: asked for ' .. (want * EPH.STACK) .. ' ' .. EPH.NAMES[elem] .. ' crystals (' .. want .. ' stack(s) of ' .. cname .. ')...')

    local target, waited = before + want * 12, 0
    while main_count(cid) < target and waited < 10 do
        coroutine.sleep(0.25)
        waited = waited + 0.25
    end
    coroutine.sleep(0.5)
    EPH.sess = nil
    local p = windower.ffxi.get_player()
    if p and p.status == 4 then release_client() end
    windower.send_command('target clear')
    EPH.fresh_stock(5)
    local got = math.max(main_count(cid) - before, 0)
    if got < want * 12 then
        return got, want, 'only ' .. got .. ' of ' .. (want * 12) .. ' ' .. cname .. ' arrived'
    end
    log('Ephemeral Moogle: got ' .. got .. ' ' .. cname .. ' (' .. EPH.NAMES[elem] .. ' left in storage: ' .. tostring(EPH.stock and EPH.stock[elem] or '?') .. ').')
    return got, want
end

state.eph = EPH   -- GardenHelper.lua's Storage reads ask for the stock too

return {harvest = harvest_crystals, eph = EPH}
end

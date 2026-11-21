-- =====================================================================
-- books.lua - GardenHelper module: the daily Mog Garden book check /
-- purchase at the Skipper Moogle (//gh books, and the books step of
-- //gh full). Loaded by GardenHelper.lua, which passes its shared
-- table (gh) in. Returns the BOOKS table (API at the bottom).
-- =====================================================================
return function(gh)

local config, state, saved_status = gh.config, gh.state, gh.saved_status
local log, debug_log, error_log = gh.log, gh.debug_log, gh.error_log
local ENTITIES, MOG_GARDEN_ZONE_ID = gh.ENTITIES, gh.MOG_GARDEN_ZONE_ID
local PORT_DINGHY_KEYS, PORT_SKIPPER_KEYS = gh.PORT_DINGHY_KEYS, gh.PORT_SKIPPER_KEYS
local alert, clear_cursor_state, current_target_is, current_zone = gh.alert, gh.clear_cursor_state, gh.current_target_is, gh.current_zone
local enter_garden_from_port, find_entity, get_garden_day_string = gh.enter_garden_from_port, gh.find_entity, gh.get_garden_day_string
local is_module_enabled, persist_status, position_at_node, press_key = gh.is_module_enabled, gh.persist_status, gh.position_at_node, gh.press_key
local retarget_entity, wait_for_zone_change, zone_name = gh.retarget_entity, gh.wait_for_zone_change, gh.zone_name

-- Books status helpers. result = 'checked' / 'purchased' / 'broke'.
local function record_books_result(result, purchased_titles)
    local now = os.time()
    saved_status.books_last_checked_date = get_garden_day_string(now)
    saved_status.books_last_checked_at = os.date('%Y-%m-%d %H:%M:%S', now)
    saved_status.books_last_checked_epoch = now
    saved_status.books_last_result = result
    saved_status.books_last_purchased = purchased_titles or ''
    saved_status.books_unknown = false
    saved_status.books_gave_up_date = ''
    persist_status()
end

local function books_done_today()
    return saved_status.books_unknown ~= true
        and saved_status.books_last_checked_date == get_garden_day_string()
        and (saved_status.books_last_result or '') ~= ''
end

-- Books due in the daily routine (//gh full, duecheck): on for this
-- character, books_in_full, not done today, not given up today.
local function books_gave_up_today()
    return (saved_status.books_gave_up_date or '') == get_garden_day_string()
end

local function books_due_for_routine()
    return config.books_in_full == true
        and is_module_enabled('books')
        and not books_done_today()
        and not books_gave_up_today()
end

-- A failed //gh full book trip; give up for today after books_daily_attempts.
local function note_books_attempt_failed()
    local today = get_garden_day_string()
    if (saved_status.books_attempt_date or '') ~= today then
        saved_status.books_attempt_date = today
        saved_status.books_attempt_count = 0
    end
    saved_status.books_attempt_count = (tonumber(saved_status.books_attempt_count) or 0) + 1
    local limit = tonumber(config.books_daily_attempts) or 2
    if saved_status.books_attempt_count >= limit then
        saved_status.books_gave_up_date = today
        error_log('Books: failed ' .. saved_status.books_attempt_count .. ' time(s) today - giving up until the next reset (//gh books to try by hand).')
    else
        log('Books: failed this time (' .. saved_status.books_attempt_count .. ' of ' .. limit .. ' tries today) - the next //gh full tries again.')
    end
    persist_status()
end

local function books_status_text()
    if saved_status.books_unknown == true and not books_gave_up_today() then
        return 'UNKNOWN'
    end
    if not books_done_today() then
        if books_gave_up_today() then
            return 'FAILED today (gave up after ' .. (tonumber(saved_status.books_attempt_count) or 0) .. ' tries)'
        end
        return 'not checked today'
    end
    local r = saved_status.books_last_result
    if r == 'purchased' then
        return 'Purchased today' .. ((saved_status.books_last_purchased ~= '') and (' (' .. saved_status.books_last_purchased .. ')') or '')
    elseif r == 'broke' then
        return "You're Broke!!!"
    end
    return 'checked today'
end

-- Key of the first phrase in phrase_map {key = phrase} found in the
-- captured lines after index since, within max_wait. Capture must be on.
local function wait_for_any_phrase_since(phrase_map, since, max_wait)
    local waited = 0
    while state.running and waited <= max_wait do
        for i = since + 1, #state.captured_lines do
            for key, phrase in pairs(phrase_map) do
                if state.captured_lines[i]:find(phrase, 1, true) then
                    return key, state.captured_lines[i]
                end
            end
        end
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    return nil
end

-- Port zone arrival for the book trip: poll for the Skipper Moogle and
-- go once the target holds port_confirm_rounds times in a row.
local function wait_for_port_skipper(skipper)
    local started = os.time()
    local deadline = started + config.port_arrival_max_seconds
    local rounds_ok = 0
    debug_log('Books: polling for the ' .. skipper.name .. '...')
    while state.running and os.time() < deadline do
        local mob = windower.ffxi.get_mob_by_id(skipper.id)
        if mob and mob.valid_target and find_entity(skipper.id, skipper.name) then
            coroutine.sleep(config.port_target_hold_seconds)
            if current_target_is(skipper.id, skipper.name) then
                rounds_ok = rounds_ok + 1
                debug_log('Books: ' .. skipper.name .. ' target held (' .. rounds_ok .. '/' .. config.port_confirm_rounds .. ')')
                if rounds_ok >= config.port_confirm_rounds then
                    local since = state.last_arrival_epoch and (os.time() - state.last_arrival_epoch) or nil
                    log('Books: ' .. skipper.name .. ' found and targeted - Port is loaded' .. (since and (' (' .. since .. 's after arrival)') or '') .. '.')
                    return true
                end
            else
                debug_log('Books: lost the target on the ' .. skipper.name .. ' - not settled yet, polling again...')
                rounds_ok = 0
            end
        else
            rounds_ok = 0
        end
        if not state.running then break end
        coroutine.sleep(config.port_poll_interval)
    end
    return false
end

-- Daily book check/purchase from the Skipper Moogle:
--   Garden: Mog Dinghy -> Enter, Down ("Whence I came."), Enter -> Port
--   (Mog House instead = can't buy, stop).
--   Port: Skipper -> Enter (wait "Heigh-ho") -> Enter -> Right (books)
--   -> Enter -> "can't sell them" = nothing, "tantalizing tomes" = buy:
--   Enter, Down, Enter (price), Enter, Enter (Yes) -> "Obtained key item"
--   (check stock again) or "not enough gil" (alert, stop).
--   Then back to the garden on the Port's Mog Dinghy.
-- Result per garden day: checked / purchased / broke. Needs state.running.
local function buy_books(force)
    if not is_module_enabled('books') then
        log('Books: disabled for this character (characters.lua) - skipping.')
        return false
    end
    if not force and books_done_today() then
        log('Books: already checked today (' .. books_status_text() .. ') - skipping. Use //gh books force to check again.')
        return false
    end

    clear_cursor_state()

    local zone, mog_house = current_zone()

    if zone == MOG_GARDEN_ZONE_ID then
        local dinghy = ENTITIES['GardenDinghy']
        if not dinghy or not position_at_node('GardenDinghy', dinghy.id, dinghy.name, 'Mog Dinghy') then
            error_log('Books: could not reach/target the Mog Garden\'s Mog Dinghy.')
            return false
        end
        log('Books: sailing back to the Port zone ("Whence I came.")...')
        state.expecting_zone = true
        local before = state.zone_change_count
        -- "Target out of range." = walk closer and try the Dinghy again.
        gh.range_retry(dinghy.id, dinghy.name, function()
            local range_count = gh.out_of_range_count()
            press_key('enter', config.menu_open_wait_seconds) -- "Set sail to where?"
            if gh.out_of_range_count() ~= range_count then return false end
            press_key('down')                                  -- "Whence I came."
            press_key('enter', 0.5)
            return true
        end)
        local new_zone = wait_for_zone_change(before, config.zone_change_wait_seconds)
        state.expecting_zone = false
        if not new_zone then
            error_log('Books: never zoned out of the Mog Garden - stopping.')
            clear_cursor_state()
            return false
        end
        zone, mog_house = current_zone()
        if not zone then zone = new_zone end
    end

    if mog_house then
        error_log('Books: "Whence I came" led to the Mog House, not a Port zone - the Skipper Moogle is only in Port San d\'Oria/Bastok/Windurst. Stopping here (log in via a Port zone next time).')
        alert('Books: landed in the Mog House instead of a Port zone.')
        return false
    end

    local skipper_key = PORT_SKIPPER_KEYS[zone]
    local skipper = skipper_key and ENTITIES[skipper_key]
    if not skipper then
        error_log('Books: in ' .. zone_name(zone) .. ', which has no Skipper Moogle listed in entities.lua - stopping.')
        if PORT_DINGHY_KEYS[zone] and state.running then enter_garden_from_port(zone) end
        return false
    end

    if not wait_for_port_skipper(skipper) then
        if not state.running then return false end
        error_log('Books: could not find/hold a target on the Skipper Moogle in ' .. zone_name(zone) .. ' within ' .. config.port_arrival_max_seconds .. 's - heading back to the Mog Garden.')
        if state.running then enter_garden_from_port(zone) end
        return false
    end
    if not position_at_node(skipper_key, skipper.id, skipper.name, 'Skipper Moogle') then
        error_log('Books: could not reach/target the Skipper Moogle - heading back to the Mog Garden.')
        if state.running then enter_garden_from_port(zone) end
        return false
    end

    log('Books: asking the Skipper Moogle what\'s in stock...')
    state.captured_lines = {}
    state.capturing_text = true

    local stock_phrases = {available = config.books_available_phrase, none = config.books_none_phrase}
    local outcome = nil
    local mark = 0
    local ask_attempts = tonumber(config.books_ask_attempts) or 2
    for attempt = 1, ask_attempts do
        if not state.running then break end
        if attempt > 1 then
            log('Books: no answer from the Skipper Moogle - closing the menu and asking again (' .. attempt .. ' of ' .. ask_attempts .. ')...')
            clear_cursor_state()
            coroutine.sleep(1.0)
            if not retarget_entity(skipper.id, skipper.name) then
                error_log('Books: could not retarget the Skipper Moogle for another try.')
                break
            end
        end
        -- "Target out of range." = walk closer and press Enter again.
        local got = gh.range_retry(skipper.id, skipper.name, function()
            local greet_mark = #state.captured_lines
            press_key('enter', 0.3)
            local phrases = {greet = config.skipper_greeting_phrase}
            for i, p in ipairs(config.out_of_range_phrases) do phrases['out_of_range' .. i] = p end
            local answer = wait_for_any_phrase_since(phrases, greet_mark, config.books_greeting_wait_seconds or config.books_reply_wait_seconds)
            return answer == 'greet' and answer or nil
        end)
        if got then
            mark = #state.captured_lines
            press_key('enter', config.menu_open_wait_seconds)  -- "What do you want to know?"
            press_key('right')                                   -- jump to the last option (books)
            press_key('enter', 0.3)
            outcome = wait_for_any_phrase_since(stock_phrases, mark, config.books_reply_wait_seconds)
            if outcome then break end
            debug_log('Books: greeting seen but no stock answer - retrying.')
        else
            debug_log('Books: no greeting within ' .. tostring(config.books_greeting_wait_seconds) .. 's - not pressing menu keys into nothing.')
        end
    end

    local purchased = {}
    local broke = false
    local failed = false
    local loops = 0

    while state.running and outcome == 'available' and loops < config.books_max_purchases do
        loops = loops + 1
        mark = #state.captured_lines
        press_key('enter', config.menu_open_wait_seconds)  -- "Which book will you buy?"
        press_key('down')                                    -- first book
        press_key('enter', 0.3)

        local _, price_line = wait_for_any_phrase_since({price = config.books_price_phrase}, mark, config.books_reply_wait_seconds)
        local title = price_line and price_line:match('"(.-)"') or 'unknown book'
        local price = price_line and price_line:match('sum of ([%d,]+) gil') or '?'
        log('Books: buying "' .. title .. '" for ' .. price .. ' gil...')

        mark = #state.captured_lines
        press_key('enter', config.menu_open_wait_seconds)  -- "Buy the book?"
        press_key('enter', 0.3)                              -- Yes

        local buy_result, buy_line = wait_for_any_phrase_since({ok = config.books_obtained_phrase, broke = config.books_no_gil_phrase}, mark, config.books_reply_wait_seconds)
        if buy_result == 'ok' then
            local got_title = buy_line:match('"(.-)"') or title
            table.insert(purchased, got_title)
            log('Books: bought "' .. got_title .. '".')
            mark = #state.captured_lines
            -- Enter continues, then check stock again (the next stock line can
            -- arrive with the purchase line, so look from just before it).
            local already = wait_for_any_phrase_since(stock_phrases, mark - 1, 1.0)
            if already then
                outcome = already
            else
                press_key('enter', 0.3)
                outcome = wait_for_any_phrase_since(stock_phrases, mark, config.books_reply_wait_seconds)
            end
        elseif buy_result == 'broke' then
            broke = true
            alert(windower.ffxi.get_player().name .. ' does not have enough gil for "' .. title .. '" (' .. price .. ' gil).')
            break
        else
            error_log('Books: no purchase confirmation or "not enough gil" message after buying "' .. title .. '" - stopping the book check.')
            failed = true
            break
        end
    end
    state.capturing_text = false

    if outcome == nil and not broke and not failed then
        error_log('Books: the Skipper Moogle never said whether books were in stock - marking books UNKNOWN.')
        failed = true
    end

    clear_cursor_state()
    windower.send_command('target clear')

    if failed then
        saved_status.books_unknown = true
        persist_status()
    elseif broke then
        record_books_result('broke', table.concat(purchased, ', '))
    elseif #purchased > 0 then
        record_books_result('purchased', table.concat(purchased, ', '))
    else
        record_books_result('checked', '')
    end
    log('Books: ' .. books_status_text() .. '.')

    if not state.running then return false end

    coroutine.sleep(1)
    if not state.running then return #purchased > 0 end
    enter_garden_from_port(zone)
    return #purchased > 0
end

-- //gh books done / reset (and //gh full done / reset).
local function set_done(done)
    if done then
        record_books_result('checked', '')
        log('Books: marked checked for today.')
        return
    end
    saved_status.books_last_checked_date = ''
    saved_status.books_last_result = ''
    saved_status.books_gave_up_date = ''
    saved_status.books_attempt_count = 0
    saved_status.books_unknown = true
    persist_status()
    log('Books: status reset to UNKNOWN for this character.')
end

return {
    done_today = books_done_today,        -- checked (or bought) today
    due = books_due_for_routine,          -- due in the daily routine (//gh full, duecheck)
    note_failed = note_books_attempt_failed,
    status_text = books_status_text,      -- for //gh status
    set_done = set_done,
    buy = buy_books,                      -- the trip itself; needs state.running
}
end

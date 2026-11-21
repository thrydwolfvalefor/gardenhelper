-- =====================================================================
-- memcheck.lua - GardenHelper module: memory check on all loaded addons
-- (//gh memory, and the last step of //gh full when turned on).
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
--
-- Runs Windower's own "//lua memory", catches its per-addon lines
-- (hidden from chat while caught), sorts them by memory used (most on
-- top), prints them and appends them to memory_report.lua in this folder.
-- The % on each line = this run vs. the addon's value in the OLDEST run
-- still in memory_report.lua (or the first run it shows up in, if it wasn't
-- loaded then). //gh memory reset starts the history over.
--
-- On/off for //gh full (v2.9.3): data/memory_check.lua
-- (return {enabled = true/false}) is the ONLY setting - written by
-- //gh memory on|off, created as off if missing. There is no config line
-- for it in GardenHelper.lua any more.
--
-- Garbage collection (v2.8.1): at the end of every //gh full (and before
-- a manual //gh memory) GardenHelper runs collectgarbage('collect') on its
-- OWN Lua state (config.gc_at_end_of_full, default true). The report gets a
-- "GC:" line per run (before -> after, freed) and a one-time marker line
-- above the first run that had it, so runs with and without it can be
-- compared. //gh memory gc = collect now and show what it freed.
--
-- Per character (v2.8.2): every run of a //gh full (one per character)
-- gets a "Per character:" line = average pol.exe growth (private and
-- virtual) per character since the last ">>>>>" marker line, and since
-- the oldest run. //gh memory mark <note> writes a marker (e.g. "unloaded
-- BattleMod"), so each test starts its own average.
--
-- Returns {run, command, in_full, help_lines}.
-- =====================================================================
return function(gh)

local config = gh.config
local log, error_log = gh.log, gh.error_log
local debug_log = gh.debug_log or function() end

local REPORT_FILE = windower.addon_path .. 'memory_report.lua'
local TOGGLE_FILE = windower.addon_path .. 'data/memory_check.lua'

local REPORT_HEADER = {
    '-- GardenHelper memory report (//gh memory) - one block per run, newest at the bottom.',
    '-- Addons sorted by memory used (most on top). Growth / Growth % = change vs. the same row in',
    '-- the oldest run in this file (an addon loaded later: the first run it appears in, shown as',
    '-- base). Total Lua = all addons added up. //gh memory reset clears the file.',
    '-- pol.exe = the whole game\'s private memory (addons + plugins + on-screen overlays + FFXI).',
    '-- If it grows while the addon rows stay flat, the leak is outside the addons.',
    '-- pol.exe is a 32-bit program (4 GB address space at most), so steady growth matters.',
    '-- pol.exe virtual = address space in use - the number a 32-bit program runs out of.',
    '-- GC: = GardenHelper\'s own collectgarbage(\'collect\') just before that run (before -> after).',
    '-- Per character: = average pol.exe growth per //gh full run (one per character) since the last',
    '-- ">>>>>" marker (//gh memory mark <note>), and since the oldest run. Needs 2+ runs to average.',
    '',
}


-- ---- On/off (saved) ----
local function read_toggle()
    local chunk = loadfile(TOGGLE_FILE)
    if not chunk then return nil end
    local ok, t = pcall(chunk)
    if ok and type(t) == 'table' and type(t.enabled) == 'boolean' then
        return t.enabled
    end
    return nil
end

-- memory_report.lua exists from the first load on (header only until a run).
-- An older report named memory.lua (v2.5-v2.7.1) is renamed to it once.
do
    local old_name = windower.addon_path .. 'memory.lua'
    local old = io.open(old_name, 'r')
    local first = old and old:read('*l')
    if old then old:close() end
    local cur = io.open(REPORT_FILE, 'r')
    if cur then cur:close() end
    if first and first:find('GardenHelper memory report', 1, true) and not cur then
        os.rename(old_name, REPORT_FILE)
    end
end
do
    local f = io.open(REPORT_FILE, 'r')
    if f then
        f:close()
    else
        f = io.open(REPORT_FILE, 'w')
        if f then
            f:write(table.concat(REPORT_HEADER, '\n') .. '\n')
            f:close()
        end
    end
end

-- data/memory_check.lua is the only on/off (v2.9.3). Missing = off;
-- the file is created (off) further down so it can be found and edited.
local saved_toggle = read_toggle()
config.memory_check_in_full = (saved_toggle == true)

local function write_toggle(on)
    local f = io.open(TOGGLE_FILE, 'w')
    if not f then
        error_log('Could not write data/memory_check.lua - the setting lasts until the next reload only.')
        return
    end
    f:write('-- Written by //gh memory on|off. true = memory check at the end of every //gh full.\n')
    f:write('return {enabled = ' .. tostring(on) .. '}\n')
    f:close()
end

if saved_toggle == nil then
    write_toggle(false)
end

-- ---- Catching //lua memory's lines ----
-- LuaCore prints "Addon memory usage:" then one line per addon:
-- "  <name>  Memory: 1234.56 KB    Stack: 3" (unit B / KB / MB / GB).
local UNIT_TO_KB = {[''] = 1 / 1024, K = 1, M = 1024, G = 1024 * 1024}

local function clean(text)
    -- Drop chat colour/format codes (0x1E xx, 0x1F xx) and line ends.
    return (text:gsub('[\30\31].', ''):gsub('[\r\n]', ''))
end


-- "lua memory" prints only to the Windower console, which addons can't
-- read. Two ways to get the numbers anyway:
-- 1) console.log (Windower's console log, when turned on): send
--    "lua memory" and read the lines it appends there.
-- 2) Probe: "lua invoke <addon> dofile memprobe.lua" for every addon
--    folder - memprobe.lua runs INSIDE that addon and sends its own
--    collectgarbage('count') (the same number the console shows) back as
--    "//gh memprobe <KB> <name>". Folders that aren't loaded just print
--    an error to the console. Used when console.log gives nothing.
local CONSOLE_LOG = windower.windower_path .. 'console.log'
local PROBE_FILE = windower.addon_path .. 'memprobe.lua'
local PROBE_TEXT = [[
-- Written by GardenHelper memcheck.lua (//gh memory). Run inside another addon with
-- "lua invoke <addon> dofile <this file>": sends that addon's Lua memory back to GardenHelper.
local name = type(_addon) == 'table' and _addon.name or '?'
windower.send_command('gh memprobe ' .. string.format('%.2f', collectgarbage('count')) .. ' ' .. tostring(name))
]]

local function file_size(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local size = f:seek('end')
    f:close()
    return size
end

local function parse_memory_line(line)
    local name, amount, unit = line:match('^.->%s+(.-)%s+Memory:%s*([%d%.]+)%s*(%a?)B')
    if not name then
        name, amount, unit = line:match('^%s*(.-)%s+Memory:%s*([%d%.]+)%s*(%a?)B')
    end
    if name and name ~= '' and tonumber(amount) then
        return {name = name, kb = tonumber(amount) * (UNIT_TO_KB[unit:upper()] or 1)}
    end
end

-- Waits until lines stop coming: up to first_wait for the first one,
-- then done after 1.5s with nothing new (max 12s). got() = count so far.
local function wait_for_lines(got, first_wait)
    local waited, quiet, count = 0, 0, 0
    while waited < 12 do
        coroutine.sleep(0.25)
        waited = waited + 0.25
        local n = got()
        if n > 0 then
            if n == count then
                quiet = quiet + 0.25
                if quiet >= 1.5 then break end
            else
                count, quiet = n, 0
            end
        elseif waited >= first_wait then
            break
        end
    end
end

local function from_console_log()
    local start = file_size(CONSOLE_LOG)
    if not start then return {} end
    windower.send_command('lua memory')
    local lines = {}
    local function got()
        local f = io.open(CONSOLE_LOG, 'rb')
        if not f then return #lines end
        f:seek('set', start)
        local text = f:read('*a') or ''
        f:close()
        local after = text:match('Addon memory usage:(.*)$')
        lines = {}
        if after then
            for line in after:gmatch('[^\r\n]+') do
                local e = parse_memory_line(line)
                if e then table.insert(lines, e) end
            end
        end
        return #lines
    end
    wait_for_lines(got, 4)
    return lines
end

local probe = nil   -- {by_name = {}, list = {}} while probing

local function from_probes()
    local f = io.open(PROBE_FILE, 'r')
    local current = f and f:read('*a')
    if f then f:close() end
    if current ~= PROBE_TEXT then
        f = io.open(PROBE_FILE, 'w')
        if not f then return {} end
        f:write(PROBE_TEXT)
        f:close()
    end
    probe = {by_name = {}, list = {}}
    local addons_dir = windower.windower_path .. 'addons/'
    local path = PROBE_FILE:gsub('\\', '/')
    for _, entry in ipairs(windower.get_dir(addons_dir) or {}) do
        if entry ~= 'libs' and not entry:find('%.') and windower.dir_exists(addons_dir .. entry) then
            windower.send_command('lua invoke "' .. entry .. '" dofile "' .. path .. '"')
        end
    end
    wait_for_lines(function() return #probe.list end, 6)
    local lines = probe.list
    probe = nil
    return lines
end

-- //gh memprobe <KB> <name> (sent by memprobe.lua inside each addon).
local function record_probe(args)
    if not probe then return end
    local kb = tonumber(args[2])
    local name = table.concat(args, ' ', 3)
    if kb and name ~= '' and not probe.by_name[name:lower()] then
        probe.by_name[name:lower()] = true
        table.insert(probe.list, {name = name, kb = kb})
    end
end

local LUA_MEMORY_WAYS = {'console.log', 'lua invoke probes'}

local function catch_lua_memory()
    local lines = from_console_log()
    if #lines > 0 then return lines, 'console.log' end
    lines = from_probes()
    return lines, 'probes'
end

-- ---- pol.exe (the whole game: plugins, overlays, the game itself) ----
-- Lua can't read process memory, so a small Windows Script Host file
-- (written next to this one) asks Windows (WMI) and writes the answer to
-- data/pol_memory.txt. It is started with windower.open_url (Windows
-- "open", runs in wscript.exe - no console window). Its parent process is
-- this game's pol.exe, which is how it picks the right one when several
-- games are open. Lines: "<pid> <private bytes> <working set> <virtual> self|other".
local POL_SCRIPT = windower.addon_path .. 'memcheck_pol.vbs'
local POL_RESULT = windower.addon_path .. 'data/pol_memory.txt'
local POL_SCRIPT_TEXT = [[
' Written by GardenHelper memcheck.lua (//gh memory): writes pol.exe memory to data\pol_memory.txt.
On Error Resume Next
Dim fso, dir, wmi, p, f, parentPid, line
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName) & "\data\"
parentPid = -1
Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
For Each p In wmi.ExecQuery("SELECT ParentProcessId, CommandLine FROM Win32_Process WHERE Name = 'wscript.exe'")
  If Not IsNull(p.CommandLine) Then
    If InStr(1, p.CommandLine, WScript.ScriptName, 1) > 0 Then parentPid = p.ParentProcessId
  End If
Next
Set f = fso.CreateTextFile(dir & "pol_memory.tmp", True)
For Each p In wmi.ExecQuery("SELECT ProcessId, PrivatePageCount, WorkingSetSize, VirtualSize FROM Win32_Process WHERE Name = 'pol.exe'")
  line = p.ProcessId & " " & p.PrivatePageCount & " " & p.WorkingSetSize & " " & p.VirtualSize
  If p.ProcessId = parentPid Then
    line = line & " self"
  Else
    line = line & " other"
  End If
  f.WriteLine line
Next
If Err.Number <> 0 Then f.WriteLine "error " & Err.Description
f.WriteLine "end"
f.Close
If fso.FileExists(dir & "pol_memory.txt") Then fso.DeleteFile dir & "pol_memory.txt", True
fso.MoveFile dir & "pol_memory.tmp", dir & "pol_memory.txt"
]]

local function ensure_pol_script()
    local f = io.open(POL_SCRIPT, 'r')
    local current = f and f:read('*a')
    if f then f:close() end
    if current == POL_SCRIPT_TEXT then return true end
    f = io.open(POL_SCRIPT, 'w')
    if not f then return false end
    f:write(POL_SCRIPT_TEXT)
    f:close()
    return true
end

-- Starts the query (the answer is read later by read_pol). false = could not start.
local function start_pol()
    if config.memory_check_game_total == false then return false end
    os.remove(POL_RESULT)
    if not ensure_pol_script() then
        error_log('Could not write memcheck_pol.vbs - no pol.exe line this time.')
        return false
    end
    local ok = pcall(windower.open_url, (POL_SCRIPT:gsub('/', '\\')))
    return ok
end

-- Waits up to max_wait seconds for the answer. Returns
-- {private_mb, working_mb, virtual_mb, note} or nil, reason.
local function read_pol(max_wait)
    local waited = 0
    local text
    while true do
        local f = io.open(POL_RESULT, 'r')
        if f then
            text = f:read('*a')
            f:close()
            if text:find('end', 1, true) then break end
        end
        if waited >= max_wait then
            return nil, 'no answer from Windows within ' .. max_wait .. 's (Windows Script Host blocked or .vbs files set to open in an editor?)'
        end
        coroutine.sleep(0.25)
        waited = waited + 0.25
    end
    local procs, self_proc = {}, nil
    for pid, priv, ws, virt, who in text:gmatch('(%d+) (%d+) (%d+) (%d+) (%a+)') do
        local p = {private_mb = tonumber(priv) / 1048576, working_mb = tonumber(ws) / 1048576, virtual_mb = tonumber(virt) / 1048576}
        table.insert(procs, p)
        if who == 'self' then self_proc = p end
    end
    if self_proc then return self_proc end
    if #procs == 1 then return procs[1] end
    if #procs == 0 then
        local err = text:match('error ([^\r\n]*)')
        return nil, 'Windows returned no pol.exe' .. (err and (' (' .. err .. ')') or '')
    end
    table.sort(procs, function(a, b) return a.private_mb > b.private_mb end)
    procs[1].note = 'largest of ' .. #procs .. ' pol.exe - could not tell which is this game'
    return procs[1]
end

-- ---- Garbage collection (GardenHelper's own Lua state only) ----
-- Lua frees unused memory a bit at a time; a full collect frees it all at
-- once. Other addons' memory can't be collected from here.
--
-- v2.21.0: a single collectgarbage('collect') stops the whole game until
-- GardenHelper's entire heap (~28 MB live, mostly the resources tables) has
-- been walked and ~15 MB freed in one go - a visible freeze that got worse
-- as the session went on. Now the collection is done in small steps
-- (gc_step_kb per step, gc_step_wait_seconds between steps) so no single
-- frame does much work, and it is skipped when little garbage has built up
-- since the last one (gc_min_garbage_kb). Each run records the time spent
-- inside the steps (ms) and the longest single step, so the GC: line shows
-- whether it is still causing a hitch.
local last_gc = nil   -- {before_kb, after_kb, time, ms, max_ms, steps, done, mode}
local gc_busy = false

local function now_ms()
    return os.clock() * 1000
end

-- One full collect, all at once (only when we can't sleep between steps).
local function collect_all_at_once()
    local before = collectgarbage('count')
    local t0 = now_ms()
    collectgarbage('collect')
    local ms = now_ms() - t0
    return {before_kb = before, after_kb = collectgarbage('count'), time = os.time(),
            ms = ms, max_ms = ms, steps = 1, done = true, mode = 'full'}
end

-- Stepped collect. Must run inside a coroutine (sleeps between steps).
local function collect_in_steps()
    local step_kb = math.max(64, tonumber(config.gc_step_kb) or 1024)
    local wait = math.max(0, tonumber(config.gc_step_wait_seconds) or 0.05)
    local max_seconds = math.max(1, tonumber(config.gc_max_seconds) or 15)
    local before = collectgarbage('count')
    local started = os.time()
    local total_ms, max_ms, steps, done = 0, 0, 0, false
    while not done do
        local t0 = now_ms()
        done = collectgarbage('step', step_kb)
        local ms = now_ms() - t0
        total_ms = total_ms + ms
        if ms > max_ms then max_ms = ms end
        steps = steps + 1
        if done or os.time() - started >= max_seconds then break end
        coroutine.sleep(wait)
    end
    return {before_kb = before, after_kb = collectgarbage('count'), time = os.time(),
            ms = total_ms, max_ms = max_ms, steps = steps, done = done, mode = 'steps'}
end

-- force = true: collect even if little garbage has built up (//gh memory gc).
-- Returns the result table, or nil if skipped / already running.
local function collect_garbage(force)
    if gc_busy then
        debug_log('Garbage collection already running - skipped.')
        return nil
    end
    local now_kb = collectgarbage('count')
    local min_kb = tonumber(config.gc_min_garbage_kb) or 8192
    if not force and last_gc and now_kb - last_gc.after_kb < min_kb then
        debug_log(string.format('Garbage collection skipped: only %.1f KB built up since the last one (gc_min_garbage_kb %d).', now_kb - last_gc.after_kb, min_kb))
        return nil
    end
    gc_busy = true
    local g
    if coroutine.running() then
        g = collect_in_steps()
    else
        g = collect_all_at_once()
    end
    gc_busy = false
    last_gc = g
    debug_log(string.format('Garbage collection (%s): %.1f KB -> %.1f KB (freed %.1f KB), %d step(s), %.0f ms total, longest step %.0f ms%s.',
        g.mode, g.before_kb, g.after_kb, g.before_kb - g.after_kb, g.steps, g.ms, g.max_ms, g.done and '' or ', stopped at gc_max_seconds (Lua finishes the rest by itself)'))
    return g
end

-- Same, but in the background: returns at once, so //gh full's "pass
-- complete" (and MuleLogger's logout after it) isn't held up.
local function collect_garbage_background()
    if gc_busy then return end
    coroutine.schedule(function() collect_garbage(false) end, 0)
end

local function gc_text(g)
    local freed = g.before_kb - g.after_kb
    local pct = g.before_kb > 0 and string.format('%+.1f%%', -freed / g.before_kb * 100) or 'n/a'
    local timing = g.ms and string.format(', %d step(s), %.0f ms, longest step %.0f ms', g.steps or 1, g.ms, g.max_ms or g.ms) or ''
    return string.format('GardenHelper %.1f KB before -> %.1f KB after, freed %.1f KB (%s)%s', g.before_kb, g.after_kb, freed, pct, timing)
end

-- ---- memory_report.lua (history) ----
-- Reads memory_report.lua: number of runs, each addon's FIRST value (by lower
-- name), the total of the first run, the first run's time, the first
-- pol.exe private MB (base.__pol) and virtual MB (base.__polv), and whether
-- any run already has a GC: line (has_gc).
-- base.__full = the //gh full runs with a pol.exe value, in order
-- ({private, virtual}); base.__mark = how many of them came before the last
-- ">>>>>" marker line.
local function read_history()
    local base, runs, first_total, first_time, has_gc = {}, 0, nil, nil, false
    base.__full, base.__mark = {}, 0
    local f = io.open(REPORT_FILE, 'r')
    if not f then return base, runs, first_total, first_time, has_gc end
    local cur = nil   -- the run being read
    local function close_run()
        if cur and cur.full and cur.private then table.insert(base.__full, cur) end
        cur = nil
    end
    for line in f:lines() do
        if line:find('^%-%- >>>>>') then
            close_run()
            base.__mark = #base.__full
        end
        if line:find('^%-%-%s+GC: ') then has_gc = true end
        local virt_mb = line:match('^%-%-%s+pol%.exe: private .- virtual ([%d%.]+) MB')
        if virt_mb and not base.__polv then base.__polv = tonumber(virt_mb) end
        if virt_mb and cur then cur.virtual = tonumber(virt_mb) end
        local pol_mb = line:match('^%-%-%s+| pol%.exe %(whole game%)%s*| %s*([%d%.]+) MB')
            or line:match('^%-%- pol%.exe .-| private ([%d%.]+) MB')
        if pol_mb and not base.__pol then base.__pol = tonumber(pol_mb) end
        if pol_mb and cur then cur.private = tonumber(pol_mb) end
        local run_no, when = line:match('^%-%- =+ Run (%d+) | ([^|]-) |')
        if run_no then
            close_run()
            cur = {full = line:find('| full pass |', 1, true) ~= nil}
            runs = math.max(runs, tonumber(run_no))
            if not first_time then first_time = when end
            local total = line:match('total ([%d%.]+) KB')
            if total and not first_total then first_total = tonumber(total) end
        else
            local name, kb = line:match('^%-%-%s+%d+ | (.-)%s*| %s*([%d%.]+) KB')
            if name and name ~= '' then
                local key = name:lower()
                if base[key] == nil then base[key] = tonumber(kb) end
            end
        end
    end
    close_run()
    f:close()
    return base, runs, first_total, first_time, has_gc
end

-- Average growth per run over list[from..#list]: private, virtual, count
-- (nil when fewer than 2 runs).
local function per_run(list, from)
    local first, last = list[from], list[#list]
    local n = #list - from + 1
    if not first or n < 2 then return nil end
    local priv = (last.private - first.private) / (n - 1)
    local virt = (first.virtual and last.virtual) and (last.virtual - first.virtual) / (n - 1) or nil
    return priv, virt, n
end

local function per_char_text(list, mark)
    local function part(from, what)
        local priv, virt, n = per_run(list, from)
        if not priv then return what .. ': needs 2+ characters' end
        return string.format('%s: pol.exe %+.1f MB, virtual %s (%d characters)', what, priv,
            virt and string.format('%+.1f MB', virt) or '?', n)
    end
    local since_mark = mark > 0 and part(mark + 1, 'since the last >>>>> marker') or nil
    local all = part(1, 'since the oldest run')
    return since_mark and (since_mark .. ' | ' .. all) or all
end

-- //gh memory mark <note>: a ">>>>>" marker line in memory_report.lua.
local function write_mark(note)
    local f = io.open(REPORT_FILE, 'a')
    if not f then
        error_log('Could not write memory_report.lua.')
        return
    end
    local player = windower.ffxi.get_player()
    f:write(string.format('-- >>>>> Marker (%s, %s): %s\n\n', os.date('%Y-%m-%d %H:%M:%S'),
        player and player.name or '?', note ~= '' and note or '(no note)'))
    f:close()
    log('Marker written to memory_report.lua: ' .. (note ~= '' and note or '(no note)') ..
        ' - the per-character average starts over from the next //gh full.')
end

local function pct_text(now_kb, base_kb)
    if not base_kb then return 'base' end
    if base_kb <= 0 then return 'n/a' end
    return string.format('%+.1f%%', (now_kb - base_kb) / base_kb * 100)
end

local function write_header(mode)
    local f = io.open(REPORT_FILE, mode)
    if not f then return nil end
    f:write(table.concat(REPORT_HEADER, '\n') .. '\n')
    return f
end

-- ---- The check ----
-- label = what started it ('manual', 'full pass'). Returns true if the
-- report was made.
local running = false

local function run_check(label)
    log('Running memory check on all loaded addons...')
    -- GC first, so GardenHelper's row is live memory only. //gh full has
    -- just done it (in_full); a manual check does it here.
    local gc = nil
    if config.gc_at_end_of_full ~= false then
        if last_gc and os.time() - last_gc.time <= 120 then
            gc = last_gc
        else
            gc = collect_garbage(true)
        end
    end
    local pol_started = start_pol()
    local lines, source = catch_lua_memory()
    if #lines == 0 then
        error_log('No addon memory numbers (tried: ' .. table.concat(LUA_MEMORY_WAYS, ', ') .. ') - addon rows left out this run.')
    else
        debug_log('Addon memory read from ' .. source .. '.')
    end
    local pol, pol_why
    if pol_started then
        pol, pol_why = read_pol(config.memory_check_game_wait_seconds or 10)
    elseif config.memory_check_game_total ~= false then
        pol_why = 'could not start the Windows query'
    end
    table.sort(lines, function(a, b) return a.kb > b.kb end)

    local base, runs, first_total, first_time, has_gc = read_history()
    local total = 0
    for _, e in ipairs(lines) do total = total + e.kb end
    local run_no = runs + 1
    local now = os.date('%Y-%m-%d %H:%M:%S')
    local player = windower.ffxi.get_player()
    local who = player and player.name or '?'
    -- Every row: value, growth (amount) and growth (%) vs. the oldest run.
    local function row(name, value, unit, base_value)
        local amount, pct = 'base', 'base'
        if base_value then
            amount = string.format('%+.1f %s', value - base_value, unit)
            pct = base_value > 0 and string.format('%+.1f%%', (value - base_value) / base_value * 100) or 'n/a'
        end
        return {name = name, value = string.format('%.1f %s', value, unit), amount = amount, pct = pct}
    end
    local rows = {}
    if #lines > 0 then
        table.insert(rows, row('Total Lua (' .. #lines .. ' addons)', total, 'KB', first_total))
    end
    if pol then
        table.insert(rows, row('pol.exe (whole game)', pol.private_mb, 'MB', base.__pol))
        table.insert(rows, row('pol.exe virtual (address space)', pol.virtual_mb, 'MB', base.__polv))
    end
    local first_addon = #rows + 1
    for _, e in ipairs(lines) do
        table.insert(rows, row(e.name, e.kb, 'KB', base[e.name:lower()]))
    end
    -- Per character: this run counts when it's a //gh full with a pol.exe value.
    local per_char = nil
    if pol and label == 'full pass' then
        local list = {}
        for _, e in ipairs(base.__full) do table.insert(list, e) end
        table.insert(list, {private = pol.private_mb, virtual = pol.virtual_mb})
        -- The first GC run writes its own marker just above it (below).
        local mark = (gc and not has_gc) and #base.__full or base.__mark
        per_char = per_char_text(list, mark)
    end
    local width = 12
    for _, r in ipairs(rows) do width = math.max(width, #r.name) end
    local function rank(i) return i >= first_addon and tostring(i - first_addon + 1) or '' end

    -- Chat
    log(string.format('Memory check #%d (%s) - growth vs. %s:', run_no, label, first_time and ('the oldest run, ' .. first_time) or 'nothing yet (this is the baseline run)'))
    for i, r in ipairs(rows) do
        log(string.format('  %3s %-' .. width .. 's %12s  %12s  %8s', rank(i) ~= '' and (rank(i) .. '.') or '', r.name, r.value, r.amount, r.pct))
    end
    if pol then
        log(string.format('  (pol.exe = private memory; %.1f MB in RAM%s)', pol.working_mb, pol.note and ('; ' .. pol.note) or ''))
    elseif pol_why then
        log('  pol.exe (whole game): not read - ' .. pol_why)
    end
    if gc then
        log('  GC: ' .. gc_text(gc))
    end
    if per_char then
        log('  Per character: ' .. per_char)
    end

    -- memory_report.lua (append; header first if the file is new)
    local f
    local existing = io.open(REPORT_FILE, 'r')
    if existing then
        existing:close()
        f = io.open(REPORT_FILE, 'a')
    else
        f = write_header('w')
    end
    if not f then
        error_log('Could not write memory_report.lua - report shown in chat only.')
        return true
    end
    -- One-time marker above the first run with GardenHelper's garbage collection.
    if gc and not has_gc then
        f:write(string.format('-- >>>>> From Run %d on (GardenHelper v%s, %s): GardenHelper runs collectgarbage(\'collect\') before\n', run_no, (_addon and _addon.version or '?'), now))
        f:write('-- >>>>> every check (end of every //gh full). Runs above this line are without it - compare\n')
        f:write('-- >>>>> the GardenHelper and pol.exe rows above and below this line to see whether it helped.\n\n')
    end
    local gc_tag = gc and string.format(' | GC freed %.1f KB', gc.before_kb - gc.after_kb) or ''
    if #lines > 0 then
        f:write(string.format('-- ===== Run %d | %s | %s | %s | %d addons | total %.1f KB%s =====\n',
            run_no, now, who, label, #lines, total, gc_tag))
    else
        f:write(string.format('-- ===== Run %d | %s | %s | %s | no addon list (//lua memory gave no answer)%s =====\n',
            run_no, now, who, label, gc_tag))
    end
    f:write(string.format('-- %3s | %-' .. width .. 's | %12s | %12s | %8s\n', '#', 'Name', 'Memory', 'Growth', 'Growth %'))
    for i, r in ipairs(rows) do
        f:write(string.format('-- %3s | %-' .. width .. 's | %12s | %12s | %8s\n', rank(i), r.name, r.value, r.amount, r.pct))
    end
    if pol then
        f:write(string.format('--       pol.exe: private (above) %.1f MB, in RAM %.1f MB, virtual %.1f MB%s\n',
            pol.private_mb, pol.working_mb, pol.virtual_mb, pol.note and (' - ' .. pol.note) or ''))
    elseif pol_why then
        f:write('--       pol.exe: not read - ' .. pol_why .. '\n')
    end
    if gc then
        f:write('--       GC: ' .. gc_text(gc) .. '\n')
    end
    if per_char then
        f:write('--       Per character: ' .. per_char .. '\n')
    end
    f:write('\n')   -- gap between runs
    f:close()
    log('Memory report saved to memory_report.lua (run ' .. run_no .. ').')
    return true
end

-- No pcall around run_check: Lua 5.1 can't sleep (yield) inside pcall.
-- A check that died mid-way stops blocking after 60s.
local function run(label)
    if running and os.time() - running < 60 then
        log('Memory check already running.')
        return false
    end
    running = os.time()
    local result = run_check(label)
    running = false
    return result
end

-- End of //gh full: garbage collection (gc_at_end_of_full) - in the
-- background, in small steps - then the memory check when turned on
-- (which waits for the GC so its GardenHelper row is live memory only).
local function in_full()
    if config.memory_check_in_full then
        -- The memory check wants the GC done first (and waits for it).
        if config.gc_at_end_of_full ~= false then collect_garbage(false) end
        run('full pass')
    elseif config.gc_at_end_of_full ~= false then
        collect_garbage_background()
    end
end

local function reset()
    local f = write_header('w')
    if not f then
        error_log('Could not rewrite memory_report.lua.')
        return
    end
    f:close()
    log('memory_report.lua cleared - the next memory check is the new baseline (0%).')
end

-- //gh memory [on|off|reset|status|gc|mark <note>]
local function command(args)
    if args[1] and args[1]:lower() == 'memprobe' then
        record_probe(args)
        return
    end
    local sub = args[2] and args[2]:lower() or nil
    if sub == nil or sub == 'now' or sub == 'run' then
        run('manual')
    elseif sub == 'reset' or sub == 'clear' then
        reset()
    elseif sub == 'mark' or sub == 'marker' then
        write_mark(table.concat(args, ' ', 3))
    elseif sub == 'gc' then
        local g = collect_garbage(true)
        if g then
            log('GC: ' .. gc_text(g) .. '.')
        else
            log('GC: already running - try again in a few seconds.')
        end
    elseif sub == 'on' or sub == 'off' then
        config.memory_check_in_full = (sub == 'on')
        write_toggle(config.memory_check_in_full)
        log('Memory check at the end of every //gh full: ' .. (config.memory_check_in_full and 'ON' or 'OFF') .. ' (saved).')
    elseif sub == 'status' then
        local _, runs, _, first_time = read_history()
        log('Memory check at the end of every //gh full: ' .. (config.memory_check_in_full and 'ON' or 'OFF') ..
            '; memory_report.lua holds ' .. runs .. ' run(s)' .. (first_time and (', oldest ' .. first_time) or '') .. '.')
    else
        error_log('Unknown option "' .. sub .. '". Use //gh memory [on|off|reset|status|gc|mark <note>].')
    end
end

local help_lines = {
    '  memory [on|off|reset|status|gc|mark <note>] - memory used by every loaded addon, most on top, with % vs. the oldest run in memory_report.lua (report appended there). on/off = also at the end of every full (saved); reset = clear memory_report.lua; gc = free GardenHelper\'s unused Lua memory now; mark <note> = marker line in the report (per-character average starts over)',
}

return {run = run, command = command, in_full = in_full, help_lines = help_lines}
end

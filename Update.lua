-- =====================================================================
-- Update.lua - GardenHelper module: //gh update (download the newest
-- release from GitHub and reload).
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
--
--   //gh update        - newer version on GitHub? download it, install it,
--                        reload GardenHelper.
--   //gh update check  - only say which version GitHub has.
--   //gh update force  - install GitHub's version even if it is the same
--                        or older (repair a broken install / roll back).
--   Add major or minor to any of them to pick the branch for that run
--   (e.g. //gh update minor, //gh update check minor).
--
-- Branches (v1.1.0):
--   major - full releases, fully tested and validated. The default.
--   minor - smaller changes, out sooner, less tested.
--   characters.lua update_branch = 'major' / 'minor' picks your default
--   ('' or missing = major).
--
-- What it does:
--   1. Reads manifest.txt from the repo: "version=X.Y.Z" plus one line
--      "file=<name> <bytes>" per file in the release.
--   2. Downloads every listed file into memory and checks it: the exact
--      size, .lua files must compile, and GardenHelper.lua must carry the
--      manifest's version (GitHub's raw files are cached for a few
--      minutes after a release - an old copy is refused, try again later).
--   3. Only then writes anything: each file it replaces is first copied to
--      backup/<name> v<old> pre-update <date time>.<ext>. If a write fails,
--      every file already written is put back.
--   4. Reloads GardenHelper; after the reload one line says
--      "Updated and reloaded - GardenHelper vX (was vY)."
--
-- NEVER touched (your own files, whatever the manifest says):
--   characters.lua, ItemTable.lua, ItemTable_*.lua, Mail.lua,
--   memory_report.lua, anything in data/ or backup/.
--   New settings a release adds to characters.lua / ItemTable.lua are
--   described in CHANGELOG.md - copy them over by hand.
--
-- Refused while GardenHelper is running something (//gh stop first).
-- The download blocks the game for a moment (a few seconds at most;
-- 15 s timeout per file).
-- =====================================================================

return function(gh)
    local M = {version = '1.1.0'}

    local REPO_RAW = 'https://raw.githubusercontent.com/thrydwolfvalefor/gardenhelper/'
    local BRANCHES = {major = true, minor = true}

    -- characters.lua update_branch, or 'major'.
    local function default_branch()
        local b = gh.character_file and gh.character_file.update_branch
        b = type(b) == 'string' and b:lower():match('^%s*(.-)%s*$') or ''
        return BRANCHES[b] and b or 'major'
    end
    local TIMEOUT_SECONDS = 15
    local NOTIFY_FILE = 'data/update_notify.txt'

    -- Files the updater must never write, even if a manifest lists them.
    local function is_user_file(name)
        local n = name:lower()
        if n == 'characters.lua' or n == 'itemtable.lua' or n == 'mail.lua' or n == 'memory_report.lua' then return true end
        if n:match('^itemtable_.*%.lua$') then return true end
        return false
    end

    -- Plain file names only (no folders, no ..), known kinds of file.
    local function is_safe_name(name)
        if name == '' or name:find('[/\\:]') or name:find('%.%.') or name:sub(1, 1) == '.' then return false end
        local n = name:lower()
        return n:match('%.lua$') or n:match('%.md$') or n:match('%.txt$') or n:match('%.vbs$') or n == 'license'
    end

    local function path(name) return windower.addon_path .. name end

    local function read_file(p)
        local f = io.open(p, 'rb')
        if not f then return nil end
        local s = f:read('*a')
        f:close()
        return s
    end

    local function write_file(p, content)
        local f, err = io.open(p, 'wb')
        if not f then return false, err end
        local ok, werr = f:write(content)
        f:close()
        if not ok then return false, werr end
        return true
    end

    -- "2.31.0" vs "2.32.0" -> -1 / 0 / 1.
    local function ver_cmp(a, b)
        local pa, pb = {}, {}
        for n in tostring(a):gmatch('%d+') do pa[#pa + 1] = tonumber(n) end
        for n in tostring(b):gmatch('%d+') do pb[#pb + 1] = tonumber(n) end
        for i = 1, math.max(#pa, #pb) do
            local x, y = pa[i] or 0, pb[i] or 0
            if x ~= y then return x < y and -1 or 1 end
        end
        return 0
    end

    -- HTTPS GET with Windower's LuaSec. Returns the body, or nil + error.
    local function http_get(url)
        local ok_https, https = pcall(require, 'ssl.https')
        if not ok_https or not https then
            return nil, 'LuaSec (ssl.https) is not available in this Windower install'
        end
        local ltn12 = require('ltn12')
        pcall(function() https.TIMEOUT = TIMEOUT_SECONDS end)
        pcall(function() require('socket.http').TIMEOUT = TIMEOUT_SECONDS end)
        local chunks = {}
        -- os.time() on the end asks GitHub's cache for a fresh copy.
        local full = url .. (url:find('?', 1, true) and '&' or '?') .. 't=' .. os.time()
        local ok, r1, code = pcall(https.request, {
            url = full,
            sink = ltn12.sink.table(chunks),
            protocol = 'any',
            options = 'all',
            verify = 'none',
            headers = {['Cache-Control'] = 'no-cache', ['User-Agent'] = 'GardenHelper-Windower'},
        })
        if not ok then return nil, tostring(r1) end
        if r1 == nil then return nil, tostring(code) end
        if code ~= 200 then return nil, 'HTTP ' .. tostring(code) end
        return table.concat(chunks)
    end

    -- manifest.txt -> {version = 'x.y.z', files = {{name, size}, ...}} or nil + error.
    local function parse_manifest(text)
        local m = {files = {}}
        for line in (text .. '\n'):gmatch('([^\r\n]*)\r?\n') do
            local v = line:match('^%s*version%s*=%s*([%d%.]+)%s*$')
            if v then m.version = v end
            local name, size = line:match('^%s*file%s*=%s*(.-)%s+(%d+)%s*$')
            if name then table.insert(m.files, {name = name, size = tonumber(size)}) end
        end
        if not m.version then return nil, 'manifest.txt has no version line' end
        if #m.files == 0 then return nil, 'manifest.txt lists no files' end
        return m
    end

    local function stamp() return os.date('%Y-%m-%d %H%M') end

    local function backup_name(name, old_ver)
        local stem, ext = name:match('^(.*)(%.[^%.]+)$')
        if not stem then stem, ext = name, '' end
        return 'backup/' .. stem .. ' v' .. old_ver .. ' pre-update ' .. stamp() .. ext
    end

    local function ensure_dir(rel)
        local full = windower.addon_path .. rel
        local exists = false
        pcall(function() exists = windower.dir_exists(full) end)
        if not exists then pcall(windower.create_dir, full) end
    end

    local function do_update(mode, branch)
        local current = _addon.version
        local base = REPO_RAW .. branch .. '/'
        gh.log('Update: checking GitHub (thrydwolfvalefor/gardenhelper, ' .. branch .. ' branch)...')
        local text, err = http_get(base .. 'manifest.txt')
        if not text then
            gh.error_log('Update: could not read manifest.txt from GitHub (' .. tostring(err) .. ').')
            return
        end
        local man, perr = parse_manifest(text)
        if not man then
            gh.error_log('Update: ' .. perr .. '.')
            return
        end
        local cmp = ver_cmp(man.version, current)
        if mode == 'check' then
            if cmp > 0 then
                gh.log('Update: v' .. man.version .. ' is on the ' .. branch .. ' branch (you have v' .. current .. '). //gh update' .. (branch ~= default_branch() and (' ' .. branch) or '') .. ' installs it.')
            elseif cmp == 0 then
                gh.log('Update: you have the newest ' .. branch .. ' version (v' .. current .. ').')
            else
                gh.log('Update: the ' .. branch .. ' branch has v' .. man.version .. ', older than yours (v' .. current .. ').')
            end
            return
        end
        if cmp <= 0 and mode ~= 'force' then
            gh.log('Update: already up to date (v' .. current .. (cmp < 0 and (', ' .. branch .. ' has v' .. man.version) or '') .. '). //gh update force' .. (branch ~= default_branch() and (' ' .. branch) or '') .. ' installs the ' .. branch .. ' copy anyway.')
            return
        end

        -- Download and check everything before writing anything.
        local downloads, skipped = {}, {}
        for _, f in ipairs(man.files) do
            if is_user_file(f.name) then
                table.insert(skipped, f.name)
            elseif not is_safe_name(f.name) then
                gh.error_log('Update: manifest.txt names an unexpected file "' .. f.name .. '" - update cancelled, nothing changed.')
                return
            else
                local body, derr = http_get(base .. f.name)
                if not body then
                    gh.error_log('Update: could not download ' .. f.name .. ' (' .. tostring(derr) .. ') - nothing changed.')
                    return
                end
                if #body ~= f.size then
                    gh.error_log('Update: ' .. f.name .. ' is ' .. #body .. ' bytes, manifest says ' .. f.size ..
                        ' - GitHub may still be serving an older copy. Nothing changed; try again in a few minutes.')
                    return
                end
                if f.name:lower():match('%.lua$') then
                    local chunk, cerr = loadstring(body, f.name)
                    if not chunk then
                        gh.error_log('Update: ' .. f.name .. ' does not compile (' .. tostring(cerr) .. ') - nothing changed.')
                        return
                    end
                end
                if f.name == 'GardenHelper.lua' and not body:find("_addon.version = '" .. man.version .. "'", 1, true) then
                    gh.error_log('Update: GitHub\'s GardenHelper.lua is not v' .. man.version ..
                        ' yet (cached copy). Nothing changed; try again in a few minutes.')
                    return
                end
                table.insert(downloads, {name = f.name, body = body})
            end
        end
        local has_main = false
        for _, d in ipairs(downloads) do if d.name == 'GardenHelper.lua' then has_main = true end end
        if not has_main then
            gh.error_log('Update: manifest.txt has no GardenHelper.lua - nothing changed.')
            return
        end

        -- Back up, then write. A failed write puts back what was written.
        ensure_dir('backup')
        ensure_dir('data')
        local written, changed = {}, 0
        for _, d in ipairs(downloads) do
            local old = read_file(path(d.name))
            if old ~= d.body then
                if old then
                    local bn = backup_name(d.name, current)
                    local ok, berr = write_file(path(bn), old)
                    if not ok then
                        gh.error_log('Update: could not back up ' .. d.name .. ' to ' .. bn .. ' (' .. tostring(berr) .. ').')
                        for _, w in ipairs(written) do
                            if w.old then write_file(path(w.name), w.old) else os.remove(path(w.name)) end
                        end
                        gh.error_log('Update: cancelled - ' .. #written .. ' file(s) already written were put back.')
                        return
                    end
                end
                local ok, werr = write_file(path(d.name), d.body)
                if not ok then
                    gh.error_log('Update: could not write ' .. d.name .. ' (' .. tostring(werr) .. ').')
                    for _, w in ipairs(written) do
                        if w.old then write_file(path(w.name), w.old) else os.remove(path(w.name)) end
                    end
                    gh.error_log('Update: cancelled - ' .. #written .. ' file(s) already written were put back.')
                    return
                end
                table.insert(written, {name = d.name, old = old})
                changed = changed + 1
            end
        end

        if #skipped > 0 then
            gh.log('Update: left your own file(s) alone: ' .. table.concat(skipped, ', ') .. '.')
        end
        gh.log('Update: downloaded v' .. man.version .. ' from ' .. branch .. ' (' .. changed .. ' file(s) changed, old copies in backup/) - reloading...')
        write_file(path(NOTIFY_FILE), current)
        coroutine.schedule(function() windower.send_command('lua r gardenhelper') end, 0.5)
    end

    -- //gh update [check|force] [major|minor]
    function M.command(args)
        local sub, branch = '', nil
        for i = 2, #args do
            local a = tostring(args[i]):lower()
            if a == 'help' then
                gh.log('//gh update [major|minor] - install the newest release from that GitHub branch and reload (default: characters.lua update_branch, now ' .. default_branch() .. '); check = only compare versions; force = install it even if not newer. major = full tested releases, minor = smaller changes sooner. characters.lua, ItemTable*.lua, Mail.lua and data/ are never touched.')
                return
            elseif a == 'check' or a == 'force' then
                sub = a
            elseif BRANCHES[a] then
                branch = a
            else
                gh.error_log('Update: unknown option "' .. a .. '" - use //gh update [check|force] [major|minor].')
                return
            end
        end
        branch = branch or default_branch()
        if sub ~= 'check' and gh.state.running then
            gh.log('Update: GardenHelper is running something - //gh stop first, then //gh update.')
            return
        end
        local ok, err = pcall(do_update, sub, branch)
        if not ok then
            gh.error_log('Update: failed (' .. tostring(err) .. ') - nothing was reloaded.')
        end
    end

    -- After an update's reload: one line saying what changed.
    do
        local old = read_file(path(NOTIFY_FILE))
        if old then
            os.remove(path(NOTIFY_FILE))
            old = old:match('^%s*(.-)%s*$')
            coroutine.schedule(function()
                gh.log('Updated and reloaded - GardenHelper v' .. _addon.version .. (old ~= '' and (' (was v' .. old .. ')') or '') .. '.')
            end, 1)
        end
    end

    return M
end

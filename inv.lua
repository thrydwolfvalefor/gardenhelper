-- =====================================================================
-- inv.lua - GardenHelper module: the inventory manager. Every item's
-- handling lives in ONE place, ItemTable.lua (action per item) - no
-- separate sell or drop addon is needed:
--   sell - at the Green Thumb Moogle: sells every action = "sell" item
--          in main inventory, and every action = "save" item held above
--          its min_save (all bags counted; the extra is pulled out of
--          the other bags first) when it has no mail_to
--   drop - drops every action = "drop" item in main inventory and passes
--          them in the treasure pool. Also runs by itself (auto_drop):
--          drop items are dropped as they land in main inventory and
--          passed as they hit the treasure pool
--   pop  - adds every main-inventory item ItemTable.lua doesn't list yet
--          with action = "" (sorted to the top for review)
--   send - mails action = "send" items to their mail_to once there are
--          min_mail of them in MAIN INVENTORY (other bags are never
--          touched - they hold stock for other characters); action = "save" items with
--          a mail_to and a min_save mail the extra instead of selling it.
--          mail_cap > 0 (v4.13.0): mail_to is never sent more than it
--          takes to reach mail_cap copies (findAll + mail still in its
--          Delivery Box); sell sells the copies over that instead
--   rec  - takes everything out of the Delivery Box, round after round,
--          until a round comes back with a box that wasn't full. Stops
--          waiting as soon as the box goes quiet / a pull brings nothing
--   org  - moves items with a store_bag: a bag name = out of main
--          inventory into it (PullFromBags = true: out of every bag); "bag_order" = out of main inventory into
--          the first bag_order bag with room; blank = left where it is
--   inv  - all six, in that order
-- Data files next to GardenHelper.lua, re-read before every step:
--   ItemTable.lua - settings, bag_order, items (yours to edit;
--                   only pop rewrites it, and only when it adds items)
--   Mail.lua      - mail tracking + last step results (INV's file)
-- A file with a Lua error is never written - the step stops instead.
-- The previous copy of each is kept in backup/<file>.bak.
-- This character's furrow fertilizer and node fertilizers are never
-- sold, dropped, mailed away or moved out of main inventory. The active
-- seed is not protected (v4.16.0) - its ItemTable.lua line decides.
-- Loaded by GardenHelper.lua, which passes its shared table (gh) in.
-- Returns the INV table (API at the bottom). History: CHANGELOG-inv.md.
-- =====================================================================
return function(gh)

local res = require('resources')
local packets = require('packets')
local config, state = gh.config, gh.state
local log, error_log = gh.log, gh.error_log

local M = {version = '4.17.1'}
local STEPS = {'sell', 'drop', 'pop', 'send', 'rec', 'org'}
-- characters.lua modules switch per step (automatic runs only). drop
-- has no switch - it always runs.
local STEP_SWITCH = {sell = 'sell', pop = 'process_inv', send = 'send_mail', rec = 'receive_mail', org = 'org_inv'}
-- The item table file (v4.17.0): characters.lua item_table (e.g.
-- 'ItemTable_Shadowhammer.lua'), else ItemTable.lua - asked fresh every
-- time, so a characters.lua edit applies without a reload.
local function items_file_name()
    local ok, f = pcall(function() return gh.item_table_file and gh.item_table_file() end)
    if ok and type(f) == 'string' and f ~= '' then return f end
    return 'ItemTable.lua'
end
local MAIL_FILE_NAME = 'Mail.lua'

-- Accepted action values, in the order ItemTable.lua is sorted by
-- (blank first = new items to review).
local ACTION_ORDER = {'', 'save', 'send', 'ignore', 'sell', 'drop'}
local ACTION_RANK = {}
for i, a in ipairs(ACTION_ORDER) do ACTION_RANK[a] = i end
local ACTION_TITLES = {
    [''] = 'NEW / REVIEW   (action = "")  - pop adds items here; nothing is done with them',
    save = 'SAVE   (action = "save")  - kept; min_save > 0 = extra is mailed (mail_to) or sold',
    send = 'SEND   (action = "send")  - mailed to mail_to once there are min_mail of them (main inventory only)',
    ignore = 'IGNORE   (action = "ignore")  - never sold, dropped, mailed or moved',
    sell = 'SELL   (action = "sell")  - sold to the Green Thumb Moogle by //gh sell',
    drop = 'DROP   (action = "drop")  - dropped from inventory / passed in the treasure pool',
}

-- Item types, in the order each action's section is grouped by (any other
-- type follows A-Z). type is only a grouping - it changes nothing.
local INV_TYPE_ORDER = {
    'Fish_unstackable', 'Fish_stackable', 'Fish', 'Wood', 'Smith', 'Gold', 'Cloth',
    'Leather', 'Bone', 'Alchemy', 'Cook', 'Food', 'Medicine', 'Seeds', 'Crystals', 'Geode',
    'Scroll', 'Weapon', 'Armor', 'Gear', 'Craft', 'General',
}
local INV_TYPE_DESCRIPTIONS = {
    Fish_unstackable = 'Fish that don\'t stack',
    Fish_stackable = 'Fish that stack (12 or 99)',
    Fish = 'Fish (sell / drop sections)',
    Wood = 'Logs, Lumber, Lbr.',
    Smith = 'Smithing ores/ingots/sheets (Iron, Steel, Darksteel, Adaman...)',
    Gold = 'Goldsmithing ores/ingots/sheets/gems (Gold, Silver, Mythril...)',
    Cloth = 'Cloths, Threads, cotton, cocoons',
    Leather = 'Hides, Skins, Leather',
    Bone = 'Bones, beaks, talons, shells, horns, fangs',
    Alchemy = 'Alchemy materials',
    Cook = 'Cooking ingredients (meat, eggs, vegetables, spices)',
    Food = 'Cooked food, anything eaten for a food buff',
    Medicine = 'Potions, Ethers, Elixirs, drops',
    Seeds = 'Seeds and other things to be planted, pots',
    Crystals = 'Crystals and clusters',
    Geode = 'Geodes, avatarites, fewells',
    Scroll = 'Spell scrolls',
    Weapon = 'Weapons',
    Armor = 'Armor',
    Gear = 'Any gear that can be worn',
    Craft = 'Crafting accessories/tools not specific to one craft',
    General = 'not really used right now',
}

local INV_DEFAULT_BAG_ORDER = {'case', 'satchel', 'safe2', 'safe', 'storage'}

-- Accepted bag values (ItemTable.lua store_bag fields and bag_order) ->
-- the Windower bag id (res/bags.lua). store_bag also takes "bag_order".
local INV_BAG_IDS = {
    inventory = 0,
    safe = 1, storage = 2, locker = 4, satchel = 5, sack = 6, case = 7,
    wardrobe = 8, safe2 = 9, wardrobe2 = 10, wardrobe3 = 11, wardrobe4 = 12,
    wardrobe5 = 13, wardrobe6 = 14, wardrobe7 = 15, wardrobe8 = 16,
}
local INV_BAG_VALUE_LIST = 'inventory, case, satchel, sack, safe, safe2, storage, locker, wardrobe, wardrobe2 ... wardrobe8'
-- Every bag besides main inventory: org gathers from them, min_save
-- counts them, sell / send pull extra copies out of them. Bags that are
-- switched off or can't be reached here (Mog House bags away from it)
-- are skipped.
local INV_SEARCH_BAGS = {'case', 'satchel', 'sack', 'safe2', 'safe', 'storage', 'locker',
    'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8'}

local last_send_epoch = 0   -- when this session last sent mail (receive waits after it)
local active = false        -- a step is running
local drop_step_pending = false  -- //gh inv run has a drop step still to come

local function inv_should_stop()
    return not state.running
end

-- Sleeps in small steps so //gh stop is noticed. Returns false if stopped.
local function inv_sleep(seconds)
    local waited = 0
    while waited < seconds do
        if inv_should_stop() then return false end
        local step = math.min(0.25, seconds - waited)
        coroutine.sleep(step)
        waited = waited + step
    end
    return not inv_should_stop()
end

local function inv_debug(message)
    if config.mail_debug then
        windower.add_to_chat(207, 'GardenHelper [inv]: ' .. message)
    end
end

-- "Charname" style (how FFXI shows every character name) from any casing.
local function proper_name(name)
    name = tostring(name or '')
    return name:sub(1, 1):upper() .. name:sub(2):lower()
end

local function current_character_lower()
    local player = windower.ffxi.get_player()
    return player and player.name and player.name:lower() or nil
end


---------------------------------------------------------------------
-- Type inference for new items (pop). Best effort - anything it can't
-- place is left as type = "" to fill in by hand.
---------------------------------------------------------------------
local INV_FISH_NAMES = {}
for _, n in ipairs({
    'Gugru Tuna', 'Cobalt Jellyfish', 'Gigant Squid', 'Bluetail', 'Mackerel',
    'Moorish Idol', 'Elshimo Newt', 'Moat Carp', 'Copper Frog', 'Gavial Fish',
    'Crescent Fish', 'Giant Catfish', 'Ca Cuong', 'Yorchete', 'Dark Bass',
    'Gold Carp', 'Black Eel', 'Ulbukan Lobster', 'Yayinbaligi', 'Pipira',
    'Ruddy Seema', 'Contortopus', 'Black Prawn', 'Black Sole', 'Brass Loach',
    'Three-eyed Fish', 'Cone Calamary', 'Zebra Eel', 'Quus', 'Bastore Bream',
    'Titanictus', 'Crayfish', 'Black Ghost', 'Red Terrapin', 'Bhefhel Marlin',
    'Dwarf Remora', 'Senroh Sardine', 'Tiny Goldfish', 'Matsya', 'Dragonfish',
    'Emperor Fish', 'Shall Shell', 'Nosteau Herring', 'Bastore Sardine',
    'Greedie', 'Tricolored Carp', 'Crystal Bass', 'Pirarucu', 'Lik',
    'Gugrusaurus', 'Monke-Onke', 'Istiridye', 'Jungle Catfish', 'Sandfish',
    'Giant Donko', 'Istavrit', 'Kalkanbaligi', 'Tiger Shark', 'Armored Pisces',
    'Ahtapot', 'Mercanbaligi', 'Hamsi', 'Alabaligi', 'Trumpet Shell',
    'Takitaro', 'Cave Cherax', 'Veydal Wrasse', 'Tavnazian Goby', 'Noble Lady',
    'Garpike', 'Ogre Eel', 'Silver Shark', 'Coral Butterfly', 'Grimmonite',
    'Barnacle', 'Pterygotus', 'Megalodon', 'Deademoiselle', 'Kaplanbaligi',
    'Abaia', 'Lakerda', 'Tuna', 'Sea Zombie', 'Sekiryu',
}) do INV_FISH_NAMES[n:lower()] = true end

-- Exact-name overrides (checked first). Lowercase keys.
local INV_EXACT_TYPES = {}
local function add_exact(item_type, names)
    for _, n in ipairs(names) do INV_EXACT_TYPES[n:lower()] = item_type end
end
add_exact('Smith', {'Iron Ore', 'Darksteel Ore', 'Dst. Nugget', 'Adaman Ore', 'Tin Ore',
    'Swamp Ore', 'Khroma Ore', 'Wootz Ore', 'Kopparnickel Ore', 'Titanium Ore',
    'Bismuth Ore', 'Vanadium Ore', 'Scintillant Ingot', 'Iron Sand'})
add_exact('Gold', {'Gold Ore', 'Silver Ore', 'Mythril Ore', 'Platinum Ore', 'Orichalcum Ore',
    'Copper Ore', 'Zinc Ore', 'Phrygian Ore', 'Aht Urhgan Brass', 'Auric Sand',
    'Meteorite', 'Pebble', 'Green Rock', 'Igneous Rock', 'Sardonyx', 'Amethyst',
    'Amber', 'Lapis Lazuli', 'Onyx', 'Clear Topaz', 'Tourmaline', 'Light Opal',
    'Garnet', 'Aquamarine', 'Peridot', 'Topaz', 'Sphene', 'Chrysoberyl',
    'Moonstone', 'Painite', 'Jadeite', 'Turquoise', 'Sunstone', 'Zircon',
    'Black Pearl', 'Pearl', 'Coral Fragment', 'Titanite', 'Velkk Necklace'})
add_exact('Cloth', {'Saruta Cotton', 'Flax Flower', 'Spider Web', 'Crawler Cocoon',
    'Wild Cocoon', 'Moko Grass', 'Red Moko Grass', 'Sheep Wool', 'Ram Wool'})
add_exact('Bone', {'Bone Chip', 'Fish Bones', 'Crab Shell', 'H.Q. Crab Shell',
    'Scorpion Shell', 'H.Q. Scp. Shell', 'Scorpion Claw', 'Turtle Shell', 'Uragnite Shell',
    'Pugil Scales', 'Ram Horn', 'Dragon Bone', 'Dragon Talon', 'Antlion Jaw', 'Beetle Jaw',
    'Beetle Shell', 'Bat Fang', 'Blk. Tiger Fang', 'Sheep Tooth', 'Bugard Tusk',
    'Giant Femur', 'Matamata Shell', 'Wivre Maul', 'Velkk Mask', 'Rusty Bucket'})
add_exact('Alchemy', {'Potion', 'Ether', 'Flint Stone', 'Poison Flour', 'Giant Stinger',
    'Insect Wing', 'Bloodblotch', 'Woozyshroom', 'Coral Fungus', 'Loc. Elutriator',
    'Lesser Chigoe', 'Beehive Chip', 'Dryad Root', 'Isleracea', 'Cactus Stems'})
add_exact('Cook', {'Fresh Mugwort', 'Fresh Marjoram', 'Apple Mint', 'Tarutaru Rice',
    'Rye Flour', 'San d\'Or. Flour', 'Semolina', 'Win. Tea Leaves', 'La Theine Cbg.',
    'Burdock', 'Napa', 'Eggplant', 'Blue Peas', 'Kukuru Bean', 'Millioncorn', 'Puffball',
    'Pine Nuts', 'Acorn', 'Chestnut', 'Walnut', 'Nopales', 'Adoulinian Kelp',
    'Crawler Egg', 'Wijnruit', 'Pamamas', 'Ulbuconut', 'King Locust', 'Skull Locust',
    'Little Worm', 'Yagudo Drink', 'Snapping Mole', 'Dragon Fruit', 'Watermelon',
    'Felicifruit', 'Persikos', 'Yagudo Cherry', 'Faerie Apple', 'Rolanberry',
    'El. Pachira Fruit', 'Marguerite', 'Red Rose'})
add_exact('Seeds', {'Grove Cuttings', 'Tree Cuttings', 'Tree Saplings', 'Revival Root',
    'Vegetable Seeds', 'Grain Seeds', 'Sunflower Seeds', 'Herb Seeds', 'Fruit Seeds',
    'Cactus Arm', 'Wildgrass Seeds', 'Flowerpot'})
add_exact('Craft', {'Fire Crystal', 'Ice Crystal', 'Wind Crystal', 'Earth Crystal',
    'Lightng. Crystal', 'Water Crystal', 'Light Crystal', 'Dark Crystal',
    'Fire Cluster', 'Ice Cluster', 'Wind Cluster', 'Earth Cluster',
    'Lightning Cluster', 'Water Cluster', 'Light Cluster', 'Dark Cluster'})

-- Name patterns (checked in order after the exact list). Lua patterns
-- against the lowercase name.
local INV_PATTERN_TYPES = {
    {' log$', 'Wood'}, {' lumber$', 'Wood'}, {' lbr%.$', 'Wood'},
    {' cloth$', 'Cloth'}, {' thread$', 'Cloth'}, {'cotton', 'Cloth'}, {'silk', 'Cloth'},
    {' hide$', 'Leather'}, {' skin$', 'Leather'}, {'leather', 'Leather'}, {' pelt$', 'Leather'},
    {'iron ', 'Smith'}, {'steel', 'Smith'}, {'adaman', 'Smith'}, {'bronze', 'Smith'},
    {'gold ', 'Gold'}, {'silver ', 'Gold'}, {'mythril', 'Gold'}, {'platinum', 'Gold'},
    {'orichalcum', 'Gold'}, {'copper ', 'Gold'}, {'brass', 'Gold'},
    {' bone', 'Bone'}, {' beak$', 'Bone'}, {' talon$', 'Bone'}, {' shell$', 'Bone'},
    {' horn$', 'Bone'}, {' fang$', 'Bone'}, {' tooth$', 'Bone'}, {' tusk$', 'Bone'},
    {' claw$', 'Bone'}, {' jaw$', 'Bone'}, {' scales?$', 'Bone'}, {'carapace', 'Bone'},
    {'potion', 'Medicine'}, {'ether', 'Medicine'}, {'elixir', 'Medicine'}, {'lixir', 'Medicine'},
    {'mugwort', 'Cook'}, {'flour', 'Cook'}, {' meat$', 'Cook'},
    {'seeds?$', 'Seeds'}, {'sapling', 'Seeds'}, {'cuttings$', 'Seeds'}, {'flowerpot', 'Seeds'},
    {' crystal$', 'Craft'}, {' cluster$', 'Craft'}, {' geode$', 'Geode'}, {' fewell$', 'Geode'},
}

local function infer_item_type(r)
    if not r then return '' end
    local name = (r.en or ''):lower()
    local stack = tonumber(r.stack) or 1
    if INV_FISH_NAMES[name] then
        return stack <= 1 and 'Fish_unstackable' or 'Fish_stackable'
    end
    if r.category == 'Weapon' then return 'Weapon' end
    if r.category == 'Armor' then return 'Armor' end
    if INV_EXACT_TYPES[name] then
        return INV_EXACT_TYPES[name]
    end
    for _, rule in ipairs(INV_PATTERN_TYPES) do
        if name:find(rule[1]) then
            return rule[2]
        end
    end
    if (r.enl or ''):lower():find('^scroll of') then
        return 'Scroll'
    end
    if r.type == 11 then
        return 'Seeds'
    end
    -- Anything else edible (Usable, item type 7) that wasn't a fish,
    -- potion or cooking ingredient above.
    if r.category == 'Usable' and r.type == 7 then
        return 'Food'
    end
    return ''
end

-- Default min_mail for new items: the stack size (12 or 99; 1 for
-- unstackable).
local function default_min_mail(stack)
    stack = tonumber(stack) or 1
    if stack >= 99 then return 99 end
    if stack <= 1 then return 1 end
    return math.min(12, stack)
end

---------------------------------------------------------------------
-- ItemTable.lua + Mail.lua load / write
---------------------------------------------------------------------
local function items_file_path() return windower.addon_path .. items_file_name() end
local function mail_file_path() return windower.addon_path .. MAIL_FILE_NAME end

local function file_exists(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
end

-- Backups always go in the backup folder (created if missing).
local function backup_path_for(file_name)
    local dir = windower.addon_path .. 'backup/'
    if windower.dir_exists and not windower.dir_exists(dir) and windower.create_dir then
        pcall(windower.create_dir, dir)
    end
    return dir .. file_name .. '.bak'
end


local function items_default_data()
    local order = {}
    for i, b in ipairs(INV_DEFAULT_BAG_ORDER) do order[i] = b end
    return {
        settings = {mail_dry_run = true, sell_dry_run = false, drop_dry_run = false,
            auto_drop = false, skip_characters = {}},
        bag_order = order,
        items = {},
    }
end

local function mail_default_data()
    return {mail = {}, status = {}}
end

-- Loads a 'return {...}' file. Returns table, or nil + error text.
-- Missing file -> nil, nil, true.
local function load_table_file(path, label)
    if not file_exists(path) then return nil, nil, true end
    local chunk, err = loadfile(path)
    if not chunk then
        return nil, label .. ' has an error and was NOT changed: ' .. tostring(err)
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then
        return nil, label .. ' did not load (' .. tostring(data) .. ') and was NOT changed.'
    end
    return data
end

local function trim_lower(v)
    return (tostring(v == nil and '' or v):gsub('%s', ''):lower())
end

-- A store_bag / bag_order value -> the bag name, or nil if unknown.
local function valid_bag_name(b)
    b = tostring(b or ''):lower():gsub('%s', '')
    if INV_BAG_IDS[b] then return b end
    return nil
end

-- An item's action ('' / save / send / ignore / sell / drop). Anything
-- else counts as '' (nothing is done with it; pop's review section).
local function item_action(e)
    local a = trim_lower(e and e.action)
    if ACTION_RANK[a] then return a end
    return ''
end

-- Per-character override lines (v4.12.0). Next to an item's default line
--     [4304]          = {name = "Grimmonite", ..., action = "sell", ...},
--     ["4304:FishVFi"] = {name = "Grimmonite", ..., action = "save", min_save = 36, ...},
-- On FishVFi the override line is used for item 4304 instead of the
-- default line (any field it leaves out comes from the default line);
-- every other character uses the default line. One line per character.
-- override_key(k): item id (number) + character (lowercase) for an
-- override key, nil for anything else.
local function override_key(k)
    if type(k) ~= 'string' then return nil end
    local id, who = k:match('^%s*(%d+)%s*:%s*(.-)%s*$')
    if not id or who == '' then return nil end
    return tonumber(id), who:lower()
end

-- data.items with me's override lines applied and every override line
-- taken out - what the steps work from (me = lowercase name, or nil).
local function apply_overrides(data, me)
    local out, over = {}, {}
    for k, e in pairs(data.items) do
        local id, who = override_key(k)
        if id then
            if me and who == me and type(e) == 'table' then over[id] = e end
        else
            out[k] = e
        end
    end
    for id, e in pairs(over) do
        local m = {}
        if type(out[id]) == 'table' then
            for f, v in pairs(out[id]) do m[f] = v end
        end
        for f, v in pairs(e) do m[f] = v end
        if m.name == nil and res.items[id] then m.name = res.items[id].en end
        out[id] = m
    end
    data.items = out
    return data
end

-- Older ItemTable.lua layouts are converted on load (nothing to do once
-- a file is converted; pop writes the new layout):
--   before inv v3.0.0: process_min -> mail_min, bag -> store_bag,
--     mail_to from the owners table by type (owners dropped).
--   before inv v4.0.0: age / process / mail_min ->
--     action (process = false + mail_to = "ignore"; mail_to = "send";
--     type Junk = "" to review; anything else = "save"), min_mail,
--     min_save = 0; a send item with no store_bag gets "bag_order" (the
--     old "mailed to me, no store_bag -> bag_order" rule).
local function migrate_items(data)
    local owner_of = {}
    if type(data.owners) == 'table' then
        local names = {}
        for name in pairs(data.owners) do table.insert(names, tostring(name)) end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        for _, name in ipairs(names) do
            local v = data.owners[name]
            for _, t in ipairs(type(v) == 'table' and v or {v}) do
                t = tostring(t or ''):lower()
                if t ~= '' and not owner_of[t] then owner_of[t] = name end
            end
        end
    end
    for k, e in pairs(data.items) do
        if type(e) == 'table' and not override_key(k) then
            if e.mail_min == nil and e.process_min ~= nil then e.mail_min = e.process_min end
            if e.store_bag == nil and e.bag ~= nil then e.store_bag = e.bag end
            if e.mail_to == nil then e.mail_to = owner_of[tostring(e.type or ''):lower()] or '' end
            e.process_min, e.bag = nil, nil
            if e.action == nil then
                local mail_to = trim_lower(e.mail_to)
                if mail_to ~= '' then
                    e.action = (e.process == false) and 'ignore' or 'send'
                    if e.action == 'send' and trim_lower(e.store_bag) == '' then e.store_bag = 'bag_order' end
                elseif trim_lower(e.type) == 'junk' then
                    e.action = ''
                else
                    e.action = 'save'
                end
            end
            if e.min_mail == nil then e.min_mail = e.mail_min end
            if e.min_save == nil then e.min_save = 0 end
            if e.mail_cap == nil then e.mail_cap = 0 end
            e.age, e.process, e.mail_min = nil, nil, nil
        end
    end
    data.owners = nil
    if type(data.settings) == 'table' then data.settings.default_process = nil end
    return data
end

local function normalize_items(data)
    local defaults = items_default_data()
    if type(data.settings) ~= 'table' then data.settings = defaults.settings end
    if data.settings.mail_dry_run == nil then data.settings.mail_dry_run = true end
    if data.settings.sell_dry_run == nil then data.settings.sell_dry_run = false end
    if data.settings.drop_dry_run == nil then data.settings.drop_dry_run = false end
    if data.settings.auto_drop == nil then data.settings.auto_drop = false end
    if type(data.settings.skip_characters) ~= 'table' then data.settings.skip_characters = {} end
    if type(data.bag_order) ~= 'table' then data.bag_order = defaults.bag_order end
    if type(data.items) ~= 'table' then data.items = {} end
    return migrate_items(data)
end

local function normalize_mail(data)
    if type(data.mail) ~= 'table' then data.mail = {} end
    if type(data.status) ~= 'table' then data.status = {} end
    return data
end
local function lua_str(s)
    return string.format('%q', tostring(s == nil and '' or s))
end

local function lua_val(v)
    if type(v) == 'boolean' or type(v) == 'number' then
        return tostring(v)
    end
    return lua_str(v)
end

local ITEM_FIELD_ORDER = {'name', 'type', 'action', 'mail_to', 'min_mail', 'min_save', 'mail_cap', 'store_bag', 'PullFromBags'}
local ITEM_FIELD_DEFAULTS = {name = '', type = '', action = '', mail_to = '', min_mail = 12, min_save = 0, mail_cap = 0, store_bag = '', PullFromBags = false}

-- The big section banner for one action.
local function action_banner(w, action)
    local bar = '        -- ' .. string.rep('#', 96)
    local title = ACTION_TITLES[action] or ('action = "' .. action .. '"')
    w('')
    w('')
    w(bar)
    w(bar)
    w('        -- ####' .. string.rep(' ', 88) .. '####')
    w(string.format('        -- ####   %-85s####', title))
    w('        -- ####' .. string.rep(' ', 88) .. '####')
    w(bar)
    w(bar)
end

local function serialize_items(data)
    local out = {}
    local function w(line) out[#out + 1] = line end

    w('-- GardenHelper item table (' .. items_file_name() .. ') - YOUR settings, bag order and items.')
    w('-- Which file is used: characters.lua item_table (blank = ItemTable.lua).')
    w('-- One list for everything: //gh sell, drop, pop, send, rec, org (and //gh inv = all of them).')
    w('--')
    w('-- Edit freely: GardenHelper re-reads this file before every step, so no reload is needed.')
    w('-- Only //gh pop (when it adds new items) and //gh inv rebuild (re-sorts it after your edits)')
    w('-- rewrite this file - values you change are kept, comments you add yourself are not')
    w('-- (the previous version is saved as backup/ItemTable.lua.bak).')
    w('-- Mail tracking and step results live in Mail.lua, so the other steps never write this file.')
    w('-- If this file has a Lua syntax error, GardenHelper stops with an error and leaves it alone.')
    w('--')
    w('-- ITEM FIELDS    [id] = {name, type, action, mail_to, min_mail, min_save, mail_cap, store_bag, PullFromBags}')
    w('--   id / name = the item id and its name (//gh pop fills both in).')
    w('--   type      = grouping only - each action section is sorted into these groups (TYPES below).')
    w('--   action    = what happens to the item. The table is sorted by action, then type, then name:')
    w('--       ""       new - //gh pop adds items with a blank action at the top. Nothing is done with')
    w('--                them until you give them an action.')
    w('--       "save"   keep it. min_save > 0: the copies above min_save (every bag counted) are')
    w('--                mailed to mail_to by //gh send, or - no mail_to - sold by //gh sell')
    w('--                (only copies in main inventory, unless PullFromBags = true).')
    w('--                min_save = 0 = keep every copy.')
    w('--       "send"   //gh send mails it to mail_to once there are min_mail of it in main inventory')
    w('--                (min_save > 0: that many are kept back). PullFromBags = true: every bag')
    w('--                counted, and copies in the other bags are pulled into main inventory first.')
    w('--       "ignore" never sold, dropped, mailed or moved.')
    w('--       "sell"   //gh sell sells every copy in main inventory to the Green Thumb Moogle')
    w('--                (PullFromBags = true: every copy in every bag).')
    w('--       "drop"   //gh drop drops every copy in main inventory and passes it in the treasure')
    w('--                pool (PullFromBags = true: every copy in every bag). settings.auto_drop: also')
    w('--                done by itself the moment one lands in main inventory / drops.')
    w('--   mail_to   = character //gh send mails it to (yours or anyone else\'s). "" = never mailed.')
    w('--   min_mail  = mail once there are at least this many. At the stack size (default for new items):')
    w('--               only full stacks are mailed. Below it (e.g. 1): partial stacks go too.')
    w('--   min_save  = how many to keep (every bag counted). 0 = no limit (keep all).')
    w('--   mail_cap  = most copies mail_to should end up with (its findAll bags + mail still in its')
    w('--               Delivery Box). Once it has that many, //gh sell sells the extra instead of')
    w('--               mailing it; short of it, only the shortfall is mailed. 0 = ignored (no cap).')
    w('--               No findAll file for mail_to = unknown, so everything is mailed as usual.')
    w('--   store_bag = where //gh org puts it (action "save", or "send" on its mail_to character):')
    w('--       ""          not organized - it stays wherever it is.')
    w('--       a bag name  moved out of main inventory into that bag (PullFromBags = true: also')
    w('--                   gathered out of every other bag into it).')
    w('--       "bag_order" moved out of main inventory only, into the first bag_order bag with room.')
    w('--       "inventory" kept in main inventory (PullFromBags = true: pulled out of every other')
    w('--                   bag into main inventory too).')
    w('--   PullFromBags = false (default): //gh send, sell, drop and org only use the copies in main')
    w('--               inventory - the other bags are left alone.')
    w('--               true: the copies in the other bags (case, satchel, sack, wardrobes; Mog House')
    w('--               bags when they can be reached) are pulled into main inventory first, and every')
    w('--               bag counts toward min_mail.')
    w('--')
    w('-- PER-CHARACTER OVERRIDES    ["id:Character"] = {...}')
    w('--   A line keyed "id:Character" (e.g. ["4304:FishVFi"]) is used for that item on that character')
    w('--   instead of the [id] line; every other character uses the [id] line. Any field the override')
    w('--   line leaves out comes from the [id] line. One override line per character per item;')
    w('--   //gh inv rebuild keeps them right under their [id] line.')
    w('--')
    w('-- ACCEPTED BAG VALUES (store_bag = "..." and bag_order)')
    w('--   ' .. INV_BAG_VALUE_LIST .. ', bag_order (store_bag only)')
    w('--   (safe, safe2, storage and locker are Mog House bags; wardrobes only hold equipment)')
    w('--')
    w('-- TYPES (each action section is grouped in this order; any other type follows A-Z)')
    for _, t in ipairs(INV_TYPE_ORDER) do
        w(string.format('--   %-17s %s', t, INV_TYPE_DESCRIPTIONS[t] or ''))
    end
    w('')
    w('return {')
    w('    settings = {')
    w('        -- true: //gh send and //gh rec only LOG what they would do. Set false to mail for real.')
    w('        mail_dry_run = ' .. tostring(data.settings.mail_dry_run ~= false) .. ',')
    w('        -- true: //gh sell only LOGS what it would sell (still visits the moogle).')
    w('        sell_dry_run = ' .. tostring(data.settings.sell_dry_run == true) .. ',')
    w('        -- true: //gh drop (and auto_drop) only LOG what they would drop / pass.')
    w('        drop_dry_run = ' .. tostring(data.settings.drop_dry_run == true) .. ',')
    w('        -- true: action = "drop" items are dropped the moment they land in main inventory and')
    w('        -- passed the moment they hit the treasure pool (off by default).')
    w('        auto_drop = ' .. tostring(data.settings.auto_drop == true) .. ',')
    w('        -- Characters the whole inventory process skips (lowercase).')
    local skips = {}
    for _, n in ipairs(data.settings.skip_characters or {}) do table.insert(skips, lua_str(tostring(n):lower())) end
    w('        skip_characters = {' .. table.concat(skips, ', ') .. '},')
    local known_settings = {mail_dry_run = true, sell_dry_run = true, drop_dry_run = true, auto_drop = true, skip_characters = true}
    local extra = {}
    for k in pairs(data.settings) do
        if not known_settings[k] and type(data.settings[k]) ~= 'table' then table.insert(extra, tostring(k)) end
    end
    table.sort(extra)
    for _, k in ipairs(extra) do
        w('        ' .. k .. ' = ' .. lua_val(data.settings[k]) .. ',')
    end
    w('    },')
    w('')
    w('    -- Bags for store_bag = "bag_order" - first bag with room wins.')
    local order = {}
    for _, b in ipairs(data.bag_order) do table.insert(order, lua_str(b)) end
    w('    bag_order = {' .. table.concat(order, ', ') .. '},')
    w('')
    w('    items = {')

    -- Sort by action (ACTION_ORDER), then type (INV_TYPE_ORDER, then any
    -- other type A-Z, then no type), then name.
    local type_rank = {}
    for i, t in ipairs(INV_TYPE_ORDER) do type_rank[t:lower()] = i end
    local ids = {}
    for id, e in pairs(data.items) do
        if type(e) == 'table' then table.insert(ids, id) end
    end
    local function trank(e)
        local t = tostring(e.type or '')
        if t == '' then return 1000 end
        return type_rank[t:lower()] or 500
    end
    -- An override line ["id:Character"] sorts (and is grouped) with its
    -- [id] line, right under it; one without an [id] line sorts by itself.
    local function sort_entry(id)
        local bid = override_key(id)
        if bid and type(data.items[bid]) == 'table' then return data.items[bid], bid end
        return data.items[id], bid or id
    end
    table.sort(ids, function(a, b)
        local ea, ia = sort_entry(a)
        local eb, ib = sort_entry(b)
        local aa, ab = ACTION_RANK[item_action(ea)], ACTION_RANK[item_action(eb)]
        if aa ~= ab then return aa < ab end
        local ra, rb = trank(ea), trank(eb)
        if ra ~= rb then return ra < rb end
        local ta, tb = tostring(ea.type or ''):lower(), tostring(eb.type or ''):lower()
        if ta ~= tb then return ta < tb end
        local na, nb = tostring(ea.name or ''):lower(), tostring(eb.name or ''):lower()
        if na ~= nb then return na < nb end
        if ia ~= ib then return tostring(ia) < tostring(ib) end
        local oa, ob = override_key(a) ~= nil, override_key(b) ~= nil
        if oa ~= ob then return ob end
        return tostring(a):lower() < tostring(b):lower()
    end)
    local last_action, last_type = nil, nil
    for _, id in ipairs(ids) do
        local e = data.items[id]
        local is_override = override_key(id) ~= nil
        local se = sort_entry(id)
        local action = item_action(se)
        if action ~= last_action then
            action_banner(w, action)
            last_action, last_type = action, nil
        end
        local type_label = tostring(se.type or '')
        if type_label ~= last_type then
            w('')
            w('        -- ---- ' .. (type_label == '' and '(no type yet - fill these in)' or type_label) .. ' ----')
            last_type = type_label
        end
        local parts = {}
        for _, k in ipairs(ITEM_FIELD_ORDER) do
            local v = e[k]
            if k == 'action' and (v ~= nil or not is_override) then v = item_action(e) end
            if k == 'PullFromBags' and v ~= nil then v = (v == true or trim_lower(v) == 'true') end
            if v == nil and not is_override then v = ITEM_FIELD_DEFAULTS[k] end
            -- override lines only write the fields they have (the rest
            -- comes from the [id] line)
            if v ~= nil then table.insert(parts, k .. ' = ' .. lua_val(v)) end
        end
        local extra_fields = {}
        for k, v in pairs(e) do
            if type(k) == 'string' and ITEM_FIELD_DEFAULTS[k] == nil and type(v) ~= 'table' then
                table.insert(extra_fields, k)
            end
        end
        table.sort(extra_fields)
        for _, k in ipairs(extra_fields) do
            table.insert(parts, k .. ' = ' .. lua_val(e[k]))
        end
        local key = type(id) == 'number' and ('[' .. id .. ']') or ('[' .. lua_str(id) .. ']')
        w(string.format('        %-8s = {%s},', key, table.concat(parts, ', ')))
    end
    w('    },')
    w('}')
    return table.concat(out, '\n') .. '\n'
end

local function serialize_mail(data)
    local out = {}
    local function w(line) out[#out + 1] = line end

    w('-- ' .. 'GardenHelper mail + status file (Mail.lua) - MANAGED BY INV (inv.lua).')
    w('--')
    w('-- Rewritten after every send / rec and every step\'s result, so you normally never open it.')
    w('-- Your settings, bag order and items are in ItemTable.lua.')
    w('-- Only edit this to fix mail tracking by hand, and not while GardenHelper is running a step.')
    w('-- Previous version = backup/Mail.lua.bak. If this file has a Lua syntax error, GardenHelper stops')
    w('-- with an error and leaves it alone.')
    w('')
    w('return {')
    w('    -- Stacks mailed but not yet received, per receiving character.')
    w('    -- //gh rec removes entries as they arrive.')
    w('    mail = {')
    local receivers = {}
    for name in pairs(data.mail) do table.insert(receivers, name) end
    table.sort(receivers)
    for _, name in ipairs(receivers) do
        local list = data.mail[name]
        if type(list) == 'table' and #list > 0 then
            w('        [' .. lua_str(name:lower()) .. '] = {')
            for _, m in ipairs(list) do
                local misses = tonumber(m.misses) or 0
                w(string.format('            {id = %s, name = %s, count = %s, from = %s, sent = %s%s},',
                    tostring(tonumber(m.id) or 0), lua_str(m.name), tostring(tonumber(m.count) or 0),
                    lua_str(m.from), lua_str(m.sent), misses > 0 and (', misses = ' .. misses) or ''))
            end
            w('        },')
        end
    end
    w('    },')
    w('')
    w('    -- Last result of each step per character (//gh status I column).')
    w('    status = {')
    local snames = {}
    for name in pairs(data.status) do table.insert(snames, name) end
    table.sort(snames)
    for _, name in ipairs(snames) do
        local s = data.status[name]
        if type(s) == 'table' then
            local parts = {}
            for _, step in ipairs(STEPS) do
                if s[step] then table.insert(parts, step .. ' = ' .. lua_str(s[step])) end
                if s[step .. '_error'] and s[step .. '_error'] ~= '' then
                    table.insert(parts, step .. '_error = ' .. lua_str(s[step .. '_error']))
                end
            end
            if s.at then table.insert(parts, 'at = ' .. lua_str(s.at)) end
            w('        [' .. lua_str(name:lower()) .. '] = {' .. table.concat(parts, ', ') .. '},')
        end
    end
    w('    },')
    w('}')
    return table.concat(out, '\n') .. '\n'
end

-- Writes text to path via path.tmp, moving the old file to bak (in the
-- backup folder).
-- The text must load back as Lua first, or nothing is touched.
local function write_table_file(path, label, text, bak)
    local check_fn, check_err = loadstring(text)
    if not check_fn then
        return false, 'internal error building ' .. label .. ' (' .. tostring(check_err) .. ') - file NOT changed.'
    end
    local tmp = path .. '.tmp'
    local f = io.open(tmp, 'w')
    if not f then
        return false, 'could not write ' .. tmp
    end
    f:write(text)
    f:close()
    os.remove(bak)
    if file_exists(path) then
        if not os.rename(path, bak) then
            -- backup folder not writable: keep going without a .bak
            -- rather than leave the old copy next to the live file.
            os.remove(path)
        end
    end
    local ok, err = os.rename(tmp, path)
    if not ok then
        return false, 'could not replace ' .. label .. ' (' .. tostring(err) .. ') - new version left at ' .. tmp
    end
    return true
end

local function write_items(data)
    local name = items_file_name()
    return write_table_file(items_file_path(), name, serialize_items(data), backup_path_for(name))
end

local function write_mail(data)
    return write_table_file(mail_file_path(), MAIL_FILE_NAME, serialize_mail(data), backup_path_for(MAIL_FILE_NAME))
end

-- ItemTable.lua as a table, or nil + error text. Missing = defaults
-- (written out by the first pop that adds something).
-- load_items_raw: the file as written, override lines included - for
-- pop and rebuild, which write it back.
local function load_items_raw()
    local data, err, missing = load_table_file(items_file_path(), items_file_name())
    if missing then return items_default_data() end
    if not data then return nil, err end
    return normalize_items(data)
end

-- load_items: what the steps use - this character's override lines
-- applied, every override line taken out (v4.12.0).
local function load_items()
    local data, err = load_items_raw()
    if not data then return nil, err end
    return apply_overrides(data, current_character_lower())
end

-- Mail.lua as a table, or nil + error text. Missing = empty.
local function load_mail()
    local data, err, missing = load_table_file(mail_file_path(), MAIL_FILE_NAME)
    if missing then return mail_default_data() end
    if not data then return nil, err end
    return normalize_mail(data)
end


-- Both files merged into one table (settings, bag_order, items,
-- mail, status) - what every step and the public API read. A file that
-- exists but won't load is an ERROR - never replaced, so edits aren't lost.
local function inv_load()
    local items, err = load_items()
    if not items then return nil, err end
    local mail, merr = load_mail()
    if not mail then return nil, merr end
    items.mail = mail.mail
    items.status = mail.status
    return items
end

-- Load ItemTable.lua fresh, apply fn(data), write it back. fn may
-- return false to skip the write. Only pop uses this.
local function inv_update_items(fn)
    local data, err = load_items_raw()
    if not data then return false, err end
    if fn(data) == false then return true end
    return write_items(data)
end

-- Load Mail.lua fresh, apply fn(data) (data.mail / data.status), write
-- it back. fn may return false to skip the write. Never touches
-- ItemTable.lua, so an item-table edit can't collide with it.
local function inv_update_mail(fn)
    local data, err = load_mail()
    if not data then return false, err end
    if fn(data) == false then return true end
    return write_mail(data)
end

local function inv_record_status(name, step, ok, message)
    if not name then return end
    local wrote, err = inv_update_mail(function(data)
        data.status[name] = data.status[name] or {}
        data.status[name][step] = ok and 'D' or 'E'
        data.status[name][step .. '_error'] = ok and '' or (message or 'error')
        data.status[name].at = os.date('%Y-%m-%d %H:%M:%S')
    end)
    if not wrote then error_log('Inventory: could not save status - ' .. tostring(err)) end
end

local function is_skipped_character(data, name)
    for _, n in ipairs(data.settings.skip_characters or {}) do
        if tostring(n):lower() == name then return true end
    end
    return false
end

local function sort_bag(bag_id)
    local ok, p = pcall(packets.new, 'outgoing', 0x03A, {['Bag'] = bag_id})
    if ok and p then
        packets.inject(p)
    end
end

local function inv_items(bag_id)
    local items = windower.ffxi.get_items(bag_id)
    if type(items) ~= 'table' then return nil end
    return items
end

local function bag_free_slots(bag_id)
    local items = inv_items(bag_id)
    if not items or items.enabled == false then return 0 end
    local max = tonumber(items.max) or 0
    local used = 0
    for i = 1, max do
        local it = items[i]
        if it and it.id and it.id ~= 0 then used = used + 1 end
    end
    return math.max(max - used, 0)
end
-- Item ids this character must keep in main inventory: its furrow
-- fertilizer and node fertilizers (gh.protected_item_names; the active
-- seed is not protected since v4.16.0).
-- Never sold, dropped, mailed or moved.
local function protected_item_ids()
    local ids = {}
    for _, name in ipairs(gh.protected_item_names()) do
        local r = res.items:with('name', name)
        if r then ids[r.id] = true end
    end
    return ids
end

local function num(v, default)
    v = tonumber(v)
    if v == nil then return default end
    return math.max(math.floor(v), 0)
end

-- mail_to of an entry, lowercase, no spaces ("" = none).
local function entry_mail_to(e)
    return trim_lower(e and e.mail_to)
end

-- PullFromBags of an entry (v4.11.0). true: send / sell / drop pull its
-- copies out of the other bags into main inventory first (and send counts
-- every bag toward min_mail). false / missing (the default): they only
-- use the copies already in main inventory.
local function pulls_from_bags(e)
    local v = e and e.PullFromBags
    return v == true or trim_lower(v) == 'true'
end

-- Main-inventory stacks that can be handled (status 0 = not equipped /
-- in bazaar): totals {id = count} and slots {id = {{index, count}, ...}}.
local function main_inventory_stacks()
    local items = inv_items(0)
    if not items then return nil end
    local totals, slots = {}, {}
    for i = 1, (tonumber(items.max) or 80) do
        local it = items[i]
        if it and it.id and it.id ~= 0 and (it.status or 0) == 0 then
            totals[it.id] = (totals[it.id] or 0) + (it.count or 0)
            slots[it.id] = slots[it.id] or {}
            table.insert(slots[it.id], {index = i, count = it.count or 0})
        end
    end
    return totals, slots
end

-- Every copy of every item across main inventory and all other bags
-- (what min_save counts). Switched-off bags are left out.
local function all_bag_totals()
    local totals = {}
    local function add_bag(bag_id)
        local items = inv_items(bag_id)
        if not items or items.enabled == false then return end
        for i = 1, (tonumber(items.max) or 0) do
            local it = items[i]
            if it and it.id and it.id ~= 0 then
                totals[it.id] = (totals[it.id] or 0) + (it.count or 0)
            end
        end
    end
    add_bag(0)
    for _, b in ipairs(INV_SEARCH_BAGS) do add_bag(INV_BAG_IDS[b]) end
    return totals
end

-- Pulls item id out of the other bags into main inventory until `need`
-- more are there (partial stacks are split off), its store_bag last.
-- unusable = {bag = true} for bags a move already failed in this run.
-- Returns how many were pulled.
local move_to_inventory  -- defined with org below
local function pull_into_inventory(id, need, last_bag, unusable, label)
    local pulled = 0
    local order = {}
    for _, b in ipairs(INV_SEARCH_BAGS) do
        if b ~= last_bag then table.insert(order, b) end
    end
    if last_bag and INV_BAG_IDS[last_bag] and last_bag ~= 'inventory' then table.insert(order, last_bag) end
    for _, src in ipairs(order) do
        if need - pulled <= 0 or inv_should_stop() then break end
        if not unusable[src] then
            local items = inv_items(INV_BAG_IDS[src])
            if items and items.enabled ~= false then
                for i = 1, (tonumber(items.max) or 0) do
                    if need - pulled <= 0 then break end
                    local it = items[i]
                    if it and it.id == id and (it.status or 0) == 0 then
                        if bag_free_slots(0) <= 0 then
                            log('Inventory ' .. label .. ': main inventory full - could not pull more ' .. (res.items[id] and res.items[id].en or id) .. ' out of ' .. src .. '.')
                            return pulled
                        end
                        local take = math.min(it.count or 0, need - pulled)
                        if move_to_inventory(INV_BAG_IDS[src], i, take) then
                            pulled = pulled + take
                            log('Inventory ' .. label .. ': pulled ' .. (res.items[id] and res.items[id].en or id) .. ' x' .. take .. ' out of ' .. src .. '.')
                            coroutine.sleep(config.org_move_delay_seconds)
                        else
                            unusable[src] = true
                            break
                        end
                    end
                end
            end
        end
    end
    return pulled
end

---------------------------------------------------------------------
-- //gh pop
---------------------------------------------------------------------
-- mail_to for an item pop adds: the character every existing item of the
-- same type is mailed to, when they all agree; otherwise "" (fill it in).
local function guess_mail_to(data, item_type)
    item_type = tostring(item_type or ''):lower()
    if item_type == '' then return '' end
    local found = nil
    for k, e in pairs(data.items) do
        if type(e) == 'table' and not override_key(k) and tostring(e.type or ''):lower() == item_type then
            local m = tostring(e.mail_to or '')
            if m == '' then return '' end
            if found and found:lower() ~= m:lower() then return '' end
            found = found or m
        end
    end
    return found or ''
end

local function inv_populate(me)
    local items = inv_items(0)
    if not items then
        return false, 'could not read main inventory'
    end
    local added = {}
    local ok, err = inv_update_items(function(data)
        for i = 1, (tonumber(items.max) or 80) do
            local it = items[i]
            if it and it.id and it.id ~= 0 and not data.items[it.id] then
                local r = res.items[it.id]
                if r then
                    local item_type = infer_item_type(r)
                    local e = {
                        name = r.en,
                        type = item_type,
                        action = '',
                        mail_to = guess_mail_to(data, item_type),
                        min_mail = default_min_mail(r.stack),
                        min_save = 0,
                        mail_cap = 0,
                        store_bag = '',
                        PullFromBags = false,
                    }
                    data.items[it.id] = e
                    table.insert(added, r.en .. (e.type ~= '' and (' (' .. e.type .. ')') or ' (no type)')
                        .. (e.mail_to ~= '' and (' -> ' .. e.mail_to) or ''))
                end
            end
        end
        if #added == 0 then return false end
    end)
    if not ok then return false, err end
    if #added == 0 then
        log('Inventory pop: nothing new in main inventory.')
    else
        log('Inventory pop: added ' .. #added .. ' item(s) to ItemTable.lua with action = "" (top of the file - review them): ' .. table.concat(added, ', '))
    end
    return true
end

---------------------------------------------------------------------
-- Delivery Box packets
-- Outgoing 0x04D (0x20 bytes): 04 Command, 05 BoxNo (1 in / 2 out /
-- -1 none), 06 PostWorkNo (box slot 0-7), 07 ItemWorkNo (inventory
-- slot), 08 ItemStacks (int32), 0C Result + 3 params (0), 10 name[16].
-- Incoming 0x04B: same first 12 bytes, 0C Result; full (0x58) packets
-- add 14 name[16], 30 item id, 38 count.
---------------------------------------------------------------------
local PBX = {
    WORK = 0x01, SET = 0x02, SEND = 0x03, CHECK = 0x05, RECV = 0x06,
    CONFIRM = 0x07, ACCEPT = 0x08, GET = 0x0A, QUERY = 0x0C,
    OPEN_SEND = 0x0D, OPEN_RECV = 0x0E, CLOSE = 0x0F,
}
local BOX_IN, BOX_OUT, BOX_NONE = 1, 2, -1
local GIL_ITEM_ID = 0xFFFF   -- gil in the box / main-inventory slot 0

local pbx = {listening = false, queue = {}, count = 0}  -- count = 0x04B packets seen while listening

local function le32(v)
    v = math.floor(tonumber(v) or 0)
    if v < 0 then v = v + 4294967296 end
    return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

local function rd_u32(d, o)
    local a, b, c, e = d:byte(o + 1, o + 4)
    if not e then return 0 end
    return a + b * 256 + c * 65536 + e * 16777216
end

local function s8(b)
    b = b or 255
    if b >= 128 then return b - 256 end
    return b
end

local function parse_pbx(d)
    local stacks = rd_u32(d, 0x08)
    if stacks >= 2147483648 then stacks = stacks - 4294967296 end
    local p = {
        cmd = d:byte(5) or 0,
        box = s8(d:byte(6)),
        post = s8(d:byte(7)),
        itemw = s8(d:byte(8)),
        stacks = stacks,
        result = d:byte(13) or 0,
        item = 0, count = 0, name = '',
    }
    if #d >= 0x3C then
        p.name = (d:sub(0x15, 0x24):gsub('%z.*$', ''))
        p.item = (d:byte(0x31) or 0) + (d:byte(0x32) or 0) * 256
        p.count = rd_u32(d, 0x38)
    end
    return p
end

local function describe_pbx(p)
    local s = string.format('cmd=%02X box=%d slot=%d iw=%d stk=%d res=%02X', p.cmd, p.box, p.post, p.itemw, p.stacks, p.result)
    if p.item ~= 0 then
        local r = res.items[p.item]
        s = s .. ' item=' .. (r and r.en or tostring(p.item)) .. ' x' .. p.count .. (p.name ~= '' and (' (' .. p.name .. ')') or '')
    end
    return s
end
-- v4.9.1: raw hex of a packet (first n bytes), for mail_debug.
local function pbx_hex(d, n)
    local t = {}
    for i = 1, math.min(#d, n or 32) do t[#t + 1] = string.format('%02X', d:byte(i)) end
    return table.concat(t, ' ')
end

-- v4.9.1 (mail_debug): every Delivery Box packet the GAME itself sends
-- (open the box by hand to compare with what GardenHelper injects).
windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
    if id ~= 0x04D or not config.mail_debug then return end
    inv_debug('PBX ' .. (injected and 'GH  ' or 'GAME') .. ' out raw (' .. #original .. 'b' .. (blocked and ', BLOCKED' or '') .. '): ' .. pbx_hex(original, 32))
end)

windower.register_event('incoming chunk', function(id, original)
    if id ~= 0x04B then return end
    local ok, p = pcall(parse_pbx, original)
    if config.mail_debug then
        -- v4.9.1: every 0x04B, even when GardenHelper isn't listening or it doesn't parse.
        inv_debug('PBX in raw (' .. #original .. 'b, ' .. (pbx.listening and 'listening' or 'NOT listening') .. '): ' .. pbx_hex(original, 16))
    end
    if not ok then return end
    if pbx.listening then
        pbx.count = pbx.count + 1
        table.insert(pbx.queue, p)
        inv_debug('PBX in:  ' .. describe_pbx(p))
    end
end)

local function pbx_send(cmd, box, post, itemw, stacks, name)
    name = tostring(name or '')
    name = name:sub(1, 15)
    local data = string.char(0x4D, 0x10, 0x00, 0x00, cmd, box % 256, post % 256, itemw % 256)
        .. le32(stacks) .. string.char(0, 0, 0, 0)
        .. name .. string.rep(string.char(0), 16 - #name)
    inv_debug(string.format('PBX out: cmd=%02X box=%d slot=%d iw=%d stk=%d%s', cmd, box, post, itemw, stacks, name ~= '' and (' name=' .. name) or ''))
    windower.packets.inject_outgoing(0x04D, data)
end

-- Waits for the first queued reply matching pred. Removes it and returns
-- it, or nil on timeout/stop.
local function pbx_wait(pred, timeout)
    local waited = 0
    timeout = timeout or config.mail_response_timeout_seconds
    while waited <= timeout do
        for i, p in ipairs(pbx.queue) do
            if pred(p) then
                table.remove(pbx.queue, i)
                return p
            end
        end
        if inv_should_stop() then return nil end
        coroutine.sleep(0.1)
        waited = waited + 0.1
    end
    return nil
end

-- Sends a command and waits for its FINAL reply (many PBX commands get
-- two replies: result 02 "in progress", then the real result).
local function pbx_call(cmd, box, post, itemw, stacks, name, match_slot)
    pbx.queue = {}
    pbx_send(cmd, box, post, itemw, stacks, name)
    return pbx_wait(function(p)
        if p.cmd ~= cmd or p.result == 0x02 then return false end
        if match_slot and p.post ~= post then return false end
        return true
    end)
end

local function pbx_close()
    pbx_call(PBX.CLOSE, BOX_NONE, -1, -1, -1)
    coroutine.sleep(config.mail_step_delay_seconds)
end

-- The outbox needs a few seconds after a Send / Confirm before the
-- slot really clears on the game's side; moving on sooner gave errors
-- (Mark, //ml humus 9/28). Returns false if stopped.
local function pbx_wait_seconds(seconds)
    local waited = 0
    seconds = tonumber(seconds) or 0
    while waited < seconds do
        if inv_should_stop() then return false end
        coroutine.sleep(0.1)
        waited = waited + 0.1
    end
    return true
end
local function pbx_after_send()
    return pbx_wait_seconds(config.mail_after_send_wait_seconds or 3)
end
local function pbx_after_confirm(delivered)
    if (delivered or 0) > 0 then
        return pbx_wait_seconds(config.mail_after_confirm_wait_seconds or 3)
    end
    return true
end
-- Before closing a box that sent something: let every sent stack
-- finish leaving before the close (and a logout right after it).
local function pbx_close_after_sends(any_sent)
    if any_sent then pbx_wait_seconds(config.mail_before_close_wait_seconds or 5) end
    pbx_close()
end

-- Opens the box (waits up to mail_open_timeout_seconds for the reply).
-- On failure a Close is sent anyway: a box that opens after we gave up
-- would otherwise stay open and block /logout (MuleLogger's keys then
-- went into the box - Woodvf 9/26 18:25, 9/27 15:38).
local function pbx_open_once(cmd)
    pbx.queue = {}
    pbx_send(cmd, BOX_NONE, -1, -1, -1)
    local p = pbx_wait(function(r)
        return r.cmd == cmd and r.result ~= 0x02
    end, config.mail_open_timeout_seconds or 10)
    if p ~= nil and p.result == 0x01 then
        return true
    end
    -- v4.9.0: why, for the log lines (answered with a result code, or silent).
    pbx.last_open_fail = p and string.format('the box answered result %02X', p.result) or ('no reply from the server within ' .. (config.mail_open_timeout_seconds or 10) .. 's')
    inv_debug('PBX open failed (' .. pbx.last_open_fail .. ') - sending Close in case it opens late')
    pbx_close()
    return false
end

-- A box that won't open right after the last one closed ("Please try
-- again in a little while" - Woodvf 9/28 22:48, rec right after send)
-- is tried again after mail_open_retry_wait_seconds (5), up to
-- mail_open_retries (2) more times (v4.6.3).
local function pbx_open(cmd)
    local tries = 0
    while true do
        if pbx_open_once(cmd) then return true end
        tries = tries + 1
        if tries > (config.mail_open_retries or 2) or inv_should_stop() then return false end
        log('Delivery Box did not open (' .. tostring(pbx.last_open_fail) .. ') - trying again in ' .. (config.mail_open_retry_wait_seconds or 5) .. 's (retry ' .. tries .. ').')
        if not pbx_wait_seconds(config.mail_open_retry_wait_seconds or 5) then return false end
    end
end

-- After the box opens, the game's own box window runs its own
-- Work/Check/Recv. Instead of a flat wait, this returns as soon as no
-- Delivery Box packet has come in for mail_open_quiet_seconds (default
-- 1), and never waits longer than mail_open_settle_seconds (3).
-- Returns false if stopped.
local function pbx_settle()
    local max_wait = config.mail_open_settle_seconds or 3
    local quiet = config.mail_open_quiet_seconds or 1
    if quiet > max_wait then quiet = max_wait end
    local waited, quiet_for, last_count = 0, 0, pbx.count
    while waited < max_wait do
        if inv_should_stop() then return false end
        coroutine.sleep(0.1)
        waited = waited + 0.1
        if pbx.count ~= last_count then
            last_count = pbx.count
            quiet_for = 0
        else
            quiet_for = quiet_for + 0.1
            if quiet_for >= quiet then break end
        end
    end
    inv_debug(string.format('PBX settle: box quiet after %.1fs', waited))
    return not inv_should_stop()
end

-- Reads the box's 8 visible slots: slots[0..7] = {item, count, name}.
local function pbx_work(box)
    pbx.queue = {}
    pbx_send(PBX.WORK, box, -1, -1, -1)
    local slots, seen = {}, 0
    for i = 0, 7 do slots[i] = {item = 0, count = 0, name = ''} end
    local waited = 0
    local seen_slot = {}
    local last_new = 0   -- when the last new slot reply came in
    local quiet = config.mail_open_quiet_seconds or 1
    while waited <= config.mail_response_timeout_seconds and seen < 8 do
        for i = #pbx.queue, 1, -1 do
            local p = pbx.queue[i]
            if p.cmd == PBX.WORK and p.post >= 0 and p.post <= 7 then
                slots[p.post] = {item = p.item, count = p.count, name = p.name}
                if not seen_slot[p.post] then
                    seen_slot[p.post] = true
                    seen = seen + 1
                    last_new = waited
                end
                table.remove(pbx.queue, i)
            end
        end
        if seen >= 8 or inv_should_stop() then break end
        -- Slot replies have stopped coming in: don't wait out the timeout.
        if seen > 0 and waited - last_new >= quiet then break end
        coroutine.sleep(0.1)
        waited = waited + 0.1
    end
    return slots, seen, seen_slot
end

-- How many items are waiting (inbox: queued new items that fit in the
-- free slots; outbox: sent items the receiver has already taken).
local function pbx_check(box)
    local p = pbx_call(PBX.CHECK, box, -1, -1, -1)
    if not p or p.result ~= 0x01 then return 0 end
    if p.post and p.post > 0 then return p.post end
    if p.stacks and p.stacks > 0 then return p.stacks end
    return 0
end

-- Free outbox slot numbers (0-7) from a pbx_work read. With seen_slot
-- (v4.6.3), a slot whose reply never came back is not counted as free.
local function pbx_free_slots(slots, seen_slot)
    local free = {}
    for i = 0, 7 do
        if slots[i].item == 0 and (seen_slot == nil or seen_slot[i]) then table.insert(free, i) end
    end
    return free
end

-- Clears the stacks the receivers already took out of the outbox and
-- WAITS until their slots are really empty before handing back the
-- slots. A received stack leaves the outbox one slot at a time.
-- v4.6.3: the game can confirm the received stacks by itself as the box
-- opens, so Check says 0 while all 8 slots are still emptying (Woodvf
-- 9/28 22:48 - v4.6.2 took that single read as final, the Set went
-- into slot 1 and the Send got EF "Communications seem to be
-- congested"). So now, confirmed here or not: Confirm what Check
-- reports, then keep re-reading all 8 slots until they are all empty,
-- or the used count has not dropped for mail_outbox_stable_seconds (5)
-- - what is left then is sent mail nobody has picked up yet. Capped at
-- mail_outbox_clear_timeout_seconds (60). A slot whose reply did not
-- come back counts as used (never handed out as free).
-- Returns slots, seen (like pbx_work), confirmed, seen_slot.
local function pbx_clear_outbox()
    local timeout = config.mail_outbox_clear_timeout_seconds or 60
    local poll = config.mail_outbox_clear_poll_seconds or 1
    local stable_needed = config.mail_outbox_stable_seconds or 5
    local function used(s, ss)
        local n = 0
        for i = 0, 7 do
            if s[i].item ~= 0 or not ss[i] then n = n + 1 end
        end
        return n
    end
    -- A read missing some slot replies is read again; if that keeps
    -- happening (3 reads in a row), the missing slots count as empty,
    -- like before v4.6.3, so it can't stall on them.
    local partial_reads = 0
    local function read()
        local s, n, ss = pbx_work(BOX_OUT)
        if n >= 8 then
            partial_reads = 0
        elseif n > 0 then
            partial_reads = partial_reads + 1
            if partial_reads >= 3 then
                inv_debug('PBX outbox clear: only ' .. n .. ' of 8 slot replies, 3 reads in a row - counting the missing ones as empty')
                for i = 0, 7 do ss[i] = true end
                n = 8
            end
        end
        return s, n, ss
    end
    local slots, seen, seen_slot = read()
    local start_used = seen >= 8 and used(slots, seen_slot) or nil
    local confirmed, waited = 0, 0
    local last_used, changed_at = nil, 0
    while not inv_should_stop() do
        local delivered = pbx_check(BOX_OUT)
        for _ = 1, delivered do
            if inv_should_stop() then break end
            pbx_call(PBX.CONFIRM, BOX_NONE, -1, -1, -1)
            coroutine.sleep(config.mail_step_delay_seconds)
            waited = waited + (config.mail_step_delay_seconds or 1)
        end
        confirmed = confirmed + delivered
        if delivered > 0 then
            if not pbx_after_confirm(delivered) then break end
            waited = waited + (config.mail_after_confirm_wait_seconds or 3)
            slots, seen, seen_slot = read()
        end
        local now_used = seen >= 8 and used(slots, seen_slot) or nil
        if now_used == 0 then
            inv_debug(string.format('PBX outbox clear: all 8 slots empty (%d confirmed here, %.0fs)', confirmed, waited))
            break
        end
        if now_used ~= nil then
            if start_used == nil then start_used = now_used + confirmed end
            if now_used ~= last_used or delivered > 0 then
                if last_used ~= nil then inv_debug('PBX outbox clear: ' .. now_used .. ' slot(s) still in use - waiting') end
                last_used, changed_at = now_used, waited
            end
            local enough = now_used <= math.max(start_used - confirmed, 0)
            if delivered == 0 and enough and waited - changed_at >= stable_needed then
                inv_debug('PBX outbox clear: ' .. now_used .. ' slot(s) still in use (sent, not picked up yet), unchanged for ' .. stable_needed .. 's')
                break
            end
        end
        if waited >= timeout then
            log('Outbox: slots still clearing after ' .. timeout .. 's - carrying on with the slots that are free.')
            break
        end
        if not pbx_wait_seconds(poll) then break end
        waited = waited + poll
        slots, seen, seen_slot = read()
    end
    return slots, seen, confirmed, seen_slot
end

-- Puts inventory slot itemw x count into the first free outbox slot
-- (free = list from pbx_free_slots, updated in place). If the game
-- refuses the slot (still clearing), waits mail_set_retry_wait_seconds
-- (3), clears/re-reads the outbox and tries again, up to
-- mail_set_retries (3) times. Returns slot, reply (slot nil = failed).
local function pbx_set_free_slot(free, itemw, count, to_proper, label)
    local tries = 0
    while true do
        if #free == 0 then return nil, nil end
        local slot = table.remove(free, 1)
        local setp = pbx_call(PBX.SET, BOX_OUT, slot, itemw, count, to_proper)
        if setp and setp.result == 0x01 then return slot, setp end
        table.insert(free, 1, slot)
        tries = tries + 1
        if tries > (config.mail_set_retries or 3) or inv_should_stop() then return nil, setp end
        log((label or 'Mail') .. ': outbox slot ' .. (slot + 1) .. ' not ready (result ' .. (setp and string.format('%02X', setp.result) or 'none') .. ') - waiting for the outbox to clear, retry ' .. tries .. '.')
        if not pbx_wait_seconds(config.mail_set_retry_wait_seconds or 3) then return nil, setp end
        local s2, seen2, _, ss2 = pbx_clear_outbox()
        if seen2 > 0 then
            for i = #free, 1, -1 do free[i] = nil end
            for _, f in ipairs(pbx_free_slots(s2, ss2)) do table.insert(free, f) end
        end
    end
end

-- Sends the stack in outbox slot. A Send the server turns down (EF
-- "Communications seem to be congested" while other slots are still
-- clearing - Woodvf 9/28 22:48) leaves the stack in its slot, so this
-- waits mail_set_retry_wait_seconds (3), clears/re-reads the outbox and
-- sends again, up to mail_send_retries (3) times (v4.6.3). No reply at
-- all is not retried (it may have gone). Returns the last reply.
local function pbx_send_slot(slot, label)
    local tries = 0
    while true do
        local sendp = pbx_call(PBX.SEND, BOX_OUT, slot, -1, -1)
        if not sendp or sendp.result == 0x01 then return sendp end
        tries = tries + 1
        if tries > (config.mail_send_retries or 3) or inv_should_stop() then return sendp end
        log((label or 'Mail') .. ': Send from outbox slot ' .. (slot + 1) .. ' refused (result ' .. string.format('%02X', sendp.result) .. ') - waiting for the outbox to clear, retry ' .. tries .. '.')
        if not pbx_wait_seconds(config.mail_set_retry_wait_seconds or 3) then return sendp end
        pbx_clear_outbox()
    end
end
---------------------------------------------------------------------
-- //gh send
---------------------------------------------------------------------
-- How many of item id (entry e) send should mail.
-- PullFromBags = false (default, v4.10.0 behavior): only main inventory
-- is mailed - copies in the other bags are left alone:
--   action "send": the main-inventory copies, less min_save.
--   action "save" with a mail_to and min_save > 0: the copies above
--     min_save (every bag counted toward min_save), at most what is
--     in main inventory.
-- PullFromBags = true (v4.11.0): every bag counted - "send": every copy
-- less min_save; "save": every copy above min_save. inv_plan_sends pulls
-- what isn't in main inventory yet.
-- Returns amount, or nil when the entry isn't mailed by this character.
local function send_allowance(e, me, main_total, all_total, pull)
    local action = item_action(e)
    local to = entry_mail_to(e)
    if to == '' or to == me then return nil end
    local min_save = num(e.min_save, 0)
    if action == 'send' then
        return math.max((pull and all_total or main_total) - min_save, 0)
    elseif action == 'save' and min_save > 0 then
        local extra = all_total - min_save
        if not pull then extra = math.min(main_total, extra) end
        return math.max(extra, 0)
    end
    return nil
end

-- mail_cap (v4.13.0): the most copies an item's mail_to should end up
-- with. What mail_to already has = its findAll file (addons/findAll/
-- data/<Name>.lua, main inventory + every other bag) + copies still in
-- its Delivery Box (Mail.lua, any sender). mail_room returns how many
-- more it can take (0 = it is full - sell finds them as extra), or nil
-- when there is no cap (mail_cap = 0) or no findAll file for mail_to
-- (unknown = mailed as usual). cache = {} shared over one plan.
local FINDALL_BAGS = {'inventory', 'case', 'satchel', 'sack', 'safe2', 'safe', 'storage', 'locker',
    'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8'}
local function findall_dir()
    local root = windower.windower_path
    if type(root) == 'string' and root ~= '' then
        if not root:match('[/\\]$') then root = root .. '/' end
        return root .. 'addons/findAll/data/'
    end
    return (windower.addon_path:gsub('GardenHelper[/\\]?$', 'findAll/')) .. 'data/'
end

local function findall_holdings(name, cache)
    if cache[name] ~= nil then return cache[name] or nil end
    local proper = tostring(name):lower():gsub('^%l', string.upper)
    local chunk = loadfile(findall_dir() .. proper .. '.lua')
    local out = false
    if chunk then
        local ok, t = pcall(chunk)
        if ok and type(t) == 'table' then
            out = {}
            for _, bag in ipairs(FINDALL_BAGS) do
                local b = t[bag]
                if type(b) == 'table' then
                    for id, n in pairs(b) do
                        id = tonumber(id)
                        if id then out[id] = (out[id] or 0) + (tonumber(n) or 0) end
                    end
                end
            end
        end
    end
    cache[name] = out
    return out or nil
end

local function mail_room(e, id, mail, cache)
    local cap = num(e and e.mail_cap, 0)
    if cap <= 0 then return nil end
    local to = entry_mail_to(e)
    if to == '' then return nil end
    local held = findall_holdings(to, cache)
    if not held then
        inv_debug('mail_cap: no findAll file for ' .. proper_name(to) .. ' - ' .. tostring(e.name or id) .. ' mailed as usual.')
        return nil
    end
    local have = held[id] or 0
    for _, m in ipairs(type(mail) == 'table' and type(mail[to]) == 'table' and mail[to] or {}) do
        if type(m) == 'table' and tonumber(m.id) == id then have = have + (tonumber(m.count) or 0) end
    end
    return math.max(cap - have, 0), have, cap
end

-- The stacks to mail: {index, id, count, name, to, to_proper}, from main
-- inventory. min_mail is the threshold: at or above a full stack only
-- full stacks go; below it, every stack (partial ones too) once the
-- amount reaches min_mail (main inventory counted, or every bag for
-- PullFromBags = true items).
-- PullFromBags = true items: do_pull pulls the copies sitting in other
-- bags into main inventory first (returns pulled = true, re-plan), at
-- most mail_pull_max_stacks (default 8 = one full outbox) stacks' worth
-- per item. Without do_pull (dry run / re-plan) the 4th value lists what
-- would be / still is in other bags.
local function inv_plan_sends(data, me, do_pull)
    local protected = protected_item_ids()
    local totals, slots = main_inventory_stacks()
    if not totals then return nil, 'could not read main inventory' end
    local all = all_bag_totals()
    local plan, pulled, unusable, elsewhere = {}, false, {}, {}
    local max_stacks = tonumber(config.mail_pull_max_stacks) or 8
    local cap_cache = {}
    local ids = {}
    for id in pairs(data.items) do table.insert(ids, id) end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    for _, id in ipairs(ids) do
        local e = data.items[id]
        if type(e) == 'table' and type(id) == 'number' and not protected[id] then
            local r = res.items[id]
            local stack = r and tonumber(r.stack) or 1
            local min_mail = num(e.min_mail, default_min_mail(stack))
            local in_main = totals[id] or 0
            local pull = pulls_from_bags(e)
            local amount = send_allowance(e, me, in_main, all[id] or in_main, pull)
            if amount and amount > 0 then
                -- mail_cap: never more than mail_to still has room for.
                local room, have, cap = mail_room(e, id, data.mail, cap_cache)
                if room and room < amount then
                    inv_debug('mail_cap: ' .. proper_name(entry_mail_to(e)) .. ' has ' .. have .. '/' .. cap .. ' '
                        .. tostring(e.name or id) .. ' - mailing ' .. room .. ' of ' .. amount .. '.')
                    amount = room
                end
            end
            if amount and amount > 0 and amount >= math.max(min_mail, 1) then
                local full_only = stack > 1 and min_mail >= stack
                -- Only whole stacks go when full_only (no remainder pulled).
                local want = amount
                if full_only then want = math.floor(amount / stack) * stack end
                if pull then
                    want = math.min(want, math.max(max_stacks, 1) * stack)
                    if want > in_main then
                        if do_pull then
                            if pull_into_inventory(id, want - in_main, valid_bag_name(e.store_bag), unusable, 'send') > 0 then
                                pulled = true
                            end
                        else
                            table.insert(elsewhere, {id = id, name = e.name or (r and r.en) or tostring(id), count = want - in_main})
                        end
                    end
                end
                local left = math.min(want, in_main)
                for _, sl in ipairs(slots[id] or {}) do
                    if left <= 0 then break end
                    local c = math.min(sl.count, left)
                    if not full_only or (sl.count == stack and c == stack) then
                        table.insert(plan, {
                            index = sl.index, id = id, count = c,
                            name = e.name or (r and r.en) or tostring(id),
                            to = entry_mail_to(e), to_proper = proper_name(entry_mail_to(e)),
                        })
                        left = left - c
                    end
                end
            end
        end
    end
    return plan, nil, pulled, elsewhere
end

local function inv_send(me)
    local data, err = inv_load()
    if not data then return false, err end
    local dry = data.settings.mail_dry_run ~= false

    -- Sort first so split stacks of the same item merge into full ones.
    sort_bag(0)
    if not inv_sleep(config.inventory_sort_wait_seconds) then return false, 'stopped' end

    local plan, perr, pulled, elsewhere = inv_plan_sends(data, me, not dry)
    if not plan then return false, perr end
    if pulled then
        -- PullFromBags copies came out of other bags: merge them, plan again.
        sort_bag(0)
        if not inv_sleep(config.inventory_sort_wait_seconds) then return false, 'stopped' end
        plan, perr = inv_plan_sends(data, me, false)
        if not plan then return false, perr end
    end
    if dry then
        if #plan == 0 and #(elsewhere or {}) == 0 then
            log('Inventory send: no items to mail.')
            return true
        end
        log('Inventory send (DRY RUN - settings.mail_dry_run in ItemTable.lua): would mail ' .. #plan .. ' stack(s) from main inventory:')
        for _, s in ipairs(plan) do
            log('  ' .. s.name .. ' x' .. s.count .. ' -> ' .. s.to_proper)
        end
        for _, x in ipairs(elsewhere or {}) do
            log('  + would pull ' .. x.name .. ' x' .. x.count .. ' out of the other bags (PullFromBags) and mail it too')
        end
        return true
    end
    if #plan == 0 then
        log('Inventory send: no items to mail.')
        return true
    end

    local errors = {}
    local sent = {}
    pbx.listening = true
    pbx.queue = {}

    if not pbx_open(PBX.OPEN_SEND) then
        pbx.listening = false
        return false, 'the Delivery Box (send) did not open (' .. tostring(pbx.last_open_fail) .. ')'
    end
    -- The game's own box window runs its own Work/Check/Recv
    -- as soon as the box opens - let that finish before reading slots.
    if not pbx_settle() then
        pbx_close()
        pbx.listening = false
        return false, 'stopped'
    end

    -- Clear stacks the receivers already took, and wait until their
    -- slots really are free.
    local slots, seen, _, seen_slot = pbx_clear_outbox()
    if seen == 0 then
        pbx_close()
        pbx.listening = false
        return false, 'could not read the outbox slots'
    end
    local free = pbx_free_slots(slots, seen_slot)

    local name_ok = {}
    for n, s in ipairs(plan) do
        if inv_should_stop() then break end
        if #free == 0 then
            table.insert(errors, 'outbox full (sent stacks not received yet) - ' .. (#plan - n + 1) .. ' stack(s) left for next time')
            break
        end
        if name_ok[s.to] == nil then
            local q = pbx_call(PBX.QUERY, BOX_NONE, -1, -1, -1, s.to_proper)
            name_ok[s.to] = (q ~= nil and q.result == 0x01)
            if not name_ok[s.to] then
                table.insert(errors, 'recipient ' .. s.to_proper .. ' not accepted')
            end
            coroutine.sleep(config.mail_step_delay_seconds)
        end
        if name_ok[s.to] then
            local cur = windower.ffxi.get_items(0, s.index)
            if cur and cur.id == s.id and (cur.count or 0) >= s.count and cur.status == 0 then
                local slot, setp = pbx_set_free_slot(free, s.index, s.count, s.to_proper, 'Inventory send')
                if slot then
                    coroutine.sleep(config.mail_step_delay_seconds)
                    local sendp = pbx_send_slot(slot, 'Inventory send')
                    if sendp and sendp.result == 0x01 then
                        table.insert(sent, s)
                        log('Inventory send: mailed ' .. s.name .. ' x' .. s.count .. ' to ' .. s.to_proper .. '.')
                        pbx_after_send()
                    else
                        table.insert(errors, s.name .. ' to ' .. s.to_proper .. ' not sent (result ' .. (sendp and string.format('%02X', sendp.result) or 'none') .. ')')
                        -- Take it back out of the outbox so it isn't stuck there unsent.
                        pbx_call(PBX.GET, BOX_OUT, slot, -1, -1)
                    end
                else
                    table.insert(errors, s.name .. ' could not be put in the outbox (result ' .. (setp and string.format('%02X', setp.result) or 'none') .. ')')
                end
                coroutine.sleep(config.mail_step_delay_seconds)
            end
        end
    end

    pbx_close_after_sends(#sent > 0)
    pbx.listening = false
    if #sent > 0 then
        last_send_epoch = os.time()
        local ok, werr = inv_update_mail(function(d)
            for _, s in ipairs(sent) do
                d.mail[s.to] = d.mail[s.to] or {}
                table.insert(d.mail[s.to], {id = s.id, name = s.name, count = s.count, from = me, sent = os.date('%Y-%m-%d %H:%M')})
            end
        end)
        if not ok then table.insert(errors, 'mail tracking NOT saved: ' .. tostring(werr)) end
    end
    log('Inventory send: ' .. #sent .. ' stack(s) mailed.')
    if #errors > 0 then
        return false, table.concat(errors, '; ')
    end
    return true
end

---------------------------------------------------------------------
-- //gh rec
---------------------------------------------------------------------
local function inv_receive(me, force)
    local data, err = inv_load()
    if not data then return false, err end
    local pending = data.mail[me] or {}
    -- rec always takes EVERYTHING in the Delivery Box (mail sent by hand
    -- or by another addon isn't tracked); force is kept for old callers.
    force = true
    log('Inventory rec: ' .. #pending .. ' stack(s) tracked for ' .. proper_name(me) .. ' - opening the Delivery Box and taking everything in it.')
    if data.settings.mail_dry_run ~= false then
        log('Inventory rec (DRY RUN): would open the Delivery Box and take everything in it.')
        return true
    end

    -- The game needs 5-10s after sending before you can receive.
    local since_send = os.time() - last_send_epoch
    if since_send < config.mail_receive_after_send_wait_seconds then
        local wait = config.mail_receive_after_send_wait_seconds - since_send
        log('Inventory rec: waiting ' .. wait .. 's after sending before opening the inbox...')
        if not inv_sleep(wait) then return false, 'stopped' end
    end

    local errors = {}
    local received = {}
    pbx.listening = true
    pbx.queue = {}
    if not pbx_open(PBX.OPEN_RECV) then
        pbx.listening = false
        return false, 'the Delivery Box (receive) did not open (' .. tostring(pbx.last_open_fail) .. ')'
    end
    -- The game's own box window pulls new mail into the empty
    -- slots by itself right after opening (its Recv
    -- filled slot 0 while ours was still reading) - wait for that first
    -- (until the box goes quiet, not a flat wait).
    if not pbx_settle() then
        pbx_close()
        pbx.listening = false
        return false, 'stopped'
    end

    local inv_full = false
    local box_emptied = false   -- a round found nothing left in the box
    for round = 1, config.mail_receive_max_rounds do
        if inv_should_stop() or inv_full then break end
        local slots = pbx_work(BOX_IN)

        -- Pull queued items (beyond the 8 visible) into the empty slots.
        -- If the server's count doesn't come back, fall back to what the
        -- tracking says is still on the way.
        local waiting = pbx_check(BOX_IN)
        if waiting <= 0 then
            local visible = 0
            for i = 0, 7 do
                if slots[i].item ~= 0 then visible = visible + 1 end
            end
            waiting = math.max(#pending - #received - visible, 0)
            -- A forced receive doesn't trust the tracking -
            -- mail sent by hand or from another addon isn't in it. If the
            -- server didn't give a count, try pulling into the empty
            -- slots on the first round; the first pull that brings
            -- nothing ends it (see below), so an empty queue costs one try.
            if force and round == 1 then waiting = 8 end
        end
        local pulled = false
        for i = 0, 7 do
            if waiting <= 0 or inv_should_stop() then break end
            if slots[i].item == 0 then
                local r = pbx_call(PBX.RECV, BOX_IN, i, 1, -1, nil, true)
                if r and (r.result == 0x01 or r.result == 0xF0) then
                    -- 01 = an item came in. F0 = that slot was already
                    -- filled (by the game's own window) - the re-read
                    -- below picks it up.
                    pulled = true
                    waiting = waiting - 1
                    coroutine.sleep(config.mail_step_delay_seconds)
                else
                    -- Nothing came in: the queue is empty, so don't try
                    -- the other empty slots.
                    inv_debug('PBX rec: pull into slot ' .. (i + 1) .. ' brought nothing (result '
                        .. (r and string.format('%02X', r.result) or 'none') .. ') - nothing queued')
                    break
                end
            end
        end

        -- Always re-read the 8 slots after pulling, instead of
        -- trusting what was read before (the thread
        -- landed in slot 0 through the game's own pull, our Recv got F0,
        -- the stale read still said "empty", so nothing was taken).
        if pulled then
            coroutine.sleep(config.mail_step_delay_seconds)
            slots = pbx_work(BOX_IN)
        end

        local got = 0
        for i = 0, 7 do
            if inv_should_stop() then break end
            if slots[i].item ~= 0 then
                if slots[i].item ~= GIL_ITEM_ID and bag_free_slots(0) <= 0 then
                    table.insert(errors, 'main inventory full - mail left in the box')
                    inv_full = true
                    break
                end
                pbx_call(PBX.ACCEPT, BOX_IN, i, -1, -1, nil, true)
                coroutine.sleep(config.mail_step_delay_seconds)
                local g = pbx_call(PBX.GET, BOX_IN, i, -1, -1, nil, true)
                if g and g.result == 0x01 then
                    got = got + 1
                    local r = slots[i].item == GIL_ITEM_ID and {en = 'Gil'} or res.items[slots[i].item]
                    table.insert(received, {id = slots[i].item, count = slots[i].count, from = slots[i].name:lower()})
                    log('Inventory rec: received ' .. (r and r.en or tostring(slots[i].item)) .. ' x' .. slots[i].count .. (slots[i].name ~= '' and (' from ' .. slots[i].name) or '') .. '.')
                elseif g and g.result == 0xB9 then
                    table.insert(errors, 'main inventory full - mail left in the box')
                    inv_full = true
                    break
                else
                    table.insert(errors, 'box slot ' .. (i + 1) .. ' not received (result ' .. (g and string.format('%02X', g.result) or 'none') .. ')')
                end
                coroutine.sleep(config.mail_step_delay_seconds)
            end
        end

        if got == 0 then
            box_emptied = not inv_should_stop()
            break
        end
        -- A box that wasn't full (fewer than 8 stacks) has nothing
        -- queued behind it: done. A full one gets checked again.
        local visible = 0
        for i = 0, 7 do
            if slots[i].item ~= 0 then visible = visible + 1 end
        end
        if visible < 8 and got >= visible and #errors == 0 then
            box_emptied = not inv_should_stop()
            break
        end
        log('Inventory rec: the Delivery Box was full (8 stacks) - checking it again for more...')
        if round < config.mail_receive_max_rounds then
            if not inv_sleep(config.mail_receive_round_wait_seconds) then break end
        end
    end

    pbx_close()
    pbx.listening = false

    -- Stale tracking: the box was emptied with no errors, yet entries are
    -- still tracked as on the way. Each such receive adds a miss to every
    -- entry older than mail_stale_min_age_minutes; mail_stale_misses (2)
    -- misses = the entry was a mistake and is removed.
    local check_stale = box_emptied and #errors == 0
    local stale_limit = tonumber(config.mail_stale_misses) or 2
    local min_age = (tonumber(config.mail_stale_min_age_minutes) or 10) * 60
    local now = os.time()
    local function sent_epoch(m)
        local y, mo, d, h, mi = tostring(m.sent or ''):match('^(%d+)-(%d+)-(%d+) (%d+):(%d+)')
        if not y then return 0 end
        return os.time({year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = 0})
    end
    local stale_notes = {}

    -- Remove what arrived from the tracked mail (same item + count +
    -- sender first, then same item + count, then same item).
    local left = 0
    local ok, werr = inv_update_mail(function(d)
        local list = d.mail[me] or {}
        for _, got in ipairs(received) do
            local found = nil
            for pass = 1, 3 do
                for idx, m in ipairs(list) do
                    if tonumber(m.id) == got.id
                        and (pass == 3 or tonumber(m.count) == got.count)
                        and (pass >= 2 or tostring(m.from or ''):lower() == got.from) then
                        found = idx
                        break
                    end
                end
                if found then break end
            end
            if found then table.remove(list, found) end
        end
        local stale_changed = false
        if check_stale then
            local kept = {}
            for _, m in ipairs(list) do
                local label = tostring(m.name or m.id) .. ' x' .. tostring(m.count) .. ' from ' .. tostring(m.from or '?') .. ' (sent ' .. tostring(m.sent or '?') .. ')'
                if now - sent_epoch(m) >= min_age then
                    m.misses = (tonumber(m.misses) or 0) + 1
                    stale_changed = true
                    if m.misses >= stale_limit then
                        table.insert(stale_notes, 'removed ' .. label .. ' from tracking - not in the Delivery Box on ' .. m.misses .. ' receives that emptied it')
                    else
                        table.insert(kept, m)
                        table.insert(stale_notes, label .. ' still tracked but not in the box (' .. m.misses .. '/' .. stale_limit .. ') - removed if it is missing again')
                    end
                else
                    table.insert(kept, m)
                end
            end
            list = kept
        end
        left = #list
        if #list == 0 then d.mail[me] = nil else d.mail[me] = list end
        if #received == 0 and not stale_changed then return false end
    end)
    for _, note in ipairs(stale_notes) do
        log('Inventory rec: ' .. note .. '.')
    end
    if not ok then table.insert(errors, 'mail tracking NOT updated: ' .. tostring(werr)) end

    if force and #received == 0 and #errors == 0 then
        log('Inventory rec (force): the Delivery Box is empty.')
    end
    log('Inventory rec: ' .. #received .. ' stack(s) received' .. (left > 0 and (', ' .. left .. ' still tracked as on the way') or '') .. '.')
    if #errors > 0 then
        return false, table.concat(errors, '; ')
    end
    return true
end

---------------------------------------------------------------------
-- //gh gil <name> <amount>
---------------------------------------------------------------------
-- Mails amount gil from this character to name through the Delivery
-- Box. Gil sits in main-inventory slot 0 (item 0xFFFF), so it goes into
-- the outbox like an item with ItemWorkNo 0 and ItemStacks = amount.
-- The game only lets gil go to characters on the same account. Checks
-- the gil actually left this character before calling it sent. Not
-- tracked in Mail.lua - the receiver takes it with //gh rec (force).

local function current_gil()
    local items = windower.ffxi.get_items()
    return items and tonumber(items.gil) or nil
end

local function inv_send_gil(me, to, amount)
    to = tostring(to or ''):lower()
    amount = math.floor(tonumber(amount) or 0)
    if to == '' or not to:match('^%a+$') then return false, 'no valid character name given' end
    if to == me then return false, 'cannot mail gil to yourself' end
    if amount <= 0 then return false, 'no valid amount given' end
    local before = current_gil()
    if not before then return false, 'could not read this character\'s gil' end
    if before < amount then
        return false, proper_name(me) .. ' has only ' .. before .. ' gil (needs ' .. amount .. ')'
    end
    local data, err = inv_load()
    if not data then return false, err end
    if data.settings.mail_dry_run ~= false then
        log('Gil send (DRY RUN - settings.mail_dry_run in ItemTable.lua): would mail ' .. amount .. ' gil to ' .. proper_name(to) .. '.')
        return false, 'mail_dry_run is on - nothing sent'
    end

    pbx.listening = true
    pbx.queue = {}
    local function done(ok, why)
        pbx_close()
        pbx.listening = false
        return ok, why
    end
    if not pbx_open(PBX.OPEN_SEND) then
        pbx.listening = false
        return false, 'the Delivery Box (send) did not open (' .. tostring(pbx.last_open_fail) .. ')'
    end
    if not pbx_settle() then return done(false, 'stopped') end

    -- Clear stacks the receivers already took, and wait until their
    -- slots really are free.
    local slots, seen, _, seen_slot = pbx_clear_outbox()
    if inv_should_stop() then return done(false, 'stopped') end
    if seen == 0 then return done(false, 'could not read the outbox slots') end
    local free = pbx_free_slots(slots, seen_slot)
    if #free == 0 then return done(false, 'outbox full (sent stacks not received yet)') end

    local q = pbx_call(PBX.QUERY, BOX_NONE, -1, -1, -1, proper_name(to))
    if not (q and q.result == 0x01) then
        return done(false, 'recipient ' .. proper_name(to) .. ' not accepted (result ' .. (q and string.format('%02X', q.result) or 'none') .. ')')
    end
    coroutine.sleep(config.mail_step_delay_seconds)
    if inv_should_stop() then return done(false, 'stopped') end

    local slot, setp = pbx_set_free_slot(free, 0, amount, proper_name(to), 'Gil send')
    if not slot then
        return done(false, 'gil could not be put in the outbox (result ' .. (setp and string.format('%02X', setp.result) or 'none') .. ' - gil only goes to characters on the same account)')
    end
    coroutine.sleep(config.mail_step_delay_seconds)
    local sendp = pbx_send_slot(slot, 'Gil send')
    if not (sendp and sendp.result == 0x01) then
        -- Take it back out of the outbox so it isn't stuck there unsent.
        pbx_call(PBX.GET, BOX_OUT, slot, -1, -1)
        return done(false, 'gil to ' .. proper_name(to) .. ' not sent (result ' .. (sendp and string.format('%02X', sendp.result) or 'none') .. ')')
    end
    coroutine.sleep(config.mail_step_delay_seconds)
    pbx_close_after_sends(true)
    pbx.listening = false
    last_send_epoch = os.time()

    -- The gil should have left this character.
    local after, waited = current_gil(), 0
    while after and after > before - amount and waited < 5 do
        coroutine.sleep(0.5)
        waited = waited + 0.5
        after = current_gil()
    end
    if not after or after > before - amount then
        return false, 'the box said sent, but gil went ' .. before .. ' -> ' .. tostring(after) .. ' (expected ' .. (before - amount) .. ') - check the Delivery Box'
    end
    log('Gil send: mailed ' .. amount .. ' gil to ' .. proper_name(to) .. ' (' .. before .. ' -> ' .. after .. ').')
    return true
end

---------------------------------------------------------------------
-- //gh mailitem <item> <name>:<count> [<name>:<count> ...]
---------------------------------------------------------------------
-- Mails exact amounts of ONE item to several characters in one
-- Delivery Box visit, in the order given: every stack for the first
-- name, then the next, until the list is done or the outbox is full
-- (the last name can get only part of its amount - the caller sends the
-- rest next time). Per name: full stacks first, then the rest from the
-- smallest stack that covers it (a partial count splits a stack). Pulls
-- the item out of the other bags first when main inventory is short.
-- Ignores ItemTable.lua actions and the protected fertilizer list
-- (you named the item). Tracked in Mail.lua like //gh send. Used by
-- MuleLogger's //ml humus.
-- Returns status ('DONE' all sent / 'FULL' outbox filled first /
-- 'FAILED'), sent {{to, count}} in send order, free outbox slots, err.

local function resolve_item(text)
    text = tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil end
    local id = tonumber(text)
    if id then return res.items[id] end
    local r = res.items:with('en', text)
    if r then return r end
    local lower = text:lower()
    for _, it in pairs(res.items) do
        if type(it) == 'table' and type(it.en) == 'string' and it.en:lower() == lower then return it end
    end
    return nil
end

-- Main-inventory stack of id to take the next count from (left = still
-- to send to this character): a full stack while a full stack is still
-- owed, else the smallest stack that covers left, else the biggest.
local function pick_mail_stack(id, left, stack)
    local _, slots = main_inventory_stacks()
    local list = slots and slots[id] or {}
    local best
    if left >= stack then
        for _, sl in ipairs(list) do
            if sl.count >= stack then return sl end
        end
    else
        for _, sl in ipairs(list) do
            if sl.count >= left and (not best or sl.count < best.count) then best = sl end
        end
        if best then return best end
    end
    for _, sl in ipairs(list) do
        if not best or sl.count > best.count then best = sl end
    end
    return best
end

local function inv_mail_item(me, item_text, list)
    local r = resolve_item(item_text)
    if not r then return 'FAILED', {}, nil, 'no item called "' .. tostring(item_text) .. '"' end
    if #list == 0 then return 'FAILED', {}, nil, 'no <name>:<count> given' end
    local id, iname = r.id, r.en
    local stack = math.max(tonumber(r.stack) or 1, 1)
    local want = 0
    for _, e in ipairs(list) do
        if e.to == me then return 'FAILED', {}, nil, 'cannot mail to yourself (' .. proper_name(me) .. ')' end
        want = want + e.count
    end
    local data, err = inv_load()
    if not data then return 'FAILED', {}, nil, err end
    if data.settings.mail_dry_run ~= false then
        local parts = {}
        for _, e in ipairs(list) do table.insert(parts, proper_name(e.to) .. ' x' .. e.count) end
        log('Mail item (DRY RUN - settings.mail_dry_run in ItemTable.lua): would mail ' .. iname .. ' to ' .. table.concat(parts, ', ') .. '.')
        return 'FAILED', {}, nil, 'mail_dry_run is on - nothing sent'
    end

    -- Enough in main inventory for the whole list or a full outbox
    -- (8 stacks), pulled out of the other bags if short; sorted so split
    -- stacks merge.
    sort_bag(0)
    if not inv_sleep(config.inventory_sort_wait_seconds) then return 'FAILED', {}, nil, 'stopped' end
    local totals = main_inventory_stacks()
    if not totals then return 'FAILED', {}, nil, 'could not read main inventory' end
    local need = math.min(want, 8 * stack)
    if (totals[id] or 0) < need then
        if pull_into_inventory(id, need - (totals[id] or 0), nil, {}, 'mailitem') > 0 then
            sort_bag(0)
            if not inv_sleep(config.inventory_sort_wait_seconds) then return 'FAILED', {}, nil, 'stopped' end
        end
        totals = main_inventory_stacks() or {}
    end
    if (totals[id] or 0) == 0 then
        return 'FAILED', {}, nil, 'no ' .. iname .. ' in main inventory (or in a bag it can be pulled out of here)'
    end

    pbx.listening = true
    pbx.queue = {}
    if not pbx_open(PBX.OPEN_SEND) then
        pbx.listening = false
        return 'FAILED', {}, nil, 'the Delivery Box (send) did not open (' .. tostring(pbx.last_open_fail) .. ')'
    end
    if not pbx_settle() then
        pbx_close()
        pbx.listening = false
        return 'FAILED', {}, nil, 'stopped'
    end
    -- Clear stacks the receivers already took, and wait until their
    -- slots really are free (the rest of a filled outbox can still be
    -- leaving after the first ones cleared).
    local slots, seen, _, seen_slot = pbx_clear_outbox()
    if seen == 0 then
        pbx_close()
        pbx.listening = false
        return 'FAILED', {}, nil, 'could not read the outbox slots'
    end
    local free = pbx_free_slots(slots, seen_slot)
    log('Mail item: ' .. iname .. ' - ' .. (totals[id] or 0) .. ' in main inventory, ' .. #free .. ' free outbox slot(s).')

    local status, errors, stacks, sent_order, sent_by = 'DONE', {}, {}, {}, {}
    for _, e in ipairs(list) do
        if inv_should_stop() then status = 'FAILED' table.insert(errors, 'stopped') break end
        if #free == 0 then status = 'FULL' break end
        local to_proper = proper_name(e.to)
        local q = pbx_call(PBX.QUERY, BOX_NONE, -1, -1, -1, to_proper)
        coroutine.sleep(config.mail_step_delay_seconds)
        if not (q and q.result == 0x01) then
            status = 'FAILED'
            table.insert(errors, 'recipient ' .. to_proper .. ' not accepted (result ' .. (q and string.format('%02X', q.result) or 'none') .. ')')
        else
            local left, bad_reads, hard_stop = e.count, 0, false
            while left > 0 and #free > 0 and not inv_should_stop() do
                local sl = pick_mail_stack(id, left, stack)
                if not sl then
                    table.insert(errors, 'ran out of ' .. iname .. ' in main inventory (' .. to_proper .. ' still owed ' .. left .. ')')
                    hard_stop = true
                    break
                end
                local c = math.min(sl.count, left)
                local cur = windower.ffxi.get_items(0, sl.index)
                if not (cur and cur.id == id and (cur.count or 0) >= c and cur.status == 0) then
                    -- Inventory not caught up with the last Set yet.
                    bad_reads = bad_reads + 1
                    if bad_reads > 3 then
                        table.insert(errors, 'main inventory slot ' .. sl.index .. ' did not match ' .. iname .. ' x' .. c)
                        hard_stop = true
                        break
                    end
                    coroutine.sleep(config.mail_step_delay_seconds)
                else
                    bad_reads = 0
                    local slot, setp = pbx_set_free_slot(free, sl.index, c, to_proper, 'Mail item')
                    if not slot and #free == 0 and setp == nil then
                        -- Every slot got used up while waiting: the rest goes next time.
                        break
                    end
                    if not slot then
                        table.insert(errors, iname .. ' x' .. c .. ' for ' .. to_proper .. ' could not be put in the outbox (result ' .. (setp and string.format('%02X', setp.result) or 'none') .. ')')
                        hard_stop = true
                        break
                    end
                    coroutine.sleep(config.mail_step_delay_seconds)
                    local sendp = pbx_send_slot(slot, 'Mail item')
                    if not (sendp and sendp.result == 0x01) then
                        -- Take it back out so it isn't stuck there unsent.
                        pbx_call(PBX.GET, BOX_OUT, slot, -1, -1)
                        table.insert(errors, iname .. ' x' .. c .. ' to ' .. to_proper .. ' not sent (result ' .. (sendp and string.format('%02X', sendp.result) or 'none') .. ')')
                        hard_stop = true
                        break
                    end
                    if not sent_by[e.to] then
                        sent_by[e.to] = 0
                        table.insert(sent_order, e.to)
                    end
                    sent_by[e.to] = sent_by[e.to] + c
                    table.insert(stacks, {to = e.to, count = c})
                    left = left - c
                    log('Mail item: mailed ' .. iname .. ' x' .. c .. ' to ' .. to_proper .. (left > 0 and (' (' .. left .. ' still to go)') or '') .. '.')
                    pbx_after_send()
                end
            end
            if hard_stop or inv_should_stop() then
                status = 'FAILED'
                if not hard_stop then table.insert(errors, 'stopped') end
                break
            end
            if left > 0 then
                status = 'FULL'
                break
            end
        end
    end

    pbx_close_after_sends(#stacks > 0)
    pbx.listening = false
    if #stacks > 0 then
        last_send_epoch = os.time()
        local ok, werr = inv_update_mail(function(d)
            for _, s in ipairs(stacks) do
                d.mail[s.to] = d.mail[s.to] or {}
                table.insert(d.mail[s.to], {id = id, name = iname, count = s.count, from = me, sent = os.date('%Y-%m-%d %H:%M')})
            end
        end)
        if not ok then table.insert(errors, 'mail tracking NOT saved: ' .. tostring(werr)) end
    end
    local sent = {}
    for _, to in ipairs(sent_order) do table.insert(sent, {to = to, count = sent_by[to]}) end
    log('Mail item: ' .. #stacks .. ' stack(s) of ' .. iname .. ' mailed' .. (status == 'FULL' and ' - outbox full' or '') .. '.')
    return status, sent, #free, (#errors > 0 and table.concat(errors, '; ') or nil)
end

---------------------------------------------------------------------
-- //gh org
---------------------------------------------------------------------
-- Moves count of the item in main-inventory slot index into bag_id and
-- waits until that inventory slot actually changes.
local function move_to_bag(index, bag_id)
    local before = windower.ffxi.get_items(0, index)
    if not before or not before.id or before.id == 0 then return false end
    windower.ffxi.put_item(bag_id, index, before.count)
    local waited = 0
    while waited < config.org_move_verify_seconds do
        coroutine.sleep(0.2)
        waited = waited + 0.2
        local now = windower.ffxi.get_items(0, index)
        if not now or now.id ~= before.id or now.count ~= before.count then
            return true
        end
    end
    return false
end

-- Pulls count (default: all) of the item in bag_id slot index into main
-- inventory and waits until that slot actually changes.
move_to_inventory = function(bag_id, index, count)
    local before = windower.ffxi.get_items(bag_id, index)
    if not before or not before.id or before.id == 0 then return false end
    count = math.min(count or before.count, before.count)
    windower.ffxi.get_item(bag_id, index, count)
    local waited = 0
    while waited < config.org_move_verify_seconds do
        coroutine.sleep(0.2)
        waited = waited + 0.2
        local now = windower.ffxi.get_items(bag_id, index)
        if not now or now.id ~= before.id or now.count ~= before.count then
            return true
        end
    end
    return false
end

-- org scenarios (store_bag):
--   ""          not organized - stays where it is.
--   a bag name  moved out of main inventory into it. PullFromBags = true:
--               also gathered out of every other bag into it ("inventory":
--               out of every other bag into main inventory).
--   "bag_order" out of main inventory only, into the first bag_order bag
--               with room.
-- Organized: action "save" (on every character) and action "send" on its
-- own mail_to character (anywhere else send mails it away). Never the
-- protected fertilizers.
local function inv_organize(me)
    local data, err = inv_load()
    if not data then return false, err end
    local errors = {}
    local touched = {}
    local unusable = {}  -- bags a move into/out of didn't work this run

    local protected = protected_item_ids()
    -- The entry and its store_bag target ('bag_order' or a bag name), or
    -- nil when this character leaves the item alone.
    local function org_target(id)
        local e = data.items[id]
        if type(e) ~= 'table' or protected[id] then return nil end
        local action = item_action(e)
        if action == 'send' then
            if entry_mail_to(e) ~= me then return nil end
        elseif action ~= 'save' then
            return nil
        end
        local store = trim_lower(e.store_bag)
        if store == '' then return nil end
        if store == 'bag_order' then return e, 'bag_order' end
        local b = valid_bag_name(store)
        if not b then return e, nil, 'unknown store_bag "' .. tostring(e.store_bag) .. '"' end
        return e, b
    end

    local order_bags = {}
    for _, b in ipairs(data.bag_order) do
        local vb = valid_bag_name(b)
        if not vb then
            table.insert(errors, 'bag_order has an unknown bag "' .. tostring(b) .. '"')
        elseif vb == 'inventory' then
            table.insert(errors, 'bag_order can\'t hold "inventory" - ignored')
        else
            table.insert(order_bags, vb)
        end
    end

    -- 1) Items with a bag name AND PullFromBags = true: pull them out of
    --    every other bag into
    --    main inventory, as far as that bag has room (step 2 then puts
    --    them away). store_bag "inventory": main inventory IS the target,
    --    so they're pulled while it has room and stay there.
    local wanted = {}  -- id -> bag name
    local reported = {}
    for id in pairs(data.items) do
        local e, target, bad = org_target(id)
        if bad and not reported[id] then
            reported[id] = true
            table.insert(errors, (e.name or tostring(id)) .. ': ' .. bad)
        elseif target and target ~= 'bag_order' and pulls_from_bags(e) then
            -- v4.17.1: only PullFromBags = true items are gathered out of
            -- the other bags; false = main inventory only (step 2).
            wanted[id] = target
        end
    end
    for id, target in pairs(wanted) do
        if inv_should_stop() then break end
        local target_room = bag_free_slots(INV_BAG_IDS[target])
        for _, src in ipairs(INV_SEARCH_BAGS) do
            if src ~= target and not unusable[src] and target_room > 0 then
                local items = inv_items(INV_BAG_IDS[src])
                if items and items.enabled ~= false then
                    for i = 1, (tonumber(items.max) or 0) do
                        local it = items[i]
                        if it and it.id == id and it.status == 0 then
                            if target_room <= 0 then break end
                            if bag_free_slots(0) <= 0 then
                                table.insert(errors, 'main inventory full - could not pull ' .. (data.items[id].name or id) .. ' out of ' .. src)
                                break
                            end
                            if move_to_inventory(INV_BAG_IDS[src], i) then
                                touched[src] = true
                                target_room = target_room - 1
                                log('Inventory org: pulled ' .. (data.items[id].name or tostring(id)) .. ' x' .. (it.count or 0) .. ' out of ' .. src .. ' (its store_bag is ' .. target .. ').')
                                coroutine.sleep(config.org_move_delay_seconds)
                            else
                                unusable[src] = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2) Main inventory: items with a bag name go there; "bag_order"
    --    items go to the first bag_order bag with room. store_bag
    --    "inventory" and blank stay put.
    local items = inv_items(0)
    if not items then return false, 'could not read main inventory' end
    local moved = 0
    for i = 1, (tonumber(items.max) or 80) do
        if inv_should_stop() then break end
        local it = windower.ffxi.get_items(0, i)
        local e, target
        if it and it.id and it.id ~= 0 and it.status == 0 then
            e, target = org_target(it.id)
        end
        local order = {}
        if target == 'bag_order' then
            order = order_bags
        elseif target and target ~= 'inventory' then
            order = {target}
        end
        if #order > 0 then
            local done = false
            for _, b in ipairs(order) do
                if not unusable[b] and bag_free_slots(INV_BAG_IDS[b]) > 0 then
                    if move_to_bag(i, INV_BAG_IDS[b]) then
                        touched[b] = true
                        moved = moved + 1
                        log('Inventory org: ' .. (e.name or tostring(it.id)) .. ' x' .. (it.count or 0) .. ' -> ' .. b .. '.')
                        done = true
                        coroutine.sleep(config.org_move_delay_seconds)
                        break
                    else
                        unusable[b] = true
                        log('Inventory org: could not move into ' .. b .. ' here - trying the next bag.')
                    end
                end
            end
            if not done then
                table.insert(errors, (e.name or tostring(it.id)) .. ': no room in ' .. table.concat(order, '/'))
            end
        end
    end

    -- 3) Sort every bag that was touched.
    local sorted = {}
    for b in pairs(touched) do
        sort_bag(INV_BAG_IDS[b])
        table.insert(sorted, b)
        coroutine.sleep(config.org_move_delay_seconds)
    end

    table.sort(sorted)
    log('Inventory org: moved ' .. moved .. ' stack(s) out of main inventory' .. (#sorted > 0 and ('; sorted ' .. table.concat(sorted, ', ')) or '') .. '.')
    if #errors > 0 then
        return false, table.concat(errors, '; ')
    end
    return true
end

---------------------------------------------------------------------
-- //gh sell - GardenHelper walks to the Green Thumb Moogle and opens its
-- shop; this decides what is sold (ItemTable.lua) and sells it (shop
-- packets, so no separate sell addon is needed).
--   action "sell": every copy in main inventory.
--   action "save" with min_save > 0 and no mail_to: the copies above
--     min_save (every bag counted), as many as are in main inventory.
--   PullFromBags = true (v4.11.0): copies in the other bags are pulled
--     into main inventory before walking to the moogle ("sell": every
--     copy; "save": every copy above min_save). false = main only.
-- Outside the Mog Garden //gh sell preps the
-- items (PullFromBags pulls) and waits; the next NPC shop you open
-- (any vendor, Buy/Sell menu) sells them. //gh sell cancel calls it off.
---------------------------------------------------------------------
local shop = {armed = false, opened = false}
local vendor = {pending = false, busy = false}
local vendor_sell  -- defined below
windower.register_event('incoming chunk', function(id)
    -- 0x03C = the shop's item list: the shop window is open (a big shop
    -- can send several - only the first one starts a vendor sell).
    if id ~= 0x03C then return end
    if shop.armed then
        shop.opened = true
    elseif vendor.pending and not vendor.busy then
        vendor.busy = true
        coroutine.schedule(vendor_sell, 0)
    end
end)

local function item_label(id)
    local r = res.items[id]
    return r and r.en or tostring(id)
end

-- {id = amount to sell from main inventory}, {names that can't be sold
-- to an NPC}, {id = copies in other bags that PullFromBags would pull}
-- - or nil + error. do_pull: pull PullFromBags = true items' copies out
-- of the other bags first.
local function sell_plan(data, do_pull)
    local protected = protected_item_ids()
    local totals = main_inventory_stacks()
    if not totals then return nil, 'could not read main inventory' end
    local all = all_bag_totals()
    local want, cant, unusable, elsewhere = {}, {}, {}, {}
    local me = current_character_lower()
    local mail = data.mail
    if mail == nil then
        local md = load_mail()
        mail = md and md.mail or {}
    end
    local cap_cache, capped = {}, {}
    for id, e in pairs(data.items) do
        if type(e) == 'table' and type(id) == 'number' and not protected[id] then
            local action = item_action(e)
            local pull = pulls_from_bags(e)
            -- target = how many should end up sold (nil = not sold).
            local target = nil
            if action == 'sell' then
                target = pull and (all[id] or 0) or (totals[id] or 0)
            elseif action == 'save' and entry_mail_to(e) == '' and num(e.min_save, 0) > 0 then
                target = math.max((all[id] or 0) - num(e.min_save, 0), 0)
            elseif num(e.mail_cap, 0) > 0 then
                -- mail_cap (v4.13.0): what send would mail beyond the room
                -- mail_to has left is sold instead.
                local sendable = send_allowance(e, me, totals[id] or 0, all[id] or 0, pull)
                if sendable and sendable > 0 then
                    local room, have, cap = mail_room(e, id, mail, cap_cache)
                    if room and sendable > room then
                        target = sendable - room
                        table.insert(capped, (e.name or item_label(id)) .. ' (' .. proper_name(entry_mail_to(e))
                            .. ' has ' .. have .. '/' .. cap .. ')')
                    end
                end
            end
            local amount = 0
            if target and target > 0 then
                local in_main = totals[id] or 0
                if pull and in_main < target then
                    if do_pull and not inv_should_stop() then
                        totals[id] = in_main
                            + pull_into_inventory(id, target - in_main, valid_bag_name(e.store_bag), unusable, 'sell')
                    else
                        elsewhere[id] = target - in_main
                    end
                end
                amount = math.min(target, totals[id] or 0)
            end
            if amount > 0 or (elsewhere[id] or 0) > 0 then
                local r = res.items[id]
                if r and r.flags and r.flags['No NPC Sale'] then
                    table.insert(cant, e.name or item_label(id))
                    elsewhere[id] = nil
                elseif amount > 0 then
                    want[id] = amount
                end
            end
        end
    end
    if #capped > 0 then
        table.sort(capped)
        log('Inventory sell: over mail_cap - selling instead of mailing: ' .. table.concat(capped, ', '))
    end
    return want, cant, elsewhere
end

local function plan_text(amounts)
    local parts = {}
    for id, n in pairs(amounts) do
        if n > 0 then table.insert(parts, item_label(id) .. ' x' .. n) end
    end
    table.sort(parts)
    return parts
end

-- Before walking to the moogle: pulls PullFromBags = true items out of
-- the other bags and returns how many items will be sold (0 = nothing,
-- skip the walk), or nil + error.
function M.sell_prepare()
    local data, err = load_items()
    if not data then return nil, err end
    local dry = data.settings.sell_dry_run == true
    local want, cant, elsewhere = sell_plan(data, not dry)
    if not want then return nil, cant end
    if dry and elsewhere and next(elsewhere) then
        log('Inventory sell (DRY RUN): would also pull out of the other bags (PullFromBags) and sell: ' .. table.concat(plan_text(elsewhere), ', '))
    end
    if #cant > 0 then
        table.sort(cant)
        error_log('Inventory sell: can\'t be sold to an NPC (No NPC Sale) - give them another action in ItemTable.lua: ' .. table.concat(cant, ', '))
    end
    local units = 0
    for _, n in pairs(want) do units = units + n end
    if units > 0 then
        log('Inventory sell: ' .. units .. ' item(s) to sell: ' .. table.concat(plan_text(want), ', '))
    end
    return units
end

-- Right before talking to the moogle: watch for its shop opening (and
-- drop any vendor sell still waiting - this sale covers it).
function M.sell_arm()
    shop.armed, shop.opened = true, false
    vendor.pending = false
end

local sell_open_shop  -- defined below

-- After the menu keys: waits for the shop to open, then sells (one stack
-- per sell_item_delay_seconds). true, sold count - or false + error.
function M.sell_at_shop()
    local waited, timeout = 0, tonumber(config.sell_shop_open_timeout_seconds) or 8
    while not shop.opened and waited < timeout and not inv_should_stop() do
        coroutine.sleep(0.2)
        waited = waited + 0.2
    end
    local opened = shop.opened
    shop.armed, shop.opened = false, false
    if not opened then
        return false, 'the moogle\'s shop did not open within ' .. timeout .. 's'
    end
    return sell_open_shop()
end

-- Sells into the shop that is open now (plan re-read from ItemTable.lua
-- and main inventory). true, sold count - or false + error.
sell_open_shop = function()
    local data, err = load_items()
    if not data then return false, err end
    local want = sell_plan(data, false)
    if not want then return false, 'could not read main inventory' end
    local dry = data.settings.sell_dry_run == true
    local sold, done = 0, {}
    local items = inv_items(0)
    for index = 1, (items and tonumber(items.max) or 80) do
        if inv_should_stop() then break end
        local it = windower.ffxi.get_items(0, index)
        if it and it.id and it.id ~= 0 and (it.status or 0) == 0 and (want[it.id] or 0) > 0 then
            local c = math.min(it.count or 0, want[it.id])
            if c > 0 then
                if not dry then
                    -- 0x084 = offer count of the stack in this slot, 0x085 = confirm.
                    windower.packets.inject_outgoing(0x084, string.char(0x84, 0x06, 0, 0) .. le32(c)
                        .. string.char(it.id % 256, math.floor(it.id / 256) % 256, index, 0))
                    windower.packets.inject_outgoing(0x085, string.char(0x85, 0x04, 0, 0, 1, 0, 0, 0))
                    coroutine.sleep(tonumber(config.sell_item_delay_seconds) or 1)
                end
                want[it.id] = want[it.id] - c
                done[it.id] = (done[it.id] or 0) + c
                sold = sold + c
            end
        end
    end
    local list = plan_text(done)
    if dry then
        log('Inventory sell (DRY RUN - settings.sell_dry_run in ItemTable.lua): would sell ' .. sold .. ' item(s)' .. (#list > 0 and (': ' .. table.concat(list, ', ')) or '.'))
    else
        log('Inventory sell: sold ' .. sold .. ' item(s)' .. (#list > 0 and (': ' .. table.concat(list, ', ')) or '.'))
    end
    return true, sold
end

-- //gh sell outside the Mog Garden (call with state.running = true, so
-- PullFromBags items can be pulled). Preps the sale and waits for any NPC
-- shop to open. Returns the number of items waiting to sell (0 = nothing,
-- not armed), or nil + error.
function M.vendor_prepare()
    vendor.pending = false
    local units, err = M.sell_prepare()
    if units == nil then return nil, err end
    if units > 0 then
        vendor.pending = true
        log('Inventory sell: ready - talk to any NPC vendor and open its Buy/Sell menu; these sell as soon as the shop opens. //gh sell cancel calls it off.')
    end
    return units
end

-- //gh sell cancel. true if a vendor sell was waiting.
function M.vendor_cancel()
    local was = vendor.pending
    vendor.pending = false
    return was
end

function M.vendor_pending()
    return vendor.pending
end

-- A shop opened with a vendor sell waiting: sell, then drop.
vendor_sell = function()
    if state.running then
        -- Another GardenHelper operation owns the game right now: leave the
        -- sale waiting for the next shop.
        error_log('Inventory sell: a shop opened while another GardenHelper operation is running - not selling now (still waiting; open the shop again when it finishes, or //gh sell cancel).')
        vendor.busy = false
        return
    end
    vendor.pending = false
    state.running = true
    log('Inventory sell: shop opened - selling...')
    local ok, res_or_err = sell_open_shop()
    if not ok then error_log('Inventory sell: ' .. tostring(res_or_err)) end
    if state.running then M.drop_now() end
    state.running = false
    vendor.busy = false
    log('SellResult: ' .. (ok and 'DONE' or 'FAILED'))
end

-- The sell step of //gh inv: sells through GardenHelper's moogle walk
-- (Mog Garden only - anywhere else it is skipped, not an error).
local function inv_sell(me)
    if not gh.in_mog_garden() then
        log('Inventory sell: not in the Mog Garden (the Green Thumb Moogle is there) - skipped. Use //gh sell to sell at any NPC vendor.')
        return true
    end
    if not config.sell_junk_enabled or not gh.is_module_enabled('sell') then
        log('Inventory sell: selling is off for this character (config.sell_junk_enabled / sell in characters.lua) - skipped.')
        return true
    end
    if gh.sell() then return true end
    if inv_should_stop() then return false, 'stopped' end
    return false, 'selling at the Green Thumb Moogle did not finish (see the lines above)'
end

---------------------------------------------------------------------
-- //gh drop - drops every action = "drop" item in main inventory and
-- passes them in the treasure pool (what //tr drop did). PullFromBags =
-- true items are pulled out of the other bags first (v4.11.0; main
-- inventory full = drop, pull again, up to drop_pull_max_rounds). With
-- settings.auto_drop it also happens by itself: dropped the moment one
-- lands in main inventory, passed the moment one hits the pool.
---------------------------------------------------------------------
local drop_cache = {ids = {}, pull = {}, loaded_at = nil, auto = false, dry = false, logged = {}}

-- Re-reads the drop list from ItemTable.lua (at most every
-- auto_drop_refresh_seconds unless forced). A broken file keeps the
-- last good list.
local function refresh_drop_cache(force)
    local every = tonumber(config.auto_drop_refresh_seconds) or 30
    if not force and drop_cache.loaded_at and os.time() - drop_cache.loaded_at < every then return end
    drop_cache.loaded_at = os.time()
    local data = load_items()
    if not data then return end
    local ids, pull = {}, {}
    for id, e in pairs(data.items) do
        if type(e) == 'table' and type(id) == 'number' and item_action(e) == 'drop' then
            ids[id] = true
            if pulls_from_bags(e) then pull[id] = true end
        end
    end
    drop_cache.ids = ids
    drop_cache.pull = pull
    drop_cache.auto = data.settings.auto_drop ~= false
    drop_cache.dry = data.settings.drop_dry_run == true
end

local function is_protected(id)
    local ok, ids = pcall(protected_item_ids)
    return ok and ids[id] or false
end

-- Drops the stack in main-inventory slot index if it is still item id.
local function drop_stack(index, id)
    local it = windower.ffxi.get_items(0, index)
    if not it or it.id ~= id or (it.status or 0) ~= 0 then return 0 end
    windower.ffxi.drop_item(index, it.count)
    return it.count or 0
end

local function inv_drop(me)
    refresh_drop_cache(true)
    local dry = drop_cache.dry
    local protected = protected_item_ids()
    local passed, dropped = {}, {}
    local all = windower.ffxi.get_items() or {}
    for index, item in pairs(all.treasure or {}) do
        if type(item) == 'table' and item.item_id and drop_cache.ids[item.item_id] then
            if not dry then
                windower.ffxi.pass_item(index)
                coroutine.sleep(0.5)
            end
            table.insert(passed, item_label(item.item_id))
        end
    end
    local amounts, would_pull = {}, {}
    -- One pass over main inventory: drop every "drop" stack.
    local function drop_main()
        local items = inv_items(0)
        if not items then return false end
        for index = 1, (tonumber(items.max) or 80) do
            if inv_should_stop() then break end
            local it = windower.ffxi.get_items(0, index)
            if it and it.id and it.id ~= 0 and (it.status or 0) == 0 and drop_cache.ids[it.id] and not protected[it.id] then
                local c = it.count or 0
                if not dry then
                    c = drop_stack(index, it.id)
                    coroutine.sleep(tonumber(config.drop_item_delay_seconds) or 0.5)
                end
                if c > 0 then amounts[it.id] = (amounts[it.id] or 0) + c end
            end
        end
        return true
    end
    -- PullFromBags = true: pull every copy in the other bags into main
    -- inventory (dry run: just list them). Returns how many were pulled.
    local unusable = {}
    local function pull_drops()
        if not next(drop_cache.pull) then return 0 end
        local totals = main_inventory_stacks() or {}
        local all = all_bag_totals()
        local got = 0
        for id in pairs(drop_cache.pull) do
            local extra = (all[id] or 0) - (totals[id] or 0)
            if extra > 0 and not protected[id] then
                if dry then
                    would_pull[id] = extra
                elseif not inv_should_stop() then
                    got = got + pull_into_inventory(id, extra, nil, unusable, 'drop')
                end
            end
        end
        return got
    end
    local pulled_any = pull_drops() > 0
    if not drop_main() then return false, 'could not read main inventory' end
    -- Main inventory filled up while pulling: drop made room, pull again.
    local rounds = tonumber(config.drop_pull_max_rounds) or 5
    while pulled_any and not dry and rounds > 1 and not inv_should_stop() do
        rounds = rounds - 1
        pulled_any = pull_drops() > 0
        if pulled_any then drop_main() end
    end
    local list = plan_text(amounts)
    table.sort(passed)
    local what = dry and 'Inventory drop (DRY RUN - settings.drop_dry_run in ItemTable.lua): would drop ' or 'Inventory drop: dropped '
    log(what .. #list .. ' item type(s)' .. (#list > 0 and (' (' .. table.concat(list, ', ') .. ')') or '')
        .. (dry and ', would pass ' or ', passed ') .. #passed .. ' in the treasure pool' .. (#passed > 0 and (' (' .. table.concat(passed, ', ') .. ')') or '') .. '.')
    if dry and next(would_pull) then
        log('Inventory drop (DRY RUN): would also pull out of the other bags (PullFromBags) and drop: ' .. table.concat(plan_text(would_pull), ', '))
    end
    return true
end

-- For GardenHelper's sell (after the moogle): drop now, outside a step.
function M.drop_now()
    -- Inside //gh inv with its drop step still to come: that step does it
    -- (no double "Inventory drop" line).
    if active and drop_step_pending then return true end
    return inv_drop(current_character_lower())
end

-- auto_drop: 0x020 / 0x01F = something changed in a bag slot, 0x0D2 = an
-- item hit the treasure pool.
-- v4.15.0: any main-inventory slot change starts a short sweep of ALL of
-- main inventory instead of dropping the one slot the packet named.
-- Loot from mobs often reached memory after the slot drop ran (Giant
-- Stinger never dropped; Beehive Chips dropped one kill late), and a
-- slot drop that missed was never tried again. The sweep re-reads every
-- slot, drops every action = "drop" stack it finds, and checks again
-- a few times while it is still finding / missing things.
local sweep = {scheduled = false, again = 0}

local function auto_drop_sweep()
    sweep.scheduled = false
    refresh_drop_cache(false)
    if not drop_cache.auto or drop_cache.dry then return end
    local items = inv_items(0)
    if not items then return end
    local protected = protected_item_ids()
    local found = false
    for index = 1, (tonumber(items.max) or 80) do
        local it = windower.ffxi.get_items(0, index)
        if it and it.id and it.id ~= 0 and drop_cache.ids[it.id] and not protected[it.id] then
            found = true
            if (it.status or 0) == 0 then
                drop_stack(index, it.id)
                coroutine.sleep(0.3 + math.random() * 0.3)
            end
        end
    end
    -- Found something: look again shortly (the drop went through, or the
    -- item was still settling), at most a few times in a row.
    if found and sweep.again > 0 then
        sweep.again = sweep.again - 1
        sweep.scheduled = true
        coroutine.schedule(auto_drop_sweep, 2)
    end
end

local function schedule_sweep()
    sweep.again = 3
    if sweep.scheduled then return end
    sweep.scheduled = true
    coroutine.schedule(auto_drop_sweep, 1 + math.random() * 0.5)
end

windower.register_event('incoming chunk', function(id, original)
    if id ~= 0x020 and id ~= 0x01F and id ~= 0x0D2 then return end
    refresh_drop_cache(false)
    if not drop_cache.auto then return end
    local ok, p = pcall(packets.parse, 'incoming', original)
    if not ok or type(p) ~= 'table' then return end
    if id ~= 0x0D2 then
        -- any main-inventory change: sweep (a drop item can sit in a
        -- slot this packet doesn't name).
        if p.Bag ~= 0 then return end
        if drop_cache.dry then
            if p.Item and drop_cache.ids[p.Item] and (p.Count or 0) > 0 and not is_protected(p.Item) then
                local key = 'drop:' .. p.Item
                if not drop_cache.logged[key] or os.time() - drop_cache.logged[key] > 60 then
                    drop_cache.logged[key] = os.time()
                    log('Inventory auto_drop (DRY RUN): would drop ' .. item_label(p.Item) .. '.')
                end
            end
            return
        end
        if next(drop_cache.ids) then schedule_sweep() end
        return
    end
    if not p.Item or not drop_cache.ids[p.Item] or is_protected(p.Item) then return end
    if drop_cache.dry then
        local key = 'pass:' .. p.Item
        if not drop_cache.logged[key] or os.time() - drop_cache.logged[key] > 60 then
            drop_cache.logged[key] = os.time()
            log('Inventory auto_drop (DRY RUN): would pass ' .. item_label(p.Item) .. '.')
        end
        return
    end
    local index = p.Index
    coroutine.schedule(function() windower.ffxi.pass_item(index) end, 0.5 + math.random())
    -- solo the item goes straight to inventory: sweep for it too
    schedule_sweep()
end)

---------------------------------------------------------------------
-- //gh inv rebuild - rewrites ItemTable.lua from what is in it now:
-- sorted by action, then type, then name, with the action banners and
-- type headers redrawn. Also tidies each item: action / store_bag
-- lowercased, a missing name filled in from the item id, missing fields
-- given their defaults. Nothing in game is touched. Your own comments
-- are not kept (the previous file is backup/ItemTable.lua.bak).
---------------------------------------------------------------------
local function inv_rebuild()
    local data, err = load_items_raw()
    if not data then return false, err end
    local notes, counts, total, overrides = {}, {}, 0, 0
    for id, e in pairs(data.items) do
        local oid = override_key(id)
        if type(e) == 'table' and oid then
            -- override line: tidy only the fields it has (no defaults
            -- filled in - missing fields come from the [id] line).
            overrides = overrides + 1
            if e.override_for ~= nil then e.override_for = nil end
            if e.action ~= nil then
                local a = trim_lower(e.action)
                if not ACTION_RANK[a] then
                    table.insert(notes, tostring(id) .. ': unknown action "' .. tostring(e.action) .. '" - set to "" (review section)')
                    a = ''
                end
                e.action = a
            end
            if e.store_bag ~= nil then
                local store = trim_lower(e.store_bag)
                if store ~= '' and store ~= 'bag_order' and not valid_bag_name(store) then
                    table.insert(notes, tostring(id) .. ': unknown store_bag "' .. tostring(e.store_bag) .. '" (left as is)')
                else
                    e.store_bag = store
                end
            end
            if type(data.items[oid]) ~= 'table' then
                table.insert(notes, tostring(id) .. ': override line with no [' .. oid .. '] line - used as the item\'s only line on that character')
            end
        elseif type(e) == 'table' then
            total = total + 1
            local label = tostring(e.name or id)
            if type(id) == 'number' and tostring(e.name or '') == '' and res.items[id] then
                e.name = res.items[id].en
                table.insert(notes, id .. ': name filled in (' .. e.name .. ')')
            end
            local raw = tostring(e.action == nil and '' or e.action)
            local a = trim_lower(raw)
            if not ACTION_RANK[a] then
                table.insert(notes, label .. ': unknown action "' .. raw .. '" - set to "" (review section)')
                a = ''
            end
            e.action = a
            local store = trim_lower(e.store_bag)
            if store ~= '' and store ~= 'bag_order' and not valid_bag_name(store) then
                table.insert(notes, label .. ': unknown store_bag "' .. tostring(e.store_bag) .. '" (left as is)')
            else
                e.store_bag = store
            end
            for k, v in pairs(ITEM_FIELD_DEFAULTS) do
                if e[k] == nil then e[k] = v end
            end
            counts[a] = (counts[a] or 0) + 1
        end
    end
    local ok, werr = write_items(data)
    if not ok then return false, werr end
    local parts = {}
    for _, a in ipairs(ACTION_ORDER) do
        if counts[a] then table.insert(parts, (a == '' and 'new' or a) .. ' ' .. counts[a]) end
    end
    log('Inventory rebuild: ItemTable.lua rewritten - ' .. total .. ' item(s) sorted by action, type, name (' .. table.concat(parts, ', ') .. ')' .. (overrides > 0 and (', ' .. overrides .. ' per-character override line(s)') or '') .. '. Previous file: backup/ItemTable.lua.bak.')
    for _, n in ipairs(notes) do log('  ' .. n) end
    return true
end

---------------------------------------------------------------------
-- Step runner
---------------------------------------------------------------------
local STEP_FUNCTIONS = {sell = inv_sell, drop = inv_drop, pop = inv_populate, send = inv_send, rec = inv_receive, org = inv_organize}

-- steps: list of 'sell'/'drop'/'pop'/'send'/'rec'/'org' (nil = all six). auto = an
-- automatic run (//gh inv auto, //gh full): the characters.lua step
-- switches apply. force_receive = rec takes everything in the box.
-- Needs state.running (//gh stop stops it). true = every step OK.
local function run_inventory_steps(steps, auto, force_receive)
    steps = steps or STEPS
    local me = current_character_lower()
    if not me then
        error_log('Inventory: no character logged in.')
        return false
    end
    if active then
        error_log('Inventory: already running (//gh stop to cancel it).')
        return false
    end
    local data, err = inv_load()
    if not data then
        error_log('Inventory: ' .. err)
        return false
    end
    if is_skipped_character(data, me) then
        log('Inventory: ' .. proper_name(me) .. ' is in ItemTable.lua settings.skip_characters - skipped.')
        return true
    end
    if auto then
        local kept, dropped = {}, {}
        for _, step in ipairs(steps) do
            table.insert((not STEP_SWITCH[step] or gh.is_module_enabled(STEP_SWITCH[step])) and kept or dropped, step)
        end
        if #dropped > 0 then
            log('Inventory: ' .. table.concat(dropped, ', ') .. ' switched off for ' .. proper_name(me) .. ' in characters.lua - skipped.')
        end
        if #kept == 0 then
            return true
        end
        steps = kept
    end
    log('Inventory: running ' .. table.concat(steps, ', ') .. ' for ' .. proper_name(me) .. '...')

    active = true
    drop_step_pending = false
    for _, step in ipairs(steps) do
        if step == 'drop' then drop_step_pending = true end
    end
    local all_ok = true
    for step_no, step in ipairs(steps) do
        if inv_should_stop() then break end
        if step == 'drop' then drop_step_pending = false end
        -- Called directly, not through pcall: the steps sleep, and Lua
        -- 5.1 can't yield across a pcall.
        local step_ok, step_err = STEP_FUNCTIONS[step](me, force_receive)
        if pbx.listening then
            pbx_close()
            pbx.listening = false
        end
        if step_err == 'stopped' then break end
        if not step_ok then
            all_ok = false
            error_log('Inventory ' .. step .. ': ' .. tostring(step_err))
        end
        inv_record_status(me, step, step_ok, step_err)
        -- Pause between steps only - not after the last one.
        if step_no < #steps and not inv_sleep(config.inventory_step_gap_seconds) then break end
    end
    if inv_should_stop() then
        log('Inventory: stopped.')
        all_ok = false
    end
    drop_step_pending = false
    active = false
    return all_ok
end

---------------------------------------------------------------------
-- API
---------------------------------------------------------------------
-- Pulls item_name out of the other bags into main inventory until
-- `want` are there (GardenHelper: a seed missing when planting).
-- Returns how many are in main inventory afterwards, nil = unknown item.
function M.pull_item(item_name, want)
    local item = res.items:with('name', item_name)
    if not item then return nil end
    local function have()
        local n = 0
        for _, it in ipairs(windower.ffxi.get_items(0) or {}) do
            if it.id == item.id then n = n + (it.count or 0) end
        end
        return n
    end
    local need = math.max((tonumber(want) or 1) - have(), 0)
    if need > 0 then
        pull_into_inventory(item.id, need, nil, {}, 'restock')
    end
    return have()
end

M.run = run_inventory_steps
-- For offline tooling / tests (file layout and conversion); not used in game.
M._internal = {serialize_items = serialize_items, normalize_items = normalize_items, sell_plan = sell_plan,
    plan_sends = inv_plan_sends, organize = inv_organize, drop = inv_drop, populate = inv_populate}
M.load = inv_load   -- ItemTable.lua + Mail.lua merged, or nil + error

-- I code for //gh status (and tools reading Mail.lua): D steps OK,
-- E an error, U never run, S skipped character.
function M.status_code(data, name)
    name = tostring(name or ''):lower()
    if not data then return 'U' end
    if is_skipped_character(data, name) then return 'S' end
    local s = data.status[name]
    if type(s) ~= 'table' then return 'U' end
    local any = false
    for _, step in ipairs(STEPS) do
        if s[step] == 'E' then return 'E' end
        if s[step] == 'D' then any = true end
    end
    return any and 'D' or 'U'
end

-- Stacks mailed to this character and not received yet.
function M.pending_mail_count(data, name)
    local list = type(data) == 'table' and type(data.mail) == 'table' and data.mail[tostring(name or ''):lower()]
    return type(list) == 'table' and #list or 0
end

-- "pop: ... | send: ..." for a character whose status has an E, else nil.
function M.error_text(data, name)
    local s = type(data) == 'table' and data.status[tostring(name or ''):lower()]
    if type(s) ~= 'table' then return nil end
    local parts = {}
    for _, step in ipairs(STEPS) do
        if s[step] == 'E' then
            table.insert(parts, step .. ': ' .. tostring(s[step .. '_error'] or 'error'))
        end
    end
    return #parts > 0 and table.concat(parts, ' | ') or nil
end

-- "Charname" for whoever is logged in ("?" when nobody is).
function M.character_label()
    return proper_name(current_character_lower() or '?')
end

---------------------------------------------------------------------
-- Commands: inv [<step>] [auto], inv rebuild, sell, drop, pop, send, rec, org, inv help
---------------------------------------------------------------------
local GROUP_WORDS = {inv = true, inventory = true}
local STEP_WORDS = {sell = 'sell', drop = 'drop', pop = 'pop', populate = 'pop', send = 'send',
    rec = 'rec', receive = 'rec', org = 'org', organize = 'org', organise = 'org'}
local FORCE_WORDS = {force = true, all = true, f = true}

function M.is_command(word)
    word = tostring(word or ''):lower()
    return GROUP_WORDS[word] == true or STEP_WORDS[word] ~= nil or word == 'gil' or word == 'mailitem'
end

-- True if any argument after the command word is one of words.
function M.has_word(args, ...)
    for i = 2, #(args or {}) do
        for _, w in ipairs({...}) do
            if tostring(args[i]):lower() == w then return true end
        end
    end
    return false
end

function M.is_help(args)
    return M.has_word(args, 'help', 'h', '?')
end

-- Runs the command (args[1] = command word). true = every step OK.
function M.command(args)
    local word = tostring(args[1] or ''):lower()
    -- //gh mailitem <item> <name>:<count> ... [auto]: exact amounts of
    -- one item to several characters (ends with MailItemResult).
    if word == 'mailitem' then
        local list, words = {}, {}
        for i = 2, #args do
            local a = tostring(args[i])
            local n, c = a:match('^(%a+):(%d+)$')
            if n then
                if tonumber(c) > 0 then table.insert(list, {to = n:lower(), count = tonumber(c)}) end
            elseif a:lower() ~= 'auto' then
                table.insert(words, a)
            end
        end
        local me = current_character_lower()
        if not me then
            error_log('Mail item: no character logged in.')
            log('MailItemResult: FAILED sent=none')
            return false
        end
        if active then
            error_log('Mail item: an inventory run is going (//gh stop to cancel it).')
            log('MailItemResult: BUSY sent=none')
            return false
        end
        active = true
        local status, sent, free, err = inv_mail_item(me, table.concat(words, ' '), list)
        if pbx.listening then
            pbx_close()
            pbx.listening = false
        end
        active = false
        if err then error_log('Mail item: ' .. tostring(err)) end
        local parts = {}
        for _, s in ipairs(sent or {}) do table.insert(parts, s.to .. ':' .. s.count) end
        log('MailItemResult: ' .. status .. ' sent=' .. (#parts > 0 and table.concat(parts, ',') or 'none') .. ' free=' .. tostring(free or '?'))
        return status ~= 'FAILED'
    end
    -- //gh gil <name> <amount> [auto]: mail gil (ends with GilResult).
    if word == 'gil' then
        local to, amount
        for i = 2, #args do
            local a = (tostring(args[i]):lower():gsub(',', ''))
            if a == 'auto' then
            elseif a:match('^%d+[km]?$') then
                local n, unit = a:match('^(%d+)([km]?)$')
                amount = tonumber(n) * (unit == 'k' and 1000 or unit == 'm' and 1000000 or 1)
            elseif a:match('^%a+$') and not to then
                to = a
            else
                error_log('Unknown gil option "' .. tostring(args[i]) .. '" - use //gh gil <name> <amount>, e.g. //gh gil Woodvf 1m.')
                log('GilResult: FAILED')
                return false
            end
        end
        local me = current_character_lower()
        if not me then
            error_log('Gil send: no character logged in.')
            log('GilResult: FAILED')
            return false
        end
        if active then
            error_log('Gil send: an inventory run is going (//gh stop to cancel it).')
            log('GilResult: BUSY')
            return false
        end
        active = true
        local ok, err = inv_send_gil(me, to, amount)
        if pbx.listening then
            pbx_close()
            pbx.listening = false
        end
        active = false
        if not ok then error_log('Gil send: ' .. tostring(err)) end
        log('GilResult: ' .. (ok and 'SENT' or 'FAILED') .. ' to=' .. tostring(to) .. ' amount=' .. tostring(amount))
        return ok
    end
    -- //gh inv rebuild: re-sort / tidy ItemTable.lua (no game steps).
    if GROUP_WORDS[word] and tostring(args[2] or ''):lower() == 'rebuild' then
        if #args > 2 then
            error_log('//gh inv rebuild takes no options.')
            return false
        end
        local ok, err = inv_rebuild()
        if not ok then error_log('Inventory rebuild: ' .. tostring(err)) end
        return ok
    end
    local force, auto, step = false, false, nil
    for i = 2, #args do
        local a = tostring(args[i]):lower()
        if FORCE_WORDS[a] then
            force = true
        elseif a == 'auto' then
            auto = true
        elseif GROUP_WORDS[word] and STEP_WORDS[a] and not step then
            step = STEP_WORDS[a]
        else
            error_log('Unknown inv option "' .. tostring(args[i]) .. '" - //gh inv help lists the commands.')
            return false
        end
    end
    local steps = STEPS
    if STEP_WORDS[word] then
        steps = {STEP_WORDS[word]}
    elseif step then
        steps = {step}
    end
    local ok = run_inventory_steps(steps, auto, force)
    log('Inventory ' .. table.concat(steps, ', ') .. ': done.')
    return ok
end

function M.help()
    local data = load_items()
    local st = data and data.settings or {}
    local function flag(v) return data and tostring(v) or '?' end
    for _, line in ipairs({
        'INV commands (inv.lua v' .. M.version .. ') - every item\'s handling comes from its action in ItemTable.lua:',
        '  //gh inv           - sell, drop, pop, send, rec, org, in that order (sell only in the Mog Garden)',
        '  //gh sell          - walk to the Green Thumb Moogle and sell: every action "sell" item in main inventory, and every action "save" item above its min_save (all bags counted; sold from main inventory) when it has no mail_to. PullFromBags = true items are pulled out of the other bags first',
        '  //gh drop          - drop every action "drop" item in main inventory (PullFromBags = true: pulled out of the other bags first) and pass them in the treasure pool. auto_drop (now ' .. flag(st.auto_drop ~= false) .. ') also does it by itself as they land / drop',
        '  //gh pop           - add every main-inventory item ItemTable.lua doesn\'t list yet with action "" (top of the file, to review): type guessed, mail_to guessed from its type, min_mail = stack size, min_save 0, store_bag blank, PullFromBags false',
        '  //gh send          - mail action "send" items to mail_to once there are min_mail in MAIN INVENTORY (other bags untouched unless the item has PullFromBags = true: then every bag counts and copies are pulled out first; min_save kept back); action "save" items with a mail_to mail what is above min_save instead of selling it. min_mail at stack size = full stacks only',
        '  //gh rec           - take everything out of the Delivery Box; while a round finds it full (8 stacks) it checks again, until the box comes back not full (max ' .. config.mail_receive_max_rounds .. ' rounds)',
        '  //gh org           - store_bag = a bag: out of main inventory into it (PullFromBags = true: gathered out of every bag); "bag_order": out of main inventory into the first bag_order bag with room; "inventory": kept in main inventory; blank: not moved. Only action "save" (any character) and "send" (on its mail_to character). Sorts every bag touched',
        '  //gh gil <name> <amount> - mail gil through the Delivery Box (1m / 500k / 250000); only to characters on the same account. Ends with "GilResult: SENT / FAILED". The receiver takes it with //gh rec',
        '  //gh mailitem <item> <name>:<count> ... - mail exact amounts of one item (e.g. //gh mailitem Rich Humus fishvf:21 goldvf:21): each name\'s stacks in turn until the list is done or the outbox is full; pulls it out of other bags first; ignores ItemTable.lua actions. Ends with "MailItemResult: DONE / FULL / FAILED sent=name:count,..."',
        '  //gh inv <step>    - same as //gh <step>;  //gh stop - stops after the current action',
        '  //gh inv rebuild   - rewrite ItemTable.lua from what is in it now: sorted by action, type, name, banners redrawn, action / store_bag lowercased, missing names filled from the item id. Nothing in game is touched; your own comments are not kept (previous file: backup/ItemTable.lua.bak)',
        '  //gh inv auto      - the automatic run (//gh full with inventory_after_full, or your own scripts): characters.lua sell / process_inv / send_mail / receive_mail / org_inv = false leave a step out; ends with "InvResult: DONE/FAILED"',
        'Item table file: ' .. items_file_name() .. ' (characters.lua item_table; blank = ItemTable.lua)',
        'ItemTable.lua settings: mail_dry_run ' .. flag(st.mail_dry_run ~= false) .. ', sell_dry_run ' .. flag(st.sell_dry_run == true) .. ', drop_dry_run ' .. flag(st.drop_dry_run == true) .. ' (true = only log), auto_drop, skip_characters; bag_order; items {name, type, action, mail_to, min_mail, min_save, store_bag, PullFromBags}; ["id:Character"] = {...} lines override an item for one character',
        'Mail.lua (INV\'s): mail = tracked stacks per receiver, status = last result of each step per character. Timings: mail_* / inventory_* / org_* / sell_* / drop_* in GardenHelper.lua\'s config; mail_debug = true prints every Delivery Box packet.',
        'This character\'s furrow fertilizer and node fertilizers are never sold, dropped, mailed away or moved (the active seed follows its ItemTable.lua line).',
    }) do
        log(line)
    end
end

return M
end

--[[ Recent changes (full history: CHANGELOG-inv.md)
  v2.0.0 (2026-09-24) - Part of GardenHelper (//gh inv, pop, send, rec,
    org; inv auto ends with InvResult). ItemTable.lua / Mail.lua in the
    GardenHelper folder, backups in backup/. The active seed, fertilizer
    and node fertilizers are never mailed or moved.
  v2.1.0 (2026-09-24) - Stale "on the way" mail: a tracked stack missing
    from a fully emptied Delivery Box mail_stale_misses (2) times is
    removed from tracking.
  v3.0.0 (2026-09-25) - mail_to per item; org gathers items with a
    store_bag out of every bag into it.
  v3.1.0 (2026-09-25) - store_bag = "inventory" keeps an item in main
    inventory (pulled out of every other bag).
  v4.0.0 (2026-09-25) - inv.lua is the whole inventory manager. Item
    lines are {name, type, action, mail_to, min_mail, min_save,
    store_bag}; action = "" / save / send / ignore / sell / drop. New
    //gh sell logic (shop packets) and //gh drop (+ auto_drop). //gh inv
    = sell, drop, pop, send, rec, org. Older files converted on load.
  v4.1.0 (2026-09-25) - //gh inv rebuild re-sorts ItemTable.lua after
    hand edits (your own comments are not kept; previous file in
    backup/ItemTable.lua.bak).
  v4.2.0 (2026-09-25) - //gh sell at any NPC vendor: outside the Mog
    Garden it preps the sale and sells at the next vendor shop you open;
    //gh sell cancel calls it off.
  v4.3.0 (2026-09-26) - Public release: a new ItemTable.lua starts with
    auto_drop OFF (was on) - an existing file keeps its own setting.
    Comments and help text made generic. No other behaviour changes.
  v4.3.1 (2026-09-26) - //gh inv no longer drops twice: the sell step's
    after-shop drop is skipped when the run's own drop step comes next
    (one "Inventory drop" line). //gh sell alone still drops after.
  v4.5.0 (2026-09-27) - //gh gil <name> <amount>: mails gil through the
    Delivery Box (gil = main-inventory slot 0 into the outbox), checks
    the gil left, ends with "GilResult: SENT / FAILED". For MuleLogger's
    //ml cash. rec takes gil even with main inventory full, and logs it
    as "Gil".
  v4.6.0 (2026-09-28) - //gh mailitem <item> <name>:<count> ...: mails
    exact amounts of one item to several characters in one Delivery Box
    visit, in the order given, until the list is done or the outbox is
    full (last name may be partial). Full stacks first, then the rest
    from the smallest stack that covers it. Pulls from other bags first.
    Tracked in Mail.lua. Ends with "MailItemResult: DONE / FULL / FAILED
    sent=name:count,... free=N". For MuleLogger's //ml humus.
  v4.6.1 (2026-09-28) - Longer waits around sending mail (Mark: errors
    in //ml humus - the outbox needs a few seconds for sent stacks to
    clear). New config: mail_after_send_wait_seconds (3) after every
    Send, mail_after_confirm_wait_seconds (3) after clearing received
    stacks and before reading the free slots, mail_before_close_wait_seconds
    (5) before closing a box that sent something. Applies to inv send,
    //gh gil and //gh mailitem.
  v4.6.2 (2026-09-28) - The outbox is really cleared before filling it
    (Mark: //ml humus on Woodvf - half the received stacks had left,
    then new stacks went in while the rest of the bottom slots were
    still clearing, and the Set failed). New pbx_clear_outbox: Confirm
    what Check reports, re-read the slots, repeat until Check reports
    nothing and the used-slot count has dropped by every stack
    confirmed (max mail_outbox_clear_timeout_seconds, 30; polls every
    mail_outbox_clear_poll_seconds, 1). And a Set the game refuses is
    retried: wait mail_set_retry_wait_seconds (3), clear/re-read the
    outbox, try again, up to mail_set_retries (3) times. Applies to inv
    send, //gh gil and //gh mailitem.
  v4.6.3 (2026-09-28) - Waits for ALL received stacks to leave the
    outbox, even when the game confirmed them itself (Mark: //ml smart
    on Woodvf 22:48 - Check said 0 while the 8 slots were still
    emptying, the stack went into slot 1 and the Send got EF
    "Communications seem to be congested"). The outbox is re-read until
    all 8 slots are empty or the used count stays the same for
    mail_outbox_stable_seconds (5), max mail_outbox_clear_timeout_seconds
    (now 60). Slots with no reply are never used as free. A refused Send
    is retried (stack stays in its slot) up to mail_send_retries (3), and
    a Delivery Box that won't open ("try again in a little while") is
    tried again after mail_open_retry_wait_seconds (5), up to
    mail_open_retries (2).  v4.7.0 (2026-09-30) - M.pull_item(name, want): pulls an item out of
    the other bags into main inventory until want are there; returns the
    count now in main inventory. Used by GardenHelper v2.17.0 when the
    seed / fertilizer isn't in main inventory at planting time.
  v4.9.0 (2026-10-01) - "Delivery Box did not open" lines now say why:
    "the box answered result XX" or "no reply from the server within
    10s" (Mark: every box failed to open on every character after
    12:47 on 10/1 - send, mailitem and rec alike).
  v4.11.0 (2026-10-01) - New ItemTable.lua item field PullFromBags
    (default false). false: //gh send, sell and drop only use the copies
    in main inventory (the other bags are left alone). true: the copies
    in the other bags are pulled into main inventory first - send counts
    every bag toward min_mail (max mail_pull_max_stacks, 8, stacks per
    item per send), sell sells every copy ("save": every copy above
    min_save), drop drops every copy (drop_pull_max_rounds, 5, when main
    inventory fills). "save" extras are no longer pulled for //gh sell
    unless PullFromBags = true. auto_drop stays main-inventory only.
  v4.12.0 (2026-10-05) - Per-character override lines in ItemTable.lua
    (Mark): ["4304:FishVFi"] = {...} next to [4304] = {...}. On FishVFi
    every step (sell, drop, auto_drop, send, org) uses the override line
    for that item; every other character uses the [id] line. Fields the
    override line leaves out come from the [id] line. (Two [4304] lines
    can't work - Lua keeps only the last one.) pop ignores override
    lines when guessing mail_to; rebuild keeps them right under their
    [id] line, writes only the fields they have and drops a leftover
    override_for field.
  v4.14.0 (2026-10-10) - auto_drop also watches packet 0x01F (Mark:
    Beehive Chip / Insect Wing from Death Jackets on Shadowhammer were
    never dropped). A stackable item joining a stack already in main
    inventory only gets 0x01F (count change), not 0x020, so auto_drop
    never saw it. Equipped / bazaar copies (status not 0) are skipped,
    and one slot gets one scheduled drop at a time.
  v4.15.0 (2026-10-10) - auto_drop sweeps all of main inventory (Mark:
    Giant Stingers from Death Jackets still not thrown away; chips /
    wings dropped one kill late). Any main-inventory slot change (0x020 /
    0x01F) or a drop item hitting the pool schedules a sweep ~1s later
    that drops every action = "drop" stack in main inventory, then checks
    again every 2s (up to 3 more times) while it still finds some. A
    missed drop is no longer lost.
  v4.16.0 (2026-10-27) - The active seed is no longer protected (Mark;
    GardenHelper v2.30.0): sell / send / drop / org follow its ItemTable.lua
    line like any other item (Arborfruit Seed: save, min_save 99 = keep 99,
    sell the rest). Fertilizers stay protected.
  v4.17.0 (2026-11-03) - The item table file comes from characters.lua
    item_table (GardenHelper v2.31.0; e.g. 'ItemTable_Shadowhammer.lua'),
    blank / missing = ItemTable.lua. Loads, pop / rebuild writes, the
    header line and the backup/<file>.bak name all follow it.
  v4.17.1 (2026-11-21) - org respects PullFromBags (Mark): store_bag
    items are only gathered out of the other bags when PullFromBags =
    true; false (default) = only main-inventory copies are put away.
]]

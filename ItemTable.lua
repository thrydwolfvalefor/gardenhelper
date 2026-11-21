-- GardenHelper item table (ItemTable.lua) - YOUR settings, bag order and items.
-- Which file is used: characters.lua item_table (blank = ItemTable.lua).
-- One list for everything: //gh sell, drop, pop, send, rec, org (and //gh inv = all of them).
--
-- Edit freely: GardenHelper re-reads this file before every step, so no reload is needed.
-- Only //gh pop (when it adds new items) and //gh inv rebuild (re-sorts it after your edits)
-- rewrite this file - values you change are kept, comments you add yourself are not
-- (the previous version is saved as backup/ItemTable.lua.bak).
-- Mail tracking and step results live in Mail.lua, so the other steps never write this file.
-- If this file has a Lua syntax error, GardenHelper stops with an error and leaves it alone.
--
-- ITEM FIELDS    [id] = {name, type, action, mail_to, min_mail, min_save, mail_cap, store_bag, PullFromBags}
--   id / name = the item id and its name (//gh pop fills both in).
--   type      = grouping only - each action section is sorted into these groups (TYPES below).
--   action    = what happens to the item. The table is sorted by action, then type, then name:
--       ""       new - //gh pop adds items with a blank action at the top. Nothing is done with
--                them until you give them an action.
--       "save"   keep it. min_save > 0: the copies above min_save (every bag counted) are
--                mailed to mail_to by //gh send, or - no mail_to - sold by //gh sell
--                (only copies in main inventory, unless PullFromBags = true).
--                min_save = 0 = keep every copy.
--       "send"   //gh send mails it to mail_to once there are min_mail of it in main inventory
--                (min_save > 0: that many are kept back). PullFromBags = true: every bag
--                counted, and copies in the other bags are pulled into main inventory first.
--       "ignore" never sold, dropped, mailed or moved.
--       "sell"   //gh sell sells every copy in main inventory to the Green Thumb Moogle
--                (PullFromBags = true: every copy in every bag).
--       "drop"   //gh drop drops every copy in main inventory and passes it in the treasure
--                pool (PullFromBags = true: every copy in every bag). settings.auto_drop: also
--                done by itself the moment one lands in main inventory / drops.
--   mail_to   = character //gh send mails it to (yours or anyone else's). "" = never mailed.
--   min_mail  = mail once there are at least this many. At the stack size (default for new items):
--               only full stacks are mailed. Below it (e.g. 1): partial stacks go too.
--   min_save  = how many to keep (every bag counted). 0 = no limit (keep all).
--   mail_cap  = most copies mail_to should end up with (its findAll bags + mail still in its
--               Delivery Box). Once it has that many, //gh sell sells the extra instead of
--               mailing it; short of it, only the shortfall is mailed. 0 = ignored (no cap).
--               No findAll file for mail_to = unknown, so everything is mailed as usual.
--   store_bag = where //gh org puts it (action "save", or "send" on its mail_to character):
--       ""          not organized - it stays wherever it is.
--       a bag name  moved out of main inventory into that bag (PullFromBags = true: also
--                   gathered out of every other bag into it).
--       "bag_order" moved out of main inventory only, into the first bag_order bag with room.
--       "inventory" kept in main inventory (PullFromBags = true: pulled out of every other
--                   bag into main inventory too).
--   PullFromBags = false (default): //gh send, sell, drop and org only use the copies in main
--               inventory - the other bags are left alone.
--               true: the copies in the other bags (case, satchel, sack, wardrobes; Mog House
--               bags when they can be reached) are pulled into main inventory first, and every
--               bag counts toward min_mail.
--
-- PER-CHARACTER OVERRIDES    ["id:Character"] = {...}
--   A line keyed "id:Character" (e.g. ["4304:FishVFi"]) is used for that item on that character
--   instead of the [id] line; every other character uses the [id] line. Any field the override
--   line leaves out comes from the [id] line. One override line per character per item;
--   //gh inv rebuild keeps them right under their [id] line.
--
-- ACCEPTED BAG VALUES (store_bag = "..." and bag_order)
--   inventory, case, satchel, sack, safe, safe2, storage, locker, wardrobe, wardrobe2 ... wardrobe8, bag_order (store_bag only)
--   (safe, safe2, storage and locker are Mog House bags; wardrobes only hold equipment)
--
-- TYPES (each action section is grouped in this order; any other type follows A-Z)
--   Fish_unstackable  Fish that don't stack
--   Fish_stackable    Fish that stack (12 or 99)
--   Fish              Fish (sell / drop sections)
--   Wood              Logs, Lumber, Lbr.
--   Smith             Smithing ores/ingots/sheets (Iron, Steel, Darksteel, Adaman...)
--   Gold              Goldsmithing ores/ingots/sheets/gems (Gold, Silver, Mythril...)
--   Cloth             Cloths, Threads, cotton, cocoons
--   Leather           Hides, Skins, Leather
--   Bone              Bones, beaks, talons, shells, horns, fangs
--   Alchemy           Alchemy materials
--   Cook              Cooking ingredients (meat, eggs, vegetables, spices)
--   Food              Cooked food, anything eaten for a food buff
--   Medicine          Potions, Ethers, Elixirs, drops
--   Seeds             Seeds and other things to be planted, pots
--   Crystals          Crystals and clusters
--   Geode             Geodes, avatarites, fewells
--   Scroll            Spell scrolls
--   Weapon            Weapons
--   Armor             Armor
--   Gear              Any gear that can be worn
--   Craft             Crafting accessories/tools not specific to one craft
--   General           not really used right now

return {
    settings = {
        -- true: //gh send and //gh rec only LOG what they would do. Set false to mail for real.
        mail_dry_run = true,
        -- true: //gh sell only LOGS what it would sell (still visits the moogle).
        sell_dry_run = false,
        -- true: //gh drop (and auto_drop) only LOG what they would drop / pass.
        drop_dry_run = false,
        -- true: action = "drop" items are dropped the moment they land in main inventory and
        -- passed the moment they hit the treasure pool (off by default).
        auto_drop = false,
        -- Characters the whole inventory process skips (lowercase).
        skip_characters = {},
    },

    -- Bags for store_bag = "bag_order" - first bag with room wins.
    bag_order = {"case", "satchel", "safe2", "safe", "storage"},

    items = {
        -- Empty on purpose: this is the clean starter table that ships with GardenHelper.
        -- Run //gh pop on each character - every main-inventory item not listed yet is added here
        -- with action = "" (nothing is done with it) for you to review and give an action.
        --
        -- Tip: keep your filled-in table in its own file (e.g. ItemTable_YourName.lua) and set
        -- item_table = 'ItemTable_YourName.lua' in characters.lua, so a new release's ItemTable.lua
        -- never replaces your items.
    },
}

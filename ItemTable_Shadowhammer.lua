-- GardenHelper item table (ItemTable_Shadowhammer.lua) - YOUR settings, bag order and items.
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
        mail_dry_run = false,
        -- true: //gh sell only LOGS what it would sell (still visits the moogle).
        sell_dry_run = false,
        -- true: //gh drop (and auto_drop) only LOG what they would drop / pass.
        drop_dry_run = false,
        -- true: action = "drop" items are dropped the moment they land in main inventory and
        -- passed the moment they hit the treasure pool (off by default).
        auto_drop = true,
        -- Characters the whole inventory process skips (lowercase).
        skip_characters = {},
    },

    -- Bags for store_bag = "bag_order" - first bag with room wins.
    bag_order = {"case", "satchel", "safe2", "safe", "storage", "locker", "sack"},

    items = {


        -- ################################################################################################
        -- ################################################################################################
        -- ####                                                                                        ####
        -- ####   SAVE   (action = "save")  - kept; min_save > 0 = extra is mailed (mail_to) or sold   ####
        -- ####                                                                                        ####
        -- ################################################################################################
        -- ################################################################################################

        -- ---- Gold ----
        [2143]   = {name = "Mandrel", type = "Gold", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Cloth ----
        [1657]   = {name = "Bundling Twine", type = "Cloth", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "case", PullFromBags = false},

        -- ---- Bone ----
        [2927]   = {name = "Glavoid Shell", type = "Bone", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Cook ----
        [635]    = {name = "Win. Tea Leaves", type = "Cook", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Food ----
        [623]    = {name = "Bay Leaves", type = "Food", action = "save", mail_to = "FoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5190]   = {name = "Carbonara", type = "Food", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5933]   = {name = "D. Fruit au Lait", type = "Food", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4509]   = {name = "Distilled Water", type = "Food", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5781]   = {name = "Kitron Macaron", type = "Food", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = false},
        [4149]   = {name = "Panacea", type = "Food", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = false},
        [5759]   = {name = "Red Curry Bun", type = "Food", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4155]   = {name = "Remedy", type = "Food", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = false},

        -- ---- Medicine ----
        [4151]   = {name = "Echo Drops", type = "Medicine", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = false},
        [4144]   = {name = "Hi-Elixir", type = "Medicine", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4173]   = {name = "Hi-Reraiser", type = "Medicine", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4164]   = {name = "Prism Powder", type = "Medicine", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "case", PullFromBags = false},
        [4165]   = {name = "Silent Oil", type = "Medicine", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "case", PullFromBags = false},
        [5770]   = {name = "Super Reraiser", type = "Medicine", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Seeds ----
        [3983]   = {name = "Arborfruit Seed", type = "Seeds", action = "save", mail_to = "", min_mail = 12, min_save = 24, mail_cap = 0, store_bag = "inventory", PullFromBags = true},

        -- ---- Crystals ----
        [4111]   = {name = "Dark Cluster", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4103]   = {name = "Dark Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4107]   = {name = "Earth Cluster", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4099]   = {name = "Earth Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4096]   = {name = "Fire Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4097]   = {name = "Ice Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4102]   = {name = "Light Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4100]   = {name = "Lightng. Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4108]   = {name = "Lightning Cluster", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4109]   = {name = "Water Cluster", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4101]   = {name = "Water Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4106]   = {name = "Wind Cluster", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4098]   = {name = "Wind Crystal", type = "Crystals", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Scroll ----
        [4182]   = {name = "Instant Reraise", type = "Scroll", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [6697]   = {name = "Instant Reraise III", type = "Scroll", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4181]   = {name = "Instant Warp", type = "Scroll", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Weapon ----
        [17806]  = {name = "Asa-arashi", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [19192]  = {name = "Awilda's Gun", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18468]  = {name = "Bonanza Ball", type = "Weapon", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16836]  = {name = "Halberd", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe2", PullFromBags = false},
        [18620]  = {name = "Magnus Pole", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [19260]  = {name = "Raider's Bmrng.", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [19254]  = {name = "Tantra Tathlum", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [20906]  = {name = "Vunetshelo", type = "Weapon", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Armor ----
        [28618]  = {name = "Anchoret's Mantle", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11733]  = {name = "Aquiline Belt", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [28620]  = {name = "Bane Cape", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12345]  = {name = "Bloodbead Ecu", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11523]  = {name = "Brisk Mask", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [26164]  = {name = "Caliber Ring", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10293]  = {name = "Chocobo Shirt", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15763]  = {name = "Emperor Band", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [28470]  = {name = "Emporox's Ring", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "wardrobe6", PullFromBags = false},
        [16208]  = {name = "Lancer's Pelerine", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11558]  = {name = "Nifty Mantle", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [6614]   = {name = "Old Case", type = "Armor", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [25416]  = {name = "Sibyl Scarf", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [27421]  = {name = "Skulk. Poulaines", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [13852]  = {name = "Suijin Kabuto", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11430]  = {name = "Tandava Crackows", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11508]  = {name = "Tokon Hachimaki", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [25438]  = {name = "Wicce Earring", type = "Armor", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Craft ----
        [6506]   = {name = "Pyre Crystal", type = "Craft", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Abyssea ----
        [2641]   = {name = "Amb. Pseudopod", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2938]   = {name = "Bakka's Wing", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2890]   = {name = "Clionid Wing", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2923]   = {name = "Ctrice. Tailmeat", type = "Abyssea", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2490]   = {name = "Forbidden Key", type = "Abyssea", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [499]    = {name = "Gigas Necklace", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [497]    = {name = "Gigas Socks", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2915]   = {name = "H.Q. Cli. Wing", type = "Abyssea", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2916]   = {name = "H.Q. Lim. Pincer", type = "Abyssea", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3091]   = {name = "Hd. Raptor Skin", type = "Abyssea", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2889]   = {name = "Limule Pincer", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5682]   = {name = "Purple Polypore", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [2888]   = {name = "Sanguinet", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2924]   = {name = "Shk. Whisker", type = "Abyssea", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2894]   = {name = "Trophy Shield", type = "Abyssea", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2953]   = {name = "Viscous Spittle", type = "Abyssea", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Abyssea_pop ----
        [2918]   = {name = "Baleful Skull", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3103]   = {name = "Black Whisker", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3074]   = {name = "Blanched Silver", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3081]   = {name = "Coeurl Round", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3078]   = {name = "Cracked Drgscale.", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3079]   = {name = "Gory Pincer", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3268]   = {name = "H.Q. Wivre Hide", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3083]   = {name = "Mngl. Ck. Skin", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2640]   = {name = "Murex Spicule", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3090]   = {name = "Spheroid Plate", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3072]   = {name = "Withered Cocoon", type = "Abyssea_pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Abyssea_Trial ----
        [2934]   = {name = "Manan. Necklet", type = "Abyssea_Trial", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- ambu ----
        [9939]   = {name = "A. Chit: Body", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9942]   = {name = "A. Chit: Foot", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9940]   = {name = "A. Chit: Hand", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9938]   = {name = "A. Chit: Head", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9941]   = {name = "A. Chit: Leg", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9948]   = {name = "A. Chit: Ring", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9937]   = {name = "A. Voucher: Replica", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9780]   = {name = "A. Voucher: Weapon", type = "ambu", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Ambu ----
        [9271]   = {name = "Abdhaljs Fiber", type = "Ambu", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9783]   = {name = "Abdhaljs Gem", type = "Ambu", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [9270]   = {name = "Abdhaljs Metal", type = "Ambu", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- ambu ----
        [9782]   = {name = "Abdhaljs Nugget", type = "ambu", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Ambu ----
        [6500]   = {name = "Abdhaljs Seal", type = "Ambu", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- BCNM ----
        [1126]   = {name = "Beastmen's Seal", type = "BCNM", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [2956]   = {name = "H. Kindred Crest", type = "BCNM", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2955]   = {name = "Kindred's Crest", type = "BCNM", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [1127]   = {name = "Kindred's Seal", type = "BCNM", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [2957]   = {name = "S. Kindred Crest", type = "BCNM", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},

        -- ---- Chocobo ----
        [5606]   = {name = "Azouph Greens", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2206]   = {name = "Chocolixir", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2402]   = {name = "CRA Racing Form", type = "Chocobo", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [534]    = {name = "Gausebit Grass", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2205]   = {name = "Gregar. Worm", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4545]   = {name = "Gysahl Greens", type = "Chocobo", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2345]   = {name = "Hi-Chocolixir", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2403]   = {name = "R Chocotrain: STR", type = "Chocobo", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2389]   = {name = "Speed Apple", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2201]   = {name = "Toko. Wildgrass", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5607]   = {name = "Vomp Carrot", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5608]   = {name = "Zegham Carrot", type = "Chocobo", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Delve ----
        [4013]   = {name = "Waktza Crest", type = "Delve", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Empyrean ----
        [3217]   = {name = "Ardor Card", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3184]   = {name = "Caller Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3204]   = {name = "Caller's Seal: Ft.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3188]   = {name = "Charis Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3127]   = {name = "Cirque Seal: Hd.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3187]   = {name = "Cirque Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3174]   = {name = "Estq. Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3178]   = {name = "Ferine Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3113]   = {name = "Goetia Seal: Hd.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3182]   = {name = "Iga Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3492]   = {name = "Kaggen's Cuticle", type = "Empyrean", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3185]   = {name = "Mavi Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3186]   = {name = "Nvrch. Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3192]   = {name = "Orison Seal: Ft.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3112]   = {name = "Orison Seal: Hd.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3172]   = {name = "Orison Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3195]   = {name = "Raid. Seal: Ft.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3175]   = {name = "Raid. Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3190]   = {name = "Rvg. Seal: Ft.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3170]   = {name = "Rvg. Seal: Lg.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3121]   = {name = "Unkai Seal: Hd.", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3213]   = {name = "Vision Card", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3211]   = {name = "Vision Coin", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3210]   = {name = "Vision Stone", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3229]   = {name = "Voyage Card", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3221]   = {name = "Wieldance Card", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3220]   = {name = "Wieldance Jewel", type = "Empyrean", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Fishing ----
        [17006]  = {name = "Drill Calamary", type = "Fishing", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "wardrobe5", PullFromBags = false},
        [17007]  = {name = "Dwarf Pugil", type = "Fishing", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "wardrobe5", PullFromBags = false},

        -- ---- Furniture ----
        [1602]   = {name = "Mannequin Body", type = "Furniture", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1605]   = {name = "Mannequin Feet", type = "Furniture", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1603]   = {name = "Mannequin Hands", type = "Furniture", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1601]   = {name = "Mannequin Head", type = "Furniture", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1604]   = {name = "Mannequin Legs", type = "Furniture", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3584]   = {name = "Panetiere", type = "Furniture", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Garden ----
        [4010]   = {name = "Coalition Chum", type = "Garden", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3990]   = {name = "Coalition Humus", type = "Garden", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4048]   = {name = "Dragoneye", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [8929]   = {name = "Dung", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4050]   = {name = "Fat Burrow Worm", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3988]   = {name = "Garden Worm", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3991]   = {name = "Grove Worm", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [4011]   = {name = "Grow-M-Good", type = "Garden", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [5810]   = {name = "Moat Carp Creel", type = "Garden", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17869]  = {name = "Rich Humus", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4049]   = {name = "Rusted Coin", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4006]   = {name = "Sardine Chum", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [4001]   = {name = "Sardine Sphere", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3996]   = {name = "Stone Serum", type = "Garden", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- item ----
        [1021]   = {name = "Hatchet", type = "item", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "case", PullFromBags = false},

        -- ---- Item ----
        [605]    = {name = "Pickaxe", type = "Item", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- NM Pop ----
        [1423]   = {name = "Autumnstone", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3341]   = {name = "Beastly Shank", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3343]   = {name = "Blue Pondweed", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1418]   = {name = "Gem of the East", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1424]   = {name = "Gem of the North", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1420]   = {name = "Gem of the South", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1422]   = {name = "Gem of the West", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [3339]   = {name = "Honey Wine", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [2564]   = {name = "Peiste Pellets", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1823]   = {name = "Shrimp Lantern", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1419]   = {name = "Springstone", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1421]   = {name = "Summerstone", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1425]   = {name = "Winterstone", type = "NM Pop", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Quest ----
        [1873]   = {name = "Brigand's Chart", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1434]   = {name = "Bst. Testimony", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1125]   = {name = "Carbuncle's Ruby", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1662]   = {name = "Ctdl. Tapestry", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [1024]   = {name = "Gls. Chest Key", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1684]   = {name = "Gold Key", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [597]    = {name = "Mine Gravel", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1428]   = {name = "Whm. Testimony", type = "Quest", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Reforged ----
        [4070]   = {name = "Rem's Tale Ch.7", type = "Reforged", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},

        -- ---- REMA ----
        [4060]   = {name = "Beitetsu", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = false},
        [6367]   = {name = "Codex of Etchings", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [2605]   = {name = "Coin of Glory", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [9929]   = {name = "Eikondrite", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [9009]   = {name = "Etched Memory", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [2931]   = {name = "Fistl. Discharge", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4072]   = {name = "Rem's Tale Ch.9", type = "REMA", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [3979]   = {name = "Rockfin Tooth", type = "REMA", action = "save", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Special ----
        [8711]   = {name = "Copper Voucher", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "satchel", PullFromBags = false},
        [4247]   = {name = "Miratete's Mem.", type = "Special", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9158]   = {name = "Mog Pell (Ochre)", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [8714]   = {name = "Mog Pell (Red)", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [10000]  = {name = "Murky Matter", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10008]  = {name = "Shard of Bravery", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9277]   = {name = "Silver Voucher", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [8930]   = {name = "Snowslit Stone", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8973]   = {name = "SP Gobbie Key", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [6716]   = {name = "Trust Primer", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [6717]   = {name = "Trust Tome", type = "Special", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Vagry ----
        [9008]   = {name = "Befouled Water", type = "Vagry", action = "save", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Voidwatch ----
        [3434]   = {name = "Cobalt Cell", type = "Voidwatch", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3508]   = {name = "Crystal Petrifact", type = "Voidwatch", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3853]   = {name = "Phase Displacer", type = "Voidwatch", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3435]   = {name = "Rubicund Cell", type = "Voidwatch", action = "save", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},


        -- ################################################################################################
        -- ################################################################################################
        -- ####                                                                                        ####
        -- ####   SEND   (action = "send")  - mailed to mail_to once there are min_mail of them (main inventory only)####
        -- ####                                                                                        ####
        -- ################################################################################################
        -- ################################################################################################

        -- ---- Fish_stackable ----
        [5954]   = {name = "Barnacle", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [4461]   = {name = "Bastore Bream", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [4429]   = {name = "Black Eel", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [5138]   = {name = "Black Ghost", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [5948]   = {name = "Black Prawn", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [4384]   = {name = "Black Sole", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [5951]   = {name = "Bloodblotch", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [4500]   = {name = "Greedie", type = "Fish_stackable", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [5960]   = {name = "Ulbukan Lobster", type = "Fish_stackable", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},

        -- ---- Fish ----
        [5818]   = {name = "Aurora Bass", type = "Fish", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4454]   = {name = "Emperor Fish", type = "Fish", action = "send", mail_to = "FishVF", min_mail = 1, min_save = 0, mail_cap = 24, store_bag = "bag_order", PullFromBags = false},
        [4304]   = {name = "Grimmonite", type = "Fish", action = "send", mail_to = "FishVFi", min_mail = 1, min_save = 0, mail_cap = 24, store_bag = "bag_order", PullFromBags = false},
        [5468]   = {name = "Matsya", type = "Fish", action = "send", mail_to = "FishVF", min_mail = 1, min_save = 0, mail_cap = 24, store_bag = "bag_order", PullFromBags = false},
        [5134]   = {name = "Mola Mola", type = "Fish", action = "send", mail_to = "FishVF", min_mail = 1, min_save = 0, mail_cap = 6, store_bag = "bag_order", PullFromBags = false},

        -- ---- Wood ----
        [729]    = {name = "Bloodwood Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [9245]   = {name = "Cypress Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [722]    = {name = "Divine Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [702]    = {name = "Ebony Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [719]    = {name = "Ebony Lumber", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [690]    = {name = "Elm Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [8725]   = {name = "Exalted Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4018]   = {name = "Guatambu Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2534]   = {name = "Jacaranda Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1446]   = {name = "Lacquer Tree Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1464]   = {name = "Lancewood Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [717]    = {name = "Mahogany Lbr.", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [700]    = {name = "Mahogany Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [703]    = {name = "Petrified Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [701]    = {name = "Rosewood Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [2532]   = {name = "Teak Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [3926]   = {name = "Urunday Log", type = "Wood", action = "send", mail_to = "WoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Smith ----
        [646]    = {name = "Adaman Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [908]    = {name = "Adamantoise Shell", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [4058]   = {name = "Bismuth Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [654]    = {name = "Darksteel Ingot", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [645]    = {name = "Darksteel Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1228]   = {name = "Dst. Nugget", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- smith ----
        [756]    = {name = "Durium Ore", type = "smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Smith ----
        [643]    = {name = "Iron Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [685]    = {name = "Khroma Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1711]   = {name = "Molybden. Ingot", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [8747]   = {name = "Ra'Kaznar Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [1466]   = {name = "Relic Iron", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2763]   = {name = "Swamp Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4020]   = {name = "Titanium Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [3920]   = {name = "Vanadium Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1469]   = {name = "Wootz Ore", type = "Smith", action = "send", mail_to = "SmithVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Gold ----
        [678]    = {name = "Aluminum Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1262]   = {name = "Dark Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1258]   = {name = "Earth Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1255]   = {name = "Fire Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [745]    = {name = "Gold Ingot", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [737]    = {name = "Gold Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1256]   = {name = "Ice Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1261]   = {name = "Light Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1259]   = {name = "Lightning Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [739]    = {name = "Orichalcum Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [740]    = {name = "Phrygian Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [746]    = {name = "Platinum Ingot", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [738]    = {name = "Platinum Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [3922]   = {name = "Rhodium Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [3521]   = {name = "Shivite", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [744]    = {name = "Silver Ingot", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [736]    = {name = "Silver Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1470]   = {name = "Sparkling Stone", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1260]   = {name = "Water Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1257]   = {name = "Wind Ore", type = "Gold", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Cloth ----
        [4028]   = {name = "Akaso Cloth", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4027]   = {name = "Akaso Thread", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1294]   = {name = "Arachne Thread", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [825]    = {name = "Cotton Cloth", type = "Cloth", action = "send", mail_to = "clothvf", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [818]    = {name = "Cotton Thread", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [819]    = {name = "Linen Thread", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [529]    = {name = "Luminicloth", type = "Cloth", action = "send", mail_to = "Clothvf", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1964]   = {name = "Mag. Lin. Cloth", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1651]   = {name = "Moblin Thread", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1826]   = {name = "Opal Silk", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [844]    = {name = "Phoenix Feather", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2476]   = {name = "Platinum Silk", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [830]    = {name = "Rainbow Cloth", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1132]   = {name = "Raxa", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1997]   = {name = "Sailcloth", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [816]    = {name = "Silk Thread", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [838]    = {name = "Spider Web", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2200]   = {name = "Twill Damask", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2289]   = {name = "Wamoura Cloth", type = "Cloth", action = "send", mail_to = "ClothVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Leather ----
        [1312]   = {name = "Angel Skin", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [862]    = {name = "Behem. Leather", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [860]    = {name = "Behemoth Hide", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1628]   = {name = "Buffalo Hide", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [863]    = {name = "Coeurl Hide", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [848]    = {name = "Dhalmel Leather", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1516]   = {name = "Griffon Hide", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1680]   = {name = "H.Q. Bugard Skin", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1741]   = {name = "H.Q. Eft Skin", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2703]   = {name = "Khrom. Leather", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2007]   = {name = "Lm. Bf. Leather", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [851]    = {name = "Ram Leather", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [855]    = {name = "Tiger Leather", type = "Leather", action = "send", mail_to = "LeatherVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Bone ----
        [1622]   = {name = "Bugard Tusk", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [887]    = {name = "Coral Fragment", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = true},
        [867]    = {name = "Dragon Scales", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [903]    = {name = "Dragon Talon", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1193]   = {name = "H.Q. Crab Shell", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [9047]   = {name = "Immani. Hide", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [869]    = {name = "Lizard Molt", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [1586]   = {name = "Titanictus Shell", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [901]    = {name = "Venomous Claw", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [866]    = {name = "Wyvern Scales", type = "Bone", action = "send", mail_to = "BoneVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Alchemy ----
        [932]    = {name = "Carbon Fiber", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1133]   = {name = "Dragon Blood", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [5984]   = {name = "Gnatbane", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = true},
        [1309]   = {name = "Gold Leaf", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1613]   = {name = "Malevolent Mem.", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [918]    = {name = "Mistletoe", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1308]   = {name = "Mythril Leaf", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1310]   = {name = "Platinum Leaf", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2712]   = {name = "Red Textile Dye", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4508]   = {name = "Royal Jelly", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1307]   = {name = "Silver Leaf", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [3930]   = {name = "Twitherym Wing", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [3935]   = {name = "Umbril Ooze", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [2709]   = {name = "White Text. Dye", type = "Alchemy", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Cook ----
        [5651]   = {name = "Burdock", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [2203]   = {name = "Cupid Worm", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [5662]   = {name = "Dragon Fruit", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [2645]   = {name = "Eastern Ginger", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1522]   = {name = "Fresh Marjoram", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [1524]   = {name = "Fresh Mugwort", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [5564]   = {name = "Hydra Meat", type = "Cook", action = "send", mail_to = "cookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4386]   = {name = "King Truffle", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4361]   = {name = "Nebimonite", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [5661]   = {name = "Walnut", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 72, store_bag = "bag_order", PullFromBags = false},
        [5562]   = {name = "White Honey", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [5907]   = {name = "Winterflower", type = "Cook", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},

        -- ---- Food ----
        [4511]   = {name = "Ambrosia", type = "Food", action = "send", mail_to = "FoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4513]   = {name = "Amrita", type = "Food", action = "send", mail_to = "FoodVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [5668]   = {name = "Smilodon Liver", type = "Food", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- _Myth ----
        [5964]   = {name = "Felicifruit", type = "_Myth", action = "send", mail_to = "Mythrandiir", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4273]   = {name = "Kitron", type = "_Myth", action = "send", mail_to = "Mythrandiir", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = true},
        [4274]   = {name = "Persikos", type = "_Myth", action = "send", mail_to = "Mythrandiir", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4402]   = {name = "Red Terrapin", type = "_Myth", action = "send", mail_to = "Mythrandiir", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- _Vayne ----
        [4401]   = {name = "Moat Carp", type = "_Vayne", action = "send", mail_to = "Vayne", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Beastmen ----
        [748]    = {name = "Gold Beastcoin", type = "Beastmen", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [750]    = {name = "Silver Beastcoin", type = "Beastmen", action = "send", mail_to = "GoldVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Furniture ----
        [364]    = {name = "Amiga Cactus", type = "Furniture", action = "send", mail_to = "GenPopVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [55]     = {name = "Cabinet", type = "Furniture", action = "send", mail_to = "GenPopVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [356]    = {name = "Guild Flyers", type = "Furniture", action = "send", mail_to = "GenPopVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},

        -- ---- Quest ----
        [4395]   = {name = "Galkan Sausage", type = "Quest", action = "send", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- REMA ----
        [1455]   = {name = "1 Byne Bill", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [1456]   = {name = "100 Byne Bill", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [2488]   = {name = "Alexandrite", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [3222]   = {name = "Balance Stone", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = true},
        [6181]   = {name = "Beitetsu Parcel", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [6182]   = {name = "Boulder Case", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [2933]   = {name = "Chukwa's Egg", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = true},
        [3509]   = {name = "Heavy Metal", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = true},
        [1450]   = {name = "L. Jadeshell", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [1452]   = {name = "O. Bronzepiece", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = false},
        [4059]   = {name = "Pluton", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [6180]   = {name = "Pluton Case", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [4061]   = {name = "Riftborn Boulder", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},
        [1018]   = {name = "Shaman Garlic", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = true},
        [1449]   = {name = "T. Whiteshell", type = "REMA", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "sack", PullFromBags = true},

        -- ---- Seed ----
        [1236]   = {name = "Cactus Stems", type = "Seed", action = "send", mail_to = "SeedsVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [940]    = {name = "Revival Root", type = "Seed", action = "send", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [953]    = {name = "Treant Bulb", type = "Seed", action = "send", mail_to = "SeedsVF", min_mail = 1, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},
        [1238]   = {name = "Tree Saplings", type = "Seed", action = "send", mail_to = "SeedsVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},

        -- ---- Sortie ----
        [9927]   = {name = "Ra'Kaz. Sapphire", type = "Sortie", action = "send", mail_to = "Shadowhammer", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},


        -- ################################################################################################
        -- ################################################################################################
        -- ####                                                                                        ####
        -- ####   SELL   (action = "sell")  - sold to the Green Thumb Moogle by //gh sell              ####
        -- ####                                                                                        ####
        -- ################################################################################################
        -- ################################################################################################

        -- ---- Fish_stackable ----
        [4360]   = {name = "Bastore Sardine", type = "Fish_stackable", action = "sell", mail_to = "", min_mail = 3, min_save = 0, mail_cap = 36, store_bag = "bag_order", PullFromBags = false},

        -- ---- Fish ----
        [5534]   = {name = "Apkallufa", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4479]   = {name = "Bhefhel Marlin", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4399]   = {name = "Bluetail", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5469]   = {name = "Brass Loach", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5474]   = {name = "Ca Cuong", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5715]   = {name = "Calico Comet", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4443]   = {name = "Cobalt Jellyfish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5128]   = {name = "Cone Calamary", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5961]   = {name = "Contortopus", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4515]   = {name = "Copper Frog", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4472]   = {name = "Crayfish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4473]   = {name = "Crescent Fish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4428]   = {name = "Dark Bass", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5959]   = {name = "Dragonfish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [6145]   = {name = "Dwarf Remora", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4579]   = {name = "Elshimo Newt", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4477]   = {name = "Gavial Fish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4469]   = {name = "Giant Catfish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4474]   = {name = "Gigant Squid", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4427]   = {name = "Gold Carp", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4480]   = {name = "Gugru Tuna", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2216]   = {name = "Lamp Marimo", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5129]   = {name = "Lik", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5950]   = {name = "Mackerel", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5467]   = {name = "Megalodon", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5121]   = {name = "Moorish Idol", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4464]   = {name = "Pipira", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4514]   = {name = "Quus", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [6146]   = {name = "Remora", type = "Fish", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5952]   = {name = "Ruddy Seema", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4305]   = {name = "Ryugu Titan", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4475]   = {name = "Sea Zombie", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5963]   = {name = "Senroh Sardine", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4484]   = {name = "Shall Shell", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4478]   = {name = "Three-eyed Fish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4310]   = {name = "Tiny Goldfish", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4476]   = {name = "Titanictus", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1618]   = {name = "Uragnite Shell", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5141]   = {name = "Veydal Wrasse", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5463]   = {name = "Yayinbaligi", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5536]   = {name = "Yorchete", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4288]   = {name = "Zebra Eel", type = "Fish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Wood ----
        [688]    = {name = "Arrowwood Log", type = "Wood", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [698]    = {name = "Ash Log", type = "Wood", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10014]  = {name = "Ash Wood", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [694]    = {name = "Chestnut Log", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [727]    = {name = "Dogwood Log", type = "Wood", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1672]   = {name = "Exor. Oak Lbr.", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2749]   = {name = "Gargouille Eye", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [689]    = {name = "Lauan Log", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [706]    = {name = "Lauan Lumber", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [691]    = {name = "Maple Log", type = "Wood", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [699]    = {name = "Oak Log", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1283]   = {name = "Ose Whisker", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [693]    = {name = "Walnut Log", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1414]   = {name = "Wisteria Lumber", type = "Wood", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Smith ----
        [2765]   = {name = "Fool's Gold Ore", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2290]   = {name = "Imperial Cermet", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2823]   = {name = "Iridium", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1155]   = {name = "Iron Sand", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1650]   = {name = "Kopparnickel Ore", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9053]   = {name = "Platinum Gear", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10011]  = {name = "Tellurium Ingot", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [641]    = {name = "Tin Ore", type = "Smith", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Gold ----
        [2417]   = {name = "Aht Urhgan Brass", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [813]    = {name = "Angelstone", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [791]    = {name = "Aquamarine", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2305]   = {name = "Auric Sand", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10012]  = {name = "Black Jadeite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [775]    = {name = "Black Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [770]    = {name = "Blue Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [801]    = {name = "Chrysoberyl", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [809]    = {name = "Clear Topaz", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [640]    = {name = "Copper Ore", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [812]    = {name = "Deathstone", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [785]    = {name = "Emerald", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [810]    = {name = "Fluorite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [808]    = {name = "Goshenite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1465]   = {name = "Granite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [772]    = {name = "Green Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1654]   = {name = "Igneous Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [784]    = {name = "Jadeite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8719]   = {name = "Maliya. Coral", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3921]   = {name = "Marble Nugget", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [582]    = {name = "Meteorite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [802]    = {name = "Moonstone", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [653]    = {name = "Mythril Ingot", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [644]    = {name = "Mythril Ore", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [797]    = {name = "Painite", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [751]    = {name = "Plt. Beastcoin", type = "Gold", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [774]    = {name = "Purple Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [769]    = {name = "Red Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [786]    = {name = "Ruby", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1649]   = {name = "Scarlet Stone", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [803]    = {name = "Sunstone", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [773]    = {name = "Translucent Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [776]    = {name = "White Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [771]    = {name = "Yellow Rock", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [642]    = {name = "Zinc Ore", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [805]    = {name = "Zircon", type = "Gold", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Cloth ----
        [4026]   = {name = "Akaso", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2149]   = {name = "Apkallu Feather", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [847]    = {name = "Bird Feather", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1700]   = {name = "Bloodthread", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3941]   = {name = "Chapuli Wing", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [840]    = {name = "Chocobo Fthr.", type = "Cloth", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2150]   = {name = "Colibri Feather", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [839]    = {name = "Crawler Cocoon", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1967]   = {name = "Dull Gold Thread", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2713]   = {name = "Dyer's Woad", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [835]    = {name = "Flax Flower", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1417]   = {name = "G. Bird Fltchg.", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [843]    = {name = "G. Bird Plume", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [842]    = {name = "Giant Bird Fthr.", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2522]   = {name = "Gnat Wing", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [817]    = {name = "Grass Thread", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2778]   = {name = "Inferior Cocoon", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2372]   = {name = "Khimaira Mane", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1163]   = {name = "Manticore Hair", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2166]   = {name = "Marid Hair", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2274]   = {name = "Mohbwa Cloth", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [833]    = {name = "Moko Grass", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9147]   = {name = "Porxie Wing", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2148]   = {name = "Puk Wing", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1828]   = {name = "Red Grs. Thread", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1845]   = {name = "Red Moko Grass", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [834]    = {name = "Saruta Cotton", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1313]   = {name = "Siren's Hair", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4016]   = {name = "Tulfaire Feather", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3948]   = {name = "Tulfaire Fltchg.", type = "Cloth", action = "sell", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10013]  = {name = "Vicuna Cloth", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2198]   = {name = "W. Spider's Web", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2011]   = {name = "Wolf Fur", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [841]    = {name = "Yagudo Feather", type = "Cloth", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Leather ----
        [1640]   = {name = "Bugard Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2124]   = {name = "Catobl. Leather", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2169]   = {name = "Cerberus Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [854]    = {name = "Cockatrice Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [857]    = {name = "Dhalmel Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1623]   = {name = "Eft Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2189]   = {name = "Fiendish Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [878]    = {name = "Karakul Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1869]   = {name = "Lamia Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [852]    = {name = "Lizard Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1116]   = {name = "Manticore Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2151]   = {name = "Marid Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2523]   = {name = "Peiste Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8707]   = {name = "Raaz Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [856]    = {name = "Rabbit Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [859]    = {name = "Ram Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [853]    = {name = "Raptor Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [850]    = {name = "Sheep Leather", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [505]    = {name = "Sheepskin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2518]   = {name = "Smilodon Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [861]    = {name = "Tiger Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [849]    = {name = "Undead Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10015]  = {name = "Wh. Serp. Leather", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [858]    = {name = "Wolf Hide", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1122]   = {name = "Wyvern Skin", type = "Leather", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Bone ----
        [2496]   = {name = "Anc. Beast Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1118]   = {name = "Antican Pauldron", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1616]   = {name = "Antlion Jaw", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [894]    = {name = "Beetle Jaw", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [889]    = {name = "Beetle Shell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [883]    = {name = "Behemoth Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [884]    = {name = "Blk. Tiger Fang", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3940]   = {name = "Carrier Crab Crpc.", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3932]   = {name = "Chapuli Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [898]    = {name = "Chicken Bone", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2171]   = {name = "Colibri Beak", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1518]   = {name = "Colossal Skull", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [881]    = {name = "Crab Shell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3933]   = {name = "Craklaw Pincer", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [902]    = {name = "Demon Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1165]   = {name = "Doll Shard", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9029]   = {name = "Douma's Shard", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1771]   = {name = "Dragon Bone", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [900]    = {name = "Fish Bones", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2748]   = {name = "Garglle. Shank", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2747]   = {name = "Gargouille Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [893]    = {name = "Giant Femur", type = "Bone", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [904]    = {name = "Giant Fish Bones", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1473]   = {name = "H.Q. Scp. Shell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2158]   = {name = "Hydra Fang", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2157]   = {name = "Imp Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2506]   = {name = "Ladybug Wing", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1123]   = {name = "Manticore Fang", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3939]   = {name = "Mantid Carapace", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2147]   = {name = "Marid Tusk", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3934]   = {name = "Matamata Shell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8980]   = {name = "Ninlil's Bone", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1770]   = {name = "Oversized Fang", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [868]    = {name = "Pugil Scales", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8709]   = {name = "Raaz Tusk", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [895]    = {name = "Ram Horn", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2754]   = {name = "Ruszor Fang", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1015]   = {name = "Sand Bat Fang", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [897]    = {name = "Scorpion Claw", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [896]    = {name = "Scorpion Shell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [888]    = {name = "Seashell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [882]    = {name = "Sheep Tooth", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17306]  = {name = "Snoll Arm", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1119]   = {name = "Tonberry Coat", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1162]   = {name = "Tonberry Lantern", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [885]    = {name = "Turtle Shell", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10016]  = {name = "Wh. Drag. Scale", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2427]   = {name = "Wivre Maul", type = "Bone", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Alchemy ----
        [3936]   = {name = "Acuex Poison", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5680]   = {name = "Agaricus", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [921]    = {name = "Ahriman Tears", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [935]    = {name = "Ahriman Wing", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [937]    = {name = "Animal Glue", type = "Alchemy", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1109]   = {name = "Artificial Lens", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1626]   = {name = "Avatar Blood", type = "Alchemy", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1110]   = {name = "Beetle Blood", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2014]   = {name = "Bird Blood", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [919]    = {name = "Boyahda Moss", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17342]  = {name = "Cannon Shell", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2229]   = {name = "Chimera Blood", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4450]   = {name = "Coral Fungus", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1156]   = {name = "Crawler Calculus", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1444]   = {name = "Divine Sap", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [923]    = {name = "Dryad Root", type = "Alchemy", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [768]    = {name = "Flint Stone", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1617]   = {name = "Flytrap Leaf", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1264]   = {name = "Grt. Boyahda Moss", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [939]    = {name = "Hecteyes Eye", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5985]   = {name = "Hemlock", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1669]   = {name = "Hoary Bomb Ash", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4154]   = {name = "Holy Water", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10017]  = {name = "Hydro Oil", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2163]   = {name = "Imp Wing", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2563]   = {name = "Karugo Clay", type = "Alchemy", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [531]    = {name = "Lanolin", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1979]   = {name = "Leech Saliva", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2155]   = {name = "Lesser Chigoe", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3942]   = {name = "Loc. Elutriator", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [954]    = {name = "Magic Pot Shard", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2805]   = {name = "Mordant 45", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1983]   = {name = "Mushrm. Locust", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8984]   = {name = "Orcfeltrap's Leaf", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [942]    = {name = "Phil. Stone", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [952]    = {name = "Poison Flour", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2514]   = {name = "Rafflesia Petal", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2513]   = {name = "Rafflesia Vine", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4449]   = {name = "Reishi Mushroom", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1886]   = {name = "Sieglinde Putty", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4374]   = {name = "Sleepshroom", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1521]   = {name = "Slime Juice", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [637]    = {name = "Slime Oil", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4031]   = {name = "Snap. Secretion", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4032]   = {name = "Snap. Tendril", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2335]   = {name = "Soulfl. Tentacle", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1108]   = {name = "Sulfur", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2323]   = {name = "Tact. Processor", type = "Alchemy", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [915]    = {name = "Toad Oil", type = "Alchemy", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4425]   = {name = "Tomato Juice", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4373]   = {name = "Woozyshroom", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1124]   = {name = "Wyvern Wing", type = "Alchemy", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Cook ----
        [4504]   = {name = "Acorn", type = "Cook", action = "sell", mail_to = "CookVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [3965]   = {name = "Adoulinian Kelp", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2503]   = {name = "Almond", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5568]   = {name = "Apkallu Egg", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2771]   = {name = "Bell Cricket", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4570]   = {name = "Bird Egg", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [626]    = {name = "Black Pepper", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [618]    = {name = "Blue Peas", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5152]   = {name = "Buffalo Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5465]   = {name = "Caedarva Frog", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5565]   = {name = "Cerberus Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [636]    = {name = "Chamomile", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [639]    = {name = "Chestnut", type = "Cook", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4435]   = {name = "Cockatrice Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4377]   = {name = "Coeurl Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4357]   = {name = "Crawler Egg", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5566]   = {name = "Date", type = "Cook", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [4359]   = {name = "Dhalmel Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4272]   = {name = "Dragon Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5604]   = {name = "El. Pachira Fruit", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4363]   = {name = "Faerie Apple", type = "Cook", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2175]   = {name = "Flan Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2408]   = {name = "Flocon-de-mer", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4372]   = {name = "G. Sheep Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1695]   = {name = "Habaneros", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4358]   = {name = "Hare Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4370]   = {name = "Honey", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5571]   = {name = "Karakul Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [612]    = {name = "Kazham Peppers", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4432]   = {name = "Kazham Pineapl.", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1982]   = {name = "King Locust", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [632]    = {name = "Kukuru Bean", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4366]   = {name = "La Theine Cbg.", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4400]   = {name = "Land Crab Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4362]   = {name = "Lizard Egg", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [926]    = {name = "Lizard Tail", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5531]   = {name = "Lucerewe Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [614]    = {name = "Mhaura Garlic", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [629]    = {name = "Millioncorn", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5235]   = {name = "Napa", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5650]   = {name = "Nopales", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [630]    = {name = "Ogre Pumpkin", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4468]   = {name = "Pamamas", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [938]    = {name = "Papaka Grass", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2213]   = {name = "Pine Nuts", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4448]   = {name = "Puffball", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5569]   = {name = "Puk Egg", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [936]    = {name = "Rock Salt", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4365]   = {name = "Rolanberry", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16995]  = {name = "Rotten Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5755]   = {name = "Ruszor Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [611]    = {name = "Rye Flour", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [638]    = {name = "Sage", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [610]    = {name = "San d'Or. Flour", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4392]   = {name = "Saruta Orange", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1840]   = {name = "Semolina", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5605]   = {name = "Sharug Greens", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1981]   = {name = "Skull Locust", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1984]   = {name = "Snapping Mole", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [620]    = {name = "Tarutaru Rice", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5966]   = {name = "Ulbuconut", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5703]   = {name = "Uleguerand Milk", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2112]   = {name = "Vanilla", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [6222]   = {name = "Warthog Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4491]   = {name = "Watermelon", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [951]    = {name = "Wijnruit", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4387]   = {name = "Wild Onion", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4445]   = {name = "Yagudo Cherry", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4558]   = {name = "Yagudo Drink", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5581]   = {name = "Ziz Meat", type = "Cook", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Food ----
        [4300]   = {name = "Apple au Lait", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4413]   = {name = "Apple Pie", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4542]   = {name = "Brain Stew", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5196]   = {name = "Buffalo Jerky", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4548]   = {name = "Coeurl Saute", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4411]   = {name = "Dhalmel Pie", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4433]   = {name = "Dhalmel Stew", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4350]   = {name = "Dragon Steak", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4388]   = {name = "Eggplant", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4398]   = {name = "Fish Mithkabob", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4276]   = {name = "Flint Caviar", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5143]   = {name = "Goblin Stir-Fry", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5146]   = {name = "Hedgehog Pie", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4376]   = {name = "Meat Jerky", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4424]   = {name = "Melon Juice", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4421]   = {name = "Melon Pie", type = "Food", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5676]   = {name = "Mushroom Saute", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4439]   = {name = "Navarin", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4422]   = {name = "Orange Juice", type = "Food", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4302]   = {name = "Pamama au Lait", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5752]   = {name = "Pot-au-feu", type = "Food", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4446]   = {name = "Pumpkin Pie", type = "Food", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5685]   = {name = "Rabbit Pie", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4444]   = {name = "Rarab Tail", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4410]   = {name = "Roast Mushroom", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4414]   = {name = "Rolanberry Pie", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5737]   = {name = "Salted Hare", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5885]   = {name = "Saltena", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4565]   = {name = "Sobbing Fungus", type = "Food", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4279]   = {name = "Tavnazian Salad", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4512]   = {name = "Vampire Juice", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5579]   = {name = "Yayla Corbasi", type = "Food", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Medicine ----
        [4205]   = {name = "Agility Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3974]   = {name = "Airlixir", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3975]   = {name = "Airlixir +1", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4153]   = {name = "Antacid", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4148]   = {name = "Antidote", type = "Medicine", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4211]   = {name = "Charisma Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5411]   = {name = "Dawn Mulsum", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4201]   = {name = "Dexterity Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4145]   = {name = "Elixir", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5355]   = {name = "Elixir Vitae", type = "Medicine", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9084]   = {name = "Eschalixir", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [9085]   = {name = "Eschalixir +1", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4128]   = {name = "Ether", type = "Medicine", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4150]   = {name = "Eye Drops", type = "Medicine", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4132]   = {name = "Hi-Ether", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4133]   = {name = "Hi-Ether +1", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4134]   = {name = "Hi-Ether +2", type = "Medicine", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4135]   = {name = "Hi-Ether +3", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4116]   = {name = "Hi-Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4117]   = {name = "Hi-Potion +1", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4118]   = {name = "Hi-Potion +2", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4119]   = {name = "Hi-Potion +3", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5255]   = {name = "Hyper Ether", type = "Medicine", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4207]   = {name = "Int. Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4209]   = {name = "Mind Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4159]   = {name = "Paralyze Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4112]   = {name = "Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4113]   = {name = "Potion +1", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4114]   = {name = "Potion +2", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4140]   = {name = "Pro-Ether", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4199]   = {name = "Strength Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4136]   = {name = "Super Ether", type = "Medicine", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4138]   = {name = "Super Ether +2", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4203]   = {name = "Vitality Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4120]   = {name = "X-Potion", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4121]   = {name = "X-Potion +1", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4122]   = {name = "X-Potion +2", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4123]   = {name = "X-Potion +3", type = "Medicine", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Seeds ----
        [957]    = {name = "Amaryllis", type = "Seeds", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3982]   = {name = "Arborscent Seed", type = "Seeds", action = "sell", mail_to = "SeedsVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [217]    = {name = "Brass Flowerpot", type = "Seeds", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [948]    = {name = "Carnation", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [574]    = {name = "Fruit Seeds", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [575]    = {name = "Grain Seeds", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3993]   = {name = "Grove Cuttings", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [572]    = {name = "Herb Seeds", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17868]  = {name = "Humus", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5965]   = {name = "Isleracea", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [958]    = {name = "Marguerite", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4256]   = {name = "Ouka Ranman", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [941]    = {name = "Red Rose", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4505]   = {name = "Sunflower Seeds", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1237]   = {name = "Tree Cuttings", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [573]    = {name = "Vegetable Seeds", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2960]   = {name = "Water Lily", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2235]   = {name = "Wildgrass Seeds", type = "Seeds", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Geode ----
        [3302]   = {name = "Aqua Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3299]   = {name = "Breeze Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3526]   = {name = "Carbite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2791]   = {name = "Dark Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2787]   = {name = "Earth Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3527]   = {name = "Fenrite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2784]   = {name = "Fire Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3297]   = {name = "Flame Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3522]   = {name = "Garudite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2785]   = {name = "Ice Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3520]   = {name = "Ifritite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3525]   = {name = "Leviatite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2790]   = {name = "Light Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3303]   = {name = "Light Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2788]   = {name = "Lightning Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3524]   = {name = "Ramuite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3304]   = {name = "Shadow Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3298]   = {name = "Snow Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3300]   = {name = "Soil Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3301]   = {name = "Thunder Geode", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3523]   = {name = "Titanite", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2789]   = {name = "Water Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2786]   = {name = "Wind Fewell", type = "Geode", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Scroll ----
        [4878]   = {name = "Absorb-INT", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4874]   = {name = "Absorb-STR", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4876]   = {name = "Absorb-VIT", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4766]   = {name = "Aero V", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4862]   = {name = "Blind", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4760]   = {name = "Blizzard IV", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5100]   = {name = "Boost-CHR", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5099]   = {name = "Boost-MND", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4889]   = {name = "Breakga", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4820]   = {name = "Burst", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5082]   = {name = "Cura II", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4746]   = {name = "Deodorize", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4751]   = {name = "Erase", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4890]   = {name = "Firaja", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5054]   = {name = "Fire Carol II", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4812]   = {name = "Flare", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4822]   = {name = "Flood", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5079]   = {name = "Foe Lullaby II", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4814]   = {name = "Freeze", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4824]   = {name = "Gravity", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4996]   = {name = "Mage's Ballad III", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4966]   = {name = "Myoshu: Ichi", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4666]   = {name = "Paralyze", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4818]   = {name = "Quake", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4717]   = {name = "Refresh", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4850]   = {name = "Refresh II", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4716]   = {name = "Regen", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4702]   = {name = "Sacrifice", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5078]   = {name = "Sentinel's Scherzo", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4667]   = {name = "Silence", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4768]   = {name = "Stone II", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4771]   = {name = "Stone V", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4893]   = {name = "Stoneja", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4925]   = {name = "Thundara II", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4816]   = {name = "Tornado", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5059]   = {name = "Water Carol II", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4895]   = {name = "Waterja", type = "Scroll", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4967]   = {name = "Yurin: Ichi", type = "Scroll", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Weapon ----
        [17840]  = {name = "Angel Lyre", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17088]  = {name = "Ash Staff", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17695]  = {name = "Bayard's Sword", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16450]  = {name = "Dagger", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17100]  = {name = "Ebony Pole", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18211]  = {name = "Gawain's Axe", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17838]  = {name = "Harlequin's Horn", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17939]  = {name = "Kriegsbeil", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [19131]  = {name = "Magnus Dagger", type = "Weapon", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [19313]  = {name = "Magnus Lance", type = "Weapon", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18514]  = {name = "Magnus Toporok", type = "Weapon", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17303]  = {name = "Manji Shuriken", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18351]  = {name = "Meteor Cesti", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17359]  = {name = "Mythic Harp", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17061]  = {name = "Mythril Rod", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17027]  = {name = "Oak Cudgel", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [19228]  = {name = "Paktong Bullet", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17296]  = {name = "Pebble", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16410]  = {name = "Psn. Baghnakhs", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17464]  = {name = "Purgatory Mace", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16447]  = {name = "Rusty Dagger", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [21134]  = {name = "Sasah Wand", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16869]  = {name = "Thundercloud", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [21191]  = {name = "Voay Staff -1", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [20772]  = {name = "Voay Sword -1", type = "Weapon", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Armor ----
        [12385]  = {name = "Acheron Shield", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [13465]  = {name = "Brass Ring", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12960]  = {name = "Bronze Leggings", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12496]  = {name = "Copper Hairpin", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12526]  = {name = "Copper Hairpin +1", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [13454]  = {name = "Copper Ring", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [13492]  = {name = "Copper Ring +1", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12696]  = {name = "Leather Gloves", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2327]   = {name = "Mana Channeler", type = "Armor", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12409]  = {name = "Numinous Shield", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2347]   = {name = "Reactive Shield", type = "Armor", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12816]  = {name = "Scale Cuisses", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [12300]  = {name = "Targe", type = "Armor", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Craft ----
        [1300]   = {name = "Ice Bead", type = "Craft", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1305]   = {name = "Light Bead", type = "Craft", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1301]   = {name = "Wind Bead", type = "Craft", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Augment ----
        [2783]   = {name = "Evolith", type = "Augment", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Automaton ----
        [2351]   = {name = "Dynamo", type = "Automaton", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2325]   = {name = "Equalizer", type = "Automaton", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2328]   = {name = "Eraser", type = "Automaton", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2350]   = {name = "Schurzen", type = "Automaton", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2329]   = {name = "Smoke Screen", type = "Automaton", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2326]   = {name = "Target Marker", type = "Automaton", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Beastmen ----
        [656]    = {name = "Beastcoin", type = "Beastmen", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false, PullFrombBags = false},
        [554]    = {name = "Gold Orcmask", type = "Beastmen", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [749]    = {name = "Mtl. Beastcoin", type = "Beastmen", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5945]   = {name = "Prize Powder", type = "Beastmen", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3929]   = {name = "Velkk Mask", type = "Beastmen", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3928]   = {name = "Velkk Necklace", type = "Beastmen", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Coalition ----
        [2524]   = {name = "Peiste Stinger", type = "Coalition", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Einherjar ----
        [5413]   = {name = "Smoldering Lamp", type = "Einherjar", action = "sell", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Fishing ----
        [17384]  = {name = "Carbon Fish. Rod", type = "Fishing", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17396]  = {name = "Little Worm", type = "Fishing", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- NM Pop ----
        [9104]   = {name = "Centurio's Armor", type = "NM Pop", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8990]   = {name = "Largantua's Shard", type = "NM Pop", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Quest ----
        [557]    = {name = "Ahriman Lens", type = "Quest", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4566]   = {name = "Deathball", type = "Quest", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Skirmish ----
        [3910]   = {name = "Cirdas Visage I", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8966]   = {name = "Eudaemon Blade", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8967]   = {name = "Eudaemon Cape", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8968]   = {name = "Eudaemon Ring", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8969]   = {name = "Eudaemon Sash", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8970]   = {name = "Eudaemon Shld.", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3902]   = {name = "Faithfl. Torso III", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3903]   = {name = "Faithfl. Torso IV", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3905]   = {name = "Faithful's Legs I", type = "Skirmish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3906]   = {name = "Faithful's Legs II", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3908]   = {name = "Faithful's Legs IV", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3900]   = {name = "Faithful's Torso I", type = "Skirmish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3901]   = {name = "Faithful's Torso II", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [8741]   = {name = "Ra'Ka. Visage I", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3895]   = {name = "Rala Visage I", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3897]   = {name = "Rala Visage III", type = "Skirmish", action = "sell", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4037]   = {name = "Yorcia Visage I", type = "Skirmish", action = "sell", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},


        -- ################################################################################################
        -- ################################################################################################
        -- ####                                                                                        ####
        -- ####   DROP   (action = "drop")  - dropped from inventory / passed in the treasure pool     ####
        -- ####                                                                                        ####
        -- ################################################################################################
        -- ################################################################################################

        -- ---- Bone ----
        [891]    = {name = "Bat Fang", type = "Bone", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [880]    = {name = "Bone Chip", type = "Bone", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Alchemy ----
        [922]    = {name = "Bat Wing", type = "Alchemy", action = "drop", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "bag_order", PullFromBags = false},
        [930]    = {name = "Beastman Blood", type = "Alchemy", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [912]    = {name = "Beehive Chip", type = "Alchemy", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1292]   = {name = "Damp Hktk. Eye", type = "Alchemy", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [924]    = {name = "Fiend Blood", type = "Alchemy", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [925]    = {name = "Giant Stinger", type = "Alchemy", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2159]   = {name = "Qutrub Bandage", type = "Alchemy", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Medicine ----
        [4174]   = {name = "Vile Elixir", type = "Medicine", action = "drop", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 1, store_bag = "bag_order", PullFromBags = false},
        [4175]   = {name = "Vile Elixir +1", type = "Medicine", action = "drop", mail_to = "AlchemyVF", min_mail = 1, min_save = 0, mail_cap = 1, store_bag = "bag_order", PullFromBags = false},

        -- ---- Seeds ----
        [1154]   = {name = "3Leaf Mandra Bud", type = "Seeds", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4369]   = {name = "4Leaf Mandra Bud", type = "Seeds", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Scroll ----
        [4899]   = {name = "Earth Spirit", type = "Scroll", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4607]   = {name = "Stone", type = "Scroll", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [4767]   = {name = "Stone", type = "Scroll", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Weapon ----
        [18479]  = {name = "Light Sachet", type = "Weapon", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18474]  = {name = "Snow Sachet", type = "Weapon", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [20765]  = {name = "Tunglmyrkvi", type = "Weapon", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Armor ----
        [14171]  = {name = "Fisherman's Boots", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14927]  = {name = "Hydra Bracers", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15597]  = {name = "Hydra Brayettes", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14515]  = {name = "Hydra Doublet", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14924]  = {name = "Hydra Gloves", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14517]  = {name = "Hydra Haubert", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14518]  = {name = "Hydra Jupon", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16209]  = {name = "Navarch's Mantle", type = "Armor", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14117]  = {name = "Rusty Leggings", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14242]  = {name = "Rusty Subligar", type = "Armor", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11592]  = {name = "Tantra Necklace", type = "Armor", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11930]  = {name = "Versa Breeches", type = "Armor", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11605]  = {name = "Ziel Charm", type = "Armor", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Abyssea ----
        [3104]   = {name = "Opaque Wing", type = "Abyssea", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Abyssea_Trial ----
        [2939]   = {name = "Cuelebre's Horn", type = "Abyssea_Trial", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2962]   = {name = "Itzpapa. Scale", type = "Abyssea_Trial", action = "drop", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- AlTaieu ----
        [1818]   = {name = "Euvhi Organ", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1872]   = {name = "Ghrah M Chip", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1871]   = {name = "H.Q. Hpemde Org.", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1852]   = {name = "H.Q. Phuabo Org.", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1855]   = {name = "H.Q. Xzomit Organ", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1783]   = {name = "Luminian Tissue", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1819]   = {name = "Luminion Chip", type = "AlTaieu", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Beastman ----
        [2510]   = {name = "Orc Helmet", type = "Beastman", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Beastmen ----
        [606]    = {name = "Fetich Head", type = "Beastmen", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [510]    = {name = "Goblin Armor", type = "Beastmen", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [508]    = {name = "Goblin Helm", type = "Beastmen", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [511]    = {name = "Goblin Mask", type = "Beastmen", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1631]   = {name = "Moblin Armor", type = "Beastmen", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1638]   = {name = "Moblin Mask", type = "Beastmen", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18173]  = {name = "Nokizaru Shuriken", type = "Beastmen", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [596]    = {name = "Quadav Backplate", type = "Beastmen", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [501]    = {name = "Quadav Helm", type = "Beastmen", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Cursed ----
        [1441]   = {name = "Lib. Abjuration", type = "Cursed", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1442]   = {name = "Obl. Abjuration", type = "Cursed", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Dynamis ----
        [15079]  = {name = "Abyss Burgeonet", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15479]  = {name = "Abyss Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15094]  = {name = "Abyss Cuirass", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15124]  = {name = "Abyss Flanchard", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15109]  = {name = "Abyss Gauntlets", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15139]  = {name = "Abyss Sollerets", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15925]  = {name = "Argute Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15040]  = {name = "Argute Bracers", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11307]  = {name = "Argute Gown", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11398]  = {name = "Argute Loafers", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11480]  = {name = "Argute M.board", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16362]  = {name = "Argute Pants", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15107]  = {name = "Assassin's Armlets", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15077]  = {name = "Assassin's Bonnet", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15480]  = {name = "Assassin's Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15122]  = {name = "Assassin's Culottes", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15137]  = {name = "Assassin's Pouln.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15092]  = {name = "Assassin's Vest", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15126]  = {name = "Bard's Cannions", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15482]  = {name = "Bard's Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15111]  = {name = "Bard's Cuffs", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15096]  = {name = "Bard's Jstcorps", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15081]  = {name = "Bard's Roundlet", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15141]  = {name = "Bard's Slippers", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15872]  = {name = "Cleric's Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15089]  = {name = "Cleric's Bliaut", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15074]  = {name = "Cleric's Cap", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15134]  = {name = "Cleric's Duckbills", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15104]  = {name = "Cleric's Mitts", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15119]  = {name = "Cleric's Pantaln.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11385]  = {name = "Comm. Bottes", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16349]  = {name = "Comm. Trews", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11468]  = {name = "Comm. Tricorne", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15920]  = {name = "Commodore Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11295]  = {name = "Commodore Frac", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15028]  = {name = "Commodore Gants", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3355]   = {name = "Divine Bijou", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15873]  = {name = "Duelist's Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15136]  = {name = "Duelist's Boots", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15076]  = {name = "Duelist's Chapeau", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15106]  = {name = "Duelist's Gloves", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15091]  = {name = "Duelist's Tabard", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15121]  = {name = "Duelist's Tights", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15038]  = {name = "Etoile Bangles", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16248]  = {name = "Etoile Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11305]  = {name = "Etoile Casaque", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11478]  = {name = "Etoile Tiara", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16360]  = {name = "Etoile Tights", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11396]  = {name = "Etoile Toe Shoes", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3404]   = {name = "Fiendish Tome (1)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3413]   = {name = "Fiendish Tome (10)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3414]   = {name = "Fiendish Tome (11)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3415]   = {name = "Fiendish Tome (12)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3416]   = {name = "Fiendish Tome (13)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3417]   = {name = "Fiendish Tome (14)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3418]   = {name = "Fiendish Tome (15)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3419]   = {name = "Fiendish Tome (16)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3420]   = {name = "Fiendish Tome (17)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3421]   = {name = "Fiendish Tome (18)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3422]   = {name = "Fiendish Tome (19)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3405]   = {name = "Fiendish Tome (2)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3423]   = {name = "Fiendish Tome (20)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3424]   = {name = "Fiendish Tome (21)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3425]   = {name = "Fiendish Tome (22)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3426]   = {name = "Fiendish Tome (23)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3427]   = {name = "Fiendish Tome (24)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3428]   = {name = "Fiendish Tome (25)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3429]   = {name = "Fiendish Tome (26)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3430]   = {name = "Fiendish Tome (27)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3431]   = {name = "Fiendish Tome (28)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3432]   = {name = "Fiendish Tome (29)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3406]   = {name = "Fiendish Tome (3)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3433]   = {name = "Fiendish Tome (30)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3407]   = {name = "Fiendish Tome (4)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3408]   = {name = "Fiendish Tome (5)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3409]   = {name = "Fiendish Tome (6)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3410]   = {name = "Fiendish Tome (7)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3411]   = {name = "Fiendish Tome (8)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3412]   = {name = "Fiendish Tome (9)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3470]   = {name = "Fnd. Tome II (1)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3479]   = {name = "Fnd. Tome II (10)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3480]   = {name = "Fnd. Tome II (11)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3481]   = {name = "Fnd. Tome II (12)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3482]   = {name = "Fnd. Tome II (13)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3483]   = {name = "Fnd. Tome II (14)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3484]   = {name = "Fnd. Tome II (15)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3485]   = {name = "Fnd. Tome II (16)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3486]   = {name = "Fnd. Tome II (17)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3471]   = {name = "Fnd. Tome II (2)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3472]   = {name = "Fnd. Tome II (3)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3473]   = {name = "Fnd. Tome II (4)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3474]   = {name = "Fnd. Tome II (5)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3475]   = {name = "Fnd. Tome II (6)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3476]   = {name = "Fnd. Tome II (7)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3477]   = {name = "Fnd. Tome II (8)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3478]   = {name = "Fnd. Tome II (9)", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1519]   = {name = "Fresh Orc Liver", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1517]   = {name = "Giant Frozen Head", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18308]  = {name = "Ihintanto", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18314]  = {name = "Ito", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15099]  = {name = "Koga Chainmail", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15129]  = {name = "Koga Hakama", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15084]  = {name = "Koga Hatsuburi", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15144]  = {name = "Koga Kyahan", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15877]  = {name = "Koga Sarashi", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15114]  = {name = "Koga Tekko", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15478]  = {name = "Melee Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15073]  = {name = "Melee Crown", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15088]  = {name = "Melee Cyclas", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15133]  = {name = "Melee Gaiters", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15103]  = {name = "Melee Gloves", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15118]  = {name = "Melee Hose", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15025]  = {name = "Mirage Bazubands", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11382]  = {name = "Mirage Charuqs", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11292]  = {name = "Mirage Jubbah", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11465]  = {name = "Mirage Keffiyeh", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16244]  = {name = "Mirage Mantle", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16346]  = {name = "Mirage Shalwar", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15875]  = {name = "Monster Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15140]  = {name = "Monster Gaiters", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15110]  = {name = "Monster Gloves", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15080]  = {name = "Monster Helm", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15095]  = {name = "Monster Jackcoat", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15125]  = {name = "Monster Trousers", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11776]  = {name = "Mujin Obi", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11773]  = {name = "Oneiros Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10973]  = {name = "Oneiros Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10972]  = {name = "Oneiros Cappa", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11671]  = {name = "Oneiros Ring", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11772]  = {name = "Oneiros Sash", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [10932]  = {name = "Oneiros Torque", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11388]  = {name = "Pantin Babouches", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16245]  = {name = "Pantin Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [16352]  = {name = "Pantin Churidars", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15031]  = {name = "Pantin Dastanas", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11471]  = {name = "Pantin Taj", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [11298]  = {name = "Pantin Tobe", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [17271]  = {name = "Platoon Gun", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18290]  = {name = "Relic Bhuj", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18278]  = {name = "Relic Blade", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18332]  = {name = "Relic Gun", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18296]  = {name = "Relic Lance", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [18302]  = {name = "Relic Scythe", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3457]   = {name = "Revelatory Juju", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15879]  = {name = "Sao. Koshi-Ate", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15098]  = {name = "Saotome Domaru", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15128]  = {name = "Saotome Haidate", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15083]  = {name = "Saotome Kabuto", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15113]  = {name = "Saotome Kote", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15143]  = {name = "Saotome Sune-Ate", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15876]  = {name = "Scout's Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15082]  = {name = "Scout's Beret", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15127]  = {name = "Scout's Braccae", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15112]  = {name = "Scout's Bracers", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15097]  = {name = "Scout's Jerkin", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15142]  = {name = "Scout's Socks", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15874]  = {name = "Sorcerer's Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15090]  = {name = "Sorcerer's Coat", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15105]  = {name = "Sorcerer's Gloves", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15075]  = {name = "Sorcerer's Petas.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15135]  = {name = "Sorcerer's Sabots", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15120]  = {name = "Sorcerer's Tonban", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3354]   = {name = "Steelwall Bijou", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15116]  = {name = "Summoner's Brcr.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15484]  = {name = "Summoner's Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15101]  = {name = "Summoner's Dblt.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15086]  = {name = "Summoner's Horn", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15146]  = {name = "Summoner's Pgch.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15131]  = {name = "Summoner's Spats", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15123]  = {name = "Valor Breeches", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15481]  = {name = "Valor Cape", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15078]  = {name = "Valor Coronet", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15108]  = {name = "Valor Gauntlets", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15138]  = {name = "Valor Leggings", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15093]  = {name = "Valor Surcoat", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15132]  = {name = "Warrior's Calligae", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15117]  = {name = "Warrior's Cuisses", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15087]  = {name = "Warrior's Lorica", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15072]  = {name = "Warrior's Mask", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15102]  = {name = "Warrior's Mufflers", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15871]  = {name = "Warrior's Stone", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15085]  = {name = "Wyrm Armet", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15878]  = {name = "Wyrm Belt", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15130]  = {name = "Wyrm Brais", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15115]  = {name = "Wyrm Fng.Gnt.", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15145]  = {name = "Wyrm Greaves", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15100]  = {name = "Wyrm Mail", type = "Dynamis", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Empyrean ----
        [3199]   = {name = "Aoid. Seal: Ft.", type = "Empyrean", action = "drop", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3224]   = {name = "Balance Jewel", type = "Empyrean", action = "drop", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3117]   = {name = "Bale Seal: Hd.", type = "Empyrean", action = "drop", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3177]   = {name = "Bale Seal: Lg.", type = "Empyrean", action = "drop", mail_to = "", min_mail = 99, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Garrison ----
        [1528]   = {name = "Red Cryptex", type = "Garrison", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- NM Pop ----
        [2566]   = {name = "Gnat Pellets", type = "NM Pop", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2565]   = {name = "Gnole Pellets", type = "NM Pop", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2385]   = {name = "Moldy Buckler", type = "NM Pop", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3234]   = {name = "Oasis Water", type = "NM Pop", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2757]   = {name = "Orc. Armor Plate", type = "NM Pop", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "safe", PullFromBags = false},
        [2384]   = {name = "Smoky Flask", type = "NM Pop", action = "drop", mail_to = "", min_mail = 1, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Quest ----
        [4368]   = {name = "2Leaf Mandra Bud", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [846]    = {name = "Insect Wing", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1696]   = {name = "Magicked Steel", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [585]    = {name = "Muddy Bar Tab", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [90]     = {name = "Rusty Bucket", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [3541]   = {name = "Seasoning Stone", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [1686]   = {name = "Soiled Letter", type = "Quest", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [950]    = {name = "Tahrongi Cactus", type = "Quest", action = "drop", mail_to = "", min_mail = 12, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},

        -- ---- Salvage ----
        [16097]  = {name = "Anu's Tiara", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [2377]   = {name = "Bhaflau Card", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [14564]  = {name = "Bodb's Robe", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5366]   = {name = "Castellanus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5370]   = {name = "Cirrocumulus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5378]   = {name = "Congestus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5367]   = {name = "Cumulus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5373]   = {name = "Duplicatus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15712]  = {name = "Enyo's Leggings", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5377]   = {name = "Fractus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15717]  = {name = "Freyr's Ledelsens", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5383]   = {name = "Humilus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5365]   = {name = "Incus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5382]   = {name = "Mediocris Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15728]  = {name = "Nemain's Sabots", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5379]   = {name = "Nimbus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [15630]  = {name = "Njord's Trousers", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5374]   = {name = "Opacus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5376]   = {name = "Pannus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5381]   = {name = "Pileus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5375]   = {name = "Praecipitatio Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5368]   = {name = "Radiatus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5384]   = {name = "Spissatus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5369]   = {name = "Stratus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5371]   = {name = "Undulatus Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5380]   = {name = "Velum Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
        [5372]   = {name = "Virga Cell", type = "Salvage", action = "drop", mail_to = "", min_mail = 0, min_save = 0, mail_cap = 0, store_bag = "", PullFromBags = false},
    },
}

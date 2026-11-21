-- GardenHelper character config (characters.lua)
--
-- Everything that differs per character lives here, instead of inside
-- GardenHelper.lua's logic: the default seed/fertilizer timing, per-
-- character seed overrides, and which modules each character skips.
-- MuleLogger reads this same file too (for //ml furrow done / //ml full
-- done, which need each character's own seed growth time), so there's
-- one place to edit instead of two.
--
-- After editing: nothing to do - GardenHelper re-reads this file at the
-- start of every //gh command when it has changed ("characters.lua changed
-- - re-read."). A file with an error (e.g. saved half-way through an edit)
-- gets one error line and the last good copy stays in use.
-- (//lua r mulelogger if you changed anything the //ml done commands use.)
--
-- Character names are always lowercase here.

return {
    -- Item table file (GardenHelper v2.31.0): which file in this folder
    -- holds your inventory settings and item lines (//gh sell, drop, pop,
    -- send, rec, org). '' = ItemTable.lua (the clean one that ships).
    -- Point it at your own copy (e.g. 'ItemTable_Shadowhammer.lua') so a
    -- new release's ItemTable.lua never replaces your items. MuleLogger
    -- reads it too.
    item_table = '',

    -- //gh update (GardenHelper v2.32.0): which GitHub branch it installs from.
    -- 'major' = full releases, fully tested and validated (default).
    -- 'minor' = smaller changes, out sooner, less tested.
    -- //gh update major / //gh update minor picks one for a single run.
    update_branch = 'major',

    -- Global furrow defaults (used by any character without its own
    -- override below).
    defaults = {
        seed = 'Arborfruit Seed', 
		harvest_time = 6 * 3600, 			-- 6 hour harvest time
		use_fertilizer = true, 
        fertilizer = 'Rich Humus',			-- Coalition Humus is for Fat Burrow Worm for Yeestog recruitment    --Rich Humus for gold leaf
        fertilize_wait_time = 6 * 3600,   	-- 6 hour harvest time (same)

        -- Fertilizer/bait for the other nodes. Used ONLY after
        -- that node has been harvested for the garden day (once a day).
        -- '' = off. Set a name here for every character, or per
        -- character in overrides below (false or '' there = off for
        -- just that character). Full item name as /item takes it; the
        -- examples are from the harvest text, so check the exact name
        -- (an unknown name just gives an error line).
        vein_fertilizer = '',             	-- e.g. 'Stone Serum'
        pond_fertilizer = '',             	-- e.g. 'Super Baitball' to get dragoneye for kuyin assistant
        grove_fertilizer = '',            	-- e.g. 'Grove Worm'
        net_fertilizer = '',  				-- e.g. 'Ponze of Coalition Chum' is for Rusty Coin, that gets susuroon assistant

        -- Records of Eminence (Set_RoE.lua - //gh roe, end of //gh full,
        -- and MuleLogger after each pass): ids accepted once per garden day,
        -- then one Unity chat line (only while a Unity Communique is
        -- active). {} / '' = off. Per character in overrides too.
        -- Unity Communique A-F (UC): 3000, 3009, 3018, 3027, 3036, 3045
        roe_objectives = {3000, 3009, 3018, 3027, 3036, 3045},
        unity_chat_message = '.',
        -- SAFETY LIMIT: Unity chat is public - at most one line per this many
        -- seconds, per character (600 = 10 min). MuleLogger uses it too, to
        -- time its Tier 5 visits.
        unity_chat_min_interval_seconds = 5400,

        -- =============================================================
        -- GARDEN ASSISTANTS (assistants.lua)
        -- =============================================================
        -- Each assistant helps ONE node at a time, doing ONE task there.
        -- Every full garden run (//gh full / force / full inspect) starts
        -- by checking ALL of them; a single node command (//gh vein,
        -- //gh furrow, ...) checks only the assistants set to THAT node
        -- ("Preparing to harvest Vein, checking on assistant settings"),
        -- even if the node is already done today. If the saved data
        -- already matches, nothing is done; otherwise it walks over,
        -- talks to them and sets node + task.
        -- An assistant not in the garden (not unlocked yet) is logged and
        -- looked for again next time.
        -- They only have to be in place BEFORE the harvest - changing one
        -- loses nothing. Effects stack with other assistants and with
        -- bait / serum / fertilizer, and Kuyin and Susuroon can both work
        -- the furrows at the same time.
        --
        -- Only use the node / task pairs listed under that assistant.
        -- false = leave this assistant alone (never talk to them).
        -- Per character: an assistants = {...} block in overrides below.
        -- Anything left out there (or '') uses these defaults; if you
        -- change a character's node, give its task too.
        -- The game never shows an assistant's task, so the one GardenHelper
        -- last set is saved and trusted. Changed one by hand? Use
        -- //gh assistants reset <name> (or //gh assistants done <name> if
        -- you set it exactly the way this file says).
        -- //gh assistants list prints every node / task name.
        --
        -- CONTRACTS (employment.lua - //gh emp, and every full run):
        -- an assistant is recruited as soon as its unlock item is in any
        -- bag (Kuyin: Dragoneye, Susuroon: Rusted Coin, Yeestog: Fat Burrow
        -- Worm); spare unlock items = +7 days, free. Contracts with 7 days
        -- or fewer are flagged; extend them with //ml extend (or //gh emp
        -- extend) - you type the weeks, it does the rest.
        -- rehire_weeks below is not used any more (the game only takes
        -- weeks you type yourself).
        -- Employment off for a character: modules = {<name> = {employment = false}}.
        assistants = {

            -- ---------- Kuyin Hathdenna (Mithra) ----------
            -- node = 'furrow'
            --     task = 'harvest'   -- "Harvest a lot of crops."
            --                        --   More crops from each furrow harvest.
            --     task = 'seeds'     -- "Look for seeds."
            --                        --   She collects seeds from the crops you harvest.
            -- node = 'pond'
            --     task = 'catch'     -- "Catch something."
            --                        --   More fish from the Pond Dredger.
            --     task = 'whopper'   -- "Go after a whopper."
            --                        --   Better chance of bigger fish.
            --     task = 'minnow'    -- "Aim for a minnow."
            --                        --   Better chance of smaller fish.
            kuyin = {node = 'furrow', task = 'seeds', rehire_weeks = 9},

            -- ---------- Susuroon (Qiqirn) ----------
            -- node = 'furrow'
            --     task = 'harvest'   -- "Harvest a lot of crops."
            --                        --   More crops from each furrow harvest.
            --     task = 'good'      -- "Grow me something good."
            --                        --   Better chance of rare crops.
            -- node = 'net'
            --     task = 'catch'     -- "Catch something."
            --                        --   More fish from the Coastal Fishing Net.
            --     task = 'whopper'   -- "Go after a whopper."
            --                        --   Better chance of bigger fish.
            --     task = 'minnow'    -- "Aim for a minnow."
            --                        --   Better chance of smaller fish.
            susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},

            -- ---------- Yeestog (Meeble) ----------
            -- node = 'grove'
            --     task = 'easier'    -- "Make gathering easier."
            --                        --   Better chance of larger grove bounties.
            --     task = 'repair'    -- "Repair the tools."
            --                        --   Sometimes gives extra gathering attempts.
            -- node = 'vein'
            --     task = 'easier'    -- "Make excavating easier."
            --                        --   Better chance of more mineral vein items.
            --     task = 'repair'    -- "Repair the tools."
            --                        --   Sometimes gives extra mining attempts.
            yeestog = {node = 'grove', task = 'easier', rehire_weeks = 9},
        },
    },

    -- Optional per-character furrow overrides. Any field left out falls
    -- back to defaults above. Fields: seed, harvest_time, fertilizer,
    -- use_fertilizer, fertilize_wait_time, reminder_intervals,
    -- fertilize_reminder_intervals, vein_fertilizer, pond_fertilizer,
    -- grove_fertilizer, net_fertilizer, roe_objectives, unity_chat_message,
    -- unity_chat_min_interval_seconds, assistants.
    -- assistants example (only the assistants you list change; the rest
    -- use the defaults above):
    --   assistants = {
    --       kuyin   = {node = 'pond', task = 'whopper'},  -- new node = give the task too
    --       yeestog = false,                              -- leave Yeestog alone on this character
    --   },
    -- To swap, comment out the active line (--) and uncomment another.
    overrides = {
        shadowhammer = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		fishvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		fishvfi = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		woodvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},	
		smithvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},	
		goldvf = { 
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		clothvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		leathervf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},	
		bonevf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},		
		alchemyvf = {
            -- seed = 'Revival Root', harvest_time = 1 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'seeds', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		cookvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		genpopvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},	
		seedsvf = {
            -- seed = 'Arborfruit Seed', harvest_time = 6 * 3600, use_fertilizer = true, 
			-- assistants = {
                -- kuyin = {node = 'furrow', task = 'harvest', rehire_weeks = 9},
				-- susuroon = {node = 'furrow', task = 'good', rehire_weeks = 9},
            -- },
		},
		gearvf = {
            -- seed = 'Revival Root', harvest_time = 1 * 3600, use_fertilizer = true, fertilizer = 'Rich Humus', harvest_time = 1 * 3600, 
			-- assistants = { 
				-- kuyin = {node = 'furrow', task = 'seeds', rehire_weeks = 9},		
			-- },        
		},	
		craftvf = {
            -- seed = 'Revival Root', harvest_time = 1 * 3600, use_fertilizer = true, fertilizer = 'Rich Humus', harvest_time = 1 * 3600, 
        -- fertilize_wait_time = 6 * 3600,   	-- 6 hour harvest time (same) 
			-- assistants = { 
				-- kuyin = {node = 'furrow', task = 'seeds', rehire_weeks = 9},		
			-- },         
		},
		foodvf = {
            -- seed = 'Revival Root', harvest_time = 1 * 3600, use_fertilizer = true, fertilizer = 'Rich Humus', harvest_time = 1 * 3600, 
			-- assistants = { 
				-- kuyin = {node = 'furrow', task = 'seeds', rehire_weeks = 9},		
			-- },  
		},		
    },

    -- Per-character module on/off switches. Anything not listed (or any
    -- character not listed) defaults to ON - only an explicit `= false`
    -- turns a module off for that character.
    -- Garden modules (GardenHelper):
    --   furrow, vein, pond, grove, crystals, flotsam, net, books
    --   A character with ALL eight garden modules off counts as having no
    --   garden in MuleLogger (one daily login only, never a furrow visit).
    -- Other switches:
    --   sell         - sell junk to the Green Thumb Moogle (//gh sell,
    --                  inventory-full selling, and the sell before
    --                  //gh pop). Off = junk is only reported.
    --   set_roe      - set the RoE objectives (Set_RoE.lua: //gh roe, end of //gh full)
    --   unity_chat   - the Unity chat line after them
    --   process_inv  - inventory pop (add new main-inventory items to
    --                  ItemTable.lua)
    --   send_mail    - inventory send (mail stacks to their owners)
    --   receive_mail - inventory rec, and //ml smart's Tier 6 mail visits
    --                  (recieve_mail works too)
    --   org_inv      - inventory org (move stacks into their bags)
    --   The four inventory switches only affect //gh inv auto (run by
    --   MuleLogger after each pass, or by //gh full when
    --   inventory_after_full is on); typing //gh inv / pop / send / rec /
    --   org still runs them. GardenHelper and MuleLogger both re-read
    --   this file when it changes - no reload needed.
    -- Example:
    --   somevf = { sell = false, unity_chat = false, send_mail = false },
    modules = {
        shadowhammer = {
            books = false,
        },
        fishvf = {},
        fishvfi = {},
        woodvf = {},
        smithvf = {},
        goldvf = {},
        clothvf = {},
        leathervf = {},
        bonevf = {},
        alchemyvf = {},
        cookvf = {},
        genpopvf = {},
        seedsvf = {},
        gearvf = {},
        craftvf = {},
        foodvf = {},
        mythrandiir = {
            books = false,
        },
        scracheebrat = {
            books = false,
        },
		vayne = {
            -- books = false,
        },
    },
}

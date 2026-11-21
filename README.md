# GardenHelper

**Author:** Shadowhammer · **Version:** 2.4.0 · **Windower 4** addon for Final Fantasy XI

GardenHelper runs your whole Mog Garden with one command:

- **Garden Furrows** - harvest, plant and (optionally) fertilize, with timers and reminders
- **Mineral Vein, Pond Dredger, Arboreal Grove, Flotsam, Coastal Fishing Net** - once per garden day
- **Node fertilizer / bait** - used once a day, only after that node's harvest
- **Ephemeral Moogle** - trades your crystals and clusters
- **Skipper Moogle books** - daily check / purchase (sails to the Port and back)
- **Records of Eminence** - sets your daily objectives (e.g. Unity Communique) and sends the
  Unity chat line - no RoE addon needed
- **Inventory manager** - one list (`ItemTable.lua`) decides what is kept, sold, dropped,
  mailed to another character, or moved into a bag

It works on one character by itself and keeps separate saved status for every character you
log in as. It started as a rewrite of **Furrow2** by Linktri & Algar.

---

## Requirements

- Mog Garden access with at least one Garden Furrow unlocked (1-3 furrows are found
  automatically).
- No targeting addon needed: since v2.27.0 GardenHelper targets furrows, nodes and NPCs by
  entity ID itself (the same packet the SetTarget addon sends). SetTarget can stay loaded or not.
- Seeds, fertilizer and any node fertilizer you want used, in **main inventory**.
- Optional: **FindAll** - after the final sell, `//findall` refreshes its offline database
  (`refresh_findall_after_pass`; harmless if FindAll isn't loaded).

No separate sell or drop addon is needed.

## Installation

1. Copy the `GardenHelper` folder into `Windower\addons\`. It must contain
   `GardenHelper.lua`, `books.lua`, `crystals.lua`, `inv.lua`, `Set_RoE.lua`, `entities.lua`,
   `Update.lua`, `characters.lua` and `ItemTable.lua`.
   (Or download it from https://github.com/thrydwolfvalefor/gardenhelper - Code > Download ZIP.)
2. In game: `//lua load gardenhelper` (or add it to your `scripts\init.txt`).
3. Edit `characters.lua` for your seed and fertilizer (see below), then
   `//lua r gardenhelper`.
4. Stand in the Mog Garden and run `//gh status`, then `//gh full`.

**Updating:** `//gh update` downloads the newest release from GitHub, backs up the files it replaces
in `backup/` and reloads. `//gh update check` only compares versions; `//gh update force` reinstalls
GitHub's copy. The repo has two branches: **major** (full releases, fully tested and validated - the
default) and **minor** (smaller changes, out sooner, less tested). Set `update_branch = 'minor'` in
`characters.lua` to follow minor, or add `major` / `minor` to any update command for one run
(`//gh update minor`, `//gh update check minor`). Your own files - `characters.lua`, `ItemTable.lua`, `ItemTable_*.lua`, `Mail.lua`,
`memory_report.lua` and `data/` - are never touched; new settings a release adds to them are
described in `CHANGELOG.md`.

**First run:** watch it. Every command presses Escape first to clear stray menus, and
`//gh stop` stops at the next safe point.

## Quick start

| You want to... | Command |
|---|---|
| Do everything that's due today | `//gh full` |
| See what's done / due | `//gh status` |
| Just the furrows | `//gh furrow` |
| Keep replanting furrows all session | `//gh furrowloop` |
| Sell your junk | `//gh sell` |
| Stop | `//gh stop` |
| Update to the newest release | `//gh update` |
| All commands in game | `//gh help` |

## Files

| File | What it is |
|---|---|
| `GardenHelper.lua` | The addon. Timings and options are in the `config` table at the top. |
| `books.lua`, `crystals.lua`, `inv.lua`, `Set_RoE.lua`, `memcheck.lua`, `assistants.lua`, `employment.lua`, `Update.lua` | Modules loaded by GardenHelper. If one is missing or broken, only that feature is off and a load line says so. |
| `entities.lua` | Every garden NPC/object: name, zone, entity ID and the X/Y spot to walk to. `//gh pos` prints a ready-to-paste line. |
| `characters.lua` | **Yours to edit.** Seed, fertilizer, node fertilizer, garden assistants and module switches, globally and per character. |
| `ItemTable.lua` | **Yours to edit.** Inventory settings and one line per item (what to do with it). Ships empty (clean starter). To keep your own table safe from future releases, save it as e.g. `ItemTable_YourName.lua` and set `item_table = 'ItemTable_YourName.lua'` at the top of `characters.lua`. |
| `Mail.lua` | Created by the addon: tracks mail you sent that hasn't been received yet. |
| `data/settings.xml` | Created by the addon: saved garden status per character. |
| `memory_report.lua` | Created by `//gh memory`: the memory check reports, one block per run. |
| `backup/` | Created by the addon: the previous copy of any file it rewrites. |

## `characters.lua`

```lua
defaults = {
    seed = 'Revival Root', harvest_time = 3600,
    use_fertilizer = false, fertilizer = 'Miracle Mulch', fertilize_wait_time = 1800,
    vein_fertilizer = '', pond_fertilizer = '', grove_fertilizer = '', net_fertilizer = '',
    roe_objectives = {3000, 3009, 3018, 3027, 3036, 3045}, unity_chat_message = '.',
    assistants = {
        kuyin    = {node = 'furrow', task = 'seeds'},   -- furrow: harvest|seeds, pond: catch|whopper|minnow
        susuroon = {node = 'net',    task = 'catch'},   -- furrow: harvest|good,  net: catch|whopper|minnow
        yeestog  = {node = 'grove',  task = 'easier'},  -- grove/vein: easier|repair
    },
},
overrides = {
    yourname = { seed = 'Tree Saplings', harvest_time = 48 * 3600, use_fertilizer = true, fertilizer = 'Rich Humus' },
},
modules = {
    yourname = { books = false },
},
```

- Character names are **lowercase**. Item names are the full names `/item` accepts.
- `harvest_time` is the seed's growth time in seconds.
- **Node fertilizer** (`vein_/pond_/grove_/net_fertilizer`): `''` = off. It's used once per
  garden day and only after that node was harvested that day - right after the harvest, or on
  the next `//gh full` / node command. It is never used after Japanese midnight before the new
  day's harvest.
- **Module switches** - `= false` turns one off for that character:
  - Garden: `furrow`, `vein`, `pond`, `grove`, `crystals`, `flotsam`, `net`, `books`
  - `sell` (selling to the Green Thumb Moogle)
  - `set_roe`, `unity_chat` (the RoE step)
  - Inventory (only for `//gh inv auto`): `process_inv`, `send_mail`, `receive_mail`, `org_inv`
- No reload needed: GardenHelper re-reads `characters.lua` at the start of any `//gh` command when it
  has changed (a file with an error is reported once and the last good copy stays in use).

## Commands

`//gh` or `//gardenhelper`.

### Whole garden

| Command | What it does |
|---|---|
| `//gh full [seed] [fertilizer]` | Books (daily check), then furrows, vein, pond, grove, crystals (when holding more than `crystals_full_threshold` of one), flotsam, net, with sells in between (`sell_level`), then inv (`inventory_after_full` - its sell step is the final sell), RoE, memory check. Anything already done today is skipped. Ends with `Full Mog Garden pass complete.` (`... complete (inventory done).` when inv ran). |
| `//gh full force` / `//gh force` | Same, ignoring saved done-today data (furrows checked live). |
| `//gh full inspect` | Live check of everything, acting on what it finds. |
| `//gh full done` / `reset` | Mark every module done today / UNKNOWN. |
| `//gh status` | One line per module from saved data, incl. node fertilizer, crystals, books, mail and inventory. |
| `//gh duecheck` | Read-only: does anything need doing? Prints `DueCheckResult: ACTION_NEEDED` or `NOT_DUE next_epoch=<t>`. |
| `//gh loaded` | The garden-loaded check on demand: normal arrival wait, then settarget the Green Thumb Moogle, hold 1s, Escape, settarget again right away, hold 1s. Prints `GardenLoadedResult: OK / FAILED / NOTGARDEN / BUSY`. (v2.18.0) |
| `//gh enter` | Into the Mog Garden from a Port zone (Mog Dinghy). From the Mog House it needs `mog_house_exit_keys` set in config. Prints `EnterGardenResult: OK/FAILED`. |

### One module

- `//gh vein | pond | grove | flotsam | net [force|inspect|done|reset]` - harvest that node
  (highest rank for vein and grove), then use its fertilizer if one is set and due.
- `//gh crystals [done|reset]` - trade every crystal and cluster to the Ephemeral Moogle.
- `//gh ephstock` - read the Ephemeral Moogle's stock (crystals stored per element) and save it; also kept
  current by itself (login, zone, `//gh status`, after every trade) and shown in `//gh status`. Ends with
  `EphStockResult: OK fire,ice,wind,earth,lightning,water,light,dark` or `FAILED`.
- `//gh ephwithdraw <element> [stacks]` - take full stacks of clusters out of the Ephemeral Moogle: each stack =
  144 crystals = 12 clusters (e.g. `//gh ephwithdraw fire 2`). Needs a free inventory slot per stack. Ends with
  `EphWithdrawResult: DONE / PARTIAL / FAILED got=<clusters>`.
- `//gh ephcapture on|off` - log the Ephemeral Moogle's packets to `data/ephemeral_packets.log`.
  Status shows **Ephemeral Moogle Missing** if you don't have him.
- `//gh books [force|done|reset]` - sail to the Port, check/buy books from the Skipper Moogle,
  sail back.

A node is only marked done after the game's completion or "already done" message; otherwise
it stays UNKNOWN and is retried. A full inventory mid-harvest triggers a sell, then that node
restarts.

### Garden assistants (`assistants.lua`)

- `//gh assistants [name]` - put Kuyin, Susuroon and Yeestog on the node/task `characters.lua`
  (`assistants = {...}`) says. Also done automatically: every full garden run (`//gh full`,
  `force`, `full inspect`) checks all of them at the start; a single node / furrow command checks
  the assistants set to that node (even if it's done today).
- `//gh assistants force [name]` - talk to them and set them again even if the saved data matches.
- `//gh assistants status | list | done [name] | reset [name]` - saved node/task; every
  node/task name; record them as already set (you did it by hand); forget the saved task.

Where an assistant is comes from which of its entity ids is loaded (no talking needed). The
game never shows its task, so the task GardenHelper last set is saved and trusted - if you
change one by hand, use `reset` (or `done`).

### Assistant contracts (`employment.lua`)

- `//gh emp` (or `//gh employment`) - also runs at the start of every full garden run, before the
  assistant check. Most runs only look at the saved data.
  - **Recruit:** an assistant not in the garden yet whose unlock item is in any bag
    (Kuyin: Dragoneye, Susuroon: Rusted Coin, Yeestog: Fat Burrow Worm) - the item is pulled
    into inventory and traded to the Green Thumb Moogle, the scene is pressed through, and the
    assistant is hired right away for `rehire_weeks` (`characters.lua`, per assistant, default 9).
  - **Spare items:** an unlock item for an assistant you already have is traded for 7 free days
    (`employment_trade_spare_items`).
  - **Contract days:** the game's daily "There are N days left on X's contract." line is saved
    whenever it shows. No line today = notices are off, so they are set to "Always notify me".
  - **Extend (by hand):** contracts under 30 days are flagged (`//gh status`, MuleLogger
    `A x`). `//gh emp extend [days=30]` opens the menus up to the weeks box for each assistant under
    that many days; you type the weeks (9) + Enter and GardenHelper finishes the deal. The game
    only accepts weeks you type yourself. `//ml extend` does it on every character that needs it.
- `//gh emp force` - also read every contract at the moogle. `//gh emp notify` - set the notices now.
- `//gh emp status | reset` - saved contract data; forget it all (the next run checks everything).
- Every recruit, hire, trade and expiry goes into `data/employment_history.log`.
- Off for one character: `modules = {<name> = {employment = false}}` in `characters.lua`.
- `//gh duecheck` reports employment work too, so MuleLogger runs a full pass for it.

### Furrows

- `//gh furrow [seed] [fertilizer] [force]` - one pass: harvest what's ready, plant what's
  empty. With `use_fertilizer` on, fertilizer goes in right after planting only - never on a
  furrow that was already growing (it may really be ready to harvest).
- `//gh furrowloop [...]` - the same, then waits the growth time and repeats.
- `//gh furrowplant [seed]`, `//gh furrowfertilize [fertilizer]`, `//gh furrowharvest` - one
  action on the furrows in the right state. `furrowfertilize` checks each furrow live first and only
  fertilizes ones that are growing without fertilizer.
- `//gh furrow inspect [1|2|3|all]` - detect each furrow's real state and act on it.
- `//gh furrow done [1|2|3|all]` / `reset` - record planted now / UNKNOWN.
- `//gh furrow recheck` - clear this character's seed error. A seed missing from main inventory is taken out of the other bags; if it is in no bag, a seed error is saved and the furrows are skipped by `//gh full` / MuleLogger until cleared (or until a manual `//gh furrow` plants).
- `//gh furrowstatus`, `//gh furrowduecheck`.
- `//gh furrowconfig [debug|selljunk|selllevel <1-4>|arrivalwait <s>|seed <n>|fertilizer <n>|usefertilizer|waittime <min>|show]`
  - session-only changes (reset on login), except `debug`, which is saved.

### Records of Eminence (`Set_RoE.lua`)

- `roe_objectives` (in `characters.lua` defaults or per character) is a list of RoE objective
  ids. Once per garden day they're accepted with the same packets the RoE addon uses; if your
  30 slots are full, objectives with **no progress** that aren't in your list are cancelled to
  make room. One the server won't give you (done today, another week's objective) is simply
  not accepted.
- Then `unity_chat_message` is sent to `/u` - at most once per `unity_chat_min_interval_seconds` (600 = 10 minutes, in
  `characters.lua`) per character, and
  only while a Unity Communique objective is active (it's public chat).
- Unity Communique A-F (UC): `3000, 3009, 3018, 3027, 3036, 3045`. `//gh roe list` shows the
  ids of what you have set right now.

| Command | What it does |
|---|---|
| `//gh roe` | Set the objectives (once per garden day), then the Unity chat line. Also runs at the end of `//gh full` (`roe_in_full`). |
| `//gh roe force` | Set them even if already set today. |
| `//gh roe set` / `chat` | Only the objectives / only the chat line. |
| `//gh roe list` | Objectives active right now, `id: progress`. |
| `//gh roe status` / `help` | Status / in-game help. |
| `//gh roe auto` | For scripts: ends with `RoEResult: DONE roe=<set/already/off> chat=<sent/limit/off/not_needed> chat_at=<epoch>`. |

### Inventory (`ItemTable.lua`)

| Command | What it does |
|---|---|
| `//gh sell` | **In the Mog Garden:** walks to the Green Thumb Moogle and sells. **Anywhere else:** preps the items (`SellResult: READY`) and sells the moment you open any NPC vendor's shop; `//gh sell cancel` calls it off. Sells every `"sell"` item in main inventory, plus `"save"` items above their `min_save` that have no `mail_to`. Items with `PullFromBags = true` are pulled out of the other bags first. Then drops `"drop"` items. |
| `//gh drop` | Drops every `"drop"` item in main inventory (`PullFromBags = true`: pulled out of the other bags first) and passes them in the treasure pool. |
| `//gh pop` | Adds every main-inventory item that isn't in `ItemTable.lua` yet, with a blank action, at the top of the file for you to review. Nothing is done with blank-action items. |
| `//gh send` | Mails `"send"` items to their `mail_to` once you have `min_mail` of them in main inventory. Other bags are left alone (they can hold stock for other characters) unless the item has `PullFromBags = true`. |
| `//gh rec [force]` | Takes everything out of the Delivery Box (gil too). |
| `//gh gil <name> <amount>` | Mails gil through the Delivery Box (`1m`, `500k` or `250000`). The game only allows gil to characters on the same account. Ends with `GilResult: SENT / FAILED / BUSY`. The receiver takes it with `//gh rec`. |
| `//gh mailitem <item> <name>:<count> ...` | Mails exact amounts of one item to several characters in one Delivery Box visit, e.g. `//gh mailitem Rich Humus fishvf:21 goldvf:21`. Each name's stacks in turn until the list is done or the outbox is full (the last name can get only part). Pulls the item out of other bags first; ignores ItemTable.lua actions. Ends with `MailItemResult: DONE / FULL / FAILED / BUSY sent=name:count,...`. |
| `//gh org` | Moves items into their `store_bag`. |
| `//gh inv` | sell, drop, pop, send, rec, org - in that order. |
| `//gh inv rebuild` | Re-sorts `ItemTable.lua` after hand edits (your own comments are not kept; the old file goes to `backup/`). |
| `//gh inv help` | In-game help, including your current dry-run settings. |

**Item line:** `[id] = {name, type, action, mail_to, min_mail, min_save, mail_cap, store_bag, PullFromBags}`

| Field | Meaning |
|---|---|
| `action` | `""` new (review) · `"save"` keep · `"send"` mail to `mail_to` · `"ignore"` never touched · `"sell"` sell · `"drop"` drop / pass |
| `type` | Grouping only (Crystals, Seeds, Wood, Smith, Cook, ...). |
| `mail_to` | Character `send` mails it to. `""` = never mailed. |
| `min_mail` | Mail once you have at least this many (stack size = full stacks only). |
| `min_save` | Keep this many (every bag counted); the extra is mailed (`mail_to`) or sold. `0` = keep all. |
| `mail_cap` | Most copies `mail_to` should end up with (its findAll bags + mail still in its Delivery Box). Once it has that many, `//gh sell` sells the extra instead of mailing it; short of it, only the shortfall is mailed. `0` = ignored. No findAll file for `mail_to` = mailed as usual. |
| `store_bag` | `""` = leave it where it is · a bag name (`case`, `satchel`, `sack`, `safe`, `storage`, `locker`, `wardrobe`...) = gather it there · `"bag_order"` = first bag in `bag_order` with room · `"inventory"` = keep it in main inventory. |
| `PullFromBags` | `false` (default) = `send`, `sell` and `drop` only use the copies in main inventory. `true` = copies in the other bags (case, satchel, sack, wardrobes; Mog House bags when reachable) are pulled into main inventory first, and every bag counts toward `min_mail`. |

**Per-character overrides:** add a line keyed `"id:Character"` under the item's `[id]` line to handle that item
differently on one character. Every other character keeps using the `[id]` line; fields the override line
leaves out come from the `[id]` line.

```lua
[4304]           = {name = "Grimmonite", type = "Fish", action = "send", mail_to = "FishVFi", min_mail = 1, ...},
["4304:FishVFi"] = {name = "Grimmonite", type = "Fish", action = "save", min_save = 36, store_bag = "safe", ...},
```

**Settings** (top of `ItemTable.lua`):

- `mail_dry_run = true` (shipped default) - `send` / `rec` only log what they would do. Set it
  to `false` once a dry run looks right.
- `sell_dry_run`, `drop_dry_run` - `true` = only log.
- `auto_drop = false` (shipped default) - `true` drops `"drop"` items the moment they land in
  main inventory and passes them in the treasure pool.
- `skip_characters = {}` - lowercase names the inventory steps skip.

The shipped `ItemTable.lua` is clean - no items at all. Build yours with `//gh pop` on each
character, then give each new item an action. Your furrow fertilizer and node fertilizers are
**never** sold, dropped, mailed or moved (the active seed follows its own item line).

**Your own item table file:** `characters.lua` has `item_table = ''` at the top (blank = `ItemTable.lua`).
Copy your filled-in table to e.g. `ItemTable_YourName.lua` and set `item_table = 'ItemTable_YourName.lua'` -
every inventory step (and `//gh pop` / `//gh inv rebuild` when they write) then uses that file, and
installing a new release (which ships a clean `ItemTable.lua`) never touches your items. `//gh inv help`
shows which file is in use.

### Other

- `//gh stop` (or `abort`) - stops at the next safe point, never mid-menu. Zoning, logging out
  or unloading also stops.
- `//gh debug on|off` - extra logging (saved).
- `//gh pos` - your X/Y and your target's, plus an `entities.lua` line.
- `//gh reloadstatus` - re-read `data/settings.xml`.
- `//gh memory` - memory used by every loaded addon (Windower's `//lua memory`), most on top, with the
  % change vs. that addon's value in the oldest run in `memory_report.lua`; the run is appended there.
  `//gh memory on|off` - also run it at the end of every `//gh full` (saved in `data/memory_check.lua`, the only on/off for it; default off); `//gh memory reset` -
  clear `memory_report.lua`; `//gh memory status`. The addon numbers come from Windower's console log
  (`console.log`, if turned on), otherwise from `memprobe.lua` run inside each addon (`lua invoke`). Each run also has a `pol.exe` line - the whole game's memory
  (plugins and on-screen overlays included), read through Windows (`memcheck_pol.vbs`, written by the
  addon; turn off with `memory_check_game_total = false`), plus a `pol.exe virtual (address space)` row.
- Garbage collection: at the end of every `//gh full` (and before a manual `//gh memory`) GardenHelper runs
  `collectgarbage('collect')` on its own Lua memory (`gc_at_end_of_full`). Each report run gets a `GC:` line
  (before -> after, freed); the first run with it has a `>>>>> From Run N on` marker above it.
  `//gh memory gc` - collect now and show what was freed.
- Per character: every `//gh full` run gets a `Per character:` line - the average `pol.exe` growth (private and
  virtual MB) per character since the last `>>>>>` marker, and since the oldest run (2+ runs needed).
  `//gh memory mark <note>` - write a marker (e.g. `//gh memory mark unloaded BattleMod AuctionHelper`) so the
  next test gets its own average.

## Useful config (`GardenHelper.lua`)

| Setting | Default | Meaning |
|---|---|---|
| `sell_level` | 2 | 1 = sell at the end only; 2 = after Pond + end; 3 = after Furrow, Pond, Grove + end; 4 = after every module. |
| `sell_inventory_full_threshold` | 0.75 | Sell at any checkpoint once inventory is this full. |
| `min_seconds_since_arrival` | 45 | Wait after login/zone-in before touching anything (raise it on a slow PC or connection). |
| `books_in_full` | true | Books trip at the start of `//gh full`. |
| `inventory_after_full` | true | Run `//gh inv auto` after Net in `//gh full` (before RoE); its sell step replaces the separate end-of-pass sell. |
| `gc_at_end_of_full` | true | Full Lua garbage collection (GardenHelper's own memory) at the end of every `//gh full` and before `//gh memory`. |
| `crystals_full_threshold` | 1 | `//gh full` trades crystals when holding more than this many of one. |
| `approach_lock_on_key` | `'numpad*'` | Your Lock On key - only used when an entity has no X/Y in `entities.lua`. |
| `mail_step_delay_seconds`, `sell_item_delay_seconds` | 1 | Raise on a slow PC or connection. |
| `mail_after_send_wait_seconds` | 3 | Pause after each stack is sent, so it clears from the outbox before the next one. |
| `mail_after_confirm_wait_seconds` | 3 | After clearing stacks the receivers took, pause before reading the free outbox slots. |
| `mail_outbox_clear_timeout_seconds` | 60 | Before filling the outbox, wait (re-reading it every `mail_outbox_clear_poll_seconds`, 1) until every stack the receivers took has really left - they clear one slot at a time, even when the game confirmed them by itself. |
| `mail_outbox_stable_seconds` | 5 | Slots still in use that haven't changed for this long are sent mail nobody has picked up yet - stop waiting and use the free ones. |
| `mail_set_retries`, `mail_set_retry_wait_seconds` | 3, 3 | A stack the outbox refuses (slot still clearing) is retried after the wait and another outbox clear. |
| `mail_send_retries` | 3 | A Send the server refuses ("Communications seem to be congested") is retried the same way; the stack stays in its slot meanwhile. |
| `mail_open_retries`, `mail_open_retry_wait_seconds` | 2, 5 | A Delivery Box that won't open ("Please try again in a little while") is tried again after the wait. |
| `mail_before_close_wait_seconds` | 5 | Before closing a Delivery Box that sent something (and before a logout right after). Raise all three on a slow connection. |
| `mail_open_timeout_seconds` | 10 | Max wait for the Delivery Box to open. A failed open is closed anyway, in case the box opens late. |
| `mail_open_quiet_seconds` | 1 | After the Delivery Box opens, move on once no box packet has come in for this long (never longer than `mail_open_settle_seconds`, 3). Raise on a slow connection. |
| `refresh_findall_after_pass` | true | `//findall` after the final sell. |
| `furrow_sync_hold` | true | In a normal pass a ready furrow waits while another furrow is still growing, so all furrows are harvested together on one login (not when they're more than `harvest_time` apart). |
| `furrow_retry_missed` | true | A furrow left ready / unknown / empty after its turn gets one more try in the same pass. |
| `furrow_detect_second_line_wait` | 2.5 | Furrow inspect: extra wait for "has matured" / "agrarian experience" after the rank line, then one more Enter. Raise on a slow connection. |
| `furrow_detect_no_text_retries`, `furrow_detect_retry_wait` | 1, 2 | No reply to a furrow's inspect keys: target it again and retry. |

## How status works

- Status is saved per character in `data/settings.xml`.
- "Today" is the **garden day**, which starts at Japanese midnight (worked out from UTC, so
  your PC's time zone and DST don't matter).
- Saved data is trusted where it can be (a growing furrow past its growth time counts as
  ready; a node done today is skipped). The furrow ETA saved for other tools (MuleLogger) is when
  the **last** furrow is ready, so one visit harvests them all. Anything without usable data is checked live;
  `inspect` and `force` always check live.
- Multi-harvest seeds (e.g. arborfruit - "...should sprout about N more times.", N counting the
  crop growing now): after a harvest with more to come the plant stays, so the furrow isn't
  replanted - it's inspected for the next harvest time and the harvests left (shown in
  `//gh status`). After the last harvest it's replanted as usual. Growing multi-harvest seeds
  aren't fertilized unless `multi_harvest_fertilize = true`.

## Troubleshooting

- **"Could not target ..."** - make sure SetTarget is loaded, clear your target, stand closer.
- **"... is not a recognized item name"** - check the spelling in `characters.lua` and that the
  item is in main inventory.
- **A module never runs** - look for `= false` on that character in `characters.lua`.
- **Node fertilizer not used** - `//gh status` says why (after harvest, none in inventory, gave
  up today).
- **"inv.lua did not start ..."** (or books.lua / crystals.lua) - that file is missing from the
  folder or has an error; the line shows the error.
- **Stopped with an `[ERROR]` about the moogle target** - something stayed on screen for 5
  minutes. Clear it by hand and run `//gh full` again.
- **The character stops short or runs into furniture** - stand where it should stop, `//gh pos`,
  and paste the line into `entities.lua`.
- **More detail:** `//gh debug on`.

## License

MIT - see `LICENSE` (includes the original Furrow2 notice). Version history: `CHANGELOG.md`.

---

*GardenHelper automates real game actions. Use it at your own risk, watch it the first time
and after every update, and be ready to take over.*
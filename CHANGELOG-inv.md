# inv.lua changelog

History of inv.lua v1.0.0 - v1.2.0 (while it lived in the MuleLogger folder). It moved into GardenHelper as inv.lua v2.0.0.

```text
  v1.0.0 (2026-09-24) - Moved out of MuleLogger.lua (ML v1.56.0) into
      this stand-alone module so the INV group can later move to
      GardenHelper (Mark) by copying this file + inventory.lua and
      wiring INV.init / INV.command / INV.run / INV.stop (see the top
      of this file). Behaviour unchanged from ML v1.55.0, except:
      - The host's run flag, sell step, log functions, command prefix
        and data path come from INV.init instead of MuleLogger's own
        state/config/functions. //gh sell + SellResult watching stays
        in MuleLogger (it's MuleLogger -> GardenHelper glue) and is
        passed in as host.sell.
      - Config keys have defaults here (DEFAULTS); the host's config
        wins for any key it sets.
      - New: inv help (//ml inv help), inv <step> [force] as another
        way to run one step, and a clear error for an unknown option.
      - New API for the host: pending_mail_count /
        receivable_mail_count (MuleLogger's M status column and //ml
        smart Tier 6), error_text, mail_summary, character_label.
  v1.1.0 (2026-09-24) - inventory.lua split into ItemTable.lua +
      Mail.lua (Mark: save conflicts editing the item table).
      - ItemTable.lua = settings, owners, bag_order, items - the part
        Mark edits. Only pop writes it, and only when it adds items.
      - Mail.lua = mail tracking + per-character step status - written
        after send / rec and after every step's status, i.e. several
        times per character. It no longer rewrites the item table, so
        an editor with ItemTable.lua open stops getting "file changed
        on disk" conflicts during runs.
      - A syntax error in one file no longer blocks saves to the other:
        send/rec status and mail tracking still save while
        ItemTable.lua is half-edited (the steps that need the item
        table still stop with the error, as before).
      - First load splits an existing inventory.lua automatically
        (values kept as-is) and renames it inventory.lua.migrated.
      - Host interface: data_dir (folder) replaces data_path; an old
        data_path still works (its folder is used).
      - Internals: inv_update -> inv_update_items (pop) and
        inv_update_mail (send, rec, status); inv_serialize ->
        serialize_items + serialize_mail; one write_table_file does the
        tmp/.bak/rename for both. inv_load still returns one merged
        table, so the steps and the public API are unchanged.
  v1.1.1 (2026-09-24) - Backups go in the backup folder (Mark: "backups
      need to always go into the backup folder for all of my addons").
      ItemTable.lua.bak, Mail.lua.bak and inventory.lua.migrated are now
      written to <data folder>backup/ (created if missing), never next
      to the live files. If the old copy can't be moved there, the save
      still goes ahead without a .bak.
  v1.1.2 (2026-09-24) - send's nothing-to-do line now reads "Inventory
      send: no items to mail." instead of "no full stacks to mail."
      (Mark) - with process_min below the stack size partial stacks
      mail too, so "full stacks" was misleading.
  v1.1.3 (2026-09-24) - No more 'lua r treasury' (Mark: the game ran out
      of memory during a long rotation - every reload loaded the whole
      item database again). The pre-inventory check now sends
      '//tr drop' (Treasury 1.2.0.5+ re-reads data/drop.lua and drops
      everything on it) and waits up to treasury_reply_wait_seconds
      (new, 3) for "Treasury: drop check done". No answer = Treasury
      isn't loaded, so it is loaded once with 'lua l treasury' and
      stays loaded. Then waits treasury_reload_wait_seconds (3) for
      the drops as before.
  v1.2.0 (2026-09-24) - Per-character switches (Mark: add Sell,
      Process_Inv, Send_Mail, Recieve_Mail, Org_Inv to characters.lua).
      Two new optional host hooks in INV.init:
      - step_enabled(step): false leaves that step (pop/send/rec/org)
        out of an AUTOMATIC run for the logged-in character, with one
        "switched off - skipped" line. Typed commands (//ml send etc.)
        still run.
      - sell_enabled(): false = the pre-inventory check reports junk
        but doesn't call the sell step (Treasury's drop check still
        runs).
```

## v4.2.0 (2026-09-25)
- `//gh sell` at any NPC vendor (Mark): outside the Mog Garden it preps the sale (pulls "save" extras), then sells at the next NPC shop opened (0x03C), then drops; logs `SellResult: DONE / FAILED`. Waits until a shop opens; `//gh sell cancel` calls it off. Mog Garden behaviour unchanged. //gh inv's sell step still skipped outside the garden.

## v4.3.1 (2026-09-26)
- `//gh inv` no longer runs drop twice (Mark: two "Inventory drop" lines). The sell step's moogle walk called `drop_now()` after closing the shop, then the drop step ran again. `drop_now()` now skips when a `//gh inv` run has its drop step still to come. `//gh sell` on its own, the full-pass sell checkpoints and vendor sells still drop right after selling.

## v4.4.0 (2026-09-26)
- Faster `//gh rec` (Mark: it waited as if a full inbox were loading, even with nothing or only 3 items waiting).
  - Open wait: instead of a flat 3s, `pbx_settle()` returns once no 0x04B has come in for `mail_open_quiet_seconds` (new, default 1). `mail_open_settle_seconds` (3) is now the max. `//gh send` uses it too.
  - Pulls: the first Recv that doesn't answer 01 (item in) or F0 (slot already filled by the game) ends the pulling - nothing is queued - instead of trying every empty slot with a 1s pause each. An empty box now costs one pull attempt; no re-read when nothing was pulled.
  - Slot read (`pbx_work`): stops once slot replies have stopped for `mail_open_quiet_seconds`, instead of waiting out the 5s timeout when the server doesn't answer all 8 slots.
  - Full boxes (8 stacks, more queued) work as before.
- `mail_debug = true` logs the settle time and the result of the pull that brought nothing.
- Backup: backup/inv v4.3.1 2026-09-26.lua, CHANGELOG-inv v4.3.1 2026-09-26.md.

## v4.4.1 (2026-09-26)
- Live check of v4.4.0 (Seedsvf 15:26, `//gh rec force`, empty box): 25s -> 7s. Box quiet after 1.8s; the server answers a pull with nothing queued with result EA in about 1s (no timeout); Check replies slot=-1 stk=-1 (no count).
- The 2s `inventory_step_gap_seconds` pause no longer runs after the last step of an inv run (it only separates steps). A single `//gh rec` ends 2s sooner.
- Backup: backup/inv v4.4.0 2026-09-26.lua.

## v4.4.2 (2026-09-27)
- `pbx_open` waits up to `mail_open_timeout_seconds` (new, 10; was the 5s `mail_response_timeout_seconds`) and, when the open fails, sends Close anyway - a box that opened after rec/send gave up stayed open and blocked MuleLogger's `/logout` (Woodvf 9/26 18:25, 9/27 15:38). `pbx_close` moved above `pbx_open`.
- Backup: backup/inv v4.4.1 2026-09-27.lua.

## v4.5.0 (2026-09-27)
- `//gh gil <name> <amount>` (`inv_send_gil`): opens the send box, confirms delivered stacks, finds a free
  outbox slot, Query (name), Set with ItemWorkNo 0 (gil = main-inventory slot 0) and ItemStacks = amount,
  Send; a failed Send takes it back out (Get). Then checks the gil actually left the character (up to 5s).
  Respects `mail_dry_run` (logs, returns FAILED). Not tracked in Mail.lua.
- rec: gil (item 0xFFFF) is taken even when main inventory is full, and logged as "Gil".
- Untested live: the Set result code for gil is the first thing to check (`mail_debug = true`).
- Backup: backup/inv v4.4.2 2026-09-27.lua, CHANGELOG-inv v4.4.2 2026-09-27.md.

## v4.6.0 (2026-09-28)
- `//gh mailitem <item> <name>:<count> [<name>:<count> ...]` (`inv_mail_item`): item by name (any case) or id.
  Sorts main inventory, pulls the item out of the other bags when main inventory has less than the list (or
  8 stacks), opens the send box, confirms delivered stacks, reads the free outbox slots. Then per name, in
  order: Query, and stacks until its count is sent - a full stack while a full stack is still owed, else the
  smallest stack that covers the rest (partial counts split a stack), else the biggest. Stops when the outbox
  is full (FULL; the last name can be partial) or on any Set / Send error (FAILED; a failed Send is taken
  back out with Get). Ignores ItemTable.lua actions and the protected seed / fertilizer list. Stacks tracked in
  Mail.lua. Respects `mail_dry_run` (logs, FAILED).
- Result line: `MailItemResult: DONE|FULL|FAILED|BUSY sent=fishvf:21,goldvf:12 free=0`.
- Untested live: partial counts from one stack (Set with fewer than the stack holds) are what //gh send already
  does for partial amounts.
- Backup: backup/inv v4.5.0 2026-09-28.lua, CHANGELOG-inv v4.5.0 2026-09-28.md.

## v4.6.3 (2026-09-28)
- Mark: `//ml smart` on Woodvf 22:48 - the outbox held 8 received Rich Humus stacks. The whole send took ~12s, so no
  Confirms ran: the game had confirmed them itself on open, Check said 0, and v4.6.2's `pbx_clear_outbox` took its one
  read as final while the slots were still emptying. Arborscent Seed went into slot 1 (Set OK), Send got EF
  ("Communications seem to be congested"), it was taken back out; the rec right after got "Please try again in a
  little while" and did not open.
- `pbx_clear_outbox`: always re-reads the 8 slots until all are empty, or the used count is unchanged for
  `mail_outbox_stable_seconds` (new, 5) with Check = 0 (what's left = sent, not picked up). Max
  `mail_outbox_clear_timeout_seconds` (now 60). Returns a 4th value, `seen_slot`.
- `pbx_work` returns `seen_slot`; `pbx_free_slots(slots, seen_slot)` never hands out a slot whose reply didn't come
  back (it used to count as empty).
- New `pbx_send_slot`: a refused Send (non-01 reply) waits `mail_set_retry_wait_seconds`, clears the outbox and sends
  again, up to `mail_send_retries` (3); no reply is not retried. Used by inv send, `//gh gil`, `//gh mailitem`.
- `pbx_open` retries a failed open after `mail_open_retry_wait_seconds` (5), up to `mail_open_retries` (2)
  (old body = `pbx_open_once`).
- Backup: backup/inv v4.6.2 2026-09-28.lua, CHANGELOG-inv v4.6.2 2026-09-28.md.

## v4.7.0 (2026-09-30) - pull_item

- `M.pull_item(name, want)`: pulls the item out of the other bags (case, satchel, sack, wardrobes, Mog House bags
  when reachable) into main inventory until `want` are there; returns the main-inventory count. Used by
  GardenHelper v2.17.0 for a seed / fertilizer missing at planting time.
- Backup: backup/inv v4.6.3 2026-09-30.lua, CHANGELOG-inv v4.6.3 2026-09-30.md.

## v4.8.0 (2026-10-01) - send counts every bag

- Mark: action `"send"` items now count **every bag** for `min_mail` (and `min_save`), not just main inventory, and
  copies in the other bags (case, satchel, sack, wardrobes, Mog House bags when reachable) are pulled into main
  inventory before the mail goes out. Same pull the `"save"` extra already had; both now share one code path.
- `send_allowance(e, me, all_total)`: amount = all bags - min_save for both "send" and "save"-with-mail_to.
- `inv_plan_sends`: pulls `want - main` (store_bag searched last). When min_mail is at stack size only whole stacks
  are pulled (no stray remainder). Capped at `mail_pull_max_stacks` (new config, default 8 = one full outbox) stacks
  per item so a big hoard doesn't fill main inventory; the rest goes on the next send. Main inventory full = it
  mails what made it in.
- Dry run (`mail_dry_run`) now also lists `+ would pull <item> x<n> out of the other bags`.
- Untested live.
- Backup: backup/inv v4.7.0 2026-10-01.lua, CHANGELOG-inv v4.7.0 2026-10-01.md.

## v4.9.0 (2026-10-01) - why the Delivery Box did not open

- Mark: every Delivery Box failed to open on every character after 12:47 on 10/1 (send, mailitem, rec alike). The
  retry and error lines now say "the box answered result XX" or "no reply from the server within 10s".
- Backup: backup/inv v4.8.0 2026-10-01.lua, CHANGELOG-inv v4.8.0 2026-10-01.md.

## v4.9.1 (2026-10-01) - Delivery Box packet capture

- Mark: //gh rec on Cookvf 13:31 still "no reply from the server within 10s" (box not shown on screen either).
- With `mail_debug = true` (turned on in GardenHelper.lua for now): every 0x04B the server sends is printed raw, even
  when GardenHelper isn't listening; every outgoing 0x04D is printed raw and marked GH (injected) or GAME (opened by
  hand), so a hand-opened box can be compared byte for byte with GardenHelper's open.
- Backup: backup/inv v4.9.0 2026-10-01.lua, CHANGELOG-inv v4.9.0 2026-10-01.md.
- Outcome: the box opened normally again after Mark restarted the game - the failure was the game client's state after
  the 12:47 restart, not GardenHelper. `mail_debug` set back to false; the raw capture stays for next time.

## v4.10.0 (2026-10-01) - send leaves the other bags alone

- Mark: //gh send (and //ml inv send) must NOT take items out of the other bags - they hold stock for other
  characters. Reverses the pull part of v4.8.0.
- action `"send"`: only main inventory is counted and mailed (main - min_save, min_mail checked on main inventory).
- action `"save"` with a `mail_to`: every bag still counts toward `min_save`, but only main-inventory copies are
  mailed (amount = min(main, all bags - min_save)).
- `inv_plan_sends(data, me)` no longer pulls or re-plans; dry run no longer lists "+ would pull".
  `mail_pull_max_stacks` is unused now (harmless if set). //gh sell, //gh mailitem and planting restock still pull.
- Untested live.
- Backup: backup/inv v4.9.1 2026-10-01.lua, CHANGELOG-inv v4.9.1 2026-10-01.md, README v2.18.0 2026-10-01.md.

## v4.11.0 (2026-10-01) - PullFromBags per item

- Mark: new ItemTable.lua item field `PullFromBags` (default `false` on every item) decides, per item, whether send /
  sell / drop pull copies out of the other bags or only work with main inventory.
- `false`: main inventory only (send = the v4.10.0 behavior). `//gh sell` no longer pulls `"save"` extras out of the
  other bags for these items - it sells what is above `min_save` (every bag counted) out of main inventory.
- `true`:
  - send: every bag counts toward `min_mail` (and `min_save`); copies in the other bags are pulled into main inventory
    first (store_bag searched last, at most `mail_pull_max_stacks`, default 8, stacks per item), then the plan is
    re-made. Dry run lists `+ would pull ...`.
  - sell: `"sell"` = every copy in every bag; `"save"` with no mail_to = every copy above `min_save`; pulled before
    walking to the moogle / arming the vendor sell. Dry run logs `would also pull ...`.
  - drop: every copy is pulled out of the other bags and dropped; if main inventory fills, drop / pull again up to
    `drop_pull_max_rounds` (default 5). Dry run logs `would also pull ...`. auto_drop stays main-inventory only.
- ItemTable.lua: `, PullFromBags = false` added to all 941 items, header comments updated; `//gh pop` adds it to new
  items and the writer always writes it as `true` / `false`. Help and README updated.
- Untested live.
- Backup: backup/inv v4.10.0 2026-10-01.lua, backup/ItemTable before PullFromBags 2026-10-01.lua,
  CHANGELOG-inv v4.10.0 2026-10-01.md, README before PullFromBags 2026-10-01.md.

## v4.13.0 (2026-10-05) - mail_cap per item

- Mark: new ItemTable.lua field `mail_cap` (after `min_save`, `0` = ignored on every item). When `mail_to` is known to
  already have `mail_cap` of the item, the extra copies are sold instead of mailed.
- "Already has" = `mail_to`'s findAll file (addons/findAll/data/<Name>.lua, main inventory + every other bag) + copies
  still in its Delivery Box (Mail.lua, any sender). No findAll file = unknown = mailed as usual.
- send: never mails more than `mail_cap - already has` (still needs `min_mail` to go).
- sell: what send would mail beyond that room is sold (logs `over mail_cap - selling instead of mailing: ...`).
  Works for `"send"` lines and `"save"` lines with a `mail_to` + `min_save`.
- `min_save` keeps its meaning (kept back on the sender).
- `//gh pop` adds `mail_cap = 0`; the writer / `//gh inv rebuild` write it; older files get `0` on load.
- ItemTable.lua: `mail_cap = 0` added to all 965 lines; Grimmonite `[4304]` set to `mail_cap = 36` (FishVFi).
- Untested live.
- Backup: backup/inv v4.12.0 2026-10-05.lua, ItemTable before mail_cap 2026-10-05.lua, README before mail_cap
  2026-10-05.md, CHANGELOG-inv v4.12.0 2026-10-05.md.

## v4.14.0 (2026-10-10) - auto_drop catches stack top-ups

- Mark: Beehive Chip and Insect Wing (action `"drop"`) from Death Jackets were not being auto-dropped on Shadowhammer.
- Cause: auto_drop only watched packet 0x020 (item lands in a new slot). A stackable item joining a stack already in
  main inventory only sends 0x01F (slot count change), so it was never seen. Non-stackables like Rusty Bucket always
  take a new slot, which is why those still dropped.
- auto_drop now also watches 0x01F (main inventory, count > 0, status 0 only - equipped / bazaar copies are left alone).
- One scheduled drop per slot at a time, so 0x020 + 0x01F for the same item don't send two drops.
- Untested live.
- Backup: backup/inv v4.13.0 2026-10-10.lua, backup/CHANGELOG-inv v4.13.0 2026-10-10.md.

## v4.15.0 (2026-10-10) - auto_drop sweeps main inventory

- Mark: Giant Stingers [925] (action `"drop"`) from Death Jackets were still not thrown away after v4.14.0; the log
  also showed Beehive Chips / Insect Wings being thrown away one kill late.
- Cause: auto_drop dropped only the slot the packet named, ~0.5-1s later, and gave up if that slot didn't hold the
  item yet. Mob loot often hadn't reached memory by then, so the drop was skipped and never retried.
- Now: any main-inventory slot change (0x020 / 0x01F), or a drop item hitting the treasure pool, schedules one sweep
  ~1s later. The sweep drops every action `"drop"` stack in main inventory (protected items and equipped / bazaar
  copies skipped), then looks again every 2s, up to 3 more times, while it still finds any.
- Pool passing unchanged. Dry run still only logs.
- Untested live.
- Backup: backup/inv v4.14.0 2026-10-10.lua, backup/CHANGELOG-inv v4.14.0 2026-10-10.md.

## v4.17.0 (2026-11-03) - Item table file from characters.lua item_table (Mark)

- GardenHelper v2.31.0: `characters.lua` `item_table` names the item table file (Mark: `ItemTable_Shadowhammer.lua`);
  blank / missing = `ItemTable.lua`, which now ships clean.
- `items_file_name()` replaces the fixed `ITEMS_FILE_NAME`: loads, pop / rebuild writes, the written header line and
  the `backup/<file>.bak` name all use it. `//gh inv help` shows the file in use.
- Backup: backup/inv v4.16.0 2026-11-03.lua, backup/CHANGELOG-inv v4.16.0 2026-11-03.md.

## v4.17.1 (2026-11-21) - org respects PullFromBags (Mark)

- Mark: `//gh org` pulled Codex of Etchings out of storage, Beitetsu out of locker and Eikondrite out of sack even
  though all three have `PullFromBags = false`.
- Cause: org step 1 (gather a store_bag item out of every other bag) never checked PullFromBags.
- Now step 1 only gathers items with `PullFromBags = true`. With `false` (default) org only puts away the copies in
  main inventory; copies in other bags are left where they are. `store_bag = "inventory"` + false = nothing moved.
- Item-table header docs and `//gh inv help` text updated to match (ItemTable.lua, ItemTable_Shadowhammer.lua).
- Untested live.
- Backup: backup/inv v4.17.0 2026-11-21.lua, backup/CHANGELOG-inv v4.17.0 2026-11-21.md, backup/ItemTable 2026-11-21.lua,
  backup/ItemTable_Shadowhammer 2026-11-21.lua.

# GardenHelper changelog

Full history up to v1.92.1, moved out of GardenHelper.lua in v2.0.0. Newer notes are at the bottom of the changelog block in GardenHelper.lua.

```text
  v1.0.0 - Initial version of FurrowHelper.
  v1.1.0 (2026-09-18) - find_furrow now targets furrows directly by their
      configured entity ID (Garden_Furrow_1_id/2_id/3_id) via the
      SetTarget addon instead of tabbing around for them. The name check
      is kept as a fallback: if the targeted entity's name doesn't match,
      the furrow is assumed not to exist. Furrows are still checked in
      order (Garden Furrow -> #2 -> #3), and the plant/fertilize/harvest
      cycles now stop immediately and skip any remaining furrows as soon
      as one isn't found, instead of continuing on to the next.
  v1.1.1 (2026-09-18) - Standardized all in-chat references to use the
      FurrowHelper name (chat prefix, load message, running/usage text),
      and settled on //fh as the short slash command ('fh' in
      _addon.commands, alongside the existing //gardenhelper).
  v1.2.0 (2026-09-18) - Removed the now-unused max_target_attempts
      config value. Added config.use_fertilizer (default true): when
      off, the automated cycle (//fh start) skips the fertilize step
      and waits config.harvest_time (with config.reminder_intervals)
      before harvesting instead of config.fertilize_wait_time (with
      config.fertilize_reminder_intervals) - toggle with
      //fh config usefertilizer. Fixed the reminder-interval check
      (it compared elapsed time against descending thresholds, which
      fired reminders back-to-back instead of spaced out at
      20/10/5 minutes remaining) while wiring it into both wait
      paths via a shared wait_with_reminders() helper. //fh status
      now also lists each furrow's found/not-found state from
      state.furrows_found, which is reset at the start of every
      plant/fertilize/harvest cycle so it never shows stale results.
      The start/plant/harvest commands now also clear the current
      target/cursor state before doing anything, since they drive
      targeting interactively (send_command) rather than by packet,
      so stale target/cursor state from before the command was run
      could otherwise interfere.
  v1.2.1 (2026-09-18) - Documented the SetTarget addon dependency at
      the top of the file (Windower's require() only loads its own
      bundled libraries, not other addons, so there's no way to
      declare an addon-to-addon dependency in code - a comment plus a
      load-time notice is the best available substitute). The load
      message now reads _addon.version instead of a hardcoded string,
      so it can't drift out of sync again.
  v1.2.2 (2026-09-18) - Moved this changelog from the top of the file to
      the bottom, oldest-first, so future entries can simply be appended
      here going forward.
  v1.3.0 (2026-09-18) - Added a read-only //fh inspect [1|2|3] command:
      targets each furrow (like the other cycles) and dumps candidate
      state fields (status, hpp, model_size, model_scale, models) so
      Mark can compare an empty/growing/ready furrow in-game and find
      the actual growth-state signal - neither this addon nor the
      wiki have a verified one, so nothing was guessed at or wired into
      plant/harvest yet. It does nothing else (no plant/fertilize/
      harvest action), so it's safe to run in any furrow state.
      Also de-duplicated the plant/fertilize/harvest furrow lists into
      one shared local FURROWS table.
  v1.3.1 (2026-09-18) - The passive fields dumped by //fh inspect
      (status/hpp/model_size/model_scale/models) turned out identical
      between an empty furrow and one that had just been planted, so
      they don't carry the growth-state signal after all. //fh
      inspect now also presses Enter on the targeted furrow (default
      once, or //fh inspect <furrow> <enterPresses> for more),
      capturing any chat/system text that appears via a new
      'incoming text' listener (gated by state.capturing_text, a
      no-op otherwise), then presses Escape so nothing gets
      confirmed. This is no longer fully passive - the first Enter
      opens the furrow's own interaction/menu - so try it watching
      the screen before trusting it unattended.
  v1.3.2 (2026-09-18) - Real inspect results came back with 3 clear,
      distinct interaction texts (empty / planted-unfertilized /
      planted-fertilized), plus "has matured!" once actually ready -
      but that last one took 2 enter presses to surface, not 1, so
      //fh inspect now defaults to 2. Added classify_furrow_text() to
      turn the captured lines into empty/growing_unfertilized/
      growing_fertilized/ready/unknown, shown at the end of each
      inspect run. Not yet wired into plant/harvest - want a couple
      more confirmed inspect runs (especially empty/planted with the
      new 2-press default) before making it gate real actions.
  v1.3.3 (2026-09-18) - //fh inspect was only capturing one response
      even with 2 enter presses - the fixed 1s gap between presses
      wasn't reliably long enough for the furrow's response to come
      back before the next enter was sent. It now waits for a new
      line to actually show up (polling every 0.2s) before sending
      the next enter, up to a max_wait_per_press of 3s (configurable
      as a 4th //fh inspect argument) instead of a fixed delay.
  v1.4.0 (2026-09-18) - Mark mapped the exact key sequences needed to
      open a furrow's menu and back out to Cancel with no changes:
      empty = enter,enter,down,enter; planted = enter,enter,enter,
      down,down,enter; ready = enter,enter,enter,down,enter. //fh
      inspect now runs a given preset (empty/planted/ready) or a raw
      comma key list (e.g. "e,e,d,e") via a new run_key_sequence()
      helper, always finishing with an extra escape, and accepts
      'all' for the furrow argument (same as leaving it blank).
      Guessed states are now saved via Windower's config library to
      data/<CharacterName>.xml - automatically separate per
      character - and shown in //fh status. Added a 'login' event
      handler that resets all live state and reloads that file,
      since switching characters doesn't reload this addon's Lua
      state on its own; a stale state.running from a previous
      character logging out mid-cycle would otherwise block every
      command on the next one. Also added an inventory check to
      plant_seed and fertilize_furrow (get_item_count(), using the
      resources library) - both now fail out with a chat message
      instead of attempting /item on something you don't have.
      NOTE: Garden_Furrow_1/2/3_id were left hardcoded rather than
      made per-character - Mark confirmed these entity IDs are the
      same across all of his characters, so one shared config value
      is correct here, not a gap.
  v1.4.1 (2026-09-18) - Fixed a real bug from Mark's 10:33 test run: the
      'incoming text' hook was capturing this addon's OWN log() output
      (it loops back through the same event), which satisfied
      run_key_sequence()'s "wait for a new line" check instantly on the
      addon's own prior line instead of the furrow's real response -
      furrow 1 moved on before its actual text arrived, and furrow 2
      opened the on-screen "What will you do?" list menu (confirmed by
      screenshot: Inspect the garden / Uproot everything / Absolutely
      nothing) which a single escape did not close, leaving it open
      into furrow 3's check. Fixed by skipping any captured line that
      contains "FurrowHelper:". Also: //fh inspect no longer touches a
      furrow's menu by default - only when a preset/key list is given,
      since a bare enter is what opened that stuck menu - and the
      closing escape is now sent twice, since escape appears to only
      dismiss a text popup and land back on the list rather than fully
      exiting it.
  v1.4.2 (2026-09-18) - //fh inspect now refuses to run a preset/key
      list against 'all'/every furrow - it requires a specific furrow
      number. A preset's down-count is tuned to that one furrow's
      actual menu size; firing it at furrows that are NOT in the
      matching state risks landing the cursor on the wrong item before
      the closing enter confirms it. This is the likely cause of
      Mark's "went too fast across all three" report if a single
      preset was run against 'all' - //fh inspect 1 empty (one furrow
      at a time, matching its real state) is the safe way to do this.
  v1.4.3 (2026-09-18) - //fh inspect is automatic and safe again. With
      no preset/key list given it now defaults to SAFE_AUTO_PROBE
      (enter, enter, enter) and runs it against all three furrows (or
      just the one given) instead of doing nothing, since that
      sequence never presses "down" and so can only ever (re-)select
      "Inspect the garden" - it cannot land on "Uproot everything" no
      matter which state a given furrow is actually in. The v1.4.2
      guard requiring a specific furrow number is narrowed to only
      apply when the sequence contains "down" (sequence_has_down()) -
      the empty/planted/ready presets and any custom list with a down
      in it still require one, since those ARE tuned to one state's
      menu size. The closing safety-net escape count went from 2 to 4
      for extra margin now that the automatic path always runs 3
      enters; exactly how many escapes fully close the top-level
      "What will you do?" list (versus just a text popup) is still
      unconfirmed, so the completion message now reminds Mark to
      glance at the screen and confirm nothing was left open. Bare
      "//fh inspect" and "//fh inspect all" both now check and save
      all three furrows' states in one go, answering "what's the
      proper command to check all three and write them to data" -
      "//fh inspect 1/2/3" still work the same way for one furrow.
  v1.4.4 (2026-09-18) - Correction from Mark's real in-game testing:
      Escape does NOT close these furrow menus/text boxes at all -
      v1.4.3's repeated escape "safety net" was based on a wrong
      assumption and did nothing useful. Worse, v1.4.3's automatic
      default (blind enter, enter, enter) was actively unsafe: an
      extra enter past the classifying text can confirm a real
      harvest on a furrow that's ready, and there is no universal
      key sequence that's safe to run blind against every furrow -
      the correct exit path is inherently state-specific, which is
      exactly why Mark's empty/planted/ready presets are each scoped
      to one state. That default is removed.
      //fh inspect (and inspect all) is still automatic, but safely:
      each furrow now has its exit sequence auto-selected from its
      own last recorded status (from a prior inspect, or now also
      from normal plant/fertilize/harvest activity - see below) -
      never one preset blasted at every furrow. A furrow whose
      status is still 'unknown' is skipped with a message to seed it
      once by hand (//fh inspect N empty/planted/ready) rather than
      guessed. An explicit preset/key list (3rd arg) still always
      requires one specific furrow number, same as v1.4.2.
      Closing an inspected furrow's menu is now done purely by the
      matched preset itself (it already ends by explicitly selecting
      "Absolutely nothing"/"No") - the single escape + target clear
      after it is just end-of-turn cursor hygiene, not a menu-close
      step.
      Also wired plant_cycle/fertilize_cycle/harvest_cycle to call
      record_furrow_state() on each success (planting ->
      growing_unfertilized, fertilizing -> growing_fertilized,
      harvesting -> empty), so the status //fh inspect relies on
      stays fresh through Mark's normal harvest-then-plant workflow
      without needing a separate manual inspect pass first. Added
      left/right key aliases (unused by the presets yet, but the
      Yes/No confirmation Mark described uses them) for future
      custom key lists.
  v1.5.0 (2026-09-18) - //fh start/plant/fertilize/harvest no longer
      act on a furrow purely because the data file says so from
      whenever it was last checked - each one now gets a genuinely
      current status right before the action is taken.
      Per Mark's guidance: if the data file already has enough to
      work out the current status without touching the furrow (a
      recorded 'empty'/'ready', which don't change on their own, or
      a 'growing_unfertilized'/'growing_fertilized' with enough
      elapsed time since it was recorded to know it must be ready by
      now, using the same config.harvest_time/fertilize_wait_time
      durations main_loop already waits by), that's used directly -
      no interaction needed, so most runs stay fast. Only a furrow
      with no usable data (last status still 'unknown', or a
      growing_* state saved before this version with no timestamp to
      measure from) falls back to an actual live check
      (live_probe_furrow, the same logic //fh inspect already used).
      record_furrow_state now also saves a raw furrow_N_checked_epoch
      timestamp (alongside the existing human-readable
      furrow_N_checked_at) so elapsed time can be computed directly
      with os.time() instead of parsing the display string.
      plant_cycle only plants furrows this fresh check confirms are
      'empty' (others are skipped with a message, not planted
      blind); harvest_cycle only harvests ones confirmed 'ready';
      fertilize_cycle only fertilizes ones confirmed
      'growing_unfertilized'. A furrow that can't be targeted at all
      still stops the whole cycle (same as before this version); one
      that's simply in the wrong state, or has no data to check
      ('needs_manual_check' - seed it with //fh inspect N
      <preset> first), is skipped on its own without aborting the
      others.
      //fh inspect itself is unchanged in spirit - it's still always
      a genuine LIVE check (via the new shared live_probe_furrow
      helper, extracted from what inspect already did), never the
      time-based estimate, since running it by hand is specifically
      for getting real ground truth or correcting drift.
  v1.6.0 (2026-09-18) - Reworked automatic status detection per
      Mark's guidance, removing the last real limitation from
      v1.4.4/v1.5.0: a furrow with no recorded data ever needed a
      manual seed (//fh inspect N <preset>) before automation would
      touch it. That's gone now. Detection no longer needs to know a
      furrow's state in advance at all: DETECT_SEQUENCE
      (enter, enter) is safe to run blind on ANY furrow, since it
      can only ever open the menu and select "Inspect the garden" -
      a read, never a confirm. Only the EXIT needs to be
      state-specific (EXIT_SEQUENCES, keyed by the state just
      classified from that detect step's text, not guessed ahead of
      time), so live_probe_furrow now always works, no matter what
      (or whether anything) was previously recorded for that furrow.
      Added reconcile_furrow_data(), called first by every
      furrow-touching command (start/plant/harvest/fertilize/
      inspect): it uses settarget to find out how many furrows
      actually exist right now, compares that to how many have real
      recorded status, and if they don't match (a furrow was added
      since the data was last written, for instance), does a fresh
      live probe on every available furrow before anything else
      happens, rather than trusting stale/partial data.
      //fh start no longer assumes every furrow is empty. Per
      Mark's spec it now: 1) harvests anything already ready,
      2) plants anything empty, 3) fertilizes anything freshly
      planted (if use_fertilizer is on), then 4) waits the FULL
      configured growth time (not a shortened/remaining estimate)
      before harvesting again. Each phase's own cycle function does
      its own fresh check and only acts on furrows actually in the
      matching state, so running every phase unconditionally is
      safe even when a given phase has nothing to do.
  v1.6.1 (2026-09-18) - Removed the passive mob-field dump (status/
      hpp/model_size/model_scale/models) that every live check
      printed to chat for each furrow. Confirmed back on 2026-09-18
      that none of those fields carry any growth-state signal (they
      were identical between an empty furrow and a freshly-planted
      one), so this was just noise, not useful information - Mark
      flagged it from a real inspect run's chat log. live_probe_furrow
      now only prints the furrow's name and, if targeting somehow
      didn't resolve to a live mob, a warning about that.
  v1.7.0 (2026-09-18) - Fixed the real cause of furrow #2 getting
      misread as "not found" (targeted "Garden Furrow" instead of
      "Garden Furrow #2"): find_furrow's confirm loop stopped
      polling as soon as ANY target appeared, not specifically the
      RIGHT one. Right after settarget-ing furrow 2, a quick
      get_mob_by_target('t') check can still briefly return furrow
      1's now-stale target before the client actually switches over
      - the old `while attempts < confirm_attempts and not target`
      loop treated that stale, non-nil target as "done" on its very
      first 0.2s check, then failed the name comparison AFTER the
      loop and wrongly concluded furrow 2 doesn't exist. It now
      keeps polling (up to 5 tries instead of 3) until the targeted
      mob's name actually matches the furrow being searched for, or
      attempts run out - giving the real target time to register
      instead of accepting a leftover one. The ids ARE correct, as
      confirmed - this was purely a timing bug in the confirmation
      loop, not a config problem.
      Also updated get_furrow_id() to read furrow ids from FURROWS
      (Mark moved Garden_Furrow_1/2/3_id there himself, adding an
      `id` field to each entry) instead of the now-empty
      config.Garden_Furrow_N_id fields it used to read, which would
      otherwise have returned nil for every furrow.
  v1.7.1 (2026-09-18) - //fh stop and //fh abort have always been
      the exact same command (command == 'stop' or command ==
      'abort' share one branch) - there's no functional difference
      between them, confirmed for Mark since he asked. Also fixed
      why stopping didn't feel immediate: wait_with_reminders (the
      long post-plant/fertilize wait inside //fh start) only checked
      state.running once every 60 SECONDS (a full coroutine.sleep(60)
      between checks), so stopping during that wait could take up to
      a full minute to take effect. It now polls every 2 seconds
      instead - reminders still fire at the same real elapsed times,
      just checked far more often. check_furrow_states and
      reconcile_furrow_data's furrow loops also never checked
      state.running between furrows at all, so a stop mid-batch had
      to wait for every remaining furrow to be probed first - both
      now check between furrows too. None of these check mid-way
      through actually driving a furrow's menu (inside
      live_probe_furrow/run_key_sequence) - stopping is still only
      ever allowed to take effect between furrows, never in the
      middle of one, so it can never abandon a furrow with its menu
      left open on screen. That bounds the worst-case delay to
      "however long the furrow currently being handled takes", not
      "however long everything left in the queue takes."
  v1.7.2 (2026-09-18) - Fixed the runtime error Mark hit running
      //fh start: "attempt to call global 'reconcile_furrow_data' (a
      nil value)". reconcile_furrow_data was a plain `local
      function`, defined further down the file than main_loop,
      which calls it directly near the top of its body. Lua
      resolves a function's free variables against what's in scope
      at the point IT was defined, not where it's later called from
      - since reconcile_furrow_data didn't exist yet when main_loop
      was defined, that call fell through to a global (nil) instead
      of the real local, exactly the same class of bug
      check_furrow_states was already protected against via a
      forward declaration. Fixed the same way: `local
      reconcile_furrow_data` is now forward-declared right next to
      check_furrow_states', and its real definition further down is
      now a plain assignment onto that upvalue instead of a second
      `local function`.
      Also: //fh start's opening log line always named the
      fertilizer even when use_fertilizer is OFF (e.g. "Starting
      automated cycle with Revival Root and Miracle Mulch" whether
      or not fertilizer is actually going to be used this run). It
      now only mentions the fertilizer when config.use_fertilizer is
      true, and says "(fertilizer is OFF)" otherwise.
  v1.7.3 (2026-09-18) - Fixed the runtime error Mark hit right after
      harvesting, while planting: "'id' is not defined for numbers"
      at get_item_count's inventory scan. windower.ffxi.get_items()
      returns each bag (inventory, safe, etc.) with a sibling 'max'
      field (its slot capacity, a plain number) alongside the
      numbered slot entries - iterating with `pairs(items.inventory)`
      walks that field too, so on that one entry `slot` was just the
      number (e.g. 80), and `slot.id` failed since a number has no
      fields. Switched to `ipairs`, which only walks the contiguous
      numeric slot entries and skips 'max' entirely - the fix
      Windower's own API expects for bag iteration.
  v1.8.0 (2026-09-18) - Furrow availability is now checked once and
      reused, instead of every cycle re-trying (or worse, blindly
      trying) all 3 furrow slots regardless of how many a character
      actually has. Added state.available_furrows, set by
      reconcile_furrow_data() and read via the new
      get_active_furrows(): check_furrow_states and the 'inspect'
      command's furrow loop now only ever attempt furrows already
      known to exist. plant_cycle/fertilize_cycle/harvest_cycle treat
      a furrow missing from fresh_states (i.e. not available) as a
      silent, expected skip - distinct from 'not_found', which still
      means a furrow that WAS expected to be there suddenly isn't,
      and still stops that cycle.
      For //fh start specifically: reconcile_furrow_data() now runs
      exactly ONCE, in the 'start' command handler, before
      main_loop's first call - not inside main_loop itself, which
      recurses (calls itself again) after the wait and final
      harvest. That recursion, and everything the whole run
      triggers (harvest/plant/fertilize before AND after the 60+
      minute wait), now all reuse that same initial availability
      check rather than re-deriving it. A single //fh
      plant/harvest/fertilize/inspect still reconciles fresh every
      time it's run, per Mark's spec, since each is a one-off with
      no long-running state to reuse.
      Added 'logout' and 'zone change' event handlers that stop
      state.running (same as //fh stop) and clear
      state.available_furrows: logging out used to leave
      state.running stuck true with nothing to reset it (Lua state
      doesn't clear on logout any more than it does on a different
      character logging in), and every FurrowHelper command only
      makes sense while standing at the Mog Garden furrows, so any
      zone change while one is running means Mark just left it.
  v1.9.0 (2026-09-18) - //fh start no longer checks a furrow's
      status, backs out, and comes back later to act on it. Per
      Mark: "it doesn't make sense to open up a furrow text box, see
      what the status is, then exit, then come later. Instead, lets
      take the next best step while we are in the furrow menu, and
      then ensure the newest state AFTER that action is logged."
      Replaced main_loop's three separate harvest_cycle()/
      plant_cycle()/fertilize_cycle() passes with a single loop over
      get_active_furrows() calling the new handle_furrow_for_start()
      once per furrow. For each furrow: recorded/inferred data is
      still trusted first exactly like check_furrow_states - only a
      furrow with no usable data gets a live detect at all. Then,
      whatever state is found (recorded or live), the next action
      happens immediately instead of ending the check there:
        - ready -> harvest it, then plant it (then fertilize it too
          if config.use_fertilizer is on), logging the newest
          'growing_...' state right after.
        - empty -> log 'empty' immediately, exit the menu (if a live
          detect opened one), then plant it the same way.
        - growing_unfertilized/growing_fertilized -> just log the
          state; nothing else to do until it's ready, except
          fertilizing a freshly-unfertilized one when
          config.use_fertilizer just turned on.
      For a live-detected 'ready' furrow specifically, harvest_furrow()
      now takes an optional `already_in_menu` argument: when true, it
      skips its own first two enters and runs only the remaining
      steps of its exact same proven sequence, continuing straight
      into the harvest from the menu DETECT_SEQUENCE (enter, enter)
      just opened - instead of exiting via EXIT_SEQUENCES.ready and
      reopening a fresh menu just to harvest it. Called with no
      argument (every other call site, including harvest_cycle()),
      harvest_furrow() is completely unchanged - the full blind
      5-enter+escape sequence, byte-for-byte identical to before.
      This exact continuation (2 detect-enters + harvest_furrow's
      remaining 3 enters, spliced together across two different
      keypress helpers - run_key_sequence's dynamic wait-for-text,
      then harvest_furrow's fixed sleeps) hasn't been separately
      hand-verified by Mark the way the standalone per-state exit
      sequences were, though it's the same keys in the same order
      harvest_furrow already sends today - worth watching closely on
      the first //fh start run that finds a furrow actually ready.
      //fh harvest, //fh plant, and //fh fertilize (and their
      harvest_cycle/plant_cycle/fertilize_cycle functions) are
      completely unchanged, per Mark's explicit instruction - they
      still each do their own single-phase fresh check across all
      active furrows and act only on the ones already in the
      matching state.
  v1.9.1 (2026-09-18) - Fixed the bug Mark reported right after
      v1.9.0: running //fh start on furrows that were actually ready
      to harvest opened each furrow's menu, correctly saw it was
      ready, and then exited without harvesting - exactly the
      check-then-come-back-later behavior v1.9.0 was supposed to
      eliminate. Root cause: the 'start' command handler's one-time
      reconcile_furrow_data() call (done once before main_loop,
      specifically so main_loop's per-furrow pass wouldn't need to
      re-check availability itself) also still ran its OWN
      mismatch-triggered live-probe pass - which opens every
      available furrow's menu, detects its state, and backs out
      again via EXIT_SEQUENCES WITHOUT acting on it, since that
      probe's only job (for the //fh plant/harvest/fertilize/inspect
      commands it's shared with) is to refresh the data file, not to
      act. That pass fires whenever the recorded/available furrow
      counts don't match - which includes a fresh data file, or any
      furrow whose recorded state is 'unknown' - so on the very run
      Mark tested this on, reconcile itself was the thing that
      opened each ready furrow's menu and closed it again before
      handle_furrow_for_start (the new merged flow) ever got a
      chance to. Fixed by giving reconcile_furrow_data an optional
      `skip_status_probe` argument: true skips that live-probe pass
      entirely and only checks existence (settarget probing, no
      menu interaction at all) - which is now what //fh start passes
      (reconcile_furrow_data(true)). handle_furrow_for_start already
      determines each furrow's status itself and always acts
      immediately on whatever it finds, so the first (and only) time
      a furrow's menu opens during //fh start is now inside
      handle_furrow_for_start, which never opens one without also
      finishing the job. //fh plant/harvest/fertilize/inspect still
      call reconcile_furrow_data() with no argument, so their
      existing refresh-on-mismatch behavior is unchanged.
  v1.9.2 (2026-09-18) - Fixed the real cause of Mark's very next
      report: //fh start printed "Checking each furrow and taking
      the next step for it..." and then produced NO further output
      at all, for furrows the data file confirmed WERE recorded as
      'ready' - meaning it wasn't even reaching handle_furrow_for_start's
      first log line, let alone acting on anything. Root cause: v1.9.0
      rewrote main_loop to call get_active_furrows() directly to
      build its new per-furrow loop, but get_active_furrows was
      still a plain `local function` defined much further down the
      file - it had never needed forward-declaring before, since its
      only two callers (check_furrow_states, the 'inspect' command)
      both happen to be defined AFTER it. main_loop is defined
      earlier than get_active_furrows, so that new direct call
      resolved to a global (nil) instead of the real local function -
      the exact same class of bug as check_furrow_states and
      reconcile_furrow_data hit earlier in this file, just newly
      introduced in a 4th spot by v1.9.0's edit. Calling a nil value
      throws immediately and unwinds the whole coroutine, which is
      why nothing after that one log line ever printed - Lua/Windower
      errors like this don't reliably surface in every chat window,
      so it looked like a silent hang rather than a crash. Fixed the
      same way as the others: `local get_active_furrows` is now
      forward-declared right next to check_furrow_states/
      reconcile_furrow_data/handle_furrow_for_start, and its real
      definition further down is now a plain assignment onto that
      upvalue instead of a second `local function`.
  v1.10.0 (2026-09-18) - plant_seed/fertilize_furrow now use the
      same dynamic wait-for-text approach as furrow menu navigation
      (DETECT_SEQUENCE/EXIT_SEQUENCES) instead of fixed sleeps
      between key presses. The old fixed delays (a blind 3-second
      wait for the item's confirmation menu to appear, then
      1s/1s/2s between each of its 3 enters and the closing escape)
      were tuned for normal conditions and could fall short under
      bad lag/high ping, sending the next key before the client had
      actually registered the previous one. Added wait_for_response()
      (waits for the first new incoming chat/system line as a loose
      "something happened" signal, capped at 5s, same signal
      run_key_sequence already uses for furrow menus) for the
      initial item-use confirmation, then run_key_sequence() itself
      for the enter/enter/enter/escape presses that follow, capped
      at 3s each. plant_seed/fertilize_furrow are now forward-declared
      (their real bodies need run_key_sequence, defined further down
      the file) - same pattern as check_furrow_states/
      reconcile_furrow_data/handle_furrow_for_start/get_active_furrows.
      Also removed the last remaining references to this addon's
      predecessor and prior contributors, since FurrowHelper has been
      rewritten enough at this point to stand on its own: _addon.author
      is now just 'Shadowhammer', the load message no longer credits
      anyone by name, and the changelog's mentions of the addon it was
      originally forked from were reworded to drop that addon's name.
      No behavior changes from either of those - comments and metadata
      only.
  v1.11.0 (2026-09-18) - Added //fh startonce [seed] [fertilizer]: the
      same merged per-furrow pass as //fh start (harvest anything
      ready, plant anything empty, fertilize anything freshly
      planted if use_fertilizer is on), but exactly once - no
      wait/recurse afterward. Ends with a distinct chat line,
      "Single pass complete.", so another addon can trigger it (via
      windower.send_command('fh startonce')) and watch chat for that
      exact line to know it's actually done, instead of guessing how
      long a pass takes. Built for MuleLogger (a new, separate
      addon) to log into a rotation of characters, run one
      harvest/plant pass on each via this command, then log out and
      move to the next - //fh start's normal 30-60 minute wait
      between passes makes no sense for that use case, since the
      whole point is to keep moving through the character list.
      Extracted the per-furrow loop itself (get_active_furrows +
      handle_furrow_for_start) into a shared run_single_furrow_pass()
      function, used by both main_loop (start's repeating version)
      and startonce, instead of duplicating it. No behavior change
      for //fh start itself.
  v1.12.0 (2026-09-18) - Added //fh duecheck: a fast, read-only
      command for other addons (MuleLogger) to ask "does anything
      here actually need doing right now?" before bothering to run a
      full startonce pass. Uses only recorded/inferred data (same
      trust-the-data-first check startonce already does per furrow)
      plus the existence-only reconcile (settarget, no menu
      interaction) - never opens a furrow's menu, so it's safe and
      cheap to call every time a mule logs in. Reports back over
      chat with a machine-parseable line - "DueCheckResult:
      ACTION_NEEDED" if any furrow is ready, empty, or has no usable
      recorded data yet, or "DueCheckResult: NOT_DUE
      next_epoch=<epoch>" (the earliest time any furrow will next be
      ready) if every active furrow is confirmed still growing and
      not due. Built specifically so MuleLogger can skip calling
      startonce on a mule with nothing due yet, while still logging
      into and out of every character in its rotation on schedule.
  v1.13.0 (2026-09-18) - Fixed a real MuleLogger failure: right after
      a fresh login, Shadowhammer's Garden Furrow #3 was found but #1
      and #2 were reported as not existing - even though all three
      are real furrows Shadowhammer has. Furrows are always unlocked
      in order, so a higher-numbered one showing up while a lower-
      numbered one doesn't can only mean the client hadn't finished
      loading nearby entities in yet, not that the lower one is
      actually missing. reconcile_furrow_data's existence check now
      detects exactly that pattern and retries (up to 4 times, 3s
      apart) before trusting a "missing" lower-numbered furrow,
      instead of writing it off on the very first pass. This is
      self-correcting and only costs extra time when the pattern
      actually shows up, so it doesn't slow down a character whose
      furrows all load in normally.
  v1.14.0 (2026-09-18) - reconcile_furrow_data() now reuses a recent
      existence probe instead of re-running it from scratch on every
      call. Noticed via //ml test: //fh duecheck and the //fh
      startonce it immediately triggered each independently probed
      all 3 furrow slots - including re-attempting (with its own
      retry-until-give-up cost) Garden Furrow #3, which the duecheck
      call moments earlier had already confirmed doesn't exist for
      that character. Added state.available_furrows_checked_at
      (epoch of the last real probe) and config.existence_cache_seconds
      (90s): a skip_status_probe caller (start/startonce/duecheck)
      now reuses the existing state.available_furrows answer when
      it's still within that window, instead of re-checking. Manual
      one-off commands (plant/fertilize/harvest/inspect) are
      unaffected - those never set skip_status_probe, so they always
      get a fully fresh existence check. The cache timestamp is reset
      alongside available_furrows on login/logout/zone change, so it
      can never carry over to a different character or a different
      trip to the garden.

      Separately, re: the same test run appearing to skip Garden
      Furrow (the harvest never happened while Furrow #2 got
      harvested and replanted) - that was correct, not a bug.
      handle_furrow_for_start trusts infer_furrow_state() first for
      each furrow independently: Furrow's last recorded state was
      growing_unfertilized and hadn't yet reached
      config.harvest_time (1 hour) since it was last checked, so it
      correctly logged "still growing" and left it alone, while
      Furrow #2's recorded state was ready, so that one got
      harvested and replanted. //fh duecheck's ACTION_NEEDED verdict
      is a per-run OR across all active furrows, not a promise that
      every furrow needs action - it only takes one. //fh status
      shows each furrow's recorded state/timestamp if this needs
      double-checking again, and //fh inspect forces a live check
      that ignores recorded data entirely.
  v1.15.0 (2026-09-19) - Fixed run_key_sequence being extremely slow
      to navigate menus during a status check: Mark reported the
      cursor visibly crawling down to "Absolutely nothing" one Down
      press at a time, each one taking the full ~3-5s
      max_wait_per_press before the next. Root cause: run_key_sequence
      waits for NEW chat/system text to appear after every keypress
      before moving on (so a real confirmation/result isn't cut off
      early), but Down/Up only shift the highlighted menu item and
      Escape doesn't even close these particular furrow screens -
      neither ever produces any text at all. That meant every single
      Down/Escape press was blocking for the ENTIRE
      max_wait_per_press with nothing to actually wait for, instead
      of the fraction of a second the client needs to register it.
      Only 'enter' can trigger a real confirmation/result line, so
      only 'enter' now uses the dynamic wait - Down/Up/Escape go
      straight to the same short fixed pause every step already gets.
      No behavior change for 'enter' handling; this only speeds up
      the cursor-move/hygiene presses that were never getting
      anything useful out of the wait to begin with.
  v1.16.0 (2026-09-19) - Mark caught a gap in v1.15.0's fix: treating
      every 'enter' as text-producing was itself wrong for one case -
      the FINAL enter in each EXIT_SEQUENCES entry, which always
      comes right after Down/Down navigation onto the closing/cancel
      selection ("Absolutely nothing") and is just as silent as the
      Down presses before it. That enter was still burning the full
      max_wait_per_press for nothing, same symptom as before, just
      narrowed down to one specific press per status check instead of
      several. run_key_sequence's steps can now be a plain key name
      OR a {key, wait = true/false} table that overrides the default
      per-key assumption for that one position - used to mark exactly
      that closing enter (and only that one) as wait = false in all
      four EXIT_SEQUENCES entries. The other enters (DETECT_SEQUENCE,
      and growing_unfertilized/growing_fertilized/ready's FIRST
      enter, which can show a real "still growing"/"ready" line)
      still get the dynamic wait as before. Also added
      describe_sequence() since table.concat can't handle a steps
      list that mixes plain strings and these override tables - used
      wherever a sequence gets logged.
  v1.17.0 (2026-09-19) - Fixed a real regression from v1.15.0/
      v1.16.0: cutting Down/Up/Escape (and wait=false 'enter')
      straight down to a 0.3s pad was too aggressive for real
      gameplay. Checked Woodvf's own log (2026-09-19, ~01:03-01:06):
      Garden Furrow's growing_fertilized exit sequence
      (enter, down, down, enter) landed on the PLANT/seed-selection
      prompt ("Nothing has been planted in this furrow. Select a
      seed...") instead of closing cleanly via "Absolutely nothing" -
      consistent with a Down press not having actually registered
      before the next key fired, leaving the cursor one item off from
      where the sequence assumed it'd be. That stuck-open prompt then
      likely blocked Garden Furrow #2's own detection right after
      (its DETECT_SEQUENCE got zero new text within 3s, "menu may
      still be open" - both //fh plant and //fh inspect showed this
      same pattern that session). Added CURSOR_SETTLE_SECONDS (1.0s):
      cursor-move/hygiene keys now pause 1.0s before the next key
      fires instead of 0.3s - still roughly 3x faster than the
      pre-v1.15.0 behavior (which burned the full max_wait_per_press,
      ~3-5s, on every one of these keys for nothing), but with real
      margin for the client to actually register the press first.
      'enter' keys that DO wait for text are unaffected - still the
      same dynamic wait plus 0.3s pad as before.
  v1.18.0 (2026-09-19) - Added approach_furrow(): when a furrow ends
      up too far away to interact with (e.g. right after zoning into
      the Garden), find_furrow() now automatically walks the
      character over instead of failing the interaction. Uses the
      real in-game Lock On camera key (Mark's binding: Numpad *,
      Windower key name 'numpad*') plus holding the normal Move
      Forward key (W) - the same as running there by hand, not any
      kind of teleport/position-packet automation. Polls distance via
      windower.ffxi.get_mob_by_id(furrow_id).distance:sqrt() (that
      field is squared distance) until within
      config.approach_target_distance yalms (default 2.0) or
      config.approach_timeout_seconds (default 20s) runs out, then
      releases Forward then Lock On. Deliberately never touches
      targeting (no 'target clear') since every find_furrow() caller
      interacts with the still-current target immediately afterward.
  v1.18.1 (2026-09-19) - Moved the approach_furrow() call out of
      find_furrow() itself and up to a single spot in each of
      start/startonce/plant/fertilize/harvest/inspect (right after
      that command's one-time reconcile_furrow_data() call), always
      aimed at Furrow #1 specifically. v1.18.0 called it from inside
      find_furrow(), which runs once per furrow PER command (and
      again anywhere a cycle re-targets the same furrow later, e.g.
      to fertilize right after planting) - so the character would
      hold Lock On/Forward and re-check distance for furrow 2 and
      furrow 3 too, every single time, even though getting close to
      Furrow #1 already puts all three within interaction range (the
      distance check made this harmless in that it never actually
      moved anyone twice, but it was still redundant work/log noise
      on every pass). duecheck deliberately does NOT get this call -
      it's the fast, read-mostly, no-menu-opening check MuleLogger
      calls every login, and it shouldn't walk the character over
      just to conclude nothing is due yet.
  v1.18.2 (2026-09-19) - Fixed a real "wrong key reaches the Harvest
      confirmation box" bug Mark heard live (the error tone, not just
      a guess): harvest_furrow()'s fixed-delay menu_steps only waited
      1s between the enter that opens "Harvest? Yes/No" (Yes
      highlighted) and the enter meant to confirm it - not always
      enough time for that box to actually be up yet, so the
      confirming enter could fire too early and land on nothing,
      leaving the step AFTER it (escape) to be what actually reached
      the now-up box instead of confirming it. Extended that one
      delay (1s -> 2.5s) in both menu_steps variants (already_in_menu
      and the standalone blind sequence) - same position in both,
      see the comment above harvest_furrow for why they line up.
  v1.19.0 (2026-09-19) - Fixed approach_furrow() sitting the
      character down instead of locking on. Root cause (confirmed by
      Mark): Numpad * is genuinely the right Lock On key on his
      setup, but it's context-sensitive - with NO target active it
      Sits/rests instead, and only locks on with a real target
      active. reconcile_furrow_data's existence probe (which every
      command runs right before approach_furrow, per v1.18.1) clears
      the target as its very last step, so by the time approach_furrow
      tapped Numpad * there was nothing targeted - hence Sit.
      approach_furrow now takes a furrow NUMBER instead of a raw id/
      name and calls find_furrow() itself first to guarantee a real
      target exists immediately before tapping Lock On (moved to
      right after find_furrow()'s own definition so it can call it).
      Also changed Lock On from a HELD key to a TAP/toggle (down+up,
      then again to release at the end) - it shares a key with Sit,
      which is itself a discrete toggle, not something you hold, so
      treating Lock On the same way matches how this key actually
      behaves rather than assuming a hold-to-lock camera feature that
      was never confirmed to exist. Call sites updated from
      approach_furrow(FURROWS[1].id, FURROWS[1].name) to
      approach_furrow(1).
  v1.19.1 (2026-09-19) - harvest_furrow() still fired the wrong key
      at the Harvest? Yes/No confirmation box even after v1.18.2
      widened the fixed delay in front of it (1s -> 2.5s): Mark
      heard the error tone again, with escape reaching an open text
      box and having to close it with Enter by hand. A fixed delay
      was never going to reliably cover this - it's exactly the same
      class of bug plant_seed/fertilize_furrow/DETECT_SEQUENCE/
      EXIT_SEQUENCES already moved off of (see v1.15.0-v1.17.0).
      harvest_furrow is now forward-declared next to plant_seed/
      fertilize_furrow and its real body (placed right after
      fertilize_furrow's) uses run_key_sequence instead of its own
      fixed-delay loop - every enter (including the Yes/No
      confirmation) now dynamically waits for its own real result
      text (up to 4s) before the next key fires, rather than a
      guessed pause. Steps are unchanged (3 enters+escape for
      already_in_menu, 5 enters+escape standalone).
  v1.19.2 (2026-09-19) - Mark clocked the hardcoded 4s wait-per-enter
      from v1.19.1 at around 5s in real testing and wants to keep
      tuning it down while evaluating. Pulled it out to
      config.harvest_max_wait_per_press (3 now, was inline 4) so it's
      a one-line edit to try lower values (e.g. 2) instead of a code
      change each time.
  v1.19.3 (2026-09-19) - Same treatment for plant_seed's own
      confirmation sequence: pulled its hardcoded run_key_sequence
      wait (3) out to config.plant_max_wait_per_press, since Mark
      saw the final planting confirmation enter sit for a similar
      ~5s. Value is unchanged (3) for now - just made tunable the
      same way harvest_max_wait_per_press is, so it's a one-line
      edit to try lower. fertilize_furrow has the identical
      run_key_sequence({'enter','enter','enter','escape'}, 3) call
      but wasn't mentioned - left as a plain 3, same treatment
      available on request if it needs it too.
  v1.19.4 (2026-09-19) - Mark caught a real furrow (Garden Furrow #3)
      get logged as "assuming it does not exist" ~60s after that
      SAME furrow was confirmed to exist earlier in the same run
      (reconcile_furrow_data's own probe). Checked whether
      find_furrow()'s name check after settarget could be fooled by
      a stuck cursor landing on some unrelated object - it can't:
      the confirm loop matches on target.name == furrow_name
      exactly, and only the real Garden Furrow #<n> entity has that
      name, so a wrong object would just correctly report "not
      found", never a false positive. More likely explanation: the
      old confirm_attempts (5, 1.0s total) simply wasn't enough time
      for settarget to resolve that particular time, right after two
      back-to-back harvest/plant cycles on the other furrows -
      widened confirm_attempts to 15 (3.0s total) to give a
      genuinely-existing furrow more room before being written off.
  v1.19.5 (2026-09-19) - Found the real cause of a DIFFERENT furrow-3
      false positive Mark caught on GenPopvf: the existence probe
      cleanly found Garden Furrow 1, 2, AND 3 with no gap at all (so
      the existing gap-based retry above never triggered), yet
      GenPopvf genuinely only has furrows 1 and 2 - confirmed by the
      very next real pass failing to target #3 at all. Root cause is
      most likely a stale entity left over in the client's local
      cache from whichever character was logged in on this same
      client immediately before GenPopvf in MuleLogger's rotation -
      //ml swaps characters via /logout+login without restarting the
      game client, so a previous character's own (real) Garden
      Furrow #3 entity could still be sitting in the client's entity
      table with a valid name, even though it isn't part of the NEW
      character's own Mog Garden instance at all. Since furrows only
      ever unlock in order, a phantom can only ever be the topmost
      found number - added a mandatory re-check of just that one
      after the existing probe/retry loop: re-target furrow 1 first
      (forces a fresh lookup instead of trusting whatever's still
      "targeted"), then re-target and re-confirm the highest number
      again; if it doesn't re-confirm, it's dropped from the
      available list for this run.
  v1.20.0 (2026-09-19) - Added record_seed_inventory(), called from
      'duecheck' (the one command MuleLogger's rotation always
      triggers on every mule visit) so the last-known count of
      config.default_seed is kept fresh in data/<CharacterName>.xml
      on every login, not just ones that actually plant something.
      Also shown now in //fh status. Built for MuleLogger's new
      //ml status command (v1.11.0), which reads this same file
      directly across every character to build a per-mule report.
  v1.20.1 (2026-09-19) - Added config.harvest_confirm_extra_wait: a
      fixed pause right before harvest_furrow's final Enter (the one
      that actually confirms the Yes/No harvest prompt), via a new
      per-step pre_wait option in run_key_sequence. Mark caught
      furrow 3's confirm firing too early during a 3-in-a-row
      harvest (furrows 1 and 2 harvested fine): the Yes/No prompt
      was still up a few seconds later, and the trailing Escape then
      hit that still-open prompt (invalid-action beep) instead of an
      already-closed menu - most likely cumulative server lag after
      two harvests already done in the same pass. Targets just that
      one press instead of raising harvest_max_wait_per_press for
      every step.
  v1.20.2 (2026-09-19) - Added config.text_settle_seconds and a
      debounce loop in run_key_sequence: once an Enter's dynamic
      wait sees its first new line of text, it now keeps watching
      and only moves on once text has gone quiet for
      text_settle_seconds (default 0.5s), instead of a flat 0.3s pad
      from the moment the FIRST line appeared. Root-caused from
      Mark's Shadowhammer //fh inspect log: Garden Furrow #2's
      DETECT_SEQUENCE only captured a short partial line ("...has a
      revival tree root planted in it.") missing the "devoid of
      fertilizer" clause every other furrow's capture had -
      classify_furrow_text correctly returned 'unknown' for that
      fragment, so (by design) no exit sequence ran and furrow #2's
      menu was left open - almost certainly the real cause of the
      "You must close the currently open window"/stray
      plant-confirmation mess reported on furrow 1 a minute later.
      Same family of bug as v1.20.1's harvest fix: something on
      screen changes before the code was actually ready to treat it
      as settled.
  v1.20.3 (2026-09-19) - Added print_captured_lines(), a display-only
      filter used everywhere a "Captured text:" block gets echoed to
      chat (live_probe_furrow's auto and explicit-sequence paths,
      harvest_furrow's debug print): skips a line that's an exact
      repeat of the one right before it. Mark's own screenshots
      showed "has matured!"/"devoid of fertilizer" lines each
      showing up as an identical back-to-back pair in that printout
      - the game client re-firing the same incoming-text line more
      than once, harmless to classify_furrow_text (which just scans
      for substrings) but redundant noise for a human reading it.
      Only the printed output changes - the underlying `lines` table
      passed to classify_furrow_text and used by run_key_sequence's
      own debounce logic is untouched.
  v1.21.0 (2026-09-19) - Added an optional (config.sell_junk_enabled,
      default off) sell-junk-to-moogle step, run once at the end of
      run_single_furrow_pass - shared by both 'start' and
      'startonce', so this covers both, and runs before MuleLogger's
      own RoE/Unity chat steps (which happen afterward, in a
      different addon, once this command returns). Loads SellNPC's
      junk list ('SellNPC Junk'), targets the Mog Garden moogle
      (config.sell_junk_moogle_id), and interacts with it - the
      standard shop greeting means SellNPC (already loaded with the
      junk list) takes over and does the actual selling itself; any
      other response is treated as a quest reminder/cutscene in the
      way and cleared (Escape x3, then Enter/Escape alternating)
      before retrying, bounded by sell_junk_max_attempts so a
      genuinely stuck screen can't loop forever.
  v1.21.1 (2026-09-19) - Corrected sell_junk_to_moogle's flow per
      Mark: getting the standard greeting only opens the moogle's
      dialogue, not the Buy/Sell menu itself - added
      config.sell_junk_menu_sequence (Enter, Down, Enter) to actually
      navigate into that menu afterward, before handing off to
      SellNPC.
  v1.22.0 (2026-09-19) - Added furrow_N_rank to status_defaults and a
      third optional `lines` param to record_furrow_state(): when
      given, it opportunistically pulls "rank N" out of the captured
      text (present in the same classifying lines classify_furrow_text
      already scans) and saves it alongside the state. Only wired up
      at the call sites that actually have real captured text on
      hand - live_probe_furrow (both //fh inspect paths) and
      handle_furrow_for_start's own live-detect fallback - the many
      other record_furrow_state call sites (state changes inferred
      purely from elapsed time, no fresh text) are left alone and
      just keep whatever rank was last recorded, since a furrow's
      rank barely changes. Built for MuleLogger's //ml status
      (v1.12.0), which now shows rank per furrow.
  v1.22.1 (2026-09-19) - Two more corrections from Mark to
      sell_junk_to_moogle: config.sell_junk_menu_sequence is actually
      Enter, Down, Enter, Enter (was missing the final Enter) to
      reach the Buy/Sell menu, and added a step 5 - Escape once,
      after giving SellNPC time to sell, to close back out of the
      moogle's shop screen.
  v1.22.2 (2026-09-19) - Added //fh config selljunk, a runtime
      toggle for config.sell_junk_enabled (same pattern as the
      existing 'debug' toggle) so Mark can turn the sell-junk step
      on to test it without editing the file - explains his
      "//fh startonce did nothing, then didn't sell to the moogle"
      report on SmithVF (2026-09-19 13:18): sell_junk_enabled's
      hardcoded default is still false (v1.21.0), there was no way
      to flip it at runtime, and reloading the addon always resets
      it back to that default anyway - so sell_junk_to_moogle() was
      returning at its very first line with no log output at all,
      exactly matching what was seen. Also shown now in
      //fh config show and the config options help.
  v1.23.0 (2026-09-19) - Root-caused Mark's "harvest crops stuck on
      screen, heard an invalid-key beep" report on Shadowhammer
      furrow 3: NOT a harvest timing issue - the log showed
      plant_seed being called because recorded status (stale) said
      'empty', but the furrow had actually already matured, so the
      seed item-use was flatly REFUSED ("There is no need to
      fertilize the revival tree root, for it is ready to harvest!")
      with no Yes/No confirm menu ever opening. The old code had no
      way to know that and blindly ran its usual enter/enter/enter/
      escape sequence anyway, which ended up interacting with the
      furrow's own separate talk menu instead (opened by one of
      those blind enters) and leaving it stuck on whatever it
      landed on when the trailing escape hit it. Fixed: plant_seed/
      fertilize_furrow now check the item-use response for
      config.item_use_reject_phrase ("There is no need to") BEFORE
      running that sequence - on a match, nothing is blindly
      pressed, the real state is reclassified from the rejection
      text itself (classify_furrow_text now also recognizes "ready
      to harvest", the exact phrase in that rejection, as 'ready',
      same as "has matured") and saved via record_furrow_state so
      the next pass acts correctly instead of repeating the same
      failed attempt. Both functions now take an optional
      furrow_number param (passed at all 5 call sites) to make that
      correction possible; wait_for_response now returns its
      captured lines so callers can actually inspect what came back.
  v1.23.1 (2026-09-19) - Fixed print_captured_lines still showing
      duplicate lines Mark caught in a screenshot: the game's repeat
      firing of the same line often stamps only ONE of the two
      copies with a "[HH:MM:SS] " prefix, so the exact-string
      comparison added in v1.20.3 didn't recognize them as the same
      line. Now strips that prefix (if present) from both sides
      before comparing.
  v1.23.2 (2026-09-19) - config.sell_junk_enabled now defaults to
      true, per Mark's request - the //fh config selljunk runtime
      toggle still works to turn it off for a session.
  v1.24.0 (2026-09-19) - Two changes:
      1. Fixed sell_junk_to_moogle()'s broken load step. The old
         single command windower.send_command('SellNPC Junk') was
         wrong syntax - live testing showed it always failed with
         SellNPC: "junk" not a valid item name. Replaced with the
         two real commands from Mark's own working macro book
         ('SellJunk', Ctrl+9): 'lua r sellnpc' (reload SellNPC so it
         picks up any junk-profile edits) then 'sellnpc junk'
         (actually load/trigger the junk sell list), with a new
         config.sell_junk_reload_wait_seconds (2s) pause between
         them. The macro's '/con' prefix is just how a macro line
         sends a raw console command - windower.send_command(...)
         already does that directly, so it's dropped, not translated.
      2. Added per-mule config overrides: a new character_overrides
         table (keyed by lowercase character name) lets any
         character get its own seed/fertilizer/use_fertilizer/
         harvest_time/fertilize_wait_time/reminder_intervals/
         fertilize_reminder_intervals instead of the global config.*
         defaults, edited directly in the file - unset/commented-out
         fields for a character fall through to config.* as before.
         Every internal read of those config.* fields (main_loop,
         infer_furrow_state, plant_seed/fertilize_furrow's defaults,
         handle_furrow_for_start, start/startonce/duecheck/plant/
         fertilize's command handlers) now goes through a matching
         get_effective_*() function instead, which checks this
         character's override first. Set up per Mark's request:
         Shadowhammer now uses 'Tree Sapling' with a 48 Earth Hour
         (real-world, i.e. 172800s) growth time, structured with the
         Revival Root/1-hour global-default pair commented out right
         below it in the same entry, so switching seeds later is a
         two-line comment/uncomment instead of retyping values.
         //fh status and //fh config show both now print the
         per-character EFFECTIVE seed/fertilizer/use_fertilizer/
         growth time plus which fields (if any) are overridden, so
         it's always clear what's actually active in-game; the
         config seed/fertilizer/usefertilizer/waittime commands still
         only change the session-only global default and now warn
         when this character's own override would still take
         precedence over them.
  v1.25.0 (2026-09-19) - Two tweaks to sell_junk_to_moogle(), per
      Mark: raised config.sell_junk_after_open_wait_seconds from 3 to
      30 seconds (selling the whole junk list can take longer than
      3s let it), and added a Treasury reload step right after that
      wait - windower.send_command('lua r treasury'), then a new
      config.treasury_reload_wait_seconds (3s default) pause - to
      trigger Treasury dropping any unwanted items on its own drop
      list before this addon closes out of the moogle's shop and
      moves on. Runs every pass sell_junk_enabled is on, right after
      the junk sell and before the closing Escape.
  v1.26.0 (2026-09-19) - Renamed two //fh commands per Mark's
      request: 'start' -> 'loop' (the continuously-repeating
      harvest/plant/fertilize/wait automation) and 'startonce' ->
      'full' (a single merged pass, no wait/recurse - the one
      MuleLogger's rotation triggers per mule). Every comment/help
      text describing current behavior was updated to match; past
      changelog entries below keep the old names since that's what
      the commands were actually called at the time. IMPORTANT: this
      is a breaking rename - MuleLogger.lua's own command string
      (windower.send_command('fh startonce')) was updated to 'fh
      full' in the same pass (see MuleLogger's changelog) - the two
      addons must be reloaded together, not one at a time, or
      MuleLogger will call a //fh command that no longer exists.
  v1.27.0 (2026-09-19) - Fixed sell_junk_to_moogle() skipping the
      junk sell entirely on GenPopVF: log evidence showed "Reloading
      SellNPC..." -> "SellNPC: Loaded profile \"junk\"" -> immediately
      "[ERROR] Could not target the Mog Garden moogle ... - skipping
      junk sell this pass" -> "Single pass complete.", meaning the
      ONE settarget attempt (0.3s flat wait, no retry, no walk-over)
      failed once and the whole step just gave up - unlike furrows,
      which always got a proper find+confirm-by-name+walk-over via
      find_furrow/approach_furrow. Added find_moogle() (same
      confirm-by-name pattern as find_furrow, 3s window) and
      walk_to_entity() (approach_furrow's movement logic, pulled out
      so it isn't furrow-specific anymore) - the existing
      sell_junk_max_attempts retry loop now actually retries
      targeting+walking over on failure instead of returning
      immediately on the first miss.
  v1.28.0 (2026-09-19) - Added an Escape press right after
      config.sell_junk_after_open_wait_seconds finishes, to close the
      Buy/Sell menu itself before reloading Treasury - previously the
      only Escape in this flow came after the Treasury reload, so the
      Buy/Sell menu itself was never explicitly closed on its own
      (Mark's request). The existing final Escape/target clear after
      the Treasury reload is unchanged and still closes out of the
      moogle's outer greeting dialogue.
  v1.28.1 (2026-09-19) - Correction to v1.28.0: Mark confirmed only
      ONE Escape is needed in this flow, right after
      config.sell_junk_after_open_wait_seconds finishes and BEFORE
      the Treasury reload - not a second one after Treasury too.
      Removed the trailing Escape that ran after 'lua r treasury';
      target clear still runs afterward to leave a clean state.
  v1.28.2 (2026-09-19) - Fixed 'inspect' running through every
      furrow's Detecting/Guessed-state sequence TWICE per run -
      confirmed on GoldVF's own log and a screenshot Mark sent
      (Garden Furrow and #2 each detected once, "Furrows available
      this run: 1 2" logged, then BOTH detected again before "Inspect
      complete."). Root cause: 'inspect' called
      reconcile_furrow_data() with no argument, so skip_status_probe
      was falsy and reconcile ran its own "Furrow count/data
      mismatch...refreshing all of them" live_probe_furrow pass
      (true whenever recorded status doesn't match the available
      count, e.g. every fresh/empty data file) - then inspect's own
      explicit live_probe_furrow loop ran right after, redoing the
      exact same live check a second time. inspect already always
      does a full live probe of its own by design, so reconcile's
      status probe was never needed here - changed the call to
      reconcile_furrow_data(true) (existence check only, same as
      loop/full/duecheck use) so inspect's own loop is the only live
      probe. Cuts //fh inspect's runtime roughly in half.

============================================================
GardenHelper (2026-09-19) - forked from FurrowHelper v1.28.2 above.
Everything above this point is FurrowHelper's own historical
changelog, preserved verbatim/unrenamed since each entry is a
quotation of what was literally true/printed in FurrowHelper at that
time - GardenHelper's own changelog starts fresh below.
============================================================

  v1.0.0 (2026-09-19) - Forked from FurrowHelper v1.28.2 for full Mog
      Garden management, per Mark's spec. Renamed FurrowHelper ->
      GardenHelper throughout (_addon.name/commands: 'fh' -> 'gh',
      alongside the existing //gardenhelper), and every existing
      furrow command got a 'furrow' prefix (start/loop -> furrowloop,
      full -> furrowfull, duecheck -> furrowduecheck, plant ->
      furrowplant, fertilize -> furrowfertilize, harvest ->
      furrowharvest, inspect -> furrowinspect, status -> furrowstatus,
      config -> furrowconfig; stop/abort/help unprefixed). Added:
        - Full Mog Garden entity reference (VEINS, POND, GROVES,
          GREEN_THUMB_MOOGLE, EPHEMERAL_MOOGLE, FLOTSAM, NET, plus a
          documentation-only EXTRA_NPCS table) alongside the existing
          FURROWS table, all fixed entity IDs Mark documented
          2026-09-19.
        - Generic find_entity()/press_enter_cycle() helpers for the
          new modules' fixed-cadence "press Enter N times, M seconds
          apart" interaction style - deliberately distinct from the
          furrow menus' dynamic wait-for-text-to-settle
          run_key_sequence(). press_enter_cycle also supports an
          optional extra_wait_after a cycle's last press (with text
          capture still on) - vein and grove use
          config.vein_grove_excavation_wait_seconds here (both
          trigger multiple excavations per cycle and the resulting
          items can take a little while to appear), net uses
          config.net_cutscene_extra_wait_seconds for its short
          post-interaction cutscene.
        - JST-day-aware (UTC+9, via a configurable local-hour offset
          - config.jst_reset_local_hour, since Mountain Time DST
          shifts the real conversion by an hour) once-per-day
          tracking (get_garden_day_string/node_done_today/
          record_node_harvest) for vein/pond/grove/flotsam/net,
          persisted to status_defaults the same way furrow state is.
        - harvest_vein/harvest_pond/harvest_grove/harvest_flotsam/
          harvest_net: always harvest the HIGHEST unlocked
          vein/grove, falling back downward if unavailable; vein
          repeats its press cycle until config.vein_stop_phrase shows
          up (bounded by config.node_max_attempts); grove tries both
          Prune the trees/Remove weeds variants (only one is
          targetable at a time); pond/net check
          config.pond_already_done_phrase/net_already_done_phrase as
          a live fallback on top of the data-file check; flotsam
          treats "can't find/target it" as "already done and gone"
          unless forced, and flags (but does not yet act on)
          config.flotsam_cant_receive_phrases - Mark's own
          untested/TBD case (already holding one).
        - harvest_crystals: pure stub (Ephemeral Moogle trade flow is
          TBD per Mark) - logs and returns, no menu sequence guessed.
        - run_full_garden_pass(force): orchestrates the whole pass in
          Mark's documented pathing order - Furrows -> Sell -> Vein
          -> Pond -> Sell -> Grove -> Sell -> Crystals -> Flotsam ->
          Net -> Sell (final, covers Treasury too). A Green Thumb
          Moogle waypoint before Pond is noted as possibly needed but
          NOT implemented - untested, flagged inline for later.
        - New top-level commands: full, force (bypasses every
          module's once-per-day check), furrow (alias for
          furrowfull), vein/pond/grove/crystals/flotsam/net (each
          takes an optional trailing "force" argument), and a new
          compact status (distinct from furrowstatus) summarizing
          rank + done-today across the whole garden.
      Every new module's live timing/phrasing is UNTESTED against the
      real game - shell/skeleton per Mark's own instruction, expect
      adjustment once tried live. MuleLogger is NOT changed by this -
      it still targets FurrowHelper's own //fh full/duecheck for mule
      rotations, unaffected by GardenHelper's existence so far.
  v1.1.0 (2026-09-20) - Live-tested timing update after Mark ran
      //gh vein on FishVF ("worked pretty good"). press_enter_cycle
      now takes an explicit per-press waits array instead of a flat
      (presses, wait_seconds) pair, since different presses in the
      same cycle need different waits. vein_press_waits set to
      Mark's own confirmed live timing: 5s after the 1st Enter, 3s
      after the 2nd, 8s after the 3rd. Applied grove_press_waits =
      the same {5, 3, 8} (Mark: "use these updated delays for Grove
      as well" - grove also does multiple excavations per cycle,
      same as vein). pond/flotsam/net_press_waits changed from a
      flat {3, 3, 3} to {5, 3, 3} (Mark: "use an initial 5s wait
      after the 1st enter for Net and Flotsam and Pond as well") -
      these three are still otherwise untested live. Also added
      "highest #" status logging Mark asked for: harvest_vein now
      logs "Highest available vein: #N. Harvesting <name>..." and
      harvest_grove logs "Highest available grove: rank #N." before
      working each variant, so the chat log shows which specific
      vein/grove rank was picked, not just that "a" vein/grove was
      found.
  v1.2.0 (2026-09-20) - Mineral Vein now handled like Arboreal
      Grove, per Mark's own finding after updating VEINS' entity ids
      from live testing: each rank has TWO vein entity ids (not one),
      and the one currently being harvested can disappear/deplete
      mid-session - continuing at that rank means finding the OTHER
      id, not stopping. Restructured VEINS from a flat 6-entry list
      into the same {rank, variants} shape GROVES already uses.
      find_highest_vein now returns both the chosen rank and the
      specific variant found (mirrors find_highest_grove).
      harvest_vein's loop now re-checks the current vein after every
      press_enter_cycle call and, if it's gone, tries the other
      variant at the SAME rank before giving up - only
      config.vein_stop_phrase, or both variants at that rank being
      gone, ends the pass (never drops to a lower rank mid-harvest).
      record_node_harvest now records vein_rank.rank directly instead
      of parsing "rank N" back out of captured text.
  v1.3.0 (2026-09-20) - Interact-distance tuning after Mark's live
      //gh pond test: pathing couldn't reliably close all the way to
      the tight furrow distance (approach_target_distance, 2 yalms),
      but 5 yalms is actually plenty to interact with vein/pond/
      grove/ephemeral moogle/flotsam/net. Added a new
      config.node_approach_distance (5.0) for those; furrows and the
      Green Thumb Moogle keep the original tight
      approach_target_distance unchanged (Mark: character should end
      up VERY close to Garden Furrow #1 specifically, close enough to
      reach all three furrows from that one spot). walk_to_entity now
      takes an optional target_distance parameter (defaults to
      approach_target_distance when omitted, so furrow/moogle callers
      are unaffected) - every vein/pond/grove/flotsam/net call site
      now passes node_approach_distance explicitly. Also: harvest_vein
      now re-walks to its current vein EVERY cycle (not just when the
      variant id changes after one disappears) - Mark's note that
      vein/grove objects can move around after each harvest attempt,
      not just get replaced outright; walk_to_entity is a cheap no-op
      when already close enough.
  v1.4.0 (2026-09-20) - Two changes to selling, per Mark:
      1. Separated SellNPC/Treasury from the furrow function -
         run_single_furrow_pass (shared by furrowloop/furrowfull/the
         furrow alias) no longer calls sell_junk_to_moogle() itself.
         This also fixes a real double-sell bug in //gh full/force:
         run_full_garden_pass already called sell_junk_to_moogle()
         explicitly right after the furrows step, so it was running
         TWICE back to back. Selling is now a fully standalone step,
         added as its own new //gh sell command, and still called at
         run_full_garden_pass's own documented checkpoints.
      2. The fixed post-open wait before closing the Buy/Sell menu
         is now dynamic: sell_junk_to_moogle waits for SellNPC's own
         completion message (config.sell_junk_complete_phrase,
         'SellNPC: Selling') instead of always sleeping
         config.sell_junk_after_open_wait_seconds - a short sell and
         a long sell both now move on to 'lua r treasury' as soon as
         SellNPC actually finishes. sell_junk_after_open_wait_seconds
         is repurposed as a safety-bound MAX wait in case that
         message is ever missed. New generic helper: wait_for_phrase
         (like wait_for_response, but for one specific phrase).
  v1.4.1 (2026-09-20) - Removed the Ephemeral Moogle (crystals) line
      from //gh status, per Mark - crystal trading isn't implemented
      yet (harvest_crystals is still a pure TBD stub), so it had
      nothing real to report.
  v1.5.0 (2026-09-20) - Fixed harvest_vein wasting a full extra
      press cycle once a vein was depleted. Mark noticed
      config.vein_stop_phrase ("It would probably be best to stop
      for now.") printing TWICE in chat before the script actually
      moved on - root cause: a depleted vein prints that message on
      EVERY Enter press, but press_enter_cycle always fired all 3 of
      vein_press_waits' presses before harvest_vein's loop ever
      checked for the stop phrase, so the message showed up 2-3
      times per leftover cycle before it was noticed. press_enter_cycle
      now takes an optional stop_phrase argument and checks for it
      after EVERY individual press (not just once per full cycle),
      breaking out of its own press loop (and skipping any
      extra_wait_after) the moment it appears. harvest_vein passes
      config.vein_stop_phrase here, so it now reacts after the FIRST
      occurrence instead of running the rest of that cycle's presses
      first. (lines_contain was moved above press_enter_cycle in the
      file so it could call it - no behavior change there.)
  v1.6.0 (2026-09-20) - Two changes, per Mark:
      1. Added config.harvest_success_phrase ('You have successfully
         performed that action') as a second early-exit signal for
         press_enter_cycle, alongside each module's own stop/done
         phrase - confirmed by Mark for Grove, ASSUMED the same
         wording for Vein pending his validation on another
         character. press_enter_cycle's third argument is now
         early_exit_phrases (a single phrase or a list) instead of
         just stop_phrase, so a confirmed successful harvest also
         cuts a press cycle short, not only a stop/done message.
         harvest_vein and harvest_grove both now watch for their own
         stop/done phrase AND harvest_success_phrase together.
      2. Rewrote harvest_grove to repeat exactly like harvest_vein,
         per Mark's own description: "the grove is just like the
         vein... target the highest object #, move to it, harvest
         it, then retarget it, but if it is not there then target
         the other object of the same level... repeat all this till
         you get the text that you can't anymore." Previously
         harvest_grove tried each of the two variants exactly ONCE
         and stopped; it now loops (bounded by config.node_max_attempts)
         re-harvesting and switching between the two variants at the
         current rank until config.grove_done_phrase appears, the
         same shape as harvest_vein's loop. find_highest_grove now
         returns the specific variant found too (mirrors
         find_highest_vein), not just the rank.
  v1.6.1 (2026-09-20) - harvest_crystals now navigates to the
      Ephemeral Moogle and logs "Trading Crystals is to be built"
      plus the standard "<name> trading complete." completion line,
      per Mark - still no actual trade logic (that part remains
      TBD), just the shell now doing real movement instead of a bare
      debug_log skip message.
  v1.7.0 (2026-09-20) - //gh status now shows "not found" for a
      furrow this character doesn't have, per Mark (screenshot: his
      Garden Furrow #3 was showing "rank 0, unknown" instead of
      something clearer). reconcile_furrow_data now persists
      furrow_N_state = 'not_found' for any furrow slot it doesn't
      find this run, and clears it back to 'unknown' the moment that
      furrow IS found again (e.g. a newly-unlocked rank), so the
      existing furrow-count/data mismatch check still schedules a
      real live probe for it rather than trusting a stale not_found
      forever. show_garden_status prints "Garden Furrow #3: not
      found" for that state instead of "rank 0, not_found".
  v1.8.0 (2026-09-20) - Added a whole-garden //gh duecheck command,
      so MuleLogger (switching from //fh duecheck/full to //gh
      duecheck/full) can gate a mule visit on the FULL garden instead
      of just furrows. furrowduecheck alone would report "not due"
      for potentially days at a stretch whenever furrows have a long
      growth time, even though vein/pond/grove/flotsam/net reset
      every REAL day - duecheck now ALSO reports ACTION_NEEDED if any
      of those five isn't recorded done for today's garden day yet.
      Same DueCheckResult: ACTION_NEEDED/NOT_DUE line format as
      furrowduecheck, for compatibility with MuleLogger's existing
      parser.
  v1.9.0 (2026-09-20) - Added clear_cursor_state(), which sends
      Escape down/up twice (with brief settle waits) before any
      module function begins acting. Per Mark: "I am seeing that the
      cursor is on the character sometimes, so we need to send key
      ESC ESC before any function is run" - a lingering
      menu/targeting cursor state was apparently able to interfere
      with a fresh command's own targeting/menu steps. Called at the
      start of sell_junk_to_moogle, harvest_vein, harvest_pond,
      harvest_grove, harvest_crystals, harvest_flotsam, harvest_net,
      and run_full_garden_pass (before its own existing target
      clear). Deliberately NOT added to the furrow-only dispatcher
      branches (furrowloop/furrowfull/furrowplant/furrowfertilize/
      furrowharvest/furrowinspect), which are pre-existing
      hand-verified FurrowHelper-inherited code with their own
      separate target-clear pattern already.
  v1.10.0 (2026-09-20) - //gh status now aligns every value into a
      single column instead of each line just being "label: value"
      back-to-back, per Mark: "is it possible to have this in a
      table format... putting spaces after the object to the status
      all line up". show_garden_status now builds label/value rows
      first, finds the longest label across all of them, then pads
      every label out to that width (+2 spaces) before printing the
      value - this assumes the in-game chat log font is fixed-width;
      if it isn't and the columns still look uneven once reloaded,
      the padding is easy to tune further (per-label instead of one
      shared max-width) since it's now computed from a plain list of
      {label, value} rows rather than baked into each log() call.
  v1.11.0 (2026-09-20) - //gh full/force now skips the sell/Treasury
      step after any stage where nothing was actually harvested,
      per Mark: "if there is no harvesting done on previous objects,
      then no need to sell/Treasury." handle_furrow_for_start,
      run_single_furrow_pass, harvest_vein, harvest_pond,
      harvest_grove, harvest_flotsam, and harvest_net all now return
      true/false for whether a real harvest happened (vein/grove:
      true if config.harvest_success_phrase showed up at least once;
      pond/net: true unless their own "already done" phrase showed
      up; flotsam: true if it was found and interacted with at all).
      run_full_garden_pass uses these to gate its three mid-pass
      sell_junk_to_moogle() calls (furrow / vein+pond / grove) and
      its final one (flotsam+net), logging why a sell was skipped
      each time instead of silently doing nothing. Also added
      config.process_crystals (default false) - the Ephemeral
      Moogle crystal-trading step is disabled entirely for now (it's
      still a pure TBD stub) until the real trade flow is built;
      harvest_crystals checks this itself and returns immediately if
      off, so //gh full just flows straight from grove to flotsam to
      net, same as a direct //gh crystals command would also now
      no-op. Since the final sell step (which also walks back to the
      Green Thumb Moogle as a side effect of talking to it) can now
      be skipped too, added return_to_green_thumb_moogle() to make
      that same walk on its own whenever the final sell is skipped -
      per Mark, //gh full should always end up back near the Green
      Thumb Moogle regardless of whether anything was sold.
  v1.12.0 (2026-09-20) - //gh status's header line now shows the
      date/time of the last //gh full or //gh force that actually
      ran to completion ("last full pass: 2026-09-20 14:32:05", or
      "never" if one hasn't yet), replacing the old "garden-day
      2026-09-19, resets ~8:00 local time" line, per Mark's request
      after seeing the newly-aligned status table in-game. Added
      status_defaults.last_full_pass_at/epoch and a small
      record_full_pass_complete() helper, called from the very end
      of run_full_garden_pass right before its own "Full Mog Garden
      pass complete." log line - so this only updates on a genuine
      full completion, never on a pass stopped early by //gh stop.
  v1.13.0 (2026-09-20) - //gh full/force no longer walks over to the
      furrows at all when nothing is actually due there. Previously
      reconcile_furrow_data(true) + approach_furrow(1) always ran
      unconditionally before run_single_furrow_pass even checked the
      data, so a fully-recorded, still-growing set of furrows still
      triggered a walk-over for nothing. Per Mark: "if the data
      shows that it's already growing and it hasn't been the full
      seed time, then it should just skip furrow fully... The only
      reason we want to do that is if there is a new furrow since
      the last data." Added furrow_pass_needed(), which trusts
      infer_furrow_state exactly like handle_furrow_for_start
      already does per-furrow: nil (no usable data - a brand new,
      never-seen furrow) or an actionable state (ready/empty) means
      something needs a live look; growing_unfertilized/
      growing_fertilized (still growing, not due yet) needs nothing.
      If EVERY active furrow is confirmed still-growing, the whole
      furrow step (approach_furrow AND run_single_furrow_pass) is
      skipped with a single "Furrows: all recorded as still growing
      (not due yet) - skipping the furrow step entirely." message,
      instead of also printing the separate "nothing harvested this
      pass" sell-skip message right after it.
  v1.14.0 (2026-09-20) - walk_to_entity now guards against the
      Numpad* Lock On key actually Sitting the character down
      instead, per Mark: "sometimes the character is sitting down
      instead of locking on... the script thinks the cursor is on
      something, but for some reason the cursor is NOT on it." Numpad*
      (config.approach_lock_on_key) is context-sensitive client-side -
      it Sits with NO target active and only Locks On with a real
      one - and Windower has no separate, non-context-sensitive "lock
      on" command; simulating that same keybind (what this addon
      already does) is the only way any Lua addon does this. Two
      changes: (1) walk_to_entity now re-confirms the CURRENT target
      ('t') is actually the entity it's about to walk to right before
      pressing Lock On (new current_target_is/retarget_entity
      helpers), instead of trusting the caller's own find_entity/
      find_furrow/find_moogle confirmation from a moment earlier,
      which could have gone stale (e.g. a just-harvested vein/grove
      briefly despawning/respawning under the same id); (2) if the
      target still somehow wasn't real, the approach loop now
      recognizes it a couple seconds in (config.
      approach_stuck_check_seconds/approach_stuck_epsilon_yalms) by
      noticing distance to the target isn't actually closing while
      Forward is held, and recovers once - release Forward, tap Lock
      On again (stands back up if sitting), retarget fresh, retry -
      instead of holding Forward uselessly for the rest of
      approach_timeout_seconds. Logs a visible (non-debug) line when
      this recovery actually triggers, so Mark can see in chat
      whether/how often this is happening.
  v1.15.0 (2026-09-20) - Added character_module_overrides, a new
      per-character table //gh full/force now checks before running
      each module, per Mark: "I need a table in the config that gh
      full looks at, and skips functions based on the table and that
      character... something like goldvf, furrow = true, vein = true,
      pond = false - in this instance it would skip the pond for
      just goldvf." Keyed the same way as the existing
      character_overrides table (lowercased character name); any
      module left out (or the character left out entirely) defaults
      to ON, only an explicit `= false` turns it off. Recognized
      keys: furrow, vein, pond, grove, crystals, flotsam, net -
      same names //gh status and the standalone //gh <module>
      commands already use. Added Goldvf's pond = false as the live
      first entry, per Mark's own example.
      Scoped deliberately to the //gh full/force flow only, the same
      way furrow's own furrow_pass_needed skip-check already works
      (checked via is_module_enabled('furrow') right there in
      run_full_garden_pass) - NOT inside each harvest_* function
      itself, so a standalone //gh vein/pond/grove/crystals/flotsam/
      net command still always runs when typed directly regardless
      of this table. Added a small run_module_if_enabled(module_key,
      label, fn) helper so the five non-furrow call sites
      (vein/pond/grove/crystals/flotsam/net) share one is_module_enabled
      check/skip-log instead of repeating it five times.
  v1.16.0 (2026-09-20) - //gh status now shows "skipped per character
      config" for a module this character has turned off via
      character_module_overrides, instead of "NOT done today" -
      per Mark, after seeing Goldvf's disabled Pond Dredger reported
      as "NOT done today" in //gh status, which reads as still
      outstanding/needs attention when it was actually never going
      to run at all for that character. show_garden_status's
      node_row now checks is_module_enabled(prefix) first (same
      check run_full_garden_pass's own run_module_if_enabled already
      uses) and shows the new label instead of the done-today/rank
      display whenever that module is disabled.
  v1.17.0 (2026-09-20) - Added configurable sell "levels" for //gh
      full/force, per Mark: "let's create a config for the levels of
      selling... Level 1, sell at the end of the full run of all the
      functions. Level 2, sell after pond, before grove. Level 3,
      current setup (sell after furrow, after pond, after grove, and
      at end). Level 4, sell after every function." Added
      config.sell_level (default 2, per Mark's own instruction) and
      config.sell_checkpoints_by_level, a table of which modules have
      an active intermediate sell checkpoint at each level - level 4
      is the only one where vein and pond each get their OWN
      checkpoint rather than sharing one, since every other level
      (including the old hardcoded v1.11.0-era behavior, now level 3)
      only ever checked once after both had been attempted. The final
      checkpoint (after Net) always fires at every level - Mark's own
      descriptions all end with "and at the end" - so it's handled
      unconditionally rather than being listed per level.
      run_full_garden_pass now tracks a single pending_sale flag
      (true whenever any module since the last actual sell returned
      true) instead of the old per-pair local variables
      (furrow_harvested/vein_harvested/etc.), and a new
      maybe_sell(module_key) closure sells and clears that flag only
      if module_key has an active checkpoint at the CURRENT sell
      level (sell_checkpoint_active) AND something is actually
      pending - so a checkpoint that exists at this level but has
      nothing to sell yet is a silent no-op (debug_log only, to avoid
      cluttering the visible log), and a checkpoint that doesn't
      exist at this level at all just lets the pending item(s) carry
      over to whichever checkpoint fires next.
      Also added get_effective_sell_level() as a thin wrapper around
      config.sell_level (not called directly at each site) - per
      Mark's own note (2026-09-20): "this may end up being a config
      we do based on the ranks of the garden, as the higher the rank
      the more items you get." A future version could compute the
      level from furrow/vein/grove rank data inside that one
      function without touching any of the checkpoint-firing logic
      in run_full_garden_pass at all.
  v1.18.0 (2026-09-20) - Added sync_module_status_flags(), which
      snapshots is_module_enabled()/node_done_today() for every
      module into new *_disabled/*_done_today saved_status fields
      (furrow/vein/pond/grove/crystals/flotsam/net for *_disabled;
      vein/pond/grove/flotsam/net for *_done_today - furrow has its
      own per-furrow state instead of a single done-today concept,
      and crystals has no once-per-day gate implemented yet). Needed
      so MuleLogger's own //ml status (Mark, 2026-09-20: wants a
      per-mule, per-module status row, including "skipped per
      config") can tell a character_module_overrides-disabled module
      apart from one that's simply not due yet - character_module_
      overrides itself lives only in this addon's own Lua source, so
      without this there'd be no way for another addon reading this
      character's settings.xml to know a module was ever disabled at
      all. Called (cheap - no menu interaction or movement) from
      //gh duecheck, the very start of //gh full/force, and //gh
      status, so the snapshot stays reasonably fresh on every path
      that realistically leads to someone checking status, matching
      //gh status's/duecheck's own existing "no live check, just
      whatever was last recorded" philosophy rather than adding a new
      one.
  v1.19.0 (2026-09-20) - sync_module_status_flags() now also computes
      furrow_next_ready_at/furrow_next_ready_epoch: either the literal
      'READY' (epoch 0) if any active furrow is immediately actionable
      (infer_furrow_state() nil/'ready'/'empty'), or the earliest
      still-growing furrow's computed next-ready timestamp/epoch
      (checked_epoch + get_effective_fertilize_wait_time()/
      get_effective_harvest_time() depending on fertilized state), or
      blank/0 if no furrows exist at all. This is Mark's own choice
      from an AskUserQuestion asked this session (2026-09-20) about
      what the Furrows column's timestamp should mean in the upcoming
      //ml status rewrite - offered "next harvest-ready time (H@)" vs.
      "last-done timestamp (D)" vs. "last-planted (P@)" vs. both, and
      Mark picked next-ready ("H@"), since that's the more actionable
      thing to know for a mule-rotation script deciding whether it's
      worth visiting a character's garden yet.
      Two ordering fixes went with this, since get_active_furrows()/
      infer_furrow_state() need state.available_furrows to be FRESH
      (i.e. reconcile_furrow_data() to have already run this pass) to
      compute an accurate ETA:
        - //gh duecheck now calls reconcile_furrow_data(true) BEFORE
          sync_module_status_flags() instead of after (it had the two
          calls backwards since v1.18.0 - harmless for the *_disabled/
          *_done_today fields v1.18.0 added, since those don't touch
          furrow data at all, but would have left furrow_next_ready
          computed from stale/pre-duecheck furrow state).
        - run_full_garden_pass now calls sync_module_status_flags() a
          SECOND time, right after the furrow section resolves
          (whether skipped-for-growing, skipped-for-disabled-character,
          or actually run), in addition to the existing call at the
          very top of the function. The top-of-function call still
          covers the non-furrow *_disabled/*_done_today fields as
          before; the new second call refreshes furrow_next_ready_at/
          epoch with this run's own just-computed furrow data instead
          of whatever was left over from before this pass started.
      show_garden_status (//gh status) and duecheck were left calling
      sync_module_status_flags() at their existing single call sites -
      both already run/rely on fresh furrow data by the time they get
      there (duecheck via the ordering fix above; status is read-only
      and doesn't reconcile furrows live at all, consistent with its
      existing "whatever was last recorded" philosophy).
  v1.20.0 (2026-09-20) - Commented out pond = false in every
      character's character_module_overrides entry, per Mark: "lets
      comment out the skipping of POND for all the characters. I want
      to process POND now." Every character's block is now an empty
      {} (with the original line kept, just commented, so it's a
      one-line uncomment per character to turn Pond back off later)
      - is_module_enabled('pond') therefore now returns true for
      every character again, and //gh full/force will run Pond
      Dredger normally on all 16 mules.
  v1.21.0 (2026-09-20) - Release-stability review pass, per Mark:
      "please review the entire ML and GH code for continuous use..
      look for memory leaks, cpu utilization issues, nil values,
      possible errors, or issues in the login... This will be a
      release version so I am going for max stability and polish."
      No classic memory leak was found (no unbounded table growth, no
      texts/prim objects, no register_event calls inside a repeated
      function - all confirmed clean), but five real issues were
      found and fixed:
      (1) config.* fields //gh furrowconfig can change at runtime
      (debug_mode, sell_junk_enabled, default_seed,
      default_fertilizer, use_fertilizer, fertilize_wait_time) were
      only ever reset on addon RELOAD, never on a character SWITCH -
      since config is one addon-wide table shared by every character
      MuleLogger logs into in a rotation, a hand-run //gh
      furrowconfig change on one mule (e.g. toggling selljunk off to
      debug something) would silently carry over to every other mule
      for the rest of the client session. Added config_defaults (a
      snapshot taken once at file load) and restore it in the
      'login' event handler, the same place state.* already gets
      reset per-login.
      (2) main_loop (//gh furrowloop) recursed via a bare statement
      call instead of `return main_loop(...)` - not a real Lua tail
      call, so every cycle left one more frame on the stack, never
      freed until the whole automation stops. Left running
      unattended long enough, this growth is unbounded and could
      eventually hit Lua's call-depth limit. Fixed to a proper tail
      call.
      (3) run_full_garden_pass's very last step (the final sell/
      return-to-moogle checkpoint) checked state.running before
      calling sell_junk_to_moogle()/return_to_green_thumb_moogle(),
      but not after - unlike every other stage in the same function.
      A //gh stop landing mid-sell could fall through to
      record_full_pass_complete() anyway, falsely marking the pass
      as cleanly completed. Added the missing re-check.
      (4) get_active_furrows()'s fallback (used when nothing has
      called reconcile_furrow_data yet this run) used to blindly
      assume all 3 furrow slots existed. show_garden_status (//gh
      status) is the one caller that never reconciles first (it's
      deliberately read-only/instant by design), so running //gh
      status as the very first command of a session on a character
      with only 1-2 furrows could report a phantom furrow as falsely
      'READY' in furrow_next_ready_at - a field built for //ml
      status to consume. Fallback now filters by saved_status's own
      last-known furrow_N_state instead, staying read-only while
      being honest about what's actually known.
      (5) Minor: GREEN_THUMB_MOOGLE's id was a second hardcoded
      literal (17924125) duplicating config.sell_junk_moogle_id -
      now reads from config.sell_junk_moogle_id instead, so the two
      can't silently drift apart if this moogle's id is ever updated.
      Also hardened the 'incoming text' capture filter used during
      menu response waits: it used to only skip this addon's OWN
      'GardenHelper:' lines; now also skips MuleLogger's ('MuleLogger:')
      and roe's ('ROE Notice:') own log lines, since those run in the
      same client process and could otherwise be mistaken for "the
      furrow/module's real response arrived." Doesn't (and can't
      fully) guard against an unpredictable server-wide system
      announcement landing mid-capture - noted in the code as a
      residual, unfixable-in-general risk.
  v1.22.0 (2026-09-21) - Two bugs found from Mark's live testing:
      (1) //gh status ("attempt to call global 'sync_module_status_
      flags' (a nil value)") - show_garden_status calls
      sync_module_status_flags(), but that function is `local
      function`-declared much further down the file (after
      is_module_enabled/node_done_today, which it needs); Lua only
      makes a `local function` name visible to code AFTER its own
      declaration point, so show_garden_status (defined earlier) was
      instead calling a nil GLOBAL of the same name. Fixed with a
      forward declaration (`local sync_module_status_flags` added
      right before show_garden_status, with the real definition now
      assigning into it via `sync_module_status_flags = function()`
      instead of redeclaring it `local` down there) rather than
      moving the whole function.
      (2) Fertilized/baited vein/pond/grove/net nodes were being
      marked done for the day without actually being harvested -
      Mark's own //ml status screenshot showed Fishvfi's Pond as "D"
      (done) when it hadn't actually run. Root cause, confirmed live
      on a fertilized Pond (a "super baitball"): fertilizer/bait
      prints one EXTRA informational line ("A super baitball is
      being used as bait.") before the normal Yes/No harvest confirm,
      which press_enter_cycle's fixed 3-press wait list for pond/net
      doesn't account for - the cycle ran out one Enter short,
      leaving the confirm prompt open on screen, while
      record_node_harvest still recorded the day as done regardless.
      Fixed generically in press_enter_cycle itself (shared by every
      vein/pond/grove/flotsam/net call) rather than per-module:
      after each scheduled press, if that press's own new captured
      lines match config.fertilizer_extra_press_phrases (currently
      just the confirmed bait wording), one extra Enter is pressed
      immediately to absorb the shift before continuing to the next
      scheduled press. Mark suspects Vein/Grove show a similar extra
      line when fertilized (untested, different wording expected,
      since they're not fishing-themed) - since every node already
      shares this same press_enter_cycle, the fix already covers them
      too; only the phrase itself still needs confirming and adding
      to the list once observed.
  v1.23.0 (2026-09-21) - sell_junk_to_moogle's quest-text/cutscene
      clearing (the "not the standard greeting" branch) no longer
      always runs its alternate Enter/Escape dance after the plain
      Escape x3 - per Mark's own observation watching it live: the
      script would select+ESC the moogle twice before a 3rd, genuinely
      fresh attempt finally opened the real conversation, even on
      runs where the very first Escape had already closed the stray
      conversation and dropped the target. Now checks
      windower.ffxi.get_mob_by_target('t') right after the plain
      Escapes - if there's no target left, the alternate Enter/Escape
      loop (meant for quest text that needs an Enter to advance a
      page before Escape can back out of it) is skipped entirely, and
      the outer attempt loop moves straight on to a fresh
      find_moogle()/walk_to_entity()/interact instead of needlessly
      reopening and reclosing a conversation that's already gone.
  v1.24.0 (2026-09-21) - Added a "reset" sub-command for every
      garden module, per Mark: "is there a command like '//gh pond
      reset' to reset the 'done today' status for that one
      character?"
      - //gh vein reset / pond reset / grove reset / flotsam reset /
        net reset / crystals reset - each clears that module's own
        *_last_harvested_date/_at for THIS character only (leaving
        *_last_rank alone), then immediately re-syncs the
        *_done_today snapshot via sync_module_status_flags() so //ml
        status reflects it right away instead of only after this
        character's next real duecheck/full/status. New shared
        reset_module_status(prefix) helper.
      - //gh furrow reset [1|2|3|all] - furrows have no once-per-day
        "done today" concept (a furrow can be empty/growing/ready at
        any moment), so per Mark's own instruction this does NOT
        mirror the other modules' reset - instead it clears that
        furrow's (or all furrows') recorded state/checked timestamp
        back to the same "never checked" shape infer_furrow_state()
        already falls back to live-checking from, so the next
        furrowloop/furrowfull/furrow/plant/harvest/fertilize/full/
        force command has to check live whether it's ready to
        harvest, ready to plant, or still growing, instead of
        trusting stale data. Also blanks furrow_next_ready_at/epoch
        (the whole-character ETA //ml status reads), since it's
        stale the moment any furrow resets - recomputed fresh next
        sync. New reset_furrow_status(furrow_arg) helper, checked
        BEFORE the existing furrow->furrowfull alias passthrough so
        "reset" is never mistaken for a seed name.
      - Both new reset functions needed sync_module_status_flags(),
        which is defined much further down in the file - relocated
        its existing forward declaration (added earlier this session
        for //gh status's own nil-global bug) from right before
        show_garden_status to right after saved_status itself, so
        every earlier-defined caller can see it, not just that one.
      - Documented all of the above in //gh help.
  v1.25.0 (2026-09-21) - Release-stability review pass (2nd), per
      Mark: reviewed the whole file for memory leaks/nil values/crash
      issues/logic issues after the reset-command work above. Two
      independent sub-agent reviews of the whole file turned up no
      memory leaks, no unguarded nil crashes, and confirmed the
      sync_module_status_flags forward declaration, press_enter_cycle's
      fertilizer handling, and sell_junk_to_moogle's target check are
      all correct as shipped. Found and fixed four real issues:
      - reset_furrow_status(furrow_arg) accepted any numeric argument
        (0, 4, 99, 2.5) as if it were a valid furrow number - the
        for-loop that actually clears furrow_N_* fields never matched
        anything, but the function still logged success and blanked
        the whole-character furrow_next_ready_at/epoch anyway. Now
        rejects anything outside 1-3 (or non-integer) with an error.
      - harvest_pond/flotsam/net ignored walk_to_entity()'s return
        value - if the walk failed (couldn't close the distance, lost
        the target, etc.), the function pressed Enter into nothing and
        still recorded that module as done for the day. Now bails out
        (without recording) whenever the walk itself fails.
      - harvest_vein/harvest_grove unconditionally called
        record_node_harvest() at the end of their retry loop even if
        neither a harvest success nor the module's own stop/done
        phrase was ever actually seen (e.g. walking/targeting failed
        on every attempt) - same false "done today" risk, just via a
        different path (a retry loop instead of a single press). Now
        only records when stopped or any_success is true; otherwise
        logs an error and leaves the day's status alone so the next
        run retries it live.
      - The new //gh <module> reset / //gh furrow reset commands could
        run concurrently with an in-progress furrowloop/full/force
        pass, letting two coroutines read-modify-write saved_status at
        the same time. Now gated behind the same state.running check
        every other command already uses ("Another operation is
        running. Use //gh stop first, then reset.").
  v1.26.0 (2026-09-21) - Added a FindAll database refresh to the
      very end of //gh full/force, per Mark: "can you confirm that the
      command '//findall' will refresh the offline inventory database
      stored in the FindAll addon for that character? If so, lets add
      this step to the end of gh full, after the final sell, before
      the logout." Confirmed against FindAll's own installed source
      (findAll.lua/README.md) before wiring anything up: bare
      `//findall` (no search terms) calls straight into its update()
      function, which is exactly its documented "Update" command -
      force-refreshes that character's stored item list immediately,
      synchronously, the same as what normally happens on an item
      packet or logout. New refresh_findall_inventory() helper sends
      it and waits config.findall_wait_seconds (3s default) - update()
      itself needs no wait at all, but this gives the final sell's own
      inventory-changing packets a moment to land first, matching
      Mark's own "may need a few seconds" caution. Called from
      run_full_garden_pass right after the final sell/return-to-moogle
      step's own state.running re-check, before record_full_pass_
      complete() and the "Full Mog Garden pass complete." announcement
      MuleLogger waits for - so this always runs before that
      character gets logged out, never after. Gated by new
      config.refresh_findall_after_pass (default on); a harmless no-op
      (just an unrecognized slash command) if FindAll isn't loaded.
  v1.27.0 (2026-09-21) - sell_junk_to_moogle's stuck-screen clearing
      now handles a genuine cutscene, per Mark: "sometimes when
      talking to the moogle for selling, it will be a cutscene. If
      thats the case then ESC is pressed, it won't loose target. If
      that situation happens, please ENTER ESC, ENTER ESC, over and
      over until the target goes away. That should complete the
      cutscene. If for some reason it doesn't go away after 5
      minutes, then please stop script and log that update to the
      user and for the logs."
      - The existing "still targeting something after plain Escape x3"
        branch used to alternate Enter/Escape a small FIXED number of
        times (config.sell_junk_clear_key_attempts, 3) before giving
        up on this attempt. A real cutscene can easily outlast that.
        Replaced with a while loop that keeps alternating Enter/Escape
        and re-checks the target after every pair, for as long as it
        takes - removed sell_junk_clear_key_attempts, replaced by new
        config.sell_junk_cutscene_timeout_seconds (300s / 5 minutes),
        a time bound rather than an attempt count.
      - Once the target actually clears, that's treated as the
        cutscene finishing - logs how long it took and falls through
        to the next moogle attempt as before.
      - If the target is STILL there once the full 5 minutes have
        passed, something is genuinely stuck (not just a slow
        cutscene) - logs a clear [ERROR] (visible in-game and in
        Windower's own chat log file - "for the logs" per Mark) and
        sets state.running = false before returning, stopping ALL
        GardenHelper operations rather than just skipping this sell
        and continuing on to the next module. Every caller
        (run_full_garden_pass's maybe_sell checkpoints and the final
        sell, plus the standalone //gh sell command) already re-checks
        state.running right after calling sell_junk_to_moogle, so this
        takes effect immediately either way.
  v1.28.0 (2026-09-21) - Furrow commands finally have a real 'force',
      per Mark: "I started a single pass furrow force, and it didn't
      harvest and plant... I need it to try to harvest and plan, or
      harvest from vein, or harvest from grove when 'force' is used" -
      followed by "but then still be smart enough based on chat
      messaging to tell if unable to harvest due to being done
      already that day, or currently growing, or needing just a
      planting." Root cause confirmed with Mark live: "//gh furrowfull
      force" was reading 'force' as a SEED NAME (furrow commands only
      ever took [seed] [fertilizer] positionally), and even ignoring
      that, furrow commands had no force concept at all -
      handle_furrow_for_start always trusted recorded/inferred status
      first with no way to skip that. Vein/pond/grove/etc were already
      fine - their own [force] only ever skips the "already done
      today" date check, then reads the real on-screen text either
      way, so no changes needed there.
      - New extract_force_arg(args, start_index) helper scans a
        furrow command's arguments for a literal 'force' anywhere
        among them (not just a fixed slot, since furrow commands also
        take seed/fertilizer positionally) and pulls it out, leaving
        the rest in order - so `force`, `gysahl force`, and `gysahl
        wild_onion force` all work, with or without force.
      - furrowloop/furrowfull now accept it and thread it through
        main_loop/run_single_furrow_pass down to
        handle_furrow_for_start, which - when forced - skips trusting
        recorded/inferred status entirely and always falls through to
        the existing live detect-and-act branch (unchanged): reads
        the actual on-screen text and correctly tells ready apart from
        empty apart from still-growing (fertilized or not) before
        doing anything. This is what makes force "smart" rather than
        blindly mashing a harvest attempt - a forced check on a
        furrow that's genuinely still growing just reports that and
        moves on, exactly like it would from cached data.
      - furrow_pass_needed() (run_full_garden_pass's own "is the whole
        furrow step even worth doing" pre-check) now takes force too -
        previously even //gh force could skip the ENTIRE furrow step
        if every furrow's cached data said still-growing, silently
        ignoring force exactly like handle_furrow_for_start used to.
        //gh full/force's own furrow step now passes its force flag
        through both furrow_pass_needed and run_single_furrow_pass.
      - The furrow alias ("//gh furrow ...") used to forward only 2
        positional arguments to furrowfull, which would have silently
        dropped 'force' typed as a 3rd argument (e.g. "//gh furrow
        gysahl wild_onion force") - now forwards every argument via
        Lua 5.1's unpack().
      - Documented force on furrowloop/furrowfull/furrow in //gh help.
  v1.29.0 (2026-09-21) - harvest_flotsam now handles the "can't
      receive" case instead of just flagging it, per Mark: "okay, we
      finaly got one of those 'you cannot obtain the xxxx' messages
      from the flotsam. Please review the chat log. I believe what is
      necessary after that message is sendkey UP, ENTER." Confirmed
      against Mark's own real chat log/screenshot from a live "You
      cannot obtain the scroll of Absorb-STR." case: the game follows
      that message with its own "Dispose of the <item>? / Posthaste. /
      Wait. I need that still." prompt, which was being left OPEN on
      screen - config.flotsam_cant_receive_phrases detection was
      already firing correctly (confirmed by the existing [ERROR] log
      line in Mark's own screenshot), the gap was purely in what
      happened next. Now sends Up (moves off the default top option
      onto "Wait. I need that still.") then Enter (confirms it,
      closing the prompt) - keeps whatever's already held rather than
      disposing it, and stops leaving a menu open for the NEXT module
      to walk into blind (Mark's log showed Coastal Fishing Net
      immediately hitting a "Lock On may not have engaged" recovery
      right after this, which an open menu could easily explain, even
      though that particular case did recover on its own). Flotsam is
      still recorded done for the day either way, same as before -
      only the leftover prompt-handling changed.
  v1.30.0 (2026-09-21) - Corrected which option v1.29.0's Up, Enter
      actually selects on the flotsam "can't receive" prompt, per
      Mark: "we are sendkey UP, ENTER so we are selecting Posthaste,
      so that way we discard of the item in the flotsam, and continue
      on with the rest of the process." v1.29.0 had the actual
      keystrokes right (Up then Enter, unchanged here) but described
      them backwards throughout - comments and the log line all said
      this kept the duplicate item by landing on "Wait. I need that
      still.", when it actually lands on "Posthaste." and discards
      the duplicate that couldn't be received, which is what actually
      lets the pass continue instead of getting stuck on the prompt.
      Comments and the log message in harvest_flotsam corrected to
      match; no behavior change.
  v1.31.0 (2026-09-21) - Fixed sell_junk_to_moogle closing the Buy/Sell
      menu and reloading Treasury before SellNPC actually finished
      selling, on larger sells. Per Mark's report on Smithvf: the sell
      process waits for SellNPC's own "SellNPC: Selling N items."
      chat line as its completion signal - confirmed correct - but
      two problems combined to break that on this character's logs:
      1. SellNPC's sell_all_items sleeps 1 full second per matching
         inventory slot (up to 80 slots) while selling, so a 14-17
         item sell can take well over 10 seconds - but
         config.sell_junk_after_open_wait_seconds was still 10,
         so the wait timed out and moved on to closing the menu/
         reloading Treasury before the completion line printed.
         Raised to 100s (80 slots * 1s worst case + margin) -
         wait_for_phrase already moves on the instant the phrase is
         seen, so this costs nothing on a normal sell.
      2. Stock SellNPC never printed that line at all when 0 items
         sold (Mark confirmed this directly), so an empty sell could
         only ever hit the full timeout blind, with no real
         completion signal. Patched the separate SellNPC.lua itself
         (sell_all_items) so it always prints the line - including
         "SellNPC: Selling 0 items." - whenever a sell was actually
         queued (via 'sellnpc junk'), while staying silent when
         nothing was queued at all (e.g. some unrelated shop), so
         this doesn't spam chat outside of an actual sell attempt.
      Selling itself was never actually broken by this (SellNPC's
      packet-injection sell loop isn't menu-gated, so it finished
      regardless, per Mark) - only Treasury's reload could start
      while a sell was still technically in flight, which this
      fixes. Comment above config.sell_junk_after_open_wait_seconds
      and config.sell_junk_complete_phrase updated to match, and to
      flag that the SellNPC.lua patch needs reapplying if that addon
      is ever reinstalled/updated from upstream.
  v1.32.0 (2026-09-21) - Two fixes from Mark's Smithvf logs/screenshot:
      1. Vein (and, per the same mechanism, Grove) can show the same
         "fertilizer/bait" extra chat line pond/net already handled -
         just with vein's own wording ("This vein has a vial of stone
         serum poured on it.") instead of pond/net's "is being used as
         bait." Confirmed live by Mark on a fertilized vein: the extra
         line was never absorbed, so the press cycle fell one Enter
         behind and the harvest stalled, repeating the same "This
         mineral vein is rank 3"/"poured on it" text every cycle
         without ever progressing. config.fertilizer_extra_press_phrases
         now also matches 'poured on it' - press_enter_cycle already
         had the extra-Enter-absorption mechanism built for this
         (added 2026-09-21 for Pond, with a comment flagging vein/grove
         as suspected-but-unconfirmed), so no new logic was needed,
         just the phrase.
      2. `//gh stop` wasn't actually stopping right away - Mark's log
         showed it print "Stopping all operations..."/"Stopped
         successfully" while a Mineral Vein harvest kept walking
         toward the vein for another 25+ seconds regardless, ending in
         its own [ERROR] giving-up-on-walking-over message. Root
         cause: several low-level building blocks shared by every
         module (walk_to_entity, find_entity/find_furrow/find_moogle/
         retarget_entity's targeting-confirm loops, wait_for_response/
         wait_for_phrase's chat-wait loops, press_enter_cycle's press
         loop, run_key_sequence's step loop and its two inner text-wait
         loops) were never checking state.running while they ran -
         only the higher-level per-module/per-attempt loops around
         them were (harvest_vein's own attempt loop, for instance,
         already checked state.running at the top of every attempt -
         but once it called into walk_to_entity for that attempt,
         nothing inside walk_to_entity itself watched for a stop until
         its own up-to-25s timeout ran out). All of the above now
         check state.running on every poll (every ~0.2s) and break out
         immediately, same pattern already used by
         wait_with_reminders/the sell-junk cutscene loop/the furrow
         retry loop elsewhere in this file. Also affects wait_for_phrase
         specifically: since v1.31.0 raised its bound to 100s for the
         sell-completion wait, a stop issued mid-sell would otherwise
         have been stuck waiting up to 100s instead of the old 10s -
         this fix covers that case too. README's `//gh stop`/Safety
         Notes sections updated to describe the corrected behavior.
  v1.33.0 (2026-09-21) - Two more fertilized-node extra-line phrases
      added to config.fertilizer_extra_press_phrases, per Mark's live
      test screenshots:
        Grove: "This grove is fertilized with grove worm." - added
          'is fertilized with' (kept generic, not tied to "grove
          worm" specifically).
        Net: showed two extra lines around its normal rank line -
          "You baited the net with ponze of sardine chum." (before
          the rank line - new, added 'You baited the net with') and
          "A ponze of sardine chum is being used as bait." (after it
          - already covered by the existing bait phrase from
          v1.29.0-era pond work). See the config comment above for
          the caveat: if both Net lines land in the same press's
          capture window one absorb covers both, but if Mark's next
          test shows Net still falling short, they're landing in
          different presses and this needs a follow-up fix beyond
          just the phrase list.
  v1.34.0 (2026-09-21) - Reverted v1.33.0's 'You baited the net with'
      addition, per Mark: that fertilized-Net test was him manually
      applying the fertilizer himself to observe the harvest script,
      not something the script's own normal flow actually produces -
      so there was never a real extra-line case to cover for Net
      there. Net's OTHER line from that same test ("...is being used
      as bait.") stays covered - it's real, from the 2026-09-19 Pond
      work, unrelated to how that particular test was set up.
      config.fertilizer_extra_press_phrases is back to just
      'is being used as bait'/'poured on it'/'is fertilized with'.
      Grove's 'is fertilized with' (also from v1.33.0) is unaffected -
      Mark confirmed that one's from the script's own normal flow.
  v1.35.0 (2026-09-21) - Added a 'target clear' at the completion of
      every object-harvesting pass (Furrow, Vein, Pond, Grove,
      Flotsam, Net), per Mark's live screenshot: after a "//gh grove"
      run, the just-harvested Arboreal Grove was still shown as the
      active target right as GardenHelper's own "Arboreal Grove rank
      2 pass complete." line printed. None of harvest_vein/
      harvest_pond/harvest_grove/harvest_flotsam/harvest_net cleared
      the target on their way out (only sell_junk_to_moogle already
      did, at its own close-out) - each now sends 'target clear'
      right after its own "harvest complete."/"pass complete." log
      line, regardless of success or failure, so nothing is left
      targeted once that module's pass is done. handle_furrow_for_start
      (furrow/furrowfull/furrowloop's shared per-furrow step) gets the
      same treatment at both of its own completion points (the
      trust-recorded-data branch and the live-detect-and-act branch) -
      furrows never explicitly cleared their target after harvesting
      either, only after some of the live-detect exit sequences via
      exit_menu_hygiene(), not after an actual harvest.
  v1.36.0 (2026-09-21) - //gh furrow no longer misreads another
      command's name as a seed. Per Mark: "//gh furrow inspect" logged
      "Starting single pass with inspect (fertilizer is OFF)" and
      tried to plant a seed literally named "inspect", instead of
      running an inspection. //gh furrow's first argument is now
      checked against every other real furrow command's own name
      (loop/full/duecheck/plant/fertilize/harvest/inspect/status/
      config, plus 'reset' which already had this treatment) before
      ever falling through to the seed/fertilizer/force forwarding
      that used to run unconditionally - a match forwards straight to
      that real command instead, with every argument after the
      reserved word passed along unchanged (e.g. "//gh furrow inspect
      2 empty" -> "//gh furrowinspect 2 empty"). 'force' needed no new
      entry - extract_force_arg already recognizes it in any position,
      so "//gh furrow force" was already working correctly. README's
      furrow section updated to document the reserved words.
  v1.37.0 (2026-09-21) - Every furrow command now closes any leftover
      character menu before it starts driving one, not just the
      target. Per Mark: ran "//gh furrow inspect" and the character's
      own self-menu (Magic) was still open from before the command
      ran - SetTarget worked fine, but the first Enter this sent
      landed inside that stale Magic menu instead of the furrow's,
      since only 'target clear' ran beforehand, which clears
      targeting but does nothing to an already-open menu. Every
      vein/pond/grove/flotsam/net/crystals harvest function has
      called clear_cursor_state() (2x Escape) at its own start since
      v1.9.0 for exactly this reason - the furrow commands' own
      "clear any leftover target/cursor state" comments already
      CLAIMED to do this too, but never actually called it, only
      'target clear'. Added clear_cursor_state() to furrowloop,
      furrowfull, furrowplant, furrowharvest, and furrowinspect
      (furrowfertilize had neither target nor cursor clearing at all -
      added both). //gh furrow itself needed no separate fix since it
      only ever forwards into one of these.
  v1.38.0 (2026-09-21) - Fixed print_captured_lines' duplicate-line
      filter (see strip_timestamp_prefix's own comment) actually
      missing duplicates, per Mark's live furrowinspect screenshot: a
      fertilized furrow's two info lines each printed twice back to
      back ("This furrow is rank 4..." then "[11:14:10] This furrow
      is rank 4..." right after it, same for the "Your agrarian
      experience..." line). The filter strips a leading
      "[HH:MM:SS] " timestamp so the two copies compare equal, but
      only stripped the bracket itself - a message with its own
      natural leading whitespace (indented sub-lines, same
      convention as e.g. vein's "  It seems possible to obtain
      something from it N more times.") ended up mismatched anyway,
      since the bracket regex's trailing %s* ate that copy's leading
      whitespace while the other copy (never matching the bracket
      pattern at all) kept its own untouched - off by a space or two,
      comparing as different, so the "duplicate" print stayed.
      strip_timestamp_prefix now trims all leading/trailing
      whitespace after stripping the bracket, not just the bracket,
      so both copies normalize to the exact same string regardless of
      incidental indentation. This is the one shared function behind
      every "Captured text:" dump in the file, so the fix applies
      everywhere that's used, not just furrowinspect.

  v1.39.0 (2026-09-21) - Added a stuck-recovery waypoint detour for
      the walk to the Green Thumb Moogle, per Mark: watched a
      character almost get stuck going from Net to the sell moogle.
      walk_to_entity already has its own in-place recovery (re-tap
      Lock On and re-target if the distance never starts closing),
      but that only helps when Lock On itself didn't engage - it
      can't do anything if the direct path is actually blocked by
      terrain, since it just keeps re-locking onto the same distant
      moogle. New walk_to_moogle_with_waypoint_fallback() tries the
      normal direct walk first as always; only if that still fails
      does it fall back to finding/walking to a new waypoint NPC,
      'Mandragora Assistant' (config.moogle_waypoint_id,
      MOOGLE_WAYPOINT - Mark's own value, ~3.4 yalms from the stuck
      position he observed, approached to a tight
      config.moogle_waypoint_approach_distance = 2.5 yalms since it's
      only a stepping stone), then re-finding and re-walking to the
      moogle itself from there. Both of the moogle-walk call sites
      (sell_junk_to_moogle and return_to_green_thumb_moogle) now go
      through this instead of calling walk_to_entity directly.
      Mandragora Assistant's id moved out of EXTRA_NPCS (where it was
      just documented, unused) into its own MOOGLE_WAYPOINT constant
      now that it's actively targeted. Untested against a real stuck
      case (Mark only saw a near-miss, not a full stuck) - flag if it
      doesn't actually clear one when it happens for real.

  v1.40.0 (2026-09-21) - Movement now double-checks it actually has
      the expected target before walking, and vein/grove no longer
      commit to a rank just because settarget/name confirmed it.
      Mark's report: a grove pass logged "Walking to Arboreal Grove
      #3", which find_entity HAD settarget/name-confirmed (id AND
      name both matched) - yet the character could never actually
      close the distance or interact with it ("Target out of range"
      repeatedly), and Mark's own live check of his garden found only
      rank #1 actually present. So a settarget/name match, done once
      and trusted from then on, isn't proof a target is really
      reachable. Two changes:
      (1) current_target_is/retarget_entity/walk_to_entity all now
      take an optional expected_name and check it alongside the id
      (previously id-only) - and walk_to_entity now runs this
      confirm-fresh check right at its own start, before even reading
      a distance, not just right before Lock On as before. Mark's own
      framing: "all movement should be preceded by a double check
      that we have the target we expect to have, not just any cursor
      target." This applies automatically to every module (furrow,
      vein, pond, grove, flotsam, net, the moogle) since they all
      funnel through walk_to_entity - only grove's two call sites
      needed an explicit 4th argument (variant.name), since grove's
      own label text has ' (action)' appended and isn't the real
      entity name on its own; everywhere else the existing label
      already was the real name, so the default (expected_name =
      label) covers it for free.
      (2) find_highest_vein/find_highest_grove now also try walking
      to a rank (via walk_to_entity, with the same double-check) as
      part of deciding it's usable, not just settarget/name-matching
      it - a rank that confirms by name but can't actually be walked
      to now falls through to the next rank down instead of being
      returned and getting the caller stuck (this is what actually
      fixes tonight's failure: grove now tries #3, fails to reach it,
      and drops to #2 then #1 instead of stalling on #3). This is the
      same detour-on-failure idea as v1.39.0's moogle waypoint fix,
      just "detour to a lower rank" instead of "detour through a
      waypoint", since a grove/vein rank has no useful waypoint to
      route through the way the moogle walk did.
      Left deliberately unexplained: WHY settarget+name confirms a
      rank that turns out to be unreachable in the first place (a
      real but currently-blocked/out-of-unlock-range object, vs. some
      other client quirk) - this fix is robust either way since it
      just detects "can't actually reach it" and routes around it,
      but flag it if a rank keeps getting skipped that Mark expects
      to be genuinely available.

  v1.41.0 (2026-09-21) - New //gh debug on / //gh debug off command,
      per Mark: "I want to be able to turn on debug mode and it stays
      on, and I then want to turn it off some other time and it stays
      off. I want the debug mode to be global though, such as //gh
      debug on, or //gh debug off." Previously debug mode was only
      reachable via //gh furrowconfig debug (a toggle, not an explicit
      on/off) and was never actually persisted anywhere - it lived in
      the in-memory config table only, so it silently reset to OFF on
      every single addon reload/login, which is exactly what Mark
      was running into wanting it to "stay on."
      Two parts: (1) //gh debug on/off (bare //gh debug reports the
      current state). (2) A new GLOBAL (not per-character) settings
      file - winconfig.load(global_defaults, {}), an empty keys table
      instead of the default per-character keying saved_status above
      already uses - holds debug_mode now, saved via the new
      set_debug_mode() helper every time it changes, from either //gh
      debug on/off or the older //gh furrowconfig debug toggle (left
      in place, now calls the same function so both stay in sync).
      This should mean it stays on/off across reloads AND across
      every character this addon runs on, not just the one it was set
      on - but the "one shared file instead of per-character" part of
      Windower's config library is untested live as of this change
      (see global_status's own comment above config.debug_mode's
      assignment) - confirm it actually carries over to a different
      mule's login, not just a reload on the same character, and flag
      it if not.

  v1.41.1 (2026-09-21) - Fixed a live bug v1.41.0 shipped with: Mark
      reloaded on GenPopVF and got a flood of chat warnings right at
      load - "GardenHelper Warning: Mismatched setting types for key
      'X': table string" for basically every key in saved_status
      (furrow_1_checked_at, vein_last_harvested_at, last_seed_name,
      etc. - dozens of them), not just the new debug_mode key. Root
      cause: v1.41.0's global debug persistence called
      winconfig.load(global_defaults, {}) - an empty second argument,
      guessed to mean "one shared settings file instead of one per
      character" per Windower config library convention, but never
      actually confirmed against real documentation. Whatever that
      argument actually does, it is not that, and calling it corrupts
      type-checking for the OTHER, completely unrelated
      winconfig.load(status_defaults) call a few lines above it -
      hence every saved_status key getting flagged, not just the new
      one. Reverted that approach entirely (see the comment now in
      its place, left there so this mistake doesn't get retried) and
      replaced it with Windower's plain 'files' library instead -
      files.new('data/global_debug.txt'), holding just the literal
      text 'true' or 'false', read/written directly with no defaults
      table, no type merging, and nothing shared with saved_status's
      config system for it to collide with. //gh debug on/off and the
      older //gh furrowconfig debug toggle both still work exactly as
      before from the caller's side - only the storage underneath
      changed. Confirmed via luac5.1 -p; the "does it actually stay
      set across a different character's login" question from
      v1.41.0's own changelog entry still stands and needs a live
      check, but this file-based approach is a much simpler mechanism
      to reason about than guessing at config library internals
      again if that turns out not to work either.

  v1.41.2 (2026-09-21) - Fixed debug mode still not persisting across
      a character switch after v1.41.1's fix (Mark: turned it ON,
      switched to SeedsVF, came up OFF). Checked the file directly on
      disk - it genuinely existed with the right content ('true'), so
      v1.41.1's WRITE side (files.new():write()) was working fine;
      something about reading it back via that same library
      (files.new():read()) was not behaving the way it was assumed
      to, and there was no other confirmed use of that library's
      :read() anywhere in this addon or MuleLogger to check the
      assumption against - files.new():write()/:exists() do have
      precedent (findAll.lua), :read() did not.
      Replaced with plain io.open/io.read('*a')/io.close, using an
      ABSOLUTE path built from windower.addon_path instead of a
      relative one - this is the exact pattern MuleLogger's own
      read_flat_settings_xml already uses successfully to read
      GardenHelper's data/settings.xml from a different addon
      folder, and its settings writer uses the matching io.open(w).
      Much higher-confidence reference than a second guess at
      Windower's files library.
      Also corrected a longstanding wrong comment at the top of the
      file: winconfig (Windower's config library) was documented as
      persisting "data/<CharacterName>.xml automatically, keyed by
      whichever character is currently logged in" - false. Checked
      data/settings.xml directly: every field saved_status uses
      (furrow states, vein/pond/grove/flotsam/net done-today flags,
      last-harvested timestamps, etc.) lives under one single
      <global> section, identical for every character this addon
      runs on, because winconfig.load(status_defaults) is called with
      no keys argument anywhere in this file - that's what actually
      caused v1.41.0's original bug (a second winconfig.load call
      colliding with that same shared file/section), not the guessed
      "empty keys table" explanation in that changelog entry.
      NOT fixed by this version, flagged for Mark instead: if
      saved_status really is one shared dataset, every mule's
      done-today/last-harvested tracking may have been comingled all
      along, despite //gh vein reset etc. being documented as "for
      THIS character." This needs its own decision (probably: add
      real per-character keying to saved_status) rather than a rushed
      fix bundled into a debug-mode changelog entry.

  v1.42.0 (2026-09-21) - Fixed sell_junk_to_moogle stalling for the
      full config.sell_junk_after_open_wait_seconds (100s) safety
      bound after a FAST/small sell. Mark watched //ml loop pause a
      long time right after Pond on Fishvf; the log showed exactly
      why: SellNPC sold its one queued item and printed "SellNPC:
      Selling 1 items." a full second BEFORE GardenHelper's own "In
      the Buy/Sell menu..." line even printed - meaning the
      completion message fired while run_key_sequence (pressing
      Enter/Down/Enter/Enter to open the Buy/Sell menu) was still
      running, not after. wait_for_phrase, called right after
      run_key_sequence returns, starts a brand-new EMPTY capture
      window at that point - it has no visibility into anything
      run_key_sequence itself already captured, and SellNPC only
      announces once, so a completion line that fired during the menu
      sequence was gone for good by the time wait_for_phrase started
      listening for it. Every fast/small sell was guaranteed to burn
      the entire 100s safety bound this way; a normal 10-17 item sell
      never hit it because SellNPC needs several real seconds (about
      1s/item) to finish, comfortably longer than the menu sequence's
      own 4 key presses, so wait_for_phrase was always listening in
      time for those.
      Fix: run_key_sequence's own return value (previously discarded)
      is now kept and checked for config.sell_junk_complete_phrase
      BEFORE ever calling wait_for_phrase - if SellNPC had already
      finished during the menu sequence itself, this catches it
      immediately instead of falling through to the 100s wait. Falls
      back to wait_for_phrase exactly as before when the phrase isn't
      there yet (the normal, larger-sell case). Confirmed via
      luac5.1 -p; the actual timing fix itself can only really be
      confirmed by Mark watching a small sell (1-2 items) move on
      promptly instead of stalling next time it comes up.

  v1.43.0 (2026-09-21) - Furrow messaging cleanup, all from Mark
      watching a live //gh furrow run and one screenshot showing
      "Found Garden Furrow #3" printed twice in the same pass:
      1) //gh furrow (the bare alias, forwards to furrowfull unless
         given a recognized sub-command) now announces itself first -
         "//gh furrow is running" (or "//gh furrow <subcommand> is
         running") - as its own line, BEFORE forwarding into
         furrowfull/furrowloop/etc's own "Starting single pass
         with..." line. Previously the forward was silent, so a
         //gh furrow run's very first output line was indistinguishable
         from a direct //gh furrowfull.
      2) find_furrow()'s "Found <furrow>" line now only prints for the
         FIRST successful find of a given furrow per command run - new
         state.furrows_announced (reset at the top of every furrow
         command, inside reconcile_furrow_data) tracks this. Every
         later re-find of the same furrow in the same run (routine -
         handle_furrow_for_start re-finds a furrow once to harvest it
         and again to replant it, sometimes a third time to fertilize)
         is downgraded to debug_log() instead of repeating the message.
      3) The verbose per-furrow "still growing" line //gh furrow prints
         during a normal pass is replaced with one compact line in the
         format Mark asked for: "Garden Furrow #1: <seed> growing &
         fertilized with <fertilizer, or (nothing)>, harvest at
         <date/time>". New shared helper describe_growing_furrow_value()
         builds this (minus the "Garden Furrow #N: " label, so both
         callers can prefix their own).
      4) //gh status's furrow rows use that same helper for any furrow
         currently growing (fertilized or not) - same wording as #3,
         plus a trailing ", (rank N)" - so it reads like the vein/
         pond/grove/flotsam/net rows right below it instead of the old
         bare "rank N, growing_fertilized". Every furrow row's label is
         now "Garden Furrow #N" (including #1, whose real in-game name
         has no "#1") purely so the three rows line up - previously #1
         used the shorter plain "Garden Furrow" label, throwing off the
         column alignment against #2/#3.
      Seed/fertilizer name in both #3 and #4 come from get_effective_
      seed()/get_effective_fertilizer() (or whatever was explicitly
      passed to that //gh furrow run) - there is no per-furrow record
      of what was actually planted, only of the single seed/fertilizer
      this addon always plants with, so this reflects current config,
      not text re-read off the furrow itself.
      Also, a correction owed from the v1.41.2 entry above: that entry
      claimed saved_status (winconfig.load(status_defaults)) was one
      shared dataset across every character. That was wrong - it was
      based on only reading the first part of data/settings.xml, which
      happens to start with a <global> section. A full scan of that
      file (grep -oE for every top-level tag) shows it actually has
      the <global> section PLUS a separate section per character
      (<shadowhammer>, <fishvf>, <genpopvf>, etc.), matching
      MuleLogger.lua's own read_flat_settings_xml, which already reads
      this exact structure. saved_status genuinely is per-character.
      Confirmed via luac5.1 -p; the messaging changes themselves need
      Mark to watch a live //gh furrow pass to confirm the new lines
      read the way he wants.

  v1.44.0 (2026-09-21) - Furrows now track which seed and which
      fertilizer are actually planted, plus a locked-in harvest-ready
      time, per Mark: "update the data file to include which seed,
      and which fertilizer is planted, as well as tracking then the
      harvest time is in the data. Then those can be used for the
      status." New persisted fields per furrow: furrow_N_seed,
      furrow_N_fertilizer, furrow_N_harvest_at/epoch.
      record_furrow_state (already the single choke point every
      furrow-state change already went through) now takes optional
      seed_name/fertilizer_name params - passed explicitly by every
      call site that just did the planting/fertilizing itself (the
      exact value used, not a guess), or - when a call is instead a
      live detect of a furrow this addon didn't just act on itself
      (e.g. after //gh furrow reset) - parsed straight out of the
      captured game text ("has a <seed> planted" / "is using a
      <fertilizer> as fertilizer"). harvest_at/epoch is computed and
      LOCKED IN at the moment of planting/fertilizing (checked_epoch
      + whichever wait time actually applies then), not only ever
      recomputed later - so a furrow's displayed ETA no longer
      silently drifts if config.harvest_time/fertilize_wait_time (or
      a character override) changes while it's already growing.
      'empty' clears all three fields; 'ready' locks harvest_epoch to
      right now instead of leaving a stale earlier estimate.
      describe_growing_furrow_value (used by both //gh furrow's own
      per-pass status line and //gh status, since v1.43.0) now reads
      these stored values instead of always assuming the currently-
      configured seed/fertilizer and recomputing the ETA from
      checked_epoch - falling back to the old computed approach only
      for a furrow still growing from before this existed, until its
      next plant/fertilize cycle fills the real value in.
      Small bonus fix while in this area: plant_seed/fertilize_furrow's
      own "planting/fertilizing refused, correcting recorded status"
      rejection handlers now also pass their already-captured `lines`
      into record_furrow_state (previously didn't, so a rejection-
      triggered correction never picked up rank OR now seed/
      fertilizer, unlike every other live-detect path).
      Confirmed via luac5.1 -p; the actual data being correct can
      only really be confirmed by Mark watching a live plant/
      fertilize cycle and then checking //gh status against what was
      really used.

  v1.45.0 (2026-09-21) - //gh status's furrow lines are now a
      compact single-line-per-furrow format, replacing v1.43.0's
      padded label/value table for furrows specifically (module rows
      - Vein/Pond/Grove/Flotsam/Net - keep their existing padded
      format unchanged). Per Mark: "/gh status is still not right. I
      had you add too much info, and its wrapping. How about this:
      Furrow #1: [seed], [fertilizer or none], [status], H@ [harvest
      date without year such as 9/21 & time without seconds] (rank
      #)". New describe_furrow_status_line builds that exact line
      (also handles 'ready', which the old describe_growing_furrow_
      value never did - the fertilizer field alone already tells
      fertilized apart from unfertilized at any of the three states,
      since record_furrow_state only clears furrow_N_fertilizer on
      'empty', never on 'ready'). New format_short_datetime helper
      (duplicated from MuleLogger's own, same reasoning as every
      other cross-file duplicate in this codebase - no cross-addon
      Lua calls) drops the year and seconds and any leading zeros:
      "2026-09-21 23:33:00" -> "9/21 11:33pm". Label shortened from
      "Garden Furrow #N" to "Furrow #N" too, one more small trim.
      describe_growing_furrow_value (and the "Garden Furrow #N"
      label) is untouched - still feeds //gh furrow's own per-pass
      line, which Mark did not ask to change this time.
      Confirmed via luac5.1 -p; the actual line wording/wrapping can
      only really be confirmed by Mark running //gh status again.

  v1.46.0 (2026-09-21) - Fixed a real bug behind Mark's report: "I
      just ran '//ml smart' on shadowhammer, and it tried to process
      like GH FULL over and over." run_full_garden_pass only called
      sync_module_status_flags() twice - once at the very start
      (before any module ran) and once right after furrow processing
      specifically (to refresh the furrow ETA //ml status/smart
      reads) - but never again after vein/pond/grove/crystals/
      flotsam/net actually ran. Those modules' own "done today" flags
      get set internally as each one completes, but the cross-addon
      MIRROR of that data (what MuleLogger's module_status_code
      reads out of this addon's own settings.xml, via
      read_flat_settings_xml) stayed frozen at its pre-pass values
      until something else called duecheck/full/force/status again.
      //ml smart's Tier 3 ("other daily module not done, character is
      in Mog Garden") reads that mirror directly without ever
      triggering a fresh //gh status/duecheck itself, so it kept
      seeing the SAME stale "not done" data after every pass and
      re-selecting/re-running //gh full on the same character
      forever. Added one more sync_module_status_flags() call at the
      very end of run_full_garden_pass, right after
      refresh_findall_inventory() and before record_full_pass_
      complete(), so the mirror reflects this pass's real results the
      moment "Full Mog Garden pass complete." fires - the exact
      signal MuleLogger is waiting on to move to its next decision.
      Confirmed via luac5.1 -p; the actual fix can only really be
      confirmed by Mark running //ml smart again and watching it
      move on to a different character/tier instead of looping.

  v1.47.0 (2026-09-21) - Furrow harvest-ready times now use the
      game's own real remaining-time text when it's available,
      instead of always assuming a fresh full harvest_time/
      fertilize_wait_time duration starting from whenever this
      addon happened to check. Mark, after a //gh furrowinspect
      screenshot showed "H@ 9/23 3:15pm" on a furrow the game had
      JUST told him was "about 1 hour and 45 minutes" away: "it
      appears when inspecting, the H@ time is calculating on the
      inspection time + the standard grow time. #1, The harvest time
      should be writing to data when planted, based on what was
      planted and how long that plant/seed takes to grow. #2, If the
      furrows are ever checked again, or inspected, and the time to
      be ready to harvest is given... we should make sure the data
      stored is still accurate, and update it if needed."
      New parse_remaining_seconds(lines) scans captured text for the
      "...you will be able to harvest the <seed> you planted in
      about <N> hour(s) [and <N> minute(s)] (Earth time)." line and
      returns the real remaining seconds, or nil if that line isn't
      present. record_furrow_state's growing_unfertilized/
      growing_fertilized branches now use checked_epoch + that real
      value when parse_remaining_seconds finds one, falling back to
      the old checked_epoch + get_effective_harvest_time()/
      get_effective_fertilize_wait_time() estimate only when it
      doesn't (e.g. no captured text at all). Since record_furrow_
      state is the single choke point every furrow-state change
      already goes through, this single change covers both of
      Mark's numbered points at once: an inspect/live-detect that
      captures this line (issue #2) gets an accurate correction, and
      planting/fertilizing (issue #1) gets the real duration too,
      now that plant_seed/fertilize_furrow actually return their own
      captured lines instead of discarding them - previously EVERY
      call site (plant_cycle, fertilize_cycle,
      handle_furrow_for_start's plant_and_maybe_fertilize x2, and
      the live-detect growing_unfertilized branch's own fertilize
      call) called record_furrow_state with lines=nil right after a
      successful plant/fertilize, so even a plant confirmation that
      DID include this exact line was being thrown away unread.
      parse_remaining_seconds is deliberately a pure function with
      no log()/debug_log() calls - it's used from record_furrow_
      state, which is defined earlier in this file than log()/
      debug_log() are (same ordering constraint documented on
      sync_module_status_flags' own forward declaration elsewhere in
      this file).
      Confirmed via luac5.1 -p; the actual accuracy can only really
      be confirmed by Mark watching a live plant or //gh
      furrowinspect against a furrow with a known real remaining
      time and checking the resulting H@ against it.

  v1.48.0 (2026-09-21) - Fixed the duplicate captured-text lines in
      chat for real this time (hopefully) - Mark, on yet another
      //gh furrowinspect screenshot showing the same "This furrow is
      rank 7..." and "Your agrarian experience..." lines each
      printed twice: "I am seeing duplicate lines again that need to
      be removed from chat log. It clutters it up." This is the SAME
      underlying bug as the two earlier "fixes" today
      (strip_timestamp_prefix's original version, then its first
      widening) - both assumed the only difference between the two
      copies was a "[HH:MM:SS] " prefix sitting at the very start of
      the string. strip_timestamp_prefix's bracket-strip was still
      anchored to position 1 (^%[...) - if the client's duplicate
      re-fire puts a non-printable colour/Auto-Translate control
      byte ahead of that embedded timestamp on one copy, the anchor
      never matches at all and that copy compares as a completely
      different string from its clean twin, so the dedup silently
      did nothing. Now strips ALL control bytes (%c) from the whole
      line (not just the start) AND matches the "[HH:MM:SS] "
      bracket anywhere in the line (not anchored), so either kind of
      leading noise - or both stacked together - gets normalized
      away before comparison. print_captured_lines also widened at
      the same time to catch a repeat of ANY earlier line in the
      same batch, not only the immediately preceding one, as extra
      insurance in case a duplicate ever lands non-adjacent to its
      twin - safe here since one furrow's own captured text never
      legitimately repeats the exact same sentence on purpose.
      Confirmed via luac5.1 -p; since this is the third attempt at
      the same bug, this one especially needs Mark to actually watch
      a //gh furrowinspect (or furrow pass) run before considering
      it done.

  v1.49.0 (2026-09-21) - H@ time confirmed accurate now (Mark:
      "Good news, the update //gh furrow inspect, seems to be
      calcing the time correctly now") - v1.47.0's fix worked as
      intended. Duplicate captured-text lines, however, are STILL
      showing up per Mark's latest screenshot, despite v1.48.0's
      control-byte-and-anywhere-bracket widening. Standalone-tested
      that exact widening against a plain-text reproduction of the
      visible pattern (identical sentence, one copy with a leading
      "[HH:MM:SS] "), and it DOES correctly normalize both copies to
      an identical string - so either something byte-level is going
      on that this fix still doesn't account for, or this screenshot
      was taken before gardenhelper was actually reloaded with
      v1.48.0. No further blind fix this time - added a temporary
      debug_hex_dump/print_captured_lines diagnostic instead (see
      its own comment) that dumps the first 40 bytes of every
      captured line as hex whenever config.debug_mode is on, so the
      next occurrence (if there is one, on a client confirmed
      running v1.49.0+) gives an actual byte-level answer instead of
      another guess.
      Confirmed via luac5.1 -p.

  v1.50.0 (2026-09-21) - Actually root-caused the duplicate-line bug
      this time. Mark: "The command I used is '//gh furrow inspect',
      and it still has the duplicate lines. Please check the log
      file." Read Shadowhammer's actual Windower log file directly
      (data/logs/Shadowhammer_2026.09.21.log) instead of going by a
      screenshot, and found v1.49.0's own hex-dump diagnostic had
      already landed and was working - it showed the real bytes: the
      duplicate copy's raw text was \30\252[HH:MM:SS]\30\1
      \30\1<the real line>, while the clean copy was just
      <the real line> with no prefix at all. Byte 0xFC (252, decimal
      \252) is a Windower colour-code VALUE byte (part of a \30 + 1
      byte colour sequence, wrapping the embedded timestamp), not a
      standard control character - v1.48.0's %c strip only catches
      true C-locale control bytes (0x00-0x1F, 0x7F), so 0xFC was
      left sitting directly in front of the text on the duplicate
      copy, and the two "normalized" strings differed by that one
      leading byte forever, exactly as still shown in Mark's latest
      report. strip_timestamp_prefix now strips whole Windower
      colour-code sequences first (\30 + 1 byte, or \31 + 3 bytes -
      the two real forms, confirmed against the actual captured
      bytes rather than guessed), THEN any leftover control byte,
      THEN the bracket timestamp. Verified against the EXACT bytes
      from Mark's own log file (not a synthetic plain-text
      approximation like the two earlier widenings) - both copies
      now normalize to an identical string.
      Also removed v1.49.0's temporary debug_hex_dump diagnostic
      from print_captured_lines now that it already did its job and
      gave a real answer - back to a clean display filter with no
      extra debug noise.
      Confirmed via luac5.1 -p; still needs Mark to actually watch
      one more //gh furrow inspect (or furrow pass) after reloading
      to v1.50.0 before calling this one done for real.

  v1.69.0 (2026-09-21) - Mark corrected v1.68.0's approach before it
      ever got a real cutscene to test against: "okay, but again none
      of those Green thumb moogle cutscenes/conversations will happen
      until the garden is loaded... 20-30 seconds... so maybe if the
      cutscene is identified before furrow function happens, sure
      that is fine.. but if the furrow function starts and then we
      see there are messages from Green Thumb Moogle, that may
      happen as well. During the cutscene there is NO cursor target
      forced by the cutscene. If furrow function runs, it can and
      will target the furrows. But they wont UN-target the furrow
      with ENTER, ESC, until the cutscene is done. That is why I
      choose that as a way to tell if the cutscene is done.. esc
      will then do the standard action and remove the target of the
      furrow." Two fixes to clear_login_moogle_cutscene():
      1) Wrong test - v1.68.0 assumed a cutscene BLOCKS targeting
         itself and looped retrying find_furrow until it succeeded.
         Backwards: targeting always works regardless, per Mark - now
         targets furrow #1 once (find_furrow, same as always), then
         loops Enter+Escape checking whether the target actually
         CLEARS - Escape's normal clear-target action is what's
         blocked mid-cutscene, not targeting.
      2) Wrong timing - v1.68.0 only checked once, at the very start
         of run_full_garden_pass. The cutscene can't even trigger
         until ~20-30s after LOGIN starts, which is roughly when the
         garden finishes loading (Mark's clarification, 2026-09-21:
         "Cutscene can't even trigger until 20-30s after the login
         starts (when the garden is loaded)") - not an extra 20-30s
         tacked on AFTER the garden's already loaded. Either way it
         can just as easily start partway through a pass (between
         furrows) as before one. Now also called at the top of run_
         single_furrow_pass's per-furrow loop, so every furrow gets a
         fresh check, not just furrow #1's.
      clear_login_moogle_cutscene needed forward-declaring (same
      pattern as harvest_furrow/live_probe_furrow above) since run_
      single_furrow_pass, which now calls it, is defined well before
      its real body further down the file.
      Confirmed via luac5.1 -p. Not yet live-tested by Mark.

  v1.68.0 (2026-09-21) - Mark: "sometimes there is a long cutscene
      with the green thumb moogle as soon as you login. Even during
      that it will let the script target the furrows. Please add
      some logic that can read the chat messages and if Green Thumb
      Moogle is talking, go through steps of ENTER, ESC, ENTER, ESC,
      until the conversation is over.. Now.. how do we test the
      conversation is over... either you can move, or you can open a
      conversation with Green Thumb Moogle that is for selling..."
      then, on being told the target-based test sell_junk_to_moogle's
      own cutscene-clear dance already uses was the right idea:
      "I know... keep doing that till the target clears... you can
      set target on the highest furrow, and then it won't clear
      until the conversation is over, and then ESC will clear it."
      Added clear_login_moogle_cutscene(), called unconditionally at
      the very start of every run_full_garden_pass (before
      reconcile_furrow_data or anything else touches a furrow, and
      regardless of which modules are enabled - the cutscene can fire
      right at the Mog Garden entrance for anyone). Each loop
      iteration presses Enter then Escape (Mark's own steps), then
      tries to target furrow #1 via find_furrow(quiet=true) - while
      a cutscene is still holding the client's target locked, that
      attempt just keeps timing out; the moment it actually succeeds,
      that's Mark's own proof the cutscene let go, and one more
      Escape clears the probing target cleanly before the real pass
      continues. Bounded by config.sell_junk_cutscene_timeout_seconds
      (300s), the same ceiling sell_junk_to_moogle's own cutscene
      dance already uses. Cheap when nothing's actually wrong (one
      Enter/Escape press, one quick successful find_furrow).
      Confirmed via luac5.1 -p. Not yet live-tested by Mark - worth
      specifically watching the next login that lands mid-cutscene
      for.

  v1.67.0 (2026-09-21) - Mark: "please review the logs for FishVF. I
      think we need an error correction algorithim... when it is not
      getting the expected 'you have successfully performed...' then
      an inspection is needed to determine the state... Maybe instead
      of 'you have successfully performed that action..' we look for
      'obtained'?" Read Fishvf's actual Windower log
      (Fishvf_2026.09.21.log) and confirmed it: "You have successfully
      performed that action N times, and may do so again M more
      times." only ever appears around Mineral Vein/Arboreal Grove
      harvests (NPC dialogue, limited-uses-per-day text) - it never
      once appears anywhere near a furrow harvest, all day, across
      many cycles. What DOES appear every single time, right after a
      furrow's Yes/No harvest confirm, is one or more "Obtained:
      <item name>." lines. So harvest_furrow()'s v1.65.0 success
      check - added to fix a real bug (see that entry below) but
      copying harvest_success_phrase from harvest_vein/harvest_grove
      without checking whether furrows actually print that same
      text - was checking for a phrase furrows apparently NEVER
      produce, meaning it would have reported every furrow harvest as
      a failure (retrying forever, never advancing past 'ready') even
      though the harvest itself was landing fine - worse than the
      pre-v1.65.0 behavior for furrows specifically. Fixed:
      config.furrow_obtained_phrase = 'Obtained:' is now the primary
      thing harvest_furrow() checks for, with harvest_success_phrase
      kept as a fallback check too (belt and suspenders, matches
      vein/grove precedent, costs nothing if it never actually
      fires for furrows).
      Also added the "inspection" Mark asked for as a second
      fallback: harvest_furrow() now takes an optional furrow
      argument (all 3 real call sites - harvest_cycle, and both
      branches of handle_furrow_for_start - now pass it), and if
      NEITHER phrase shows up, it calls live_probe_furrow(furrow) to
      actually re-open the menu and read the real current state
      rather than leaving a possibly-stale recorded status for next
      pass to blindly retry against. If the inspection finds the
      furrow really is 'empty' now (harvest landed, confirmation text
      was just missed - e.g. client lag, Mark's other guess), that's
      now treated as a success after all; any other inspected state
      is logged and left recorded as whatever it truly is, so the
      next pass acts on real data instead of guessing.
      live_probe_furrow needed forward-declaring (same pattern as
      harvest_furrow/plant_seed/etc. above) since harvest_furrow's
      body, which now calls it, is defined before live_probe_furrow's
      real body further down the file.
      Confirmed via luac5.1 -p. Not yet live-tested by Mark (the
      log reviewed predates this fix, from before any v1.65.0/v1.66.0
      reload) - worth specifically watching the next //ml smart run's
      furrow harvests for.

  v1.66.0 (2026-09-21) - Mark: "we can address that now" (the
      login-event race flagged but deliberately left unfixed in the
      v1.65.0 audit pass, to test before testing //ml smart). Fixed:
      saved_status is a single shared upvalue table, and the 'login'
      event handler REASSIGNS it wholesale (saved_status = winconfig.
      load(...)) for whichever character just logged in - it has no
      way to know about, or wait for, some other coroutine left
      sleeping mid-pass from the PREVIOUS character (e.g. inside
      reconcile_furrow_data's retry loop, or between capturing
      harvest text and recording it). If that stale coroutine woke up
      and saved AFTER the swap, it would write the previous
      character's just-captured values onto the NEW character's
      saved_status table - a real theoretical corruption risk given
      this addon's coroutine.sleep-heavy capture/retry loops, not
      confirmed to have happened live but worth closing before a
      public release.
      New guarded save_status() (defined right after saved_status
      itself) checks state.running before saving, and is now used by
      every save site that carries forward a live-captured
      observation across a sleep: record_furrow_state,
      record_seed_inventory, record_node_harvest,
      record_full_pass_complete, and both saves inside
      reconcile_furrow_data. state.running is the right guard because
      every event that could swap saved_status out from under a
      caller (login/logout/zone change/unload/'//gh stop') sets it
      false FIRST, synchronously, with no sleep of its own - so a
      truly stale coroutine will reliably see it as false by the time
      it wakes, well before a brand new pass for the new character
      could set it back to true (that takes many real seconds of
      logout wait/character-select/login wait/furrow polling). A
      skipped save just means one late observation is lost - status
      tracking self-heals on the next real check, which beats
      silently attributing it to the wrong character.
      Deliberately did NOT gate the other 3 winconfig.save(
      saved_status) call sites the same way - reset_furrow_status,
      reset_module_status (synchronous, command-triggered, no sleep
      between their own read and save - no race window exists) and
      sync_module_status_flags (a pure fresh recompute off LIVE game
      state every time it runs, not a carried-forward captured value
      - and it's explicitly meant to be safe to call anytime,
      including from //gh status while nothing is actively running;
      gating it on state.running would have broken that). Confirmed
      via luac5.1 -p; this closes a theoretical race rather than a
      confirmed live symptom, so there's nothing specific for Mark to
      watch for beyond normal //ml smart testing.

  v1.65.0 (2026-09-21) - Mark: "let's move forward towards a public
      release. Please look for any errors, logic issues, memory
      issues, possible nil value, crash issues, and also useability
      in the readme, and anything unclear." Multi-agent pre-release
      audit pass across the whole file plus README.md. Real bugs
      fixed (not just doc/comment cleanup - see below for those):
      1) harvest_furrow() previously returned nothing at all and
         never checked for a real confirmation - every call site
         (both branches of handle_furrow_for_start, plus the
         standalone harvest_cycle) blindly marked the furrow 'empty'
         and counted it harvested regardless of whether the final
         Yes/No confirm actually registered. Under lag, a dropped
         keypress there left a furrow still full of an unharvested
         crop while the recorded data said 'empty' (wiping the real
         harvest_at/epoch) - the next pass would then try to plant
         into the still-occupied furrow, silently wasting a real
         plant-menu attempt (self-correcting only via plant_seed's
         own rejection-text handling). harvest_furrow now checks for
         config.harvest_success_phrase (the same generic confirmation
         vein/grove already gate on) and returns a real success
         value; all three call sites now only record/count a harvest
         when it actually returns true, matching vein/grove's
         existing any_success pattern.
      2) harvest_pond/harvest_flotsam/harvest_net recorded "done
         today" unconditionally, with no equivalent confirmation
         check - unlike harvest_vein/harvest_grove, which already
         gate record_node_harvest behind an any_success check. A
         dropped keypress (no captured text at all) would still mark
         the module done for the rest of the JST day, with no error,
         recoverable only via a manual //gh <module> reset. All three
         now only record a harvest when a real confirmation showed up
         (the already-done phrase, or config.harvest_success_phrase)
         and error_log clearly when it doesn't.
      3) //gh vein/pond/grove/crystals/flotsam/net's own [force]
         argument was case-sensitive (exact 'force' only) while the
         sibling 'reset' check and furrow's own force-detection were
         both already case-insensitive - a capitalized typo (e.g.
         //gh vein Force) silently ran a normal, non-forced pass with
         no warning it wasn't understood. Now case-insensitive to
         match, and an unrecognized second argument now gets an
         explicit error_log instead of silently being ignored.
      4) //gh furrowinspect <bad number> (a typo, or an out-of-range
         number like 4) previously gave no feedback at all - a
         non-numeric argument silently collapsed to "inspect every
         furrow" and an out-of-range number silently inspected
         nothing. Now validated explicitly (1, 2, 3, or "all"),
         matching reset_furrow_status's own validation for the same
         shape of input.
      5) approach_furrow(furrow_number) indexed FURROWS[furrow_number]
         positionally instead of by each entry's own .number field,
         unlike every other furrow lookup in the file (get_furrow_id,
         find_furrow). Currently harmless since FURROWS happens to be
         in gap-free 1/2/3 order, but fragile against a future
         reorder/edit - now looks up by .number like everywhere else.
      Doc/comment-only fixes, also found this pass: the top-of-file
      winconfig comment claiming saved_status does NOT persist per-
      character was itself stale/wrong (already contradicted by the
      v1.41.2 entry's own correction, never updated to match) - re-
      verified directly against a live settings.xml this pass
      (pond_last_harvested_date genuinely differs per character
      section) and corrected; sell_checkpoint_active's comment still
      called the final Net checkpoint "unconditional" after v1.64.0
      made it conditional; sync_module_status_flags's comment named
      status_defaults instead of the saved_status table it actually
      mutates. All confirmed via luac5.1 -p; the live-behavior fixes
      (1-2 especially) can only be fully confirmed by Mark watching
      real passes over time, since they only change what happens on
      an already-rare dropped-confirmation edge case.

  v1.64.0 (2026-09-21) - Mark: "with the //ml smart, 90% of the time
      it will just be furrows being processed, so ending up at sell
      moogle is a waste of time. Lets only do that if the character
      is going other places like once a day when all the other
      objects get harvested." Then, once inventory-fill was raised as
      a concern for a long run of furrow-only passes: "is there maybe
      a way that inventory space can be checked,.. if over 75% full,
      then sell?" - "actually, lets make a config for that as well.
      Set at 75% for now."
      run_full_garden_pass already had non_furrow_pending_sale
      gating every intermediate sell checkpoint except furrow's own
      so a furrow-only pass never triggered an actual sell menu
      interaction - but the FINAL checkpoint (after Net, always fires
      regardless of sell level) still unconditionally walked all the
      way back to the Green Thumb Moogle even with nothing to sell
      (return_to_green_thumb_moogle), just to skip the menu once it
      got there. That walk itself was the "waste of time" Mark meant,
      not just the sell interaction - so a furrow-only pass
      (non_furrow_pending_sale still false) now skips this whole
      final step and simply stays wherever the last furrow left it,
      instead of walking back at all. return_to_green_thumb_moogle()
      is consequently unused for now (left in place, see its own
      updated comment) - nothing else currently calls it.
      Added new config.sell_inventory_full_threshold (0.75) plus
      inventory_fill_ratio()/inventory_getting_full() (occupied
      inventory slots / max slots, via windower.ffxi.get_items(),
      same ipairs-over-items.inventory approach get_item_count
      already used) as a safety-net override on top of the above: if
      inventory is at/above this threshold, BOTH the final checkpoint
      and every intermediate maybe_sell() checkpoint will now sell
      (and, for the final one, walk back) even on an otherwise
      furrow-only pass or an inactive sell-level checkpoint, so a long
      run of small furrow-only harvests can't quietly fill inventory
      with no real catchup pass in sight to clear it.
      Confirmed via luac5.1 -p; the real-world effect (no more
      furrow-only trips to the moogle, but still selling once
      inventory actually gets full) can only be confirmed by Mark
      watching //ml smart run live.

  v1.63.0 (2026-09-21) - Mark (screenshot, red box): "these lines
      are not needed" - removed the two notice() lines that printed
      right after the "GardenHelper vX.X.X loaded" line on every
      single load ("Please ensure at least one Garden Furrow is
      unlocked for proper operation." and "Requires the SetTarget
      addon to be loaded for ID-based furrow targeting.") - one-time
      setup reminders Mark already knows by now, not worth reprinting
      on every reload.

  v1.62.0 (2026-09-21) - Mark: "'ml smart' knows its time to
      harvest, but then once logged in maybe its 'gh furrow' or 'gh
      full' that doesn't think it is time to harvest?" - exactly
      right. infer_furrow_state() (used by furrow_pass_needed - the
      gate that decides whether //gh full/furrow even walks over to
      check a growing furrow at all) was recomputing ready-ness from
      checked_epoch + the flat get_effective_harvest_time()/
      get_effective_fertilize_wait_time() estimate (60/30 min
      config defaults), while MuleLogger's scheduling (via
      sync_module_status_flags's furrow_next_ready_epoch) already
      used the ACCURATE stored furrow_N_harvest_epoch - the game's
      own reported remaining time for that specific seed (record_
      furrow_state/parse_remaining_seconds), which can be shorter
      than the flat estimate (e.g. 52 real minutes for tree saplings
      vs the 60-minute default). Whenever the real time was shorter,
      MuleLogger correctly saw the furrow as ready and kept
      re-triggering a visit every ~13s (Shadowhammer, 2026-09-21
      17:08-17:10+: dozens of consecutive "Staying logged in... to
      harvest furrows" -> "gh full" -> "Furrows: all recorded as
      still growing (not due yet)" -> Unity chat message, back to
      back), while GardenHelper's own gate kept saying not due yet
      until the flat 60-minute estimate ALSO elapsed - a real
      mismatch, not a timing race, and one that spammed Unity chat
      on every single failed retry (see MuleLogger v1.33.0's own
      fix for that danger). infer_furrow_state now prefers the
      stored furrow_N_harvest_epoch (same as sync_module_status_
      flags already does) and only falls back to the flat estimate
      when no harvest_epoch is recorded yet. This is the single
      shared function behind furrow_pass_needed, handle_furrow_for_
      start, and every other live/scheduling decision in this file,
      so the fix applies everywhere at once rather than needing to
      be repeated per call site.

  v1.61.0 (2026-09-21) - Mark (screenshot, red box): "let's do
      another cleanup pass to limit messaging that is used by the
      script, but the player doesn't necessarily need to see" -
      live_probe_furrow (the function behind //gh furrowinspect)
      still printed its full internal play-by-play every time:
      "Running (explicit): ...", "Detecting (enter, enter)...", "(no
      new chat/system text appeared)", "Captured text:" plus the raw
      captured lines themselves, and "Exiting (...): ...". All of
      that is now debug_log-only - furrowinspect's visible output is
      just the "--- <furrow name> ---" header and the "Guessed
      state: ..." summary line (plus any real error_log). Also, per
      Mark: "Add the date/time when the furrow is next ready (format:
      9/21 4:45pm)" - the summary line now appends ", H@ <time>" (via
      the existing format_short_datetime helper) whenever the guessed
      state is growing_unfertilized/growing_fertilized/ready, e.g.
      "Guessed state: growing_unfertilized, H@ 9/21 5:57pm". Moved
      record_furrow_state's call earlier in the function (before the
      summary line instead of after cursor hygiene at the very end)
      so the freshly-computed harvest_at value is available in time
      to print. Scoped to live_probe_furrow/furrowinspect only - a
      second, similar-looking Detecting/Guessed-state pair elsewhere
      in the file (the furrowloop live-detect fallback) was left
      untouched since Mark's screenshot was specifically of
      furrowinspect output.

  v1.60.0 (2026-09-21) - Mark: "these lines I would like to keep for
      now" - walk_to_entity's one-time "Lock On may not have engaged
      ... recovering and retrying" narration. Reverted back to a
      normal (visible) log() line - it was downgraded to debug_log in
      v1.59.0's broader attempt/retry cleanup, but Mark wants this
      one kept. The other 4 lines from that same cleanup (sell-to-
      moogle attempt counter, the two moogle-cutscene-retry lines,
      and the furrow entity-loading-lag retry loop) stay debug-only.

  v1.59.0 (2026-09-21) - Mark: "let's clean that up the same way for
      all functions, all objects... it's just clutter.. we just need
      to know the outcome... what Vein is being targeted, what
      grove.. etc.", then "we don't need to see the attempts to find
      each one... that would be fine for Debug messaging." Most of
      vein/pond/grove/crystals/flotsam/net's own retry/attempt
      narration was already debug_log (find_entity, find_highest_
      vein/grove's per-rank fallback, the depleted-target replacement
      search, etc. - see v1.18.0-era comments). Downgraded the 5
      remaining spots still printing every time: walk_to_entity's
      one-time stuck-recovery narration, the sell-to-moogle "Talking
      to the moogle (attempt N/5)..." counter (visible on literally
      every sell, even a normal first-try one), two moogle-cutscene-
      retry lines, and the furrow entity-loading-lag retry loop. The
      actual outcome each of these leads to ("Walking to X...",
      "Reached X", "Highest available vein: rank #N. Harvesting
      X...", "Got the standard greeting...", "X harvest complete.",
      "Furrows available this run: ...", etc.) is untouched and still
      prints normally either way.

  v1.58.0 (2026-09-21) - Mark (screenshot, red box): "let's clean up
      the messages, and remove these lines" - "Found Garden Furrow
      #3", "[ERROR] Could not target Garden Furrow #3 ... assuming it
      does not exist", and "Garden Furrow 3 did not re-confirm after
      a flush re-check - most likely a stale entity ... Removing it
      from this run." all printed together every time a stale/phantom
      furrow entity (carried over from a previous character in the
      same client session - a known, already-self-handled situation,
      see the flush-recheck comment above) got probed and then
      correctly filtered back out. Added a `quiet` param to
      find_furrow(): when true, its Found/Could-not-target/wrong-name
      messages go to debug_log instead of log/error_log. Wired
      quiet=true into probe_existence() (the existence-only scan - a
      REAL furrow still gets its normal "Found Garden Furrow #N" the
      first time something actually interacts with it later in the
      same run, just deferred from the abstract probe to the real
      approach) and into the flush-recheck's own two find_furrow
      calls. The "did not re-confirm... removing it" explanation is
      debug_log now too - the outcome ("Furrows available this run:
      1 2") still shows either way, just without the play-by-play on
      every single pass.

  v1.57.0 (2026-09-21) - Mark: "when kicking off gh full, gh furrow,
      ml startfromhere, can we check the time from zone in / login,
      so that we ensure we wait till the entities are loaded? ... or
      pretty much any of the commands." Added state.last_arrival_epoch,
      set by both the 'login' and 'zone change' event handlers
      (whichever happened most recently is what matters - either can
      leave furrow/vein/pond/grove/flotsam/net/the sell moogle not
      yet spawned). New wait_for_entities_settled(), called at the
      very top of garden_command() for every command EXCEPT a short
      exempt list of pure status/info/control ones (stop, abort,
      debug, furrowstatus, furrowconfig, status, help) - waits out
      whatever's left of config.min_seconds_since_arrival (new,
      default 15s) before letting the command actually touch
      anything. This is a single fix that covers every caller: //gh
      full/furrow/etc run by hand right after zoning in, AND //ml
      startfromhere (which explicitly skips MuleLogger's own
      login_wait_seconds wrapper) - both just end up sending a //gh
      command through this same dispatcher, so nothing needed
      changing in MuleLogger.lua at all. A no-op once enough time has
      already passed - the normal case for anything MuleLogger's own
      automated login flow triggers, since its wait already covers
      this before 'gh full' is ever sent. Added //gh furrowconfig
      arrivalwait <seconds> (0-120) to adjust without editing the
      file, plus a line in furrowconfig show. Also caught and fixed a
      gap from v1.55.0 while in here: sell_level was never added to
      config_defaults, so a //gh furrowconfig selllevel change would
      have silently carried over to the next mule MuleLogger logged
      into instead of resetting - the exact bug config_defaults
      exists to prevent for every other //gh furrowconfig-settable
      value. Both sell_level and the new min_seconds_since_arrival are
      in config_defaults now.

  v1.56.0 (2026-09-21) - Mark: "when using //ml smart, it is selling
      after the furrow still. Please check the most recent logs."
      Checked Goldvf's real log: Vein and Pond both printed "already
      harvested today - skipping" (nothing new), yet the Pond
      checkpoint (sell level 2) still triggered a full moogle trip -
      because furrow's own harvest was setting the shared
      pending_sale flag, and every checkpoint sells on ANY pending
      item regardless of source. This technically matched sell level
      2 as documented, but since furrows can ripen several times a
      day while vein/pond/etc only reset once, //ml smart's Tier 1
      "harvest furrows" visits are common and mostly furrow-only, so
      this meant a real sell trip almost every time for just a couple
      furrow items - not what v1.55.0's level-2 answer actually
      intended. Added a second flag, non_furrow_pending_sale, set
      only by vein/pond/grove/crystals/flotsam/net. Every checkpoint
      except furrow's own (level 3/4 only, where "sell right after
      furrow" IS the point of that checkpoint) now requires this
      instead of plain pending_sale - so a furrow-only pass no longer
      sells at ANY level; furrow's items just ride along whenever a
      checkpoint next fires for a real reason.

  v1.55.0 (2026-09-21) - Mark asked whether there's a sell level for
      "furrow if ready > vein > pond > sell" (not selling after furrow
      alone, since furrows don't give many items). Answer: sell level
      2 - config.sell_checkpoints_by_level[2] = {pond = true} - is
      already exactly this, and is already the default (no checkpoint
      at furrow or vein, first sell fires once pond's been attempted,
      final sell always happens at the end after Net) - nothing to
      create or adjust there. What WAS missing: no way to see or
      change the active sell level in-game at all - config.sell_level
      was config-only (same as sell_junk_enabled, doesn't survive a
      reload) and invisible without opening the file. Added //gh
      furrowconfig selllevel <1-4> to set it, and a Sell level line
      (with each level's one-line description) to //gh furrowconfig
      show, so it can actually be checked/changed without editing the
      file.

  v1.54.0 (2026-09-21) - Trimmed the "already harvested today -
      skipping" module lines (Vein/Pond/Grove/Flotsam/Net) and the
      furrows "not due yet" line, per Mark's 2nd screenshot (red boxes
      around the trailing "(use //gh X force, or //gh force, to
      override)" hints and the furrows line's "- skipping the furrow
      step entirely" tail): "they are assumed and not needed here."
      These were boilerplate on every already-done module regardless
      of whether anyone needed the override reminder that run. Each
      line now just states the fact ("Vein: already harvested today -
      skipping.", "Furrows: all recorded as still growing (not due
      yet)."), nothing appended.

  v1.53.0 (2026-09-21) - Two fixes from Mark's latest //gh
      furrowinspect test. (1) Duplicate chat lines, REAL root cause
      finally found via the new v1.51.0 silent hex diagnostic
      (data/debug_captured_lines.log): the v1.50.0 "fix" was written
      through a python device_bash script using the string literal
      '\30.'/'\31...', intending Lua's decimal-escape syntax (byte
      0x1E, the real FFXI color-code introducer) - but that was a
      PYTHON string literal, and Python parses '\30' as an OCTAL
      escape (24 decimal = byte 0x18), not decimal 30. So the byte
      actually deployed to the live file was 0x18 (never present in
      real chat text), meaning the v1.50.0 gsub never matched
      anything at all in production - it only looked correct in the
      earlier standalone Lua test, which used Lua's own \30 escape
      directly and wasn't affected. Rebuilt strip_timestamp_prefix
      with the correct byte values (0x1E, 0x1F) via unambiguous
      chr()-built strings this time. Also folded in a second finding
      from the same hex dump: the ORIGINAL (non-duplicate) capture of
      several lines ends in a trailing Windower control sequence -
      byte 0x7F followed by one argument byte (e.g. 0x7F 0x31) - that
      the old %c strip only half-removed (stripping 0x7F but leaving
      the argument byte behind as literal text), so the original and
      duplicate copies normalized to two different strings one
      character apart and never matched. Now strips 0x7F + 1 byte as
      its own sequence too, same as the 0x1E/0x1F handling.
      (2) Menu-navigation timing race (Mark: "had a timing issue with
      one of the furrows, and ended up selecting 'inspect' instead of
      DOWN DOWN ENTER to select 'absolutely nothing'"). Each
      EXIT_SEQUENCES entry's first navigational Down was firing
      immediately once the preceding Enter's captured text went quiet
      (run_key_sequence's text_settle_seconds debounce) - but chat
      text going quiet doesn't guarantee the menu UI has actually
      finished transitioning/become interactive yet. A Down fired
      into a not-yet-interactive menu is dropped, leaving the cursor
      on the default first item ("Inspect the garden"), so the
      sequence's final Enter confirmed that instead of "Absolutely
      nothing" - exactly Mark's symptom. Added a 0.4s pre_wait
      (run_key_sequence already supported this option, previously
      unused) before every EXIT_SEQUENCES entry's first navigational
      key, giving the client a moment to catch up before the first
      Down/menu-nav press fires.

  v1.52.0 (2026-09-21) - Fixed '//ml status' showing a stale/wrong
      harvest time even after a //gh furrowinspect had already
      corrected it (Mark: "I also just now noticed that '//ml status'
      still has the 9/23 harvest time, instead of the newly calced
      time from recent //gh furrow inspect"). Two separate root
      causes: (1) sync_module_status_flags() - which computes
      furrow_next_ready_at/epoch, the fields //ml status actually
      reads cross-addon - was recomputing its own "next ready" guess
      from checked_epoch + the flat configured wait time, completely
      ignoring furrow_N_harvest_epoch (which record_furrow_state had
      already correctly set from the game's own real remaining-time
      text back in v1.47.0). Now prefers the stored harvest_epoch,
      falling back to the old estimate formula only if it's missing/
      zero. (2) furrowinspect never called sync_module_status_flags()
      at all - only duecheck/full/force/status did - so even a
      perfectly correct furrow_N_harvest_epoch from a live inspect
      wouldn't reach furrow_next_ready_at/epoch (and therefore //ml
      status) until one of those other commands happened to run next.
      Added the sync call to furrowinspect too.

  v1.51.0 (2026-09-21) - v1.50.0's colour-code fix did NOT resolve
      it. Mark, after a confirmed v1.50.0 reload (log file showed
      "GardenHelper v1.50.0 loaded" at 15:50:53, then the duplicate
      again at 15:51:05): "I reloaded GH, and I am still seeing
      duplicate lines when inspecting. Please review the most recent
      logs again." Checked Shadowhammer's log file directly again -
      but this time confirmed the log file itself is not useful
      evidence here: Windower's own log writer already strips colour-
      code bytes before saving to disk, so the "duplicate" line in
      the log shows a perfectly plain "[15:51:04] This furrow..."
      with no unusual bytes around it at all (verified with a raw
      hex dump of that exact byte range) - the log file can't show
      what this addon's own 'incoming text' handler actually
      received, only what got written after Windower's own
      stripping already ran. So the log file can no longer answer
      "what's actually different between these two copies" - only
      the addon's own real-time capture can.
      Rather than guess a further colour-code variant blind, added a
      silent file-based diagnostic (debug_dump_raw_line, wired into
      print_captured_lines) that writes the full hex of every
      captured line straight to its own data/debug_captured_lines.log
      file whenever config.debug_mode is on - no chat spam this
      round, and no screenshot needed either, since this can be read
      directly. Once Mark reproduces this once more on a confirmed
      v1.51.0 reload, that file has the real answer.
      Confirmed via luac5.1 -p.


  v1.70.0 (2026-09-22) - Big batch from Mark's 11-item list.
      NEW FILES next to this one (loaded once at startup, plain data):
        entities.lua   - every NPC/object with friendly name, real
                         name, zone, id and X/Y (item #2).
        characters.lua - seed/fertilizer defaults, per-character seed
                         overrides, and per-character module on/off
                         (incl. the new 'books' switch). MuleLogger
                         reads it too. Moved out of this file.
      #1/#9 Arrival: min_seconds_since_arrival 15 -> 30 (from login or
        zone-in), then poll for the Green Thumb Moogle, target him and
        make sure the target holds, then poll for the first node
        (furrow 1) - once per arrival (wait_for_entities_settled). The
        v1.68/1.69 Enter/Escape cutscene probe on furrow 1 before every
        furrow is now OFF (config.furrow_cutscene_probe_enabled) - it
        was what interfered with furrow harvesting.
      #2 X/Y navigation (config.navigation_mode = 'xy'): walks to the
        entities.lua spot with windower.ffxi.run(), re-aiming every
        0.1s, sidestepping when stuck, falling back to the old Lock-On
        walk if it can't get there. Within config.interact_distance
        (5.5) counts as reachable. Vein/Grove: if the next variant
        shows up out of reach after harvesting started, it walks over
        and harvests it anyway, and alert()s (<call0> via /echo, or
        config.alert_sound_file) with your current X/Y so a better spot
        can be picked. Mineral Vein rank 4 added. //gh pos now prints
        your own standing X/Y plus a paste-ready entities.lua line (and
        no longer ALSO prints "Unknown command: pos").
      #3 Books: //gh books [force|done|reset] - Mark's exact Mog Dinghy
        -> Port -> Skipper Moogle -> buy loop -> Dinghy back flow, once
        per garden day, skipped for books = false. Not in //gh full
        unless config.books_in_full. Status: checked today / Purchased
        today / not checked today / You're Broke!!! (alert on no gil).
        Deliberate zone changes no longer stop the running operation
        (state.expecting_zone).
      #3b Entering the garden: any garden command run from a Port zone
        within 30 yalms of the Mog Dinghy boards it first; //gh enter
        does it from anywhere in the Port zone (prints
        EnterGardenResult: OK/FAILED). Mog House -> garden: superwarp
        can't do it (only Dinghy + Adoulin NPCs), so it's a config
        hook (mog_house_exit_keys / mog_house_exit_door_xy) waiting for
        a one-time key mapping.
      #4 Commands: //gh full force|inspect|done|reset; //gh <vein|pond|
        grove|flotsam|net> force|inspect|done|reset; crystals done|
        reset; books done|reset; furrow done (planted now with this
        character's seed -> harvest time). reset = UNKNOWN (new
        *_unknown fields).
      #5 Pond/Flotsam/Net success = "Obtained:" lines, waiting 2s after
        the last one. Nothing is marked done without a completion or
        "already done" message - otherwise UNKNOWN. Flotsam: Enter with
        no response at all = already harvested today = done.
      #7/#10 Garden day now computed from UTC (JST midnight = 15:00
        UTC): 9am MDT / 8am MST automatically, config.jst_reset_local_
        hour removed. Date labels match the old ones, so existing data
        still lines up. //gh status checks it fresh every time.
      #8 Inventory full ("...after sorting your inventory") mid-harvest:
        Enter, Escape, sell (SellNPC + Treasury), then restart that
        node/furrow (up to 2 times), never marking it done.
      #11 Crystals: //gh crystals trades ALL crystals/clusters to the
        Ephemeral Moogle (TradeNPC's trade packet built in - no
        TradeNPC/QuickTrade needed), repeating until none are left,
        answering the "hold onto these" / "That's all" prompts. //gh
        full only trades when holding more than 12 of any one type.
      Also: every settings save now re-reads data/settings.xml first
        (persist_status) - Windower's config library rewrites the whole
        file from a load-time snapshot of every character, so
        MuleLogger's cross-character edits were being silently undone.
        //gh reloadstatus re-reads it on demand (MuleLogger sends it).
        Fixed save_status() calling debug_log before it's defined.
      Confirmed via luac5.1 -p, plus a no-stray-globals check.
  v1.71.0 (2026-09-22) - Items #12-#14 from Mark's list.
      #12 //gh furrow inspect [1|2|3|all] (= furrowinspect) and //gh full
        inspect now ACT on what they find: each furrow is detected live
        (forced merged pass - same enter, enter detect) and anything
        ready is harvested + replanted, anything empty is planted, and
        a planted-but-unfertilized furrow is fertilized if
        use_fertilizer is on. New config.inspect_takes_action (default
        true; false = old look-only inspect). An explicit preset/key
        list (//gh furrowinspect 1 empty) stays look-only.
        run_single_furrow_pass got an optional only_number argument.
      #13 Walker (walk_to_xy): once within config.xy_near_zone_yalms (6)
        of the X/Y spot it watches the distance and finishes the walk
        as soon as it stops going down for config.xy_plateau_seconds
        (0.6s, progress = at least xy_plateau_epsilon_yalms 0.1 closer)
        - handles spots that are node centers you can't stand on. No
        sidesteps inside that zone; a stall farther out than 6 yalms
        still gets the usual sidestep / stuck-check handling. The
        end-of-walk "close enough" check now uses max(interact_distance,
        xy_near_zone_yalms). navigate_to_entity still closes the gap to
        the real target afterward if it's out of interact range.
      #14 //gh pos prints "Zone ID: <id> (<zone name>)" first, adds the
        zone to the Target line, and says whether the target is already
        in entities.lua (its friendly name, zone and X/Y) - with an error
        if that entry's zone doesn't match the zone you're in. On load,
        every entities.lua entry is checked for a missing zone, and
        against the zone encoded in its entity id (id = 0x1000000 +
        zone * 4096 + index); mismatches print a [WARN]. All 38 current
        entries already have a zone and all match their ids.
      Confirmed via luac5.1 -p.
  v1.72.0 (2026-09-22) - Ephemeral Moogle missing status (Mark).
      harvest_crystals now checks the Ephemeral Moogle is actually in
        the garden before doing anything: get_mob_by_id first (cheap,
        every pass - even with no crystals to trade), then find_entity
        right before walking over to trade. Either failing logs
        "Ephemeral Moogle Missing" and sets the new saved_status field
        crystals_missing (cleared the next time it's found).
      //gh status's Crystals row shows "Ephemeral Moogle Missing" when
        that flag is set; MuleLogger v1.44.0's //ml status shows M in
        its new Crys column.
  v1.73.0 (2026-09-23) - //gh sell reports its result (Mark: sell and
      reload Treasury before MuleLogger's //ml inv). //gh sell now
      always ends with a "SellResult: DONE / FAILED / BUSY / DISABLED"
      line, which MuleLogger v1.46.0 waits for before running
      inventory. sell_junk_to_moogle returns true once it has sold
      (SellNPC) and reloaded Treasury; nothing else about selling
      changed.
  v1.74.0 (2026-09-23) - Pond marked UNKNOWN even though it was
      harvested (Mark, Clothvf log 09:05). Enter at 09:05:08, press
      waits (5+3+3s) ran out at 09:05:19, error logged, then the 8
      "Obtained" lines arrived at 09:05:20 - the pond's net-raising
      cutscene makes the result print ~12s after the first Enter.
      MuleLogger then saw Pond not done and ran a second pass, which
      got "too light" and recorded it done. Fix: Pond/Flotsam/Net
      now keep listening after their last press for up to
      config.obtained_late_wait_seconds (10) for the first "Obtained"
      / already-done / inventory-full line, ending the moment it
      arrives, then settle as before. Net's flat 5s cutscene wait is
      folded into this. Vein/Grove unchanged.
  v1.75.0 (2026-09-23) - Arrival timing (Mark, 09:29 log).
      min_seconds_since_arrival 30 -> 45: wait a full 45s after
        login/zone-in, then start polling for the Green Thumb Moogle.
      "Could not target the Mog Garden moogle" is no longer shown
        while polling (find_moogle(quiet) -> debug only). Polling runs
        until config.arrival_give_up_seconds (60) after login/zone-in;
        only a miss at that point is shown as an error.
      Once found: target -> hold check -> release cursor (target
        clear + Escape x2), config.arrival_confirm_rounds (3) times
        in a row, THEN "Green Thumb Moogle detected" is shown to the
        player and furrow detection starts. A dropped target in any
        round goes back to polling.
      Fixed stale "resets to 15" text in //gh furrowconfig arrivalwait.
  v1.76.0 (2026-09-23) - "Target out of range" walker (Mark,
      Leathervf log 09:30). Both furrows were within interact_distance
      by the numbers, but every harvest/inspect press came back
      "Target out of range." (distance or line of sight), so both
      were recorded UNKNOWN. Now, whenever an interaction's FIRST
      press gets "Target out of range" (or it's the only thing the
      game said), the walker walks toward the target itself - to 3.0
      yalms, then 1.5, then straight at it until it stops getting
      closer - re-targets it by id and name, and starts that
      interaction over. Up to config.out_of_range_max_retries (2)
      walks, then it gives up as before (not marked done) with an
      error that shows the standing X/Y for entities.lua.
      Covers every garden operation: run_key_sequence (furrow
      detect/harvest/plant/fertilize menus, the sell moogle),
      press_enter_cycle (Vein, Pond, Grove, Flotsam, Net), Flotsam's
      first press, and /item seed/fertilizer on a furrow (now
      use_item_on_target - never presses on into the menu when the
      item use was refused). Stops pressing the moment it's refused
      instead of pressing Enter into nothing 5 more times.
      harvest_furrow skips its follow-up inspection when the harvest
      was still refused after the retries (it would be refused too).
      New config: out_of_range_phrases, out_of_range_max_retries,
      out_of_range_walk_distances, out_of_range_retry_settle_seconds.
  v1.77.0 (2026-09-23) - Green Thumb Moogle cutscene on arrival
      (Mark). The arrival check/release rounds now also check the
      release itself worked (nothing targeted after target clear +
      Escape x2, watched for config.arrival_release_check_seconds).
      If the target won't release config.arrival_release_fail_limit
      (3) times in a row, it's treated as a Green Thumb Moogle
      cutscene: Enter, Escape, check for the release, repeat, until
      the target releases (= end of the cutscene) or
      config.arrival_cutscene_max_seconds (300 = 5 min) pass. Either
      way the arrival counts as done and furrow work carries on (an
      error is shown if it never released).
      New config: arrival_release_fail_limit, arrival_cutscene_max_seconds,
      arrival_cutscene_key_wait_seconds, arrival_release_check_seconds.
  v1.78.0 (2026-09-23) - Books are part of the daily routine (Mark:
      "I haven't seen BOOKS checked today on any character... add that
      to the daily routine for GH full / ML smart / ML start / ML
      loop"). Books never ran because config.books_in_full was false.
      config.books_in_full now true: //gh full checks books once per
        garden day, at the very end. //gh full force no longer
        repeats a book check already done today (//gh books force).
      //gh duecheck reports "books" as action needed when books
        aren't checked today, so //ml start/loop visits run //gh full.
      Failed trips (Mog House landing, Skipper never answered, ...)
        count toward config.books_daily_attempts (2) per garden day,
        then books are given up until the next reset so //ml smart
        doesn't keep coming back. Status shows "FAILED today".
        //gh books / books reset still work by hand.
      If the Skipper Moogle can't be found/targeted in the Port zone,
        it now takes the Mog Dinghy back to the garden instead of
        leaving the character standing in the Port.
      New saved fields for MuleLogger: books_auto, books_attempt_date,
        books_attempt_count, books_gave_up_date.
  v1.79.0 (2026-09-23) - Flotsam "cannot obtain" discard fixed (Mark,
      Fishvf 10:13 - "You cannot obtain the gem of the north." then the
      Up, Enter to discard didn't take, and it was marked UNKNOWN).
      The press cycle now stops the moment "cannot obtain" shows up,
      Up, Enter goes out ~1s later (was 13s later, after the 10s
      late-Obtained wait). Then the Flotsam is re-checked with one
      Enter: no response = cleared, recorded DONE for today (no more
      endless retries). If it answers again the discard didn't take -
      the dialog is re-run and re-discarded, up to
      config.flotsam_dispose_max_attempts (2), then UNKNOWN.
      An inventory-full "cannot obtain" (+ "Come back after sorting")
      still goes to the inventory-full path, not the discard.
      flotsam_cant_receive_phrases narrowed to 'cannot obtain' /
      "can't obtain" (was any "can't"/"cannot").
      New config: flotsam_dispose_prompt_wait_seconds,
      flotsam_dispose_settle_seconds, flotsam_cant_receive_settle_seconds,
      flotsam_dispose_max_attempts.
  v1.80.0 (2026-09-23) - Flotsam discard confirm + campaign rounds
      (Mark). The discard is now confirmed by the game's "You dispose
      of the <item>." line (config.flotsam_disposed_phrase, waited up
      to flotsam_dispose_confirm_seconds). After every round - item
      obtained OR duplicate discarded - the Flotsam is targeted and
      harvested once more, since Mog Garden campaigns can give double
      flotsam items. Rounds repeat until it stops answering (= cleared,
      recorded done), up to config.flotsam_max_rounds (4). Replaces
      flotsam_dispose_max_attempts (a discard that isn't confirmed is
      simply re-checked on the next round).
  v1.81.0 (2026-09-23) - Skip the Green Thumb Moogle arrival check
      when the garden is already loaded (Mark). If 60s+ have passed
      since the latest login / zone-in
      (config.arrival_skip_check_after_seconds), the target/release
      rounds are skipped and work starts right away. The check still
      runs during the loading phase (under 60s), and when no login/
      zone-in time is known (addon loaded after arriving).
  v1.81.1 (2026-09-23) - The 60s skip didn't apply after a
      //lua r gardenhelper (Mark, Fishvf //gh flotsam still did the
      3x moogle check): a reload clears the login/zone-in time. Now,
      with no recorded time, the check is skipped as long as the
      Green Thumb Moogle is already spawned. Applies to every command
      (full, flotsam, net, furrow, books, MuleLogger's smart/start/loop)
      since they all go through wait_for_entities_settled().
  v1.82.0 (2026-09-23) - Faster book trips from a Port zone (Mark,
      Fishvf //ml smart: landed in Port Windurst 10:39:41 but sat in
      the 45s "Mog Garden to finish loading" wait until 10:40:27).
      Port zones load much faster than the garden, so the fixed wait
      is gone there: right after the zone-in it polls for the Skipper
      Moogle, targets him and checks the cursor is still on him 1s
      later, 2 rounds in a row, then starts the book check
      (config.port_poll_interval, port_arrival_max_seconds 60,
      port_target_hold_seconds, port_confirm_rounds).
      Already standing in a Port zone with today's book check due
      (//gh full, //gh enter, MuleLogger logging in at a Port): books
      are done right there first, then the Dinghy into the garden -
      no garden -> Port -> garden round trip at the end of //gh full
      (config.books_first_from_port = true). A failed trip counts
      toward books_daily_attempts as before.
      //gh stop / //ml stop during the trip back no longer prints
      "[ERROR] Could not reach/target the Mog Dinghy".
  v1.82.1 (2026-09-23) - //gh books (and the books step of //gh full
      / //ml) now starts with Escape (x2, clear_cursor_state) to drop
      any cursor target before doing anything (Mark). Previously that
      only happened when starting inside the Mog Garden; now it also
      runs when starting in a Port zone. Skipped when books are
      disabled for the character or already done today.
  v1.83.0 (2026-09-23) - Side-step before the Net -> Green Thumb
      Moogle walk (Mark: the walk was awkward and bumped into the
      tables and chairs). When a moogle walk starts within 8 yalms of
      the Coastal Fishing Net, it first moves 10 yalms to the left
      (relative to the direction of the moogle), then walks to the
      moogle as before. Stops the side-step early if something blocks
      it. config: net_to_moogle_strafe_enabled, _yalms (10), _side
      ('left' - flip to 'right' if it goes the wrong way),
      _trigger_yalms (8), _timeout_seconds (5).
  v1.84.0 (2026-09-23) - Furrow rank now updates after a book
      upgrade (Mark, Fishvf //ml smart: Designer Farming took the
      furrows from rank 4 to 5 and unlocked #3; the game said "rank 5"
      for all three, but //gh status showed #1/#2 at rank 4, #3 at 5).
      Cause: a furrow harvested from recorded status ("recorded status
      says ready - harvesting") recorded 'empty' without the captured
      harvest text, so its "This furrow is rank N" line was never read;
      only live inspections (#3, newly found) updated the rank.
      Now the harvest text is passed through (//gh furrow / full / ML
      passes and //gh furrowharvest), and since all furrows share one
      rank, a rank read from any furrow is written to every furrow
      that exists (not 'not_found').
  v1.85.0 (2026-09-23) - Books showing U in //ml status after a
      successful check/purchase (Mark, Fishvf). Two causes:
      1) Settings leak: Windower's config.reload fills every other
         character's missing keys with THIS character's live values;
         the next save wrote them out. Fishvf's books_unknown = true
         (//gh books reset at 10:45, failed ask at 12:26) was copied
         into every mule's section, so their checks/purchases still
         read U. persist_status and //gh reloadstatus now load the
         <global> values into the live table before reloading
         (reload_status_from_disk). Same leak explains other stale
         copied fields (e.g. furrow_3_rank 7 on not_found furrows).
      2) Slow Skipper greeting: Fishvf 12:26 - "Heigh-ho" came 10s
         after Enter, the 8s wait ran out and the menu keys were
         pressed before the dialog opened -> UNKNOWN. Now waits up to
         books_greeting_wait_seconds (20) for the greeting, presses
         menu keys only after it, and on no answer does Escape x2,
         retarget, ask again (books_ask_attempts = 2).
  v1.86.0 (2026-09-23) - Fertilizer now applied to furrows that are
      already growing (Mark, Shadowhammer): use_fertilizer was turned
      on in characters.lua while saplings were growing; //gh furrow
      showed "Tree Saplings and Rich Humus" in its header but only
      logged each furrow, because a recorded growing_unfertilized
      furrow never reached the fertilize step (only fresh plants and
      live detects did). Now a growing, unfertilized furrow is
      fertilized whenever fertilizer is ON (//gh furrow, full, ML
      passes); the full pass no longer skips furrows as "not due"
      when one still needs fertilizer and some is in inventory; a
      mid-growth fertilize keeps the earlier harvest time unless the
      game states a new one. Unfertilized furrows now log "growing
      (no fertilizer)" instead of "fertilized with (nothing)".
  v1.87.0 (2026-09-23) - Sell loads SellNPC's 'save_some' profile too
      (Mark): after 'lua r sellnpc', sell_junk_to_moogle now sends
      'sellnpc junk' AND 'sellnpc save_some' before going to the
      moogle, so items with a keep amount (e.g. Revival Root, keep 24)
      sell only the extra. New config sell_npc_profiles =
      {'junk', 'save_some'} (order sent; add/remove profiles there).
      Needs SellNPC 2.0.0.2+ for keep amounts. //gh sell, //gh full's
      sell checkpoints and MuleLogger's pre-inventory sell all use
      this same function.
  v1.88.0 (2026-09-23) - Sell loads ALL SellNPC profiles (Mark: so new
      profiles don't need a code change). sell_junk_to_moogle now reads
      addons/SellNPC/profiles.lua fresh each sell and sends
      'sellnpc <name>' for every profile in it ('junk' first, then
      A-Z). Replaces v1.87.0's fixed sell_npc_profiles list. New config:
      sell_npc_profiles_path, sell_npc_skip_profiles (names to leave
      out, empty by default). A profile name with a space is skipped
      with an error line (SellNPC only reads one word). If the file
      can't be read, falls back to just 'junk' with an error line.
  v1.89.0 (2026-09-24) - //gh status: new 'Mail in Inbox' row (Mark) -
      Y (N stacks tracked) / N, from the INV group's mail tracking
      (MuleLogger's inventory.lua mail table; new config inv_data_file
      = 'MuleLogger/inventory.lua', relative to the addons folder). Only
      mail sent by //ml send / inv is tracked. Goes with MuleLogger
      v1.56.0 (Tier 6 mail pickup, M status column, INV in inv.lua).
  v1.90.0 (2026-09-24) - No more reloading SellNPC / Treasury (Mark:
      the game ran out of memory and crashed during a long MuleLogger
      rotation - "not enough memory" on SellNPC and Treasury loads).
      Every 'lua r sellnpc' / 'lua r treasury' loaded the whole item
      database again, once or twice per character, and Windower
      doesn't give all of that back, so the game's memory crept up
      every character until a load failed.
      - Sell: 'sellnpc clear' empties SellNPC's queue instead of
        reloading it; every profile in profiles.lua is still loaded
        after it ('junk' first, then A-Z). Needs SellNPC 2.0.0.3+,
        which re-reads profiles.lua itself on each 'sellnpc <profile>'
        so edits still count without a reload.
      - After selling: '//tr drop' instead of 'lua r treasury'. Needs
        Treasury 1.2.0.5+, which re-reads data/drop.lua every time and
        drops everything on it.
      - New send_to_addon_or_load (nested inside sell_junk_to_moogle -
        the main chunk is at Lua's 200-local limit): waits up to
        addon_reply_wait_seconds (new config, 3) for the addon's
        reply line. No reply = not loaded, so it is loaded ONCE with
        'lua l' and stays loaded.
      - Help/log wording updated (sell no longer says "reload").
  v1.91.0 (2026-09-24) - Characters with furrow = false no longer show
      furrows READY (Mark: MuleLogger logged into Foodvf and looped
      trying to do furrows; Foodvf/Craftvf/Gearvf have no furrows and
      furrow = false in characters.lua).
      - Cause: //gh status on Foodvf ran sync_module_status_flags,
        which counted its never-seen furrows as "needs a live look" and
        saved furrow_next_ready_at = READY. MuleLogger read that as
        furrows ready to harvest.
      - The furrow ETA now skips every furrow when furrow = false
        (saves a blank ETA instead of READY).
      - New per-character switch sell (characters.lua modules): sell =
        false -> sell_junk_to_moogle does nothing (logs why), //gh sell
        answers SellResult: DISABLED, and a full inventory during a
        harvest skips that furrow instead of selling.
      - characters.lua documents the new MuleLogger switches too
        (set_roe, unity_chat, process_inv, send_mail, receive_mail,
        org_inv) - GardenHelper ignores those.
      - Goes with MuleLogger v1.61.0 / inv.lua v1.2.0.
  v1.92.0 (2026-09-24) - Fertilizer/bait for the Vein, Pond, Grove
      and Net (Mark), per character.
      - characters.lua: vein_fertilizer / pond_fertilizer /
        grove_fertilizer / net_fertilizer in defaults (everyone) or
        in a character's overrides entry. '' (or false in an
        override) = off. All off by default.
      - Used ONLY after that node is harvested for the current garden
        day, and at most once per garden day. Runs at the end of
        harvest_vein/pond/grove/net (//gh full, force, ML passes and
        //gh vein/pond/grove/net), including the "already harvested
        today - skipping" branch, so a fertilizer switched on after
        the harvest is used on the next pass. Never before a harvest.
      - How: walk to/target the node, '/item "<name>" <t>', then Enter
        one at a time (node_fertilize_max_enters, 3) until the item
        count drops or a node_fertilize_done_phrases line shows up,
        then Escape x2. "There is no need to..." = already fertilized
        -> recorded as done for today. No item in inventory -> log
        line, skipped. "Target out of range" uses the v1.76.0 walker.
      - New saved fields: <node>_fertilized_date / _fertilized_at /
        _fertilizer. //gh status adds ", fertilized with X" (used
        today) or ", X after harvest" (configured, not used yet).
      - Not in //gh duecheck: MuleLogger never schedules a visit just
        for fertilizer.
      - The helper lives on state (state.fertilize_node_after_harvest)
        - the main chunk is at Lua 5.1's 200-local limit.
  v1.92.1 (2026-09-24) - //gh status 'Mail in Inbox' fixed (Mark):
      config.inv_data_file still pointed at MuleLogger/inventory.lua,
      which MuleLogger v1.57.0 split into ItemTable.lua + Mail.lua, so
      the row could only say "unknown (... not readable)". Now reads
      MuleLogger/Mail.lua (same mail = {<name> = {stacks}} table).
```

## v2.1.0 (2026-09-25) - one item list (inv.lua v4.0.0)

```text
  GardenHelper v2.1.0 / inv.lua v4.0.0 (Mark: item handling was spread
  over SellNPC, Treasury and ItemTable.lua - too complicated).
  - ItemTable.lua items are now {name, type, action, mail_to, min_mail,
    min_save, store_bag}. action = "" (new, review) / save / send /
    ignore / sell / drop replaces age + process; mail_min renamed
    min_mail; new min_save (keep this many, all bags counted; 0 = keep
    all). Sorted by action then type, a big banner per action.
    Converted: mail_to set -> send (store_bag "bag_order" if blank;
    process = false -> ignore), no mail_to -> save, type Junk -> sell
    when on SellNPC's junk list, else "" to review. Revival Root = save,
    Seeds, min_save 72.
  - Imported SellNPC's junk profile (494 items, action sell) and
    Treasury's drop list (249 items, action drop) with item ids and a
    craft/use type. Items on both lists -> drop.
  - //gh sell: inv.lua decides what to sell and sells it with the shop
    packets (sell items + save extras above min_save with no mail_to,
    pulled from other bags first). Nothing to sell = no moogle walk.
  - New //gh drop (+ auto_drop: drop on landing, pass in the pool).
  - //gh inv = sell, drop, pop, send, rec, org. rec always takes
    everything and re-checks while the box is full.
  - org: blank store_bag = not moved; bag = gather from every bag;
    "bag_order" = from main inventory into bag_order.
  - New settings sell_dry_run / drop_dry_run / auto_drop (ItemTable.lua);
    config sell_shop_open_timeout_seconds, sell_item_delay_seconds,
    drop_item_delay_seconds, auto_drop_refresh_seconds;
    mail_receive_max_rounds 6 -> 12. SellNPC / Treasury config removed.
  Backups: backup/inv v3.1.0 2026-09-25.lua, backup/ItemTable before
  action 2026-09-25.lua, backup/GardenHelper v2.0.2 2026-09-25.lua,
  backup/README before action 2026-09-25.md.
```

## v2.1.1 (2026-09-25) - //gh inv rebuild (inv.lua v4.1.0)

```text
  - New //gh inv rebuild (Mark): rewrites ItemTable.lua from what is in
    it now - sorted by action, type, name, banners / type headers
    redrawn after hand edits. Lowercases action and store_bag, fills a
    missing name from the item id, adds missing fields, reports an
    unknown action (moved to the "" review section) or store_bag. No
    game steps; own comments not kept (backup/ItemTable.lua.bak).
  Backups: backup/inv v4.0.0 2026-09-25.lua, backup/GardenHelper v2.1.0
  2026-09-25.lua.
```

## v2.2.0 (2026-09-25) - //gh sell at any NPC vendor (inv.lua v4.2.0)

```text
  - //gh sell outside the Mog Garden works like SellNPC did (Mark): preps
    the items (pulls "save" extras out of other bags), logs "SellResult:
    READY", and sells as soon as any NPC vendor's shop opens (0x03C) -
    then drops action "drop" items and logs "SellResult: DONE / FAILED".
    Waits until a shop opens (zoning doesn't clear it); //gh sell cancel
    calls it off. In the Mog Garden it still walks to the Green Thumb
    Moogle (a waiting vendor sale is folded into that one).
  - Fixed a hand-edit typo in ItemTable.lua line 373 (Translucent Rock:
    type = "Gold action = ...) that stopped //gh inv rebuild.
  Backups: backup/inv v4.1.0 2026-09-25.lua, backup/GardenHelper v2.1.1
  2026-09-25.lua, backup/ItemTable before line373 fix 2026-09-25.lua.
```

## v2.3.0 (2026-09-26) - public release text (inv.lua v4.3.0)
- Comments, help and messages made generic for the public release (MuleLogger / SellNPC /
  Treasury / character names removed; result lines unchanged). A NEW ItemTable.lua starts
  with auto_drop = false (an existing file keeps its setting). Release zip:
  release/GardenHelper-v2.3.0.zip. Live README replaced by the public one (+ RoE section).
  Backups: backup/GardenHelper v2.2.1 2026-09-26.lua, backup/inv v4.2.0 2026-09-26.lua,
  backup/README before roe 2026-09-26.md.

## v2.4.0 (2026-09-26) - RoE + Unity chat built in (Set_RoE.lua v1.0.0)
- Mark: RoE setting and Unity chatting inside GH without the RoE addon, logic in its own
  file Set_RoE.lua, the objective list in characters.lua.
- characters.lua defaults: roe_objectives = {3000, 3009, 3018, 3027, 3036, 3045} (Unity
  Communique A-F - there is no G; LandSandBoat's list ends at F), unity_chat_message = '.'.
  Overrides per character work too; modules set_roe / unity_chat = false turn a step off.
- Objectives: once per garden day, every listed id not already active is accepted with the
  RoE packets (out 0x10C; active list from in 0x111, completed flags from 0x112). Not enough
  of the 30 slots -> 0-progress objectives outside the list are cancelled (0x10D,
  roe_clear_zero_progress). The server refuses what isn't available (other weeks' UC) -
  logged as "not accepted".
- Unity chat: after the objectives, /u <message>, max 1 per 10 min per character
  (unity_chat_min_interval_seconds 600), only while a Unity Communique is active
  (unity_chat_only_for_communique).
- //gh roe [force|set|chat|list|status|help|auto]; auto -> "RoEResult: DONE roe=<r>
  chat=<c> chat_at=<epoch>". Runs at the end of //gh full (roe_in_full, before
  inventory_after_full). //gh status row "RoE / Unity". Saved per character:
  roe_last_set_at/_epoch, unity_chat_last_at/_epoch.
- MuleLogger v2.5.0 calls //gh roe auto after each pass instead of //roe set + its own chat.
- Checked: luac -p; Set_RoE.lua run in a stubbed Windower (set, refused id, already-today,
  chat limit, list/status/help). Backup: backup/characters before roe 2026-09-26.lua.

## v2.4.1 (2026-09-26) - Unity chat limit in characters.lua (Set_RoE.lua v1.1.0)
- Mark: the "Unity chat at most every 10 minutes" setting moved to characters.lua, next to
  roe_objectives / unity_chat_message: `unity_chat_min_interval_seconds = 600` (defaults,
  or per character in overrides; 600 if missing, never below 60). Removed from Set_RoE.lua's
  config defaults. MuleLogger v2.5.1 reads the same value for its Tier 5 timing.
- Backups: backup/Set_RoE v1.0.0 2026-09-26.lua, backup/GardenHelper v2.4.0 2026-09-26.lua,
  backup/characters before unity interval 2026-09-26.lua.

## v2.4.2 (2026-09-26) - Multi-harvest seeds (arborfruit) in the furrow inspect exit
- Mark's log: inspecting a growing arborfruit furrow gives a 3rd line after the grow time -
  "You also conclude that the seed you planted should sprout about N more times." - so the
  old exit (Enter, Down, Down, Enter) was one Enter short. Real sequence: Enter (rank line),
  Enter (grow time), Enter (sprout line), Enter (opens "What will you do?" with "Inspect the
  garden." highlighted), Right to "Absolutely nothing.", Enter.
- New run_exit_sequence(): for growing_unfertilized / growing_fertilized the first exit Enter
  is read; if it shows "should sprout about" -> Enter, Right, Enter (Right waits
  config.sprout_menu_settle_seconds 1.0 for the menu); otherwise Down, Down, Enter as before.
  Used by live probes (//gh furrowinspect, rank/status probes) and the live detect in
  //gh furrow / full. Debug line logs the sprouts left.
- //gh furrowinspect preset "sprouting" = e,e,e,e,right,e.
- Checked: luac -p; stubbed run of the exit (sprout / normal / empty key orders).
- Not yet seen: the harvest text of a ready multi-harvest furrow (the plant stays after a
  harvest - a follow-up plant would be refused and the state corrected from the refusal).
- Backup: backup/GardenHelper v2.4.1 2026-09-26.lua.

## v2.5.0 (2026-09-26) - Memory check on all loaded addons (memcheck.lua)
- Mark: find which addon's memory keeps growing over long //ml smart runs. Before logging out
  each cycle, tell chat it is running a memory check on all loaded addons, list them by memory
  used (most on top) with a % vs. the oldest report, and keep the full history in memory.lua
  (a gap between runs). //gh memory / reset / on / off; an easy true/false to turn it off.
- New module memcheck.lua: sends "lua memory" (Windower LuaCore: "Addon memory usage:" then
  "  <name>  Memory: 1234.56 KB    Stack: N" per addon), catches and hides those lines (up to
  6s, done after 1s quiet), converts B/KB/MB/GB to KB, sorts, prints, appends to memory.lua.
- % = this run vs. the addon's first value in memory.lua (oldest run, or the first run it
  appears in if it was loaded later - shown as "base" then). Total line too.
- memory.lua: every line is a Lua comment ("-- ===== Run N | time | character | label |
  N addons | total X KB (%) =====", then "--   1 | Name | 1234.5 KB | +12.3%"), blank line
  between runs. //gh memory reset rewrites it with the header only.
- config.memory_check_in_full (true) = run it as the last step of //gh full (after RoE and
  inventory_after_full, before "Full Mog Garden pass complete", so a script waiting for that
  line logs out after it). //gh memory on|off saves data/memory_check.lua {enabled = ...},
  which wins over the config value. //gh memory status. Allowed during a run; no garden needed.
- Backup: backup/GardenHelper v2.4.2 2026-09-26.lua (+ README, CHANGELOG).

## v2.5.1 (2026-09-26) - pol.exe (whole game) line in the memory check
- Mark: //lua memory only covers Lua addons - add the game's total so plugins (.dll) and
  addon overlays (texts/images live in Windower, not in the addon's Lua memory) are covered.
- memcheck.lua writes memcheck_pol.vbs (rewritten only if its text changed) and starts it with
  windower.open_url (Windows "open" -> wscript.exe, no console window) before //lua memory.
  The script asks WMI for every pol.exe (PrivatePageCount, WorkingSetSize, VirtualSize),
  marks the one that is its own parent process ("self" = this game), writes
  data/pol_memory.txt via a .tmp + rename. Read for up to memory_check_game_wait_seconds (10).
- Chat: "pol.exe (whole game): X MB private, Y MB in RAM - +Z% private vs. the oldest run".
  memory.lua: "-- pol.exe (whole game: ...) | private X MB | working set Y MB | virtual V MB | %"
  right under each run header; % base = first pol.exe line in the file. Several pol.exe and
  none marked self -> largest, noted. No answer -> "not read - ..." line, addons still reported.
- config.memory_check_game_total (true; false = addons only), memory_check_game_wait_seconds.
- The check is no longer wrapped in pcall (Lua 5.1 can't sleep inside pcall); a stuck
  "already running" flag clears after 60s.
- Checked: luac -p; stubbed runs (self / two pol.exe / no answer / WMI error / switched off).
- Backup: backup/GardenHelper v2.5.0 2026-09-26.lua.

## v2.5.2 (2026-09-26) - Growth amount + % on every memory report row
- Mark: each report must show the amount of growth and the % growth for every item, including
  pol.exe and total Lua.
- memcheck.lua: rows = Total Lua (N addons), pol.exe (whole game, private MB), then the addons
  (numbered, most memory first). Each row: Memory | Growth (+X KB / +X MB) | Growth % vs. the
  same row in the oldest run in memory.lua ("base" on the first run / first appearance).
- memory.lua per run: "-- ===== Run N | time | char | label | N addons | total X KB =====",
  a "#, Name, Memory, Growth, Growth %" header row, the rows, then a pol.exe detail line
  (private, in RAM, virtual) or why it wasn't read; blank line between runs.
- Checked: luac -p; stubbed runs (baseline, growth, two pol.exe, no answer, WMI error, off).
- Backup: backup/GardenHelper v2.5.1 2026-09-26.lua.

## v2.6.0 (2026-09-26) - Multi-harvest seeds when READY (harvest keys, no replant, harvests left)
- Mark's log (arborfruit, ready, 1st harvest): Enter "rank 4 ... has an arborfruit seed planted,
  but is devoid of fertilizer.", Enter "Your arborfruit seed has matured!", Enter "You also
  conclude that the seed you planted should sprout about 2 more times.", Enter opens "What will
  you do?" ("Harvest crop." highlighted), Enter "Harvest this crop?" (Yes), Enter -> Obtained
  lines (crystals, walnut, date, 3 arborfruit seeds). N = harvests left INCLUDING the one being
  harvested: 2 -> 1 more after this one.
- run_key_sequence: new step option {key, if_text = 'phrase'} - pressed only if a line captured
  so far in the sequence has the phrase (logged as skipped otherwise).
- harvest_furrow: {'enter', if_text = 'should sprout about'} after the 3rd Enter (not in menu:
  e,e,e,[e],e,confirm,escape; after the detect: e,[e],e,confirm,escape). Normal seeds unchanged.
- New furrow_after_harvest(furrow, lines) used by //gh furrow / full / furrowloop (recorded-ready
  and live-detect paths) and //gh furrowharvest: no sprout line -> empty (plant as before);
  N = 1 -> last harvest, empty, plant; N > 1 or N not read -> no planting or fertilizing, live
  inspect (live_probe_furrow) records the regrow time ("in about Xh Ym") and harvests left; if the
  inspect fails it's recorded growing with the flat harvest_time estimate + N - 1 left.
- New saved field furrow_N_harvests_left (from any sprout line; 0 on empty / fertilized_empty).
  Shown in //gh status ("H@ ..., 1 harvest left (rank 4)") and the growing furrow lines.
- run_exit_sequence also handles 'ready': sprout line -> Enter (menu), Down, Enter (the Down is a
  guess - same as a normal ready furrow; not seen live). New //gh furrowinspect preset
  "sprouting_ready" = e,e,e,e,down,e.
- config.multi_harvest_fertilize (false): a growing furrow with harvests_left > 0 isn't
  fertilized by //gh furrow / full and doesn't count as due for fertilizer in the due check.
- Live detect of a growing furrow now records after the exit, so the sprout line is saved.
- furrow_cycle: act can return a 6th value (recorded = true) to skip the default record.
- Checked: luac -p; stubbed runs of the key orders (multi not-in-menu = 6 Enters + Escape, normal
  = 5 + Escape, multi after detect, last harvest -> empty, regrow -> growing + 1 left, exits).
- Backup: backup/GardenHelper v2.5.2 2026-09-26.lua (+ README, CHANGELOG v2.5.2).

## v2.6.1 (2026-09-26) - Vein double check before picking the highest rank
- Mark: a vein like #4 was sometimes found, "Walking to 4a" started, then on arrival only #2
  existed and #2 was harvested. Veins should be double-checked (target, then check it still
  exists 1s later) before deciding the highest rank and walking over.
- New ranked_candidate_confirmed(prefix, v): get_mob_by_id + valid_target + settarget/name check,
  wait config.ranked_double_check_seconds (1), then still loaded, valid_target and still the
  current target (one re-target allowed). Fails -> "showed up but was gone 1s later - not walking
  to it", target cleared, next variant / rank down. find_highest_ranked uses it (so harvest and
  the after-harvest fertilizer both get it).
- config.ranked_double_check = {vein = true, grove = false}.
- Checked: luac -p.
- Backup: backup/GardenHelper v2.6.0 2026-09-26.lua (+ CHANGELOG v2.6.0).

## v2.7.0 (2026-09-26) - Double check on the way, for every garden object
- Mark: use the vein double check for the rest of the garden objects, and do it on the way
  (adjust the target while walking once it's sure what's up) instead of stalling first.
- New walk_confirmed(kind, key, id, name, label): object must be loaded (get_mob_by_id,
  valid_target) and targetable to start; walk_to_xy's stop_check re-checks it every
  config.double_check_seconds (1) while walking - gone = the walk stops there, "<label>
  disappeared on the way (stopped walking) - not using it.", target cleared; on arrival it is
  checked once more, no sooner than 1s after the first check (short/no walk = waits the rest).
  Returns true / false + 'missing' | 'gone'.
- Vein/Grove: find_highest_ranked targets each variant (no wait), walks with the check; a variant
  that vanishes on the way moves on to the other variant / next rank down from where you stopped.
  Replaces v2.6.1's 1s wait before walking.
- Pond/Net (harvest + fertilizer), Flotsam (not there / vanished = UNKNOWN), Ephemeral Moogle
  (crystals.lua passes 'crystals'), furrows (approach_furrow, X/Y mode) all use it.
  Books' Mog Dinghy / Skipper Moogle don't (outside the garden / already have their own wait).
- position_at_node(key, id, name, label, kind): kind = module key for the check.
  navigate_to_entity(..., walk_opts) passes walk options to walk_to_xy.
- config.double_check_before_walk = {vein, grove, pond, net, flotsam, crystals, furrow = true}
  and double_check_seconds = 1 replace ranked_double_check / ranked_double_check_seconds.
- Checked: luac -p (GardenHelper.lua, crystals.lua).
- Backup: backup/GardenHelper v2.6.1 2026-09-26.lua, crystals before walk check 2026-09-26.lua,
  CHANGELOG v2.6.1 2026-09-26.md.

## v2.7.1 (2026-09-26) - Memory check: memory.lua never written
- Mark: no memory.lua with the history. Logs (Fishvf 12:10:04, Seedsvf 12:04:55): "Running memory
  check..." then 6s later "[ERROR] No reply from //lua memory - memory check skipped." - and the
  skip also skipped writing the file. pol.exe query worked (data/pol_memory.txt: ~739 MB private).
- Cause: windower.send_command('lua memory') from an addon prints LuaCore's list outside chat
  (nothing reached 'incoming text' - Logger didn't log it either).
- memcheck.lua: tries 'lua memory', then 'input //lua memory' (typed into the chat line like you
  would, which prints to chat); each waits up to 4s for the first line.
- memory.lua is created (header) when GardenHelper loads; every run is appended even without the
  addon list (header "no addon list (//lua memory gave no answer)", pol.exe row still there).
  History parse: run numbers no longer need a total in the header.
- Checked: luac -p; stubbed runs (neither way answers / only input answers / first answers).
- Backup: backup/GardenHelper v2.7.0 2026-09-26.lua.

## v2.7.2 (2026-09-26) - Memory report file renamed to memory_report.lua
- Mark: rename the report file to memory_report.lua, holding only the memory check reports.
- memcheck.lua: REPORT_FILE = memory_report.lua (created on load; //gh memory, reset, status and
  all messages use the new name). A memory.lua whose first line is the report header is renamed
  to memory_report.lua once, if memory_report.lua doesn't exist yet. Report format unchanged.
- Backup: backup/GardenHelper v2.7.1 2026-09-26.lua.

## v2.7.3 (2026-09-26) - Memory check: addon numbers from console.log / probes
- Mark confirmed //lua memory prints only in the Windower console (not chat), so GardenHelper never
  saw it. Mark turned on the console log: Windower\console.log now gets the list live
  ("12:26:16 >   TradeNPC        Memory:   18.44 MB    Stack: 0").
- memcheck.lua: notes console.log's size, sends "lua memory", reads only what is appended after
  that ("Addon memory usage:" and the lines after it), waits up to 4s for the first line.
- Fallback when console.log gives nothing: writes memprobe.lua and sends
  lua invoke "<folder>" dofile "<GardenHelper>/memprobe.lua" for every addons\ folder (not libs).
  memprobe.lua runs inside that addon and sends "gh memprobe <collectgarbage('count')> <_addon.name>";
  not-loaded folders only print an error in the console. //gh memprobe (exempt from the garden
  check) collects the answers. Same number LuaCore shows.
- Removed the chat capture of "lua memory" and the "input //lua memory" retry (never worked).
- Checked: luac -p; stubbed runs (console.log with old content, probes, neither).
- Backup: backup/GardenHelper v2.7.2 2026-09-26.lua.

## v2.8.0 (2026-09-26) - //gh full reordered: Books first, inv before RoE, memory last
- Mark: XY walking to the Pond, Ephemeral Moogle, garden Mog Dinghy and Coastal Fishing Net
  stopped short and ran into invisible walls for a second or two. New standing spots from
  GenPopVF's log (//gh pos, 13:11-13:12) in entities.lua:
  Pond 1.449, 9.333 · Ephemeral Moogle -20.475, -18.842 · Mog Dinghy -16.498, -19.297 ·
  Coastal Fishing Net 17.317, -26.318.
- Mark: new //gh full order - Books, Furrow, Vein, Pond, Grove, Crystals, Flotsam, Net, inv,
  then RoE, then memory check. sell_level stays 2 (sell after Pond).
- Books moved to the start (the trip sails to the Port zone and back before anything is
  harvested). If the trip doesn't end back in the Mog Garden the pass stops with an error.
- inventory_after_full now defaults to true. Its sell step is the end-of-pass sell, so there is
  no separate sell after Net while it's on (with it off, the old plain sell after Net still runs).
- Last line is "Full Mog Garden pass complete (inventory done)." when inv ran in the pass;
  MuleLogger v2.6.1 skips its own //gh inv auto on that line.
- Backup: backup/GardenHelper v2.7.3 2026-09-26.lua, entities before new xy 2026-09-26.lua,
  CHANGELOG v2.7.3 2026-09-26.md, README v2.7.3 2026-09-26.md.

## v2.8.3 (2026-09-26) - Faster Delivery Box receive (inv.lua v4.4.0)
- Mark: rec waited as if a full inbox (8 items) were loading, even with 0 or 3 items waiting.
- New config.mail_open_quiet_seconds (1). See CHANGELOG-inv.md v4.4.0.
- Backup: backup/GardenHelper v2.8.2 2026-09-26.lua, README v2.8.2 2026-09-26.md,
  CHANGELOG v2.8.2 2026-09-26.md.

## v2.8.4 (2026-09-26) - Furrows: inspect before harvesting when recorded data says ready
- Mark: SeedsVF 15:27 - Garden Furrow (arborfruit) was harvested by hand at 11:42 (furrows were
  disabled for the 11:57 run), so its record still said "growing, ready 9:05am". The pass
  treated it as ready and pressed the whole harvest sequence blind; the text ("in about 2 hours
  and 17 minutes") was only looked at afterwards.
- harvest_furrow() without an open menu now runs DETECT_SEQUENCE (Enter, Enter) first and
  classifies the text. Ready -> continues with the same keys as the live-detect path (same total
  key count as before). Anything else -> matching exit sequence, records the real state and
  harvest time, logs it, returns false. Unclassifiable -> error, no keys pressed further.
- Affects the "recorded status says ready" path in //gh full / furrow / furrowloop and
  //gh furrowharvest. Found empty instead -> //gh full / furrow / furrowloop plant it.
- Backup: backup/GardenHelper v2.8.3 2026-09-26.lua, CHANGELOG v2.8.3 2026-09-26.md.

## v2.9.0 (2026-09-26) - Garden assistants (Kuyin, Susuroon, Yeestog)
- Mark: track which node and task each garden assistant is on, set per assistant in
  characters.lua (defaults + per-character overrides), and only talk to one when it isn't on
  the node/task its setting says. Menus and standing spots captured on Shadowhammer
  (2026-09-26 17:43-18:17).
- New assistants.lua module. Each assistant has a different entity id per node, and only the
  one for its current node is loaded - so the node is read without talking (neither id =
  "not in this Mog Garden", logged, looked for again next time). The task is never shown by
  the game, so the task GardenHelper last set is saved in data/settings.xml
  (assistant_<name>_node / _task / _set_at / _checked_at).
- "Preparing to harvest <node>, checking on assistant settings..." right before a furrow
  (only when a furrow may be harvested: forced, recorded ready, or no data), vein, pond, grove
  or net harvest - only for assistants set to THAT node. Nodes already done today, or turned
  off in modules, are not checked. Data matches -> no change. Otherwise: walk to where the
  assistant is now, Enter (greeting), Enter (what they're doing), Enter (node menu), Down x
  node, Enter, Down x task, Enter, wait for their "got it" line, Enter, wait out the black
  screen, confirm they reappeared on the new node (by id), then record it.
- characters.lua: defaults.assistants with a guide per assistant listing only the nodes/tasks
  it can take and what each task does. Defaults: kuyin furrow/seeds, susuroon net/catch,
  yeestog grove/easier. Overrides: leave an assistant out (or '') = defaults; false = never
  touch it on that character; changing the node needs the task too. Bad settings are an error
  line and that assistant is skipped.
- New command //gh assistants [force|status|list|done|reset|help] [kuyin|susuroon|yeestog].
  //gh status has a row per assistant (saved node/task, and the setting when it differs).
- entities.lua: six standing spots (Kuyin Furrow/Pond, Susuroon Furrow/Net, Yeestog
  Grove/Vein); the unused 'Yeestog' entry was replaced by 'Yeestog Grove'.
- New config: assistant_text_wait_seconds (8), assistant_menu_settle_seconds (1.0),
  assistant_down_settle_seconds (0.5), assistant_move_wait_seconds (12),
  assistant_after_move_seconds (1.0).
- Not seen yet: Yeestog's "got it" line - any line from him after the task Enter counts, and
  GardenHelper prints it ("Yeestog said: ...") so it can be added.
- Backup: backup/GardenHelper v2.8.4 2026-09-26.lua, characters v2.8.4 2026-09-26.lua,
  entities v2.8.4 2026-09-26.lua, CHANGELOG v2.8.4 2026-09-26.md, README v2.8.4 2026-09-26.md.

## v2.9.1 (2026-09-26) - Assistants: full-run check, single-node check, Yeestog line; characters.lua re-read
- Mark: Yeestog's "got it" line is "Ain't no day wit'out a gud day's woik, eh? Best way t' pass da
  time, it bee!" - now checked for ("gud day's woik") like Kuyin's and Susuroon's.
- Mark: every full garden run checks and sets up ALL assistants. //gh full / force / full inspect
  start with "Preparing the garden run, checking on assistant settings..." (right after the books
  trip, before the furrows) - all matching = no action. The node steps in that run don't check
  again.
- Mark: a single node command checks the assistants set to that node, even when the node is
  already done today: //gh vein / pond / grove / net, //gh furrow (furrowfull), furrowloop (each
  cycle), furrowharvest, furrow inspect. Each node is checked at most once per command
  (ASSIST.begin_run / state.assist_checked).
- characters.lua is re-read at the start of every //gh command (and on login) when its text has
  changed - no //lua r needed ("characters.lua changed - re-read."). A file with an error is
  reported once and the last good copy stays in use. The table keeps its identity (Set_RoE.lua
  holds a reference). Fields removed from defaults go back to the built-in fallbacks; the
  furrowconfig runtime values that come from it (seed, fertilizer, ...) reset to the file's
  values on a change.
- Backup: backup/GardenHelper v2.9.0 2026-09-26.lua, assistants v2.9.0 2026-09-26.lua,
  characters v2.9.0 2026-09-26.lua, CHANGELOG v2.9.0 2026-09-26.md (README v2.9.0 2026-09-26.md
  already has the v2.9.1 README edits - use README v2.8.4 plus the v2.9.0 section if needed).

## v2.9.2 (2026-09-26) - Assistants: slower, safer menu timing
- Mark: first //gh full on Shadowhammer (19:33) - Kuyin went to furrow but ended on "Harvest a lot
  of crops." instead of "Look for seeds.". The greeting and her pond line came in the same second;
  the Enter that should open the node menu was pressed while her line was still being written, so
  it only finished the line and every later key landed one menu early. No "got it" line came, and
  the "one more Enter" nudge 6s later picked the highlighted "Harvest a lot of crops.".
- After each of their lines (greeting, what they're doing, "got it") GardenHelper now waits
  assistant_line_settle_seconds (1.5) before the next Enter. Node menu settle 1.0 -> 1.5
  (assistant_menu_settle_seconds), new assistant_submenu_settle_seconds (2.0) after choosing the
  node, Down settle 0.5 -> 0.7.
- The blind Enter nudge while waiting for the black screen is gone. No "got it" line = Escape x3
  (backs out of any open menu) and the task stays unknown, so the next check sets it again.
- Backup: backup/assistants v2.9.1 2026-09-26.lua, GardenHelper v2.9.1 2026-09-26.lua,
  CHANGELOG v2.9.1 2026-09-26.md.

## v2.9.3 (2026-09-27) - Memory check on/off: one setting
- Mark: memory_check_in_full = false in GardenHelper.lua, but //ml smart still ran the memory check
  at the end of every character's //gh full - data/memory_check.lua (from an earlier //gh memory on)
  said enabled = true and silently won.
- The memory_check_in_full config line is commented out, with a note pointing to
  data/memory_check.lua. That file (return {enabled = true/false}, written by //gh memory on|off) is
  now the only on/off; missing = off, and it is created (off) on load so it can be found. README
  config table row removed, command line updated.
- Backup: backup/GardenHelper v2.9.2 2026-09-27.lua, memcheck v2.9.2 2026-09-27.lua,
  CHANGELOG v2.9.2 2026-09-27.md, README v2.9.2 2026-09-27.md.

## v2.10.0 (2026-09-27) - Furrows stay on the same timing
- Mark: furrow 3 kept getting processed wrong and harvested/planted a login later, so the three
  furrows drifted apart. Logs (Sep 25-27, all characters) showed three causes:
  - **Ready furrow read as growing** (Leathervf 9/26 17:02, Woodvf 9/27 12:30 - #2): the rank line
    came, then a repeat of it (the client re-fires lines with a `[HH:MM:SS]` stamp) or a Unity chat
    line ended the wait for the 2nd Enter before "has matured!" arrived. The growing exit keys
    (Enter, Down, Down, Enter) then left #2's harvest prompt open, #3's first Enter harvested #2
    ("Obtained" under #3), and #3 was never touched ("could not be classified"). #2 was recorded as
    growing while empty; #3 waited for the next login.
  - **No reply at all** (Genpopvf 9/26 19:52, Fishvfi 9/27 11:20 - #3; Leathervf 9/27 10:05 - #2;
    Cookvf 9/27 07:08 - #1 right after login): the inspect keys got nothing for 7s.
  - **After an inventory-full sell** (Cookvf 9/27 03:36 - #3, Goldvf 9/26 21:11 - #2): the first
    Enter handed over the rest of the crop with no rank line -> "could not be classified", so the
    furrow wasn't replanted until later.
- run_key_sequence: a repeated line (same text once the stamp and colour codes are stripped) no
  longer counts as a reply. Player chat (Unity `{Name}`, linkshell `<Name>`, party `(Name)`,
  tells) is never captured.
- Furrow inspect (FURROW_SYNC.detect, used by the harvest check, the live detect in full/furrow and
  //gh furrow inspect): a planted furrow needs its second line (has matured / agrarian experience /
  sprout line). Rank line only -> listen `furrow_detect_second_line_wait` (2.5s) more, then one more
  Enter; still missing -> unknown (never guessed as growing). No text at all -> target again and
  retry (`furrow_detect_no_text_retries` 1, `furrow_detect_retry_wait` 2s).
- harvest_furrow: on the re-try after an inventory-full sell, "Obtained:" on the first Enter = harvest
  done (inventory full again = not done).
- run_single_furrow_pass: a furrow still ready / unknown (or empty with seeds in inventory) after its
  turn gets one more try right away (`furrow_retry_missed`).
- Furrow ETA (`furrow_next_ready_at/_epoch`, what MuleLogger reads) = when the LAST unlocked furrow is
  ready (was the soonest). Empty / no data = READY as before. Furrows more than `harvest_time` apart
  (e.g. a 48h seed next to a 1h one) fall back to the soonest.
- `furrow_sync_hold` (true): in a normal //gh full / furrow pass, a ready furrow waits while another
  furrow is still growing (group in sync), so they are harvested and replanted together. force and
  single-furrow commands ignore it.
- The v2.10.0 helpers live in one table (FURROW_SYNC) - the main chunk is at Lua's 200-local limit.
- Backup: backup/GardenHelper v2.9.3 2026-09-27.lua, CHANGELOG v2.9.3 2026-09-27.md,
  README v2.9.3 2026-09-27.md.

## v2.10.1 (2026-09-27) - Late-opening Delivery Box closed (inv.lua v4.4.2)
- Mark: MuleLogger logged into the wrong character during `//ml rec`. Woodvf 9/26 18:25 and 9/27 15:38: rec gave up
  after 5s ("the Delivery Box (receive) did not open"), the box opened a moment later and stayed open, the game refused
  MuleLogger's `/logout` ("You cannot use that command while checking your delivery box.") and its character-select keys
  went into the box.
- New `mail_open_timeout_seconds` (10): max wait for the box to open. A failed open now sends Close anyway.
- Pairs with MuleLogger v2.8.1 (waits for a real logout before any key).
- Backup: backup/GardenHelper v2.10.0 2026-09-27.lua, inv v4.4.1 2026-09-27.lua, CHANGELOG v2.10.0 2026-09-27.md,
  README v2.10.0 2026-09-27.md.

## v2.11.0 (2026-09-27) - Assistant contracts (employment.lua)

- New `employment.lua`: `//gh emp` / `//gh employment [force|notify|status|reset|help]`, and the
  first step of every full run (before the assistant check).
- Recruits an assistant whose unlock item is in any bag (Kuyin Dragoneye, Susuroon Rusted Coin,
  Yeestog Fat Burrow Worm): pulled into inventory, traded to the Green Thumb Moogle, scene pressed
  through (Enter after each line; a menu's top option), then hired right away for `rehire_weeks`.
- Spare unlock items for recruited assistants are traded for +7 free days.
- The daily "There are N days left on X's contract." / "X's contract has expired." lines are read
  from chat whenever they show. None today = contract notices set to "Always notify me" (at most
  every `employment_notify_retry_days`).
- Contracts under `employment_extend_below_days` (7), or never read, are checked at the moogle and
  extended by `rehire_weeks` (characters.lua, per assistant; default 9) after a gil check. The
  assistant's name in the moogle's reply is checked against the one picked.
- Data in settings.xml (`employ_...`), history in `data/employment_history.log`, rows in
  `//gh status`, employment work in `//gh duecheck`. assistants.lua gets `present(key)`.
- Pairs with MuleLogger v2.9.0 (`|A1 y|` column).
- Backup: backup/GardenHelper v2.10.1 2026-09-27.lua, assistants v2.10.1 2026-09-27.lua,
  characters v2.10.1 2026-09-27.lua, CHANGELOG v2.10.1 2026-09-27.md, README v2.10.1 2026-09-27.md.

## v2.11.1 (2026-09-27) - Weeks box timing

- The weeks digit never showed (Genpopvf 18:09): longer wait for the box
  (`employment_number_box_settle_seconds` 2.5), digit held longer (`employment_digit_hold_seconds`
  0.25), pause before Enter (`employment_after_digit_seconds` 1.5). `employment_weeks_input = 'up'`
  = press Up once per week instead of typing.
- `employment_notify_nav` default is now `'bottom'` (Right Right Up).

## v2.12.0 (2026-09-27) - Assistant hires by packet

- The weeks box never took setkey digits or Up, and it is client-side. Captures (`//gh emp capture`,
  Genpopvf 19:28-19:34) show the hire is one menu choice: `weeks * 256 + 28 + n` (n: Kuyin 0,
  Susuroon 1, Yeestog 2 - Yeestog's not captured yet), after 27 and before 1, 11, 11 (last one ends
  the talk). GardenHelper now talks to the moogle with its menu window held back, sends those
  choices, and checks the new contract seconds the server returns and the gil paid.
- Every talk to the Green Thumb Moogle (menu 1016, sells too) updates all contract days from the
  exact seconds in the menu data.
- Removed the weeks-box key settings; new `employment_menu_id` (1016), `employment_packet_wait_seconds` (5).
- Backup: backup/GardenHelper v2.11.1 2026-09-27.lua, employment v2.11.1 2026-09-27.lua.

## v2.12.1 (2026-09-27) - Hire with the menu open

- Cookvf 20:42: blocking the moogle's menu (0x034) got no server answer to the hire choices and left
  the talk open, so the following Dragoneye pull from the safe failed. The talk now opens normally
  (scenes first), the choices are sent with the menu on screen, and Escape closes it if needed.
- Every hire's packets are logged to `data/employment_packets.log`; the error names the step.
- Item pulls/trades wait for an open talk to end first.
- Backup: backup/employment v2.12.0 2026-09-27.lua (v2.12.1 copy also in backup/).

## v2.13.0 (2026-09-27) - Contract extensions by hand, with help

- Nothing GardenHelper can send reaches the weeks box (setkey digits, Up, Windower typed text -> /say,
  injected menu packets -> ignored by the server, Cookvf 21:03). Automatic hires removed, including
  the first hire after recruiting; `//gh emp test` and the packet-hire settings removed.
- `//gh emp extend [days=30] [auto]`: for each recruited assistant under that many days, menus up to
  the empty weeks box, chat prompt "TYPE THE WEEKS (9) AND PRESS ENTER NOW", then "Is this
  sufficient?" Yes and the new contract is recorded. Empty box / 0 = skipped.
  `auto` ends with `ExtendResult: DONE|NONE|FAILED` (MuleLogger `//ml extend`).
- The full-run step only flags contracts at `employment_extend_below_days` (7) or fewer days
  (`employ_extend_due`, a `//gh status` row, MuleLogger `A x`). New `employment_manual_wait_seconds` (300).
- Backup: backup/employment v2.12.1-hotfix 2026-09-27.lua.
- Extension flag (`employ_extend_due`, MuleLogger `A x`) and the `//gh emp extend` default now use
  `employment_extend_below_days` = 30 (under 30 days), the same cutoff as `//ml extend`.

## v2.14.0 (2026-09-27) - "Target out of range." -> walk closer, try again (everywhere)

- Fishvf 22:04: the Green Thumb Moogle refused three Enters at 4.5 yalms (the X/Y walk stops anywhere
  inside `interact_distance`, 5.5) and employment gave up ("did not open its menu after 3 tries").
- Nodes, furrows, flotsam, fertilizer `/item` and the sell talk already walked closer; now everything
  else does too, through the new shared `GH.range_retry`: employment's moogle talk and item trades,
  the assistant talks, the Ephemeral Moogle crystal trades, and the Mog Dinghy / Skipper Moogle (books).
- Each refusal walks to 3.0 yalms, then 1.5, then gives up (`out_of_range_walk_distances`,
  `out_of_range_max_retries`). Every "Target out of range." line is counted whether or not text is
  being captured (`state.out_of_range_count`).
- Backup: backup/GardenHelper, employment, assistants, crystals, books v2.13.1 2026-09-27.lua.

## v2.15.0 (2026-09-27) - //gh gil

- `//gh gil <name> <amount>` (inv.lua v4.5.0), for MuleLogger's `//ml cash`: mails gil through the
  Delivery Box to a character on the same account. Amount as `1000000`, `1m` or `500k`. Ends with
  `GilResult: SENT / FAILED / BUSY` (BUSY = GardenHelper was running something else).
- Backup: backup/GardenHelper v2.14.0 2026-09-27.lua, CHANGELOG / README v2.14.0, inv v4.4.2.

## v2.15.1 (2026-09-28) - Walker waypoints (Ephemeral Moogle)

- A character got stuck on a wall near the grove walking to the Ephemeral Moogle.
- entities.lua entries can now list `via = {{x = ..., y = ...}, ...}`: waypoints walked first, in order
  (navigate_to_entity), each skipped when you're already closer to the destination than it is. A waypoint
  that can't be reached just logs (debug) and the walk carries on.
- `Ephem` gets one waypoint at X -11.275, Y -13.051 (`//gh pos`, Bonevf).
- Backup: backup/GardenHelper, entities, CHANGELOG v2.15.0 2026-09-28.

## v2.16.0 (2026-09-28) - //gh mailitem

- `//gh mailitem <item> <name>:<count> ...` (inv.lua v4.6.0), for MuleLogger's `//ml humus`: mails exact
  amounts of one item to several characters in one Delivery Box visit, in the order given - every stack for
  the first name, then the next - until the list is done or the outbox is full (the last name can get only
  part of its amount). Ends with `MailItemResult: DONE / FULL / FAILED / BUSY sent=name:count,... free=N`.
- Backup: backup/GardenHelper v2.15.1 2026-09-28.lua, CHANGELOG / README v2.15.1, inv v4.5.0.

## v2.17.0 (2026-09-30) - missing seeds

- Seed not in main inventory when planting: it is taken out of the other bags (inv.lua v4.7.0 `pull_item`),
  enough for every furrow. Same for furrow fertilizer.
- Seed in no bag at all: **SEED ERROR** saved per character (`furrow_seed_error`, `furrow_seed_error_at` in
  data/settings.xml). While it is set, `//gh full` skips the furrows, duecheck / the furrow ETA don't count them
  (so MuleLogger won't log in for them) and `//gh status` shows it.
- Cleared by `//ml furrow recheck` (MuleLogger v2.20.0 - clears every character's error and logs into each for a
  pass), `//gh furrow recheck` on the character, or a manual `//gh furrow` that plants successfully.
- Backup: backup/GardenHelper v2.16.3 2026-09-30.lua, CHANGELOG / README v2.16.3, inv v4.6.3.

## v2.18.0 (2026-10-01) - garden-loaded check, //gh loaded (inv.lua v4.9.0)

- Mark: after the normal arrival wait (`min_seconds_since_arrival`) the Green Thumb Moogle check is now: settarget him,
  the target must hold 1s (`arrival_target_hold_seconds`), Escape drops the cursor, settarget again right away, it must
  hold another 1s -> garden is loaded. Was 3 target / hold 2s / target clear rounds (`arrival_confirm_rounds` removed).
- A failed check says why (moogle not loaded, or more than 50 yalms away - SetTarget's limit) and is no longer
  remembered as passed. A late check still polls at least `arrival_min_poll_seconds` (20).
- New `//gh loaded`: the check on demand (even if already passed), ends with
  `GardenLoadedResult: OK / FAILED / NOTGARDEN / BUSY`. MuleLogger v2.26.0 uses it after every login and before every
  humus send.
- inv.lua v4.9.0: "Delivery Box did not open" lines say whether the box answered (result code) or sent no reply.
- Backup: backup/GardenHelper v2.17.0 2026-10-01.lua, inv v4.8.0 2026-10-01.lua, CHANGELOG v2.17.0, CHANGELOG-inv v4.8.0,
  README v2.17.0 2026-10-01 b.

## v2.19.0 (2026-10-01) - furrow fertilizer only right after planting

- Mark: furrow fertilizer must only go in while the plant is growing, never when it is ready to harvest - add it right
  after planting.
- `//gh furrow` / `furrowloop` / `full` (handle_furrow_for_start) now fertilize ONLY in the same visit that just planted
  the seed (plant -> fertilize). A furrow already recorded or detected as growing without fertilizer is left alone:
  its recorded time can be stale and it may really be ready (the game refuses with "There is no need to fertilize ...
  ready to harvest!"). It gets fertilizer after its next harvest + replant.
- The fertilize-after-planting step is also skipped if the planting text corrected the furrow to anything other than
  growing unfertilized.
- furrow_pass_needed (`//gh full`) no longer counts a growing, unfertilized furrow as due - no walk-over just to fertilize.
- `//gh furrowfertilize` (manual) is unchanged: it does a live check first and only fertilizes growing, unfertilized furrows.
- Removed fertilize_growing_furrow.
- Backup: backup/GardenHelper v2.18.0 2026-10-01.lua, CHANGELOG v2.18.0 2026-10-01.md, README v2.18.0 2026-10-01 b.md.

## v2.20.0 (2026-10-01) - Net route via Green Thumb Moogle and Flotsam

- Mark: the X/Y walk to the Coastal Fishing Net sometimes got stuck on the stable and chairs.
- Walking to the Net starting from the Green Thumb Moogle, a furrow, a vein or the pond now goes Green Thumb Moogle ->
  Flotsam -> Net. From anywhere else (grove side, Flotsam itself) it walks as before.
- entities.lua: `via` waypoints can name another entry (`{key = 'Flotsam', tolerance = 2.5}`) instead of x/y. New
  `via_from` (list of entry names) + `via_from_radius` (default 6): the route is used only when the walk starts within
  that radius of one of those entries' X/Y, and is then walked in full, in order (no "already past it" skip - needed
  because from Furrow 1/2 the Net is nearer than the moogle is).
- Backup: backup/GardenHelper v2.19.0 2026-10-01.lua, entities v2.19.0 2026-10-01.lua, CHANGELOG v2.19.0 2026-10-01.md.

## v2.21.0 (2026-10-03) - Stepped, background garbage collection

- Mark: the end-of-`//gh full` garbage collection caused lag at logout that got worse with every character. Turned off
  for now (`gc_at_end_of_full = false`).
- Cause: one `collectgarbage('collect')` blocks the game until GardenHelper's whole heap (~28 MB live, mostly the
  resources tables) is walked and ~15 MB freed at once. GardenHelper's own memory stayed flat run to run (no leak);
  pol.exe's address space grew over the session, which likely made the big burst of frees slower each time.
- memcheck.lua: the GC now runs in small steps (`collectgarbage('step', gc_step_kb)`, `gc_step_wait_seconds` between
  steps) so no single frame does much work. At the end of `//gh full` it runs in the background - "pass complete" and
  MuleLogger's logout are not held up. Skipped when less than `gc_min_garbage_kb` (8192) has built up since the last
  one; stops after `gc_max_seconds` (15) and leaves the rest to Lua's normal GC. Falls back to one full collect only
  outside a coroutine.
- With the memory check on, the GC still runs first and the check waits for it. `//gh memory gc` always collects.
- GC: lines (debug log, `//gh memory gc`, memory_report.lua) now include steps, total ms and longest step.
- New config: gc_step_kb (1024), gc_step_wait_seconds (0.05), gc_min_garbage_kb (8192), gc_max_seconds (15).
- Backup: backup/GardenHelper v2.20.0 2026-10-03.lua, memcheck v2.20.0 2026-10-03.lua, CHANGELOG v2.20.0 2026-10-03.md.

## v2.21.1 (2026-10-03) - Extend: typing the weeks right away is seen

- Mark: on `//ml extend` the prompt (sound) came 1-2 s before GardenHelper was ready; typing 9 + Enter right away was
  not recognised at all.
- Cause: after the sound it waited 1 s, pressed Enter to open the weeks box, waited 1.5 s more, and only THEN marked
  the chat log to watch for the "N-day contract costing" quote - a quote that came during those 2.5 s was behind the
  mark and never seen, so it sat out the 300 s wait.
- employment.lua: the watch now starts before the sound (right after "Hire this helper?"), so the quote is caught no
  matter how fast you type. The weeks box opens 0.4 s after the sound (new `employment_alert_lead_seconds`, was a
  fixed 1 s) and nothing waits after it.
- Backup: backup/employment v2.21.0 2026-10-03.lua, GardenHelper v2.21.0 2026-10-03 b.lua, CHANGELOG v2.21.0 2026-10-03 b.md.

## v2.22.0 (2026-10-03) - Garden must be loaded first, always

- Mark: `//ml extend` went ahead before the garden had loaded. Every GardenHelper and MuleLogger function must wait for
  the garden to load fully and do the standard 2x Green Thumb Moogle check first.
- Cause: the check was skipped when the garden had been "loaded" 60 s or more (`arrival_skip_check_after_seconds`) or
  after an addon reload, and a failed check only said "carrying on anyway" - so when MuleLogger's own check didn't pass,
  `//gh emp extend` (and any other garden command) just ran.
- Every garden command now: normal arrival wait -> Green Thumb Moogle 2x check (settarget, hold 1 s, Escape, settarget
  right away, hold 1 s). Never skipped; a pass is remembered for that arrival only (a new login / zone-in checks again).
- Not confirmed = the command does not run. It prints `GardenLoadedResult: FAILED` so MuleLogger stops waiting for it.
- inv / pop / send / rec / org / drop / roe / books still work outside the garden, but used in the garden they now do the
  check first too (before, they never did).
- The Green Thumb Moogle loaded but over 50 yalms away (SetTarget can't reach him): walks closer (to
  `arrival_walk_to_moogle_yalms`, 30) and checks again.
- `arrival_give_up_seconds` 60 -> 180 for slower PCs / connections. `arrival_skip_check_after_seconds` removed.
- `//gh enter` (Dinghy / Mog House) answers OK only once the garden has loaded.
- Backup: backup/GardenHelper v2.21.1 2026-10-03.lua, CHANGELOG v2.21.1 2026-10-03.md.

## v2.23.0 (2026-10-03) - //gh emp extend target: assistants end at about the same time

- Mark: `//ml extend` should work out the weeks for each assistant instead of always asking for 9, so that every
  assistant on every character expires within 7 days of the longest contract.
- employment.lua: new `//gh emp extend target <days>` (what MuleLogger v2.32.0 sends). After reading the contracts,
  each assistant gets `floor((target - days left) / 7)` weeks - it ends within 7 days of the target and never past it.
  Assistants already within 7 days are left alone.
- The prompt and the party-chat sound name the number: `>>> Kuyin (12 days left): TYPE 6 AND PRESS ENTER NOW <<<`.
- A different number typed (the quote says another week count) is backed out before "Seal the deal" - nothing is paid -
  and the box opens once more; a second wrong number = not extended (FAILED).
- More than 9 weeks needed: 9 now, then another round for the rest (`employment_max_weeks_per_hire`, 9; at most 3 rounds).
- Plain `//gh emp extend [days]` (no target) works as before.
- Backup: backup/employment v2.22.0 2026-10-03.lua, GardenHelper v2.22.0 2026-10-03.lua, CHANGELOG v2.22.0 2026-10-03.md.

## v2.24.0 (2026-10-09) - Vein/Grove rank: read the real garden rank

- V and G in `//gh status` / `//ml status` were the number of the vein/grove *object* harvested (Mineral Vein / #2 / #3 / #4),
  not the garden rank. Several ranks share one object, so the value topped out at 4 (Shadowhammer: V4 with a rank 7 vein).
- `harvest_ranked` now reads the rank from the game's line - "This mineral vein is rank N." / "This grove of trees is rank N."
  (`rank_pattern` on the vein/grove entries in NODES) - and saves that as `vein_last_rank` / `grove_last_rank`.
- Line not seen: the saved rank is kept (the object number is saved only when nothing was saved before); a debug line says so.
- Harvesting (which object, walking, stop phrase) is unchanged. Each character's V/G corrects itself on its next vein/grove harvest.
- The finish line now reads "Mineral Vein rank 7 harvest complete (object #4)."
- Logs checked 2026-10-08: game ranks 3-7 across the 16 characters vs saved 2-4.
- Backup: backup/GardenHelper v2.23.0 2026-10-09.lua.

## v2.25.0 (2026-10-09) - Shining Stars tracking (Mark)

- Mark: track how many Shining Stars each character has, from the line the game shows on the first login / Mog Garden
  visit of the day: "1 star on your GPS crystal has come aglow.A total of 25 stars twinkle softly inside your GPS crystal."
  (one chat line; the two sentences are joined by a BEL character in the log).
- `incoming text`: a line containing "GPS crystal" and "A total of N star(s)" saves N as `shining_stars` (+ `shining_stars_at`)
  2s later, only if the same character is still logged in. Saved with `persist_status` (works whether or not a run is going).
- New per-character fields in data/settings.xml: `shining_stars` (-1 = not seen yet), `shining_stars_at`.
- `//gh status`: new "Shining Stars" row - "25 (seen 10/9 10:46am)" or "not seen yet".
- MuleLogger v2.36.0 shows it in `//ml status` / ML_Status.lua as `|S  25|` after the M column.
- Characters show "not seen yet" until their next first-of-the-day garden visit.
- Backup: backup/GardenHelper v2.24.0 2026-10-09.lua.

## v2.26.0 (2026-10-09) - Storage bag tracking (Mark)

- Mark: add the Storage bag to GH status and ML status. It maxes at 80 slots; some characters have 0.
- `state.storage.read()` (fields on `state` - the main chunk is at the 200-local limit): bag 2's size from `windower.ffxi.get_items(2).max`, clamped 0-80; skipped (nil) while the
  client hasn't loaded the bags yet (main inventory max 0).
- Read 15s after login, 10s after every zone change, 3s after the addon loads and on every `//gh status`
  (delayed reads only if the same character is still logged in). Saved with `persist_status` only when it changes.
- New per-character fields in data/settings.xml: `storage_slots` (-1 = not read yet), `storage_slots_at` (when it last changed).
- `//gh status`: new "Storage" row after Shining Stars - "80 of 80 slots" / "0 of 80 slots" / "not read yet".
- MuleLogger v2.37.0 shows it in `//ml status` / ML_Status.lua as `|Str80|` / `|Str 5|` / `|Str 0|` after the S column.
- Backup: backup/GardenHelper v2.25.0 2026-10-09.lua.

## v2.27.0 (2026-10-11) - Built-in targeting, SetTarget no longer needed (Mark)

- Mark: GardenHelper (and MuleLogger, which drives it) should run without the external SetTarget addon.
- New `state.set_target(id)` (a field on `state` - the main chunk is at the 200-local limit): does what Windower's
  SetTarget does - injects an incoming 0x058 packet (Player = player.id, Target = entity id, Player Index =
  player.index) through the packets lib. Skips (false, debug line) an entity that isn't loaded / has index 0 or is
  over 50 yalms away, same limit as SetTarget. The inject is pcall-wrapped (error line if it fails).
- All three `settarget <id>` commands now use it: `settarget_confirm` (furrows, nodes, NPCs, Green Thumb Moogle),
  `retarget_entity` (Lock-On walking) and the re-target after Escape in the 2x Green Thumb Moogle arrival check.
- Behaviour change to watch: SetTarget went through Windower's command queue (async); the packet now goes in right
  away. The waits, name checks and retries after each target are unchanged.
- New config `use_settarget_addon` (default false): true = back to `settarget <id>` (SetTarget must be loaded).
- Log/comment wording: "SetTarget only reaches 50" -> "targeting only reaches 50".
- README: SetTarget removed from Requirements and Installation.
- Backup: backup/GardenHelper v2.26.0 2026-10-11.lua (plus CHANGELOG / README v2.26.0 2026-10-11.md).

## v2.27.1 (2026-10-14) - Crystals always traded
- `//gh full` now trades crystals to the Ephemeral Moogle when holding **at least** `crystals_full_threshold` of one type (was *more than*). Threshold stays 1, so any crystal/cluster held gets traded.
- Backup: backup/GardenHelper v2.27.0 2026-10-14.lua, backup/crystals v2.27.0 2026-10-14.lua.

## v2.28.0 (2026-10-21) - Kitron Macaron tracking (Mark)

- Mark: track how many Kitron Macarons each character has in GH status and ML status (`|KM14|`).
- `state.km.read()` (fields on `state` - main chunk local limit): adds up item 5781 across inventory, safe, safe2,
  storage, locker, satchel, sack and case; nil while the client hasn't loaded the bags (main inventory max 0).
- Counted wherever Storage is read (`state.storage.record()` now also calls `state.km.record()`: 15s after login, 10s
  after zone change, 3s after load, every `//gh status`), plus 2s after any `add item` / `remove item` event for
  item 5781 (one recount per burst, same character only).
- New per-character fields in data/settings.xml: `kitron_macarons` (-1 = not counted yet), `kitron_macarons_at`.
- `//gh status`: new "Kitron Macarons" row after Storage.
- MuleLogger v2.39.0 shows it as `|KM14|` / `|KM 5|` / `|KM 0|` right after the Str column.
- Backup: backup/GardenHelper v2.27.1 2026-10-21.lua.

## v2.29.0 (2026-10-26) - Ephemeral Moogle stock + withdrawals (Mark)

- Mark: MuleLogger should move crystals saved at the Ephemeral Moogle on the non-crafting mules to the crafters, in
  full stacks of clusters (144 crystals at a time). GardenHelper now knows each character's moogle stock and can take
  stacks out; MuleLogger v2.41.0 (`//ml eph`, `//ml smart` Tier 12) does the planning and mailing.
- Stock: crystals.lua reads incoming 0x113 (the currency packet), 8 ushorts from 0xE8 in element order Fire, Ice,
  Wind, Earth, Lightning, Water, Light, Dark (same offsets as the craft addon), asked for with outgoing 0x10F. Asked at
  the Storage / Kitron Macaron moments (15s after login, 10s after a zone change, 3s after load, `//gh status`),
  after every crystal trade and every withdrawal. New per-character fields in data/settings.xml: `eph_crystals`
  (`"fire,ice,...,dark"`, '' = not read yet) and `eph_crystals_at`, saved only when the stock changes.
- `//gh ephstock`: asks now, prints the stock, `EphStockResult: OK f,i,w,e,l,wa,li,d` / `FAILED`. Works anywhere.
- `//gh ephwithdraw <element> [stacks]` (`ephw`): garden-loaded check, walks to the moogle, talks (Enter) with its
  menu packet (0x034 / 0x032) held back from the client, then ends the talk with outgoing 0x05B, option =
  element (1-8) x 65536 + crystals (stacks x 144). The moogle gives 12 clusters per 144. Takes fewer stacks when the
  stock or free main-inventory slots don't allow all of them. Checks the clusters actually arrived; releases the
  client (incoming 0x052) if it is still flagged in an event. `EphWithdrawResult: DONE / PARTIAL / FAILED / BUSY
  got=<clusters> asked=<clusters> element=<n>`.
- The option format comes from the LandSandBoat server's ephemeral_moogle.lua, not a retail capture. If a
  withdrawal ever fails (no clusters arrive), `//gh ephcapture on`, take some crystals out by hand, `//gh ephcapture
  off` and the log in data/ephemeral_packets.log shows what the client really sends.
- `//gh status`: new "Ephemeral Moogle" row (stored crystals, zeros left out). `//gh help` lists the three commands.
- Backup: backup/GardenHelper v2.28.0 2026-10-26.lua, backup/crystals v2.28.0 2026-10-26.lua (plus CHANGELOG /
  README v2.28.0 2026-10-26.md).

## v2.29.1 (2026-10-26) - //gh ephwithdraw: retail option format (Mark)

- Mark: `//gh ephwithdraw earth 1` failed ("only 0 of 12 Earth Cluster arrived"); he captured a withdrawal of 144 Earth
  done by hand (`//gh ephcapture`, Fishvf).
- Capture: talk = outgoing 0x01A; menu = incoming 0x034, Menu ID 1092, parameters `5F 00 70 00 8C 00 A1 00 58 00 7F 00
  87 00 78 00` = the stock as 8 ushorts (95, 112, 140, 161 Earth, ...; the moogle said "How many? (161 stored)");
  choice = outgoing 0x05B option `90 00 04 40` = 0x40040090, not automated; then 0x052.
- Fix: the high word is 0x4000 + element (v2.29.0 sent the element alone, 0x00040090, which the server ignored).
  Option = (0x4000 + element) x 65536 + crystals. Element numbers (Earth = 4) and the low word were right.
- The 0x034 stock is now saved on every talk to the moogle (`EPH.on_034_stock`), and after a talk by hand ends (0x052)
  the 0x113 stock is asked for again - a withdrawal done by hand used to leave the saved stock stale until the next
  login / zone.
- Backup: backup/GardenHelper v2.29.0 2026-10-26.lua, backup/crystals v2.29.0 2026-10-26.lua.

## v2.30.0 (2026-10-27) - Active seed no longer protected (Mark)

- See the version notes at the bottom of GardenHelper.lua (inv.lua v4.16.0). Backup: backup/GardenHelper v2.29.1
  2026-10-27.lua, backup/inv v4.15.0 2026-10-27.lua.

## v2.31.0 (2026-11-03) - Personal item table + clean shipped ItemTable.lua (Mark)

- Mark: releases shipped his populated ItemTable.lua, so other players got his item logic (actions, mail_to names,
  per-character overrides). From now on releases ship a clean ItemTable.lua and his table lives in its own file.
- New top-level `characters.lua` setting `item_table` - the item table file INV uses, in the GardenHelper folder.
  `''` / missing / not a plain `.lua` file name = `ItemTable.lua`. Read fresh on every use (characters.lua is
  already re-read when it changes), so no reload is needed after changing it.
- GardenHelper.lua: `GH.item_table_file()` for the modules. inv.lua v4.17.0: load, `//gh pop` / `//gh inv rebuild`
  writes, the file header line and the backup name (`backup/<file>.bak`) follow it; `//gh inv help` prints the
  file in use. MuleLogger v2.41.1 reads the same setting.
- Mark's table: copied unchanged to `ItemTable_Shadowhammer.lua` (1209 item lines) and his live `characters.lua` has
  `item_table = 'ItemTable_Shadowhammer.lua'`. Extra copy: backup/ItemTable_Shadowhammer 2026-11-03.lua.
- `ItemTable.lua` is now the clean starter: same field/type docs, `mail_dry_run = true`, `auto_drop = false`,
  default `bag_order`, `items = {}` (fill with `//gh pop`). Same as what inv.lua writes when no file exists.
- Release rule from now on: the zip ships the clean `ItemTable.lua`, leaves out every `ItemTable_*.lua`, and its
  `characters.lua` has `item_table = ''`.
- README: Files table, inventory section (clean starter, `item_table`; the active-seed line brought up to v2.30.0).
- Backup: backup/GardenHelper v2.30.0 2026-11-03.lua, backup/inv v4.16.0 2026-11-03.lua, backup/characters v2.30.0
  2026-11-03.lua, backup/README v2.30.0 2026-11-03.md, backup/CHANGELOG v2.30.0 2026-11-03.md.

## v2.32.0 (2026-11-21) - //gh update from GitHub (Mark)

- New module `Update.lua` (v1.0.0), loaded as `GH.update` (the main chunk is at Lua's 200-local limit).
- `//gh update` - reads `manifest.txt` from https://github.com/thrydwolfvalefor/gardenhelper (`version=X.Y.Z` +
  `file=<name> <bytes>` lines), downloads every listed file over HTTPS (Windower's LuaSec, 15s timeout), checks
  each one (exact size, `.lua` compiles, `GardenHelper.lua` carries the manifest version - catches GitHub's few-minute
  raw-file cache), and only then writes: each replaced file is copied first to
  `backup/<name> v<old> pre-update <date time>.<ext>`; a failed write puts back everything already written. Then
  `//lua r gardenhelper`; after the reload: "Updated and reloaded - GardenHelper vX (was vY)." (via
  `data/update_notify.txt`).
- `//gh update check` - only compares versions. `//gh update force` - reinstalls GitHub's copy even if not newer.
- Branches (Mark): `major` = full releases, fully tested and validated (default); `minor` = smaller changes, out sooner.
  New `characters.lua` setting `update_branch = 'major'|'minor'` (blank / missing = major); `//gh update major|minor`
  (also with check / force) picks one for a single run. Update.lua v1.1.0.
- Never written, whatever the manifest says: `characters.lua`, `ItemTable.lua`, `ItemTable_*.lua`, `Mail.lua`,
  `memory_report.lua`, anything outside the addon folder (plain file names only). Refused while a run is going.
- Works outside the Mog Garden (no garden entry / arrival wait). In `//gh help`.
- inv.lua v4.17.1 in the same release: `//gh org` only gathers items out of the other bags when `PullFromBags = true`
  (see CHANGELOG-inv.md).
- Tested outside the game against a fake GitHub (install, backups, user files skipped, post-reload line, up to date,
  bad compile, stale cache, bad file name). Untested live.
- Backup: backup/GardenHelper v2.31.0 2026-11-21.lua, backup/README v2.31.0 2026-11-21.md,
  backup/CHANGELOG v2.31.0 2026-11-21.md, backup/characters v2.31.0 2026-11-21.lua.

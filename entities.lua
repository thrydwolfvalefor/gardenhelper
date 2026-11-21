-- GardenHelper entity table (entities.lua)
--
-- Every NPC/object GardenHelper targets or walks to, with a friendly
-- name (used in chat messages and by //gh commands), the real in-game
-- name (what settarget/get_mob_by_target reports - used to confirm the
-- right thing actually got targeted), the zone it lives in, its fixed
-- entity ID, and the X/Y spot to WALK TO before interacting with it.
--
-- Why a separate file: this is plain data you'll keep tuning by hand
-- (new XY spots after testing), so it lives on its own where it can't
-- break the addon's logic. It's read ONCE when GardenHelper loads -
-- after that it's an ordinary in-memory Lua table, so there is no speed
-- or reliability difference versus having it inside GardenHelper.lua.
-- After editing this file: //lua r gardenhelper
--
-- X/Y notes:
--   * x/y is where the CHARACTER stands, not necessarily where the
--     object is. You can interact from up to ~6 yalms away, so pick a
--     spot that's within reach of every variant of that node (Vein
--     a/b, Grove a/b) and has a clear straight line from wherever the
--     previous step leaves you (tables/chairs block straight-line
--     running).
--   * //gh pos prints your CURRENT standing position (and your
--     target's position) in exactly this format - stand where you
--     want the character to stop, then copy the line in here.
--   * via = {{x = ..., y = ...}, ...} (optional): waypoints walked
--     first, in order, to steer around walls. A waypoint is skipped
--     when you're already closer to the destination than it is.
--     A waypoint can name another entry instead: {key = 'Flotsam'}
--     (optional tolerance = yalms that count as passed).
--   * via_from = {'Pond', ...} + via_from_radius (default 6): only use
--     the via route when the walk starts within that many yalms of one
--     of those entries' X/Y; then every waypoint is walked, in order.
--   * Leave x/y as nil on any entry to fall back to the old
--     Lock-On-and-walk-forward method for that one entity.
--   * "Same as" entries below just copy the other variant's numbers,
--     so a character standing there can reach both.
--   * The starting values below were captured with the old //gh pos
--     (which printed the TARGET's own position), so most of them are
--     the object's center, not a standing spot. That still works: the
--     walker stops as soon as it's within xy_arrive_tolerance of the
--     spot, OR if it bumps into the object while already within
--     interact range of the spot. Replace them with real standing
--     spots as you test.
--
-- zone: 280 = Mog Garden, 232 = Port San d'Oria, 236 = Port Bastok,
--       240 = Port Windurst

return {
    -- ===================== Mog Garden =====================
    {friendly = 'GreenThumb',    name = 'Green Thumb Moogle',   zone = 280, id = 17924125, x = 0.0099999997764826, y = 0},

    {friendly = 'Furrow 1',      name = 'Garden Furrow',        zone = 280, id = 17924128, x = 4.4865469932556,  y = 2.0695252418518},
    {friendly = 'Furrow 2',      name = 'Garden Furrow #2',     zone = 280, id = 17924129, x = 4.5499391555786,  y = -2.2272243499756},
    {friendly = 'Furrow 3',      name = 'Garden Furrow #3',     zone = 280, id = 17924130, x = 5.1360001564026,  y = 5.7430000305176},

    -- Veins: a/b are the two variants at each rank (only one visible
    -- at a time). a/b share one standing spot (tuned 2026-09-26) that reaches both.
    {friendly = 'Vein 1a',       name = 'Mineral Vein',         zone = 280, id = 17924139, x = 7.618, y = 15.139},  -- same as Vein 1b
    {friendly = 'Vein 1b',       name = 'Mineral Vein',         zone = 280, id = 17924140, x = 7.618, y = 15.139},
    {friendly = 'Vein 2a',       name = 'Mineral Vein #2',      zone = 280, id = 17924141, x = 6.471, y = 16.479},  -- same as Vein 2b
    {friendly = 'Vein 2b',       name = 'Mineral Vein #2',      zone = 280, id = 17924142, x = 6.471, y = 16.479},
    {friendly = 'Vein 3a',       name = 'Mineral Vein #3',      zone = 280, id = 17924143, x = 5.090, y = 18.091},  -- same as Vein 3b
    {friendly = 'Vein 3b',       name = 'Mineral Vein #3',      zone = 280, id = 17924144, x = 5.090, y = 18.091},
    {friendly = 'Vein 4a',       name = 'Mineral Vein #4',      zone = 280, id = 17924145, x = 4.590, y = 18.565},   -- same as Vein 4b
    {friendly = 'Vein 4b',       name = 'Mineral Vein #4',      zone = 280, id = 17924146, x = 4.590, y = 18.565},

    {friendly = 'Pond',          name = 'Pond Dredger',         zone = 280, id = 17924147, x = 1.449, y = 9.333},

    -- Groves: a = Prune the trees, b = Remove weeds. 'b' uses the same
    -- X/Y as 'a'. (Your list said "use the same as Vein 1a" etc. for the
    -- b rows - read as Grove 1a/2a/3a/4a, since the Vein spots are on
    -- the other side of the garden.)
    {friendly = 'Grove 1a',      name = 'Arboreal Grove',       zone = 280, id = 17924131, x = -14.727999687195, y = 2.3369998931885},
    {friendly = 'Grove 1b',      name = 'Arboreal Grove',       zone = 280, id = 17924132, x = -14.727999687195, y = 2.3369998931885},  -- same as Grove 1a
    {friendly = 'Grove 2a',      name = 'Arboreal Grove #2',    zone = 280, id = 17924133, x = -12.630000114441, y = -0.82599997520447},
    {friendly = 'Grove 2b',      name = 'Arboreal Grove #2',    zone = 280, id = 17924134, x = -12.630000114441, y = -0.82599997520447}, -- same as Grove 2a
    {friendly = 'Grove 3a',      name = 'Arboreal Grove #3',    zone = 280, id = 17924135, x = -10.701000213623, y = 5.5830001831055},
    {friendly = 'Grove 3b',      name = 'Arboreal Grove #3',    zone = 280, id = 17924136, x = -10.701000213623, y = 5.5830001831055},  -- same as Grove 3a
    {friendly = 'Grove 4a',      name = 'Arboreal Grove #4',    zone = 280, id = 17924137, x = -9.173999786377,  y = 2.4790000915527},
    {friendly = 'Grove 4b',      name = 'Arboreal Grove #4',    zone = 280, id = 17924138, x = -9.173999786377,  y = 2.4790000915527},  -- same as Grove 4a

    {friendly = 'Flotsam',       name = 'Flotsam',              zone = 280, id = 17924150, x = 10.72200012207,   y = -20.361999511719},
    -- Net: from the moogle / furrows / veins / pond the straight run catches
    -- the stable and chairs, so go Green Thumb Moogle -> Flotsam -> Net (Mark 2026-10-01).
    {friendly = 'Net',           name = 'Coastal Fishing Net',  zone = 280, id = 17924149, x = 17.317,  y = -26.318,
        via = {{key = 'GreenThumb', tolerance = 2.5}, {key = 'Flotsam', tolerance = 2.5}},
        via_from = {'GreenThumb', 'Furrow 1', 'Furrow 2', 'Furrow 3',
                    'Vein 1a', 'Vein 2a', 'Vein 3a', 'Vein 4a', 'Pond'},
        via_from_radius = 6},
    {friendly = 'GardenDinghy',  name = 'Mog Dinghy',           zone = 280, id = 17924126, x = -16.498, y = -19.297},
    -- Ephem: waypoint so the walk from the grove side doesn't catch the wall (//gh pos, Bonevf 2026-09-28).
    {friendly = 'Ephem',         name = 'Ephemeral Moogle',     zone = 280, id = 17924238, x = -20.475, y = -18.842,
        via = {{x = -11.275, y = -13.051}}},

    -- Garden assistants (assistants.lua). Each one has a different id
    -- per node it works, and stands somewhere else for each. x/y = where
    -- to stand to talk (from //gh pos, Shadowhammer 2026-09-26).
    {friendly = 'Kuyin Furrow',    name = 'Kuyin Hathdenna',    zone = 280, id = 17924202, x = 7.869,  y = 3.478},
    {friendly = 'Kuyin Pond',      name = 'Kuyin Hathdenna',    zone = 280, id = 17924183, x = -5.071, y = 8.854},
    {friendly = 'Susuroon Furrow', name = 'Susuroon',           zone = 280, id = 17924184, x = 9.986,  y = 0.392},
    {friendly = 'Susuroon Net',    name = 'Susuroon',           zone = 280, id = 17924203, x = -6.306, y = -20.325},
    {friendly = 'Yeestog Grove',   name = 'Yeestog',            zone = 280, id = 17924204, x = -9.398, y = -2.531},
    {friendly = 'Yeestog Vein',    name = 'Yeestog',            zone = 280, id = 17924185, x = 11.983, y = 15.184},

    {friendly = 'Porter',        name = 'Porter Moogle',        zone = 280, id = 17924221, x = -18.166000366211, y = -12.208000183105},
    {friendly = 'Assistant',     name = 'Mandragora Assistant', zone = 280, id = 17924240, x = 13.994000434875,  y = -11.123000144958},
    {friendly = 'Chacha',        name = 'Chacharoon',           zone = 280, id = 17924231, x = -12.012999534607, y = 7.3540000915527},
    {friendly = 'Footprint',     name = 'Goblin Footprint',     zone = 280, id = 17924208, x = -15.420000076294, y = -10.520000457764},
    {friendly = 'Crabauble',     name = 'Crabauble',            zone = 280, id = 17924206, x = -2.0320000648499, y = -19.850999832153},
    {friendly = 'Chest',         name = 'Garden Strongbox',     zone = 280, id = 17924210, x = -0.33000001311302, y = 22.049999237061},

    -- ===================== Port zones =====================
    {friendly = 'WindyDinghy',   name = 'Mog Dinghy',           zone = 240, id = 17760509, x = -194.46112060547, y = 69.766868591309},
    {friendly = 'WindySkipper',  name = 'Skipper Moogle',       zone = 240, id = 17760510, x = -194.22058105469, y = 67.600730895996},
    {friendly = 'SandyDinghy',   name = 'Mog Dinghy',           zone = 232, id = 17727656, x = 22.346000671387,  y = -51.169998168945},
    {friendly = 'SandySkipper',  name = 'Skipper Moogle',       zone = 232, id = 17727657, x = 26.028999328613,  y = -51.627998352051},
    {friendly = 'BastokDinghy',  name = 'Mog Dinghy',           zone = 236, id = 17744187, x = 81.039001464844,  y = -174.01400756836},
    {friendly = 'BastokSkipper', name = 'Skipper Moogle',       zone = 236, id = 17744188, x = 75.313003540039,  y = -176.87899780273},
}

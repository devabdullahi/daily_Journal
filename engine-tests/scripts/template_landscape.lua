-- Landscape template v2. The app puts the engine-9 header, `--@ chunk`, the
-- user's painter STYLE and the entry's parameters P in front of this file:
--   STYLE = {brush="lively", temper="warm", light="natural", ground="ochre"}
--   P = {setting="meadow", time="sunset", weather="clear", season="summer",
--        subject="tree", side="left", people=1, accent="none", path=true,
--        birds=false, mood="calm", seed=7}
-- setting: meadow | hills | sea          season: spring | summer | autumn | winter
-- time:    dawn | morning | midday | afternoon | sunset | dusk | night
-- weather: clear | cloudy | rain | fog | snow
-- subject: none | tree | house | figure | boat | flowers   (boat: sea only)
-- side:    left | center | right         people: 1..3 (figure)
-- accent:  none | red | orange | yellow | green | blue | purple | pink | white | brown
-- mood:    joyful | hopeful | calm | tense | tired | melancholy
-- STYLE.brush smooth | lively | bold; temper warm | neutral | cool;
-- light high | natural | low; ground white | ochre | red
-- Every shape varies with the seed (the same entry paints the same way).
-- Techniques from the tested v7 / v3c plans and docs/color-rules.md.
STYLE = STYLE or {}
if P.setting == "city" and (P.subject == "house" or P.subject == "boat" or P.subject == "flowers") then P.subject = "none" end
if P.subject == "boat" and P.setting ~= "sea" then P.subject = "tree" end
if P.setting == "sea" and (P.subject == "tree" or P.subject == "flowers") then P.subject = "boat" end
GROUNDS = {white={{"lead white", 4}, {"yellow ochre", 0.15}},
           ochre={{"lead white", 2}, {"yellow ochre", 1}, {"red earth", 0.05}},
           red={{"red earth", 1}, {"lead white", 1.2}, {"yellow ochre", 0.3}}}
canvas{size=300, aspect=1, linen=16, seed=P.seed,
       ground={{pile=GROUNDS[STYLE.ground] or GROUNDS.white, um=60, apply="knife", texture=0.3}}}

--@ chunk
-- the day's light, the mood and the painter's hand, as numbers every pass uses
KEY = ({dawn=0.9, morning=1.05, midday=1.1, afternoon=1.0, sunset=0.85, dusk=0.6, night=0.3})[P.time] or 1
KEY = KEY * (({joyful=1.1, hopeful=1.05, calm=1, tense=0.95, tired=0.9, melancholy=0.85})[P.mood] or 1)
KEY = KEY * (({high=1.12, natural=1, low=0.88})[STYLE.light] or 1)
MUTE = ({joyful=0, hopeful=0.01, calm=0.02, tense=0.035, tired=0.05, melancholy=0.06})[P.mood] or 0.02
TEMPER = ({warm={"yellow ochre", 0.09}, cool={"cobalt blue", 0.07}})[STYLE.temper]
LEN = ({smooth=1.25, lively=1, bold=1.1})[STYLE.brush] or 1
COV = ({smooth=1.1, lively=1, bold=0.85})[STYLE.brush] or 1
SIZE = ({smooth=0.8, lively=1.15, bold=1.7})[STYLE.brush] or 1
-- broken colour (gaps showing the ground) only for a bold hand on a toned ground
FILL = not (STYLE.brush == "bold" and STYLE.ground ~= "white")
GREY = ({clear=0, cloudy=0.5, rain=0.75, fog=0.6, snow=0.5})[P.weather] or 0
SEASON = P.season or "summer"
WARM = P.time == "sunset" or P.time == "dawn"
NIGHT = P.time == "night"
BG = {}
-- our own generator, seeded by the entry (the engine's rand doesn't follow P.seed)
RNG = (P.seed * 7919 + 104729) % 2147483647
function rand(a, b)
  RNG = (RNG * 48271) % 2147483647
  return a + (b - a) * (RNG / 2147483647)
end
for i = 1, 5 do rand(0, 1) end
function L(a, b) return {a * LEN, b * LEN} end
function C(c) return c * COV end
function jit(v, d) return v + rand(-d, d) end

-- where things are: varied by the seed
H = jit(({meadow=500, hills=470, sea=480, city=520})[P.setting] or 500, 45)
CITY = P.setting == "city"
VX = jit(500, 70)
SCALE = rand(0.85, 1.2)
SX = jit(({left=250, center=500, right=750})[P.side] or 500, 55)
SUNX = CITY and jit(VX, 60) or jit((P.side == "right") and 270 or 740, 80)
G0 = H + jit(230, 40)

-- tube lists merged by name (a pile names each tube once)
function merge(a, wa, b, wb)
  local t, at = {}, {}
  for _, l in ipairs({{a, wa}, {b, wb}}) do
    for _, p in ipairs(l[1]) do
      local n = p[2] * l[2]
      if n > 0 then
        if at[p[1]] then t[at[p[1]]][2] = t[at[p[1]]][2] + n
        else t[#t + 1] = {p[1], n}; at[p[1]] = #t end
      end
    end
  end
  return t
end

-- a pile in the day's key (white scaled), muted by the mood with a tip of raw
-- umber, leaning the painter's way (a tip of ochre or cobalt)
function paint_of(list, opts)
  opts = opts or {}
  local t, sum = {}, 0
  for _, p in ipairs(list) do
    local n = p[2]
    if p[1] == "lead white" and not opts.keep then n = n * (opts.key or KEY) end
    if n > 0 then t[#t + 1] = {p[1], n}; sum = sum + n end
  end
  local m = MUTE * (opts.mute or 1) * sum
  if m > 0 then t = merge(t, 1, {{"raw umber", m}}, 1) end
  if TEMPER and not opts.pure then t = merge(t, 1, {{TEMPER[1], TEMPER[2] * sum}}, 1) end
  local pl = pile(t)
  if not opts.fg then BG[#BG + 1] = pl end
  return pl
end

-- a wavy line across the canvas: n points around `base`, `amp` up or down
function wavy(base, amp, n)
  local pts = {}
  for i = 0, n do pts[#pts + 1] = {i * 1000 / n, base + rand(-amp, amp)} end
  return pts
end

ACCENTS = {red={{"vermilion", 1}, {"lead white", 0.4}, {"chrome yellow", 0.03}},
           orange={{"vermilion", 0.5}, {"chrome yellow", 0.7}, {"lead white", 0.4}},
           yellow={{"chrome yellow", 1}, {"lead white", 0.5}},
           green={{"Prussian blue", 0.3}, {"chrome yellow", 1}, {"lead white", 0.5}},
           blue={{"cobalt blue", 1}, {"lead white", 0.5}},
           purple={{"cobalt blue", 0.6}, {"red earth", 0.4}, {"lead white", 0.6}},
           pink={{"lead white", 3}, {"vermilion", 0.45}, {"chrome yellow", 0.04}},
           white={{"lead white", 3}, {"yellow ochre", 0.05}},
           brown={{"red earth", 0.7}, {"raw umber", 0.5}, {"lead white", 0.3}}}
ACCENT = ACCENTS[P.accent]

OVERCAST = {{"lead white", 2.6}, {"raw umber", 0.16}, {"cobalt blue", 0.12}, {"yellow ochre", 0.04}}
SKY = ({
  dawn      = {top={{"cobalt blue", 0.7}, {"lead white", 2.4}, {"red earth", 0.12}}, low={{"lead white", 3}, {"vermilion", 0.12}, {"chrome yellow", 0.3}}},
  morning   = {top={{"cobalt blue", 1}, {"lead white", 2.6}}, low={{"lead white", 3}, {"cobalt blue", 0.2}, {"yellow ochre", 0.05}}},
  midday    = {top={{"cobalt blue", 1}, {"lead white", 2.0}}, low={{"lead white", 3}, {"cobalt blue", 0.35}}},
  afternoon = {top={{"cobalt blue", 1}, {"lead white", 2.2}}, low={{"lead white", 3}, {"cobalt blue", 0.25}, {"yellow ochre", 0.08}}},
  sunset    = {top={{"cobalt blue", 0.6}, {"lead white", 2}, {"red earth", 0.18}}, low={{"lead white", 2}, {"vermilion", 0.35}, {"chrome yellow", 0.7}}},
  dusk      = {top={{"Prussian blue", 0.5}, {"cobalt blue", 0.5}, {"lead white", 1.4}, {"red earth", 0.1}}, low={{"lead white", 2}, {"red earth", 0.3}, {"cobalt blue", 0.3}, {"chrome yellow", 0.1}}},
  night     = {top={{"Prussian blue", 1}, {"raw umber", 0.4}, {"lead white", 1.0}}, low={{"Prussian blue", 0.6}, {"cobalt blue", 0.4}, {"lead white", 1.6}, {"raw umber", 0.2}}},
})[P.time] or SKY

-- reserved shapes: the subject, the sun or moon and a path, painted later on clean ground
subject_mask = nil
if P.subject == "tree" then
  local s = SCALE
  local th = 250 * s
  trunk = poly({{SX - 22 * s, G0}, {SX + 22 * s, G0}, {SX + 12 * s, G0 - th}, {SX - 10 * s, G0 - th}})
  CY = G0 - th - 80 * s
  canopy = ellipse(SX, CY, jit(150, 25) * s, jit(115, 20) * s)
  for i = 1, math.floor(rand(2, 5)) do
    canopy = canopy + ellipse(SX + rand(-120, 120) * s, CY + rand(-60, 60) * s, rand(60, 100) * s, rand(50, 80) * s)
  end
  canopy = canopy:roughen(22, 70, P.seed + 1):soften(6)
  if SEASON == "winter" and P.weather ~= "snow" then canopy = nil end
  subject_mask = trunk + (canopy or trunk)
  if not canopy then
    branches = nil
    for i = 1, 5 do
      local y0 = G0 - th * rand(0.55, 0.95)
      local dx = rand(70, 150) * s * ((i % 2 == 0) and 1 or -1)
      local b = ribbon({{SX, y0}, {SX + dx * 0.5, y0 - rand(40, 80) * s}, {SX + dx, y0 - rand(80, 150) * s}}, {9 * s, 5 * s, 2})
      branches = branches and (branches + b) or b
    end
    subject_mask = subject_mask + branches
  end
  subject_mask = subject_mask:grow(4)
elseif P.subject == "house" then
  local w, wh, rh = jit(130, 30) * SCALE, jit(185, 30) * SCALE, jit(130, 25) * SCALE
  walls = poly({{SX - w, G0}, {SX + w, G0}, {SX + w, G0 - wh}, {SX - w, G0 - wh}})
  roof = poly({{SX - w - 30, G0 - wh + 5}, {SX + w + 30, G0 - wh + 5}, {SX + rand(-20, 20), G0 - wh - rh}})
  door = rect(SX + rand(-w * 0.5, w * 0.3), G0 - 95 * SCALE, 50 * SCALE, 95 * SCALE)
  windows = nil
  for i = 1, math.floor(rand(1, 4)) do
    local wx = SX - w + 20 + (i - 1) * (2 * w - 60) / 3
    local win = rect(wx, G0 - wh + 35 * SCALE, 42 * SCALE, 42 * SCALE) - door
    windows = windows and (windows + win) or win
  end
  subject_mask = (walls + roof):grow(4)
elseif P.subject == "figure" then
  local n = math.max(1, math.min(3, P.people or 1))
  local spots = ({{0}, {-60, 60}, {-100, 0, 100}})[n]
  heads, coats, legs, umbrellas = nil, nil, nil, nil
  for i = 1, n do
    local s = SCALE * rand(0.88, 1.05)
    local x = SX + spots[i] * SCALE + rand(-15, 15)
    local g = G0 + rand(-20, 20)
    local hd = ellipse(x, g - 228 * s, 17 * s, 21 * s)
    local ct = poly({{x - 30 * s, g - 205 * s}, {x + 30 * s, g - 205 * s}, {x + 44 * s, g - 70 * s}, {x - 44 * s, g - 70 * s}}, true)
    local lg = ribbon({{x - 14 * s, g - 75 * s}, {x - 17 * s, g}}, 12 * s) + ribbon({{x + 14 * s, g - 75 * s}, {x + 18 * s, g}}, 12 * s)
    heads = heads and (heads + hd) or hd
    coats = coats and (coats + ct) or ct
    legs = legs and (legs + lg) or lg
    if P.weather == "rain" then
      local u = (ellipse(x, g - 262 * s, 80 * s, 42 * s) * above(function() return g - 258 * s end))
                + ribbon({{x, g - 260 * s}, {x + 2, g - 170 * s}}, 3)
      umbrellas = umbrellas and (umbrellas + u) or u
    end
  end
  subject_mask = heads + coats + legs
  if umbrellas then subject_mask = subject_mask + umbrellas end
  subject_mask = subject_mask:grow(4)
elseif P.subject == "boat" then
  local s = SCALE
  BY = H + jit(130, 40)
  hull = poly({{SX - 110 * s, BY}, {SX + 110 * s, BY}, {SX + 78 * s, BY + 44 * s}, {SX - 78 * s, BY + 44 * s}})
  mast = ribbon({{SX, BY}, {SX, BY - 190 * s}}, 5)
  sail = poly({{SX + 6, BY - 182 * s}, {SX + 6, BY - 14 * s}, {SX + 96 * s, BY - 20 * s}})
  subject_mask = (hull + mast + sail):grow(4)
end
-- the city: a street in one-point perspective toward (VX, H), buildings of
-- varied heights along both sides, reserved from the sky
BASE_NEAR = 860
if CITY then
  STREET = {}
  BUILDINGS = nil
  for _, sign in ipairs({-1, 1}) do
    local edge, inner = (sign < 0) and 0 or 1000, VX + sign * 40
    local span = math.abs(edge - inner)
    local roofs = {}
    local function tt(xx) return clamp(math.abs(xx - inner) / span, 0, 1) end
    local function base(xx) return H + (BASE_NEAR - H) * tt(xx) end
    local x, i = inner, 0
    while (sign < 0 and x > edge + 1) or (sign > 0 and x < edge - 1) do
      i = i + 1
      local w = (25 + 230 * tt(x)) * rand(0.7, 1.25) + 15
      local x1 = x + sign * w
      if (sign < 0 and x1 < edge + 30) or (sign > 0 and x1 > edge - 30) then x1 = edge end
      local f = rand(0.5, 1.0)
      local roof = function(xx) return H - 30 - f * (H - 120) * tt(xx) - 50 * f * (1 - tt(xx)) end
      local b = poly({{x, roof(x)}, {x1, roof(x1)}, {x1, base(x1)}, {x, base(x)}})
      STREET[#STREET + 1] = {mask=b, kind=1 + (i + (sign > 0 and 1 or 0)) % 3}
      BUILDINGS = BUILDINGS and (BUILDINGS + b) or b
      x = x1
    end
    -- windows: floors and bays in perspective (depth ~ 1/k), above the ground floor
    local side_mask = mask(function(xx, yy)
      local t = tt(xx)
      local k = 0.12 + 0.88 * t
      local z = (base(xx) - yy) / (k * 70)
      local fz = z - math.floor(z)
      local d = 6 / k
      local fd = d - math.floor(d)
      return (z > 1.3 and fz > 0.3 and fz < 0.72 and fd < 0.5) and 1 or 0
    end)
    WINDOWS = WINDOWS and (WINDOWS + side_mask) or side_mask
  end
  WINDOWS = WINDOWS * BUILDINGS:shrink(6)
  road = poly({{VX - 30, H}, {VX + 30, H}, {900, 1010}, {100, 1010}})
  walks = poly({{VX - 40, H}, {VX - 30, H}, {100, 1010}, {-10, 1010}, {-10, BASE_NEAR}})
          + poly({{VX + 30, H}, {VX + 40, H}, {1010, BASE_NEAR}, {1010, 1010}, {900, 1010}})
  -- street lamps along both curbs, smaller with distance
  LAMPS, LAMP_HEADS = nil, nil
  for _, t in ipairs({0.3, 0.62, 0.95}) do
    for _, sign in ipairs({-1, 1}) do
      local cx = (VX + sign * 30) + ((sign < 0 and 100 or 900) - (VX + sign * 30)) * t
      local cy = H + (1010 - H) * t
      local k = 0.12 + 0.88 * t
      local post = ribbon({{cx + sign * 8 * k, cy}, {cx + sign * 8 * k, cy - 230 * k}}, 3 + 4 * k)
      local head = ellipse(cx + sign * 8 * k, cy - 236 * k, 9 * k + 2, 7 * k + 2)
      LAMPS = LAMPS and (LAMPS + post) or post
      LAMP_HEADS = LAMP_HEADS and (LAMP_HEADS + head) or head
    end
  end
end
if P.path and P.setting ~= "sea" and not CITY then
  local x0 = jit(SX > 500 and 300 or 700, 120)
  path = ribbon({{x0, 1010}, {jit(x0 * 0.6 + 200, 60), H + 200}, {jit(500, 150), H + 60}, {jit(500, 200), H + 8}}, {200, 110, 40, 8}):roughen(8, 50, P.seed + 2)
  if subject_mask then path = path - subject_mask end
end
SHOW_SUN = (P.weather == "clear") and P.time ~= "midday"
if SHOW_SUN then
  SUNY = WARM and (H - jit(70, 25)) or (NIGHT and jit(170, 40) or jit(210, 50))
  if CITY then SUNY = math.min(SUNY, H - 230) end
  SUNR = NIGHT and 34 or 40
  sun = ellipse(SUNX, SUNY, SUNR, SUNR):soften(3)
end
function clean(m)
  if subject_mask then m = m - subject_mask end
  if sun then m = m - sun:grow(3) end
  return m
end
CLIP = (subject_mask or sun) and true or nil

--@ chunk
-- sky: cool at the top, warm or pale toward the horizon. A warm low sky is its
-- own band, so blue and orange never mix in one passage (colour rule).
sky = above(function(x) return H + 10 end):soften(30)
if BUILDINGS then sky = sky - BUILDINGS:grow(2) end
sky_top = paint_of(merge(SKY.top, 1 - GREY, OVERCAST, GREY))
sky_low = paint_of(merge(SKY.low, 1 - GREY, OVERCAST, GREY))
if WARM and GREY < 0.5 then
  local band = rand(0.42, 0.55)
  work(clean(sky * above(function(x) return H * (band + 0.12) end):soften(60)), {hand="broad", pile=sky_top, angle=0.03, coverage=C(2), fill=FILL, scale_at=SIZE, clip=CLIP})
  work(clean(sky * below(function(x) return H * band end):soften(60)), {hand="broad", pile=sky_low, angle=0.03, coverage=C(2), fill=FILL, scale_at=SIZE, clip=CLIP})
else
  work(clean(sky), {clip=CLIP, hand="broad", angle=0.03, coverage=C(2), fill=FILL, scale_at=SIZE,
       piles={{sky_top, function(x, y) return clamp(1 - y / H, 0, 1) end},
              {sky_low, function(x, y) return clamp(y / H, 0, 1) end}}})
end
if sun then
  sun_paint = NIGHT and paint_of({{"lead white", 4}, {"yellow ochre", 0.12}}, {keep=true, mute=0, pure=true})
               or paint_of({{"lead white", 3}, {"chrome yellow", WARM and 0.9 or 0.25}, {"vermilion", WARM and 0.15 or 0}}, {keep=true, mute=0, pure=true})
  work(sun, {hand="body", pile=sun_paint, coverage=2.4, fill=true, clip=true, length={8, 20}})
  blend(sun:grow(12) - sun:shrink(10), {angle=0.2})
end

--@ chunk
-- clouds by the weather, placed by the seed
cloud_list = NIGHT and {{"lead white", 1.4}, {"Prussian blue", 0.3}, {"raw umber", 0.25}}
             or (WARM and {{"lead white", 3}, {"vermilion", 0.15}, {"chrome yellow", 0.25}}
             or {{"lead white", 4}, {"yellow ochre", 0.05}})
cloud_paint = paint_of(merge(cloud_list, 1 - GREY * 0.6, OVERCAST, GREY * 0.6))
if P.weather ~= "fog" and not (P.weather == "clear" and NIGHT) then
  local count = (P.weather == "clear") and math.floor(rand(1, 4)) or math.floor(rand(4, 7))
  local big = P.weather == "rain" and 1.4 or 1
  clouds = nil
  for i = 1, count do
    local cx, cy = rand(60, 940), rand(70, math.max(120, H - 170))
    local rx, ry = rand(70, 190) * big, rand(28, 50) * big
    local c = ellipse(cx, cy, rx, ry) + ellipse(cx + rand(-rx, rx) * 0.5, cy - ry * 0.5, rx * 0.55, ry * 1.1)
    clouds = clouds and (clouds + c) or c
  end
  clouds = clouds:roughen(16, 65, P.seed + 3):soften(12)
  work(clean(clouds * sky), {clip=CLIP, hand="body", pile=cloud_paint, angle=0.05, coverage=C(1.7), fill=FILL, scale_at=SIZE, length=L(28, 66)})
  blend(clean(clouds:grow(22) * sky), {angle=0.05})
end
if STYLE.brush == "smooth" then
  blend(clean(sky:shrink(20)), {angle=0.03})
end

--@ chunk
-- the distance: tree line, hills or a far headland, cooler and paler (aerial perspective)
if NIGHT then far_list = {{"Prussian blue", 0.6}, {"raw umber", 0.3}, {"lead white", 0.5}}
elseif P.weather == "snow" then far_list = {{"lead white", 2.4}, {"cobalt blue", 0.25}, {"raw umber", 0.12}}
elseif SEASON == "autumn" then far_list = {{"yellow ochre", 0.6}, {"red earth", 0.15}, {"Prussian blue", 0.12}, {"lead white", 1.4}}
elseif SEASON == "winter" then far_list = {{"raw umber", 0.3}, {"cobalt blue", 0.2}, {"lead white", 1.6}, {"yellow ochre", 0.1}}
else far_list = {{"Prussian blue", 0.25}, {"chrome yellow", 0.8}, {"lead white", 1.6}, {"cobalt blue", 0.1}} end
far_paint = paint_of(merge(far_list, 1 - GREY * 0.5, OVERCAST, GREY * 0.5))
if CITY then
  -- a pale skyline at the end of the street (aerial perspective)
  skyline = nil
  local x = VX - 170
  while x < VX + 170 do
    local w = rand(18, 45)
    local r = rect(x, H - rand(40, 150), w, 160)
    skyline = skyline and (skyline + r) or r
    x = x + w * rand(0.8, 1.1)
  end
  skyline = skyline * above(function() return H + 4 end) - BUILDINGS
  far_city = paint_of(merge(far_list, 0.3, {{"lead white", 2}, {"cobalt blue", 0.3}, {"raw umber", 0.1}}, 0.7))
  work(clean(skyline), {clip=true, hand="body", pile=far_city, angle=math.pi / 2, coverage=C(2), fill=true, length=L(10, 30)})
elseif P.setting == "meadow" then
  far = outline{pts=wavy(H - jit(85, 25), 22, math.floor(rand(6, 10))), open=true}:below() * above(function(x) return H + 20 end):soften(20)
  work(clean(far), {clip=CLIP, hand="body", pile=far_paint, angle=0.2, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(20, 50), edge="soft"})
elseif P.setting == "hills" then
  far = outline{pts=wavy(H - jit(100, 30), 45, math.floor(rand(4, 7))), open=true}:below() * above(function(x) return H + 30 end):soften(20)
  hill_far = paint_of(merge(far_list, 0.6, {{"cobalt blue", 0.5}, {"lead white", 1.2}, {"yellow ochre", 0.1}}, 0.4))
  work(clean(far), {clip=CLIP, hand="body", pile=hill_far, angle=0.15, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(30, 70), edge="soft"})
  blend(clean(far:rim(30, 10)), {angle=0.15})
else
  local x1 = rand(150, 420)
  local left = rand(0, 1) < 0.5
  local pts = left and {{0, H - jit(45, 15)}, {x1 * 0.5, H - jit(55, 15)}, {x1, H - 20}, {x1 + 60, H}}
                   or {{940 - x1, H}, {1000 - x1, H - 20}, {1000 - x1 * 0.5, H - jit(55, 15)}, {1000, H - jit(45, 15)}}
  headland = (outline{pts=pts, open=true}:below() * above(function(x) return H + 4 end)):soften(4)
  work(clean(headland), {clip=CLIP, hand="body", pile=far_paint, angle=0.1, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(15, 40), edge="soft"})
end

--@ chunk
-- the ground: grass lit toward the light (by season), or the sea and a strip of beach
if CITY then
  -- buildings: brick, stone and grey fronts, lit windows at dusk and night
  FRONTS = {{{"red earth", 1}, {"raw umber", 0.2}, {"lead white", 0.6}},
            {{"yellow ochre", 0.7}, {"lead white", 1.4}, {"raw umber", 0.1}},
            {{"lead white", 1.2}, {"raw umber", 0.3}, {"cobalt blue", 0.15}}}
  front_piles = {}
  for k = 1, 3 do front_piles[k] = paint_of(merge(FRONTS[k], 1 - GREY * 0.3, OVERCAST, GREY * 0.3)) end
  for _, b in ipairs(STREET) do
    work(clean(b.mask - WINDOWS), {clip=true, hand="body", pile=front_piles[b.kind], angle=math.pi / 2, coverage=C(2), fill=FILL, scale_at=SIZE * 0.8, length=L(14, 40)})
  end
  LIT = NIGHT or P.time == "dusk"
  window_city = paint_of(LIT and {{"chrome yellow", 1}, {"lead white", 1.4}, {"vermilion", 0.06}} or {{"cobalt blue", 0.4}, {"raw umber", 0.5}, {"lead white", 0.6}},
                         {keep=LIT, mute=LIT and 0 or 1, pure=LIT})
  work(clean(WINDOWS), {clip=true, hand="detail", pile=window_city, coverage=2.2, fill=true})
  road_list = (P.weather == "rain") and {{"lead white", 1.0}, {"raw umber", 0.35}, {"cobalt blue", 0.3}} or {{"lead white", 1.2}, {"raw umber", 0.4}, {"cobalt blue", 0.15}, {"yellow ochre", 0.1}}
  if P.weather == "snow" then road_list = {{"lead white", 2.6}, {"cobalt blue", 0.15}, {"raw umber", 0.08}} end
  road_paint = paint_of(road_list)
  walk_paint = paint_of(merge(road_list, 1, {{"lead white", 0.6}, {"yellow ochre", 0.15}}, 1))
  work(clean(road), {clip=true, hand="body", pile=road_paint, angle=0, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(30, 90)})
  work(clean(walks), {clip=true, hand="body", pile=walk_paint, angle=0.3, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(20, 60)})
  if P.weather == "rain" then
    -- reflections of the lit windows and lamps in the wet or dark street
    shine_city = paint_of({{"lead white", 2}, {"chrome yellow", LIT and 0.15 or 0.03}, {"cobalt blue", LIT and 0 or 0.1}}, {keep=true, mute=0, pure=true})
    work(clean(road * below(function() return H + 60 end)), {hand="hatch", pile=shine_city, angle=math.pi / 2, coverage=0.1, length={15, 45}, clip=true})
  end
elseif P.setting == "sea" then
  water = below(function(x) return H end) * above(function(x) return 850 end):soften(16)
  near_list = NIGHT and {{"Prussian blue", 1}, {"raw umber", 0.3}, {"lead white", 0.4}} or {{"Prussian blue", 0.7}, {"cobalt blue", 0.4}, {"lead white", 1.4}}
  far_water = paint_of(merge(merge(SKY.low, 0.5, near_list, 0.5), 1 - GREY * 0.5, OVERCAST, GREY * 0.5))
  near_water = paint_of(merge(near_list, 1 - GREY * 0.4, OVERCAST, GREY * 0.4))
  water_piles = {{far_water, function(x, y) return clamp(1 - (y - H) / 300, 0, 1) end},
                 {near_water, function(x, y) return clamp((y - H) / 300, 0, 1) end}}
  if sun then
    -- the sun's or moon's path on the water: a band under it, widening toward us
    shine = paint_of(NIGHT and {{"lead white", 2.4}, {"cobalt blue", 0.3}, {"yellow ochre", 0.05}} or SKY.low, {keep=true, mute=0})
    water_piles[3] = {shine, function(x, y)
      local w = 14 + (y - H) * 0.22
      return 1.6 * math.exp(-((x - SUNX) / w) ^ 2) * clamp(1 - (y - H) / 420, 0.25, 1)
    end}
  end
  work(clean(water), {hand="body", angle=0, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(40, 120), clip=CLIP, piles=water_piles})
  sand = paint_of(P.weather == "snow" and {{"lead white", 3}, {"cobalt blue", 0.1}} or {{"lead white", 2}, {"yellow ochre", 0.7}, {"red earth", 0.06}})
  local wave = rand(60, 120)
  work(clean(below(function(x) return 845 + 12 * math.sin(x / wave) end)), {clip=CLIP, hand="body", pile=sand, angle=0.05, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(30, 80)})
else
  ground = below(function(x) return H + (P.setting == "hills" and 10 * math.sin(x / 140) or 0) end):soften(20)
  if path then ground = ground - path end
  if P.weather == "snow" then
    lit_list, deep_list = {{"lead white", 4}, {"yellow ochre", 0.06}}, {{"lead white", 2.6}, {"cobalt blue", 0.22}, {"raw umber", 0.05}}
  elseif NIGHT then
    lit_list, deep_list = {{"Prussian blue", 0.5}, {"chrome yellow", 0.4}, {"lead white", 0.6}, {"raw umber", 0.2}}, {{"Prussian blue", 0.6}, {"raw umber", 0.4}, {"lead white", 0.3}}
  elseif SEASON == "spring" then
    lit_list, deep_list = {{"chrome yellow", 1}, {"Prussian blue", 0.06}, {"lead white", 1.3}}, {{"chrome yellow", 1}, {"Prussian blue", 0.14}, {"lead white", 0.8}}
  elseif SEASON == "autumn" then
    lit_list, deep_list = {{"yellow ochre", 0.8}, {"chrome yellow", 0.5}, {"Prussian blue", 0.06}, {"lead white", 0.9}, {"red earth", 0.05}},
                          {{"yellow ochre", 0.7}, {"Prussian blue", 0.15}, {"raw umber", 0.15}, {"lead white", 0.5}, {"red earth", 0.06}}
  elseif SEASON == "winter" then
    lit_list, deep_list = {{"lead white", 1.4}, {"yellow ochre", 0.4}, {"Prussian blue", 0.08}, {"raw umber", 0.1}},
                          {{"lead white", 0.8}, {"raw umber", 0.3}, {"Prussian blue", 0.12}, {"yellow ochre", 0.3}}
  else
    lit_list = {{"chrome yellow", 1}, {"Prussian blue", 0.08}, {"lead white", 1.1}}
    deep_list = {{"chrome yellow", 1}, {"Prussian blue", 0.18}, {"lead white", 0.6}, {"red earth", 0.04}}
  end
  if WARM and not NIGHT and P.weather ~= "snow" then lit_list = merge(lit_list, 1, {{"vermilion", 0.04}, {"yellow ochre", 0.2}}, 1) end
  grass_lit = paint_of(merge(lit_list, 1 - GREY * 0.35, OVERCAST, GREY * 0.35))
  grass_deep = paint_of(merge(deep_list, 1 - GREY * 0.35, OVERCAST, GREY * 0.35))
  work(clean(ground), {clip=CLIP, hand=(STYLE.brush == "smooth") and "broad" or "body", angle=jit(0.08, 0.06), coverage=C(2), fill=FILL, scale_at=SIZE, length=L(40, 110),
       piles={{grass_lit, function(x, y) return clamp(1 - (y - H) / 520, 0, 1) end},
              {grass_deep, function(x, y) return clamp((y - H) / 520, 0, 1) end}}})
  if path then
    path_paint = paint_of(P.weather == "snow" and {{"lead white", 3}, {"cobalt blue", 0.12}, {"raw umber", 0.04}}
                          or {{"lead white", 2}, {"yellow ochre", 0.7}, {"red earth", 0.08}})
    work(path, {hand="body", pile=path_paint, angle=-0.5, coverage=C(2), fill=true, clip=true, length=L(30, 80)})
  end
end

--@ chunk
-- the background is done: scrape its piles off the palette (it holds 16)
palette{scrape=BG}
-- the subject, lit from the side the light comes from
LDIR = (SUNX > SX) and 1 or -1
function lit_at(cx, cy, r)
  return function(x, y) return clamp(0.5 + LDIR * (x - cx) / r - (y - cy) / r, 0, 1) end
end
FG = {fg=true}
if P.subject == "tree" then
  bark = paint_of({{"raw umber", 1}, {"cobalt blue", 0.15}, {"red earth", 0.3}, {"lead white", 0.3}}, FG)
  work(trunk, {hand="body", pile=bark, angle=math.pi / 2, coverage=2.2, fill=true, clip=true})
  if branches then work(branches, {hand="detail", pile=bark, coverage=2.5, fill=true, clip=true}) end
  if canopy then
    if P.weather == "snow" or NIGHT then
      leaf_shade = paint_of({{"Prussian blue", 0.5}, {"raw umber", 0.4}, {"chrome yellow", 0.3}, {"lead white", 0.4}}, FG)
      leaf_lit = paint_of({{"Prussian blue", 0.3}, {"chrome yellow", 0.6}, {"lead white", 0.9}}, FG)
    elseif SEASON == "autumn" then
      leaf_shade = paint_of({{"red earth", 0.6}, {"vermilion", 0.3}, {"chrome yellow", 0.5}, {"raw umber", 0.2}, {"lead white", 0.3}}, FG)
      leaf_lit = paint_of({{"chrome yellow", 1}, {"vermilion", 0.35}, {"lead white", 0.6}}, FG)
    elseif SEASON == "spring" then
      leaf_shade = paint_of({{"Prussian blue", 0.25}, {"chrome yellow", 1}, {"lead white", 0.6}}, FG)
      leaf_lit = paint_of({{"chrome yellow", 1}, {"Prussian blue", 0.05}, {"lead white", 1.4}}, FG)
    else
      leaf_shade = paint_of({{"Prussian blue", 0.35}, {"chrome yellow", 1}, {"yellow ochre", 0.3}, {"red earth", 0.04}, {"lead white", 0.35}}, FG)
      leaf_lit = paint_of({{"chrome yellow", 1}, {"Prussian blue", 0.1}, {"lead white", 1.0}}, FG)
    end
    local lit = lit_at(SX, CY, 300)
    work(canopy, {hand="body", angle=jit(0.6, 0.3), coverage=C(2.4), fill=FILL, scale_at=SIZE, length=L(14, 34),
                  piles={{leaf_shade, function(x, y) return 1 - lit(x, y) end}, {leaf_lit, lit}}})
    if SEASON == "spring" and not NIGHT then
      blossom = paint_of(ACCENT or {{"lead white", 3}, {"vermilion", 0.3}, {"chrome yellow", 0.03}}, {fg=true, keep=true})
      stipple(canopy:shrink(10), {pile=blossom, width=4, coverage=0.004, cluster=0.6})
    end
  end
elseif P.subject == "house" then
  wall = paint_of({{"lead white", 2.4}, {"yellow ochre", 0.5}, {"red earth", 0.05}}, FG)
  wall_shade = paint_of({{"lead white", 1.4}, {"yellow ochre", 0.4}, {"cobalt blue", 0.12}, {"raw umber", 0.1}}, FG)
  local lit = lit_at(SX, G0 - 100, 260)
  work(walls - door - windows, {hand="body", angle=math.pi / 2, coverage=C(2.2), fill=true, clip=true, length=L(20, 50),
       piles={{wall_shade, function(x, y) return 1 - lit(x, y) end}, {wall, lit}}})
  roof_paint = paint_of({{"red earth", 1}, {"vermilion", 0.2}, {"raw umber", 0.15}, {"lead white", 0.4}}, FG)
  work(roof, {hand="body", pile=roof_paint, angle=0.5 * LDIR, coverage=C(2.2), fill=true, clip=true, length=L(20, 50)})
  door_paint = paint_of(ACCENT or {{"raw umber", 1}, {"red earth", 0.3}, {"lead white", 0.15}}, FG)
  work(door, {hand="body", pile=door_paint, angle=math.pi / 2, coverage=2.2, fill=true, clip=true, length={10, 30}})
  glow = (NIGHT or P.time == "dusk") and {{"chrome yellow", 1}, {"lead white", 1.5}, {"vermilion", 0.08}}
         or {{"cobalt blue", 0.4}, {"raw umber", 0.5}, {"lead white", 0.5}}
  window_paint = paint_of(glow, {fg=true, keep=true, mute=0, pure=true})
  work(windows, {hand="body", pile=window_paint, coverage=2.4, fill=true, clip=true, length={8, 20}})
elseif P.subject == "figure" then
  coat_list = ACCENT or ({joyful={{"vermilion", 0.8}, {"lead white", 0.6}, {"chrome yellow", 0.05}},
                hopeful={{"chrome yellow", 0.7}, {"yellow ochre", 0.4}, {"lead white", 0.6}},
                calm={{"yellow ochre", 0.8}, {"red earth", 0.2}, {"lead white", 0.6}},
                tense={{"raw umber", 0.7}, {"Prussian blue", 0.4}, {"lead white", 0.2}},
                tired={{"cobalt blue", 0.6}, {"raw umber", 0.4}, {"lead white", 0.5}},
                melancholy={{"Prussian blue", 0.5}, {"raw umber", 0.4}, {"lead white", 0.6}}})[P.mood]
  coat_paint = paint_of(coat_list, FG)
  work(coats, {hand="body", pile=coat_paint, angle=math.pi / 2, coverage=2.4, fill=true, clip=true, length={10, 26}})
  dark = paint_of({{"raw umber", 1}, {"cobalt blue", 0.3}, {"lead white", 0.15}}, FG)
  work(legs, {hand="detail", pile=dark, coverage=2.5, fill=true, clip=true})
  skin = paint_of({{"lead white", 2}, {"yellow ochre", 0.4}, {"vermilion", 0.12}, {"chrome yellow", 0.03}}, FG)
  work(heads, {hand="detail", pile=skin, coverage=2.5, fill=true, clip=true})
  if umbrellas then
    brolly = paint_of({{"Prussian blue", 0.6}, {"raw umber", 0.5}, {"lead white", 0.2}}, FG)
    work(umbrellas, {hand="body", pile=brolly, angle=0.2, coverage=2.4, fill=true, clip=true, length={10, 26}})
  end
elseif P.subject == "boat" then
  hull_paint = paint_of(ACCENT or {{"red earth", 1}, {"raw umber", 0.4}, {"lead white", 0.3}}, FG)
  work(hull, {hand="body", pile=hull_paint, angle=0, coverage=2.4, fill=true, clip=true, length={20, 50}})
  sail_paint = paint_of({{"lead white", 3}, {"yellow ochre", 0.2}, {"chrome yellow", 0.03}}, FG)
  work(sail, {hand="body", pile=sail_paint, angle=1.2, coverage=2.4, fill=true, clip=true, length={14, 40}})
  mast_paint = paint_of({{"raw umber", 1}, {"lead white", 0.2}}, FG)
  work(mast, {hand="detail", pile=mast_paint, coverage=2.5, fill=true, clip=true})
end

--@ chunk
-- accents: flowers, birds, then the weather over everything
if P.subject == "flowers" then
  b = brush{kind="round", width=13, point=0.5}
  flower_piles = {paint_of(ACCENT or {{"vermilion", 1}, {"lead white", 0.8}, {"chrome yellow", 0.05}}, FG),
                  paint_of({{"chrome yellow", 1}, {"lead white", 1}}, FG),
                  paint_of({{"lead white", 4}, {"yellow ochre", 0.05}}, FG)}
  local x0, x1 = (P.side == "left") and 20 or ((P.side == "right") and 400 or 120), (P.side == "left") and 600 or ((P.side == "right") and 980 or 880)
  for i = 1, math.floor(rand(70, 130)) do
    local x, y = rand(x0, x1), rand(H + 120, 990)
    local s = 0.6 + (y - H) / 700
    -- loaded heavy and pressed on, so the dab sits on the wet grass instead of mixing into it
    b:load(flower_piles[1 + (i % 4 == 0 and 1 or 0) + (i % 7 == 0 and 1 or 0)], 1)
    b:gesture({{x, y, 1}, {x + 7 * s, y - 8 * s, 1}, {x + 12 * s, y - 6 * s, 0.6}})
  end
end
if CITY and LAMPS then
  lamp_paint = paint_of({{"raw umber", 1}, {"Prussian blue", 0.3}, {"lead white", 0.15}}, FG)
  work(LAMPS, {hand="detail", pile=lamp_paint, coverage=2.5, fill=true, clip=true})
  head_paint = paint_of(LIT and {{"chrome yellow", 1}, {"lead white", 2}} or {{"lead white", 1.5}, {"raw umber", 0.3}}, {fg=true, keep=true, mute=0, pure=true})
  work(LAMP_HEADS, {hand="detail", pile=head_paint, coverage=2.5, fill=true, clip=true})
end
if P.birds and not NIGHT then
  bb = brush{kind="round", width=3, point=0.5}
  bird = paint_of({{"raw umber", 1}, {"cobalt blue", 0.3}, {"lead white", 0.2}}, FG)
  local cx, cy = rand(150, 850), rand(90, math.max(140, H - 200))
  for i = 1, math.floor(rand(3, 7)) do
    local x, y, s = cx + rand(-150, 150), cy + rand(-60, 60), rand(0.7, 1.3)
    bb:load(bird, 0.5)
    bb:gesture({{x - 12 * s, y - 5 * s, 0.3}, {x - 5 * s, y - 2 * s, 0.7}, {x, y + 2 * s, 0.6}, {x + 5 * s, y - 2 * s, 0.7}, {x + 12 * s, y - 5 * s, 0.3}})
  end
end
if P.weather == "rain" then
  rain = paint_of({{"lead white", 2}, {"cobalt blue", 0.15}, {"raw umber", 0.08}}, {fg=true, keep=true})
  work(everywhere(), {hand="hatch", pile=rain, angle=jit(1.35, 0.12), coverage=0.18, length={20, 60}, pressure={0.2, 0.4}})
elseif P.weather == "snow" then
  b = brush{kind="round", width=5, point=0.5}
  flake = paint_of({{"lead white", 4}, {"cobalt blue", 0.03}}, {fg=true, keep=true})
  for i = 1, math.floor(rand(70, 120)) do
    local x, y = rand(10, 990), rand(10, 990)
    b:load(flake, 0.5)
    b:gesture({{x, y, 0.6}, {x + 2, y + 2, 0.3}})
  end
elseif P.weather == "fog" then
  fog = paint_of({{"lead white", 3}, {"raw umber", 0.05}, {"cobalt blue", 0.04}}, {fg=true, keep=true})
  work(above(function(x) return H + 160 end) * below(function(x) return H - 200 end):soften(80), {hand="glaze", pile=fog, coverage=1})
end

-- Scene compiler v1: paints the scene a language model composed from a journal
-- entry. The app puts the engine-9 header, `--@ chunk`, the user's painter
-- STYLE and the SCENE table in front of this file (see SceneSpec.swift):
--   STYLE = {brush="lively", temper="warm", light="natural", ground="ochre"}
--   SCENE = {title=..., place=..., indoor=false, horizon=55, upper="skyBlue",
--            lower="green", surface="grass", time="afternoon", weather="clear",
--            feeling="joyful", light="right", seed=7, elements={
--              {name="ice cream cone", shape="cylinder", x=50, y=90, w=12, h=30,
--               color="pink", second="tan", glows=false}, ...}}
-- Positions are percents; y is where an element's bottom sits.
-- Techniques from the tested landscape template and docs/color-rules.md.
STYLE = STYLE or {}
S = SCENE
GROUNDS = {white={{"lead white", 4}, {"yellow ochre", 0.15}},
           ochre={{"lead white", 2}, {"yellow ochre", 1}, {"red earth", 0.05}},
           red={{"red earth", 1}, {"lead white", 1.2}, {"yellow ochre", 0.3}}}
canvas{size=300, aspect=1, linen=16, seed=S.seed,
       ground={{pile=GROUNDS[STYLE.ground] or GROUNDS.white, um=60, apply="knife", texture=0.3}}}

--@ chunk
-- the light, the feeling and the painter's hand
KEY = ({dawn=0.9, morning=1.05, midday=1.1, afternoon=1.0, sunset=0.85, dusk=0.6, night=0.35})[S.time] or 1
if S.indoor and S.time == "night" then KEY = 0.55 end
KEY = KEY * (({joyful=1.1, hopeful=1.05, calm=1, tense=0.95, tired=0.9, melancholy=0.85})[S.feeling] or 1)
KEY = KEY * (({high=1.12, natural=1, low=0.88})[STYLE.light] or 1)
MUTE = ({joyful=0, hopeful=0.01, calm=0.02, tense=0.035, tired=0.05, melancholy=0.06})[S.feeling] or 0.02
TEMPER = ({warm={"yellow ochre", 0.09}, cool={"cobalt blue", 0.07}})[STYLE.temper]
LEN = ({smooth=1.25, lively=1, bold=1.1})[STYLE.brush] or 1
COV = ({smooth=1.1, lively=1, bold=0.85})[STYLE.brush] or 1
SIZE = ({smooth=0.8, lively=1.15, bold=1.7})[STYLE.brush] or 1
FILL = not (STYLE.brush == "bold" and STYLE.ground ~= "white")
GREY = S.indoor and 0 or (({clear=0, cloudy=0.5, rain=0.75, fog=0.6, snow=0.5})[S.weather] or 0)
WARM = S.time == "sunset" or S.time == "dawn"
NIGHT = S.time == "night"
LX = ({left=-1, right=1, above=0, front=0})[S.light] or 1
BG = {}

-- our own generator, seeded by the entry
RNG = (S.seed * 7919 + 104729) % 2147483647
function rand(a, b)
  RNG = (RNG * 48271) % 2147483647
  return a + (b - a) * (RNG / 2147483647)
end
for i = 1, 5 do rand(0, 1) end
function L(a, b) return {a * LEN, b * LEN} end
function C(c) return c * COV end
function jit(v, d) return v + rand(-d, d) end

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
  if opts.list then opts.list[#opts.list + 1] = pl elseif not opts.fg then BG[#BG + 1] = pl end
  return pl
end

-- the named colours as tube mixtures (colour rules: chromatic darks, no black by reflex)
COLORS = {
  white={{"lead white", 3}, {"yellow ochre", 0.05}},
  cream={{"lead white", 2.4}, {"yellow ochre", 0.5}},
  yellow={{"chrome yellow", 1}, {"lead white", 0.5}},
  gold={{"chrome yellow", 0.6}, {"yellow ochre", 0.7}, {"lead white", 0.3}},
  orange={{"vermilion", 0.5}, {"chrome yellow", 0.7}, {"lead white", 0.4}},
  red={{"vermilion", 1}, {"lead white", 0.3}, {"chrome yellow", 0.03}},
  darkRed={{"red earth", 1}, {"vermilion", 0.2}, {"raw umber", 0.15}, {"lead white", 0.2}},
  pink={{"lead white", 3}, {"vermilion", 0.45}, {"chrome yellow", 0.04}},
  purple={{"cobalt blue", 0.6}, {"red earth", 0.4}, {"lead white", 0.6}},
  blue={{"cobalt blue", 1}, {"lead white", 0.6}},
  skyBlue={{"cobalt blue", 1}, {"lead white", 2.4}},
  navy={{"Prussian blue", 1}, {"raw umber", 0.3}, {"lead white", 0.3}},
  green={{"Prussian blue", 0.3}, {"chrome yellow", 1}, {"lead white", 0.5}},
  darkGreen={{"Prussian blue", 0.5}, {"chrome yellow", 0.6}, {"raw umber", 0.2}, {"lead white", 0.2}},
  brown={{"red earth", 0.7}, {"raw umber", 0.5}, {"lead white", 0.3}},
  tan={{"yellow ochre", 0.8}, {"lead white", 1}, {"red earth", 0.1}},
  grey={{"lead white", 1.4}, {"raw umber", 0.3}, {"cobalt blue", 0.15}},
  darkGrey={{"raw umber", 0.6}, {"cobalt blue", 0.3}, {"lead white", 0.5}},
  black={{"raw umber", 1}, {"Prussian blue", 0.5}, {"lead white", 0.05}},
}
function color(name) return COLORS[name] or COLORS.grey end
-- the shadow side of a colour: less white, a cool dark mixed in
function shade(list)
  return merge(list, 1, {{"raw umber", 0.25}, {"cobalt blue", 0.12}}, 1)
end
function lighter(list, k)
  return merge(list, 1, {{"lead white", k}, {"yellow ochre", 0.03 * k}}, 1)
end
OVERCAST = {{"lead white", 2.6}, {"raw umber", 0.16}, {"cobalt blue", 0.12}, {"yellow ochre", 0.04}}

-- composition: the model said what is there and what matters; we place it like a painter
H = S.indoor and jit(600, 40) or jit(520, 50)
BASE = {person=300, animal=130, tree=470, plant=130, building=380, vehicle=170, furniture=240, food=80, drink=80,
        object=100, screen=110, lamp=310, window=270, mountain=330, sun=90, moon=80}
RATIO = {person=0.4, animal=1.5, tree=0.75, plant=0.6, building=0.9, vehicle=2.2, furniture=1.5, food=0.8, drink=0.7,
         object=1, screen=1.4, lamp=0.35, window=0.75, mountain=2.6, sun=1, moon=1}
SIZEK = {small=0.75, medium=1, large=1.3}
SMALL = {food=true, drink=true, object=true, screen=true, plant=true}
function has(name, words)
  local n = string.lower(name or "")
  for _, w in ipairs(words) do if string.find(n, w, 1, true) then return true end end
  return false
end
-- one main; the rest beside or behind
local raw, main = {}, nil
for i, e in ipairs(S.elements or {}) do
  if i > 5 then break end
  if not BASE[e.kind] then e.kind = "object" end
  -- backdrop and weather named as things: the ground, sky and weather passes already paint them
  if e.kind ~= "mountain" and has(e.name, {"wave", "sea", "ocean", "sand", "beach", "sky", "rain", "snow", "fog", "cloud",
      "grass", "ground", "road", "street", "floor", "wall", "light", "view", "sunset", "air", "weather"}) and
      not has(e.name, {"lamp", "light bulb", "streetlight", "traffic light", "snowman"}) then e = nil end
  if e and (e.kind == "sun" or e.kind == "moon") and S.indoor then e = nil end
  if e then
    if e.role == "main" and not main then main = e elseif e.role == "main" then e.role = "beside" end
    raw[#raw + 1] = e
  end
end
if not main and raw[1] then main = raw[1]; main.role = "main" end
for i, e in ipairs(raw) do if e == main and i > 1 then table.remove(raw, i); table.insert(raw, 1, main); break end end
furniture = nil
for _, e in ipairs(raw) do if e.kind == "furniture" and e ~= main then furniture = furniture or e end end
if main and main.kind == "furniture" then furniture = main end
ELS = {}
function place(e, cx, by, h, k)
  local w = h * (RATIO[e.kind] or 1)
  if e.drawing then w = h * clamp(e.drawing.wp or 100, 15, 400) / 100 end
  if e.kind == "furniture" and has(e.name, {"couch", "sofa", "bed"}) then w = h * 2.2 end
  ELS[#ELS + 1] = {e=e, cx=cx, by=by, w=w, h=h, k=k or 1, i=#ELS + 1}
  return ELS[#ELS]
end
function depth_at(d) return H + d * (1000 - H) end
function k_at(d) return 0.45 + 0.55 * d end
if S.fixed and main then
  -- comparison renders: the one object alone, same box height for every variant
  local h = 620
  local wr = main.drawing and clamp(main.drawing.wp or 100, 15, 400) / 100 or (RATIO[main.kind] or 1)
  if h * wr > 900 then h = 900 / wr end
  place(main, 500, 930, h, 1)
  raw = {}
end
MX = jit(500, 70)
SKYX = (LX > 0) and jit(780, 60) or jit(220, 60)
local side = (rand(0, 1) < 0.5) and -1 or 1
local placed_main, top = nil, nil
-- furniture first when small things sit on it
if furniture and main and main ~= furniture and SMALL[main.kind] then
  local d = 0.55
  local fh = BASE.furniture * (SIZEK[furniture.size] or 1) * k_at(d) * 1.3
  local f = place(furniture, MX, depth_at(d), fh, k_at(d))
  if has(furniture.name, {"couch", "sofa", "bed"}) then top = f.by - fh * 0.45 else top = f.by - fh * 0.92 end
  furniture.placed = true
end
for _, e in ipairs(raw) do
  if e.placed then goto continue end
  local sk = SIZEK[e.size] or 1
  local n = math.max(1, math.min(3, e.count or 1))
  if e.kind == "sun" or e.kind == "moon" then
    place(e, SKYX, jit(250, 50), BASE[e.kind] * sk, 1)
  elseif e.kind == "mountain" then
    place(e, jit(500, 200), H + 8, BASE.mountain * sk, 1)
  elseif e.kind == "window" then
    local x = S.indoor and ((MX > 500) and jit(250, 60) or jit(750, 60)) or MX
    place(e, x, H - jit(70, 20), BASE.window * sk, 1)
  elseif e == main then
    if SMALL[main.kind] and top then
      -- on the table or desk
      local h = BASE[e.kind] * sk * 1.6
      for c = 1, n do place(e, MX + (c - (n + 1) / 2) * h * 1.1, top + 4, h, 1) end
    elseif SMALL[main.kind] then
      -- a close-up: the thing itself fills the picture, rising from the bottom edge
      local h = 560 * sk
      place(e, MX, 1000 + h * 0.06, h, 1.6)
    else
      local d = S.indoor and 0.5 or 0.62
      local h = BASE[e.kind] * sk * k_at(d) * 1.3
      for c = 1, n do
        local s = (c == 1) and 1 or rand(0.85, 0.98)
        local el = place(e, MX, depth_at(d) + rand(-12, 12), h * s, k_at(d))
        el.cx = MX + (c - (n + 1) / 2) * el.w * 1.15
      end
    end
  elseif e.role == "behind" or e.kind == "building" then
    local d = (e.kind == "building") and 0.02 or 0.15
    local h = BASE[e.kind] * sk * ((e.kind == "building") and 1 or k_at(d))
    local x = (MX > 500) and jit(260, 120) or jit(740, 120)
    for c = 1, n do
      local el = place(e, x, depth_at(d) + c * 3, h * rand(0.85, 1.1), k_at(d))
      el.cx = clamp(x + (c - (n + 1) / 2) * el.w * 1.1, el.w * 0.3, 1000 - el.w * 0.3)
    end
  else
    -- beside the main subject, alternating sides
    local m = ELS[1]
    local d = S.indoor and 0.55 or 0.66
    local h = BASE[e.kind] * sk * k_at(d) * 1.2
    if SMALL[e.kind] and top then
      h = BASE[e.kind] * sk * 1.4
      local x = MX + side * rand(110, 200)
      place(e, x, top + 4, h, 1)
    else
      local w1 = h * (RATIO[e.kind] or 1)
      local x = (m and m.cx or MX) + side * ((m and m.w or 100) / 2 + w1 / 2 + 30)
      if x < w1 * 0.4 or x > 1000 - w1 * 0.4 then side = -side; x = (m and m.cx or MX) + side * ((m and m.w or 100) / 2 + w1 / 2 + 30) end
      for c = 1, n do
        local el = place(e, x + side * (c - 1) * w1 * 1.05, depth_at(d) + rand(-15, 15), h * rand(0.9, 1.05), k_at(d))
      end
    end
    side = -side
  end
  ::continue::
end
-- paint far to near (bottoms higher first); sky things first of all
for _, el in ipairs(ELS) do
  el.order = (el.e.kind == "sun" or el.e.kind == "moon") and -1 or ((el.e.kind == "mountain") and 0 or el.by)
end
table.sort(ELS, function(a, b) return a.order < b.order end)
for i, el in ipairs(ELS) do el.i = i end

-- each kind built from parts; c names the colour: main, second, skin, dark, glow, glow2
function rot(px, py, cx, cy, t)
  local c, s = math.cos(t), math.sin(t)
  local dx, dy = px - cx, py - cy
  return {cx + dx * c - dy * s, cy + dx * s + dy * c}
end
-- a drawing from the model: {wp, parts={{shape, x, y, w, h, tilt, colour}, ...}} in percent of the box
function build_drawn(el, d)
  local x0, y0 = el.cx - el.w / 2, el.by - el.h
  local P, all = {}, nil
  for _, q in ipairs(d.parts or {}) do
    local sh, px, py, pw, ph, tilt, col = q[1], q[2], q[3], q[4], q[5], q[6] or 0, q[7]
    local cx, cy = x0 + px / 100 * el.w, y0 + py / 100 * el.h
    local w, h = math.max(3, pw / 100 * el.w), math.max(3, ph / 100 * el.h)
    local t = tilt * math.pi / 180
    local m
    if sh == "circle" then
      local r = math.min(w, h) / 2
      m = ellipse(cx, cy, r, r)
    elseif sh == "oval" then
      if tilt == 0 then m = ellipse(cx, cy, w / 2, h / 2) else
        local pts = {}
        for a = 0, 15 do local u = a / 16 * 2 * math.pi; pts[#pts + 1] = rot(cx + math.cos(u) * w / 2, cy + math.sin(u) * h / 2, cx, cy, t) end
        m = poly(pts, true)
      end
    elseif sh == "triangle" then
      m = poly({rot(cx - w / 2, cy + h / 2, cx, cy, t), rot(cx + w / 2, cy + h / 2, cx, cy, t), rot(cx, cy - h / 2, cx, cy, t)})
    elseif sh == "line" then
      local len, th = math.max(w, h), math.max(3, math.min(w, h))
      local a, b
      if w >= h then a, b = rot(cx - len / 2, cy, cx, cy, t), rot(cx + len / 2, cy, cx, cy, t)
      else a, b = rot(cx, cy - len / 2, cx, cy, t), rot(cx, cy + len / 2, cx, cy, t) end
      m = ribbon({a, b}, th)
    else
      m = poly({rot(cx - w / 2, cy - h / 2, cx, cy, t), rot(cx + w / 2, cy - h / 2, cx, cy, t), rot(cx + w / 2, cy + h / 2, cx, cy, t), rot(cx - w / 2, cy + h / 2, cx, cy, t)})
    end
    P[#P + 1] = {m=m, c="part", list=color(col)}
    all = all and (all + m) or m
  end
  el.parts, el.all = P, all
end
function build(el)
  if el.e.drawing then return build_drawn(el, el.e.drawing) end
  local e, cx, by, w, h = el.e, el.cx, el.by, el.w, el.h
  local P = {}
  local function add(m, c) P[#P + 1] = {m=m, c=c} end
  local face = (cx > 500) and -1 or 1
  local k = e.kind
  if k == "person" then
    local sc = h / 240
    add(poly({{cx - 30 * sc, by - 205 * sc}, {cx + 30 * sc, by - 205 * sc}, {cx + 44 * sc, by - 70 * sc}, {cx - 44 * sc, by - 70 * sc}}, true), "main")
    add(ribbon({{cx - 14 * sc, by - 75 * sc}, {cx - 17 * sc, by}}, 12 * sc) + ribbon({{cx + 14 * sc, by - 75 * sc}, {cx + 18 * sc, by}}, 12 * sc), "second")
    add(ellipse(cx, by - 228 * sc, 17 * sc, 21 * sc), "skin")
  elseif k == "animal" then
    local bw, bh = w * 0.42, h * 0.3
    local bodyy = by - h * 0.42
    add(ellipse(cx, bodyy, bw, bh):roughen(math.max(2, w * 0.015), 30, S.seed + el.i), "main")
    local legs = nil
    for _, f in ipairs({-0.7, -0.4, 0.4, 0.7}) do
      local l = ribbon({{cx + f * bw, bodyy + bh * 0.5}, {cx + f * bw + 2, by}}, math.max(4, w * 0.06))
      legs = legs and (legs + l) or l
    end
    add(legs, "dark")
    add(ribbon({{cx - face * bw * 0.95, bodyy - bh * 0.2}, {cx - face * bw * 1.25, bodyy - bh * 0.9}}, {math.max(4, w * 0.05), 2}), "main")
    add(ellipse(cx + face * bw * 1.05, bodyy - bh * 0.75, w * 0.17, h * 0.17) + ellipse(cx + face * bw * 0.95, bodyy - bh * 1.25, w * 0.05, h * 0.08), "main")
  elseif k == "tree" then
    local th = h * 0.45
    add(poly({{cx - w * 0.07, by}, {cx + w * 0.07, by}, {cx + w * 0.04, by - th}, {cx - w * 0.04, by - th}}), "second")
    local cy = by - th - (h - th) * 0.42
    local c = ellipse(cx, cy, w * 0.45, (h - th) * 0.5)
    for j = 1, 3 do c = c + ellipse(cx + rand(-0.3, 0.3) * w, cy + rand(-0.2, 0.2) * h, w * rand(0.2, 0.3), h * rand(0.12, 0.2)) end
    add(c:roughen(math.max(6, w * 0.05), math.max(25, w * 0.2), S.seed + el.i):soften(5), "main")
  elseif k == "plant" then
    add(ribbon({{cx, by}, {cx + rand(-8, 8), by - h * 0.55}}, math.max(3, w * 0.06)), "dark")
    add(ellipse(cx, by - h * 0.45, w * 0.45, h * 0.25):roughen(math.max(3, w * 0.04), 25, S.seed + el.i), "main")
    add(ellipse(cx, by - h * 0.78, w * 0.22, h * 0.2), "second")
  elseif k == "building" then
    add(rect(cx - w / 2, by - h, w, h), "main")
    local win = nil
    local cols, rows = math.max(2, math.floor(w / 45)), math.max(2, math.floor(h / 55))
    for r = 1, rows do for c = 1, cols do
      local wr = rect(cx - w / 2 + (c - 0.72) * w / cols, by - h + (r - 0.75) * h / rows, w / cols * 0.45, h / rows * 0.4)
      win = win and (win + wr) or wr
    end end
    add(win, NIGHT and "glow2" or "second")
  elseif k == "vehicle" then
    add(poly({{cx - w / 2, by - h * 0.2}, {cx + w / 2, by - h * 0.2}, {cx + w / 2, by - h * 0.65}, {cx + w * 0.25, by - h}, {cx - w * 0.35, by - h}, {cx - w / 2, by - h * 0.7}}, true), "main")
    add(rect(cx - w * 0.3, by - h * 0.9, w * 0.5, h * 0.25), (NIGHT or S.time == "dusk") and "glow2" or "second")
    add(ellipse(cx - w * 0.3, by - h * 0.15, h * 0.17, h * 0.17) + ellipse(cx + w * 0.3, by - h * 0.15, h * 0.17, h * 0.17), "dark")
  elseif k == "furniture" then
    if has(e.name, {"table", "desk", "counter"}) then
      add(rect(cx - w / 2, by - h, w, h * 0.12), "main")
      add(rect(cx - w * 0.45, by - h * 0.9, w * 0.06, h * 0.9) + rect(cx + w * 0.39, by - h * 0.9, w * 0.06, h * 0.9), "dark")
    elseif has(e.name, {"couch", "sofa", "bed"}) then
      add(rect(cx - w / 2, by - h * 0.55, w, h * 0.42) + rect(cx - w / 2, by - h, w, h * 0.5), "main")
      add(rect(cx - w / 2 + 10, by - h * 0.6, w - 20, h * 0.12), "second")
      add(rect(cx - w / 2, by - h * 0.13, w * 0.05, h * 0.13) + rect(cx + w * 0.45, by - h * 0.13, w * 0.05, h * 0.13), "dark")
    elseif has(e.name, {"chair", "bench", "stool"}) then
      add(rect(cx - w / 2, by - h * 0.5, w, h * 0.1) + rect(cx - w / 2, by - h, w * 0.1, h * 0.55), "main")
      add(rect(cx - w * 0.45, by - h * 0.42, w * 0.07, h * 0.42) + rect(cx + w * 0.38, by - h * 0.42, w * 0.07, h * 0.42), "dark")
    else
      add(rect(cx - w / 2, by - h, w, h), "main")
      add(rect(cx - w / 2 + w * 0.08, by - h * 0.85, w * 0.84, h * 0.3), "second")
    end
  elseif k == "food" then
    if has(e.name, {"ice cream", "icecream", "cone", "gelato"}) then
      add(poly({{cx - w * 0.28, by - h * 0.52}, {cx + w * 0.28, by - h * 0.52}, {cx + w * 0.03, by}, {cx - w * 0.03, by}}), "cone")
      add(ellipse(cx, by - h * 0.62, w * 0.36, h * 0.17) + ellipse(cx, by - h * 0.8, w * 0.28, h * 0.15), "main")
    elseif has(e.name, {"hot dog", "hotdog", "sandwich", "burger"}) then
      add(ellipse(cx, by - h * 0.35, w * 0.5, h * 0.3), "cone")
      add(ribbon({{cx - w * 0.55, by - h * 0.5}, {cx + w * 0.55, by - h * 0.5}}, h * 0.18), "main")
    elseif has(e.name, {"cake", "pizza", "pie", "slice"}) then
      add(poly({{cx - w / 2, by}, {cx + w / 2, by}, {cx + w / 2, by - h * 0.6}, {cx - w * 0.3, by - h * 0.6}}), "main")
      add(rect(cx - w * 0.3, by - h * 0.7, w * 0.8, h * 0.12), "second")
    else
      add(ellipse(cx, by - h * 0.12, w * 0.6, h * 0.12), "plate")
      add(ellipse(cx, by - h * 0.4, w * 0.4, h * 0.3):roughen(3, 20, S.seed + el.i), "main")
    end
  elseif k == "drink" then
    local rim = math.max(4, h * 0.1)
    add(rect(cx - w / 2, by - h + rim, w, h - rim * 1.5) + ellipse(cx, by - rim, w / 2, rim), "main")
    add(ribbon({{cx + w / 2, by - h * 0.7}, {cx + w * 0.78, by - h * 0.55}, {cx + w / 2, by - h * 0.3}}, math.max(3, w * 0.09)), "main")
    add(ellipse(cx, by - h + rim, w / 2, rim), "second")
    if has(e.name, {"steam", "hot", "tea", "coffee", "cocoa"}) then el.steam = true end
  elseif k == "screen" then
    if has(e.name, {"laptop", "notebook"}) then
      add(poly({{cx - w / 2, by - h * 0.08}, {cx + w / 2, by - h * 0.08}, {cx + w * 0.42, by - h}, {cx - w * 0.42, by - h}}), "main")
      add(poly({{cx - w * 0.43, by - h * 0.14}, {cx + w * 0.43, by - h * 0.14}, {cx + w * 0.36, by - h * 0.93}, {cx - w * 0.36, by - h * 0.93}}), "glow2")
      add(rect(cx - w * 0.6, by - h * 0.08, w * 1.2, h * 0.08), "dark")
    else
      add(rect(cx - w / 2, by - h, w, h * 0.85), "main")
      add(rect(cx - w * 0.44, by - h * 0.94, w * 0.88, h * 0.73), "glow2")
      add(rect(cx - w * 0.06, by - h * 0.15, w * 0.12, h * 0.15), "dark")
    end
  elseif k == "lamp" then
    add(ribbon({{cx, by}, {cx, by - h * 0.8}}, math.max(3, w * 0.12)), "dark")
    add(poly({{cx - w * 0.5, by - h * 0.72}, {cx + w * 0.5, by - h * 0.72}, {cx + w * 0.25, by - h}, {cx - w * 0.25, by - h}}), "glow")
  elseif k == "window" then
    local fr = math.max(6, math.min(w, h) * 0.07)
    local pane = rect(cx - w / 2 + fr, by - h + fr, w - 2 * fr, h - 2 * fr)
    local bars = rect(cx - fr / 3, by - h, fr * 0.66, h) + rect(cx - w / 2, by - h / 2 - fr / 3, w, fr * 0.66)
    add(rect(cx - w / 2, by - h, w, h) - (pane - bars), "main")
    add(pane - bars, "view")
  elseif k == "mountain" then
    local peak = cx + rand(-0.1, 0.1) * w
    add(poly({{cx - w / 2, by}, {cx + w / 2, by}, {peak, by - h}}), "main")
    add(poly({{peak - w * 0.09, by - h * 0.8}, {peak + w * 0.09, by - h * 0.8}, {peak, by - h}}), "second")
  elseif k == "sun" or k == "moon" then
    add(ellipse(cx, by, h / 2, h / 2):soften(3), "glow")
  else -- object
    if has(e.name, {"book", "notebook", "letter"}) then
      add(rect(cx - w / 2, by - h * 0.3, w, h * 0.3), "main")
      add(rect(cx - w / 2 + 4, by - h * 0.24, w - 8, h * 0.08), "pages")
    elseif has(e.name, {"phone"}) then
      add(rect(cx - w * 0.25, by - h, w * 0.5, h), "dark")
      add(rect(cx - w * 0.2, by - h * 0.93, w * 0.4, h * 0.86), "glow2")
    else
      add(rect(cx - w / 2, by - h, w, h), "main")
      add(rect(cx - w / 2, by - h * 0.6, w, h * 0.18), "second")
    end
  end
  el.parts = P
  local all = nil
  for _, p in ipairs(P) do all = all and (all + p.m) or p.m end
  el.all = all
end
for _, el in ipairs(ELS) do build(el) end
ALL = nil
for _, el in ipairs(ELS) do if el.all then ALL = ALL and (ALL + el.all) or el.all end end
function clean(m) if ALL then return m - ALL:grow(3) end return m end
CLIP = ALL and true or nil

--@ chunk
-- the backdrop: sky or back wall, graded toward the light
upper = color(S.upper)
back = above(function(x) return H + 10 end):soften(20)
if S.indoor then
  wall_lit = paint_of(lighter(upper, 0.6))
  wall_dark = paint_of(shade(upper))
  local lit = function(x, y) return clamp(0.5 + LX * (x - 500) / 900, 0, 1) end
  work(clean(back), {clip=CLIP, hand="broad", angle=math.pi / 2, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(60, 160),
       piles={{wall_dark, function(x, y) return 1 - lit(x, y) end}, {wall_lit, lit}}})
else
  sky_top = paint_of(merge(upper, 1 - GREY, OVERCAST, GREY))
  local low = WARM and merge(upper, 0.4, {{"lead white", 2}, {"vermilion", 0.25}, {"chrome yellow", 0.5}}, 0.6) or lighter(upper, 1.2)
  sky_low = paint_of(merge(low, 1 - GREY, OVERCAST, GREY))
  if WARM and GREY < 0.5 then
    work(clean(back * above(function(x) return H * 0.62 end):soften(60)), {clip=CLIP, hand="broad", pile=sky_top, angle=0.03, coverage=C(2), fill=FILL, scale_at=SIZE})
    work(clean(back * below(function(x) return H * 0.5 end):soften(60)), {clip=CLIP, hand="broad", pile=sky_low, angle=0.03, coverage=C(2), fill=FILL, scale_at=SIZE})
  else
    work(clean(back), {clip=CLIP, hand="broad", angle=0.03, coverage=C(2), fill=FILL, scale_at=SIZE,
         piles={{sky_top, function(x, y) return clamp(1 - y / H, 0, 1) end}, {sky_low, function(x, y) return clamp(y / H, 0, 1) end}}})
  end
  if S.weather ~= "clear" and S.weather ~= "fog" and H > 250 then
    cloud_paint = paint_of(merge(NIGHT and {{"lead white", 1.4}, {"Prussian blue", 0.3}, {"raw umber", 0.25}} or {{"lead white", 4}, {"yellow ochre", 0.05}}, 1 - GREY * 0.6, OVERCAST, GREY * 0.6))
    clouds = nil
    for i = 1, math.floor(rand(3, 6)) do
      local cx, cy, rx, ry = rand(60, 940), rand(60, math.max(100, H - 140)), rand(70, 180), rand(26, 46)
      local c = ellipse(cx, cy, rx, ry) + ellipse(cx + rand(-rx, rx) * 0.5, cy - ry * 0.5, rx * 0.55, ry * 1.1)
      clouds = clouds and (clouds + c) or c
    end
    clouds = clouds:roughen(16, 65, S.seed + 3):soften(12)
    work(clean(clouds * back), {clip=CLIP, hand="body", pile=cloud_paint, angle=0.05, coverage=C(1.7), fill=FILL, scale_at=SIZE, length=L(28, 66)})
    blend(clean(clouds:grow(22) * back), {angle=0.05})
  end
end

--@ chunk
-- the ground or floor, brushed as what it is, with the elements' shadows
lower = color(S.lower)
if S.surface == "snow" then lower = merge(lower, 0.3, {{"lead white", 3}, {"cobalt blue", 0.1}}, 0.7) end
floor = below(function(x) return H end):soften(S.indoor and 4 or 16)
near = paint_of(merge(shade(lower), 1 - GREY * 0.3, OVERCAST, GREY * 0.3))
far = paint_of(merge(S.indoor and lower or lighter(lower, 0.5), 1 - GREY * 0.3, OVERCAST, GREY * 0.3))
HANDLING = ({grass={angle=0.08, len={40, 110}, hand="body"}, water={angle=0, len={60, 160}, hand="body"},
             sand={angle=0.05, len={30, 80}, hand="body"}, road={angle=0, len={50, 140}, hand="broad"},
             snow={angle=0.05, len={40, 110}, hand="body"}, wood={angle=0, len={80, 220}, hand="body"},
             tiles={angle=0, len={20, 50}, hand="body"}, carpet={angle=0.3, len={10, 30}, hand="body"},
             stone={angle=0.2, len={20, 45}, hand="body"}})[S.surface] or {angle=0.05, len={30, 90}, hand="body"}
depth = 1000 - H
work(clean(floor), {clip=CLIP, hand=HANDLING.hand, angle=HANDLING.angle, coverage=C(2), fill=FILL, scale_at=SIZE, length=L(HANDLING.len[1], HANDLING.len[2]),
     piles={{far, function(x, y) return clamp(1 - (y - H) / depth, 0, 1) end}, {near, function(x, y) return clamp((y - H) / depth, 0, 1) end}}})
if S.indoor then
  -- where wall meets floor
  skirting = paint_of(shade(shade(upper)))
  work(clean(ribbon({{-10, H}, {1010, H}}, 6)), {clip=true, hand="detail", pile=skirting, coverage=2.2, fill=true})
end
-- cast shadows: on the ground beside things standing on it, away from the light
shadow = paint_of(shade(shade(lower)))
for _, el in ipairs(ELS) do
  local kk = el.e.kind
  if el.by > H + 10 and kk ~= "window" and kk ~= "sun" and kk ~= "moon" and kk ~= "mountain" and el.by < 1000 then
    local sw = el.w * 0.55
    local sh = math.max(8, math.min(el.w * 0.12, (el.by - H) * 0.25))
    local m = ellipse(el.cx - LX * sw * 0.35, el.by, sw, sh):soften(6) * floor
    work(clean(m), {clip=true, hand="body", pile=shadow, coverage=1.6, fill=true, length={10, 30}})
  end
end

--@ chunk
-- the elements, far to near, each on clean canvas, lit from the light's side
palette{scrape=BG}
function lit_at(el)
  local cx, cy, r = el.cx, el.by - el.h / 2, math.max(el.w, el.h)
  return function(x, y) return clamp(0.5 + LX * (x - cx) / r * 1.2 - (y - cy) / r * 0.6, 0, 1) end
end
FIXED = {skin={{"lead white", 2}, {"yellow ochre", 0.4}, {"vermilion", 0.12}, {"chrome yellow", 0.03}},
         cone={{"yellow ochre", 1}, {"red earth", 0.25}, {"lead white", 0.9}},
         plate={{"lead white", 3}, {"cobalt blue", 0.05}},
         pages={{"lead white", 3}, {"yellow ochre", 0.15}}}
for n, el in ipairs(ELS) do
  local e = el.e
  local nearer = nil
  for m = n + 1, #ELS do if ELS[m].all then nearer = nearer and (nearer + ELS[m].all) or ELS[m].all end end
  local lit = lit_at(el)
  for j, part in ipairs(el.parts) do
    -- the later parts of this element, and nearer elements, are reserved
    local m = part.m
    for q = j + 1, #el.parts do m = m - el.parts[q].m end
    if nearer then m = m - nearer:grow(2) end
    local used = {}
    local c = part.c
    local list = (c == "second" or c == "glow2" or c == "view") and color(e.second) or color(e.color)
    if FIXED[c] then list = FIXED[c] end
    if part.list then list = part.list end
    if c == "dark" then list = shade(shade(color(e.color))) end
    if c == "view" and NIGHT then list = shade(list) end
    local glow = c == "glow" or c == "glow2"
    local lp, dp
    if glow then
      lp = paint_of(lighter(list, 1.6), {fg=true, keep=true, mute=0, pure=true, list=used}); dp = lp
    else
      lp = paint_of(list, {fg=true, list=used}); dp = paint_of(shade(list), {fg=true, list=used})
    end
    local small = math.min(el.w, el.h)
    local hand = (small < 70 or c == "dark" or c == "skin") and "detail" or "body"
    local angle = (e.kind == "person" or e.kind == "lamp" or e.kind == "drink" or e.kind == "building") and math.pi / 2 or jit(0.4, 0.3)
    work(m, {hand=hand, angle=angle, coverage=2.4, fill=true, clip=true, length=(hand == "body") and L(10, 32) or nil,
         piles={{dp, function(x, y) return 1 - lit(x, y) end}, {lp, lit}}})
    if glow then
      local halo = paint_of(lighter(list, 2.4), {fg=true, keep=true, mute=0, pure=true, list=used})
      local g = part.m:grow(math.max(18, small * 0.25)):soften(18) - el.all
      if nearer then g = g - nearer end
      work(g, {hand="glaze", pile=halo, coverage=1})
    end
    palette{scrape=used}
  end
  if el.steam then
    local st = paint_of({{"lead white", 3}, {"cobalt blue", 0.03}}, {fg=true, keep=true, mute=0})
    local s1 = ribbon({{el.cx - el.w * 0.15, el.by - el.h * 1.05}, {el.cx, el.by - el.h * 1.3}, {el.cx - el.w * 0.1, el.by - el.h * 1.6}}, {6, 4, 1})
    work(s1 - (nearer or s1:shrink(1000)), {hand="glaze", pile=st, coverage=1})
    palette{scrape={st}}
  end
end

--@ chunk
-- the weather over everything (outdoors)
if not S.indoor then
  if S.weather == "rain" then
    rain = paint_of({{"lead white", 2}, {"cobalt blue", 0.15}, {"raw umber", 0.08}}, {fg=true, keep=true})
    work(everywhere(), {hand="hatch", pile=rain, angle=jit(1.35, 0.12), coverage=0.18, length={20, 60}, pressure={0.2, 0.4}})
  elseif S.weather == "snow" then
    b = brush{kind="round", width=5, point=0.5}
    flake = paint_of({{"lead white", 4}, {"cobalt blue", 0.03}}, {fg=true, keep=true})
    for i = 1, math.floor(rand(70, 120)) do
      local x, y = rand(10, 990), rand(10, 990)
      b:load(flake, 0.5)
      b:gesture({{x, y, 0.6}, {x + 2, y + 2, 0.3}})
    end
  elseif S.weather == "fog" then
    fog = paint_of({{"lead white", 3}, {"raw umber", 0.05}, {"cobalt blue", 0.04}}, {fg=true, keep=true})
    work(above(function(x) return H + 160 end) * below(function(x) return H - 200 end):soften(80), {hand="glaze", pile=fog, coverage=1})
  end
end

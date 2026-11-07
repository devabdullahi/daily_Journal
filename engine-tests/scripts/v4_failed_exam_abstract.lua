-- Entry: "had a bad day today i failed my exam"  (abstract: paint the feeling, not the scene)
-- Reading: disappointment, deflation, a little shame. valence -0.7, energy 0.3, intensity 0.7.
-- Arc: expectation -> collapse. Texture: heavy, sinking, cut.
-- Mapping: pale washed hope at the top; a heavy cool dark mass pressing down from below;
-- downward strokes (sinking); one knife cut through the mass (the break); a rag wipe (numbness).
--@ chunk
canvas{size=300, aspect=1, linen=16, seed=23,
       ground={{pile={{"lead white", 4}, {"raw umber", 0.3}}, um=60, apply="knife", texture=0.4}}}

--@ chunk
-- what was hoped: a pale, thin, washed-out light across the top
hope = pile{{"lead white", 3}, {"yellow ochre", 0.15}, {"cobalt blue", 0.08}}
top_band = above(function(x) return 380 + 40 * math.sin(x / 160) end):soften(60)
work(top_band, {hand="broad", pile=hope, angle=0.02, coverage=1.8, fill=true})

--@ chunk
-- the weight: a heavy cool dark mass pressing up from below, strokes falling downward
heavy = pile{{"Prussian blue", 1}, {"raw umber", 1.2}, {"bone black", 0.4}, {"lead white", 0.3}}
grey = pile{{"raw umber", 1}, {"lead white", 1.4}, {"cobalt blue", 0.4}}
mass = below(function(x) return 330 + 70 * math.sin(x / 210 + 1) end):soften(50)
depth = function(x, y) return clamp((y - 320) / 600, 0, 1) end
work(mass, {hand="body", angle=function(x, y) return math.pi / 2 + 0.25 * math.sin(x / 90) end,
            coverage=2.2, fill=true, length={60, 160},
            piles={{grey, function(x, y) return 1 - depth(x, y) end}, {heavy, depth}}})

--@ chunk
-- sinking: a few long, slow, heavy strokes dragged downward through the wet mass
b = brush{kind="flat", width=26, lay=4}
for i = 1, 7 do
  local x = 120 + i * 110 + rand(-25, 25)
  b:reload(heavy, 0.9)
  b:gesture({{x, 360 + rand(0, 60), 0.4}, {x + rand(-20, 20), 620, 0.9}, {x + rand(-30, 30), 960, 0.6}}, {wobble=12})
end

--@ chunk
-- the break: one knife cut scraped through the dark, exposing the pale beneath
k = knife{width=40}
k:scrape({{180, 520}, {520, 700}, {860, 640}}, {pressure=0.8})

--@ chunk
-- numbness: a rag wiped across part of the mass, thinning it to a dull veil
r = rag()
r:wipe(ellipse(640, 820, 220, 90):soften(50), {pressure=0.5, angle=0.1, passes=1})

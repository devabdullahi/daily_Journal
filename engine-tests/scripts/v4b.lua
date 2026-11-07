--@ engine 9
--@ knife-skim
--@ palette-carried-paint
--@ limbs-join-nearest
--@ reload-finite
--@ blend-feather
--@ brush-skim
--@ blend-at-masks
--@ glaze-film
--@ liquid-film-levels
--@ sealed-drawing-guide
--@ drawing-optics
--@ rag-lift
--@ full-palette-refuses
--@ pastel-current-heap
--@ calls-agree
--@ drain
--@ paper
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
work(mass, {hand="body", angle=function(x, y) return 0.35 + 0.3 * math.sin(x / 140 + y / 200) end,
            coverage=2.2, fill=true, length={70, 180}, edge="lost",
            piles={{grey, function(x, y) return 1 - depth(x, y) end}, {heavy, depth}}})

--@ chunk
-- sinking: a few irregular heavy drags, different widths, starting inside the mass
for i = 1, 5 do
  local b = brush{kind="flat", width=rand(14, 34), lay=3}
  local x = rand(150, 850)
  local y0 = rand(480, 620)
  b:reload(heavy, rand(0.6, 0.95))
  b:gesture({{x, y0, 0.5}, {x + rand(-60, 60), y0 + rand(120, 200), 0.9}, {x + rand(-90, 90), y0 + rand(260, 360), 0.3}}, {wobble=3})
end

-- the break: one knife-laid slash of the pale hope colour cutting across the dark
k = knife{width=34}
k:load(hope, 1)
k:lay({{160, 610}, {470, 700}, {820, 660}}, {pressure={0.5, 0.8}, angle=1.2})

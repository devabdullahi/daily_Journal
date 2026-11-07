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
-- Entry: "today was amazing i went to the park and ate some icecream"
-- Reading: joy, lightness, summer afternoon, outdoors. Strongest image: an ice cream in the park.
-- Emotion via light/colour: warm sunlight, clear blue sky, fresh yellow-greens, high key, no heavy darks.
-- Composition: cone rising from the bottom edge (held, hand implied), sunny park behind.
--@ chunk
canvas{size=300, aspect=1, linen=16, seed=31,
       ground={{pile={{"lead white", 4}, {"yellow ochre", 0.15}}, um=60, apply="knife", texture=0.3}}}

--@ chunk
-- sky: clear blue at the top, pale and warm near the horizon, painted as one graded passage
sky = above(function(x) return 470 end):soften(30)
sky_top = pile{{"cobalt blue", 1}, {"lead white", 2.2}}
sky_low = pile{{"lead white", 3}, {"cobalt blue", 0.25}, {"yellow ochre", 0.08}}
work(sky, {hand="broad", angle=0.03, coverage=2, fill=true,
           piles={{sky_top, function(x, y) return clamp(1 - y / 460, 0, 1) end},
                  {sky_low, function(x, y) return clamp(y / 460, 0, 1) end}}})
-- a few soft summer clouds
cloud = pile{{"lead white", 4}, {"yellow ochre", 0.05}}
clouds = (ellipse(210, 150, 120, 38) + ellipse(290, 130, 80, 45) + ellipse(760, 210, 140, 34) + ellipse(840, 190, 70, 40)):roughen(14, 60, 5):soften(10)
work(clouds, {hand="body", pile=cloud, angle=0.05, coverage=1.6, fill=true, length={25, 60}})
blend(clouds:grow(20), {angle=0.05})

--@ chunk
-- distant tree line: soft blue-greens (aerial perspective), irregular top
far_line = outline{{0, 430}, {120, 400}, {260, 425}, {380, 395}, {520, 420}, {700, 390}, {860, 415}, {1000, 400}, open=true}
far_trees = far_line:below() * above(function(x) return 500 end):soften(20)
far_green = pile{{"Prussian blue", 0.4}, {"chrome yellow", 0.6}, {"lead white", 1.4}, {"raw umber", 0.15}}
work(far_trees, {hand="body", pile=far_green, angle=0.2, coverage=2, fill=true, length={20, 50}, edge="soft"})

--@ chunk
-- sunlit grass: bright yellow-green near the light, fresher green toward the bottom
grass = below(function(x) return 480 end):soften(20)
grass_lit = pile{{"chrome yellow", 1}, {"Prussian blue", 0.18}, {"lead white", 0.8}}
grass_deep = pile{{"chrome yellow", 1}, {"Prussian blue", 0.4}, {"lead white", 0.3}}
work(grass, {hand="body", angle=0.08, coverage=2, fill=true, length={40, 110},
             piles={{grass_lit, function(x, y) return clamp(1 - (y - 480) / 520, 0, 1) end},
                    {grass_deep, function(x, y) return clamp((y - 480) / 520, 0, 1) end}}})
-- a winding warm path
path = ribbon({{1000, 520}, {760, 600}, {560, 700}, {330, 840}, {140, 1000}}, {20, 50, 80, 120, 170}):roughen(8, 50, 7)
path_paint = pile{{"lead white", 2}, {"yellow ochre", 0.7}, {"red earth", 0.08}}
work(path, {hand="body", pile=path_paint, angle=-0.5, coverage=2, fill=true, clip=true, length={30, 80}})

--@ chunk
-- one leafy tree on the left: trunk, then a canopy lit from the upper right
trunk = poly({{150, 700}, {190, 700}, {182, 460}, {160, 460}})
bark = pile{{"raw umber", 1}, {"red earth", 0.3}, {"lead white", 0.3}}
work(trunk, {hand="body", pile=bark, angle=math.pi / 2, coverage=2.2, fill=true, clip=true})
canopy = (ellipse(170, 380, 150, 120) + ellipse(90, 430, 90, 70) + ellipse(260, 420, 90, 75)):roughen(22, 70, 9):soften(6)
leaf_shade = pile{{"Prussian blue", 0.6}, {"chrome yellow", 1}, {"raw umber", 0.25}, {"lead white", 0.2}}
leaf_lit = pile{{"chrome yellow", 1}, {"Prussian blue", 0.2}, {"lead white", 0.7}}
lit = function(x, y) return clamp(0.5 + (x - 170) / 300 - (y - 380) / 300, 0, 1) end
work(canopy, {hand="body", angle=0.6, coverage=2.4, fill=true, length={14, 34},
              piles={{leaf_shade, function(x, y) return 1 - lit(x, y) end}, {leaf_lit, lit}}})
--@ chunk
-- the waffle cone, rising from the bottom edge (tip cropped: it's being held)
cone = poly({{430, 700}, {610, 700}, {548, 1010}, {492, 1010}})
waffle = pile{{"yellow ochre", 1}, {"red earth", 0.25}, {"lead white", 0.9}}
work(cone, {hand="body", pile=waffle, angle=0, coverage=2.4, fill=true, clip=true, length={20, 50}})
grid_paint = pile{{"red earth", 0.6}, {"raw umber", 0.5}, {"yellow ochre", 0.6}}
work(cone:shrink(6), {hand="hatch", pile=grid_paint, angle=0.85, coverage=0.5, clip=true})
work(cone:shrink(6), {hand="hatch", pile=grid_paint, angle=-0.85, coverage=0.5, clip=true})

--@ chunk
-- the background is done: scrape its piles off the palette (it holds 16)
palette{scrape={sky_top, sky_low, cloud, far_green, grass_lit, grass_deep, path_paint, bark}}
-- the background is done: scrape its piles off the palette (it holds 16)
palette{scrape={sky_top, sky_low, cloud, far_green, grass_lit, grass_deep, path_paint, bark}}
-- two scoops: strawberry below, mint on top, lit from the upper right
pink = pile{{"lead white", 3}, {"vermilion", 0.45}}
pink_shade = pile{{"lead white", 2}, {"vermilion", 0.6}, {"red earth", 0.15}}
scoop1 = (ellipse(520, 665, 118, 72) + ellipse(450, 700, 40, 26) + ellipse(600, 698, 38, 24)):roughen(10, 40, 12):soften(4)
s1lit = function(x, y) return clamp(0.55 + (x - 520) / 240 - (y - 660) / 160, 0, 1) end
work(scoop1, {hand="body", coverage=2.4, fill=true, clip=true, length={14, 30}, angle=0.3,
              piles={{pink_shade, function(x, y) return 1 - s1lit(x, y) end}, {pink, s1lit}}})
mint = pile{{"lead white", 3}, {"Rinmann's green", 0.6}, {"chrome yellow", 0.1}}
mint_shade = pile{{"lead white", 2}, {"Rinmann's green", 0.8}, {"cobalt blue", 0.1}}
scoop2 = ellipse(515, 575, 98, 72):roughen(10, 40, 13):soften(4)
s2lit = function(x, y) return clamp(0.55 + (x - 515) / 200 - (y - 570) / 150, 0, 1) end
work(scoop2, {hand="body", coverage=2.4, fill=true, clip=true, length={12, 28}, angle=0.3,
              piles={{mint_shade, function(x, y) return 1 - s2lit(x, y) end}, {mint, s2lit}}})
-- a little melting drip, and sunlit highlights
drip = ribbon({{575, 715}, {580, 745}, {578, 770}}, {10, 8, 6})
work(drip, {hand="detail", pile=pink, coverage=2.5, fill=true, clip=true})
hi = pile{{"lead white", 4}, {"chrome yellow", 0.05}}
b = brush{kind="round", width=7, point=0.5}
b:load(hi, 0.7)
b:gesture({{545, 540, 0.3}, {570, 548, 0.8}, {585, 565, 0.2}})
b:load(hi, 0.6)
b:gesture({{555, 628, 0.3}, {585, 640, 0.7}, {598, 660, 0.2}})

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
-- v7 SKY PLATE (chunks up to the sky, no clouds). v7: clouds in their own chunk for the living-painting sky plate. v6: colour rules from color2oilpaint (warm-white touch, complement/earth muting, no black darks); reserved shapes for the ice cream and path, brighter warmer greens
-- Entry: "today was amazing i went to the park and ate some icecream"
-- Reading: joy, lightness, summer afternoon, outdoors. Strongest image: an ice cream in the park.
-- Emotion via light/colour: warm sunlight, clear blue sky, fresh yellow-greens, high key, no heavy darks.
-- Composition: cone rising from the bottom edge (held, hand implied), sunny park behind.
--@ chunk
canvas{size=300, aspect=1, linen=16, seed=31,
       ground={{pile={{"lead white", 4}, {"yellow ochre", 0.15}}, um=60, apply="knife", texture=0.3}}}

--@ chunk
-- reserved shapes: painted later on clean ground, never over wet grass
path = ribbon({{1000, 520}, {760, 600}, {560, 700}, {330, 840}, {140, 1000}}, {20, 50, 80, 120, 170}):roughen(8, 50, 7)
cone = poly({{430, 700}, {610, 700}, {548, 1010}, {492, 1010}})
scoop1 = (ellipse(520, 665, 118, 72) + ellipse(450, 700, 40, 26) + ellipse(600, 698, 38, 24)):roughen(10, 40, 12):soften(4)
scoop2 = ellipse(515, 575, 98, 72):roughen(10, 40, 13):soften(4)
icecream = (cone + scoop1 + scoop2):grow(4)

--@ chunk
-- sky: clear blue at the top, pale and warm near the horizon, painted as one graded passage
sky = above(function(x) return 470 end):soften(30)
sky_top = pile{{"cobalt blue", 1}, {"lead white", 2.2}}
sky_low = pile{{"lead white", 3}, {"cobalt blue", 0.25}, {"yellow ochre", 0.08}}
work(sky, {hand="broad", angle=0.03, coverage=2, fill=true,
           piles={{sky_top, function(x, y) return clamp(1 - y / 460, 0, 1) end},
                  {sky_low, function(x, y) return clamp(y / 460, 0, 1) end}}})

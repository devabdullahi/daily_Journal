-- Day tile v2: same entry, better technique (fill gaps, separate sky bands, blend, glaze light)
--@ chunk
canvas{size=300, aspect=1, linen=16, seed=7,
       ground={{pile={{"lead white", 4}, {"red earth", 0.15}}, um=60, apply="knife", texture=0.3}}}

--@ chunk
horizon = outline{{0, 640}, {300, 622}, {650, 648}, {1000, 632}, open=true}
sky = horizon:above()
land = horizon:below()
-- sky in three bands with soft overlaps, so blue never mixes into orange
high = sky * above(function(x) return 260 end):soften(80)
mid = sky * below(function(x) return 200 end):soften(80) * above(function(x) return 470 end):soften(80)
low = sky * below(function(x) return 420 end):soften(60)
blue = pile{{"cobalt blue", 1}, {"lead white", 2.5}}
rose = pile{{"lead white", 3}, {"vermilion", 0.35}, {"cobalt blue", 0.1}}
amber = pile{{"chrome yellow", 1}, {"vermilion", 0.7}, {"lead white", 1.2}}
work(high, {hand="broad", pile=blue, angle=0.05, coverage=2, fill=true})
work(mid, {hand="broad", pile=rose, angle=0.05, coverage=2, fill=true})
work(low, {hand="broad", pile=amber, angle=0.03, coverage=2.2, fill=true})
blend(sky, {angle=0})

--@ chunk
street = pile{{"raw umber", 1}, {"bone black", 0.35}, {"lead white", 1.0}, {"cobalt blue", 0.35}}
work(land, {hand="body", pile=street, angle=0, coverage=2, fill=true, length={40, 90}})
blend(land, {angle=0})

--@ chunk
-- glow reflected in the wet street, painted wet-in-wet
glow = pile{{"chrome yellow", 1}, {"vermilion", 0.6}, {"lead white", 1}}
work(rect(560, 660, 300, 220):roughen(25, 90, 4) * land, {hand="body", pile=glow, angle=math.pi / 2,
     coverage=0.8, length={30, 80}, pressure={0.2, 0.45}, load=0.5})

--@ chunk
sun = pile{{"lead white", 3}, {"chrome yellow", 1.2}}
work(ellipse(700, 575, 48, 48):soften(6), {hand="body", pile=sun, coverage=2, fill=true, clip=true})

--@ chunk
-- the walker: one dark silhouette with a gesture stroke for the umbrella
fig = body_of{spine={{420, 575}, {424, 625}, {428, 690}}, widths={12, 20, 11},
              limbs={{{427, 645}, {412, 700}, widths={8, 5}}, {{427, 645}, {446, 700}, widths={8, 5}}}}
dark = pile{{"bone black", 1}, {"raw umber", 0.6}}
work(fig:mask(), {hand="detail", pile=dark, coverage=3, fill=true, clip=true})
b = brush{kind="round", width=6, point=0.6}
b:load(dark, 0.8)
b:gesture({{392, 572, 0.3}, {422, 556, 0.9}, {454, 574, 0.3}})

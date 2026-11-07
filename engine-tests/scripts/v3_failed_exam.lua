-- Entry: "had a bad day today i failed my exam"
-- Reading: mood heavy/disappointed, setting implied (desk, studying), indoors, evening, alone.
-- Plan: quiet still life - desk by a rainy window, closed book, papers, one small warm lamp glow.
--@ chunk
canvas{size=300, aspect=1, linen=16, seed=11,
       ground={{pile={{"lead white", 4}, {"raw umber", 0.25}}, um=60, apply="knife", texture=0.3}}}

--@ chunk
-- the room wall: muted blue-grey, the day's weight
wall = above(function(x) return 640 end)
wall_paint = pile{{"lead white", 2}, {"cobalt blue", 0.5}, {"raw umber", 0.6}, {"bone black", 0.1}}
work(wall, {hand="broad", pile=wall_paint, angle=0.1, coverage=2, fill=true})

--@ chunk
-- the window: rainy grey sky, a cooler, lighter rectangle
win = rect(140, 110, 360, 380)
rain_sky = pile{{"lead white", 3}, {"cobalt blue", 0.35}, {"raw umber", 0.25}}
work(win, {hand="body", pile=rain_sky, angle=math.pi / 2, coverage=2, fill=true, clip=true})
frame = pile{{"raw umber", 1}, {"bone black", 0.3}, {"lead white", 0.4}}
work(win:rim(14, 1) + rect(312, 110, 14, 380) + rect(140, 292, 360, 12), {hand="detail", pile=frame, coverage=2, fill=true, clip=true})

--@ chunk
-- rain streaks on the glass: thin pale falling marks
streak = pile{{"lead white", 3}, {"cobalt blue", 0.2}, medium=0.3}
r = brush{kind="rigger", width=1.6, point=1}
for i = 1, 26 do
  local x = rand(160, 480)
  local y = rand(130, 420)
  r:load(streak, 0.5)
  r:stroke({{x, y}, {x - 2, y + rand(25, 60)}}, {pressure={0.5, 0.05}, clip=win:shrink(16)})
end

--@ chunk
-- the desk: dark warm wood across the bottom
desk = below(function(x) return 640 end)
wood = pile{{"raw umber", 1}, {"red earth", 0.35}, {"bone black", 0.25}, {"lead white", 0.25}}
work(desk, {hand="body", pile=wood, angle=0, coverage=2, fill=true, length={60, 140}})

--@ chunk
-- papers and a closed book on the desk
paper = pile{{"lead white", 3}, {"yellow ochre", 0.15}, {"raw umber", 0.1}}
sheets = poly({{300, 760}, {560, 730}, {600, 840}, {330, 875}})
work(sheets, {hand="body", pile=paper, angle=0, coverage=2.2, fill=true, clip=true})
book = poly({{620, 700}, {860, 690}, {880, 780}, {630, 795}})
cover = pile{{"Prussian blue", 1}, {"raw umber", 0.6}, {"lead white", 0.5}}
work(book, {hand="body", pile=cover, angle=0, coverage=2.2, fill=true, clip=true})
pages = pile{{"lead white", 2}, {"yellow ochre", 0.3}}
work(poly({{630, 795}, {880, 780}, {882, 796}, {632, 811}}), {hand="detail", pile=pages, coverage=2, fill=true, clip=true})

--@ chunk
-- one small warm lamp glow: comfort, not cheer
glow = pile{{"chrome yellow", 1}, {"yellow ochre", 0.5}, {"lead white", 1}, medium=0.4}
work(ellipse(800, 560, 170, 140):soften(60), {hand="glaze", pile=glow, coverage=0.9})
lamp = pile{{"lead white", 2}, {"chrome yellow", 1}}
work(ellipse(800, 560, 30, 30):soften(6), {hand="body", pile=lamp, coverage=2, fill=true, clip=true})

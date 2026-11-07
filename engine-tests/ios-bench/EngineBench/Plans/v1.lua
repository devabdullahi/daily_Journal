-- Day tile test: "rough morning, missed the bus in the rain ... long walk home, sky was orange"
--@ chunk
canvas{size=300, aspect=1, linen=16, seed=7,
       ground={{pile={{"lead white", 4}, {"yellow ochre", 0.2}}, um=60, apply="knife", texture=0.3}}}

--@ chunk
horizon = outline{{0, 640}, {300, 620}, {650, 650}, {1000, 630}, open=true}
sky = horizon:above()
land = horizon:below()

sky_top = pile{{"cobalt blue", 1}, {"lead white", 3}, {"raw umber", 0.3}}
sky_glow = pile{{"chrome yellow", 1}, {"vermilion", 0.6}, {"lead white", 2}}
work(sky, {hand="broad", angle=0, coverage=1.6,
           piles={{sky_top, function(x, y) return clamp(1 - y / 500, 0, 1) end},
                  {sky_glow, function(x, y) return clamp(y / 600, 0, 1) end}}})

--@ chunk
street = pile{{"raw umber", 1}, {"bone black", 0.4}, {"lead white", 1.2}, {"cobalt blue", 0.3}}
work(land, {hand="body", pile=street, angle=0, coverage=1.4})

--@ chunk
-- reflected glow on the wet street
puddle = pile{{"chrome yellow", 1}, {"vermilion", 0.5}, {"lead white", 1.5}, medium=0.3}
work(rect(250, 700, 500, 120):roughen(20, 80, 3), {hand="glaze", pile=puddle, coverage=0.7, angle=0})

--@ chunk
sun = pile{{"lead white", 3}, {"chrome yellow", 1}}
work(ellipse(700, 560, 55, 55), {hand="body", pile=sun, coverage=1.2})

--@ chunk
-- a small walking figure
fig = body_of{spine={{420, 560}, {425, 620}, {430, 690}}, widths={14, 22, 12},
              limbs={{{428, 640}, {410, 700}, widths={8, 6}}, {{428, 640}, {450, 700}, widths={8, 6}}}}
dark = pile{{"bone black", 1}, {"raw umber", 0.5}}
work(fig:mask(), {hand="detail", pile=dark, coverage=2})

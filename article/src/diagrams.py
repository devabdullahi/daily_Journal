# Writes the article's diagrams as standalone HTML pages (one SVG each) for headless rendering.
from pathlib import Path
OUT = Path(__file__).parent / "svg"
OUT.mkdir(exist_ok=True)

INK, MUTED, LINE, BOX, BG = "#302c28", "#6d655c", "#d9cfc2", "#ffffff", "#fffdf8"
ACC, ACC_BG = "#a34e37", "#f8ece5"
MAC, PHONE = "#2f6c9e", "#c0643f"
FONT = "system-ui,-apple-system,'Segoe UI',sans-serif"
MONO = "ui-monospace,Menlo,monospace"

def page(name, w, h, body):
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="{FONT}">
<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M0,0 L10,5 L0,10 z" fill="{MUTED}"/></marker></defs>
<rect width="{w}" height="{h}" fill="{BG}"/>{body}</svg>'''
    (OUT / f"{name}.html").write_text(f'<!doctype html><meta charset="utf-8"><style>html,body{{margin:0;background:{BG}}}</style>{svg}')

def box(x, y, w, h, title, lines=(), accent=False, mono_title=False):
    fill, stroke = (ACC_BG, ACC) if accent else (BOX, LINE)
    tf = MONO if mono_title else FONT
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>'
    s += f'<text x="{x+14}" y="{y+26}" font-size="14" font-weight="650" fill="{ACC if accent else INK}" font-family="{tf}">{title}</text>'
    for i, ln in enumerate(lines):
        s += f'<text x="{x+14}" y="{y+48+i*18}" font-size="12.5" fill="{MUTED}">{ln}</text>'
    return s

def arrow(x1, y1, x2, y2, label=None, lx=None, ly=None):
    s = f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{MUTED}" stroke-width="1.5" marker-end="url(#a)"/>'
    if label:
        s += f'<text x="{lx}" y="{ly}" font-size="11.5" fill="{MUTED}" text-anchor="middle">{label}</text>'
    return s

# ---------- 1. Pipeline ----------
b = ""
b += box(20, 20, 210, 96, "Journal entry", ["“rough morning, missed the bus", "in the rain… sky was orange”"])
b += box(255, 20, 210, 96, "Reader (AI)", ["Foundation Models on device,", "or opt-in Claude Haiku"])
b += box(490, 20, 210, 96, "Reading", ["subject, setting, light,", "mood colors, key motifs"])
b += arrow(230, 68, 253, 68) + arrow(465, 68, 488, 68)
# shared crate
b += f'<rect x="10" y="150" width="700" height="150" rx="12" fill="none" stroke="{ACC}" stroke-width="1.2" stroke-dasharray="5 4"/>'
b += f'<text x="26" y="172" font-size="12" font-weight="650" fill="{ACC}" letter-spacing=".04em">SHARED RUST CRATE · SAME CODE ON iOS AND THE LINUX PAINTER</text>'
b += box(490, 186, 210, 100, "Planner", ["a few strong compositions", "+ technique & color rules", "deterministic, seeded"])
b += box(255, 186, 210, 100, "PaintPlan", ["Lua chunks: canvas, piles,", "masks, work(), blend()", "versioned + canonicalized"])
b += box(20, 186, 210, 100, "claude-paint engine", ["bristles, wet paint, drying,", "Kubelka–Munk pigment optics", "(forked, MIT)"], accent=True)
b += arrow(595, 116, 595, 184) + arrow(488, 236, 467, 236) + arrow(253, 236, 232, 236)
b += arrow(125, 286, 125, 330)
b += box(20, 332, 680, 64, "Output", ["PNG  +  stroke log  +  timelapse frames  +  provenance (engine, plan, Reading versions, seed)"])
page("01-pipeline", 720, 410, b)

# ---------- 2. Engine hot path ----------
b = ""
b += box(20, 20, 150, 80, "Stroke", ["path, hand, pile,", "pressure, load"])
b += box(200, 20, 150, 80, "Bristles", ["each one carries", "its own wet paint"])
b += box(380, 20, 320, 80, "exchange::contact", ["bristle ↔ canvas, every pixel touched:", "take paint off, lay paint down"], accent=True, mono_title=True)
b += arrow(170, 60, 198, 60) + arrow(350, 60, 378, 60)
# pixel
b += f'<rect x="20" y="130" width="440" height="200" rx="10" fill="{BOX}" stroke="{LINE}" stroke-width="1.5"/>'
b += f'<text x="34" y="154" font-size="14" font-weight="650" fill="{INK}">One pixel</text>'
b += f'<text x="112" y="154" font-size="12.5" fill="{MUTED}" font-family="{MONO}">Vec&lt;Layer&gt;</text>'
for i, (name, parts) in enumerate([("wet top layer", ["lead white .62", "vermilion .21", "chrome yel .17"]),
                                   ("drying layer below", ["cobalt blue .55", "lead white .45"])]):
    y = 170 + i * 78
    b += f'<rect x="34" y="{y}" width="412" height="66" rx="7" fill="{BG}" stroke="{LINE}"/>'
    b += f'<text x="46" y="{y+20}" font-size="12.5" font-weight="600" fill="{INK}">Layer · {name}</text>'
    b += f'<text x="300" y="{y+20}" font-size="11.5" fill="{MUTED}" font-family="{MONO}">Latent.parts: Vec</text>'
    for j, p in enumerate(parts):
        x = 46 + j * 132
        b += f'<rect x="{x}" y="{y+32}" width="122" height="24" rx="12" fill="{ACC_BG}" stroke="{LINE}"/>'
        b += f'<text x="{x+61}" y="{y+48}" font-size="11.5" fill="{INK}" text-anchor="middle" font-family="{MONO}">{p}</text>'
b += arrow(540, 100, 462, 150)
b += box(490, 130, 210, 92, "Kubelka–Munk", ["layers + tube parts →", "absorption & scattering →", "the color you see"])
b += arrow(460, 176, 488, 176)
# stats
b += f'<rect x="490" y="238" width="210" height="92" rx="8" fill="{BOX}" stroke="{LINE}" stroke-width="1.5"/>'
for i, (k, v) in enumerate([("95%", "of time in contact"), ("~1B", "heap allocs / painting"), ("~30%", "alloc + copy work")]):
    y = 262 + i * 26
    b += f'<text x="504" y="{y}" font-size="15" font-weight="700" fill="{ACC}">{k}</text>'
    b += f'<text x="556" y="{y}" font-size="12" fill="{MUTED}">{v}</text>'
b += f'<text x="20" y="356" font-size="12" fill="{MUTED}">One 512 px painting: ~290 million pixel paint operations, ~150 million on pixels with more than one layer.</text>'
page("02-hot-path", 720, 372, b)

# ---------- 3. Copy vs move ----------
def lane(y, title, steps, note, color):
    s = f'<text x="20" y="{y}" font-size="13" font-weight="700" fill="{color}" letter-spacing=".03em">{title}</text>'
    x = 20
    for i, (label, sub, alloc) in enumerate(steps):
        w = 158
        s += f'<rect x="{x}" y="{y+12}" width="{w}" height="58" rx="8" fill="{ACC_BG if alloc else BOX}" stroke="{ACC if alloc else LINE}" stroke-width="1.5"/>'
        s += f'<text x="{x+12}" y="{y+36}" font-size="12.5" font-weight="600" fill="{INK}" font-family="{MONO}">{label}</text>'
        s += f'<text x="{x+12}" y="{y+56}" font-size="11.5" fill="{ACC if alloc else MUTED}">{sub}</text>'
        if i < len(steps) - 1:
            s += arrow(x + w, y + 41, x + w + 16, y + 41)
        x += w + 16
    s += f'<text x="20" y="{y+92}" font-size="12" fill="{MUTED}">{note}</text>'
    return s
b = lane(26, "BEFORE", [("latent.layers()", "clone whole stack · alloc", True), ("split_top()", "two new halves · alloc", True),
                        ("from_layers()", "rebuild the pixel", False), ("drop(original)", "free the old stack", True)],
         "Every take/lay on a layered pixel copied the stack it was about to throw away.", MUTED)
b += lane(148, "AFTER (M1)", [("mem::take(lat)", "move it out · no alloc", False), ("split_top_owned()", "split in place", False),
                              ("from_layers()", "reserve parts up front", False), ("—", "nothing left to free", False)],
          "Same values, same arithmetic, same order. 0 of 262,144 pixels changed. ~10% faster on both machines.", MAC)
page("03-copy-vs-move", 720, 256, b)

# ---------- 4. Speed chart ----------
def hbar(x0, y, val, scale, color, h=16):
    w = val * scale
    return (f'<path d="M{x0},{y} h{w-4} a4,4 0 0 1 4,4 v{h-8} a4,4 0 0 1 -4,4 h-{w-4} z" fill="{color}"/>'
            f'<text x="{x0+w+6}" y="{y+12.5}" font-size="12" fill="{INK}" font-weight="600" stroke="{BG}" stroke-width="4" paint-order="stroke">{val:.1f} s</text>')
X0, SC = 210, 9.0  # 0–50 s over 450 px
b = f'<text x="20" y="24" font-size="14" font-weight="650" fill="{INK}">Time to paint one 512 px painting (v7 park plan, 3 runs each)</text>'
b += f'<rect x="20" y="38" width="12" height="12" rx="3" fill="{MAC}"/><text x="38" y="48" font-size="12" fill="{MUTED}">M4 Mac</text>'
b += f'<rect x="104" y="38" width="12" height="12" rx="3" fill="{PHONE}"/><text x="122" y="48" font-size="12" fill="{MUTED}">iPhone 17 Pro Max</text>'
for t in range(0, 51, 10):
    x = X0 + t * SC
    b += f'<line x1="{x}" y1="66" x2="{x}" y2="244" stroke="#eee6db"/>'
    b += f'<text x="{x}" y="262" font-size="11" fill="{MUTED}" text-anchor="middle">{t} s</text>'
tx = X0 + 30 * SC
b += f'<line x1="{tx}" y1="60" x2="{tx}" y2="244" stroke="{ACC}" stroke-dasharray="4 3" stroke-width="1.2"/>'
b += f'<text x="{tx+4}" y="62" font-size="11" fill="{ACC}">30 s target</text>'
rows = [("Baseline", "engine 9, release", 29.7, 43.6), ("M1 · move layers", "kept · 0 px changed", 26.8, 38.9), ("M2 · faster part merge", "kept · 0 px changed", 25.4, 34.5)]
y = 78
for name, sub, mac, ph in rows:
    b += f'<text x="20" y="{y+12}" font-size="12.5" font-weight="600" fill="{INK}">{name}</text>'
    b += f'<text x="20" y="{y+30}" font-size="11.5" fill="{MUTED}">{sub}</text>'
    b += hbar(X0, y, mac, SC, MAC)
    if ph: b += hbar(X0, y + 20, ph, SC, PHONE)
    y += 56
b += f'<line x1="{X0}" y1="66" x2="{X0}" y2="244" stroke="{MUTED}"/>'
page("04-speed", 720, 274, b)

# ---------- 5. Threads / QoS ----------
X0, SC = 230, 8.0
b = f'<text x="20" y="24" font-size="14" font-weight="650" fill="{INK}">iPhone: rayon pool size and worker QoS (v7 plan, median of 3)</text>'
cfgs = [("6 threads · user-initiated", 41.8), ("6 threads · default QoS", 43.6), ("3 threads · user-initiated", 48.3),
        ("2 threads · user-initiated", 51.7), ("2 threads · default QoS", 52.2)]
for t in range(0, 61, 10):
    x = X0 + t * SC
    b += f'<line x1="{x}" y1="40" x2="{x}" y2="{40+len(cfgs)*30}" stroke="#eee6db"/>'
    b += f'<text x="{x}" y="{58+len(cfgs)*30}" font-size="11" fill="{MUTED}" text-anchor="middle">{t} s</text>'
for i, (n, v) in enumerate(cfgs):
    y = 48 + i * 30
    b += f'<text x="20" y="{y+12.5}" font-size="12.5" fill="{INK}">{n}</text>'
    b += hbar(X0, y, v, SC, PHONE)
b += f'<line x1="{X0}" y1="40" x2="{X0}" y2="{40+len(cfgs)*30}" stroke="{MUTED}"/>'
page("05-threads", 720, 72 + len(cfgs) * 30, b)
print("ok")

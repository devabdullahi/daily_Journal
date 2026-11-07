# Builds the photo figures for the article from engine test renders.
import sys
from pathlib import Path
from PIL import Image

P = Path(sys.argv[1])          # engine-tests/paintings
OUT = Path(sys.argv[2])        # article/images
BG = (255, 253, 248)
GAP = 16

def load(p, size):
    return Image.open(P / p).convert("RGB").resize((size, size), Image.LANCZOS)

def row(paths, size, name, q=86):
    ims = [load(p, size) for p in paths]
    w = size * len(ims) + GAP * (len(ims) - 1)
    canvas = Image.new("RGBA", (w, size), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        canvas.paste(im, (i * (size + GAP), 0))
    canvas.save(OUT / name.replace(".jpg", ".webp"), "WEBP", quality=q, method=6)

# Hero: three finished paintings
row(["v2-1024.png", "v3c-failed-exam-1024.png", "iphone/v6-park-icecream-512.png"], 640, "01-hero.jpg")
# Same entry, naive plan vs technique plan
row(["v1-1024.png", "v2-1024.png"], 720, "02-v1-vs-v2.jpg")
# Literal vs abstract translation of the same entry
row(["v3c-failed-exam-1024.png", "v4-failed-exam-abstract-1024.png"], 720, "05-literal-vs-abstract.jpg")
# Ice cream over wet grass vs reserved space
row(["iphone/v5-park-icecream-512.png", "iphone/v6-park-icecream-512.png"], 720, "06-green-cone.jpg")
# Timelapse filmstrip: one frame per chunk boundary
frames = ["00002.png", "00005.png", "00011.png", "00016.png", "00019.png"]
row([f"v2-timelapse-frames/{f}" for f in frames], 400, "03-timelapse.jpg")
print("ok")

# UI skin for Colony Empire (original art, drawn in code).  python make_ui_skin.py <out_dir>
# Style: dark slate-blue "glass" panels with a bevelled gold frame, glossy buttons and bars —
# the classic 4X strategy look. Every image is a 9-slice: hud.gd stretches only the middle.
# Drawn 4x larger and scaled down for smooth edges.
import sys, os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4
OUT = sys.argv[1] if len(sys.argv) > 1 else "."


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def vgrad(w, h, stops):
    """Vertical gradient. stops = [(t, (r,g,b,a)), ...]"""
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                k = (t - stops[i][0]) / max(1e-6, stops[i + 1][0] - stops[i][0])
                c = lerp(stops[i][1], stops[i + 1][1], k)
                break
        for x in range(w):
            px[x, y] = c
    return im


def rmask(w, h, r, inset=0):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([inset, inset, w - 1 - inset, h - 1 - inset], max(0, r - inset), fill=255)
    return m


def layer(base, fill_img, mask):
    base.alpha_composite(Image.composite(fill_img, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))


def ring(w, h, r, inset, width, fill):
    """A frame line `width` px thick starting `inset` px inside the edge. fill = colour or image."""
    outer = rmask(w, h, r, inset)
    inner = rmask(w, h, r, inset + width)
    m = ImageChops.subtract(outer, inner)
    img = fill if isinstance(fill, Image.Image) else Image.new("RGBA", (w, h), fill)
    return img, m


GOLD = [(0.0, (255, 236, 170, 255)), (0.45, (214, 170, 84, 255)), (1.0, (122, 84, 34, 255))]
GOLD_HI = [(0.0, (255, 250, 214, 255)), (0.45, (250, 212, 118, 255)), (1.0, (170, 120, 48, 255))]
GOLD_DIM = [(0.0, (186, 164, 118, 255)), (1.0, (96, 78, 50, 255))]


def framed(name, w, h, r, body, frame=GOLD, fw=2, sheen=0.10, dark_line=True, glow=None):
    W, H, R = w * S, h * S, r * S
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if dark_line:                                    # thin dark outline so it reads on any map colour
        layer(im, Image.new("RGBA", (W, H), (6, 8, 12, 235)), rmask(W, H, R))
    layer(im, vgrad(W, H, body), rmask(W, H, R, 1 * S))
    if sheen > 0:                                    # glassy highlight on the upper half
        sh = vgrad(W, H, [(0, (255, 255, 255, int(255 * sheen))), (0.5, (255, 255, 255, 0)), (1, (255, 255, 255, 0))])
        layer(im, sh, rmask(W, H, R, (1 + fw) * S))
    if fw > 0:
        img, m = ring(W, H, R, 1 * S, fw * S, vgrad(W, H, frame))
        layer(im, img, m)
        img, m = ring(W, H, R, (1 + fw) * S, S, (10, 12, 16, 200))          # dark groove inside the gold
        layer(im, img, m)
        img, m = ring(W, H, R, (2 + fw) * S, S, (255, 255, 255, 26))        # faint inner highlight
        layer(im, img, m)
    if glow:
        img, m = ring(W, H, R, (2 + fw) * S, 2 * S, glow)
        layer(im, img, m.filter(ImageFilter.GaussianBlur(S)))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, f"skin_{name}.png"))


SLATE = [(0.0, (40, 54, 72, 240)), (0.5, (22, 31, 44, 240)), (1.0, (13, 19, 28, 244))]
SLATE_SOLID = [(0.0, (38, 51, 68, 252)), (0.5, (22, 31, 44, 252)), (1.0, (13, 19, 28, 252))]

# panels
framed("panel", 64, 64, 12, SLATE, GOLD, 2)
framed("window", 64, 64, 14, SLATE_SOLID, GOLD, 3, sheen=0.08)
framed("tooltip", 32, 32, 6, [(0, (24, 32, 44, 250)), (1, (12, 17, 25, 250))], GOLD_DIM, 1, sheen=0.05)
framed("card", 40, 40, 8, [(0, (46, 60, 80, 230)), (1, (26, 35, 49, 230))], GOLD_DIM, 1, sheen=0.07)
framed("card_on", 40, 40, 8, [(0, (52, 70, 58, 235)), (1, (26, 42, 32, 235))], [(0, (190, 240, 160, 255)), (1, (70, 130, 60, 255))], 1, sheen=0.08)
framed("inset", 32, 32, 6, [(0, (4, 7, 11, 200)), (1, (14, 20, 28, 200))], GOLD_DIM, 1, sheen=0, dark_line=False)
framed("event", 40, 32, 6, [(0, (28, 38, 52, 225)), (1, (15, 21, 30, 225))], GOLD_DIM, 1, sheen=0.06)
framed("event_bad", 40, 32, 6, [(0, (60, 30, 30, 225)), (1, (30, 14, 14, 225))], [(0, (255, 160, 140, 255)), (1, (140, 50, 40, 255))], 1, sheen=0.06)
# buttons: glossy steel-blue with a gold rim
BTN = [(0.0, (92, 118, 150, 255)), (0.48, (52, 72, 98, 255)), (0.52, (40, 56, 78, 255)), (1.0, (28, 40, 58, 255))]
BTN_HI = [(0.0, (122, 152, 190, 255)), (0.48, (72, 98, 132, 255)), (0.52, (56, 78, 108, 255)), (1.0, (38, 54, 78, 255))]
BTN_DN = [(0.0, (18, 26, 38, 255)), (0.5, (30, 42, 60, 255)), (1.0, (44, 60, 84, 255))]
BTN_OFF = [(0.0, (58, 62, 68, 220)), (1.0, (30, 32, 36, 220))]
framed("button", 48, 32, 7, BTN, GOLD_DIM, 1, sheen=0.12)
framed("button_hover", 48, 32, 7, BTN_HI, GOLD_HI, 1, sheen=0.16)
framed("button_pressed", 48, 32, 7, BTN_DN, GOLD, 1, sheen=0)
framed("button_disabled", 48, 32, 7, BTN_OFF, [(0, (110, 110, 110, 255)), (1, (60, 60, 60, 255))], 1, sheen=0.04)
framed("button_on", 48, 32, 7, BTN_HI, GOLD_HI, 2, sheen=0.16, glow=(255, 220, 120, 150))
# the big gold button (End Turn / Start)
GOLDBTN = [(0.0, (255, 226, 140, 255)), (0.48, (224, 168, 64, 255)), (0.52, (196, 138, 40, 255)), (1.0, (150, 98, 24, 255))]
GOLDBTN_HI = [(0.0, (255, 240, 180, 255)), (0.48, (240, 190, 88, 255)), (0.52, (218, 160, 56, 255)), (1.0, (170, 114, 32, 255))]
GOLDBTN_DN = [(0.0, (130, 84, 20, 255)), (1.0, (206, 150, 56, 255))]
framed("gold", 48, 40, 9, GOLDBTN, [(0, (255, 250, 220, 255)), (1, (110, 70, 20, 255))], 1, sheen=0.18)
framed("gold_hover", 48, 40, 9, GOLDBTN_HI, [(0, (255, 255, 240, 255)), (1, (140, 90, 30, 255))], 1, sheen=0.22)
framed("gold_pressed", 48, 40, 9, GOLDBTN_DN, [(0, (120, 80, 20, 255)), (1, (255, 230, 160, 255))], 1, sheen=0)
# progress bars: dark well + a white glossy fill that hud.gd tints per bar
framed("bar_bg", 32, 20, 5, [(0, (2, 4, 7, 230)), (1, (18, 24, 32, 230))], [(0, (70, 64, 52, 255)), (1, (150, 130, 90, 255))], 1, sheen=0, dark_line=False)
framed("bar_fill", 32, 20, 5, [(0.0, (255, 255, 255, 255)), (0.45, (215, 215, 215, 255)), (0.55, (185, 185, 185, 255)), (1.0, (140, 140, 140, 255))],
       [(0, (255, 255, 255, 120)), (1, (0, 0, 0, 90))], 1, sheen=0.25, dark_line=False)

# top bar: a full-width strip, gold edge at the bottom only
W, H = 64 * S, 48 * S
im = vgrad(W, H, [(0, (34, 46, 62, 246)), (0.7, (16, 23, 33, 246)), (0.86, (10, 14, 20, 250)), (1, (10, 14, 20, 250))])
d = ImageDraw.Draw(im)
g = vgrad(W, 3 * S, GOLD)
im.paste(g, (0, H - 6 * S))
d.rectangle([0, H - 3 * S, W, H - 2 * S], fill=(10, 12, 16, 230))
im.alpha_composite(vgrad(W, 2 * S, [(0, (0, 0, 0, 120)), (1, (0, 0, 0, 0))]), (0, H - 2 * S))
im.resize((64, 48), Image.LANCZOS).save(os.path.join(OUT, "skin_topbar.png"))

# a round medallion (nation badge / city population)
for name, fill in [("medal", [(0, (60, 78, 100, 255)), (1, (20, 28, 40, 255))])]:
    D = 64 * S
    im = Image.new("RGBA", (D, D), (0, 0, 0, 0))
    m = Image.new("L", (D, D), 0); ImageDraw.Draw(m).ellipse([0, 0, D - 1, D - 1], fill=255)
    layer(im, Image.new("RGBA", (D, D), (6, 8, 12, 240)), m)
    m = Image.new("L", (D, D), 0); ImageDraw.Draw(m).ellipse([S, S, D - 1 - S, D - 1 - S], fill=255)
    layer(im, vgrad(D, D, GOLD), m)
    m = Image.new("L", (D, D), 0); ImageDraw.Draw(m).ellipse([5 * S, 5 * S, D - 1 - 5 * S, D - 1 - 5 * S], fill=255)
    layer(im, vgrad(D, D, fill), m)
    im.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, f"skin_{name}.png"))
print("ok")

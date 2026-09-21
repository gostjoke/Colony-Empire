# Unit sprite generator for Colony Empire.
# Usage:   pip install cairosvg pillow numpy
#          python make_units.py
# Writes, per unit:
#   art_src/unit_<name>.svg                          editable vector source (open in Inkscape etc.)
#   godot_starter/assets/units/unit_<name>.png       base art, team-colour areas painted grey
#   godot_starter/assets/units/unit_<name>_team.png  mask: white = where the nation colour goes
# Team areas are drawn with T1 (light) / T2 (shade); main.gd multiplies them by the nation colour.
import re, io, sys
import cairosvg
from PIL import Image
import numpy as np

SIZE = 128
OUT = "#2b2220"          # outline
T1, T2 = "#ececec", "#b2b2b2"   # team colour: light / shade (tinted in-game)
SKIN, SKIN2 = "#f2c9a2", "#dca582"
HAIR = "#6b4226"
LEATHER, LEATHER2 = "#8c5b33", "#6a4324"
FELT, FELT2 = "#7a5536", "#5b3d25"
PANTS, PANTS2 = "#4b4239", "#3a322b"
BOOT = "#35271f"
BUFF, BUFF2 = "#dcc79e", "#bfa77c"
CREAM, CREAM2 = "#f1e6cc", "#d7c6a2"
METAL, METAL2, METAL3 = "#cfd6dd", "#8f9aa5", "#f4f7f9"
WOOD, WOOD2 = "#a06f42", "#7b5230"
BRASS, BRASS2, BRASS3 = "#dba543", "#ae7b22", "#f5d57e"

SW = 'stroke="%s" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"' % OUT

def limb(x1, y1, x2, y2, col, w=9):
    """Arm/leg as a thick line with an outline (outline drawn wider underneath)."""
    return (f'<path d="M{x1} {y1} L{x2} {y2}" stroke="{OUT}" stroke-width="{w+4.4}" stroke-linecap="round" fill="none"/>'
            f'<path d="M{x1} {y1} L{x2} {y2}" stroke="{col}" stroke-width="{w}" stroke-linecap="round" fill="none"/>')

def hand(x, y, r=5.2):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{SKIN}" {SW}/>'

def legs(pants=PANTS, pants2=PANTS2, boot=BOOT, tall=False):
    top = 100 if tall else 107
    s = f'<rect x="53" y="94" width="10" height="16" fill="{pants}" {SW}/>'
    s += f'<rect x="65" y="94" width="10" height="16" fill="{pants2}" {SW}/>'
    s += f'<rect x="49" y="{top}" width="15" height="{117-top}" rx="3.5" fill="{boot}" {SW}/>'
    s += f'<rect x="64" y="{top}" width="15" height="{117-top}" rx="3.5" fill="{boot}" {SW}/>'
    if tall:   # boot cuffs
        s += f'<rect x="48" y="{top-1}" width="17" height="5" rx="2" fill="{LEATHER}" {SW}/>'
        s += f'<rect x="63" y="{top-1}" width="17" height="5" rx="2" fill="{LEATHER}" {SW}/>'
    return s

def torso(fill, shade, bottom=100):
    s = f'<path d="M47 57 C52 53 76 53 81 57 L83 86 L87 {bottom} Q64 {bottom+4} 41 {bottom} L45 86 Z" fill="{fill}" {SW}/>'
    s += f'<path d="M72 55.5 C77 55 80 56 81 57 L83 86 L87 {bottom} Q80 {bottom+2.5} 73 {bottom+3} Z" fill="{shade}"/>'
    s += f'<path d="M47 57 C52 53 76 53 81 57 L83 86 L87 {bottom} Q64 {bottom+4} 41 {bottom} L45 86 Z" fill="none" {SW}/>'
    return s

def head(face="smile"):
    s = f'<circle cx="64" cy="38" r="16.5" fill="{HAIR}" {SW}/>'           # hair behind
    s += f'<circle cx="64" cy="41" r="15" fill="{SKIN}" {SW}/>'
    s += f'<path d="M72 30 A15 15 0 0 1 78.5 45 Q74 52 68 55 A15 15 0 0 0 72 30 Z" fill="{SKIN2}" opacity="0.55"/>'
    s += f'<circle cx="55" cy="47" r="3" fill="#e8907c" opacity="0.45"/><circle cx="73" cy="47" r="3" fill="#e8907c" opacity="0.45"/>'
    if face == "squint":   # one eye shut (looking through a spyglass)
        s += f'<path d="M56 42 Q58.5 40 61 42" stroke="{OUT}" stroke-width="2" fill="none" stroke-linecap="round"/>'
    else:
        s += f'<ellipse cx="58.5" cy="42" rx="2.1" ry="2.7" fill="{OUT}"/><circle cx="59.2" cy="41" r="0.8" fill="#fff"/>'
    if face != "squint":
        s += f'<ellipse cx="69.5" cy="42" rx="2.1" ry="2.7" fill="{OUT}"/><circle cx="70.2" cy="41" r="0.8" fill="#fff"/>'
    if face == "stern":
        s += f'<path d="M55 37 L61 38.5 M73 37 L67 38.5" stroke="{OUT}" stroke-width="1.8" stroke-linecap="round"/>'
        s += f'<path d="M60.5 50 L67.5 50" stroke="{OUT}" stroke-width="1.8" stroke-linecap="round"/>'
    else:
        s += f'<path d="M60.5 49 Q64 52 67.5 49" stroke="{OUT}" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
    return s

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 128 128">{body}</svg>'

# ---------------------------------------------------------------- Colonist
def colonist():
    s = ""
    # bedroll on the back
    s += f'<rect x="37" y="45" width="54" height="14" rx="7" fill="{CREAM}" {SW}/>'
    s += f'<rect x="37" y="52" width="54" height="7" rx="3.5" fill="{CREAM2}"/>'
    s += f'<rect x="37" y="45" width="54" height="14" rx="7" fill="none" {SW}/>'
    s += f'<ellipse cx="41" cy="52" rx="3.2" ry="6" fill="{CREAM2}" {SW}/><ellipse cx="87" cy="52" rx="3.2" ry="6" fill="{CREAM2}" {SW}/>'
    s += legs()
    # spade (behind the hand)
    s += limb(40.5, 60, 36.5, 106, WOOD, 3.6)
    s += f'<path d="M35 56 L46 57" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/><path d="M35 56 L46 57" stroke="{WOOD}" stroke-width="3" stroke-linecap="round"/>'
    s += f'<path d="M29.5 103 L43.5 104 L42.5 114 Q36 121 30 114 Z" fill="{METAL}" {SW}/>'
    s += f'<path d="M32 106 L35 106 L34.5 113" stroke="{METAL3}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    s += torso(T1, T2)
    # shirt collar + coat opening + buttons
    s += f'<path d="M57 55 L64 66 L71 55 Z" fill="{CREAM}" {SW}/>'
    s += f'<path d="M64 66 L64 99" stroke="{OUT}" stroke-width="1.6"/>'
    for y in (72, 79):
        s += f'<circle cx="67.5" cy="{y}" r="1.5" fill="{BRASS}" stroke="{OUT}" stroke-width="1"/>'
    # belt + pack straps
    s += f'<rect x="44.5" y="84" width="39" height="5" fill="{LEATHER2}" {SW}/><rect x="61" y="83" width="6" height="7" rx="1" fill="{BRASS}" {SW}/>'
    s += f'<path d="M51 57 L53 84 M77 57 L75 84" stroke="{OUT}" stroke-width="5.5" stroke-linecap="round"/>'
    s += f'<path d="M51 57 L53 84 M77 57 L75 84" stroke="{LEATHER}" stroke-width="2.6" stroke-linecap="round"/>'
    # arms
    s += limb(48.5, 61, 40.5, 81, T1) + hand(40, 83)
    s += limb(79.5, 61, 86.5, 81, T2) + hand(87, 83)
    s += head("smile")
    # wide-brim felt hat
    s += f'<ellipse cx="64" cy="29.5" rx="24" ry="5.8" fill="{FELT2}" {SW}/>'
    s += f'<path d="M51.5 29.5 L53.5 14 Q64 9.5 74.5 14 L76.5 29.5 Q64 32 51.5 29.5 Z" fill="{FELT}" {SW}/>'
    s += f'<path d="M52.4 23 Q64 25.5 75.6 23 L76.3 28.5 Q64 31 51.7 28.5 Z" fill="{OUT}"/>'
    s += f'<rect x="61" y="23.6" width="6" height="5.4" rx="0.8" fill="none" stroke="{BRASS}" stroke-width="1.6"/>'
    s += f'<path d="M56 15.5 Q58 14 60 13.6" stroke="#a37a55" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    return svg(s)

# ---------------------------------------------------------------- Scout
def scout():
    s = ""
    # team-coloured cloak behind
    s += f'<path d="M47 57 Q39 80 33 105 Q48 110 64 107 Q80 110 95 105 Q89 80 81 57 Z" fill="{T1}" {SW}/>'
    s += f'<path d="M80 60 Q87 82 95 105 Q88 107 82 107 Q80 84 76 62 Z" fill="{T2}"/>'
    s += f'<path d="M47 57 Q39 80 33 105 Q48 110 64 107 Q80 110 95 105 Q89 80 81 57 Z" fill="none" {SW}/>'
    s += legs(BUFF, BUFF2, LEATHER2, tall=True)
    s += torso(LEATHER, LEATHER2, 98)
    # fringe + opening
    s += f'<path d="M64 58 L64 97" stroke="{OUT}" stroke-width="1.6"/>'
    s += ''.join(f'<path d="M{x} 97 L{x} 101" stroke="{LEATHER2}" stroke-width="1.6" stroke-linecap="round"/>' for x in range(46, 84, 4))
    # neckerchief (team)
    s += f'<path d="M55 55 Q64 61 73 55 L68 64 L64 70 L60 64 Z" fill="{T1}" {SW}/>'
    # satchel strap + bag
    s += f'<path d="M50 58 L80 90" stroke="{OUT}" stroke-width="6" stroke-linecap="round"/><path d="M50 58 L80 90" stroke="{WOOD2}" stroke-width="3" stroke-linecap="round"/>'
    s += f'<rect x="73" y="84" width="16" height="13" rx="3" fill="{WOOD}" {SW}/><path d="M73 89 Q81 93 89 89" stroke="{OUT}" stroke-width="1.6" fill="none"/>'
    s += f'<rect x="44.5" y="82" width="39" height="5" fill="{LEATHER2}" {SW}/>'
    # left arm hanging on the hip
    s += limb(48.5, 61, 43, 82, LEATHER) + hand(43, 84)
    # right arm raised to the eye
    s += limb(79.5, 61, 86, 50, LEATHER2)
    s += head("squint")
    # spyglass in front of the right eye, pointing to the upper right
    s += '<g transform="rotate(-18 70 42)">'
    s += f'<rect x="67" y="38" width="12" height="8" rx="1.5" fill="{BRASS2}" {SW}/>'
    s += f'<rect x="79" y="36.5" width="12" height="11" rx="1.5" fill="{BRASS}" {SW}/>'
    s += f'<rect x="91" y="35" width="13" height="14" rx="2" fill="{BRASS}" {SW}/>'
    s += f'<rect x="80" y="38" width="10" height="2.4" rx="1" fill="{BRASS3}"/><rect x="92.5" y="36.8" width="10" height="2.6" rx="1" fill="{BRASS3}"/>'
    s += f'<rect x="101" y="35" width="3" height="14" fill="{BRASS2}" {SW}/>'
    s += '</g>'
    s += hand(84, 44.5)
    # slouch hat with a team-coloured feather
    s += f'<path d="M50 20 Q39 4 28 11 Q34 14 40 17 Q35 17 31 19 Q42 23 51 27 Z" fill="{T1}" {SW}/>'
    s += f'<path d="M50 24 Q40 14 31 12" stroke="{T2}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M40 30 Q64 22 88 28 Q86 34 64 33 Q46 34 40 30 Z" fill="{FELT2}" {SW}/>'
    s += f'<path d="M50.5 29 Q50 15 64 13 Q78 14 77.5 28 Q64 31 50.5 29 Z" fill="{FELT}" {SW}/>'
    s += f'<path d="M50.8 25 Q64 27.5 77.3 24.5 L77.4 28 Q64 31 50.6 28.5 Z" fill="{LEATHER2}"/>'
    return svg(s)

# ---------------------------------------------------------------- Guard
def guard():
    s = ""
    # halberd (behind the hand)
    s += limb(37, 118, 37, 12, WOOD, 3.8)
    s += f'<path d="M34.5 9 L37 2.5 L39.5 9 L39.5 13 L34.5 13 Z" fill="{METAL}" {SW}/>'
    s += f'<path d="M35 12 L22 9 Q16 20 22 32 L35 27 Z" fill="{METAL}" {SW}/>'
    s += f'<path d="M22 12 Q18.5 20 22.5 29" stroke="{METAL3}" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M39 15 L48 13 L39 22 Z" fill="{METAL2}" {SW}/>'
    s += f'<rect x="33.5" y="27" width="7" height="4" rx="1" fill="{METAL2}" {SW}/>'
    s += legs()
    s += torso(T1, T2)
    # breastplate
    s += f'<path d="M50 57 Q64 52 78 57 L77 78 Q64 84 51 78 Z" fill="{METAL}" {SW}/>'
    s += f'<path d="M64 56 L64 81" stroke="{METAL2}" stroke-width="1.6"/>'
    s += f'<path d="M55 60 Q54 69 56 76" stroke="{METAL3}" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M71 58 L77 57 L76.3 77.5 Q73 80 70.5 80.5 Z" fill="{METAL2}" opacity="0.55"/>'
    s += f'<rect x="44.5" y="84" width="39" height="5" fill="{LEATHER2}" {SW}/><rect x="61" y="83" width="6" height="7" rx="1" fill="{METAL}" {SW}/>'
    # arm holding the halberd
    s += limb(48.5, 61, 40, 78, T1) + hand(38.5, 79)
    s += f'<path d="M34 76 L42.5 76" stroke="{OUT}" stroke-width="1.6" stroke-linecap="round"/>'
    # shield on the other arm (team colour, cream star, steel rim)
    s += limb(79.5, 61, 85, 74, T2)
    s += f'<circle cx="87" cy="81" r="17.5" fill="{METAL2}" {SW}/>'
    s += f'<circle cx="87" cy="81" r="14" fill="{T1}" {SW}/>'
    s += f'<path d="M87 81 m0 -14 A14 14 0 0 1 101 81 L87 81 Z" fill="{T2}" opacity="0.6"/>'
    s += f'<path d="M87 81 m0 14 A14 14 0 0 1 73 81 L87 81 Z" fill="{T2}" opacity="0.35"/>'
    s += f'<path d="M87 69.5 L90 78 L98.5 81 L90 84 L87 92.5 L84 84 L75.5 81 L84 78 Z" fill="{CREAM}" stroke="{OUT}" stroke-width="1.4" stroke-linejoin="round"/>'
    s += f'<circle cx="87" cy="81" r="3.6" fill="{METAL}" {SW}/>'
    s += head("stern")
    # plume (team) + steel morion helmet
    s += f'<path d="M66 13 Q74 -1 92 4 Q84 6 80 9 Q88 9 91 13 Q80 13 71 18 Z" fill="{T1}" {SW}/>'
    s += f'<path d="M69 15 Q77 7 88 6" stroke="{T2}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M49.5 33 Q48.5 14 64 12 Q79.5 14 78.5 33 Z" fill="{METAL}" {SW}/>'
    s += f'<path d="M64 12 Q61 7 64 5 Q67 7 64 12" fill="{METAL}" {SW}/>'
    s += f'<path d="M71 16 Q77 21 77.5 32 L72 32 Q72 22 69 17 Z" fill="{METAL2}" opacity="0.6"/>'
    s += f'<path d="M55 17 Q52 23 52.5 30" stroke="{METAL3}" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    s += f'<path d="M38 27 Q43 35 64 36 Q85 35 90 27 Q91 34 85 38 Q64 43 43 38 Q37 34 38 27 Z" fill="{METAL}" {SW}/>'
    s += f'<path d="M45 36 Q64 40.5 83 36" stroke="{METAL2}" stroke-width="1.6" fill="none"/>'
    return svg(s)


UNITS = {"settler": colonist, "scout": scout, "guard": guard}

def render(svg_text):
    png = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=SIZE, output_height=SIZE)
    return Image.open(io.BytesIO(png)).convert("RGBA")

def team_mask(svg_text):
    # Paint every colour black except the two team greys (white) -> luminance = where to tint.
    t = re.sub(r'#[0-9a-fA-F]{6}\b', lambda m: m.group(0) if m.group(0) in (T1, T2) else '#000000', svg_text)
    t = t.replace(T1, '#ffffff').replace(T2, '#ffffff').replace('fill="#fff"', 'fill="#000000"').replace("opacity=", "data-o=")
    img = render(t)
    a = np.asarray(img).astype(np.float32) / 255.0
    lum = a[..., 0] * a[..., 3]
    out = np.zeros((SIZE, SIZE, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (lum * 255).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")

def tint(base, mask, col):
    # Same maths as main.gd: out = lerp(c, c * nation_colour, mask)
    b = np.asarray(base).astype(np.float32) / 255.0
    m = np.asarray(mask).astype(np.float32)[..., 3:4] / 255.0
    c = np.array(col + (1.0,), np.float32)
    t = b * c
    o = b * (1 - m) + t * m
    return Image.fromarray((o * 255).round().astype(np.uint8), "RGBA")

if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    png_dir = os.path.join(here, "..", "godot_starter", "assets", "units")
    os.makedirs(png_dir, exist_ok=True)
    for name, fn in UNITS.items():
        text = fn()
        open(os.path.join(here, f"unit_{name}.svg"), "w").write(text)
        render(text).save(os.path.join(png_dir, f"unit_{name}.png"))
        team_mask(text).save(os.path.join(png_dir, f"unit_{name}_team.png"))
        print("wrote", name)

# UI icons for Colony Empire (original vector art). python make_icons.py <out_dir>
import sys, os, cairosvg
OUT = "#2b2220"
SW = f'stroke="{OUT}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"'
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{body}</svg>'
ICONS = {
 # gold coin with an embossed crown
 "gold": f'''<circle cx="32" cy="33" r="25" fill="#c98f1f" {SW}/><circle cx="32" cy="31" r="23" fill="#f2c14e"/>
  <circle cx="32" cy="31" r="17" fill="none" stroke="#c98f1f" stroke-width="2.5"/>
  <path d="M22 37 L22 26 L27 31 L32 23 L37 31 L42 26 L42 37 Z" fill="#fbe08a" stroke="#b07a14" stroke-width="2" stroke-linejoin="round"/>
  <path d="M16 22 Q20 14 28 11" stroke="#fff6cf" stroke-width="3" fill="none" stroke-linecap="round"/>''',
 # open book
 "research": f'''<path d="M6 16 Q19 11 32 17 Q45 11 58 16 L58 51 Q45 46 32 52 Q19 46 6 51 Z" fill="#3f6fb5" {SW}/>
  <path d="M10 15 Q20 11 31 16 L31 48 Q20 43 10 47 Z" fill="#f4ecd8" {SW}/><path d="M54 15 Q44 11 33 16 L33 48 Q44 43 54 47 Z" fill="#e9dfc6" {SW}/>
  <path d="M15 22 L26 24 M15 29 L26 31 M15 36 L26 38 M38 24 L49 22 M38 31 L49 29" stroke="#a89a7c" stroke-width="2.2" stroke-linecap="round"/>''',
 # wheat sheaf
 "food": f'''<path d="M32 58 L32 22" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/><path d="M32 58 L32 22" stroke="#d9a441" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M32 58 L20 30 M32 58 L44 30" stroke="{OUT}" stroke-width="6" stroke-linecap="round"/><path d="M32 58 L20 30 M32 58 L44 30" stroke="#d9a441" stroke-width="2.8" stroke-linecap="round"/>
  ''' + ''.join(f'<ellipse cx="{x}" cy="{y}" rx="4.2" ry="7" fill="#f3cc5c" transform="rotate({a} {x} {y})" {SW}/>' for x,y,a in
   [(32,12,0),(26,19,-25),(38,19,25),(26,29,-25),(38,29,25),(15,22,-35),(12,33,-50),(20,35,-30),(49,22,35),(52,33,50),(44,35,30)]) +
  f'<rect x="24" y="44" width="16" height="6" rx="2" fill="#a0522d" {SW}/>',
 # hammer
 "production": f'''<path d="M20 56 L40 24" stroke="{OUT}" stroke-width="10" stroke-linecap="round"/><path d="M20 56 L40 24" stroke="#a8743f" stroke-width="5.5" stroke-linecap="round"/>
  <path d="M26 16 L44 6 L56 26 L38 36 Z" fill="#9aa4ae" {SW}/><path d="M29 16 L43 9 L47 15 L33 23 Z" fill="#d6dde3"/>''',
 # person bust
 "population": f'''<circle cx="32" cy="21" r="11" fill="#f2c9a2" {SW}/><path d="M22 14 Q32 4 42 14 Q38 10 32 11 Q26 10 22 14 Z" fill="#6b4226" {SW}/>
  <path d="M10 58 Q10 36 32 36 Q54 36 54 58 Z" fill="#5d8fd6" {SW}/><path d="M26 37 L32 46 L38 37" fill="#f4ecd8" {SW}/>''',
 # star
 "score": f'''<path d="M32 5 L39.5 23 L58 24.5 L44 37 L48.5 56 L32 46 L15.5 56 L20 37 L6 24.5 L24.5 23 Z" fill="#f2c14e" {SW}/>
  <path d="M32 14 L36.5 25.5" stroke="#fff3c4" stroke-width="3" stroke-linecap="round"/>''',
 # hourglass
 "year": f'''<rect x="12" y="6" width="40" height="7" rx="3" fill="#8b5a2b" {SW}/><rect x="12" y="51" width="40" height="7" rx="3" fill="#8b5a2b" {SW}/>
  <path d="M18 13 L46 13 Q46 26 34 32 Q46 38 46 51 L18 51 Q18 38 30 32 Q18 26 18 13 Z" fill="#dfeef7" {SW}/>
  <path d="M22 19 L42 19 Q40 26 32 30 Q24 26 22 19 Z" fill="#e8c26a"/><path d="M20 49 Q24 40 32 38 Q40 40 44 49 Z" fill="#e8c26a"/>''',
 # house
 "city": f'''<path d="M8 30 L32 10 L56 30 Z" fill="#c0503a" {SW}/><rect x="14" y="29" width="36" height="27" fill="#f1e6cc" {SW}/>
  <rect x="28" y="40" width="9" height="16" fill="#7a4b2a" {SW}/><rect x="18" y="35" width="7" height="7" fill="#8fc1e8" stroke="{OUT}" stroke-width="2"/><rect x="40" y="35" width="7" height="7" fill="#8fc1e8" stroke="{OUT}" stroke-width="2"/>''',
 # flag (culture / borders)
 "culture": f'''<path d="M16 58 L16 8" stroke="{OUT}" stroke-width="7" stroke-linecap="round"/><path d="M16 58 L16 8" stroke="#a8743f" stroke-width="3.5" stroke-linecap="round"/>
  <path d="M18 10 Q30 4 40 10 Q48 15 56 11 L56 34 Q48 38 40 33 Q30 27 18 33 Z" fill="#c0503a" {SW}/>''',
 # boot (movement)
 "moves": f'''<path d="M18 8 L36 8 L36 36 L52 42 Q58 45 56 52 L56 56 L14 56 L14 44 Q18 38 18 30 Z" fill="#8b5a2b" {SW}/>
  <path d="M14 50 L56 50" stroke="{OUT}" stroke-width="3"/><path d="M18 16 L36 16" stroke="#c89560" stroke-width="3" stroke-linecap="round"/>''',
 # handshake-ish scroll (diplomacy)
 "diplomacy": f'''<rect x="12" y="10" width="40" height="44" rx="4" fill="#f1e6cc" {SW}/><path d="M8 12 Q8 6 14 6 L50 6 Q56 6 56 12" fill="none" {SW}/>
  <path d="M20 20 L44 20 M20 28 L44 28 M20 36 L36 36" stroke="#a89a7c" stroke-width="3" stroke-linecap="round"/><circle cx="42" cy="44" r="7" fill="#c0503a" {SW}/>''',
}
out = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(out, exist_ok=True)
for k, v in ICONS.items():
    cairosvg.svg2png(bytestring=svg(v).encode(), write_to=os.path.join(out, f"icon_{k}.png"), output_width=64, output_height=64)
print("ok", len(ICONS))

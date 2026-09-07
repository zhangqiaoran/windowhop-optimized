#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import math, random, sys

source = Path(sys.argv[1] if len(sys.argv) > 1 else "Support/AppIconSource.png")
assets = Path("docs/assets")
assets.mkdir(parents=True, exist_ok=True)

img = Image.open(source).convert("RGBA")
side = min(img.size)
left = (img.width - side) // 2
top = (img.height - side) // 2
icon = img.crop((left, top, left + side, top + side))
master = icon.resize((1024, 1024), Image.Resampling.LANCZOS)
master.resize((512, 512), Image.Resampling.LANCZOS).save(assets / "app-icon.png", optimize=True)
master.resize((128, 128), Image.Resampling.LANCZOS).save(assets / "favicon.png", optimize=True)

W, H = 1200, 675
FPS = 16
FRAME_COUNT = 72
frames = []
icon_small = master.resize((112, 112), Image.Resampling.LANCZOS)

def get_font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size=size)
            except Exception:
                pass
    return ImageFont.load_default()

F_BIG = get_font(54, True)
F_MED = get_font(28, True)
F_SMALL = get_font(20)
F_CHIP = get_font(18, True)

random.seed(344)
particles = []
palette = [(80,190,255), (120,120,255), (205,90,255), (255,80,180), (255,190,230)]
for _ in range(520):
    particles.append((
        random.random(), random.random(),
        random.uniform(-0.35, 0.35),
        random.uniform(35, 255),
        random.uniform(1.5, 5.0),
        random.uniform(0.45, 1.0),
        random.choice(palette)
    ))

cards = [
    ("Finder", (43,110,170)),
    ("Code", (28,34,55)),
    ("Browser", (52,43,82)),
]

def ease(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3

def lerp(a, b, t):
    return a + (b - a) * t

for fi in range(FRAME_COUNT):
    t = fi / max(1, FRAME_COUNT - 1)
    phase = t * 5.0
    canvas = Image.new("RGBA", (W, H), (5, 11, 33, 255))
    d = ImageDraw.Draw(canvas)

    for y in range(H):
        yy = y / H
        d.line((0, y, W, y), fill=(int(6+18*yy), int(14+15*yy), int(40+40*yy), 255))

    glow = Image.new("RGBA", (W, H), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-180, 250, 520, 880), fill=(35,120,255,55))
    gd.ellipse((720, -120, 1400, 650), fill=(160,50,255,55))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    canvas = Image.alpha_composite(canvas, glow)
    d = ImageDraw.Draw(canvas)

    canvas.alpha_composite(icon_small, (60, 44))
    d.text((196, 56), "my-alt-tab", font=F_BIG, fill=(245,249,255,255))
    d.text((198, 121), "Lightweight native macOS window switcher", font=F_SMALL, fill=(176,199,236,255))
    d.rounded_rectangle((870,68,1085,118), 24, fill=(40,58,120,190), outline=(110,170,255,220), width=2)
    d.text((918,80), "v3.4.5", font=F_MED, fill=(245,249,255,255))

    chips = [("Lightweight",190), ("Fast 1↔2 switching",240), ("Particle dissolve close",270)]
    x = 65
    for label, width in chips:
        d.rounded_rectangle((x,178,x+width,226), 24, fill=(20,33,74,200), outline=(79,130,224,170))
        d.text((x+18,190), label, font=F_CHIP, fill=(224,235,255,255))
        x += width + 16

    d.rounded_rectangle((115,300,1085,565), 34, fill=(21,31,66,215), outline=(93,149,255,220), width=3)

    if phase < 1.4:
        q = ease(phase / 1.4)
        glow0, glow1 = 1-q, q
    else:
        glow0, glow1 = 0, 1

    dissolve = max(0, min(1, (phase - 2.3) / 1.95))
    reflow = max(0, min(1, (phase - 4.15) / 0.85))
    base_x = [180,455,730]
    positions = [base_x[0], base_x[1], lerp(base_x[2], base_x[1], ease(reflow))]
    cw, ch = 235, 165
    cy = 345

    for idx, (name, bg) in enumerate(cards):
        if idx == 1 and dissolve >= 1:
            continue
        cx = int(positions[idx])
        visible_w = cw if idx != 1 else max(0, int(cw * (1 - dissolve * 0.82)))
        alpha = 255 if idx != 1 else int(255 * (1 - dissolve))

        if visible_w > 0:
            card = Image.new("RGBA", (cw, ch), (0,0,0,0))
            cd = ImageDraw.Draw(card)
            cd.rounded_rectangle((0,0,cw-1,ch-1), 18, fill=bg+(alpha,), outline=(80,105,160,alpha), width=2)
            cd.rounded_rectangle((10,10,cw-10,31), 8, fill=(255,255,255,int(alpha*0.08)))
            for k, col in enumerate([(255,90,90),(255,195,65),(65,210,100)]):
                cd.ellipse((16+18*k,16,24+18*k,24), fill=col+(alpha,))
            if idx == 0:
                cd.rectangle((18,46,86,145), fill=(82,135,215,int(alpha*0.55)))
                cd.rectangle((98,46,216,75), fill=(167,206,255,int(alpha*0.22)))
                cd.rectangle((98,85,216,145), fill=(90,155,230,int(alpha*0.24)))
            elif idx == 1:
                for line in range(9):
                    yy = 48 + 10*line
                    cd.rectangle((22,yy,142+(line%3)*24,yy+3), fill=(85,160,255,int(alpha*0.62)))
            else:
                cd.rectangle((18,45,216,105), fill=(118,82,190,int(alpha*0.35)))
                cd.rectangle((18,115,110,145), fill=(220,210,255,int(alpha*0.18)))
                cd.rectangle((120,115,216,145), fill=(120,190,255,int(alpha*0.18)))
            if idx == 1 and dissolve > 0:
                card = card.crop((0,0,visible_w,ch))
            canvas.alpha_composite(card, (cx,cy))

        strength = glow0 if idx == 0 else glow1 if idx == 1 else 0
        if strength > 0.01 and not (idx == 1 and dissolve > 0.7):
            d = ImageDraw.Draw(canvas)
            d.rounded_rectangle((cx-3,cy-3,cx+cw+3,cy+ch+3), 21,
                                outline=(120,205,255,int(255*strength)), width=3)

        if idx != 1 or dissolve < 0.88:
            d.text((cx+8,520), name, font=F_SMALL, fill=(224,235,255,alpha))

    if dissolve > 0:
        pd = ImageDraw.Draw(canvas)
        origin_x = 455 + cw * (1 - dissolve * 0.82)
        for px, py, ang, speed, size, life, col in particles:
            local = max(0, min(1, (dissolve - (1-px)*0.58) / max(0.01, life)))
            if local <= 0 or local >= 1:
                continue
            x = origin_x + px*cw*0.25 + speed*local + 22*math.sin(ang*8 + local*4)
            y = cy + py*ch + math.sin(ang)*speed*local - 40*local
            a = int(255*(1-local)*min(1,dissolve*2))
            r = size * (1 + local*0.7)
            pd.ellipse((x-r,y-r,x+r,y+r), fill=col+(a,))

    caption = (
        "Fast 1 ↔ 2 switching" if phase < 1.4 else
        "Selected window ready" if phase < 2.3 else
        "Close → particle dissolve" if phase < 4.25 else
        "Lightweight. Clean. Done."
    )
    d = ImageDraw.Draw(canvas)
    box = d.textbbox((0,0), caption, font=F_MED)
    d.text(((W-(box[2]-box[0]))//2, 598), caption, font=F_MED, fill=(235,241,255,255))

    frames.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE, colors=128))

frames[0].save(
    assets / "my-alt-tab-demo.gif",
    save_all=True,
    append_images=frames[1:],
    duration=int(1000/FPS),
    loop=0,
    optimize=True,
    disposal=2
)
print("rendered docs brand assets")


# ---------------------------------------------------------------------------
# GitHub README hero poster.
# The raster includes a visual download button under the canonical app icon.
# README wraps the whole hero in Releases/latest so the CTA is genuinely live.
# ---------------------------------------------------------------------------
HW, HH = 1200, 1600
hero = Image.new("RGBA", (HW, HH), (4, 10, 31, 255))
hd = ImageDraw.Draw(hero)

# vertical midnight gradient
for y in range(HH):
    t = y / HH
    r = int(4 + 11 * t)
    g = int(10 + 8 * t)
    b = int(31 + 35 * t)
    hd.line((0, y, HW, y), fill=(r, g, b, 255))

# soft atmospheric glows
hglow = Image.new("RGBA", (HW, HH), (0, 0, 0, 0))
hgd = ImageDraw.Draw(hglow)
hgd.ellipse((-250, 40, 520, 760), fill=(20, 145, 255, 62))
hgd.ellipse((680, -100, 1460, 720), fill=(155, 45, 255, 58))
hgd.ellipse((180, 890, 1080, 1710), fill=(90, 35, 210, 42))
hglow = hglow.filter(ImageFilter.GaussianBlur(95))
hero = Image.alpha_composite(hero, hglow)
hd = ImageDraw.Draw(hero)

# tiny stars
rng = random.Random(3444)
for _ in range(95):
    x = rng.randrange(35, HW - 35)
    y = rng.randrange(20, 520)
    rr = rng.choice([1, 1, 1, 2])
    a = rng.randrange(65, 180)
    hd.ellipse((x-rr, y-rr, x+rr, y+rr), fill=(200, 220, 255, a))

# brand header
hero_icon = master.resize((230, 230), Image.Resampling.LANCZOS)
hero.alpha_composite(hero_icon, (70, 60))
F_HERO = get_font(74, True)
F_SUB = get_font(31, True)
F_BODY = get_font(24)
F_SECTION = get_font(46, True)
F_CARD = get_font(25, True)
F_TINY = get_font(18)

hd.text((340, 88), "my-alt-tab", font=F_HERO, fill=(244, 249, 255, 255))
hd.text((344, 180), "Lightweight native macOS window switcher",
        font=F_SUB, fill=(226, 235, 255, 255))
hd.text((344, 226), "Switch between windows instantly",
        font=F_BODY, fill=(155, 184, 230, 255))

# version badge
hd.rounded_rectangle((865, 238, 1120, 292), 27,
                     fill=(35, 42, 94, 220), outline=(143, 101, 255, 230), width=2)
hd.text((912, 251), "Latest v3.4.5", font=F_BODY, fill=(244, 248, 255, 255))

# real-looking CTA directly under icon
cta = Image.new("RGBA", (310, 72), (0,0,0,0))
cd = ImageDraw.Draw(cta)
for x in range(310):
    tt = x / 309
    col = (
        int(32 + 185*tt),
        int(161 - 60*tt),
        int(255 - 22*tt),
        245
    )
    cd.line((x, 0, x, 72), fill=col)
mask = Image.new("L", (310,72), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle((0,0,309,71), 36, fill=255)
cta.putalpha(mask)
cta_glow = Image.new("RGBA", (360,122), (0,0,0,0))
cta_glow.alpha_composite(cta, (25,25))
cta_glow = cta_glow.filter(ImageFilter.GaussianBlur(13))
hero.alpha_composite(cta_glow, (43, 278))
hero.alpha_composite(cta, (68, 303))
hd = ImageDraw.Draw(hero)
hd.text((95, 324), "↓  Download Latest v3.4.5", font=F_CARD, fill=(255,255,255,255))

# feature pills
features = [
    ("Lightweight", "Small. Powerful."),
    ("Universal 2", "Intel & Apple Silicon"),
    ("macOS 14+", "Sonoma and later"),
]
fx = 405
for label, sub in features:
    w = 225
    hd.rounded_rectangle((fx, 320, fx+w, 392), 32,
                         fill=(19, 33, 72, 205), outline=(83, 132, 223, 180), width=2)
    hd.text((fx+20, 333), label, font=F_CARD, fill=(236, 243, 255, 255))
    hd.text((fx+20, 363), sub, font=F_TINY, fill=(150, 181, 225, 255))
    fx += w + 18

# install panel
hd.rounded_rectangle((45, 445, 1155, 825), 34,
                     fill=(11, 23, 55, 220), outline=(91, 121, 225, 175), width=2)
hd.text((80, 485), "Install in 3 simple steps", font=F_SECTION,
        fill=(238, 244, 255, 255))

steps = [
    ("1", "Download 3.4.5", "Get the latest release"),
    ("2", "Drag to Applications", "Unzip and install"),
    ("3", "Grant permissions", "Accessibility + previews"),
]
sx = 80
for num, title, sub in steps:
    sw = 320
    hd.rounded_rectangle((sx, 565, sx+sw, 740), 28,
                         fill=(18, 32, 70, 225), outline=(74, 108, 185, 190), width=2)
    hd.ellipse((sx+22, 588, sx+76, 642), fill=(112, 177, 255, 255))
    hd.text((sx+40, 598), num, font=F_CARD, fill=(8, 18, 42, 255))
    hd.text((sx+92, 586), title, font=F_CARD, fill=(244, 248, 255, 255))
    hd.text((sx+92, 624), sub, font=F_TINY, fill=(155, 184, 225, 255))
    # simple pictogram
    if num == "1":
        hd.line((sx+150, 670, sx+150, 708), fill=(72,190,255,255), width=8)
        hd.polygon([(sx+133,694),(sx+167,694),(sx+150,716)], fill=(72,190,255,255))
    elif num == "2":
        hd.rounded_rectangle((sx+118, 670, sx+206, 720), 10, fill=(67,168,248,255))
        hd.text((sx+143, 682), "A", font=F_CARD, fill=(215,238,255,255))
    else:
        hd.ellipse((sx+130, 666, sx+194, 730), outline=(96,211,168,255), width=7)
        hd.line((sx+145,700,sx+158,714), fill=(96,211,168,255), width=6)
        hd.line((sx+158,714,sx+184,684), fill=(96,211,168,255), width=6)
    sx += 355

hd.text((150, 770), "Accessibility for switching", font=F_TINY, fill=(166,196,235,255))
hd.text((650, 770), "Screen Recording only for window previews", font=F_TINY,
        fill=(166,196,235,255))

# product showcase
hd.text((72, 875), "A faster, lighter way to switch.", font=F_SECTION,
        fill=(235, 243, 255, 255))
hd.text((73, 932), "Fast 1↔2 switching  •  Window previews  •  Particle dissolve close",
        font=F_BODY, fill=(155, 187, 235, 255))

# switcher glass bar
hd.rounded_rectangle((160, 1025, 1040, 1288), 34,
                     fill=(35, 42, 82, 210), outline=(112, 162, 255, 210), width=3)

card_xs = [205, 430, 655, 880]
card_cols = [(30,40,62), (45,75,110), (36,38,62), (54,50,82)]
for i, cx in enumerate(card_xs):
    cw, ch = 180, 145
    hd.rounded_rectangle((cx,1085,cx+cw,1085+ch), 20,
                         fill=card_cols[i]+(255,), outline=(76,107,170,255), width=2)
    hd.rounded_rectangle((cx+12,1097,cx+168,1118), 8, fill=(255,255,255,22))
    for k, col in enumerate([(255,90,90),(255,195,65),(65,210,100)]):
        hd.ellipse((cx+16+16*k,1103,cx+23+16*k,1110), fill=col+(255,))
    if i == 1:
        hd.rounded_rectangle((cx-5,1080,cx+cw+5,1085+ch+5), 24,
                             outline=(95,190,255,255), width=4)
        hd.rectangle((cx+20,1130,cx+160,1205), fill=(95,160,220,100))
    elif i == 0:
        for line in range(7):
            yy = 1135 + line*10
            hd.rectangle((cx+20,yy,cx+120+(line%3)*15,yy+3), fill=(90,160,255,150))
    elif i == 2:
        hd.rectangle((cx+25,1138,cx+155,1190), fill=(175,74,215,80))
        hd.rectangle((cx+25,1200,cx+95,1215), fill=(85,150,230,85))
    else:
        hd.rectangle((cx+20,1135,cx+160,1205), fill=(110,165,225,80))

# dissolve last card edge into colorful particles
prng = random.Random(34444)
for _ in range(310):
    x = prng.gauss(1030, 95)
    y = prng.gauss(1155, 72)
    if x < 930:
        continue
    r = prng.uniform(1.3, 4.6)
    col = prng.choice([(75,190,255,210),(126,106,255,220),(220,76,255,215),(255,90,180,220)])
    hd.ellipse((x-r,y-r,x+r,y+r), fill=col)

# compact feature chips
chips = [("🪶", "Lightweight"), ("⚡", "Fast 1↔2"), ("✨", "Particle dissolve"), ("🌐", "English / 中文")]
cx = 100
for icon_char, label in chips:
    w = 240
    hd.rounded_rectangle((cx, 1340, cx+w, 1402), 28,
                         fill=(18,30,66,220), outline=(83,127,215,170), width=2)
    hd.text((cx+18,1357), f"{icon_char}  {label}", font=F_TINY, fill=(229,238,255,255))
    cx += 255

# bottom statement
message = "Designed for people who want a cleaner, lighter Alt+Tab experience on macOS."
bbox = hd.textbbox((0,0), message, font=F_BODY)
hd.text(((HW-(bbox[2]-bbox[0]))//2, 1462), message, font=F_BODY, fill=(178,199,232,255))

# bottom CTA echo
hd.rounded_rectangle((420, 1520, 780, 1582), 31,
                     fill=(45,116,220,235), outline=(151,111,255,240), width=2)
hd.text((495, 1537), "Get my-alt-tab  ›", font=F_CARD, fill=(255,255,255,255))

hero.convert("RGB").save(assets / "my-alt-tab-hero.png", quality=95, optimize=True)
print("rendered docs/assets/my-alt-tab-hero.png")

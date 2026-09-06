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
    d.text((918,80), "v3.4.4", font=F_MED, fill=(245,249,255,255))

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

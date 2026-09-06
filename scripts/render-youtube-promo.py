#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
import imageio.v2 as imageio
import imageio_ffmpeg
import math, random, subprocess, wave, os

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs" / "assets"
ICON = ASSETS / "app-icon.png"
DEMO = ASSETS / "my-alt-tab-demo.gif"
OUT = ASSETS / "my-alt-tab-youtube-promo.mp4"
THUMB = ASSETS / "my-alt-tab-youtube-thumbnail.png"
TMP_VIDEO = ROOT / "build" / "youtube-promo-video.mp4"
TMP_AUDIO = ROOT / "build" / "youtube-promo-audio.wav"
TMP_VIDEO.parent.mkdir(parents=True, exist_ok=True)

W, H = 1920, 1080
FPS = 24
DURATION = 20.0
TOTAL = int(FPS * DURATION)

def font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    for p in candidates:
        if Path(p).exists():
            try: return ImageFont.truetype(p, size=size)
            except Exception: pass
    return ImageFont.load_default()

F_HUGE = font(104, True)
F_BIG = font(70, True)
F_MED = font(42, True)
F_BODY = font(31)
F_SMALL = font(24, True)
F_TINY = font(20)

icon = Image.open(ICON).convert("RGBA")
gif = Image.open(DEMO)
demo_frames = []
try:
    while True:
        demo_frames.append(gif.convert("RGBA").copy())
        gif.seek(gif.tell() + 1)
except EOFError:
    pass

def ease(x):
    x = max(0.0, min(1.0, x))
    return 1 - (1-x)**3

def smoothstep(a,b,x):
    if b == a: return 1.0
    t = max(0.0,min(1.0,(x-a)/(b-a)))
    return t*t*(3-2*t)

def alpha_text(base, xy, text, fnt, fill, alpha=255, anchor=None):
    layer = Image.new("RGBA", base.size, (0,0,0,0))
    d = ImageDraw.Draw(layer)
    color = (*fill[:3], int(alpha))
    d.text(xy, text, font=fnt, fill=color, anchor=anchor)
    return Image.alpha_composite(base, layer)

def draw_bg(t):
    img = Image.new("RGBA",(W,H),(4,8,28,255))
    d = ImageDraw.Draw(img)
    for y in range(H):
        q=y/H
        d.line((0,y,W,y), fill=(int(4+12*q),int(8+9*q),int(28+32*q),255))
    glow = Image.new("RGBA",(W,H),(0,0,0,0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-260,420,880,1420), fill=(20,115,255,55))
    gd.ellipse((1120,-250,2240,820), fill=(165,45,255,52))
    gd.ellipse((570,650,1430,1510), fill=(75,50,225,40))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    img = Image.alpha_composite(img,glow)
    d = ImageDraw.Draw(img)
    rng = random.Random(3444)
    for _ in range(90):
        x=rng.randrange(30,W-30); y=rng.randrange(30,560)
        r=rng.choice([1,1,1,2]); a=rng.randrange(45,125)
        d.ellipse((x-r,y-r,x+r,y+r), fill=(210,225,255,a))
    return img

def paste_center(base, im, center, maxsize, alpha=255):
    im=im.copy()
    scale=min(maxsize[0]/im.width,maxsize[1]/im.height)
    size=(max(1,int(im.width*scale)),max(1,int(im.height*scale)))
    im=im.resize(size,Image.Resampling.LANCZOS)
    if alpha < 255:
        a=im.getchannel("A").point(lambda p:p*alpha//255)
        im.putalpha(a)
    x=int(center[0]-size[0]/2); y=int(center[1]-size[1]/2)
    base.alpha_composite(im,(x,y))
    return (x,y,size[0],size[1])

# deterministic promo particles
prng=random.Random(34444)
particles=[]
for _ in range(460):
    particles.append((
        prng.uniform(0,1),prng.uniform(0,1),prng.uniform(-1,1),
        prng.uniform(90,450),prng.uniform(1.5,6),
        prng.choice([(70,190,255),(118,104,255),(212,72,255),(255,82,170),(255,215,245)])
    ))

def feature_chip(img, x, y, label, alpha=255):
    layer=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(layer)
    box=d.textbbox((0,0),label,font=F_SMALL)
    tw=box[2]-box[0]
    d.rounded_rectangle((x,y,x+tw+58,y+58),29,fill=(17,29,66,int(210*alpha/255)),
                        outline=(85,132,225,int(170*alpha/255)),width=2)
    d.text((x+29,y+29),label,font=F_SMALL,fill=(232,240,255,alpha),anchor="lm")
    return Image.alpha_composite(img,layer)

writer=imageio.get_writer(TMP_VIDEO, fps=FPS, codec="libx264", quality=8, macro_block_size=None)

for fi in range(TOTAL):
    t=fi/FPS
    img=draw_bg(t)
    d=ImageDraw.Draw(img)

    # Scene 1: brand reveal 0-4s
    if t < 4:
        a=int(255*smoothstep(0,0.65,t)*smoothstep(4,3.45,t))
        scale=260+int(40*ease(min(1,t/1.0)))
        ico=icon.resize((scale,scale),Image.Resampling.LANCZOS)
        x=960-scale//2; y=250-scale//2
        glow=Image.new("RGBA",(W,H),(0,0,0,0))
        gd=ImageDraw.Draw(glow); gd.ellipse((x-30,y-30,x+scale+30,y+scale+30),fill=(80,110,255,85))
        glow=glow.filter(ImageFilter.GaussianBlur(45)); img=Image.alpha_composite(img,glow)
        ico.putalpha(ico.getchannel("A").point(lambda p:p*a//255)); img.alpha_composite(ico,(x,y))
        img=alpha_text(img,(960,480),"my-alt-tab",F_HUGE,(245,249,255),a,anchor="mm")
        img=alpha_text(img,(960,570),"Lightweight native macOS window switcher",F_MED,(187,211,250),a,anchor="mm")
        img=feature_chip(img,515,675,"Lightweight",a)
        img=feature_chip(img,810,675,"Fast 1↔2 switching",a)
        img=feature_chip(img,1195,675,"macOS 14+",a)

    # Scene 2: demo 4-13s
    elif t < 13:
        a=int(255*smoothstep(4,4.7,t)*smoothstep(13,12.3,t))
        title = "Switch windows. Instantly." if t < 8.2 else "Fast 1↔2 switching."
        img=alpha_text(img,(960,116),title,F_BIG,(242,247,255),a,anchor="mm")
        idx=int(((t-4)/9.0)*len(demo_frames)*1.4)%len(demo_frames)
        fr=demo_frames[idx]
        # crop/fit into cinematic rounded panel
        panel=Image.new("RGBA",(1450,690),(0,0,0,0))
        scale=min(1400/fr.width,640/fr.height)
        fs=(int(fr.width*scale),int(fr.height*scale))
        rr=fr.resize(fs,Image.Resampling.LANCZOS)
        panel.alpha_composite(rr,((1450-fs[0])//2,(690-fs[1])//2))
        mask=Image.new("L",panel.size,0); md=ImageDraw.Draw(mask); md.rounded_rectangle((0,0,1449,689),42,fill=a)
        panel.putalpha(Image.composite(panel.getchannel("A"),Image.new("L",panel.size,0),mask))
        glow=Image.new("RGBA",(W,H),(0,0,0,0)); gd=ImageDraw.Draw(glow)
        gd.rounded_rectangle((210,205,1710,945),55,fill=(72,105,255,45))
        glow=glow.filter(ImageFilter.GaussianBlur(45)); img=Image.alpha_composite(img,glow)
        img.alpha_composite(panel,(235,230))
        if t > 8.3:
            img=feature_chip(img,320,950,"Window previews",a)
            img=feature_chip(img,705,950,"Responsive MRU",a)
            img=feature_chip(img,1105,950,"Native Swift / AppKit",a)

    # Scene 3: particle close 13-17s
    elif t < 17:
        a=int(255*smoothstep(13,13.55,t)*smoothstep(17,16.45,t))
        img=alpha_text(img,(960,120),"Close a window.",F_BIG,(242,247,255),a,anchor="mm")
        img=alpha_text(img,(960,195),"Watch it dissolve.",F_MED,(185,205,248),a,anchor="mm")
        # faux switcher
        d=ImageDraw.Draw(img)
        d.rounded_rectangle((250,360,1670,720),48,fill=(29,38,78,210),outline=(105,157,255,210),width=3)
        for i,cx in enumerate([330,650,970,1290]):
            d.rounded_rectangle((cx,430,cx+260,625),26,fill=(27+10*i,36+7*i,62+12*i,255),
                                outline=(77,108,172,255),width=2)
            d.rounded_rectangle((cx+18,448,cx+242,474),9,fill=(255,255,255,18))
            for k,col in enumerate([(255,90,90),(255,195,65),(65,210,100)]):
                d.ellipse((cx+22+18*k,456,cx+30+18*k,464),fill=col+(255,))
            if i==2:
                d.rounded_rectangle((cx-6,424,cx+266,631),31,outline=(104,191,255,255),width=5)
        q=smoothstep(13.6,16.5,t)
        origin_x=1230
        pd=ImageDraw.Draw(img)
        for px,py,ang,speed,size,col in particles:
            local=max(0,min(1,(q-(1-px)*0.55)/0.72))
            if local<=0 or local>=1: continue
            x=origin_x+px*180+speed*local+35*math.sin(ang*5+local*4)
            y=445+py*170+ang*35-speed*0.15*local
            r=size*(1+local)
            aa=int(a*(1-local))
            pd.ellipse((x-r,y-r,x+r,y+r),fill=col+(aa,))
        img=alpha_text(img,(960,860),"Particle dissolve close",F_MED,(238,243,255),a,anchor="mm")
        img=alpha_text(img,(960,920),"Beautiful. Lightweight. Zero idle animation loop.",F_BODY,(161,188,230),a,anchor="mm")

    # Scene 4: CTA 17-20s
    else:
        a=int(255*smoothstep(17,17.5,t))
        ico=icon.resize((220,220),Image.Resampling.LANCZOS)
        ico.putalpha(ico.getchannel("A").point(lambda p:p*a//255)); img.alpha_composite(ico,(850,140))
        img=alpha_text(img,(960,440),"my-alt-tab",F_HUGE,(246,249,255),a,anchor="mm")
        img=alpha_text(img,(960,540),"Open source on GitHub",F_MED,(182,206,247),a,anchor="mm")
        # CTA
        layer=Image.new("RGBA",(W,H),(0,0,0,0)); ld=ImageDraw.Draw(layer)
        ld.rounded_rectangle((590,650,1330,770),60,fill=(70,105,235,a),outline=(155,112,255,a),width=3)
        ld.text((960,710),"Download my-alt-tab v3.4.4",font=F_MED,fill=(255,255,255,a),anchor="mm")
        img=Image.alpha_composite(img,layer)
        img=alpha_text(img,(960,845),"github.com/zhangqiaoran/my-alt-tab",F_BODY,(170,193,232),a,anchor="mm")
        img=alpha_text(img,(960,925),"Lightweight • Fast switching • Particle dissolve close",F_SMALL,(224,234,255),a,anchor="mm")

    writer.append_data(np.asarray(img.convert("RGB")))
writer.close()

# Simple original ambient synth soundtrack (no copyrighted audio).
sr=48000
n=int(DURATION*sr)
x=np.linspace(0,DURATION,n,endpoint=False)
audio=np.zeros(n,dtype=np.float32)
# warm minor-ish pad
for f0,amp in [(110,0.06),(164.81,0.045),(220,0.035),(329.63,0.025)]:
    audio += amp*np.sin(2*np.pi*f0*x)
# gentle pulse
audio *= (0.68+0.32*(0.5+0.5*np.sin(2*np.pi*0.5*x)))
# transition whooshes
rng=np.random.default_rng(3444)
for center in [4,8.4,13,17]:
    start=max(0,int((center-0.45)*sr)); end=min(n,int((center+0.45)*sr))
    tt=np.linspace(-1,1,end-start)
    env=np.exp(-5*tt*tt)
    noise=rng.normal(0,1,end-start).astype(np.float32)
    audio[start:end]+=0.045*noise*env
# end sparkle
for f0 in [660,880,990]:
    start=int(17.2*sr)
    tt=np.arange(n-start)/sr
    audio[start:]+=0.015*np.sin(2*np.pi*f0*tt)*np.exp(-tt/2.8)
# fade
fade=int(0.8*sr)
audio[:fade]*=np.linspace(0,1,fade)
audio[-fade:]*=np.linspace(1,0,fade)
audio=np.clip(audio,-0.95,0.95)
with wave.open(str(TMP_AUDIO),"wb") as wf:
    wf.setnchannels(2); wf.setsampwidth(2); wf.setframerate(sr)
    pcm=(audio*32767).astype(np.int16)
    stereo=np.column_stack([pcm,pcm]).ravel()
    wf.writeframes(stereo.tobytes())

ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([
    ffmpeg,"-y","-i",str(TMP_VIDEO),"-i",str(TMP_AUDIO),
    "-c:v","copy","-c:a","aac","-b:a","160k","-shortest",
    "-movflags","+faststart",str(OUT)
],check=True)

# Thumbnail
thumb=draw_bg(0)
ico=icon.resize((300,300),Image.Resampling.LANCZOS)
thumb.alpha_composite(ico,(150,390))
td=ImageDraw.Draw(thumb)
td.text((535,335),"my-alt-tab",font=F_HUGE,fill=(246,249,255,255))
td.text((540,470),"A better Alt+Tab for macOS",font=F_BIG,fill=(190,211,249,255))
td.rounded_rectangle((540,600,1320,700),50,fill=(69,105,232,235),outline=(155,111,255,240),width=3)
td.text((930,650),"LIGHTWEIGHT • FAST • BEAUTIFUL",font=F_MED,fill=(255,255,255,255),anchor="mm")
td.text((540,775),"Window previews  •  Fast 1↔2 switching",font=F_BODY,fill=(170,195,235,255))
td.text((540,830),"Particle dissolve close  •  Open source",font=F_BODY,fill=(170,195,235,255))
thumb.convert("RGB").save(THUMB,quality=95,optimize=True)

print(f"rendered {OUT}")
print(f"rendered {THUMB}")

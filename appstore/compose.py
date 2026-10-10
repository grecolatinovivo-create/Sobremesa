#!/usr/bin/env python3
"""Compone gli screenshot per l'App Store (iPhone 6,9", 1320x2868) secondo il
kit di Astra (docs/APPSTORE_KIT.md): sfondo Ultima luce, titolo Young Serif 82 px
avorio, sottotitolo Source Serif 42 px, screenshot REALE dentro una cornice di iPhone
che prosegue oltre il bordo inferiore.

Uso: python3 compose.py screenshot.png "Titolo" "Sottotitolo" out.png
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "native-ios", "Sobremesa", "Resources", "Fonts")
W, H = 1320, 2868

def compose(shot_path, title, subtitle, out_path):
    bg = Image.open(os.path.join(HERE, "bg.png")).convert("RGB").resize((W, H))
    d = ImageDraw.Draw(bg)
    ft = ImageFont.truetype(os.path.join(FONTS, "YoungSerif-Regular.ttf"), 82)
    fs = ImageFont.truetype(os.path.join(FONTS, "SourceSerif4-Variable.ttf"), 46)
    y = 170
    for text, font, color, gap in ((title, ft, (245, 239, 227), 26), (subtitle, fs, (205, 210, 196), 0)):
        w = d.textlength(text, font=font)
        d.text(((W - w) / 2, y), text, font=font, fill=color)
        y += font.size + gap
    # Cornice: bordo scuro con filo d'ottone, angoli arrotondati; esce in basso.
    shot = Image.open(shot_path).convert("RGB")
    sw = 1000
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    bez = 30
    fx, fy = (W - sw) // 2 - bez, y + 150
    fw, fh = sw + 2 * bez, sh + 2 * bez
    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle((0, 0, fw - 1, fh - 1), radius=150, fill=(8, 10, 9, 255), outline=(231, 188, 108, 150), width=4)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=122, fill=255)
    frame.paste(shot, (bez, bez), mask)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((fx + 10, fy + 30, fx + fw + 10, fy + fh + 30), radius=150, fill=(0, 0, 0, 110))
    from PIL import ImageFilter
    bg = Image.alpha_composite(bg.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(40)))
    bg.alpha_composite(frame, (fx, fy)) if fy + fh <= H else bg.alpha_composite(frame.crop((0, 0, fw, H - fy)), (fx, fy))
    bg.convert("RGB").save(out_path)

if __name__ == "__main__":
    compose(*sys.argv[1:5])

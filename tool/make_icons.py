"""Generates the Closer app icon and splash images from the brand palette.

Run:  python tool/make_icons.py   (needs Pillow)
Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create

Mark = white heart on a coral-light -> rose diagonal gradient, the same as the
in-app CloserLogo widget (lib/core/widgets/closer_logo.dart).
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon"
CORAL_LIGHT = (0xF8, 0x9A, 0x8E)
ROSE = (0xE8, 0x4F, 0x6D)
SIZE = 1024
SS = 4  # supersampling for smooth edges


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(CORAL_LIGHT, ROSE))
    return img


def heart_mask(size, scale):
    """Classic heart curve, centred, `scale` = width as a fraction of size."""
    big = size * SS
    pts = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x, -y))
    w = big * scale / 32.0
    cy_shift = big * 0.03  # optical centring (the heart's mass sits high)
    pts = [(big / 2 + x * w, big / 2 + y * w + cy_shift) for x, y in pts]
    m = Image.new("L", (big, big), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    # Round the tip and notch like Material's favorite_rounded: blur, then
    # re-threshold (a morphological "open/close"), then a light anti-alias.
    m = m.filter(ImageFilter.GaussianBlur(big * 0.012))
    m = m.point(lambda v: 255 if v >= 128 else 0)
    m = m.filter(ImageFilter.GaussianBlur(SS * 0.6))
    return m.resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = gradient(SIZE)

    # Full-bleed icon (iOS masks it; legacy Android).
    icon = bg.copy()
    icon.paste((255, 255, 255), (0, 0), heart_mask(SIZE, 0.52))
    icon.save(OUT / "icon.png")

    # Adaptive icon layers: heart inside the 66 % safe zone.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fg.paste((255, 255, 255, 255), (0, 0), heart_mask(SIZE, 0.36))
    fg.save(OUT / "foreground.png")
    bg.save(OUT / "background.png")

    # Splash mark: rounded gradient tile with the heart (like CloserLogo).
    tile = 512
    mark = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    rounded = Image.new("L", (tile * SS, tile * SS), 0)
    ImageDraw.Draw(rounded).rounded_rectangle(
        (0, 0, tile * SS - 1, tile * SS - 1), radius=int(tile * SS * 0.28), fill=255)
    rounded = rounded.resize((tile, tile), Image.LANCZOS)
    mark.paste(gradient(tile), (0, 0), rounded)
    mark.paste((255, 255, 255, 255), (0, 0), heart_mask(tile, 0.56))
    mark.save(OUT / "splash.png")

    # Android 12+ splash: icon on a circle-safe canvas (centre 2/3 is shown).
    a12 = Image.new("RGBA", (1152, 1152), (0, 0, 0, 0))
    a12.paste(mark.resize((640, 640), Image.LANCZOS), (256, 256))
    a12.save(OUT / "splash_android12.png")
    print("icons written to", OUT)


if __name__ == "__main__":
    main()

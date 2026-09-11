from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "app-icon-cat-dog-v1.png"
OPAQUE = ROOT / "app-icon-cat-dog-v1-opaque.png"
PREVIEW = ROOT / "app-icon-cat-dog-v1-preview.png"


def font(size, bold=False):
    name = "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), size)


def squircle(image, size, radius):
    tile = image.resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    tile.putalpha(mask)
    return tile


def render():
    source = Image.open(SOURCE).convert("RGBA")
    base = Image.new("RGBA", source.size, "#BB4C2C")
    opaque = Image.alpha_composite(base, source).convert("RGB")
    opaque.save(OPAQUE, quality=96)

    canvas = Image.new("RGBA", (720, 460), "#F3F0E7")
    texture = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(texture, "RGBA")
    for x in range(0, 721, 20):
        draw.line((x, 0, x, 460), fill=(52, 72, 57, 8), width=1)
    for y in range(0, 461, 20):
        draw.line((0, y, 720, y), fill=(52, 72, 57, 8), width=1)
    random.seed(18)
    for _ in range(3500):
        x = random.randrange(720)
        y = random.randrange(460)
        draw.point((x, y), fill=(70, 70, 60, 5))
    canvas = Image.alpha_composite(canvas, texture)

    ink = "#1E281F"
    muted = "#697269"
    orange = "#D97849"
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((48, 40), "路慢慢 · App 图标", fill=ink, font=font(24, True))
    draw.text((48, 77), "猫狗陪伴版 v1", fill=muted, font=font(14))

    large = squircle(opaque.convert("RGBA"), 240, 56)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((47, 126, 299, 378), radius=61, fill=(30, 40, 31, 30))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(large, (40, 118))

    medium = squircle(opaque.convert("RGBA"), 84, 19)
    small = squircle(opaque.convert("RGBA"), 48, 11)
    canvas.alpha_composite(medium, (388, 148))
    canvas.alpha_composite(small, (504, 166))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((388, 252), "84 px", fill=ink, font=font(14, True))
    draw.text((504, 252), "48 px", fill=ink, font=font(14, True))
    draw.text((388, 286), "缩小后猫和狗仍能一眼分清", fill=muted, font=font(14))
    draw.line((388, 328, 650, 328), fill=orange, width=3)
    draw.text((388, 350), "暖陶土底 · 无文字 · 无爪印", fill=ink, font=font(15))

    canvas.convert("RGB").save(PREVIEW, quality=96)


if __name__ == "__main__":
    render()

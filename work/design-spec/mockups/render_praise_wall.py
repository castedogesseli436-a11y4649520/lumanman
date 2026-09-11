from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "praise-wall-cat-dog-v1-source-matte.png"
OUTPUT = ROOT / "praise-wall-v1.png"

SCALE = 3
WIDTH, HEIGHT = 360 * SCALE, 800 * SCALE


def px(value):
    return int(round(value * SCALE))


def ui_font(size, bold=False):
    name = "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), px(size))


def contain_rgb(path, width, height):
    image = Image.open(path).convert("RGB")
    image.thumbnail((width, height), Image.Resampling.LANCZOS)
    return image


def render():
    background = "#F3F0E7"
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), background)

    grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid, "RGBA")
    for x in range(0, 361, 10):
        grid_draw.line((px(x), 0, px(x), HEIGHT), fill=(52, 72, 57, 7), width=1)
    for y in range(0, 801, 10):
        grid_draw.line((0, px(y), WIDTH, px(y)), fill=(52, 72, 57, 7), width=1)
    canvas = Image.alpha_composite(canvas, grid)

    random.seed(46)
    grain = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    grain_draw = ImageDraw.Draw(grain, "RGBA")
    for _ in range(18000):
        x = random.randrange(WIDTH)
        y = random.randrange(HEIGHT)
        shade = random.choice((52, 86, 118, 148))
        grain_draw.point((x, y), fill=(shade, shade, shade, 5))
    canvas = Image.alpha_composite(canvas, grain)

    ink = "#1E281F"
    muted = "#697269"
    green = "#315A43"
    orange = "#D97849"
    hairline = "#D5D7CF"
    mint = "#E3ECE7"

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((px(21), px(14)), "11:08", fill=ink, font=ui_font(9, True))
    draw.text((px(339), px(14)), "5G · 78%", fill=ink, font=ui_font(8, True), anchor="ra")

    draw.text((px(21), px(42)), "路 慢 慢", fill=muted, font=ui_font(10))
    draw.text((px(21), px(65)), "夸夸墙", fill=ink, font=ui_font(32, True))
    draw.text((px(339), px(47)), "今天", fill=ink, font=ui_font(13.5, True), anchor="ra")
    draw.text((px(339), px(68)), "已经夸了 3 次", fill=muted, font=ui_font(9.5), anchor="ra")

    companion = contain_rgb(SOURCE, px(352), px(235))
    pet_x = (WIDTH - companion.width) // 2
    pet_y = px(92)
    canvas.alpha_composite(companion.convert("RGBA"), (pet_x, pet_y))

    # The matte-backed companion image overlaps the lower title bounds, so the
    # page title is intentionally redrawn above that layer.
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((px(21), px(65)), "夸夸墙", fill=ink, font=ui_font(32, True))

    # The first praise sits on the blank note held by the animals.
    draw.text((px(148), px(246)), "今天没有拖延，", fill=ink, font=ui_font(11.2, True))
    draw.text((px(148), px(268)), "把难做的事情先完成了。", fill=ink, font=ui_font(11.2, True))
    draw.text((px(148), px(296)), "上午 10:32", fill=muted, font=ui_font(8.2))

    # A second note keeps the wall useful without restoring deleted guidance copy.
    note = Image.new("RGBA", (px(270), px(132)), mint)
    note_draw = ImageDraw.Draw(note, "RGBA")
    note_draw.rectangle((0, 0, note.width - 1, note.height - 1), outline=(49, 90, 67, 22), width=1)
    note_draw.text((px(18), px(22)), "我愿意停下来，", fill=ink, font=ui_font(12.5, True))
    note_draw.text((px(18), px(48)), "好好听完对方的话。", fill=ink, font=ui_font(12.5, True))
    note_draw.text((px(18), px(91)), "下午 15:06", fill=muted, font=ui_font(8.5))
    note_draw.arc((px(230), px(42), px(286), px(98)), 270, 90, fill=(217, 120, 73, 105), width=px(1))
    note = note.rotate(-1.1, resample=Image.Resampling.BICUBIC, expand=True, fillcolor=(0, 0, 0, 0))
    canvas.alpha_composite(note, (px(45), px(372)))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.line((px(21), px(552), px(339), px(552)), fill=hairline, width=1)

    draw.rounded_rectangle(
        (px(24), px(640), px(336), px(694)),
        radius=px(27),
        outline=ink,
        width=px(1),
    )
    draw.text((px(180), px(667)), "+ 贴一张夸夸", fill=ink, font=ui_font(12, True), anchor="mm")

    draw.rectangle((0, px(724), WIDTH, HEIGHT), fill=(243, 240, 231, 250))
    draw.line((0, px(724), WIDTH, px(724)), fill=hairline, width=1)
    navigation = ((48, "今天"), (136, "收支"), (224, "回想"), (312, "记下"))
    for x, label in navigation:
        active = label == "今天"
        draw.text(
            (px(x), px(762)),
            label,
            fill=ink if active else muted,
            font=ui_font(10.5, active),
            anchor="ma",
        )
    draw.line((px(36), px(790), px(60), px(790)), fill=orange, width=px(2.5))

    canvas = canvas.convert("RGB").resize((360, 800), Image.Resampling.LANCZOS)
    canvas.save(OUTPUT, quality=96)


if __name__ == "__main__":
    render()

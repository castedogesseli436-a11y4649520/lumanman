from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "ledger-cat-dog-receipts-v1-source-matte.png"
OUTPUT = ROOT / "ledger-v1.png"

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

    random.seed(62)
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
    receipt = "#F8F6EF"

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((px(21), px(14)), "11:08", fill=ink, font=ui_font(9, True))
    draw.text((px(339), px(14)), "5G · 78%", fill=ink, font=ui_font(8, True), anchor="ra")

    draw.text((px(21), px(42)), "路 慢 慢", fill=muted, font=ui_font(10))
    draw.text((px(21), px(65)), "收支", fill=ink, font=ui_font(34, True))
    draw.text((px(339), px(47)), "8月", fill=ink, font=ui_font(14.5, True), anchor="ra")
    draw.text((px(339), px(69)), "本月", fill=muted, font=ui_font(9.5), anchor="ra")

    # Main receipt: one bounded summary surface, with a soft perforated edge.
    rx0, ry0, rx1, ry1 = map(px, (21, 118, 339, 262))
    draw.rectangle((rx0, ry0, rx1, ry1), fill=receipt, outline=(30, 40, 31, 18), width=1)
    for x in range(26, 340, 10):
        draw.polygon(
            [(px(x), ry1), (px(x + 5), px(267)), (px(x + 10), ry1)],
            fill=(243, 240, 231, 255),
        )
    draw.text((px(38), px(135)), "本月还剩", fill=muted, font=ui_font(9.5))
    draw.text((px(38), px(158)), "¥222.00", fill=ink, font=ui_font(30, True))
    draw.line((px(38), px(207), px(322), px(207)), fill=hairline, width=1)
    draw.text((px(38), px(219)), "收入", fill=muted, font=ui_font(9.2))
    draw.text((px(38), px(238)), "¥222.00", fill=ink, font=ui_font(12.2, True))
    draw.line((px(178), px(219), px(178), px(251)), fill=hairline, width=1)
    draw.text((px(198), px(219)), "支出", fill=muted, font=ui_font(9.2))
    draw.text((px(198), px(238)), "¥0.00", fill=ink, font=ui_font(12.2, True))

    draw.line((px(21), px(286), px(339), px(286)), fill=hairline, width=1)
    draw.text((px(100), px(309)), "收入", fill=ink, font=ui_font(12.5, True), anchor="mm")
    draw.text((px(260), px(309)), "支出", fill=ink, font=ui_font(12.5), anchor="mm")
    draw.line((px(73), px(331), px(127), px(331)), fill=orange, width=px(2))
    draw.line((px(21), px(332), px(339), px(332)), fill=hairline, width=1)

    draw.text((px(21), px(354)), "8月收入", fill=ink, font=ui_font(18, True))
    draw.rounded_rectangle((px(238), px(342), px(339), px(384)), radius=px(21), fill=green)
    draw.text((px(288.5), px(363)), "+ 记收入", fill="#F3F0E7", font=ui_font(11.2, True), anchor="mm")

    rows = ((414, "28日", "工资", "¥111.00"), (470, "27日", "工资", "¥111.00"))
    for y, day, category, amount in rows:
        draw.text((px(21), px(y)), day, fill=muted, font=ui_font(10.2))
        draw.text((px(79), px(y - 1)), category, fill=ink, font=ui_font(12.5, True))
        draw.text((px(304), px(y - 1)), amount, fill=ink, font=ui_font(12.5, True), anchor="ra")
        draw.ellipse((px(321), px(y + 8), px(324), px(y + 11)), fill=ink)
        draw.ellipse((px(327), px(y + 8), px(330), px(y + 11)), fill=ink)
        draw.ellipse((px(333), px(y + 8), px(336), px(y + 11)), fill=ink)
        draw.line((px(21), px(y + 36), px(339), px(y + 36)), fill=hairline, width=1)

    companion = contain_rgb(SOURCE, px(210), px(140))
    canvas.alpha_composite(companion.convert("RGBA"), (px(142), px(528)))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rectangle((0, px(724), WIDTH, HEIGHT), fill=(243, 240, 231, 250))
    draw.line((0, px(724), WIDTH, px(724)), fill=hairline, width=1)
    navigation = ((48, "今天"), (136, "收支"), (224, "回想"), (312, "记下"))
    for x, label in navigation:
        active = label == "收支"
        draw.text(
            (px(x), px(762)),
            label,
            fill=ink if active else muted,
            font=ui_font(10.5, active),
            anchor="ma",
        )
    draw.line((px(124), px(790), px(148), px(790)), fill=orange, width=px(2.5))

    canvas = canvas.convert("RGB").resize((360, 800), Image.Resampling.LANCZOS)
    canvas.save(OUTPUT, quality=96)


if __name__ == "__main__":
    render()

from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
REFERENCE = PROJECT / "work" / "design-spec" / "references"
PHOTO_28 = ROOT / "today-photo-extracted.jpg"
PHOTO_29_SCREEN = REFERENCE / "today-purple-photo-screen.jpg"
PHOTO_29 = ROOT / "recall-purple-photo-extracted.jpg"
COMPANION = ROOT / "recall-cat-dog-photos-v1-source-matte.png"
COMPANION_CUTOUT = ROOT / "recall-cat-dog-photos-v1-cutout.png"
OUTPUT = ROOT / "recall-v1.png"

SCALE = 3
WIDTH, HEIGHT = 360 * SCALE, 800 * SCALE


def px(value):
    return int(round(value * SCALE))


def ui_font(size, bold=False):
    name = "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), px(size))


def cover_image(path, width, height):
    image = Image.open(path).convert("RGB")
    ratio = max(width / image.width, height / image.height)
    image = image.resize(
        (round(image.width * ratio), round(image.height * ratio)),
        Image.Resampling.LANCZOS,
    )
    left = (image.width - width) // 2
    top = (image.height - height) // 2
    return image.crop((left, top, left + width, top + height)).convert("RGBA")


def extract_photo_29():
    source = Image.open(PHOTO_29_SCREEN).convert("RGB")
    # Exact photo rectangle in the user's 1240 x 2772 phone screenshot.
    photo = source.crop((77, 585, 1163, 1398))
    photo.save(PHOTO_29, quality=96)


def remove_companion_matte():
    image = Image.open(COMPANION).convert("RGBA")
    pixels = image.load()
    sample_points = (
        (0, 0),
        (image.width - 1, 0),
        (0, image.height - 1),
        (image.width - 1, image.height - 1),
    )
    background = tuple(
        sum(pixels[x, y][channel] for x, y in sample_points) / len(sample_points)
        for channel in range(3)
    )
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, _ = pixels[x, y]
            distance = (
                (red - background[0]) ** 2
                + (green - background[1]) ** 2
                + (blue - background[2]) ** 2
            ) ** 0.5
            alpha = max(0, min(255, round((distance - 6) * 14)))
            pixels[x, y] = (red, green, blue, alpha)
    image.save(COMPANION_CUTOUT)


def render():
    extract_photo_29()
    remove_companion_matte()

    background = "#F3F0E7"
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), background)

    grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid, "RGBA")
    for x in range(0, 361, 10):
        grid_draw.line((px(x), 0, px(x), HEIGHT), fill=(52, 72, 57, 7), width=1)
    for y in range(0, 801, 10):
        grid_draw.line((0, px(y), WIDTH, px(y)), fill=(52, 72, 57, 7), width=1)
    canvas = Image.alpha_composite(canvas, grid)

    random.seed(83)
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
    soft = "#E8EAE2"

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((px(21), px(14)), "11:08", fill=ink, font=ui_font(9, True))
    draw.text((px(339), px(14)), "5G · 78%", fill=ink, font=ui_font(8, True), anchor="ra")

    draw.text((px(21), px(42)), "路 慢 慢", fill=muted, font=ui_font(10))
    draw.text((px(21), px(65)), "回想", fill=ink, font=ui_font(34, True))
    draw.text((px(339), px(47)), "2026", fill=ink, font=ui_font(14.5, True), anchor="ra")
    draw.text((px(339), px(69)), "慢慢走过", fill=muted, font=ui_font(9.5), anchor="ra")

    draw.text((px(31), px(132)), "‹", fill=green, font=ui_font(21, True), anchor="mm")
    draw.text((px(180), px(132)), "8月", fill=ink, font=ui_font(17, True), anchor="mm")
    draw.text((px(329), px(132)), "›", fill=green, font=ui_font(21, True), anchor="mm")
    draw.line((px(53), px(150), px(307), px(150)), fill=(49, 90, 67, 48), width=1)

    weekday_x = [30, 80, 130, 180, 230, 280, 330]
    for x, label in zip(weekday_x, "一二三四五六日"):
        draw.text((px(x), px(169)), label, fill=muted, font=ui_font(8.8), anchor="mm")

    row_y = [198, 238, 278, 318, 358, 398]
    for day in range(1, 32):
        slot = day + 4  # 2026-08-01 is Saturday in a Monday-first calendar.
        row = slot // 7
        col = slot % 7
        x = weekday_x[col]
        y = row_y[row]

        if day in (28, 29):
            source = PHOTO_28 if day == 28 else PHOTO_29
            thumb = cover_image(source, px(35), px(35))
            canvas.alpha_composite(thumb, (px(x - 17.5), px(y - 15)))
            draw = ImageDraw.Draw(canvas, "RGBA")
            draw.rectangle((px(x - 15), px(y - 13), px(x + 1), px(y + 1)), fill=(243, 240, 231, 225))
            draw.text((px(x - 7), px(y - 6)), str(day), fill=ink, font=ui_font(7.4, True), anchor="mm")
            if day == 28:
                draw.rounded_rectangle(
                    (px(x - 19), px(y - 17), px(x + 19), px(y + 21)),
                    radius=px(2),
                    outline=orange,
                    width=px(1.5),
                )
        else:
            draw.text((px(x), px(y)), str(day), fill=ink, font=ui_font(8.2), anchor="mm")

    draw.line((px(21), px(444), px(339), px(444)), fill=hairline, width=1)
    draw.text((px(21), px(469)), "8月28日", fill=ink, font=ui_font(20, True))
    draw.text((px(339), px(474)), "3条回忆", fill=muted, font=ui_font(9.5), anchor="ra")

    detail_rows = (
        (520, orange, "开心", "哈哈哈哈笑死我了"),
        (558, "#A3A89F", "不开心", "呜呜呜"),
        (596, green, "夸夸", "还不错"),
    )
    for y, dot_color, label, value in detail_rows:
        draw.ellipse((px(22), px(y + 3), px(28), px(y + 9)), fill=dot_color)
        draw.text((px(37), px(y)), label, fill=muted, font=ui_font(9.4))
        draw.text((px(85), px(y - 1)), value, fill=ink, font=ui_font(10.8, True))
        draw.line((px(37), px(y + 27), px(211), px(y + 27)), fill=hairline, width=1)

    companion = Image.open(COMPANION_CUTOUT).convert("RGBA")
    companion.thumbnail((px(150), px(110)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(companion, (px(202), px(588)))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.line((px(21), px(704), px(339), px(704)), fill=soft, width=1)
    draw.rectangle((0, px(724), WIDTH, HEIGHT), fill=(243, 240, 231, 250))
    draw.line((0, px(724), WIDTH, px(724)), fill=hairline, width=1)
    navigation = ((48, "今天"), (136, "收支"), (224, "回想"), (312, "记下"))
    for x, label in navigation:
        active = label == "回想"
        draw.text(
            (px(x), px(762)),
            label,
            fill=ink if active else muted,
            font=ui_font(10.5, active),
            anchor="ma",
        )
    draw.line((px(212), px(790), px(236), px(790)), fill=orange, width=px(2.5))

    canvas = canvas.convert("RGB").resize((360, 800), Image.Resampling.LANCZOS)
    canvas.save(OUTPUT, quality=96)


if __name__ == "__main__":
    render()

from pathlib import Path
import random

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
REFERENCE = PROJECT / "work" / "design-spec" / "references"
PET_SOURCE = REFERENCE / "cat-dog-photo-edge-exact.png"
PET_CUTOUT = ROOT / "cat-dog-photo-edge-exact-cutout.png"
PHOTO_SOURCE = PROJECT / "work" / "design-v3" / "today-source.jpg"
PHOTO_CROP = ROOT / "today-photo-extracted.jpg"
OUTPUT = ROOT / "today-exact-cat-dog-v1.png"

SCALE = 3
WIDTH, HEIGHT = 360 * SCALE, 800 * SCALE


def px(value):
    return int(round(value * SCALE))


def ui_font(size, bold=False):
    name = "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), px(size))


def remove_checkerboard_background():
    source = cv2.imread(str(PET_SOURCE), cv2.IMREAD_COLOR)
    height, width = source.shape[:2]
    hsv = cv2.cvtColor(source, cv2.COLOR_BGR2HSV)

    mask = np.full((height, width), cv2.GC_PR_FGD, dtype=np.uint8)
    pale_neutral = (hsv[:, :, 1] < 20) & (hsv[:, :, 2] > 225)
    mask[pale_neutral] = cv2.GC_PR_BGD

    edge = max(12, round(min(height, width) * 0.012))
    mask[:edge, :] = cv2.GC_BGD
    mask[-edge:, :] = cv2.GC_BGD
    mask[:, :edge] = cv2.GC_BGD
    mask[:, -edge:] = cv2.GC_BGD

    definite_pet = (hsv[:, :, 1] > 34) | (hsv[:, :, 2] < 205)
    mask[definite_pet] = cv2.GC_FGD

    background = np.zeros((1, 65), np.float64)
    foreground = np.zeros((1, 65), np.float64)
    cv2.grabCut(source, mask, None, background, foreground, 7, cv2.GC_INIT_WITH_MASK)

    alpha = np.where(
        (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0
    ).astype(np.uint8)
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.7)
    alpha[alpha < 16] = 0

    rgba = cv2.cvtColor(source, cv2.COLOR_BGR2RGBA)
    rgba[:, :, 3] = alpha
    result = Image.fromarray(rgba)
    bbox = result.getbbox()
    if bbox:
        result = result.crop(bbox)
    result.save(PET_CUTOUT)


def extract_today_photo():
    source = Image.open(PHOTO_SOURCE).convert("RGB")
    # The durable source is a 1240 x 2772 phone screenshot. These coordinates
    # are the exact photo rectangle visible in that screenshot.
    photo = source.crop((77, 474, 1163, 1288))
    photo.save(PHOTO_CROP, quality=96)


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


def contain_image(path, width, height):
    image = Image.open(path).convert("RGBA")
    image.thumbnail((width, height), Image.Resampling.LANCZOS)
    return image


def render():
    remove_checkerboard_background()
    extract_today_photo()

    canvas = Image.new("RGBA", (WIDTH, HEIGHT), "#F4F1E8")

    grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid, "RGBA")
    for x in range(0, 361, 10):
        grid_draw.line((px(x), 0, px(x), HEIGHT), fill=(63, 79, 65, 8), width=1)
    for y in range(0, 801, 10):
        grid_draw.line((0, px(y), WIDTH, px(y)), fill=(63, 79, 65, 8), width=1)
    canvas = Image.alpha_composite(canvas, grid)

    random.seed(31)
    grain = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    grain_draw = ImageDraw.Draw(grain, "RGBA")
    for _ in range(22000):
        x = random.randrange(WIDTH)
        y = random.randrange(HEIGHT)
        shade = random.choice((46, 78, 112, 146))
        grain_draw.point((x, y), fill=(shade, shade, shade, 6))
    canvas = Image.alpha_composite(canvas, grain)

    draw = ImageDraw.Draw(canvas, "RGBA")
    ink = "#1E281F"
    muted = "#697269"
    green = "#315A43"
    orange = "#D97849"
    hairline = "#D5D7CF"

    draw.text((px(21), px(14)), "11:08", fill=ink, font=ui_font(9, True))
    draw.text((px(339), px(14)), "5G · 78%", fill=ink, font=ui_font(8, True), anchor="ra")

    draw.text((px(21), px(42)), "路 慢 慢", fill=muted, font=ui_font(10))
    draw.text((px(21), px(65)), "今天", fill=ink, font=ui_font(34, True))
    draw.text((px(339), px(46)), "8月31日", fill=ink, font=ui_font(15, True), anchor="ra")
    draw.text((px(339), px(69)), "星期一", fill=muted, font=ui_font(10.5), anchor="ra")

    photo_x, photo_y, photo_w, photo_h = map(px, (21, 252, 318, 200))
    photo = cover_image(PHOTO_CROP, photo_w, photo_h)
    photo_mask = Image.new("L", (photo_w, photo_h), 0)
    ImageDraw.Draw(photo_mask).rounded_rectangle(
        (0, 0, photo_w - 1, photo_h - 1), radius=px(7), fill=255
    )
    photo.putalpha(photo_mask)
    canvas.alpha_composite(photo, (photo_x, photo_y))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.rounded_rectangle(
        (photo_x, photo_y, photo_x + photo_w, photo_y + photo_h),
        radius=px(7),
        outline=(30, 40, 31, 24),
        width=1,
    )

    pet = contain_image(PET_CUTOUT, px(316), px(220))
    pet_x = px(22) + (px(316) - pet.width) // 2
    pet_y = px(96) + (px(220) - pet.height) // 2
    shadow = Image.new("RGBA", pet.size, (0, 0, 0, 0))
    shadow.putalpha(pet.getchannel("A").filter(ImageFilter.GaussianBlur(px(2.2))))
    shadow_color = Image.new("RGBA", pet.size, (39, 52, 42, 32))
    shadow_color.putalpha(shadow.getchannel("A").point(lambda value: value * 30 // 255))
    canvas.alpha_composite(shadow_color, (pet_x, pet_y + px(2)))
    canvas.alpha_composite(pet, (pet_x, pet_y))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((px(21), px(466)), "今天拍下的", fill=muted, font=ui_font(10.5))
    draw.text((px(339), px(466)), "换一张", fill=green, font=ui_font(10.5, True), anchor="ra")

    quote_font = ImageFont.truetype("C:/Windows/Fonts/georgia.ttf", px(34))
    draw.text((px(27), px(488)), "“", fill=orange, font=quote_font)
    draw.text(
        (px(45), px(514)),
        "生活的真谛从来都不在别处，",
        fill=ink,
        font=ui_font(14.2, True),
    )
    draw.text(
        (px(45), px(539)),
        "就在日常一点一滴的奋斗里。",
        fill=ink,
        font=ui_font(14.2, True),
    )
    draw.line((px(21), px(592), px(339), px(592)), fill=hairline, width=1)

    draw.text((px(21), px(611)), "今天的心情", fill=ink, font=ui_font(16, True))
    draw.text((px(339), px(613)), "去记下", fill=green, font=ui_font(11, True), anchor="ra")

    draw.ellipse((px(23), px(651), px(31), px(659)), fill=orange)
    draw.text((px(39), px(645)), "开心 · 2条", fill=ink, font=ui_font(11.5, True))
    draw.text((px(39), px(666)), "今天笑得停不下来。", fill=muted, font=ui_font(9.2))

    draw.line((px(179), px(642), px(179), px(683)), fill=hairline, width=1)
    draw.ellipse((px(193), px(651), px(201), px(659)), fill="#AEB4AD")
    draw.text((px(209), px(645)), "不开心 · 1条", fill=ink, font=ui_font(11.5, True))
    draw.text((px(209), px(666)), "也被好好放下。", fill=muted, font=ui_font(9.2))

    draw.ellipse((px(172), px(704), px(176), px(708)), fill=orange)
    draw.ellipse((px(180), px(704), px(184), px(708)), fill=(30, 40, 31, 42))
    draw.ellipse((px(188), px(704), px(192), px(708)), fill=(30, 40, 31, 42))

    draw.rectangle((0, px(724), WIDTH, HEIGHT), fill=(244, 241, 232, 250))
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

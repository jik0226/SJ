"""Generate the SJ app icon — a stylized anchor (닻) on the ocean palette.

Outputs a 1024x1024 PNG into StudyApp/Assets.xcassets/AppIcon.appiconset/.
Kept intentionally simple so the icon stays recognizable at small sizes:
- vertical bar (shank)
- crown ring at the top (the "stock")
- arc + flukes at the bottom
- knock-out white silhouette on a deep-ocean gradient.
"""
from PIL import Image, ImageDraw
import math, os

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "StudyApp", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png",
)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def gradient_bg(img):
    top = (0x1C, 0x4F, 0x82)
    bottom = (0x4D, 0xAE, 0xF2)
    px = img.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        c = lerp(top, bottom, t)
        for x in range(SIZE):
            px[x, y] = c + (255,)

def draw_anchor(draw):
    cx = SIZE / 2
    white = (255, 255, 255, 255)
    # Crown ring (top loop)
    ring_outer_r = 110
    ring_inner_r = 72
    ring_cy = 220
    draw.ellipse(
        (cx - ring_outer_r, ring_cy - ring_outer_r, cx + ring_outer_r, ring_cy + ring_outer_r),
        fill=white,
    )
    draw.ellipse(
        (cx - ring_inner_r, ring_cy - ring_inner_r, cx + ring_inner_r, ring_cy + ring_inner_r),
        fill=(0, 0, 0, 0),
    )
    # Horizontal stock bar
    bar_y = ring_cy + ring_outer_r + 36
    bar_h = 46
    bar_w = 380
    draw.rounded_rectangle(
        (cx - bar_w / 2, bar_y, cx + bar_w / 2, bar_y + bar_h),
        radius=18, fill=white,
    )
    # Shank (vertical bar down to the arc)
    shank_top = bar_y + bar_h
    shank_bot = 760
    shank_w = 60
    draw.rounded_rectangle(
        (cx - shank_w / 2, shank_top, cx + shank_w / 2, shank_bot),
        radius=12, fill=white,
    )
    # Bottom arc (semi-circle opening upward), drawn as a thick ring slice
    arc_cy = shank_bot - 20
    arc_r_outer = 280
    arc_r_inner = 220
    bbox_outer = (cx - arc_r_outer, arc_cy - arc_r_outer, cx + arc_r_outer, arc_cy + arc_r_outer)
    bbox_inner = (cx - arc_r_inner, arc_cy - arc_r_inner, cx + arc_r_inner, arc_cy + arc_r_inner)
    draw.pieslice(bbox_outer, start=10, end=170, fill=white)
    draw.pieslice(bbox_inner, start=0, end=180, fill=(0, 0, 0, 0))
    # Flukes (triangular tips at the arc ends)
    def fluke(angle_deg, flip=False):
        a = math.radians(angle_deg)
        base_x = cx + arc_r_outer * math.cos(a)
        base_y = arc_cy + arc_r_outer * math.sin(a)
        tip_x = cx + (arc_r_outer + 90) * math.cos(a)
        tip_y = arc_cy + (arc_r_outer + 90) * math.sin(a)
        perp = a + math.pi / 2
        off = 70
        p1 = (base_x + off * math.cos(perp), base_y + off * math.sin(perp))
        p2 = (base_x - off * math.cos(perp), base_y - off * math.sin(perp))
        draw.polygon([p1, p2, (tip_x, tip_y)], fill=white)
    fluke(170, flip=False)
    fluke(10, flip=True)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
    gradient_bg(img)
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw_anchor(draw)
    img = Image.alpha_composite(img, overlay).convert("RGB")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, format="PNG", optimize=True)
    print("Wrote", OUT, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()

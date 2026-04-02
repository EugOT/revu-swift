"""Generate a clean DMG background image for Revu installer."""
from PIL import Image, ImageDraw, ImageFont
import os

WIDTH, HEIGHT = 600, 400
# Subtle dark gradient background
img = Image.new("RGB", (WIDTH, HEIGHT))
draw = ImageDraw.Draw(img)

# Gradient from dark charcoal to slightly lighter
for y in range(HEIGHT):
    t = y / HEIGHT
    r = int(28 + t * 12)
    g = int(28 + t * 12)
    b = int(32 + t * 14)
    draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))

# Subtle horizontal divider line near bottom
divider_y = HEIGHT - 80
draw.line([(40, divider_y), (WIDTH - 40, divider_y)], fill=(60, 60, 66), width=1)

# "Drag to install" hint text
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
except OSError:
    font = ImageFont.load_default()

text = "Drag Revu to Applications to install"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((WIDTH - tw) / 2, divider_y + 20), text, fill=(140, 140, 150), font=font)

# Arrow hint between icon positions (left icon at ~150, right at ~450)
arrow_y = HEIGHT // 2 + 10
for x in range(240, 360, 4):
    alpha = 1.0 - abs(x - 300) / 80
    c = int(80 * alpha + 40)
    draw.rectangle([x, arrow_y, x + 2, arrow_y + 2], fill=(c, c, c + 5))
# Arrowhead
draw.polygon([(355, arrow_y - 5), (365, arrow_y + 1), (355, arrow_y + 7)], fill=(90, 90, 95))

out = os.path.join(os.path.dirname(__file__), "dmg-background.png")
img.save(out)
# create-dmg requires @2x for retina
img_2x = img.resize((WIDTH * 2, HEIGHT * 2), Image.LANCZOS)
img_2x.save(out.replace(".png", "@2x.png"))
print(f"Saved {out}")

"""Build Countdown.ico from Countdown.png for ps2exe -iconFile."""
from pathlib import Path

try:
    from PIL import Image
except ImportError as e:
    raise SystemExit("Install Pillow: pip install pillow") from e

root = Path(__file__).resolve().parent
png = root / "Countdown.png"
ico = root / "Countdown.ico"
if not png.is_file():
    raise SystemExit(f"Missing {png}")

img = Image.open(png)
if img.mode not in ("RGB", "RGBA"):
    img = img.convert("RGBA")
img.save(ico, format="ICO", sizes=[(256, 256), (48, 48), (32, 32), (16, 16)])
print(f"Wrote {ico}")

"""Build the addon's icon files from the source artwork (Media/Source/signpost-icon.jpg), reproducibly.

    python tools/make_icons.py            writes Media/icon.tga, Media/icon-round.tga and Media/curseforge-logo.png

- Media/icon.tga: 128x128 square, 32-bit uncompressed TGA (the client reads only TGA and BLP, with power-of-two sides):
  the TOC's `## IconTexture` (the AddOns list).
- Media/icon-round.tga: the same with soft round edges (a circular alpha mask), for the minimap button, which sits in a round
  ring: the key shapes of the artwork lie inside the inscribed circle.
- Media/curseforge-logo.png: 512x512 square PNG for the CurseForge project logo (not shipped in the addon zip).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Media" / "Source" / "signpost-icon.jpg"
GAME_SIZE = 128
LOGO_SIZE = 512
FEATHER = 0.03  # fraction of the diameter blurred at the round edge


def resized(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.LANCZOS)


def round_mask(size: int) -> Image.Image:
    """A white disc on black, drawn at 4x and blurred a little, so the edge is smooth at any size."""
    big = size * 4
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=big * FEATHER / 2))
    return mask.resize((size, size), Image.LANCZOS)


def save_tga(image: Image.Image, path: Path) -> None:
    # 32 bits per pixel, uncompressed, origin bottom-left: what the client's own art tools write.
    image.convert("RGBA").save(path, "TGA", rle=False, orientation=1)


def main() -> int:
    if not SOURCE.is_file():
        print(f"make_icons: {SOURCE} not found", file=sys.stderr)
        return 1
    source = Image.open(SOURCE).convert("RGB")
    if source.width != source.height:
        print(f"make_icons: the source must be square, it is {source.size}", file=sys.stderr)
        return 1
    media = ROOT / "Media"
    square = resized(source, GAME_SIZE).convert("RGBA")
    save_tga(square, media / "icon.tga")
    round_icon = square.copy()
    round_icon.putalpha(round_mask(GAME_SIZE))
    save_tga(round_icon, media / "icon-round.tga")
    resized(source, LOGO_SIZE).save(media / "curseforge-logo.png", optimize=True)
    for name in ("icon.tga", "icon-round.tga", "curseforge-logo.png"):
        print(f"wrote Media/{name} ({(media / name).stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

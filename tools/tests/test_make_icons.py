import re
import struct
import tempfile
import unittest
from pathlib import Path

import package

try:  # the converter is a developer tool: the checks on the shipped files below need only the standard library
    import make_icons
    from PIL import Image
except ImportError:  # CI installs nothing beyond the standard library
    make_icons = Image = None

ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / "Media"


def power_of_two(n: int) -> bool:
    return n > 0 and n & (n - 1) == 0


def tga_info(path: Path) -> dict:
    """The header of an uncompressed true-colour TGA, and the alpha of its first pixel."""
    data = path.read_bytes()
    id_length, _, image_type = data[0], data[1], data[2]
    width, height = struct.unpack("<HH", data[12:16])
    bits = data[16]
    first = 18 + id_length
    return {"type": image_type, "width": width, "height": height, "bits": bits, "alpha": data[first + 3], "size": len(data)}


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    return struct.unpack(">II", data[16:24])


@unittest.skipIf(make_icons is None, "Pillow is not installed")
class MakeIconsTest(unittest.TestCase):
    def test_the_round_mask_is_a_soft_disc(self):
        mask = make_icons.round_mask(64)
        self.assertEqual(mask.size, (64, 64))
        self.assertEqual(mask.getpixel((0, 0)), 0)  # the corner is cut
        self.assertEqual(mask.getpixel((32, 32)), 255)  # the middle is whole

    def test_a_tga_is_32_bit_with_the_alpha_channel(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.tga"
            make_icons.save_tga(Image.new("RGBA", (16, 16), (10, 20, 30, 128)), path)
            info = tga_info(path)
            self.assertEqual((info["type"], info["bits"], info["width"], info["height"]), (2, 32, 16, 16))
            self.assertEqual(info["alpha"], 128)


class ShippedIconsTest(unittest.TestCase):
    """The files the client and the packaging actually use (standard library only)."""

    def test_the_game_textures_are_square_power_of_two_uncompressed_32_bit(self):
        for name in ("icon.tga", "icon-round.tga"):
            info = tga_info(MEDIA / name)
            self.assertEqual(info["width"], info["height"], name)
            self.assertTrue(power_of_two(info["width"]) and info["width"] <= 256, f"{name} is {info['width']} wide")
            self.assertEqual((info["type"], info["bits"]), (2, 32), name)  # uncompressed true colour with alpha

    def test_the_round_icon_has_transparent_corners_and_the_square_one_does_not(self):
        self.assertEqual(tga_info(MEDIA / "icon-round.tga")["alpha"], 0)
        self.assertEqual(tga_info(MEDIA / "icon.tga")["alpha"], 255)

    def test_both_tocs_point_at_an_icon_that_exists(self):
        for toc in ("Signpost.toc", "Signpost_Camelot.toc"):
            lines = (ROOT / toc).read_text(encoding="utf-8").splitlines()
            line = next(item for item in lines if item.startswith("## IconTexture:"))
            path = line.split(":", 1)[1].strip().replace("\\", "/")
            match = re.fullmatch(r"Interface/AddOns/Signpost/(.+)", path)
            self.assertIsNotNone(match, f"{toc}: {path}")
            self.assertTrue((ROOT / (match.group(1) + ".tga")).is_file(), f"{toc}: {path}.tga")

    def test_the_source_art_and_the_curseforge_logo_stay_out_of_the_zip(self):
        ignores = package.pkgmeta_ignores((ROOT / ".pkgmeta").read_text(encoding="utf-8"))
        files = ["Media/icon.tga", "Media/icon-round.tga", "Media/Source/signpost-icon.jpg", "Media/curseforge-logo.png"]
        self.assertEqual(package.shipped_files(files, ignores), ["Media/icon-round.tga", "Media/icon.tga"])

    def test_the_curseforge_logo_is_a_square_png(self):
        width, height = png_size(MEDIA / "curseforge-logo.png")
        self.assertEqual(width, height)
        self.assertGreaterEqual(width, 400)


if __name__ == "__main__":
    unittest.main()

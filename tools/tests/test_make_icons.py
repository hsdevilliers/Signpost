import re
import tempfile
import unittest
from pathlib import Path

import make_icons
import package
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / "Media"


def power_of_two(n: int) -> bool:
    return n > 0 and n & (n - 1) == 0


class MakeIconsTest(unittest.TestCase):
    def test_the_round_mask_is_a_soft_disc(self):
        mask = make_icons.round_mask(64)
        self.assertEqual(mask.size, (64, 64))
        self.assertEqual(mask.getpixel((0, 0)), 0)  # the corner is cut
        self.assertEqual(mask.getpixel((32, 32)), 255)  # the middle is whole
        self.assertTrue(0 < mask.getpixel((32, 1)) < 255 or mask.getpixel((32, 1)) == 255)

    def test_a_tga_is_32_bit_with_the_alpha_channel(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.tga"
            make_icons.save_tga(Image.new("RGBA", (16, 16), (10, 20, 30, 128)), path)
            with Image.open(path) as image:
                self.assertEqual((image.size, image.mode), ((16, 16), "RGBA"))
                self.assertEqual(image.getpixel((3, 3)), (10, 20, 30, 128))


class ShippedIconsTest(unittest.TestCase):
    """The files the client and the packaging actually use."""

    def test_the_game_textures_are_square_power_of_two_rgba(self):
        for name in ("icon.tga", "icon-round.tga"):
            with Image.open(MEDIA / name) as image:
                self.assertEqual(image.width, image.height, name)
                self.assertTrue(power_of_two(image.width) and image.width <= 256, f"{name} is {image.size}")
                self.assertEqual(image.mode, "RGBA", name)

    def test_the_round_icon_has_transparent_corners_and_the_square_one_does_not(self):
        with Image.open(MEDIA / "icon-round.tga") as round_icon, Image.open(MEDIA / "icon.tga") as square:
            self.assertEqual(round_icon.convert("RGBA").getpixel((0, 0))[3], 0)
            self.assertEqual(square.convert("RGBA").getpixel((0, 0))[3], 255)

    def test_both_tocs_point_at_an_icon_that_exists(self):
        for toc in ("Signpost.toc", "Signpost_Camelot.toc"):
            line = next(
                l for l in (ROOT / toc).read_text(encoding="utf-8").splitlines() if l.startswith("## IconTexture:")
            )
            path = line.split(":", 1)[1].strip().replace("\\", "/")
            match = re.fullmatch(r"Interface/AddOns/Signpost/(.+)", path)
            self.assertIsNotNone(match, f"{toc}: {path}")
            self.assertTrue((ROOT / (match.group(1) + ".tga")).is_file(), f"{toc}: {path}.tga")

    def test_the_source_art_and_the_curseforge_logo_stay_out_of_the_zip(self):
        ignores = package.pkgmeta_ignores((ROOT / ".pkgmeta").read_text(encoding="utf-8"))
        files = ["Media/icon.tga", "Media/icon-round.tga", "Media/Source/signpost-icon.jpg", "Media/curseforge-logo.png"]
        self.assertEqual(package.shipped_files(files, ignores), ["Media/icon-round.tga", "Media/icon.tga"])

    def test_the_curseforge_logo_is_a_square_png(self):
        with Image.open(MEDIA / "curseforge-logo.png") as image:
            self.assertEqual(image.width, image.height)
            self.assertGreaterEqual(image.width, 400)


if __name__ == "__main__":
    unittest.main()

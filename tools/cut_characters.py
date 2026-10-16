"""Cut the Bluey characters out of the character poster into transparent PNGs.

Usage: python3 tools/cut_characters.py <poster.jpg> <out_dir> [contact_sheet.png]

Needs Pillow, numpy and scipy. Each character is a hand-placed box on the poster; the sky
(a smooth blue gradient) is removed by flood-filling from the box border.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

# name: (x0, y0, x1, y1) on the 735x1012 poster, labels excluded.
BOXES = {
    "dad": (20, 12, 120, 178), "mum": (125, 12, 250, 178), "nana": (255, 12, 375, 178),
    "grandad": (380, 12, 500, 178), "stripe": (500, 12, 606, 178), "trixie": (612, 12, 725, 178),
    "indy": (10, 215, 130, 380), "chloe": (135, 215, 255, 380), "calypso": (262, 215, 385, 380),
    "rusty": (385, 215, 478, 380), "lucky": (500, 215, 620, 380), "mackenzie": (615, 215, 730, 380),
    "bluey": (5, 410, 130, 565), "bingo": (600, 410, 730, 565),
    "coco": (20, 605, 125, 765), "jack": (135, 605, 255, 765), "judo": (262, 605, 385, 765),
    "socks": (395, 605, 510, 765), "honey": (515, 605, 625, 765), "muffin": (620, 605, 730, 765),
    "buddy": (20, 828, 125, 970), "missy": (135, 828, 250, 970), "bently": (255, 828, 380, 970),
    "winton": (385, 828, 500, 970), "terriers": (505, 828, 730, 970),
}
TOLERANCE = 28  # colour distance from the sky at that row
MIN_PIECE = 0.02  # keep detached pieces bigger than this share of the largest piece


def cut(img: np.ndarray, box: tuple[int, int, int, int]) -> Image.Image:
    x0, y0, x1, y1 = box
    crop = img[y0:y1, x0:x1].astype(float)
    # Sky colour for each row: median of the outermost columns of the box.
    edge = np.concatenate([crop[:, :3], crop[:, -3:]], axis=1)
    sky = np.median(edge, axis=1)[:, None, :]
    near_sky = np.linalg.norm(crop - sky, axis=2) < TOLERANCE
    labels, _ = ndimage.label(near_sky)
    border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, border[border > 0])
    foreground = ~background
    pieces, n = ndimage.label(foreground)
    if n == 0:
        raise SystemExit(f"nothing found in {box}")
    sizes = ndimage.sum(foreground, pieces, range(1, n + 1))
    keep = [i + 1 for i, s in enumerate(sizes) if s >= MIN_PIECE * sizes.max()]
    foreground = np.isin(pieces, keep)
    foreground = ndimage.binary_fill_holes(foreground)
    # Trim the one-pixel sky-coloured halo, then soften the edge.
    foreground = ndimage.binary_erosion(foreground, iterations=1)
    alpha = ndimage.gaussian_filter(foreground.astype(float), 0.7)
    rgba = np.dstack([crop, alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    return out.crop(out.getbbox())


def main() -> None:
    poster = np.array(Image.open(sys.argv[1]).convert("RGB"))
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    sprites = {name: cut(poster, box) for name, box in BOXES.items()}
    for name, sprite in sprites.items():
        sprite.save(out_dir / f"{name}.png", optimize=True)
    if len(sys.argv) > 3:
        cell, cols = 180, 5
        rows = -(-len(sprites) // cols)
        sheet = Image.new("RGB", (cols * cell, rows * cell), (255, 105, 180))
        for i, sprite in enumerate(sprites.values()):
            s = sprite.copy()
            s.thumbnail((cell - 10, cell - 10))
            sheet.paste(s, ((i % cols) * cell + 5, (i // cols) * cell + 5), s)
        sheet.save(sys.argv[3])


if __name__ == "__main__":
    main()

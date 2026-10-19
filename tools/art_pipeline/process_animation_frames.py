from __future__ import annotations

import argparse
import colorsys
from pathlib import Path

from PIL import Image, ImageFilter


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Convert keyed animation frames into aligned WebP sprites.')
    parser.add_argument('source_dir', type=Path)
    parser.add_argument('target_dir', type=Path)
    parser.add_argument('--pattern', default='frame_*.png')
    parser.add_argument('--prefix', default='frame')
    parser.add_argument('--canvas', type=int, default=192)
    parser.add_argument('--content', type=int, default=176)
    return parser.parse_args()


def build_mask(image: Image.Image) -> Image.Image:
    mask = Image.new('L', image.size, 255)
    mask_pixels = mask.load()
    pixels = image.load()
    if mask_pixels is None or pixels is None:
        raise RuntimeError('Image pixel access is unavailable')
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, _ = pixels[x, y]
            hue, saturation, _ = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
            keyed = (
                0.18 <= hue <= 0.45 and saturation >= 0.22 and green > red * 1.06 and green > blue * 1.12 and green > 85
            )
            mask_pixels[x, y] = 0 if keyed else 255
    return mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))


def main() -> None:
    args = parse_args()
    source_dir: Path = args.source_dir
    target_dir: Path = args.target_dir
    canvas_size: int = args.canvas
    content_size: int = args.content
    if canvas_size <= 0 or content_size <= 0 or content_size > canvas_size:
        raise ValueError('Canvas and content sizes must be positive, with content no larger than canvas')

    paths = sorted(source_dir.glob(args.pattern))
    if not paths:
        raise RuntimeError(f'No source frames matched {args.pattern} in {source_dir}')

    target_dir.mkdir(parents=True, exist_ok=True)
    frames: list[Image.Image] = []
    boxes: list[tuple[int, int, int, int]] = []
    threshold_table = [0 if value <= 28 else 255 for value in range(256)]
    for path in paths:
        image = Image.open(path).convert('RGBA')
        mask = build_mask(image)
        image.putalpha(mask)
        bbox = mask.point(threshold_table).getbbox()
        if bbox is None:
            raise RuntimeError(f'No foreground found in {path}')
        frames.append(image)
        boxes.append(bbox)

    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    union = (left, top, right, bottom)
    width = right - left
    height = bottom - top
    scale = min(content_size / width, content_size / height)
    new_size = (max(1, round(width * scale)), max(1, round(height * scale)))

    for index, image in enumerate(frames):
        cropped = image.crop(union).resize(new_size, Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
        x = (canvas_size - cropped.width) // 2
        y = canvas_size - cropped.height - 4
        canvas.alpha_composite(cropped, (x, y))
        output = target_dir / f'{args.prefix}_{index:02d}.webp'
        canvas.save(output, 'WEBP', lossless=True, method=6)

    print(f'Processed {len(frames)} frames using union crop {union} into {target_dir}')


if __name__ == '__main__':
    main()

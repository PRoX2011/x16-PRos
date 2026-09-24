from PIL import Image
import os

def prepare_bmp(input_path, output_path, max_width=320, max_height=240, stretch=False):
    """
    Convert an image to 8-bit BMP with a 256-color palette.

    Args:
        input_path  (str): Path to the input image (PNG, JPG, etc.).
        output_path (str): Path to save the output BMP file.
        max_width   (int): Target / maximum width.
        max_height  (int): Target / maximum height.
        stretch     (bool): If True, force exact (max_width, max_height) size
                            ignoring aspect ratio. Otherwise fit while keeping
                            aspect ratio (thumbnail behaviour).
    """
    try:
        img = Image.open(input_path)

        if img.mode != 'RGB':
            img = img.convert('RGB')

        if stretch:
            img = img.resize((max_width, max_height), Image.Resampling.LANCZOS)
        else:
            img.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)

        img_8bit = img.quantize(colors=256, method=2)

        img_8bit.save(output_path, 'BMP')
        print(f"Successfully converted {input_path} to {output_path}")
        print(f"Output size: {img_8bit.size[0]}x{img_8bit.size[1]}, 8-bit BMP")

    except Exception as e:
        print(f"Error processing {input_path}: {str(e)}")

def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="Convert an image to 8-bit BMP (256-color palette).")
    parser.add_argument("input", help="Input image (PNG, JPG, ...).")
    parser.add_argument("output", nargs="?",
                        help="Output .bmp path (default: <input>_converted.bmp).")
    parser.add_argument("-W", "--width",  type=int, default=320, help="Target width.")
    parser.add_argument("-H", "--height", type=int, default=240, help="Target height.")
    parser.add_argument("-s", "--stretch", action="store_true",
                        help="Force exact WxH, ignore aspect ratio "
                             "(useful for full-screen mode 13h logos).")
    args = parser.parse_args()

    output_path = args.output or os.path.splitext(args.input)[0] + '_converted.bmp'
    prepare_bmp(args.input, output_path,
                max_width=args.width, max_height=args.height,
                stretch=args.stretch)

if __name__ == "__main__":
    main()

from PIL import Image
import os

def prepare_bmp(input_path, output_path, max_width=220, max_height=170):
    """
    Convert an image to 8-bit BMP with a 256-color palette.
    
    Args:
        input_path  (str): Path to the input image (PNG, JPG, etc.).
        output_path (str): Path to save the output BMP file.
        max_width   (int): Maximum width.
        max_height  (int): Maximum height.
    """
    try:
        img = Image.open(input_path)
        
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        img.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
        
        img_8bit = img.quantize(colors=256, method=2)  
        
        img_8bit.save(output_path, 'BMP')
        print(f"Successfully converted {input_path} to {output_path}")
        print(f"Output size: {img_8bit.size[0]}x{img_8bit.size[1]}, 8-bit BMP")
        
    except Exception as e:
        print(f"Error processing {input_path}: {str(e)}")

def main():
    import sys
    if len(sys.argv) < 2:
        print("Usage: python png2bmp.py <input_image> [output_image]")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(input_path)[0] + '_converted.bmp'
    
    prepare_bmp(input_path, output_path)

if __name__ == "__main__":
    main()

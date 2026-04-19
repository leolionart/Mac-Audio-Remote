import os
from PIL import Image, ImageFilter

def resize_icon(input_path, output_path, size=(128, 128)):
    if not os.path.exists(input_path):
        return
    with Image.open(input_path) as img:
        img = img.resize(size, Image.Resampling.LANCZOS)
        img.save(output_path, format="PNG")
        print(f"Resized icon to {output_path}")

def center_crop(input_path, output_path, target_size=(1400, 560)):
    if not os.path.exists(input_path):
        return
    with Image.open(input_path) as img:
        width, height = img.size
        target_w, target_h = target_size
        
        # Calculate aspect ratios
        img_ratio = width / height
        target_ratio = target_w / target_h
        
        if img_ratio > target_ratio:
            # Image is wider than target, resize based on height
            new_h = target_h
            new_w = int(new_h * img_ratio)
        else:
            # Image is taller than target, resize based on width
            new_w = target_w
            new_h = int(new_w / img_ratio)
            
        img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Center crop
        left = (new_w - target_w) / 2
        top = (new_h - target_h) / 2
        right = (new_w + target_w) / 2
        bottom = (new_h + target_h) / 2
        
        img = img.crop((left, top, right, bottom))
        img.save(output_path, format="PNG")
        print(f"Center cropped marquee to {output_path}")

def pad_screenshot_blur_bg(input_path, output_path, target_size=(1280, 800)):
    if not os.path.exists(input_path):
        return
    with Image.open(input_path) as img:
        img = img.convert("RGBA")
        width, height = img.size
        target_w, target_h = target_size
        
        # 1. Create blurred background
        # Resize image to fill the target size
        img_ratio = width / height
        target_ratio = target_w / target_h
        
        if img_ratio > target_ratio:
            bg_h = target_h
            bg_w = int(bg_h * img_ratio)
        else:
            bg_w = target_w
            bg_h = int(bg_w / img_ratio)
            
        bg = img.convert("RGB").resize((bg_w, bg_h), Image.Resampling.LANCZOS)
        
        # Center crop the background to exact target size
        left = (bg_w - target_w) / 2
        top = (bg_h - target_h) / 2
        right = (bg_w + target_w) / 2
        bottom = (bg_h + target_h) / 2
        bg = bg.crop((left, top, right, bottom))
        
        # Apply heavy blur
        bg = bg.filter(ImageFilter.GaussianBlur(radius=30))
        
        # Darken the background slightly so the screenshot pops
        dark_overlay = Image.new("RGBA", bg.size, (0, 0, 0, 100))
        bg = Image.alpha_composite(bg.convert("RGBA"), dark_overlay)
        
        # 2. Add the original screenshot on top
        # Scale screenshot if it's too big, with some padding (e.g., 90% of target)
        max_w = int(target_w * 0.9)
        max_h = int(target_h * 0.9)
        
        if width > max_w or height > max_h:
            scale = min(max_w / width, max_h / height)
            new_w = int(width * scale)
            new_h = int(height * scale)
            fg = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        else:
            fg = img
        
        # Draw a subtle drop shadow
        shadow = Image.new("RGBA", bg.size, (0, 0, 0, 0))
        shadow_w, shadow_h = fg.size
        # Make a black rectangle same size as fg
        shadow_rect = Image.new("RGBA", fg.size, (0, 0, 0, 150))
        # Paste it onto dummy image, slightly offset
        offset_y = 10
        offset_x = 0
        shadow_pos = ((target_w - shadow_w) // 2 + offset_x, (target_h - shadow_h) // 2 + offset_y)
        shadow.paste(shadow_rect, shadow_pos)
        # Blur the shadow
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=15))
        
        # Composite shadow over bg
        bg = Image.alpha_composite(bg, shadow)
        
        # Composite foreground over bg
        fg_pos = ((target_w - fg.width) // 2, (target_h - fg.height) // 2)
        bg.paste(fg, fg_pos, fg)
        
        bg.convert("RGB").save(output_path, format="PNG")
        print(f"Padded screenshot to {output_path}")

def main():
    print("Standardizing Chrome Web Store Assets...")
    
    # 1. Store Icon (128x128)
    resize_icon("app_icon.png", "icon_128.png")
    
    # 2. Small promo tile (440x280)
    # bg_small.png is already 440x280, check it
    if os.path.exists("bg_small.png"):
        with Image.open("bg_small.png") as img:
            if img.size != (440, 280):
                center_crop("bg_small.png", "bg_small_440x280.png", (440, 280))
            else:
                print("bg_small.png is already 440x280")
                
    # 3. Marquee promo (1400x560)
    center_crop("image.png", "marquee_1400x560.png", (1400, 560))
    
    # 4. Screenshots (1280x800)
    screenshots = ["app_menu.png", "app_settings.png", "menu_ui.png"]
    for sc_name in screenshots:
        if os.path.exists(sc_name):
            out_name = sc_name.replace(".png", "_1280x800.png")
            pad_screenshot_blur_bg(sc_name, out_name, (1280, 800))

if __name__ == "__main__":
    main()

from PIL import Image
import sys
import os

def generate_transparent_icon(source_path, target_path):
    print(f"Processing {source_path}...")
    try:
        img = Image.open(source_path).convert("RGBA")
        datas = img.getdata()

        newData = []
        for item in datas:
            # item is (R, G, B, A)
            # Threshold: if it's "bright" enough, keep it as white silhouette
            # Otherwise, make it 100% transparent
            # We use a combined brightness threshold
            avg = (item[0] + item[1] + item[2]) / 3
            if avg > 200: # Adjust threshold if needed
                newData.append((255, 255, 255, 255))
            else:
                newData.append((255, 255, 255, 0))

        img.putdata(newData)
        
        # Ensure the directory exists
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        
        img.save(target_path, "PNG")
        print(f"Success! Saved to {target_path}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    src = r"d:\baas_platform\kesh_kart\assets\images\icon.png"
    dest = r"d:\baas_platform\kesh_kart\android\app\src\main\res\drawable\ic_notification.png"
    generate_transparent_icon(src, dest)

import re

with open('lib/features/artwork_detail/screens/artwork_detail_screen.dart', 'r') as f:
    content = f.read()

# We need to find the start of the Creator details
creator_start_str = "// Creator details and Likes row (Spaced out beautifully)"
creator_start_idx = content.find(creator_start_str)

desc_start_str = "// Artwork Description and Tags box"
desc_start_idx = content.find(desc_start_str)

image_start_str = "// Beautiful Hero Image Display with rounded bottom edges"
image_start_idx = content.find(image_start_str)

divider_start_str = "const Padding(\n                          padding: EdgeInsets.symmetric("
divider_start_idx = content.find(divider_start_str, image_start_idx)

if creator_start_idx != -1 and desc_start_idx != -1 and image_start_idx != -1 and divider_start_idx != -1:
    creator_block = content[creator_start_idx:desc_start_idx].strip()
    desc_block = content[desc_start_idx:image_start_idx].strip()
    image_block = content[image_start_idx:divider_start_idx].strip()
    
    new_order = f"{image_block}\n\n                        {creator_block}\n\n                        {desc_block}\n\n                        "
    
    old_section = content[creator_start_idx:divider_start_idx]
    new_content = content.replace(old_section, new_order)
    
    with open('lib/features/artwork_detail/screens/artwork_detail_screen.dart', 'w') as f:
        f.write(new_content)
    print("Success")
else:
    print("Failed to find indices", creator_start_idx, desc_start_idx, image_start_idx, divider_start_idx)

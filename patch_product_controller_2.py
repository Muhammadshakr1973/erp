import sys

with open('backend/app/Http/Controllers/Api/V1/ProductController.php', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("['location' => 'سەرەکی', 'is_active' => true]", "['is_main' => true, 'is_active' => true]")

with open('backend/app/Http/Controllers/Api/V1/ProductController.php', 'w', encoding='utf-8') as f:
    f.write(content)

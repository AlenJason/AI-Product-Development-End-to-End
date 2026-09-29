import re

with open('lib/widgets/app_widgets.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix ChoiceChip map
content = re.sub(r'(children:\s*options\.map\(\(option\)\s*\{\s*.*?return ChoiceChip\(.*?\);\s*\}\))(\s*,)', r'\1.toList()\2', content, flags=re.DOTALL)

# Fix Container map (ingredients)
content = re.sub(r'(children:\s*ingredients\s*\.map\(\(item\)\s*=>\s*Container\(.*?\)\))(\s*,)', r'\1.toList()\2', content, flags=re.DOTALL)

# Fix Container map (tags)
content = re.sub(r'(children:\s*tags\s*\.map\(\(tag\)\s*=>\s*Container\(.*?\)\))(\s*,)', r'\1.toList()\2', content, flags=re.DOTALL)

with open('lib/widgets/app_widgets.dart', 'w', encoding='utf-8') as f:
    f.write(content)

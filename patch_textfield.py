import sys

with open('lib/core/components/app_text_field.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("final TextEditingController? controller;", "final TextEditingController? controller;\n  final FocusNode? focusNode;")
content = content.replace("this.controller,", "this.controller,\n    this.focusNode,")
content = content.replace("controller: controller,", "controller: controller,\n      focusNode: focusNode,")

with open('lib/core/components/app_text_field.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched AppTextField")

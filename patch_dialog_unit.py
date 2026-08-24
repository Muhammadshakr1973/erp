import sys

with open('lib/features/products/views/product_form_dialog.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add FocusNode
content = content.replace("late TextEditingController _unitController;", "late TextEditingController _unitController;\n  late FocusNode _unitFocusNode;")
content = content.replace("_unitController = TextEditingController", "_unitFocusNode = FocusNode();\n    _unitController = TextEditingController")
content = content.replace("_unitController.dispose();", "_unitController.dispose();\n    _unitFocusNode.dispose();")

# Create the Autocomplete widget helper method
target_method = "  Future<void> _submit() async {"
replacement_method = """
  Widget _buildUnitAutocomplete(ThemeData theme) {
    final List<String> unitOptions = [
      'ج', 'ک', 'پاکەت', 'باڵە', 'عەلاگە', 'پ', 'دانە', 'پارچە', 'سێت'
    ];

    return RawAutocomplete<String>(
      textEditingController: _unitController,
      focusNode: _unitFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return unitOptions.where((String option) {
          return option.contains(textEditingValue.text);
        });
      },
      onSelected: (String selection) {
        _unitController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return AppTextField(
          controller: controller,
          focusNode: focusNode,
          labelText: 'یەکە (دانە، کیلۆ...)',
          hintText: 'دانە، کیلۆ یان کارتۆن',
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface,
            child: SizedBox(
              width: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {"""

content = content.replace(target_method, replacement_method)

# Replace the text field
target_mobile = """                          AppTextField(
                            controller: _unitController,
                            labelText: 'یەکە (دانە، کیلۆ...)',
                            hintText: 'دانە، کیلۆ یان کارتۆن',
                          ),"""
replacement_mobile = "                          _buildUnitAutocomplete(theme),"
content = content.replace(target_mobile, replacement_mobile)

target_desktop = """                              Expanded(
                                child: AppTextField(
                                  controller: _unitController,
                                  labelText: 'یەکە (دانە، کیلۆ...)',
                                  hintText: 'دانە، کیلۆ',
                                ),
                              ),"""
replacement_desktop = """                              Expanded(
                                child: _buildUnitAutocomplete(theme),
                              ),"""
content = content.replace(target_desktop, replacement_desktop)

with open('lib/features/products/views/product_form_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched Autocomplete")

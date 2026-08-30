const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, 'lib');
const strings = new Map();
let counter = 1;

function processFile(filePath) {
    if (!filePath.endsWith('.dart')) return;
    let content = fs.readFileSync(filePath, 'utf8');
    let changed = false;

    // Match strings with Kurdish/Arabic characters
    // Need to handle both single and double quotes, and handle interpolation carefully.
    // For simplicity, let's just find strings that don't have interpolation first.
    const regex = /(['"])([^'$"\n]*?[أ-يەێۆگچپژ][^'$"\n]*?)\1/g;
    
    content = content.replace(regex, (match, quote, text) => {
        if (!strings.has(text)) {
            // Create a safe key name
            let key = text.replace(/[^a-zA-Z0-9]/g, '_').replace(/^_+|_+$/g, '').substring(0, 20);
            if (!key || key.length === 0 || key === '_') {
                key = 'str_' + counter++;
            } else {
                key = 'str_' + key + '_' + counter++;
            }
            strings.set(text, key);
        }
        changed = true;
        return `AppStrings.${strings.get(text)}`;
    });

    if (changed) {
        // add import if not there
        if (!content.includes('app_strings.dart')) {
            // naive import addition
            const importStmt = "import 'package:gardi/core/localization/app_strings.dart';\n";
            // wait, we don't know the package name. Let's use a relative import or find the package name.
            // Let's check pubspec.yaml
        }
    }
}

const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(file));
        } else if (file.endsWith('.dart')) {
            results.push(file);
        }
    });
    return results;
}

const files = walk('lib');
files.forEach(file => {
    let content = fs.readFileSync(file, 'utf8');
    let changed = false;

    // Pattern: ${amount.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع
    // Or similar variations.
    
    // Let's replace the common one:
    const regex1 = /\$\{(.*?)\.toInt\(\)\.toString\(\)\.replaceAllMapped\(RegExp\(r"(\(\\d\{1,3\}\)\(\?=\(\\d\{3\}\)\+\(\?!\\d\)\))"\),\s*\(Match m\)\s*=>\s*"\$\{m\[1\]\},"\)\}\s*د\.ع/g;
    
    if (regex1.test(content)) {
        content = content.replace(regex1, (match, expr) => {
            return `\${Formatters.currency(${expr})}`;
        });
        changed = true;
    }
    
    // Replace: ${order.totalAmount.toInt()} د.ع
    // Wait, regex for this: \$\{(.*?)\.toInt\(\)\}\s*د\.ع
    const regex2 = /\$\{(.*?)\.toInt\(\)\}\s*د\.ع/g;
    if (regex2.test(content)) {
        content = content.replace(regex2, (match, expr) => {
            // Need to wrap in Formatters.currency
            // But if it's inside a String, it will be `${Formatters.currency(...)}`.
            return `\${Formatters.currency(${expr})}`;
        });
        changed = true;
    }

    if (changed) {
        if (!content.includes('package:pos_app/core/utils/formatters.dart')) {
            content = "import 'package:pos_app/core/utils/formatters.dart';\n" + content;
        }
        fs.writeFileSync(file, content);
    }
});

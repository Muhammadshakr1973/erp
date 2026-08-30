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
    // Use simple string replacement instead of regex
    const str1 = "${amount.toInt().toString().replaceAllMapped(RegExp(r\"(\\d{1,3})(?=(\\d{3})+(?!\\d))\"), (Match m) => \"${m[1]},\")} د.ع";
    if (content.includes(str1)) {
        content = content.split(str1).join("${Formatters.currency(amount)}");
        changed = true;
    }
    const str2 = "${order.totalAmount.toInt().toString().replaceAllMapped(RegExp(r\"(\\d{1,3})(?=(\\d{3})+(?!\\d))\"), (Match m) => \"${m[1]},\")} د.ع";
    if (content.includes(str2)) {
        content = content.split(str2).join("${Formatters.currency(order.totalAmount)}");
        changed = true;
    }

    if (changed) {
        if (!content.includes('package:pos_app/core/utils/formatters.dart')) {
            content = "import 'package:pos_app/core/utils/formatters.dart';\n" + content;
        }
        fs.writeFileSync(file, content);
    }
});

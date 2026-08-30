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

    // Replace anything like: \$\{([^}]+)\}\s*د\.ع
    // with \${Formatters.currency($1)}
    // except if it's already Formatters.currency(...)
    const regex = /\$\{([^}]+)\}\s*د\.ع/g;
    content = content.replace(regex, (match, expr) => {
        if (expr.includes('Formatters.currency')) return match;
        // if expr is just a variable or variable.toInt(), wrap it
        changed = true;
        // wait, we don't want the ` د.ع` anymore, because Formatters.currency adds it!
        // so we just return `${Formatters.currency(expr)}`
        return `\${Formatters.currency(${expr})}`;
    });

    if (changed) {
        if (!content.includes('package:pos_app/core/utils/formatters.dart')) {
            content = "import 'package:pos_app/core/utils/formatters.dart';\n" + content;
        }
        fs.writeFileSync(file, content);
    }
});

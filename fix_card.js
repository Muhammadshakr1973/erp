const fs = require('fs');
let c = fs.readFileSync('lib/features/admin/views/admin_categories_dialog.dart', 'utf8');

c = c.replace(/return Padding\(padding: const EdgeInsets\.only\(bottom: 8\), child: AppCard\([\s\S]*?child: ListTile\(/, `return Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(
                          child: ListTile(`);
                          
c = c.replace(/child: ListTile\([\s\S]*?\},/g, match => {
    return match; // we need to just add a closing parenthesis to the end of the return statement.
});


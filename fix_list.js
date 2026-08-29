const fs = require('fs');
let c = fs.readFileSync('lib/features/admin/views/admin_categories_dialog.dart', 'utf8');

c = c.replace(/return Padding\(padding: const EdgeInsets.only\(bottom: 8\), child: AppCard\([\s\S]*?;\s*},\s*\);/, `return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: ListTile(
                              title: Text(cat.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(AppIcons.edit, color: AppColors.primary),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => CategoryFormDialog(category: cat),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(AppIcons.delete, color: AppColors.danger),
                                    onPressed: () => _deleteCategory(context, ref, cat),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );`);
fs.writeFileSync('lib/features/admin/views/admin_categories_dialog.dart', c);

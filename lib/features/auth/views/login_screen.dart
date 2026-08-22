import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

// بەکارهێنانی ConsumerWidget لە جیاتی StatelessWidget بۆ بەکارهێنانی Riverpod
class LoginScreen extends ConsumerWidget {
  LoginScreen({super.key});

  final TextEditingController phoneController = TextEditingController(
    text: '07500000001',
  );
  final TextEditingController passwordController = TextEditingController(
    text: 'password',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // چاودێریکردنی دۆخی لۆگین (loading, error, etc.)
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.storefront, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 32),
              const Text(
                'بەخێربێیتەوە',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // کێڵگەی ژمارە مۆبایل
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'ژمارە مۆبایل',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // کێڵگەی پاسۆرد
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'وشەی نهێنی',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // پیشاندانی نامەی هەڵە
              if (authState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // دوگمەی چوونەژوورەوە
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          // بانگکردنی فەنکشنی لۆگین لە Provider
                          final success = await ref
                              .read(authProvider.notifier)
                              .login(
                                phoneController.text.trim(),
                                passwordController.text,
                              );

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('چوونەژوورەوە سەرکەوتوو بوو!'),
                              ),
                            );
                            // دواتر لێرەدا دەیبەینە پەڕەی داشبۆرد
                          }
                        },
                  child: authState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'چوونەژوورەوە',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

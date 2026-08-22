import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/views/login_screen.dart';
import '../../features/salesman/views/salesman_main_screen.dart';
import '../../features/admin/views/admin_main_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Admin / Owner Routes
      GoRoute(
        path: '/admin',
        name: 'adminDashboard',
        builder: (context, state) => const AdminMainScreen(),
      ),
      // Salesman Routes
      GoRoute(
        path: '/salesman',
        name: 'salesmanDashboard',
        builder: (context, state) => const SalesmanMainScreen(),
        routes: [
          GoRoute(
            path: 'create-order',
            name: 'createOrder',
            builder: (context, state) => const Scaffold(
              appBar: AppBar(title: Text('دروستکردنی پسوڵەی نوێ')),
              body: Center(child: Text('بەمزووانە...')),
            ),
          ),
        ],
      ),
    ],
  );
});

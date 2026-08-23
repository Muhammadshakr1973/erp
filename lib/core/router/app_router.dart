import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/views/login_screen.dart';
import '../../features/salesman/views/salesman_main_screen.dart';
import '../../features/salesman/views/create_order_screen.dart';
import '../../features/admin/views/admin_main_screen.dart';
import '../../features/warehouse/views/warehouse_main_screen.dart';
import '../../features/driver/views/driver_main_screen.dart';
import '../../features/shared/views/customer_detail_screen.dart';
import '../../features/shared/views/order_detail_screen.dart';
import '../../features/driver/views/trip_orders_screen.dart';
import '../../features/shared/views/profile_screen.dart';
import '../../features/shared/views/notifications_screen.dart';
import '../../features/admin/views/admin_purchases_screen.dart';
import '../../features/warehouse/views/pack_order_screen.dart';

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
            builder: (context, state) => const CreateOrderScreen(),
          ),
        ],
      ),
      // Warehouse Routes
      GoRoute(
        path: '/warehouse',
        name: 'warehouseDashboard',
        builder: (context, state) => const WarehouseMainScreen(),
      ),
      // Driver Routes
      GoRoute(
        path: '/driver',
        name: 'driverDashboard',
        builder: (context, state) => const DriverMainScreen(),
      ),
      // Shared Routes
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/customer/:id',
        name: 'customerDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomerDetailScreen(customerId: id);
        },
      ),
      GoRoute(
        path: '/order/:id',
        name: 'orderDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OrderDetailScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/pack-order/:id',
        name: 'packOrder',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PackOrderScreen(orderId: id);
        },
      ),
      GoRoute(
        path: '/admin-purchases',
        name: 'adminPurchases',
        builder: (context, state) => const AdminPurchasesScreen(),
      ),
      GoRoute(
        path: '/trip/:id',
        name: 'tripDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TripOrdersScreen(tripId: id);
        },
      ),
    ],
  );
});

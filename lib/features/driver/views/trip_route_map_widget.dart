import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../models/delivery_trip_model.dart';

class TripRouteMapWidget extends StatefulWidget {
  final DeliveryTripModel trip;

  const TripRouteMapWidget({super.key, required this.trip});

  @override
  State<TripRouteMapWidget> createState() => _TripRouteMapWidgetState();
}

class _TripRouteMapWidgetState extends State<TripRouteMapWidget> with SingleTickerProviderStateMixin {
  late MapController _mapController;
  LatLng? _driverLocation;
  bool _isLoadingDriverLoc = false;
  StreamSubscription<Position>? _positionSubscription;
  bool _hasInitialFit = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _startLocationListening();
  }

  @override
  void didUpdateWidget(TripRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      _hasInitialFit = false;
      _fitAllBounds();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startLocationListening() async {
    setState(() {
      _isLoadingDriverLoc = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get current first
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        ).catchError((_) => Position(
              latitude: 36.1912,
              longitude: 44.0091,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            ));

        if (mounted) {
          setState(() {
            _driverLocation = LatLng(pos.latitude, pos.longitude);
            _isLoadingDriverLoc = false;
          });
          _fitAllBounds();
        }

        // Subscribe to updates
        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _driverLocation = LatLng(position.latitude, position.longitude);
            });
            if (!_hasInitialFit) {
              _fitAllBounds();
            }
          }
        });
      } else {
        if (mounted) {
          setState(() => _isLoadingDriverLoc = false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDriverLoc = false);
      }
    }
  }

  void _fitAllBounds() {
    if (!mounted) return;

    final points = _getRoutePoints();
    if (points.isEmpty) return;

    // Wait for the map controller to be ready
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 50.0),
          ),
        );
        _hasInitialFit = true;
      } catch (_) {}
    });
  }

  List<LatLng> _getRoutePoints() {
    final points = <LatLng>[];

    // If driver location is known, let's optionally add it
    if (_driverLocation != null) {
      points.add(_driverLocation!);
    }

    // Sort orders by deliveryOrder sequence
    final sortedOrders = List<DeliveryTripOrderModel>.from(widget.trip.orders)
      ..sort((a, b) => a.deliveryOrder.compareTo(b.deliveryOrder));

    for (final tripOrder in sortedOrders) {
      final lat = tripOrder.order?.customerLatitude;
      final lng = tripOrder.order?.customerLongitude;
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        points.add(LatLng(lat, lng));
      }
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort orders for sequence
    final sortedOrders = List<DeliveryTripOrderModel>.from(widget.trip.orders)
      ..sort((a, b) => a.deliveryOrder.compareTo(b.deliveryOrder));

    // Filter valid customer coordinates
    final customerOrdersWithLoc = sortedOrders.where((tripOrder) {
      final lat = tripOrder.order?.customerLatitude;
      final lng = tripOrder.order?.customerLongitude;
      return lat != null && lng != null && (lat != 0 || lng != 0);
    }).toList();

    // Map route polylines
    final routePoints = <LatLng>[];
    for (final tripOrder in customerOrdersWithLoc) {
      routePoints.add(LatLng(tripOrder.order!.customerLatitude!, tripOrder.order!.customerLongitude!));
    }

    final hasCustomersWithLoc = customerOrdersWithLoc.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      overflow: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Widget exactly like 2.png
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.blueGrey.shade800 : Colors.blue.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation_rounded, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ماپی گەیاندن - Delivery Map',
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'گەشتی #${widget.trip.tripNumber} • ${widget.trip.orders.length} پسوڵە',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.blue),
                  tooltip: 'ڕێکخستنەوەی نەخشە',
                  onPressed: _fitAllBounds,
                ),
              ],
            ),
          ),

          // Map Area
          SizedBox(
            height: 400,
            child: !hasCustomersWithLoc
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: isDark ? Colors.grey : Colors.blueGrey.shade300),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'هیچ ناونیشانێکی کڕیار بەردەست نییە بۆ دیاریکردنی ڕێڕەو',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: routePoints.isNotEmpty
                              ? routePoints.first
                              : const LatLng(36.1912, 44.0091),
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.gardipos.app',
                          ),
                          
                          // Route line connecting all customers
                          if (routePoints.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  strokeWidth: 5.0,
                                  color: Colors.blue.shade600,
                                  borderColor: Colors.blue.shade900,
                                  borderStrokeWidth: 1.5,
                                ),
                              ],
                            ),

                          // If driver location is available and there's a route, optionally connect driver to first client
                          if (_driverLocation != null && routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [_driverLocation!, routePoints.first],
                                  strokeWidth: 3.5,
                                  color: Colors.orange.withOpacity(0.8),
                                  isDotted: true,
                                ),
                              ],
                            ),

                          // Markers Layer
                          MarkerLayer(
                            markers: [
                              // Driver Location Marker
                              if (_driverLocation != null)
                                Marker(
                                  point: _driverLocation!,
                                  width: 100,
                                  height: 100,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade900,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                        ),
                                        child: const Text(
                                          'شوێنی ئێستا',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Rudaw',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const PulsingLocationMarker(),
                                    ],
                                  ),
                                ),

                              // Customer Location Markers
                              for (int i = 0; i < customerOrdersWithLoc.length; i++) ...[
                                () {
                                  final tripOrder = customerOrdersWithLoc[i];
                                  final order = tripOrder.order!;
                                  final lat = order.customerLatitude!;
                                  final lng = order.customerLongitude!;
                                  final customerName = order.customerName;
                                  final seqNo = i + 1;
                                  final status = tripOrder.status.toUpperCase();

                                  Color pinColor = Colors.blue;
                                  Widget pinIcon = Text(
                                    '$seqNo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );

                                  if (status == 'DELIVERED') {
                                    pinColor = Colors.green.shade600;
                                    pinIcon = const Icon(Icons.check, color: Colors.white, size: 12);
                                  } else if (status == 'FAILED') {
                                    pinColor = AppColors.danger;
                                    pinIcon = const Icon(Icons.close, color: Colors.white, size: 12);
                                  }

                                  return Marker(
                                    point: LatLng(lat, lng),
                                    width: 140,
                                    height: 75,
                                    alignment: Alignment.topCenter,
                                    child: GestureDetector(
                                      onTap: () => _showCustomerDetailsBottomSheet(context, tripOrder, seqNo),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Speech bubble label
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: pinColor, width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              '$seqNo. $customerName',
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade900,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Rudaw',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          // Pin Icon
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                Icons.location_on_rounded,
                                                color: pinColor,
                                                size: 28,
                                              ),
                                              Positioned(
                                                top: 4,
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: pinIcon,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }(),
                              ],
                            ],
                          ),
                        ],
                      ),

                      // Re-center Floating Action Button inside map
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'map_fit_btn',
                              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                              foregroundColor: Colors.blue,
                              onPressed: _fitAllBounds,
                              child: const Icon(Icons.zoom_out_map_rounded, size: 18),
                            ),
                            if (_driverLocation != null) ...[
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'map_myloc_btn',
                                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                                foregroundColor: Colors.blue,
                                onPressed: () {
                                  if (_driverLocation != null) {
                                    _mapController.move(_driverLocation!, 15.0);
                                  }
                                },
                                child: const Icon(Icons.my_location_rounded, size: 18),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetailsBottomSheet(BuildContext context, DeliveryTripOrderModel tripOrder, int seqNo) {
    final order = tripOrder.order;
    final customer = order?.customer;
    final customerName = order?.customerName ?? 'کڕیاری نەناسراو';
    final address = order?.customerAddress ?? 'ناونیشان دیاری نەکراوە';
    final phone = customer is Map ? (customer['phone']?.toString() ?? '') : '';
    final totalAmount = order?.totalAmount ?? 0;
    final status = tripOrder.status.toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'کڕیاری ژمارە $seqNo: $customerName',
                      style: AppTextStyles.h3,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'ناونیشان: $address',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: Colors.blue),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'مۆبایل: $phone',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'بڕی پسوڵە: ',
                      style: AppTextStyles.bodyMedium,
                    ),
                    Text(
                      '${Formatters.currency(totalAmount)} د.ع',
                      style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryAdaptive(context)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                    const SizedBox(width: AppSpacing.xs),
                    const Text('دۆخی گەیاندن: ', style: AppTextStyles.bodyMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'DELIVERED'
                            ? Colors.green.withOpacity(0.12)
                            : status == 'FAILED'
                                ? AppColors.danger.withOpacity(0.12)
                                : AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status == 'DELIVERED'
                            ? 'گەیشتووە'
                            : status == 'FAILED'
                                ? 'شکستخواردوو'
                                : 'ماوە / ئامادەیە',
                        style: TextStyle(
                          color: status == 'DELIVERED'
                              ? Colors.green
                              : status == 'FAILED'
                                  ? AppColors.danger
                                  : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Rudaw',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/trip/${tripOrder.deliveryTripId}');
                    },
                    child: const Text(
                      'تۆمارکردنی دۆخی گەیاندن یان بینینی پسوڵە',
                      style: TextStyle(fontFamily: 'Rudaw', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PulsingLocationMarker extends StatefulWidget {
  const PulsingLocationMarker({super.key});

  @override
  State<PulsingLocationMarker> createState() => _PulsingLocationMarkerState();
}

class _PulsingLocationMarkerState extends State<PulsingLocationMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing outer ring
            Container(
              width: 12 + (24 * _controller.value),
              height: 12 + (24 * _controller.value),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(1.0 - _controller.value),
                shape: BoxShape.circle,
              ),
            ),
            // Inner circle ring with border
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            // Solid center dot
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

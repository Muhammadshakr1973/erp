import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../core/components/app_text_field.dart';

class MapPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final bool isReadOnly;

  const MapPickerDialog({
    super.key,
    this.initialLocation,
    this.isReadOnly = false,
  });

  static Future<void> showCustomerLocation(
    BuildContext context, {
    required String customerName,
    required String customerAddress,
    double? latitude,
    double? longitude,
    bool isReadOnly = false,
  }) async {
    if (latitude != null && longitude != null && (latitude != 0 || longitude != 0)) {
      await showDialog(
        context: context,
        builder: (context) => MapPickerDialog(
          initialLocation: LatLng(latitude, longitude),
          isReadOnly: isReadOnly,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'کڕیاری "$customerName" نیشانەی نەخشەی (GPS) بۆ تۆمار نەکراوە. ناونیشان: $customerAddress',
            style: const TextStyle(fontFamily: 'Rudaw'),
          ),
          backgroundColor: Colors.orangeAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  bool _isLocating = false;

  // Driver/Routing state
  LatLng? _driverLocation;
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  double? _routeDurationMinutes;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation =
        widget.initialLocation ??
        const LatLng(36.1912, 44.0091); // Default Erbil Coordinate

    _latController = TextEditingController(
      text: _selectedLocation!.latitude.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: _selectedLocation!.longitude.toStringAsFixed(6),
    );

    // If we are in read-only mode, fetch both current driver location and route
    // If we are in edit mode and no initial location is provided, fetch user's location
    if (widget.isReadOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocationAndRoute();
      });
    } else if (widget.initialLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocation();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _updateLocation(LatLng location, {bool moveMap = false}) {
    if (widget.isReadOnly) return; // Do not update location in read-only mode
    setState(() {
      _selectedLocation = location;
      _latController.text = location.latitude.toStringAsFixed(6);
      _lngController.text = location.longitude.toStringAsFixed(6);
    });
    if (moveMap) {
      _mapController.move(location, 14.0);
    }
  }

  void _onManualCoordinateChange(String _) {
    if (widget.isReadOnly) return;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      final newLoc = LatLng(lat, lng);
      setState(() {
        _selectedLocation = newLoc;
      });
      _mapController.move(newLoc, _mapController.camera.zoom);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تکایە لۆکەیشنی ئامێرەکەت (GPS) کار پێ بکە، یان بە دەستی شوێنەکە نیشان بکە.',
                  style: TextStyle(fontFamily: 'Rudaw'),
                ),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دەسەڵاتی خوێندنەوەی لۆکەیشن ڕەتکرایەوە، تکایە بە دەست لۆکەیشنەکە دیاری بکە.',
                  style: TextStyle(fontFamily: 'Rudaw'),
                ),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'دەسەڵاتی لۆکەیشن بلۆک کراوە. تکایە بە دەست لۆکەیشنەکە لەسەر نەخشەکە نیشان بکە.',
                style: TextStyle(fontFamily: 'Rudaw'),
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final userLoc = LatLng(position.latitude, position.longitude);
      _updateLocation(userLoc, moveMap: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'خزمەتگوزاری لۆکەیشن کار ناکات یان پێگەکەت چالاک نەکراوە. تکایە بە دەستی لەسەر نەخشەکە شوێنەکە دەستنیشان بکە.',
              style: TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  // Find driver's current position and fetch route to the customer location
  Future<void> _getCurrentLocationAndRoute() async {
    setState(() {
      _isLocating = true;
    });

    try {
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تکایە لۆکەیشنی ئامێرەکەت (GPS) کار پێ بکە بۆ دیاریکردنی ڕێگاکە.',
                  style: TextStyle(fontFamily: 'Rudaw'),
                ),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'دەسەڵاتی خوێندنەوەی لۆکەیشن ڕەتکرایەوە، ناتوانرێت ڕێگاکە بدۆزرێتەوە بەبێ لۆکەیشن.',
                  style: TextStyle(fontFamily: 'Rudaw'),
                ),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'دەسەڵاتی لۆکەیشن بلۆک کراوە. تکایە لە ڕێکخستنەکان کارای بکە.',
                style: TextStyle(fontFamily: 'Rudaw'),
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final userLoc = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _driverLocation = userLoc;
      });

      await _fetchRoutePoints();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'خزمەتگوزاری لۆکەیشن کار ناکات یان پێگەکەت چالاک نەکراوە، تکایە دڵنیابەرەوە لە هەبوونی هێڵ و لۆکەیشن.',
              style: TextStyle(fontFamily: 'Rudaw'),
            ),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  // Fetch routing coordinates from OpenStreetMap public OSRM router
  Future<void> _fetchRoutePoints() async {
    final driverLoc = _driverLocation;
    final customerLoc = _selectedLocation;
    if (driverLoc == null || customerLoc == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final dio = Dio();
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${driverLoc.longitude},${driverLoc.latitude};'
          '${customerLoc.longitude},${customerLoc.latitude}'
          '?overview=full&geometries=geojson';

      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List;
            final List<LatLng> points = [];
            for (var coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final double lon = double.parse(coord[0].toString());
                final double lat = double.parse(coord[1].toString());
                points.add(LatLng(lat, lon));
              }
            }

            double? distanceMeters;
            double? durationSeconds;
            try {
              distanceMeters = double.tryParse(route['distance']?.toString() ?? '');
              durationSeconds = double.tryParse(route['duration']?.toString() ?? '');
            } catch (_) {}

            setState(() {
              _routePoints = points;
              if (distanceMeters != null) {
                _routeDistanceKm = distanceMeters / 1000.0;
              }
              if (durationSeconds != null) {
                _routeDurationMinutes = durationSeconds / 60.0;
              }
            });

            _fitMapBounds();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('OSRM Routing Error: $e');
      }
      // Fallback: draw straight line
      setState(() {
        _routePoints = [driverLoc, customerLoc];
        final distanceMeters = Geolocator.distanceBetween(
          driverLoc.latitude,
          driverLoc.longitude,
          customerLoc.latitude,
          customerLoc.longitude,
        );
        _routeDistanceKm = distanceMeters / 1000.0;
        _routeDurationMinutes = (_routeDistanceKm! / 40.0) * 60.0; // Estimate 40km/h
      });
      _fitMapBounds();
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _fitMapBounds() {
    final driverLoc = _driverLocation;
    final customerLoc = _selectedLocation;
    if (driverLoc == null || customerLoc == null) return;

    try {
      final bounds = LatLngBounds.fromPoints([driverLoc, customerLoc]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60.0),
        ),
      );
    } catch (e) {
      final midLat = (driverLoc.latitude + customerLoc.latitude) / 2.0;
      final midLng = (driverLoc.longitude + customerLoc.longitude) / 2.0;
      _mapController.move(LatLng(midLat, midLng), 13.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 600 : double.infinity,
        height: widget.isReadOnly ? 560 : 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    widget.isReadOnly ? Icons.alt_route_rounded : Icons.map_outlined,
                    color: Colors.blue,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isReadOnly ? 'نەخشەی کڕیار و ڕێگای گەیشتن' : 'دیاریکردنی ناونیشان لەسەر نەخشە',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Rudaw',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Show manual coordinate fields ONLY in edit/picker mode
            if (!widget.isReadOnly) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        customDecoration: InputDecoration(
                          labelText: 'پانی (Lat)',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                        ),
                        onChanged: _onManualCoordinateChange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        customDecoration: InputDecoration(
                          labelText: 'درێژی (Lon)',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                        ),
                        onChanged: _onManualCoordinateChange,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],

            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _selectedLocation ?? const LatLng(36.1912, 44.0091),
                      initialZoom: 13.0,
                      onTap: widget.isReadOnly
                          ? null // DISABLE interactions (cannot move marker/tap map) in ReadOnly Mode
                          : (tapPosition, point) {
                              _updateLocation(point);
                            },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.gardipos.app',
                      ),
                      
                      // Show Polyline route ONLY in read-only / driver mode
                      if (widget.isReadOnly && _routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 5.0,
                              color: Colors.blueAccent,
                              borderColor: Colors.blue.withOpacity(0.3),
                              borderStrokeWidth: 3.0,
                            ),
                          ],
                        ),

                      MarkerLayer(
                        markers: [
                          // Destination/Customer Marker (Red Pin)
                          if (_selectedLocation != null)
                            Marker(
                              point: _selectedLocation!,
                              width: 60,
                              height: 60,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          
                          // Driver current location Marker (Blue Circle + Car Icon)
                          if (widget.isReadOnly && _driverLocation != null)
                            Marker(
                              point: _driverLocation!,
                              width: 50,
                              height: 50,
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.blue, width: 2),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Floating action button to locate (Edit Mode) or recalculate/refresh route (ReadOnly Mode)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      onPressed: _isLocating
                          ? null
                          : (widget.isReadOnly ? _getCurrentLocationAndRoute : _getCurrentLocation),
                      child: _isLocating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.my_location,
                              color: isDark ? const Color(0xFF60A5FA) : Colors.blue,
                            ),
                    ),
                  ),

                  // Route status overlay banner (ReadOnly Mode only)
                  if (widget.isReadOnly)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: _isLoadingRoute
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'بارکردنی ڕێگا و نەخشە...',
                                    style: TextStyle(
                                      fontFamily: 'Rudaw',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.navigation_rounded, color: Colors.green, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'ئاسانترین ڕێگای پێشنیارکراو',
                                          style: TextStyle(
                                            fontFamily: 'Rudaw',
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _routeDistanceKm != null && _routeDurationMinutes != null
                                              ? 'دووری: ${_routeDistanceKm!.toStringAsFixed(1)} کم  |  ماوە: ${_routeDurationMinutes!.toStringAsFixed(0)} خولەک'
                                              : 'دووری: نەزانراو  |  لۆکەیشنی شۆفێر باردەکرێت...',
                                          style: const TextStyle(
                                            fontFamily: 'Rudaw',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Bottom Action buttons (different layout based on ReadOnly mode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: widget.isReadOnly
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[200],
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'داخستن',
                              style: TextStyle(
                                fontFamily: 'Rudaw',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'پاشگەزبوونەوە',
                            style: TextStyle(fontFamily: 'Rudaw'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, _selectedLocation);
                          },
                          child: const Text(
                            'دیاریکردنی جێگا',
                            style: TextStyle(
                              fontFamily: 'Rudaw',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/components/app_text_field.dart';

class MapPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerDialog({super.key, this.initialLocation});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  bool _isLocating = false;

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

    // If no initial location is provided, automatically find the user's location on startup
    if (widget.initialLocation == null) {
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
      // Geolocator.isLocationServiceEnabled() is not supported on web and throws MissingPluginException.
      // Bypass it if we are on Web.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 550 : double.infinity,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, color: Colors.blue, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'دیاریکردنی ناونیشان لەسەر نەخشە',
                      style: TextStyle(
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
            // Manual coordinate fields
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
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _selectedLocation ?? const LatLng(36.1912, 44.0091),
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                        _updateLocation(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.gardipos.app',
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(
                          markers: [
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
                          ],
                        ),
                    ],
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: _isLocating ? null : _getCurrentLocation,
                      child: _isLocating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
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

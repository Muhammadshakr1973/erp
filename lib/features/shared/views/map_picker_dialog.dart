import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';

class MapPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerDialog({super.key, this.initialLocation});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  late MapController _mapController;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation ?? const LatLng(36.1912, 44.0091); // Default Erbil Coordinate
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 550 : double.infinity,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'دیاریکردنی ناونیشان لەسەر نەخشە',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Rudaw',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
                      initialCenter: _selectedLocation ?? const LatLng(36.1912, 44.0091),
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                      onPressed: () {
                        _mapController.move(const LatLng(36.1912, 44.0091), 13.0);
                        setState(() {
                          _selectedLocation = const LatLng(36.1912, 44.0091);
                        });
                      },
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context, _selectedLocation);
                    },
                    child: const Text(
                      'دیاریکردن',
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/geocoding_service.dart';

class PickedLocation {
  final LatLng point;
  final String? name;

  const PickedLocation({required this.point, this.name});
}

class PickLocationPage extends StatefulWidget {
  final LatLng initialPosition;

  const PickLocationPage({super.key, required this.initialPosition});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  late LatLng _selected;
  final _geo = GeocodingService();

  bool _resolving = false;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPosition;
  }

  Future<void> _resolveName() async {
    setState(() => _resolving = true);
    try {
      final lat = double.parse(_selected.latitude.toStringAsFixed(6));
      final lng = double.parse(_selected.longitude.toStringAsFixed(6));
      final name = await _geo.reverse(lat: lat, lng: lng);
      if (!mounted) return;
      setState(() => _placeName = name);
    } catch (_) {
      // MVP: si falla, no bloqueamos
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir ubicación')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 16,
              onPositionChanged: (position, _) {
                setState(() {
                  _selected = position.center;
                  _placeName = null; // invalida nombre al mover
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'co.opentic.yalecaigo',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona un punto público.\nNo hoteles ni residencias.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    if (_placeName != null)
                      Text(
                        _placeName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resolving ? null : _resolveName,
                            icon: _resolving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.place),
                            label: Text(
                              _resolving ? 'Buscando…' : 'Buscar nombre',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                PickedLocation(
                                  point: _selected,
                                  name: _placeName,
                                ),
                              );
                            },
                            child: const Text('Confirmar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

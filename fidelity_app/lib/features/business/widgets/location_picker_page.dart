import 'package:flutter/material.dart' hide Text;

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page_header.dart';
import 'location_picker_map.dart';
import '../../../core/l10n/tr_text.dart';

/// Ubicación elegida en el mapa.
class LocationSelection {
  final double latitude;
  final double longitude;
  final String address;

  const LocationSelection({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// Abre el mapa para elegir la ubicación del negocio. Devuelve la selección
/// confirmada o `null` si el usuario vuelve sin confirmar.
Future<LocationSelection?> pickBusinessLocation(
  BuildContext context, {
  double? latitude,
  double? longitude,
  String? address,
}) {
  return Navigator.of(context).push<LocationSelection>(
    MaterialPageRoute(
      builder: (_) => _LocationPickerPage(
        latitude: latitude,
        longitude: longitude,
        address: address,
      ),
    ),
  );
}

class _LocationPickerPage extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? address;

  const _LocationPickerPage({this.latitude, this.longitude, this.address});

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  LocationSelection? _selection;

  @override
  void initState() {
    super.initState();
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      _selection = LocationSelection(
        latitude: lat,
        longitude: lng,
        address: widget.address ?? '',
      );
    }
  }

  void _confirm() {
    final selection = _selection;
    if (selection == null) {
      // El mapa arranca centrado en Quito sin que eso cuente como elección.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toca el mapa, busca una dirección o usa UBICARME.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(selection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'Ubicación'),
            Expanded(
              child: LocationPickerMap(
                initialLatitude: widget.latitude,
                initialLongitude: widget.longitude,
                initialAddress: widget.address,
                onLocationSelected: (lat, lng, address) {
                  _selection = LocationSelection(
                    latitude: lat,
                    longitude: lng,
                    address: address,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 16, 48, 24),
              child: AppPrimaryButton(label: 'Confirmar', onPressed: _confirm),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'image_source.dart';

/// Imagen elegida por el usuario, lista para previsualizar y enviar.
class PickedImage {
  final Uint8List bytes;
  final String dataUri;

  const PickedImage({required this.bytes, required this.dataUri});
}

/// Abre la galería y devuelve la imagen elegida, ya reducida.
///
/// Se limita el lado mayor a [maxSide] px para que el resultado sea liviano
/// (un avatar o logo no necesita más). Devuelve `null` si el usuario cancela;
/// lanza [FormatException] (mensaje para el usuario) si el archivo no sirve.
Future<PickedImage?> pickImageFromGallery({double maxSide = 640}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxSide,
    maxHeight: maxSide,
    imageQuality: 80,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  return PickedImage(bytes: bytes, dataUri: imageBytesToDataUri(bytes));
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Convierte la URL de un avatar o logo en un [ImageProvider].
///
/// Los avatares y logos se guardan como URL http(s) o como data URI base64
/// (`data:image/png;base64,...`). `NetworkImage` no sabe leer estas últimas
/// fuera del navegador, por lo que se decodifican a bytes en memoria.
///
/// Devuelve `null` si [url] es nula, vacía o no es una imagen interpretable.
ImageProvider? imageProviderFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;

  if (url.startsWith('data:')) {
    final bytes = _decodeDataUri(url);
    return bytes == null ? null : MemoryImage(bytes);
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return null;
  }
  return NetworkImage(url);
}

Uint8List? _decodeDataUri(String url) {
  try {
    final data = UriData.parse(url);
    if (!data.mimeType.startsWith('image/')) return null;
    return data.contentAsBytes();
  } catch (_) {
    return null;
  }
}

/// Detecta el formato real de una imagen por su cabecera (no por la
/// extensión, que en web suele no existir). `null` si no es compatible.
String? imageMimeFromBytes(Uint8List bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  // WebP: "RIFF" + 4 bytes de tamaño + "WEBP"
  if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
      startsWith([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}

/// Tamaño máximo de imagen que acepta el backend (~1 MB).
const int maxImageBytes = 1000000;

/// Codifica [bytes] como data URI lista para enviar al backend.
///
/// Lanza [FormatException] con un mensaje apto para el usuario si el formato
/// no es compatible o la imagen es demasiado grande.
String imageBytesToDataUri(Uint8List bytes) {
  final mime = imageMimeFromBytes(bytes);
  if (mime == null) {
    throw const FormatException(
      'Formato de imagen no compatible. Usa PNG, JPG, WEBP o GIF.',
    );
  }
  if (bytes.length > maxImageBytes) {
    throw const FormatException(
      'La imagen es demasiado grande. Elige una de menos de 1 MB.',
    );
  }
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

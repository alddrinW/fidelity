import 'dart:typed_data';

import 'package:fidelity_app/core/utils/image_source.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG mínimo válido de 1x1 píxel.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
]);
final Uint8List _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
final Uint8List _gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
final Uint8List _webp = Uint8List.fromList([
  0x52, 0x49, 0x46, 0x46, 0x10, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
]);

void main() {
  group('imageProviderFromUrl', () {
    test('devuelve null para valores vacíos o inválidos', () {
      expect(imageProviderFromUrl(null), isNull);
      expect(imageProviderFromUrl(''), isNull);
      expect(imageProviderFromUrl('no-es-una-url'), isNull);
      expect(imageProviderFromUrl('file:///etc/passwd'), isNull);
      expect(imageProviderFromUrl('javascript:alert(1)'), isNull);
    });

    test('usa NetworkImage para URLs http(s)', () {
      expect(imageProviderFromUrl('https://cdn.ejemplo.com/a.png'), isA<NetworkImage>());
      expect(imageProviderFromUrl('http://localhost:3000/a.png'), isA<NetworkImage>());
    });

    test('decodifica data URI de imagen a MemoryImage', () {
      final provider = imageProviderFromUrl(imageBytesToDataUri(_png));
      expect(provider, isA<MemoryImage>());
      expect((provider as MemoryImage).bytes, _png);
    });

    test('ignora data URI que no es imagen o está corrupta', () {
      expect(imageProviderFromUrl('data:text/html;base64,PGgxPg=='), isNull);
      expect(imageProviderFromUrl('data:image/png;base64,%%%'), isNull);
    });
  });

  group('imageMimeFromBytes', () {
    test('reconoce los formatos permitidos por su cabecera', () {
      expect(imageMimeFromBytes(_png), 'image/png');
      expect(imageMimeFromBytes(_jpeg), 'image/jpeg');
      expect(imageMimeFromBytes(_gif), 'image/gif');
      expect(imageMimeFromBytes(_webp), 'image/webp');
    });

    test('rechaza formatos no permitidos', () {
      final svg = Uint8List.fromList('<svg></svg>'.codeUnits);
      expect(imageMimeFromBytes(svg), isNull);
      expect(imageMimeFromBytes(Uint8List(0)), isNull);
    });
  });

  group('imageBytesToDataUri', () {
    test('genera un data URI con el tipo correcto', () {
      expect(imageBytesToDataUri(_jpeg), startsWith('data:image/jpeg;base64,'));
    });

    test('falla con mensaje claro si el formato no es compatible', () {
      expect(
        () => imageBytesToDataUri(Uint8List.fromList('<svg/>'.codeUnits)),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Formato'))),
      );
    });

    test('falla si la imagen supera el tamaño máximo', () {
      final big = Uint8List(maxImageBytes + 1)..setAll(0, _png);
      expect(
        () => imageBytesToDataUri(big),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('grande'))),
      );
    });
  });
}

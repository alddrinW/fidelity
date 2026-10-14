import { registerDecorator, ValidationOptions } from 'class-validator';

/**
 * Tamano maximo (en caracteres) de una imagen enviada como data URI base64.
 * 1.4 millones de caracteres equivalen a ~1 MB de imagen real.
 */
export const MAX_IMAGE_DATA_URI_LENGTH = 1_400_000;

// SVG queda fuera a proposito: puede contener scripts.
const DATA_URI_PATTERN = /^data:image\/(png|jpeg|webp|gif);base64,[A-Za-z0-9+/]+={0,2}$/;
const HTTP_URL_PATTERN = /^https?:\/\/\S+$/i;

/**
 * Una imagen valida es una URL http(s), una data URI base64 de un formato
 * raster permitido, o una cadena vacia (para quitar la imagen).
 */
export function isImageSource(value: unknown): boolean {
  if (typeof value !== 'string') return false;
  if (value === '') return true;
  if (value.length > MAX_IMAGE_DATA_URI_LENGTH) return false;
  return DATA_URI_PATTERN.test(value) || HTTP_URL_PATTERN.test(value);
}

export function IsImageSource(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isImageSource',
      target: object.constructor,
      propertyName,
      options: {
        message:
          'La imagen debe ser una URL http(s) o una imagen base64 (png, jpeg, webp o gif) de hasta 1 MB',
        ...validationOptions,
      },
      validator: { validate: (value: unknown) => isImageSource(value) },
    });
  };
}

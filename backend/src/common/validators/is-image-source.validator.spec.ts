import { validate } from 'class-validator';
import {
  IsImageSource,
  isImageSource,
  MAX_IMAGE_DATA_URI_LENGTH,
} from './is-image-source.validator';

describe('isImageSource', () => {
  it('acepta data URI raster en base64', () => {
    expect(isImageSource('data:image/png;base64,iVBORw0KGgo=')).toBe(true);
    expect(isImageSource('data:image/jpeg;base64,/9j/4AAQSkZJRg==')).toBe(true);
    expect(isImageSource('data:image/webp;base64,UklGRg==')).toBe(true);
  });

  it('acepta URLs http(s) y la cadena vacia (quitar imagen)', () => {
    expect(isImageSource('https://cdn.ejemplo.com/logo.png')).toBe(true);
    expect(isImageSource('http://localhost:3000/logo.png')).toBe(true);
    expect(isImageSource('')).toBe(true);
  });

  it('rechaza SVG, otros esquemas y valores que no son texto', () => {
    expect(isImageSource('data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=')).toBe(false);
    expect(isImageSource('javascript:alert(1)')).toBe(false);
    expect(isImageSource('data:text/html;base64,PGgxPg==')).toBe(false);
    expect(isImageSource('file:///etc/passwd')).toBe(false);
    expect(isImageSource(123)).toBe(false);
    expect(isImageSource(null)).toBe(false);
  });

  it('rechaza base64 con caracteres invalidos', () => {
    expect(isImageSource('data:image/png;base64,@@@')).toBe(false);
  });

  it('rechaza imagenes que superan el tamano maximo', () => {
    const big = 'data:image/png;base64,' + 'A'.repeat(MAX_IMAGE_DATA_URI_LENGTH);
    expect(isImageSource(big)).toBe(false);
  });
});

describe('@IsImageSource', () => {
  class Dto {
    @IsImageSource()
    image?: string;
  }

  it('devuelve un mensaje claro cuando la imagen no es valida', async () => {
    const dto = new Dto();
    dto.image = 'data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=';
    const errors = await validate(dto);
    expect(errors).toHaveLength(1);
    expect(Object.values(errors[0].constraints ?? {})[0]).toContain('imagen');
  });
});

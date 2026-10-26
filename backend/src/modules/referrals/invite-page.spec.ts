import { invitePage, safeUrl } from './invite-page';

describe('página del enlace de invitación', () => {
  it('muestra el código y dice cuánto gana el amigo', () => {
    const html = invitePage({ code: 'AMG-ABC234', friendPoints: 1 });

    expect(html).toContain('¡Te invitaron a Fidelity!');
    expect(html).toContain('AMG-ABC234');
    expect(html).toContain('1 punto');
    expect(html).toContain('Copiar código');
  });

  it('con varios puntos lo dice en plural; sin puntos no promete nada', () => {
    expect(invitePage({ code: 'AMG-ABC234', friendPoints: 3 })).toContain('3 puntos');
    expect(invitePage({ code: 'AMG-ABC234', friendPoints: 0 })).not.toMatch(/ganas <strong>/);
  });

  it('ofrece abrir la web y descargar la app solo con las direcciones configuradas', () => {
    const none = invitePage({ code: 'AMG-ABC234', friendPoints: 1 });
    expect(none).not.toContain('Google Play');
    expect(none).not.toContain('App Store');
    expect(none).not.toContain('Abrir Fidelity en la web');

    const all = invitePage({
      code: 'AMG-ABC234',
      friendPoints: 1,
      webUrl: 'https://app.fidelity.test',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=fidelity',
      appStoreUrl: 'https://apps.apple.com/app/fidelity/id1',
    });
    expect(all).toContain('Descargar en Google Play');
    expect(all).toContain('Descargar en App Store');
    // La web recibe el código para que ya aparezca al registrarse.
    expect(all).toContain('href="https://app.fidelity.test/?code=AMG-ABC234"');
  });

  it('un enlace inválido dice que no sirve y no muestra ningún código', () => {
    const html = invitePage({ code: null, friendPoints: 1 });

    expect(html).toContain('Enlace no válido');
    expect(html).not.toContain('Copiar código');
  });

  it('un código con caracteres raros se trata como inválido (nada se inyecta en la página)', () => {
    const html = invitePage({ code: '<script>alert(1)</script>', friendPoints: 1 });

    expect(html).toContain('Enlace no válido');
    expect(html).not.toContain('alert(1)');
  });

  it('solo se aceptan direcciones http(s)', () => {
    expect(safeUrl('https://a.com/x')).toBe('https://a.com/x');
    expect(safeUrl('http://a.com')).toBe('http://a.com/');
    expect(safeUrl('javascript:alert(1)')).toBeNull();
    expect(safeUrl('no es una url')).toBeNull();
    expect(safeUrl('')).toBeNull();
    expect(safeUrl(undefined)).toBeNull();
  });

  it('una dirección peligrosa no llega a la página', () => {
    const html = invitePage({ code: 'AMG-ABC234', friendPoints: 1, playStoreUrl: 'javascript:alert(1)' });

    expect(html).not.toContain('javascript:');
    expect(html).not.toContain('Google Play');
  });
});

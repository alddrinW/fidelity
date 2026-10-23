import { escapeHtml, passwordChangedEmail, passwordResetEmail, testEmail } from './mail-templates';

describe('plantillas de correo', () => {
  describe('código para restablecer la contraseña', () => {
    const base = { name: 'Ana', code: '482913', minutes: 15 };

    it('en español: asunto, código y vigencia en el texto y en el HTML', () => {
      const mail = passwordResetEmail({ ...base, language: 'es' });

      expect(mail.subject).toBe('Tu código para restablecer la contraseña de Fidelity');
      expect(mail.text).toContain('Hola Ana,');
      expect(mail.text).toContain('482913');
      expect(mail.text).toContain('15 minutos');
      expect(mail.html).toContain('482913');
      expect(mail.html).toContain('15 minutos');
      expect(mail.text).toContain('tu contraseña no ha cambiado');
    });

    it('en inglés cuando la app de la persona está en inglés', () => {
      const mail = passwordResetEmail({ ...base, language: 'en' });

      expect(mail.subject).toBe('Your Fidelity password reset code');
      expect(mail.text).toContain('Hi Ana,');
      expect(mail.text).toContain('15 minutes');
      expect(mail.html).toContain('Use this code');
    });

    it('sin idioma o con uno desconocido sale en español', () => {
      expect(passwordResetEmail({ ...base }).subject).toContain('Tu código');
      expect(passwordResetEmail({ ...base, language: 'fr' }).subject).toContain('Tu código');
    });

    it('sin nombre saluda sin él', () => {
      expect(passwordResetEmail({ code: '111222', minutes: 15, name: null }).text).toMatch(/^Hola,\n/);
      expect(passwordResetEmail({ code: '111222', minutes: 15, name: '  ', language: 'en' }).text).toMatch(/^Hi,\n/);
    });

    it('lleva la marca: franja rosa con FIDELITY y el código resaltado', () => {
      const html = passwordResetEmail(base).html;

      expect(html).toContain('FIDELITY');
      expect(html).toContain('#FEC3DD');
      expect(html).toContain('<!doctype html>');
    });

    it('lo que escribió la persona no puede meter HTML en el correo', () => {
      const mail = passwordResetEmail({ ...base, name: '<script>alert(1)</script> & "Ana"' });

      expect(mail.html).not.toContain('<script>');
      expect(mail.html).toContain('&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;Ana&quot;');
    });
  });

  describe('aviso de contraseña cambiada', () => {
    it('avisa qué hacer si no fue la persona (en español)', () => {
      const mail = passwordChangedEmail({ name: 'Ana', language: 'es' });

      expect(mail.subject).toBe('Cambiaste la contraseña de tu cuenta de Fidelity');
      expect(mail.text).toContain('Si no fuiste tú');
      expect(mail.html).toContain('¿Olvidaste tu contraseña?');
    });

    it('y en inglés', () => {
      const mail = passwordChangedEmail({ name: 'Ana', language: 'en' });

      expect(mail.subject).toBe('Your Fidelity password was changed');
      expect(mail.text).toContain('If it was not you');
    });
  });

  describe('correo de prueba', () => {
    it('existe en los dos idiomas', () => {
      expect(testEmail('es').subject).toBe('Fidelity: correo de prueba');
      expect(testEmail('en').subject).toBe('Fidelity: test email');
      expect(testEmail().text).toContain('Funciona');
    });
  });

  it('escapeHtml cubre los caracteres peligrosos', () => {
    expect(escapeHtml(`<a href="x">'&'</a>`)).toBe('&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;');
  });
});

import { normalizeLanguage } from '../notifications/notification-translator';

/** Un correo listo para enviar: asunto, texto plano y HTML. */
export interface MailContent {
  subject: string;
  text: string;
  html: string;
}

/** Escapa lo que escribió una persona (su nombre) antes de ponerlo en el HTML. */
export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const PINK = '#FEC3DD';

/**
 * El marco de marca de todos los correos: franja rosa con el nombre, contenido
 * y pie. Usa tablas y estilos en línea (así se ve igual en Gmail, Outlook y
 * los celulares).
 */
function layout(language: 'es' | 'en', bodyHtml: string): string {
  const footer =
    language === 'en'
      ? 'You received this email because of an action on your Fidelity account.'
      : 'Recibiste este correo por una acción en tu cuenta de Fidelity.';
  return (
    `<!doctype html><html><body style="margin:0;padding:0;background:#ffffff;">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#ffffff;">` +
    `<tr><td align="center" style="padding:24px 12px;">` +
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;border:2px solid #000000;border-radius:28px;overflow:hidden;font-family:Arial,Helvetica,sans-serif;color:#000000;">` +
    `<tr><td align="center" style="background:${PINK};padding:22px 16px;border-bottom:2px solid #000000;">` +
    `<span style="font-family:Impact,'Arial Black',Arial,sans-serif;font-size:34px;letter-spacing:2px;color:#000000;">FIDELITY</span>` +
    `</td></tr>` +
    `<tr><td style="padding:28px 28px 8px 28px;font-size:16px;line-height:1.55;">${bodyHtml}</td></tr>` +
    `<tr><td style="padding:16px 28px 26px 28px;font-size:12px;line-height:1.5;color:#666666;">${footer}</td></tr>` +
    `</table></td></tr></table></body></html>`
  );
}

function greeting(language: 'es' | 'en', name?: string | null): string {
  const clean = name?.trim();
  if (language === 'en') return clean ? `Hi ${clean},` : 'Hi,';
  return clean ? `Hola ${clean},` : 'Hola,';
}

/** El código para restablecer la contraseña. */
export function passwordResetEmail(input: {
  name?: string | null;
  code: string;
  minutes: number;
  language?: string | null;
}): MailContent {
  const language = normalizeLanguage(input.language);
  const hello = greeting(language, input.name);
  const { code, minutes } = input;

  if (language === 'en') {
    return {
      subject: 'Your Fidelity password reset code',
      text:
        `${hello}\n\nYour code to reset your Fidelity password is: ${code}\n\n` +
        `It expires in ${minutes} minutes. If you did not ask for it, ignore this message: your password has not changed.`,
      html: layout(
        language,
        `<p style="margin:0 0 14px 0;">${escapeHtml(hello)}</p>` +
          `<p style="margin:0 0 14px 0;">Use this code to reset your Fidelity password:</p>` +
          `<p style="margin:0 0 14px 0;text-align:center;"><span style="display:inline-block;background:${PINK};border:2px solid #000000;border-radius:18px;padding:12px 22px;font-family:Impact,'Arial Black',Arial,sans-serif;font-size:36px;letter-spacing:10px;">${code}</span></p>` +
          `<p style="margin:0 0 14px 0;">It expires in <b>${minutes} minutes</b>. If you did not ask for it, ignore this message: your password has not changed.</p>`,
      ),
    };
  }

  return {
    subject: 'Tu código para restablecer la contraseña de Fidelity',
    text:
      `${hello}\n\nTu código para restablecer la contraseña de Fidelity es: ${code}\n\n` +
      `Vence en ${minutes} minutos. Si no lo pediste, ignora este mensaje: tu contraseña no ha cambiado.`,
    html: layout(
      language,
      `<p style="margin:0 0 14px 0;">${escapeHtml(hello)}</p>` +
        `<p style="margin:0 0 14px 0;">Usa este código para restablecer la contraseña de tu cuenta de Fidelity:</p>` +
        `<p style="margin:0 0 14px 0;text-align:center;"><span style="display:inline-block;background:${PINK};border:2px solid #000000;border-radius:18px;padding:12px 22px;font-family:Impact,'Arial Black',Arial,sans-serif;font-size:36px;letter-spacing:10px;">${code}</span></p>` +
        `<p style="margin:0 0 14px 0;">Vence en <b>${minutes} minutos</b>. Si no lo pediste, ignora este mensaje: tu contraseña no ha cambiado.</p>`,
    ),
  };
}

/** Aviso de seguridad: la contraseña se cambió. */
export function passwordChangedEmail(input: { name?: string | null; language?: string | null }): MailContent {
  const language = normalizeLanguage(input.language);
  const hello = greeting(language, input.name);

  if (language === 'en') {
    return {
      subject: 'Your Fidelity password was changed',
      text:
        `${hello}\n\nThe password of your Fidelity account was just changed.\n\n` +
        `If it was you, you do not need to do anything. If it was not you, reset your password right away from "Forgot your password?" in the app.`,
      html: layout(
        language,
        `<p style="margin:0 0 14px 0;">${escapeHtml(hello)}</p>` +
          `<p style="margin:0 0 14px 0;">The password of your Fidelity account was just changed.</p>` +
          `<p style="margin:0 0 14px 0;">If it was you, you do not need to do anything. If it was <b>not</b> you, reset your password right away from <b>"Forgot your password?"</b> in the app.</p>`,
      ),
    };
  }

  return {
    subject: 'Cambiaste la contraseña de tu cuenta de Fidelity',
    text:
      `${hello}\n\nLa contraseña de tu cuenta de Fidelity acaba de cambiar.\n\n` +
      `Si fuiste tú, no tienes que hacer nada. Si no fuiste tú, restablécela de inmediato desde "¿Olvidaste tu contraseña?" en la app.`,
    html: layout(
      language,
      `<p style="margin:0 0 14px 0;">${escapeHtml(hello)}</p>` +
        `<p style="margin:0 0 14px 0;">La contraseña de tu cuenta de Fidelity acaba de cambiar.</p>` +
        `<p style="margin:0 0 14px 0;">Si fuiste tú, no tienes que hacer nada. Si <b>no</b> fuiste tú, restablécela de inmediato desde <b>"¿Olvidaste tu contraseña?"</b> en la app.</p>`,
    ),
  };
}

/** El correo de prueba (npm run mail:test). */
export function testEmail(language?: string | null): MailContent {
  const lang = normalizeLanguage(language);
  if (lang === 'en') {
    return {
      subject: 'Fidelity: test email',
      text: 'It works! Fidelity can send emails from this server.',
      html: layout(lang, `<p style="margin:0 0 14px 0;"><b>It works!</b> Fidelity can send emails from this server.</p>`),
    };
  }
  return {
    subject: 'Fidelity: correo de prueba',
    text: '¡Funciona! Fidelity puede enviar correos desde este servidor.',
    html: layout(lang, `<p style="margin:0 0 14px 0;"><b>¡Funciona!</b> Fidelity puede enviar correos desde este servidor.</p>`),
  };
}

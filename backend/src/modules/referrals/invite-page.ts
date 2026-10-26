/** Los datos de la página pública a la que lleva el enlace de invitación. */
export interface InvitePageOptions {
  /** El código (`AMG-XXXXXX`) o `null` si el enlace no es válido. */
  code: string | null;
  /** Lo que gana el amigo con su primer escaneo (0 si no gana nada). */
  friendPoints: number;
  webUrl?: string;
  playStoreUrl?: string;
  appStoreUrl?: string;
}

/** Solo direcciones http(s): nunca se pone en la página algo que no lo sea. */
export function safeUrl(url?: string): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.toString() : null;
  } catch {
    return null;
  }
}

const escapeHtml = (text: string) =>
  text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/**
 * La página que abre quien recibe el enlace de invitación: dice que lo invitaron
 * a Fidelity, muestra el código para copiarlo y ofrece abrir la app web o
 * descargarla (solo con las direcciones que estén configuradas).
 */
export function invitePage(options: InvitePageOptions): string {
  const code = options.code && /^[A-Z0-9-]{4,20}$/.test(options.code) ? options.code : null;
  const web = safeUrl(options.webUrl);
  const play = safeUrl(options.playStoreUrl);
  const store = safeUrl(options.appStoreUrl);

  const gift =
    options.friendPoints > 0
      ? `Haz tu primer escaneo y ganas <strong>${options.friendPoints} ${options.friendPoints === 1 ? 'punto' : 'puntos'}</strong> para usar en el local que elijas.`
      : 'Junta puntos con tus escaneos y gana premios en tus locales favoritos.';

  const buttons = [
    web ? `<a class="btn dark" href="${escapeHtml(web + (web.includes('?') ? '&' : '?') + 'code=' + (code ?? ''))}">Abrir Fidelity en la web</a>` : '',
    play ? `<a class="btn" href="${escapeHtml(play)}">Descargar en Google Play</a>` : '',
    store ? `<a class="btn" href="${escapeHtml(store)}">Descargar en App Store</a>` : '',
  ].join('');

  const body = code
    ? `<h1>¡Te invitaron a Fidelity!</h1>
  <p>${gift}</p>
  <p class="label">Tu código de amigo</p>
  <div class="code" id="code">${escapeHtml(code)}</div>
  <button class="btn dark" id="copy" type="button">Copiar código</button>
  ${buttons}
  <p class="small">Al registrarte en la app, escríbelo en <em>Código de un amigo</em>.</p>
  <script>
    document.getElementById('copy').addEventListener('click', function () {
      var text = document.getElementById('code').textContent;
      var done = function () { document.getElementById('copy').textContent = '¡Copiado!'; };
      if (navigator.clipboard) { navigator.clipboard.writeText(text).then(done); } else { done(); }
    });
  </script>`
    : `<h1>Enlace no válido</h1>
  <p>Este enlace de invitación no existe o ya no funciona. Pídele a tu amigo que te lo comparta de nuevo desde la app de Fidelity.</p>`;

  return `<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>Fidelity · Te invitaron</title>
<style>
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
    background:#fff;color:#000;font-family:Helvetica,Arial,sans-serif;padding:24px;box-sizing:border-box}
  main{max-width:420px;width:100%;text-align:center}
  .badge{display:inline-block;background:#ffb3d9;border:1.5px solid #000;border-radius:999px;
    padding:6px 18px;letter-spacing:.2em;font-size:12px;font-weight:700;margin-bottom:20px}
  h1{font-size:30px;margin:0 0 12px;text-transform:uppercase;letter-spacing:.04em}
  p{font-size:16px;line-height:1.5;margin:0 0 14px;font-weight:300}
  .label{font-size:12px;letter-spacing:.2em;text-transform:uppercase;margin:22px 0 8px}
  .code{font-size:34px;font-weight:800;letter-spacing:.12em;background:#f5f5f5;border-radius:18px;padding:16px;margin-bottom:16px}
  .btn{display:block;box-sizing:border-box;width:100%;padding:14px;margin:0 0 10px;border-radius:999px;border:1.5px solid #000;
    background:#fff;color:#000;font-size:15px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;text-decoration:none;cursor:pointer}
  .btn.dark{background:#000;color:#fff}
  .small{font-size:13px;margin-top:18px}
</style></head>
<body><main>
  <span class="badge">FIDELITY</span>
  ${body}
</main></body></html>`;
}

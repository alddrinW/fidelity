/**
 * Datos de demostración para llenar la plataforma: negocios, clientes, tarjetas,
 * escaneos, premios, campañas, gift cards, rutas, minijuegos, pagos, opiniones y
 * notificaciones.
 *
 *   npm run seed:demo            crea los datos (si ya existen, no duplica)
 *   npm run seed:demo -- --reset borra los datos de demostración y los crea de nuevo
 *   npm run seed:demo -- --clean solo borra los datos de demostración
 *
 * Todo lo que crea cuelga de cuentas con correo `@demo.fidelity.test`, así que
 * nunca toca los datos reales: borrar esas cuentas borra también todo lo suyo
 * (las claves foráneas son en cascada). Solo corre contra una base local, salvo
 * que se pida con DB_SEED_ALLOW_REMOTE=true.
 *
 * Las cuentas de demostración usan la clave DEMO_PASSWORD (de pruebas, para
 * desarrollo local).
 */
import { Client } from 'pg';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';
import { randomBytes } from 'crypto';
import { deflateSync } from 'zlib';

dotenv.config();

export const DEMO_DOMAIN = 'demo.fidelity.test';
export const DEMO_PASSWORD = 'Demo1234!';

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;
const now = Date.now();
const ago = (ms: number) => new Date(now - ms);
const ahead = (ms: number) => new Date(now + ms);

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

/** Aleatorio repetible: el mismo seed da siempre los mismos datos. */
function makeRandom(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const random = makeRandom(2026);
const int = (min: number, max: number) => min + Math.floor(random() * (max - min + 1));
const pick = <T>(list: T[]): T => list[Math.floor(random() * list.length)];
const chance = (p: number) => random() < p;
function shuffle<T>(list: T[]): T[] {
  const copy = [...list];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

const CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
function code(prefix: string, length = 6): string {
  const bytes = randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i++) out += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  return `${prefix}-${out}`;
}

// PNG sencillo (sin dependencias) para logos, fotos de perfil y portadas.
const CRC_TABLE = (() => {
  const table: number[] = [];
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();
function crc32(buffer: Buffer): number {
  let c = 0xffffffff;
  for (const byte of buffer) c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type: string, data: Buffer): Buffer {
  const body = Buffer.concat([Buffer.from(type), data]);
  const out = Buffer.alloc(body.length + 8);
  out.writeUInt32BE(data.length, 0);
  body.copy(out, 4);
  out.writeUInt32BE(crc32(body), body.length + 4);
  return out;
}
type Rgb = [number, number, number];
function pngDataUri(
  width: number,
  height: number,
  paint: (x: number, y: number) => [number, number, number, number],
): string {
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    for (let x = 0; x < width; x++) {
      const [r, g, b, a] = paint(x, y);
      const o = y * (width * 4 + 1) + 1 + x * 4;
      raw[o] = r;
      raw[o + 1] = g;
      raw[o + 2] = b;
      raw[o + 3] = a;
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6;
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  return `data:image/png;base64,${png.toString('base64')}`;
}

/** Un disco de color con un círculo interior (logo o foto de perfil). */
function badge(color: Rgb, accent: Rgb): string {
  const size = 96;
  const c = (size - 1) / 2;
  return pngDataUri(size, size, (x, y) => {
    const d = Math.hypot(x - c, y - c);
    if (d > 46) return [0, 0, 0, 0];
    if (d < 20) return [...accent, 255];
    if (d > 41) return [0, 0, 0, 255];
    return [...color, 255];
  });
}

/** Una portada con franjas de color (campañas). */
function banner(color: Rgb, accent: Rgb): string {
  return pngDataUri(240, 120, (x, y) => {
    const stripe = Math.floor((x + y) / 24) % 2 === 0;
    return [...(stripe ? color : accent), 255] as [number, number, number, number];
  });
}

const PINK: Rgb = [255, 192, 220];
const BLACK: Rgb = [0, 0, 0];
const WHITE: Rgb = [255, 255, 255];
const PALETTE: Array<[Rgb, Rgb]> = [
  [PINK, BLACK],
  [BLACK, PINK],
  [WHITE, PINK],
  [[255, 214, 232], BLACK],
  [[40, 40, 40], WHITE],
  [PINK, WHITE],
];

// ---------------------------------------------------------------------------
// Datos base
// ---------------------------------------------------------------------------

const FIRST_NAMES = [
  'Camila', 'Mateo', 'Valentina', 'Sebastián', 'Isabella', 'Santiago', 'Daniela', 'Nicolás',
  'Mariana', 'Andrés', 'Paula', 'Diego', 'Sofía', 'Gabriel', 'Lucía', 'Felipe', 'Carolina',
  'Esteban', 'Fernanda', 'Joaquín', 'Andrea', 'Ricardo', 'Gabriela', 'Javier', 'Natalia',
  'Pablo', 'Verónica', 'Kevin',
];
const LAST_NAMES = [
  'Paz', 'Mora', 'Andrade', 'Cevallos', 'Villacís', 'Játiva', 'Zambrano', 'Naranjo', 'Proaño',
  'Salazar', 'Cárdenas', 'Mena', 'Guerrero', 'Ortiz', 'Quishpe', 'Tapia', 'Romero', 'Vega',
  'Lasso', 'Tituaña', 'Cueva', 'Ponce', 'Barrera', 'Montalvo',
];

interface BusinessSeed {
  key: string;
  name: string;
  category: string;
  description: string;
  address: string;
  lat: number;
  lng: number;
  phone: string;
  taxId: string;
  reward: string;
  rewardLong: string;
  points: number;
  cooldown: number;
  state: 'active' | 'pending-payment' | 'reported-payment';
  owner: string;
  parent?: string;
  popularity: number; // 0..1: qué parte de los clientes tiene tarjeta aquí
}

const BUSINESSES: BusinessSeed[] = [
  {
    key: 'aurora', name: 'Café Aurora', category: 'Cafeterías & Panaderías',
    description: 'Café de especialidad de altura y repostería artesanal en el corazón de La Floresta.',
    address: 'Av. 12 de Octubre N24-593 y Cordero, Quito', lat: -0.2023, lng: -78.4896, phone: '0991230001',
    taxId: '1790012345001', reward: 'Café americano gratis', rewardLong: 'Un café americano o té a elección, en cualquier tamaño.',
    points: 8, cooldown: 12, state: 'active', owner: 'Aurora Zhunio', popularity: 0.8,
  },
  {
    key: 'aurora-cumbaya', name: 'Café Aurora Cumbayá', category: 'Cafeterías & Panaderías',
    description: 'Sucursal de Café Aurora en el Scala Shopping.',
    address: 'Scala Shopping, Cumbayá, Quito', lat: -0.2000, lng: -78.4290, phone: '0991230002',
    taxId: '1790012345001', reward: 'Café americano gratis', rewardLong: 'Un café americano o té a elección, en cualquier tamaño.',
    points: 8, cooldown: 12, state: 'active', owner: 'Aurora Zhunio', parent: 'aurora', popularity: 0.35,
  },
  {
    key: 'espiga', name: 'Panadería La Espiga', category: 'Cafeterías & Panaderías',
    description: 'Pan de masa madre horneado cada mañana, empanadas de viento y pasteles.',
    address: 'Calle Venezuela 8-22, Cuenca', lat: -2.8974, lng: -79.0045, phone: '0991230003',
    taxId: '0190123456001', reward: 'Pan de la casa + café', rewardLong: 'Un pan artesanal a elección con un café pasado.',
    points: 10, cooldown: 24, state: 'active', owner: 'Marcelo Idrovo', popularity: 0.55,
  },
  {
    key: 'fogon', name: 'Asadero El Fogón', category: 'Restaurantes & Bares',
    description: 'Parrilladas, hornado y platos típicos a leña. Ambiente familiar.',
    address: 'Av. Amazonas N31-120 y Mariana de Jesús, Quito', lat: -0.1807, lng: -78.4836, phone: '0991230004',
    taxId: '1791234567001', reward: 'Postre gratis', rewardLong: 'Un postre de la casa con tu próxima comida.',
    points: 10, cooldown: 24, state: 'active', owner: 'Rodrigo Albán', popularity: 0.7,
  },
  {
    key: 'filo', name: 'Barbería Don Filo', category: 'Belleza & Barberías',
    description: 'Cortes clásicos, perfilado de barba y afeitado con toalla caliente.',
    address: 'Calle Sucre 12-40, Ambato', lat: -1.2417, lng: -78.6197, phone: '0991230005',
    taxId: '1890123456001', reward: 'Corte de cabello gratis', rewardLong: 'Un corte clásico o degradado sin costo.',
    points: 6, cooldown: 72, state: 'active', owner: 'Filomeno Chávez', popularity: 0.5,
  },
  {
    key: 'luna', name: 'Boutique Luna', category: 'Moda & Calzado',
    description: 'Ropa casual y accesorios de diseñadores ecuatorianos.',
    address: 'CC Quicentro Sur, local 215, Quito', lat: -0.2923, lng: -78.5442, phone: '0991230006',
    taxId: '1792345678001', reward: '20% en tu próxima compra', rewardLong: 'Descuento del 20% en prendas de la nueva colección.',
    points: 10, cooldown: 48, state: 'active', owner: 'Luna Mercado', popularity: 0.4,
  },
  {
    key: 'titan', name: 'Gym Titán Fit', category: 'Salud & Fitness',
    description: 'Musculación, funcional y clases grupales de lunes a sábado.',
    address: 'Av. del Maestro N52-80, Quito', lat: -0.1650, lng: -78.4700, phone: '0991230007',
    taxId: '1793456789001', reward: 'Semana de pase libre', rewardLong: 'Siete días de acceso libre a todas las clases.',
    points: 12, cooldown: 24, state: 'active', owner: 'Dario Titán', popularity: 0.45,
  },
  {
    key: 'arcade', name: 'Cine Arcade Plaza', category: 'Servicios & Entretenimiento',
    description: 'Cine independiente, sala de juegos retro y snacks.',
    address: 'Plaza Foch, Mariscal, Quito', lat: -0.2000, lng: -78.4900, phone: '0991230008',
    taxId: '1794567890001', reward: 'Entrada 2x1', rewardLong: 'Dos entradas por el precio de una, de lunes a jueves.',
    points: 8, cooldown: 24, state: 'active', owner: 'Ximena Plaza', popularity: 0.3,
  },
  {
    key: 'nube', name: 'Heladería Nube', category: 'Cafeterías & Panaderías',
    description: 'Helados artesanales de frutas del Ecuador.',
    address: 'Malecón 2000, Guayaquil', lat: -2.1894, lng: -79.8817, phone: '0991230009',
    taxId: '0991234567001', reward: 'Helado de dos sabores gratis', rewardLong: 'Un helado de dos bolas con cobertura.',
    points: 8, cooldown: 24, state: 'reported-payment', owner: 'Tatiana Nube', popularity: 0,
  },
  {
    key: 'taller', name: 'Taller Mecánico RPM', category: 'Servicios & Entretenimiento',
    description: 'Mantenimiento preventivo y alineación.',
    address: 'Av. Eloy Alfaro N40-12, Quito', lat: -0.1700, lng: -78.4800, phone: '0991230010',
    taxId: '1795678901001', reward: 'Lavado de auto gratis', rewardLong: 'Lavado exterior e interior al terminar tu servicio.',
    points: 6, cooldown: 24, state: 'pending-payment', owner: 'Rubén Paredes', popularity: 0,
  },
];

const APPROVERS: Array<{ name: string; business: string }> = [
  { name: 'Josué Ramos', business: 'aurora' },
  { name: 'Mónica Sandoval', business: 'aurora' },
  { name: 'Bryan Toapanta', business: 'fogon' },
  { name: 'Erika Lozada', business: 'filo' },
];

const slug = (text: string) =>
  text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^\.|\.$/g, '');

// ---------------------------------------------------------------------------
// Base de datos
// ---------------------------------------------------------------------------

type Row = Record<string, unknown>;

class Db {
  constructor(private readonly client: Client) {}

  async one<T = Row>(sql: string, params: unknown[] = []): Promise<T | undefined> {
    return (await this.client.query(sql, params)).rows[0] as T | undefined;
  }
  async all<T = Row>(sql: string, params: unknown[] = []): Promise<T[]> {
    return (await this.client.query(sql, params)).rows as T[];
  }
  async run(sql: string, params: unknown[] = []) {
    return this.client.query(sql, params);
  }
  /** INSERT a partir de un objeto; devuelve el id. */
  async insert(table: string, data: Row): Promise<string> {
    const keys = Object.keys(data).filter((k) => data[k] !== undefined);
    const values = keys.map((k) => {
      const v = data[k];
      return v !== null && typeof v === 'object' && !(v instanceof Date) && !Array.isArray(v)
        ? JSON.stringify(v)
        : v;
    });
    const sql = `INSERT INTO ${table} (${keys.join(', ')}) VALUES (${keys.map((_, i) => `$${i + 1}`).join(', ')}) RETURNING id`;
    return (await this.client.query(sql, values)).rows[0].id as string;
  }
}

function assertLocal() {
  const host = (process.env.DB_HOST || 'localhost').toLowerCase();
  const local = ['localhost', '127.0.0.1', '::1'].includes(host);
  if (process.env.NODE_ENV === 'production' || (!local && process.env.DB_SEED_ALLOW_REMOTE !== 'true')) {
    throw new Error(
      `Este seed solo corre contra una base local (DB_HOST=${host}). ` +
        'Si de verdad quieres usar otra, define DB_SEED_ALLOW_REMOTE=true.',
    );
  }
}

async function clean(db: Db) {
  const res = await db.run(`DELETE FROM profiles WHERE email LIKE $1`, [`%@${DEMO_DOMAIN}`]);
  console.log(`Datos de demostración borrados (${res.rowCount} cuentas y todo lo suyo).`);
}

// ---------------------------------------------------------------------------
// Siembra
// ---------------------------------------------------------------------------

async function seed(db: Db) {
  const existing = await db.one<{ n: string }>(`SELECT count(*) AS n FROM profiles WHERE email LIKE $1`, [
    `%@${DEMO_DOMAIN}`,
  ]);
  if (Number(existing?.n) > 0) {
    console.log('Ya hay datos de demostración. Usa --reset para crearlos de nuevo.');
    return;
  }

  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 10);
  const email = (name: string, tag = '') => `${slug(name)}${tag}@${DEMO_DOMAIN}`;

  // El administrador que valida pagos y atiende (se usa el existente).
  let admin = await db.one<{ id: string }>(`SELECT id FROM profiles WHERE role='admin' ORDER BY created_at LIMIT 1`);
  if (!admin) {
    const id = await db.insert('profiles', {
      email: `admin@${DEMO_DOMAIN}`, full_name: 'Administrador Demo', role: 'admin', password_hash: passwordHash,
    });
    admin = { id };
  }
  const adminId = admin.id;

  const categories = await db.all<{ id: number; name: string }>(`SELECT id, name FROM business_categories`);
  const categoryId = (name: string) => categories.find((c) => c.name === name)?.id ?? null;

  // ---- Dueños, negocios y QR ----
  const ownerIds = new Map<string, string>();
  const businessIds = new Map<string, string>();
  const qrIds = new Map<string, string[]>();
  let paletteIndex = 0;

  for (const b of BUSINESSES) {
    if (!ownerIds.has(b.owner)) {
      const [c, a] = PALETTE[paletteIndex++ % PALETTE.length];
      ownerIds.set(
        b.owner,
        await db.insert('profiles', {
          email: email(b.owner), full_name: b.owner, role: 'business', password_hash: passwordHash,
          phone: `09${int(10000000, 99999999)}`, avatar_url: badge(a, c),
        }),
      );
    }
  }
  paletteIndex = 0;
  for (const b of BUSINESSES) {
    const [c, a] = PALETTE[paletteIndex++ % PALETTE.length];
    const id = await db.insert('businesses', {
      owner_id: ownerIds.get(b.owner), category_id: categoryId(b.category), name: b.name,
      description: b.description, category: b.category, logo_url: badge(c, a),
      reward_description: b.reward, reward_long_description: b.rewardLong, points_required: b.points,
      cooldown_hours: b.cooldown, is_active: b.state === 'active', latitude: b.lat, longitude: b.lng,
      address: b.address, phone: b.phone, tax_id: b.taxId,
      parent_id: b.parent ? businessIds.get(b.parent) : null,
      created_at: ago(int(40, 120) * DAY),
    });
    businessIds.set(b.key, id);

    if (b.state === 'active') {
      const labels = ['Mostrador principal', 'Caja 2'].slice(0, b.popularity > 0.5 ? 2 : 1);
      const ids: string[] = [];
      for (const label of labels) {
        ids.push(
          await db.insert('qr_codes', {
            business_id: id, label, qr_code: `FID-${id.substring(0, 8)}-${randomBytes(4).toString('hex')}`.toUpperCase(),
          }),
        );
      }
      qrIds.set(b.key, ids);
    }
  }
  const active = BUSINESSES.filter((b) => b.state === 'active');
  console.log(`Negocios: ${BUSINESSES.length} (${active.length} activos) de ${ownerIds.size} dueños`);

  // ---- Pagos de registro (PAGA YA) ----
  const fee = parseFloat(process.env.REGISTRATION_FEE ?? '') || 20;
  let receipt = 1000;
  for (const b of BUSINESSES) {
    const base = {
      business_id: businessIds.get(b.key), owner_id: ownerIds.get(b.owner), concept: b.parent ? 'branch' : 'registration',
      amount: b.parent ? Math.round(fee * 0.6 * 100) / 100 : fee, currency: 'USD', reference: code('FID'),
    };
    if (b.state === 'active') {
      const card = chance(0.6);
      await db.insert('payments', {
        ...base, status: 'paid', method: card ? 'card' : pick(['transfer', 'deposit']),
        note: card ? null : 'Comprobante enviado por WhatsApp',
        receipt_number: `REC-${receipt++}`, paid_at: ago(int(10, 100) * DAY), reported_at: ago(int(10, 100) * DAY),
        validated_by_id: card ? null : adminId, gateway_auth_code: card ? randomBytes(3).toString('hex').toUpperCase() : null,
        created_at: ago(int(30, 110) * DAY),
      });
    } else if (b.state === 'reported-payment') {
      await db.insert('payments', {
        ...base, status: 'reported', method: 'transfer', note: 'Transferencia Banco Pichincha',
        proof_url: banner(PINK, WHITE), reported_at: ago(3 * HOUR), created_at: ago(2 * DAY),
      });
    } else {
      await db.insert('payments', { ...base, status: 'pending', created_at: ago(5 * HOUR) });
    }
  }

  // ---- Aprobadores ----
  const approverIds = new Map<string, string>();
  for (const a of APPROVERS) {
    const id = await db.insert('profiles', {
      email: email(a.name), full_name: a.name, role: 'approver', password_hash: passwordHash, phone: `09${int(10000000, 99999999)}`,
    });
    approverIds.set(a.name, id);
    await db.insert('business_members', { business_id: businessIds.get(a.business), user_id: id, role: 'approver' });
    await db.insert('notifications', {
      user_id: id, type: 'approver_assigned', title: 'Ahora eres aprobador',
      body: `${BUSINESSES.find((b) => b.key === a.business)!.name} te asignó como aprobador. Vuelve a iniciar sesión para ver su panel.`,
      read_at: ago(DAY), created_at: ago(2 * DAY),
    });
  }

  // ---- Clientes ----
  interface Client { id: string; name: string }
  const clients: Client[] = [];
  const usedNames = new Set<string>();
  while (clients.length < 28) {
    const name = `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)}`;
    if (usedNames.has(name)) continue;
    usedNames.add(name);
    const [c, a] = PALETTE[clients.length % PALETTE.length];
    const id = await db.insert('profiles', {
      email: email(name), full_name: name, role: 'client', password_hash: passwordHash,
      phone: `09${int(10000000, 99999999)}`, avatar_url: badge(a, c), created_at: ago(int(5, 100) * DAY),
    });
    clients.push({ id, name });
  }
  console.log(`Clientes: ${clients.length}, aprobadores: ${APPROVERS.length}`);

  // ---- Tarjetas, escaneos y premios ----
  interface Card { id: string; clientId: string; clientName: string; businessKey: string; points: number; rewarded: number }
  const cards: Card[] = [];
  const pendingScansPerBusiness = new Map<string, number>();

  for (const client of clients) {
    const chosen = shuffle(active).filter((b) => chance(b.popularity + 0.15)).slice(0, 5);
    if (chosen.length < 2) chosen.push(...shuffle(active).filter((b) => !chosen.includes(b)).slice(0, 2 - chosen.length));

    for (const b of chosen) {
      const businessId = businessIds.get(b.key)!;
      const rewardsClaimed = chance(0.3) ? int(1, 2) : 0;
      // Algunos clientes están a un punto de ganar, otros recién empiezan.
      const points = chance(0.25) ? b.points - 1 : chance(0.15) ? 0 : int(1, b.points - 1);
      const lifetime = points + rewardsClaimed * b.points;
      const firstScan = ago(int(10, 80) * DAY);
      const scanTimes = Array.from({ length: lifetime }, (_, i) =>
        new Date(firstScan.getTime() + ((now - firstScan.getTime()) * (i + random() * 0.8)) / Math.max(lifetime, 1)),
      ).sort((x, y) => x.getTime() - y.getTime());
      const lastScan = scanTimes[scanTimes.length - 1] ?? null;

      const cardId = await db.insert('loyalty_cards', {
        user_id: client.id, business_id: businessId, current_points: points, total_points_lifetime: lifetime,
        rewards_claimed: rewardsClaimed, last_scan_at: lastScan, created_at: firstScan,
      });
      cards.push({ id: cardId, clientId: client.id, clientName: client.name, businessKey: b.key, points, rewarded: rewardsClaimed });

      const qrs = qrIds.get(b.key)!;
      for (const at of scanTimes) {
        await db.insert('scans', {
          user_id: client.id, business_id: businessId, loyalty_card_id: cardId, qr_code_id: pick(qrs),
          status: 'approved', scanned_at: at, created_at: at,
        });
      }
      // Premios ya canjeados.
      for (let r = 0; r < rewardsClaimed; r++) {
        const earned = scanTimes[Math.min((r + 1) * b.points - 1, scanTimes.length - 1)] ?? ago(20 * DAY);
        await db.insert('rewards', {
          user_id: client.id, business_id: businessId, loyalty_card_id: cardId, reward_description: b.reward,
          description: b.rewardLong, points_used: b.points, status: 'claimed', earned_at: earned,
          claimed_at: new Date(earned.getTime() + int(1, 5) * DAY), created_at: earned,
        });
      }
    }
  }
  console.log(`Tarjetas: ${cards.length}`);

  // Pendientes de aprobar y rechazados (lo que ve el aprobador en su pestaña).
  let pendingScans = 0;
  for (const b of active) {
    const businessCards = cards.filter((c) => c.businessKey === b.key);
    const count = Math.min(businessCards.length, b.popularity > 0.5 ? int(2, 4) : int(0, 2));
    for (const card of shuffle(businessCards).slice(0, count)) {
      await db.insert('scans', {
        user_id: card.clientId, business_id: businessIds.get(b.key), loyalty_card_id: card.id,
        qr_code_id: pick(qrIds.get(b.key)!), status: 'pending', scanned_at: ago(int(1, 90) * 60 * 1000),
        created_at: ago(int(1, 90) * 60 * 1000),
      });
      pendingScans++;
      pendingScansPerBusiness.set(b.key, (pendingScansPerBusiness.get(b.key) ?? 0) + 1);
    }
    const rejected = shuffle(businessCards)[0];
    if (rejected && chance(0.6)) {
      await db.insert('scans', {
        user_id: rejected.clientId, business_id: businessIds.get(b.key), loyalty_card_id: rejected.id,
        qr_code_id: pick(qrIds.get(b.key)!), status: 'rejected', scanned_at: ago(int(2, 20) * DAY),
        created_at: ago(int(2, 20) * DAY),
      });
    }
  }

  // Premios listos para entregar (los valida el dueño o el aprobador).
  let readyRewards = 0;
  for (const card of shuffle(cards).slice(0, 10)) {
    const b = BUSINESSES.find((x) => x.key === card.businessKey)!;
    const status = chance(0.6) ? 'pending' : 'approved';
    await db.insert('rewards', {
      user_id: card.clientId, business_id: businessIds.get(card.businessKey), loyalty_card_id: card.id,
      reward_description: b.reward, description: b.rewardLong, points_used: b.points, status,
      earned_at: ago(int(1, 48) * HOUR), created_at: ago(int(1, 48) * HOUR),
    });
    readyRewards++;
    await db.insert('notifications', {
      user_id: card.clientId, type: 'general', title: 'Premio alcanzado',
      body: `Has ganado premio en ${b.name}, acercate a retirar.`,
      data: { route: '/' }, read_at: chance(0.4) ? ago(HOUR) : null, created_at: ago(int(1, 40) * HOUR),
    });
  }
  const rejectedCard = pick(cards);
  const rejectedBusiness = BUSINESSES.find((x) => x.key === rejectedCard.businessKey)!;
  await db.insert('rewards', {
    user_id: rejectedCard.clientId, business_id: businessIds.get(rejectedCard.businessKey),
    loyalty_card_id: rejectedCard.id, reward_description: rejectedBusiness.reward, points_used: rejectedBusiness.points,
    status: 'rejected', earned_at: ago(9 * DAY), created_at: ago(9 * DAY),
  });
  console.log(`Escaneos pendientes: ${pendingScans}, premios por entregar: ${readyRewards}`);

  // ---- Campañas ----
  const customersOf = (key: string) => cards.filter((c) => c.businessKey === key).map((c) => c.clientId);

  async function campaign(
    key: string,
    data: {
      type: 'event' | 'gift_card' | 'route' | 'scan_challenge'; title: string; description?: string; benefit?: 'discount_percent' | 'mini_prize';
      value?: number; label?: string; audience?: 'all' | 'selected'; stamps?: number; starts: Date; ends?: Date | null;
      cancelled?: boolean; image?: boolean; hidden?: boolean; scans?: number; businesses?: string[];
    },
  ) {
    const started = data.starts.getTime() <= now;
    const id = await db.insert('campaigns', {
      business_id: businessIds.get(key), type: data.type, title: data.title, description: data.description ?? null,
      image_url: data.image === false ? null : banner(...(pick(PALETTE) as [Rgb, Rgb])),
      benefit_type: data.benefit ?? null, benefit_value: data.value ?? null, benefit_label: data.label ?? null,
      audience: data.audience ?? 'all', required_stamps: data.stamps ?? null, required_scans: data.scans ?? null, starts_at: data.starts,
      ends_at: data.ends ?? null, cancelled_at: data.cancelled ? ago(2 * DAY) : null, hidden: data.hidden ?? false,
      notified_at: started ? data.starts : null, created_at: new Date(Math.min(data.starts.getTime(), now) - DAY),
    });
    for (const businessKey of data.businesses ?? [key]) {
      await db.insert('campaign_businesses', { campaign_id: id, business_id: businessIds.get(businessKey) });
    }
    return id;
  }

  async function issueClaims(
    campaignId: string, userIds: string[], redeemRate: number, redeemerKey: string, selected = false,
  ) {
    const redeemers = [ownerIds.get(BUSINESSES.find((b) => b.key === redeemerKey)!.owner)!];
    for (const [name, businessKey] of APPROVERS.map((a) => [a.name, a.business] as const)) {
      if (businessKey === redeemerKey) redeemers.push(approverIds.get(name)!);
    }
    for (const userId of userIds) {
      if (selected) await db.insert('campaign_recipients', { campaign_id: campaignId, user_id: userId });
      const redeemed = chance(redeemRate);
      await db.insert('campaign_claims', {
        campaign_id: campaignId, user_id: userId, code: code('GFT'), status: redeemed ? 'redeemed' : 'active',
        source: 'claim', redeemed_by_id: redeemed ? pick(redeemers) : null,
        redeemed_at: redeemed ? ago(int(1, 10) * DAY) : null, created_at: ago(int(1, 14) * DAY),
      });
    }
  }

  let campaignCount = 0;
  let claimsTotal = 0;
  const addClaims = async (id: string, users: string[], rate: number, key: string, selected = false) => {
    await issueClaims(id, users, rate, key, selected);
    claimsTotal += users.length;
  };

  // Café Aurora
  const aurora = customersOf('aurora');
  let id = await campaign('aurora', {
    type: 'gift_card', title: '20% en tu café', description: 'Muestra tu código en caja y disfruta tu café con descuento.',
    benefit: 'discount_percent', value: 20, label: '20% de descuento', starts: ago(10 * DAY), ends: ahead(20 * DAY),
  });
  await addClaims(id, aurora, 0.35, 'aurora'); campaignCount++;
  id = await campaign('aurora', {
    type: 'gift_card', title: 'Galleta de cortesía', description: 'Un detalle para nuestros clientes más fieles.',
    benefit: 'mini_prize', label: 'Galleta de chocolate gratis', audience: 'selected', starts: ago(3 * DAY), ends: ahead(30 * DAY),
  });
  await addClaims(id, shuffle(aurora).slice(0, 6), 0.3, 'aurora', true); campaignCount++;
  await campaign('aurora', {
    type: 'event', title: 'Noche de jazz y café', description: 'Viernes 8 pm en vivo con el cuarteto Quito Blue.',
    starts: ago(2 * DAY), ends: ahead(5 * DAY),
  }); campaignCount++;
  await campaign('aurora', {
    type: 'event', title: 'Taller de latte art', description: 'Aprende con nuestros baristas. Cupos limitados.',
    starts: ahead(6 * DAY), ends: ahead(7 * DAY),
  }); campaignCount++;
  await campaign('aurora', {
    type: 'event', title: 'Feria de postres', description: 'Una tarde de dulces artesanales.',
    starts: ago(35 * DAY), ends: ago(33 * DAY),
  }); campaignCount++;
  await campaign('aurora', {
    type: 'gift_card', title: 'Combo desayuno', benefit: 'discount_percent', value: 10, label: '10% de descuento',
    starts: ago(8 * DAY), ends: ahead(8 * DAY), cancelled: true,
  }); campaignCount++;

  // Don Filo
  id = await campaign('filo', {
    type: 'gift_card', title: '15% en tu corte', benefit: 'discount_percent', value: 15, label: '15% de descuento',
    starts: ago(6 * DAY), ends: ahead(24 * DAY),
  });
  await addClaims(id, customersOf('filo'), 0.4, 'filo'); campaignCount++;
  await campaign('filo', {
    type: 'event', title: 'Martes de barba', description: 'Perfilado de barba con 2x1 todos los martes.',
    starts: ago(DAY), ends: ahead(60 * DAY),
  }); campaignCount++;

  // El Fogón
  id = await campaign('fogon', {
    type: 'gift_card', title: '2x1 en postres', benefit: 'mini_prize', label: 'Segundo postre gratis',
    starts: ago(4 * DAY), ends: ahead(14 * DAY),
  });
  await addClaims(id, customersOf('fogon'), 0.3, 'fogon'); campaignCount++;
  await campaign('fogon', {
    type: 'event', title: 'Hornado de domingo', description: 'Cada domingo, hornado con mote y llapingachos.',
    starts: ago(20 * DAY), ends: ahead(40 * DAY),
  }); campaignCount++;

  // Titán Fit
  await campaign('titan', {
    type: 'event', title: 'Reto 30 días', description: 'Inscríbete y gana premios por constancia.',
    starts: ago(5 * DAY), ends: ahead(25 * DAY),
  }); campaignCount++;
  id = await campaign('titan', {
    type: 'gift_card', title: 'Pase de cortesía', benefit: 'mini_prize', label: 'Un día de pase libre',
    audience: 'selected', starts: ago(DAY), ends: ahead(15 * DAY),
  });
  await addClaims(id, shuffle(customersOf('titan')).slice(0, 4), 0.25, 'titan', true); campaignCount++;

  // Boutique Luna (programada)
  await campaign('luna', {
    type: 'gift_card', title: 'Black Friday Luna', benefit: 'discount_percent', value: 30, label: '30% de descuento',
    starts: ahead(21 * DAY), ends: ahead(24 * DAY),
  }); campaignCount++;

  // Reto de escaneos: 5 escaneos en Café Aurora para ganar un descuento
  const challengeId = await campaign('aurora', {
    type: 'scan_challenge', title: 'Reto de 5 escaneos', description: 'Escanea 5 veces en Café Aurora y llévate un descuento.',
    benefit: 'discount_percent', value: 15, label: '15% de descuento', scans: 5, starts: ago(6 * DAY), ends: ahead(24 * DAY),
  }); campaignCount++;
  for (const card of shuffle(cards.filter((c) => c.businessKey === 'aurora')).slice(0, 2)) {
    await db.insert('campaign_claims', {
      campaign_id: challengeId, user_id: card.clientId, code: code('RTO'), status: chance(0.5) ? 'redeemed' : 'active',
      source: 'challenge_complete', created_at: ago(int(1, 4) * DAY),
    });
  }

  // Ruta del Sabor: pasaporte entre tres locales
  const routeBusinesses = ['aurora', 'fogon', 'espiga'];
  const routeId = await campaign('aurora', {
    type: 'route', title: 'Ruta del sabor', description: 'Visita los tres locales y llévate una cena para dos.',
    benefit: 'mini_prize', label: 'Cena para dos en El Fogón', stamps: 3, starts: ago(15 * DAY), ends: ahead(45 * DAY),
    businesses: routeBusinesses,
  }); campaignCount++;
  const routeUsers = clients.filter((c) =>
    routeBusinesses.some((k) => cards.some((card) => card.clientId === c.id && card.businessKey === k)),
  );
  let stamps = 0;
  let completed = 0;
  for (const client of routeUsers) {
    const mine = routeBusinesses.filter((k) => cards.some((c) => c.clientId === client.id && c.businessKey === k));
    const done = chance(0.2) && mine.length === 3 ? 3 : int(1, mine.length);
    for (const k of mine.slice(0, done)) {
      await db.insert('campaign_stamps', {
        campaign_id: routeId, user_id: client.id, business_id: businessIds.get(k), created_at: ago(int(1, 12) * DAY),
      });
      stamps++;
    }
    if (done === 3) {
      await db.insert('campaign_claims', {
        campaign_id: routeId, user_id: client.id, code: code('RUT'), status: chance(0.5) ? 'redeemed' : 'active',
        source: 'route_complete', created_at: ago(int(1, 5) * DAY),
      });
      completed++;
    }
  }
  console.log(`Campañas: ${campaignCount}, gift cards entregadas: ${claimsTotal}, sellos de ruta: ${stamps} (${completed} rutas completas)`);

  // ---- Minijuegos ----
  const games = ['tictactoe', 'hangman', 'flappy'];
  const GAME_LABELS: Record<string, string> = { tictactoe: 'Tres en raya', hangman: 'Ahorcado', flappy: 'Flappy Bird' };
  const untilLabel = (d: Date) =>
    d.toLocaleString('es-EC', {
      timeZone: 'America/Guayaquil', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false,
    });
  const prizeCampaigns: Record<string, string> = {};
  for (const game of games) {
    const title = { tictactoe: 'Tres en raya', hangman: 'Ahorcado', flappy: 'Flappy Bird' }[game]!;
    prizeCampaigns[game] = await campaign('aurora', {
      type: 'gift_card', title: `Premio: ${title}`, description: 'Premio de los minijuegos', hidden: true, benefit: 'discount_percent',
      value: 20, label: '20% de descuento', audience: 'selected', starts: ago(9 * DAY), ends: null, image: false,
    });
  }
  await db.insert('game_access', {
    business_id: businessIds.get('aurora'), owner_id: ownerIds.get('Aurora Zhunio'), status: 'approved',
    note: 'Quiero atraer más clientes los fines de semana', games, prize_type: 'discount_percent', prize_value: 20,
    prize_label: '20% de descuento', prize_campaigns: prizeCampaigns, requested_at: ago(10 * DAY),
    resolved_at: ago(9 * DAY), resolved_by_id: adminId,
  });
  await db.insert('game_access', {
    business_id: businessIds.get('filo'), owner_id: ownerIds.get('Filomeno Chávez'), status: 'pending',
    note: 'Para que los clientes jueguen mientras esperan su turno', requested_at: ago(4 * HOUR),
  });
  await db.insert('game_access', {
    business_id: businessIds.get('titan'), owner_id: ownerIds.get('Dario Titán'), status: 'rejected',
    admin_note: 'Primero completa la validación de tu pago de registro', requested_at: ago(6 * DAY),
    resolved_at: ago(5 * DAY), resolved_by_id: adminId,
  });

  const gameClients = shuffle(aurora).slice(0, 12);
  const states: Array<'upcoming' | 'sent' | 'retry' | 'won' | 'lost' | 'expired'> = [
    'sent', 'sent', 'sent', 'retry', 'retry', 'won', 'won', 'won', 'lost', 'expired', 'upcoming', 'upcoming',
  ];
  let invites = 0;
  for (const [i, userId] of gameClients.entries()) {
    const game = games[i % games.length];
    const state = states[i];
    const startsAt = state === 'upcoming' ? ahead(int(3, 30) * HOUR) : state === 'expired' ? ago(12 * DAY) : ago(int(1, 48) * HOUR);
    const expiresAt = state === 'expired' ? ago(5 * DAY) : new Date(startsAt.getTime() + 7 * DAY);
    let claimId: string | null = null;
    if (state === 'won') {
      claimId = await db.insert('campaign_claims', {
        campaign_id: prizeCampaigns[game], user_id: userId, code: code('GFT'), status: 'active', source: 'claim',
        created_at: ago(int(1, 24) * HOUR),
      });
    }
    await db.insert('game_invites', {
      business_id: businessIds.get('aurora'), user_id: userId, sent_by_id: ownerIds.get('Aurora Zhunio'), game,
      status: state === 'won' || state === 'lost' ? 'finished' : 'sent',
      result: state === 'won' ? 'won' : state === 'lost' ? 'lost' : null,
      score: game === 'flappy' && (state === 'won' || state === 'lost') ? (state === 'won' ? 10 : 4) : null,
      claim_id: claimId, starts_at: startsAt, expires_at: expiresAt,
      attempts: state === 'won' ? int(1, 3) : state === 'lost' ? 3 : state === 'retry' ? int(1, 2) : 0,
      notified_at: state === 'upcoming' ? null : startsAt,
      finished_at: state === 'won' || state === 'lost' ? ago(int(1, 20) * HOUR) : null,
      created_at: ago(int(2, 50) * HOUR),
    });
    invites++;
    if (state !== 'upcoming') {
      const name = BUSINESSES.find((b) => b.key === 'aurora')!.name;
      await db.insert('notifications', {
        user_id: userId, type: state === 'won' ? 'game_won' : 'game_invite',
        title: state === 'won' ? '¡Ganaste!' : `${name} te reta a jugar`,
        body:
          state === 'won'
            ? `Ganaste ${GAME_LABELS[game]} y tu premio es: 20% de descuento. Ábrelo en Mis regalos.`
            : `Juega ${GAME_LABELS[game]} y gana: 20% de descuento. Tienes 3 intentos hasta el ${untilLabel(expiresAt)}.`,
        data: { route: state === 'won' ? '/my_gifts' : '/play_game' }, read_at: chance(0.5) ? ago(HOUR) : null,
        created_at: ago(int(1, 40) * HOUR),
      });
    }
  }
  console.log(`Minijuegos: 3 solicitudes (aprobada, pendiente, rechazada) y ${invites} retos`);

  // ---- Notificaciones de uso diario ----
  let notificationCount = 0;
  for (const card of shuffle(cards).slice(0, 40)) {
    const b = BUSINESSES.find((x) => x.key === card.businessKey)!;
    await db.insert('notifications', {
      user_id: card.clientId, type: 'general', title: 'Punto aprobado',
      body: `Tu escaneo en ${b.name} fue aprobado.`,
      read_at: chance(0.7) ? ago(int(1, 5) * DAY) : null, created_at: ago(int(1, 15) * DAY),
    });
    notificationCount++;
  }
  for (const b of active) {
    const owner = ownerIds.get(b.owner)!;
    const pending = pendingScansPerBusiness.get(b.key) ?? 0;
    if (pending > 0) {
      await db.insert('notifications', {
        user_id: owner, type: 'general', title: 'Escaneo por aprobar',
        body: `${pick(clients).name} escaneo en ${b.name}. Apruebalo para sumarle el punto.`,
        read_at: null, created_at: ago(int(5, 120) * 60 * 1000),
      });
      notificationCount++;
    }
    await db.insert('notifications', {
      user_id: owner, type: 'business_activated', title: '¡Tu negocio fue activado!',
      body: `${b.name} ya está activo en Fidelity. Vuelve a iniciar sesión para empezar.`, read_at: ago(20 * DAY), created_at: ago(30 * DAY),
    });
    notificationCount++;
  }
  await db.insert('notifications', {
    user_id: ownerIds.get('Aurora Zhunio'), type: 'game_won_owner', title: '¡Un cliente ganó!',
    body: 'Camila Paz ganó Ahorcado.', read_at: null, created_at: ago(3 * HOUR),
  });
  const campaignPush = await db.all<{ id: string; title: string; business_id: string }>(
    `SELECT id, title, business_id FROM campaigns WHERE notified_at IS NOT NULL AND type <> 'route' AND NOT hidden AND cancelled_at IS NULL LIMIT 6`,
  );
  for (const c of campaignPush) {
    const owner = BUSINESSES.find((b) => businessIds.get(b.key) === c.business_id);
    const fans = cards.filter((card) => businessIds.get(card.businessKey) === c.business_id).slice(0, 6);
    for (const f of fans) {
      await db.insert('notifications', {
        user_id: f.clientId, type: 'campaign', title: `Novedades de ${owner?.name ?? 'tu local'}`,
        body: c.title, data: { route: '/' }, read_at: chance(0.4) ? ago(DAY) : null, created_at: ago(int(1, 6) * DAY),
      });
      notificationCount++;
    }
  }
  console.log(`Notificaciones: ${notificationCount}+`);

  // ---- Opiniones, sugerencias y soporte ----
  const opinions: Array<{ kind: string; rating: number | null; tags: string[]; message: string }> = [
    { kind: 'praise', rating: 5, tags: ['Atención', 'Rapidez'], message: 'Siempre me atienden con una sonrisa. ¡Gracias!' },
    { kind: 'praise', rating: 5, tags: ['Calidad'], message: 'El mejor café de la zona, sin duda.' },
    { kind: 'praise', rating: 4, tags: ['Limpieza'], message: 'Local limpio y ordenado.' },
    { kind: 'suggestion', rating: 4, tags: ['Variedad'], message: 'Estaría bien tener más opciones sin azúcar.' },
    { kind: 'suggestion', rating: 4, tags: ['Horarios'], message: '¿Podrían abrir un poco más temprano los sábados?' },
    { kind: 'suggestion', rating: null, tags: [], message: 'Me gustaría poder pagar con código QR.' },
    { kind: 'complaint', rating: 2, tags: ['Espera'], message: 'Esperé 25 minutos para que me atendieran.' },
    { kind: 'complaint', rating: 1, tags: ['Atención'], message: 'Me cobraron de más y no me devolvieron la diferencia.' },
    { kind: 'complaint', rating: 3, tags: ['Precio'], message: 'Subieron los precios sin avisar.' },
  ];
  let feedbacks = 0;
  for (const b of active) {
    const businessCards = cards.filter((c) => c.businessKey === b.key);
    for (const card of shuffle(businessCards).slice(0, int(2, 4))) {
      const o = pick(opinions);
      const answered = chance(0.5);
      const ownerId = ownerIds.get(b.owner)!;
      await db.insert('feedbacks', {
        user_id: card.clientId, business_id: businessIds.get(b.key), kind: o.kind, rating: o.rating, tags: o.tags,
        message: o.message, status: answered ? 'resolved' : 'open',
        reply: answered ? 'Gracias por escribirnos, lo tendremos en cuenta. ¡Te esperamos pronto!' : null,
        resolved_by_id: answered ? ownerId : null, resolved_at: answered ? ago(int(1, 5) * DAY) : null,
        created_at: ago(int(2, 25) * DAY),
      });
      feedbacks++;
    }
  }
  await db.insert('support_tickets', {
    user_id: clients[0].id, business_id: businessIds.get('aurora'), subject: 'No me llegó la notificación del premio',
    message: 'Hice mi escaneo hace dos días y todavía no veo mi punto en la tarjeta.', status: 'open', created_at: ago(DAY),
  });
  await db.insert('support_tickets', {
    user_id: ownerIds.get('Filomeno Chávez')!, subject: '¿Cómo cambio el logo de mi negocio?',
    message: 'Quiero subir un logo nuevo pero no encuentro la opción.', status: 'resolved', created_at: ago(8 * DAY),
  });
  console.log(`Opiniones: ${feedbacks}, tickets de soporte: 2`);

  console.log('\nListo. Cuentas de demostración (misma clave para todas: DEMO_PASSWORD en este archivo):');
  console.log(`  Dueño:      ${email('Aurora Zhunio')}`);
  console.log(`  Dueño:      ${email('Filomeno Chávez')}`);
  console.log(`  Aprobador:  ${email('Josué Ramos')}`);
  console.log(`  Cliente:    ${email(clients[0].name)}  (y ${clients.length - 1} más)`);
}

async function main() {
  assertLocal();
  const client = new Client({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT ?? '5432', 10),
    user: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_DATABASE || 'fidelity_db',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  });
  await client.connect();
  const db = new Db(client);
  const args = process.argv.slice(2);
  try {
    await db.run('BEGIN');
    if (args.includes('--reset') || args.includes('--clean')) await clean(db);
    if (!args.includes('--clean')) await seed(db);
    await db.run('COMMIT');
  } catch (error) {
    await db.run('ROLLBACK');
    throw error;
  } finally {
    await client.end();
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('No se pudo sembrar los datos de demostración:', error.message);
    process.exit(1);
  });

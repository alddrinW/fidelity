/**
 * Crea (o renueva la clave de) la cuenta de administrador.
 *
 *   npm run seed:admin                       crea el administrador si no existe
 *   npm run seed:admin -- --rotate           le pone una clave nueva al que ya existe
 *
 * Variables opcionales: ADMIN_EMAIL (por defecto admin@fidelity.com), ADMIN_NAME
 * y ADMIN_PASSWORD. Sin ADMIN_PASSWORD se genera una clave fuerte al azar y se
 * muestra **una sola vez** en esta pantalla: guárdala en tu gestor de claves.
 *
 * Nunca hay una clave por defecto, y si el administrador ya existe no se le
 * toca la clave a menos que se pida con --rotate.
 */
import { randomInt } from 'crypto';
import * as bcrypt from 'bcrypt';
import { AppDataSource } from '../../config/data-source';
import { Profile, UserRole } from '../entities/profile.entity';
import { passwordProblem } from '../../common/validators/strong-password';

/** Sin letras que se confunden (0/O, 1/l/I) para poder copiarla a mano. */
const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';
const DIGITS = '23456789';
const SYMBOLS = '!#$%*+-=?@';

/** Una clave fuerte al azar: 18 caracteres con letras, números y símbolos. */
export function generatePassword(length = 18): string {
  const all = LETTERS + DIGITS + SYMBOLS;
  const pick = (set: string) => set[randomInt(set.length)];
  const chars = [pick(LETTERS), pick(LETTERS), pick(DIGITS), pick(DIGITS), pick(SYMBOLS)];
  while (chars.length < length) chars.push(pick(all));
  // Mezcla (Fisher-Yates) para que las obligatorias no queden siempre al inicio.
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}

async function seedAdmin() {
  const email = (process.env.ADMIN_EMAIL || 'admin@fidelity.com').toLowerCase().trim();
  const fullName = process.env.ADMIN_NAME || 'Administrador Fidelity';
  const rotate = process.argv.includes('--rotate');

  const provided = process.env.ADMIN_PASSWORD;
  if (provided) {
    const problem = passwordProblem(provided);
    if (problem) throw new Error(`ADMIN_PASSWORD no sirve: ${problem}`);
  }

  console.log('Inicializando conexion a la base de datos...');
  await AppDataSource.initialize();
  const profileRepository = AppDataSource.getRepository(Profile);
  const existing = await profileRepository.findOne({ where: { email } });

  if (existing && !rotate) {
    // Aseguramos el rol, pero no se toca la clave.
    if (existing.role !== UserRole.ADMIN) {
      existing.role = UserRole.ADMIN;
      await profileRepository.save(existing);
      console.log(`${email} ahora es administrador (su clave no se cambió).`);
    } else {
      console.log(`El administrador ${email} ya existe: no se cambió nada. Para ponerle una clave nueva usa --rotate.`);
    }
    await AppDataSource.destroy();
    return;
  }

  const password = provided || generatePassword();
  const passwordHash = await bcrypt.hash(password, 10);

  if (existing) {
    existing.fullName = fullName;
    existing.role = UserRole.ADMIN;
    existing.passwordHash = passwordHash;
    await profileRepository.save(existing);
    console.log(`Clave del administrador renovada: ${email}`);
  } else {
    await profileRepository.save(
      profileRepository.create({ email, fullName, role: UserRole.ADMIN, passwordHash, isDemo: false }),
    );
    console.log(`Administrador creado: ${email}`);
  }

  if (!provided) {
    console.log('\n==================================================');
    console.log(' Clave generada (se muestra UNA SOLA VEZ, guárdala):');
    console.log(`   ${password}`);
    console.log('==================================================\n');
  }
  await AppDataSource.destroy();
}

if (require.main === module) {
  seedAdmin()
    .then(() => {
      console.log('Proceso de seed completado.');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Error al ejecutar el seed de administrador:', error.message);
      process.exit(1);
    });
}

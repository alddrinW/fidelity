import { AppDataSource } from '../../config/data-source';
import { Profile, UserRole } from '../entities/profile.entity';
import * as bcrypt from 'bcrypt';

async function seedAdmin() {
  const email = 'admin@fidelity.com';
  const password = 'hola123';
  const fullName = 'Administrador Fidelity';

  console.log('Inicializando conexion a la base de datos...');
  await AppDataSource.initialize();

  const profileRepository = AppDataSource.getRepository(Profile);

  const existingAdmin = await profileRepository.findOne({
    where: { email: email.toLowerCase().trim() },
  });

  const salt = await bcrypt.genSalt(10);
  const passwordHash = await bcrypt.hash(password, salt);

  if (existingAdmin) {
    existingAdmin.fullName = fullName;
    existingAdmin.role = UserRole.ADMIN;
    existingAdmin.passwordHash = passwordHash;
    await profileRepository.save(existingAdmin);
    console.log(`Usuario administrador actualizado con exito: ${email}`);
  } else {
    const adminProfile = profileRepository.create({
      email: email.toLowerCase().trim(),
      fullName,
      role: UserRole.ADMIN,
      passwordHash,
      isDemo: false,
    });
    await profileRepository.save(adminProfile);
    console.log(`Usuario administrador creado con exito: ${email}`);
  }

  await AppDataSource.destroy();
}

seedAdmin()
  .then(() => {
    console.log('Proceso de seed completado.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error al ejecutar el seed de administrador:', error);
    process.exit(1);
  });

"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const data_source_1 = require("../../config/data-source");
const profile_entity_1 = require("../entities/profile.entity");
const bcrypt = require("bcrypt");
async function seedAdmin() {
    const email = 'admin@fidelity.com';
    const password = 'hola123';
    const fullName = 'Administrador Fidelity';
    console.log('Inicializando conexion a la base de datos...');
    await data_source_1.AppDataSource.initialize();
    const profileRepository = data_source_1.AppDataSource.getRepository(profile_entity_1.Profile);
    const existingAdmin = await profileRepository.findOne({
        where: { email: email.toLowerCase().trim() },
    });
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);
    if (existingAdmin) {
        existingAdmin.fullName = fullName;
        existingAdmin.role = profile_entity_1.UserRole.ADMIN;
        existingAdmin.passwordHash = passwordHash;
        await profileRepository.save(existingAdmin);
        console.log(`Usuario administrador actualizado con exito: ${email}`);
    }
    else {
        const adminProfile = profileRepository.create({
            email: email.toLowerCase().trim(),
            fullName,
            role: profile_entity_1.UserRole.ADMIN,
            passwordHash,
            isDemo: false,
        });
        await profileRepository.save(adminProfile);
        console.log(`Usuario administrador creado con exito: ${email}`);
    }
    await data_source_1.AppDataSource.destroy();
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
//# sourceMappingURL=create-admin.js.map
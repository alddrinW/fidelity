import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateBusinessDto, UpdateBusinessDto } from './businesses.dto';

async function errorsFor<T extends object>(cls: new () => T, data: object) {
  const errors = await validate(plainToInstance(cls, data));
  return errors.map((e) => e.property);
}

describe('Business DTOs', () => {
  it('acepta cedula de 10 digitos y RUC de 13 digitos', async () => {
    expect(await errorsFor(UpdateBusinessDto, { taxId: '1712345678' })).toEqual([]);
    expect(await errorsFor(UpdateBusinessDto, { taxId: '1712345678001' })).toEqual([]);
  });

  it('rechaza identificaciones con otra longitud o con letras', async () => {
    expect(await errorsFor(UpdateBusinessDto, { taxId: '12345' })).toEqual(['taxId']);
    expect(await errorsFor(UpdateBusinessDto, { taxId: '171234567A' })).toEqual(['taxId']);
    expect(await errorsFor(CreateBusinessDto, { name: 'Cafe', taxId: '17123456789' })).toEqual([
      'taxId',
    ]);
  });

  it('taxId y descripcion larga son opcionales', async () => {
    expect(await errorsFor(CreateBusinessDto, { name: 'Cafe' })).toEqual([]);
    expect(
      await errorsFor(CreateBusinessDto, { name: 'Cafe', rewardLongDescription: 'Detalle' }),
    ).toEqual([]);
  });

  it('el logo debe ser una imagen valida', async () => {
    expect(
      await errorsFor(UpdateBusinessDto, { logoUrl: 'data:image/png;base64,iVBORw0KGgo=' }),
    ).toEqual([]);
    expect(await errorsFor(UpdateBusinessDto, { logoUrl: 'javascript:alert(1)' })).toEqual([
      'logoUrl',
    ]);
  });
});

import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDate,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  IsUrl,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { BANNER_ACTIONS, BannerAction } from '../../../database/entities/banner.entity';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

const LINK_MESSAGE = 'El enlace debe empezar con http:// o https://';

export class CreateBannerDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title: string;

  @IsString()
  @IsNotEmpty({ message: 'Sube la imagen del banner' })
  @IsImageSource()
  imageUrl: string;

  /** La versión en inglés (vacía = se usa la principal). */
  @IsOptional()
  @IsImageSource()
  imageUrlEn?: string;

  @IsOptional()
  @IsIn(BANNER_ACTIONS as unknown as string[])
  action?: BannerAction;

  @ValidateIf((o) => o.linkUrl !== undefined && o.linkUrl !== '')
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true }, { message: LINK_MESSAGE })
  @MaxLength(500)
  linkUrl?: string;

  @IsOptional()
  @IsBoolean()
  blendWhite?: boolean;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  startsAt?: Date | null;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  endsAt?: Date | null;
}

export class UpdateBannerDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty({ message: 'La imagen del banner no puede quedar vacía' })
  @IsImageSource()
  imageUrl?: string;

  @IsOptional()
  @IsImageSource()
  imageUrlEn?: string;

  @IsOptional()
  @IsIn(BANNER_ACTIONS as unknown as string[])
  action?: BannerAction;

  @ValidateIf((o) => o.linkUrl !== undefined && o.linkUrl !== '')
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true }, { message: LINK_MESSAGE })
  @MaxLength(500)
  linkUrl?: string;

  @IsOptional()
  @IsBoolean()
  blendWhite?: boolean;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  startsAt?: Date | null;

  @IsOptional()
  @Type(() => Date)
  @IsDate()
  endsAt?: Date | null;
}

/** El orden nuevo: los id de todos los banners, del primero al último. */
export class ReorderBannersDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @IsUUID('all', { each: true })
  ids: string[];
}

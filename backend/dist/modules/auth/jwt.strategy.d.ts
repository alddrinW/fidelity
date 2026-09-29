import { Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { Profile } from '../../database/entities/profile.entity';
import { JwtPayload, AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
declare const JwtStrategy_base: new (...args: any[]) => Strategy;
export declare class JwtStrategy extends JwtStrategy_base {
    private readonly configService;
    private readonly profileRepository;
    constructor(configService: ConfigService, profileRepository: Repository<Profile>);
    validate(payload: JwtPayload): Promise<AuthenticatedUser>;
}
export {};

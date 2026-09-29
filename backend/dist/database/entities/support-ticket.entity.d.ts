import { Profile } from './profile.entity';
import { Business } from './business.entity';
export declare class SupportTicket {
    id: string;
    userId: string;
    user: Profile;
    businessId: string;
    business: Business;
    subject: string;
    message: string;
    status: string;
    createdAt: Date;
}

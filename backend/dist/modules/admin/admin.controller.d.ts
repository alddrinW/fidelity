import { AdminService } from './admin.service';
import { UserRole } from '../../database/entities/profile.entity';
export declare class AdminController {
    private readonly adminService;
    constructor(adminService: AdminService);
    getStats(): Promise<{
        users: {
            total: number;
            clients: number;
            businessOwners: number;
            admins: number;
        };
        businesses: {
            total: number;
            active: number;
            inactive: number;
        };
        scans: {
            total: number;
            approved: number;
            pending: number;
        };
        rewards: {
            total: number;
            pending: number;
            claimed: number;
        };
        transfers: {
            total: number;
        };
    }>;
    getUsers(role?: UserRole, search?: string): Promise<import("../../database/entities/profile.entity").Profile[]>;
    getActivity(limit?: string, businessId?: string, startDate?: string, endDate?: string): Promise<import("../../database/entities").Scan[]>;
    getQrStats(startDate?: string, endDate?: string): Promise<import("../../database/entities").Scan[]>;
    getRewards(businessId?: string, startDate?: string, endDate?: string): Promise<import("../../database/entities").Reward[]>;
    updateUserRole(userId: string, role: UserRole): Promise<import("../../database/entities/profile.entity").Profile>;
}

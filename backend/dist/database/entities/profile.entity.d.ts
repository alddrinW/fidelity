export declare enum UserRole {
    ADMIN = "admin",
    BUSINESS = "business",
    CLIENT = "client"
}
export declare class Profile {
    id: string;
    email: string;
    fullName: string;
    role: UserRole;
    passwordHash: string;
    fcmToken: string;
    avatarUrl: string;
    phone: string;
    isDemo: boolean;
    createdAt: Date;
    updatedAt: Date;
}

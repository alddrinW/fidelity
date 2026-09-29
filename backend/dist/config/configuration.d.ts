export declare const configuration: () => {
    port: number;
    nodeEnv: string;
    apiPrefix: string;
    corsOrigin: string;
    database: {
        host: string;
        port: number;
        username: string;
        password: string;
        database: string;
        ssl: boolean | {
            rejectUnauthorized: boolean;
        };
        synchronize: boolean;
    };
    jwt: {
        secret: string;
        expiresIn: string;
    };
    firebase: {
        serviceAccount: string;
        credentialsPath: string;
    };
    webhookSecret: string;
};

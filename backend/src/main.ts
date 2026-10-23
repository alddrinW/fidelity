import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { assertProductionSecrets } from './config/secrets';
import { AllExceptionsFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const logger = new Logger('FidelityBackend');
  // En producción no se arranca con las claves de ejemplo.
  assertProductionSecrets();
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Las imagenes de perfil y logo viajan como data URI base64 (hasta ~1 MB).
  // El limite por defecto de Express (100 kb) las rechazaria.
  app.useBodyParser('json', { limit: '2mb' });
  app.useBodyParser('urlencoded', { limit: '2mb', extended: true });

  const configService = app.get(ConfigService);

  // Detrás de un proxy (Nginx, un balanceador) la IP del cliente viene en un
  // encabezado: sin esto, todos parecerían la misma persona para el límite de intentos.
  const trustProxy = configService.get<string>('rateLimit.trustProxy');
  if (trustProxy) {
    app.set('trust proxy', /^\d+$/.test(trustProxy) ? Number(trustProxy) : trustProxy === 'true' ? true : trustProxy);
  }
  const port = configService.get<number>('port') || 3000;
  const apiPrefix = configService.get<string>('apiPrefix') || 'api/v1';
  const corsOrigin = configService.get<string>('corsOrigin') || '*';

  // Global Prefix
  app.setGlobalPrefix(apiPrefix);

  // CORS
  app.enableCors({
    origin: corsOrigin,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // Global Validation Pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Global Filters & Interceptors
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(new TransformInterceptor());

  // Swagger OpenAPI Documentation
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Fidelity API')
    .setDescription('Especificacion REST API del backend Fidelity (NestJS, Express & PostgreSQL)')
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(port);
  logger.log(`Fidelity Backend API running on port ${port} with prefix /${apiPrefix}`);
  logger.log(`Swagger OpenAPI documentation available at http://localhost:${port}/api/docs`);
}

bootstrap();

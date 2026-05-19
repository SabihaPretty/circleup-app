import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';
import * as express from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: true,
    credentials: true,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    allowedHeaders: 'Content-Type, Authorization',
  });

  app.use('/uploads', express.static(join(process.cwd(), 'uploads')));

  const port = Number(process.env.PORT) || 5000;

  await app.listen(port, '0.0.0.0');

  console.log(`CircleUp backend is running on port ${port}`);
}

bootstrap();

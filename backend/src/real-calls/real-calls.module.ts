import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { RealCallsController } from './real-calls.controller';
import { RealCallsService } from './real-calls.service';

@Module({
  imports: [PrismaModule],
  controllers: [RealCallsController],
  providers: [RealCallsService],
})
export class RealCallsModule {}

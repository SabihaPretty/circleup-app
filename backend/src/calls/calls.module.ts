import { Module } from '@nestjs/common';
import { CallsGateway } from './calls.gateway';

@Module({
  providers: [CallsGateway],
})
export class CallsModule {}

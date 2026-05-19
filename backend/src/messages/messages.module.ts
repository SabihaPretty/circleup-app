import { Module } from '@nestjs/common';
import { ConnectionsModule } from '../connections/connections.module';
import { SafetyModule } from '../safety/safety.module';
import { MessagesController } from './messages.controller';
import { MessagesGateway } from './messages.gateway';
import { MessagesService } from './messages.service';

@Module({
  imports: [ConnectionsModule, SafetyModule],
  controllers: [MessagesController],
  providers: [MessagesService, MessagesGateway],
})
export class MessagesModule {}

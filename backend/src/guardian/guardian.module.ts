import { Module } from '@nestjs/common';
import { GuardianController } from './guardian.controller';
import { GuardianService } from './guardian.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [GuardianController],
  providers: [GuardianService],
  exports: [GuardianService],
})
export class GuardianModule {}

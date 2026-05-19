import { Module } from '@nestjs/common';
import { GroupsController } from './groups.controller';
import { GroupsGateway } from './groups.gateway';
import { GroupsService } from './groups.service';

@Module({
  controllers: [GroupsController],
  providers: [GroupsService, GroupsGateway],
})
export class GroupsModule {}

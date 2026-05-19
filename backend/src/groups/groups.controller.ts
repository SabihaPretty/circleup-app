import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { GroupsService } from './groups.service';

@Controller('groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Post()
  createGroup(@Body() body: any) {
    return this.groupsService.createGroup(body);
  }

  @Get('my/:userId')
  myGroups(@Param('userId') userId: string) {
    return this.groupsService.myGroups(Number(userId));
  }

  @Post('add-member')
  addMember(@Body() body: any) {
    return this.groupsService.addMember(body);
  }

  @Get(':groupId/messages')
  getMessages(@Param('groupId') groupId: string) {
    return this.groupsService.getMessages(Number(groupId));
  }

  @Post(':groupId/messages')
  sendMessage(@Param('groupId') groupId: string, @Body() body: any) {
    return this.groupsService.sendMessage({
      ...body,
      groupId: Number(groupId),
    });
  }
}

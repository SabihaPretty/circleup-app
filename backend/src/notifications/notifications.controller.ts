import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Post('create')
  create(@Body() body: any) {
    return this.notificationsService.createNotification(body);
  }

  @Get('user/:userId')
  getUserNotifications(@Param('userId') userId: string) {
    return this.notificationsService.getUserNotifications(Number(userId));
  }

  @Get('unread/:userId')
  getUnreadCount(@Param('userId') userId: string) {
    return this.notificationsService.getUnreadCount(Number(userId));
  }

  @Post(':notificationId/read')
  markOneRead(
    @Param('notificationId') notificationId: string,
    @Query('userId') userId: string,
  ) {
    return this.notificationsService.markOneRead(
      Number(notificationId),
      Number(userId),
    );
  }

  @Post('read-all/:userId')
  markAllRead(@Param('userId') userId: string) {
    return this.notificationsService.markAllRead(Number(userId));
  }
}

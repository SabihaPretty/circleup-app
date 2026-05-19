import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { SafetyService } from './safety.service';

@Controller('safety')
export class SafetyController {
  constructor(private readonly safetyService: SafetyService) {}

  @Post('reports/create')
  createReport(@Body() body: any) {
    return this.safetyService.createReport(body);
  }

  @Get('reports/my/:userId')
  getMyReports(@Param('userId') userId: string) {
    return this.safetyService.getMyReports(Number(userId));
  }

  @Get('reports/admin')
  getAdminReports(@Query('status') status: string) {
    return this.safetyService.getAdminReports(status || 'all');
  }

  @Post('reports/:reportId/review')
  reviewReport(@Param('reportId') reportId: string, @Body() body: any) {
    return this.safetyService.reviewReport(Number(reportId), body);
  }

  @Post('block')
  blockUser(@Body() body: any) {
    return this.safetyService.blockUser(body);
  }

  @Post('unblock')
  unblockUser(@Body() body: any) {
    return this.safetyService.unblockUser(body);
  }

  @Get('blocked/:userId')
  getBlockedUsers(@Param('userId') userId: string) {
    return this.safetyService.getBlockedUsers(Number(userId));
  }

  @Get('summary/:userId')
  getSummary(@Param('userId') userId: string) {
    return this.safetyService.getSafetySummary(Number(userId));
  }
}

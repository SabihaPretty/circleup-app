import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { GuardianService } from './guardian.service';

@Controller('guardian')
export class GuardianController {
  constructor(private readonly guardianService: GuardianService) {}

  @Post('invite/create')
  createGuardianInvite(@Body() body: any) {
    return this.guardianService.createGuardianInvite(body);
  }

  @Post('connect-by-code')
  connectByCode(@Body() body: any) {
    return this.guardianService.connectByCode(body);
  }

  @Get('user/:userId')
  getGuardianLinks(@Param('userId') userId: string) {
    return this.guardianService.getGuardianLinks(Number(userId));
  }

  @Post('links/:linkId/remove')
  removeGuardianLink(@Param('linkId') linkId: string, @Body() body: any) {
    return this.guardianService.removeGuardianLink(
      Number(linkId),
      Number(body.userId),
    );
  }
}

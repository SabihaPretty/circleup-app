import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { SettingsService } from './settings.service';

@Controller('settings')
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get(':userId')
  getSettings(@Param('userId') userId: string) {
    return this.settingsService.getSettings(Number(userId));
  }

  @Post('update')
  updateSettings(@Body() body: any) {
    return this.settingsService.updateSettings(body);
  }
}

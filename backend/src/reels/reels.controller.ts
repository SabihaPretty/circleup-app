import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ReelsService } from './reels.service';

@Controller('reels')
export class ReelsController {
  constructor(private readonly reelsService: ReelsService) {}

  @Post('create')
  create(@Body() body: any) {
    return this.reelsService.createReel(body);
  }

  @Get()
  getReels(
    @Query('ageGroup') ageGroup: string,
    @Query('circleId') circleId: string,
    @Query('category') category: string,
  ) {
    return this.reelsService.getReels(
      ageGroup || 'adult',
      circleId,
      category || 'all',
    );
  }
}

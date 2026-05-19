import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { NicknamesService } from './nicknames.service';

@Controller('nicknames')
export class NicknamesController {
  constructor(private readonly nicknamesService: NicknamesService) {}

  @Post('set')
  setNickname(@Body() body: any) {
    return this.nicknamesService.setNickname(body);
  }

  @Get('user/:ownerId')
  myNicknames(@Param('ownerId') ownerId: string) {
    return this.nicknamesService.myNicknames(Number(ownerId));
  }
}

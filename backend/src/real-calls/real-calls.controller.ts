import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { RealCallsService } from './real-calls.service';

@Controller('real-calls')
export class RealCallsController {
  constructor(private readonly realCallsService: RealCallsService) {}

  @Post('start')
  startCall(@Body() body: any) {
    return this.realCallsService.startCall(body);
  }

  @Get('incoming/:userId')
  incoming(@Param('userId') userId: string) {
    return this.realCallsService.incoming(Number(userId));
  }

  @Post('accept')
  accept(@Body() body: any) {
    return this.realCallsService.acceptCall(body);
  }

  @Post('reject')
  reject(@Body() body: any) {
    return this.realCallsService.rejectCall(body);
  }

  @Post('end')
  end(@Body() body: any) {
    return this.realCallsService.endCall(body);
  }

  @Post('token')
  token(@Body() body: any) {
    return this.realCallsService.token(body);
  }
}

import { Body, Controller, Post } from '@nestjs/common';
import { CallsService } from './calls.service';

@Controller('calls')
export class CallsController {
  constructor(private readonly callsService: CallsService) {}

  @Post('start')
  start(@Body() body: any) {
    return this.callsService.startCall(body);
  }
}

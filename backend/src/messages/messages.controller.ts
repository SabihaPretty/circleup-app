import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { MessagesService } from './messages.service';

@Controller('messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Post('send')
  send(@Body() body: any) {
    return this.messagesService.sendMessage(body);
  }

  @Get()
  get(@Query('conversation') conversation: string) {
    return this.messagesService.getMessages(conversation);
  }
}

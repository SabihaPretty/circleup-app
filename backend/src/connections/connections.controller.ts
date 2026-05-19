import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ConnectionsService } from './connections.service';

@Controller('connections')
export class ConnectionsController {
  constructor(private readonly connectionsService: ConnectionsService) {}

  @Get('suggestions/:userId')
  getSuggestions(@Param('userId') userId: string) {
    return this.connectionsService.getSuggestions(Number(userId));
  }

  @Get('user/:userId')
  getUserConnections(@Param('userId') userId: string) {
    return this.connectionsService.getUserConnections(Number(userId));
  }

  @Post('request')
  sendRequest(@Body() body: any) {
    return this.connectionsService.sendRequest(
      Number(body.requesterId),
      Number(body.receiverId),
    );
  }

  @Post(':connectionId/respond')
  respond(@Param('connectionId') connectionId: string, @Body() body: any) {
    return this.connectionsService.respond(
      Number(connectionId),
      Number(body.userId),
      body.status,
    );
  }

  @Post(':connectionId/block')
  block(@Param('connectionId') connectionId: string, @Body() body: any) {
    return this.connectionsService.blockConnection(
      Number(connectionId),
      Number(body.userId),
    );
  }
}

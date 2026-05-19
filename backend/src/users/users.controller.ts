import { Body, Controller, Get, Post } from '@nestjs/common';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register')
  register(@Body() body: any) {
    return this.usersService.createUser(body);
  }

  @Post('creator-mode')
  updateCreatorMode(@Body() body: any) {
    return this.usersService.updateCreatorMode(body);
  }

  @Get()
  getAll() {
    return this.usersService.getAllUsers();
  }
}

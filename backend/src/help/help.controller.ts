import { Body, Controller, Get, Post } from '@nestjs/common';
import { HelpService } from './help.service';

@Controller('help')
export class HelpController {
  constructor(private readonly helpService: HelpService) {}

  @Post('create')
  create(@Body() body: any) {
    return this.helpService.createHelpPost(body);
  }

  @Get()
  getAll() {
    return this.helpService.getAllHelpPosts();
  }
}

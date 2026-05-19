import { Body, Controller, Get, Post } from '@nestjs/common';
import { CirclesService } from './circles.service';

@Controller('circles')
export class CirclesController {
  constructor(private readonly circlesService: CirclesService) {}

  @Post('create')
  create(@Body() body: any) {
    return this.circlesService.createCircle(body);
  }

  @Get()
  getAll() {
    return this.circlesService.getAllCircles();
  }
}

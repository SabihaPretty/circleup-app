import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { StoriesService } from './stories.service';

@Controller('stories')
export class StoriesController {
  constructor(private readonly storiesService: StoriesService) {}

  @Post()
  createStory(@Body() body: any) {
    return this.storiesService.createStory(body);
  }

  @Get()
  getStories(@Query() query: any) {
    return this.storiesService.getStories(query);
  }
}

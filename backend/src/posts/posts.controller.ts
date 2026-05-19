import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PostsService } from './posts.service';

@Controller('posts')
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Post('create')
  createPost(@Body() body: any) {
    return this.postsService.createPost(body);
  }

  @Get('smart')
  getSmartPosts(@Query() query: any) {
    return this.postsService.getSmartPosts(query);
  }

  @Get()
  getAllPosts() {
    return this.postsService.getAllPosts();
  }
}

import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { InteractionsService } from './interactions.service';

@Controller('interactions')
export class InteractionsController {
  constructor(private readonly interactionsService: InteractionsService) {}

  @Post('posts/:postId/reaction')
  reactToPost(@Param('postId') postId: string, @Body() body: any) {
    return this.interactionsService.reactToPost(
      Number(postId),
      Number(body.userId),
      body.reactionType || 'boost',
    );
  }

  @Post('posts/:postId/boost')
  boostPost(@Param('postId') postId: string, @Body() body: any) {
    return this.interactionsService.togglePostBoost(
      Number(postId),
      Number(body.userId),
    );
  }

  @Post('posts/:postId/thoughts')
  addThought(@Param('postId') postId: string, @Body() body: any) {
    return this.interactionsService.addThought(
      Number(postId),
      Number(body.userId),
      body.content,
      body.mediaType,
      body.mediaUrl,
    );
  }

  @Get('posts/:postId/thoughts')
  getThoughts(@Param('postId') postId: string) {
    return this.interactionsService.getThoughts(Number(postId));
  }
}

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class InteractionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private buildReactionCounts(likes: any[]) {
    const counts: Record<string, number> = {
      boost: 0,
      support: 0,
      useful: 0,
      trend: 0,
      help: 0,
      concern: 0,
      angry: 0,
    };

    for (const like of likes || []) {
      const type = like.reactionType || 'boost';
      counts[type] = (counts[type] || 0) + 1;
    }

    return counts;
  }

  private reactionLabel(type: string) {
    const labels: Record<string, string> = {
      boost: 'boosted',
      support: 'supported',
      useful: 'marked useful',
      trend: 'trended',
      help: 'asked help on',
      concern: 'marked concern on',
      angry: 'reacted angry to',
    };

    return labels[type] || 'reacted to';
  }

  async reactToPost(postId: number, userId: number, reactionType: string) {
    const allowed = ['boost', 'support', 'useful', 'trend', 'help', 'concern', 'angry'];
    const cleanReaction = allowed.includes(reactionType) ? reactionType : 'boost';

    const existing = await this.prisma.like.findUnique({
      where: {
        userId_postId: {
          userId,
          postId,
        },
      },
    });

    let active = true;

    if (existing && existing.reactionType === cleanReaction) {
      await this.prisma.like.delete({
        where: { id: existing.id },
      });
      active = false;
    } else if (existing) {
      await this.prisma.like.update({
        where: { id: existing.id },
        data: { reactionType: cleanReaction },
      });
    } else {
      await this.prisma.like.create({
        data: {
          userId,
          postId,
          reactionType: cleanReaction,
        },
      });
    }

    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    const sender = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
      },
    });

    if (active && post && sender && post.userId !== userId) {
      await this.notificationsService.createNotification({
        type: 'reaction',
        title: 'New reaction on your post',
        message: `${sender.name} ${this.reactionLabel(cleanReaction)} your post`,
        targetType: 'post',
        targetId: postId,
        recipientId: post.userId,
        senderId: userId,
      });
    }

    const likes = await this.prisma.like.findMany({
      where: { postId },
      select: { reactionType: true },
    });

    const thoughtsCount = await this.prisma.comment.count({
      where: { postId },
    });

    return {
      success: true,
      active,
      postId,
      reactionType: cleanReaction,
      reactionsTotal: likes.length,
      thoughtsCount,
      reactionCounts: this.buildReactionCounts(likes),
      message: active ? 'Reaction added' : 'Reaction removed',
    };
  }

  async togglePostBoost(postId: number, userId: number) {
    return this.reactToPost(postId, userId, 'boost');
  }

  async addThought(
    postId: number,
    userId: number,
    content: string,
    mediaType?: string,
    mediaUrl?: string,
  ) {
    const comment = await this.prisma.comment.create({
      data: {
        postId,
        userId,
        content,
        mediaType: mediaType || 'text',
        mediaUrl: mediaUrl || null,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            ageGroup: true,
            profilePic: true,
          },
        },
        post: {
          select: {
            id: true,
            userId: true,
          },
        },
      },
    });

    if (comment.post.userId !== userId) {
      await this.notificationsService.createNotification({
        type: 'thought',
        title: 'New helpful thought',
        message: `${comment.user.name} added a thought on your post`,
        targetType: 'post',
        targetId: postId,
        recipientId: comment.post.userId,
        senderId: userId,
      });
    }

    const count = await this.prisma.comment.count({
      where: { postId },
    });

    return {
      success: true,
      message: 'Thought added',
      thought: comment,
      thoughtsCount: count,
    };
  }

  async getThoughts(postId: number) {
    return this.prisma.comment.findMany({
      where: { postId },
      orderBy: { createdAt: 'asc' },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            ageGroup: true,
            profilePic: true,
          },
        },
      },
    });
  }
}

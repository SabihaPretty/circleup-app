import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PostsService {
  constructor(private readonly prisma: PrismaService) {}

  private userSelect() {
    return {
      id: true,
      name: true,
      nickname: true,
      email: true,
      phone: true,
      ageGroup: true,
      profilePic: true,
      trustScore: true,
      accountMode: true,
      createdAt: true,
    };
  }

  private async getOrCreateDefaultCircle(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    let circle = await this.prisma.circle.findFirst({
      where: {
        name: 'Public Circle',
        type: 'public',
      },
    });

    if (!circle) {
      circle = await this.prisma.circle.create({
        data: {
          name: 'Public Circle',
          type: 'public',
          members: {
            connect: {
              id: userId,
            },
          },
        },
      });
    } else {
      try {
        await this.prisma.circle.update({
          where: { id: circle.id },
          data: {
            members: {
              connect: {
                id: userId,
              },
            },
          },
        });
      } catch (_) {}
    }

    return circle.id;
  }

  async createPost(data: any) {
    const userId = Number(data.userId);
    const content = String(data.content || '').trim();
    const mediaUrl = data.mediaUrl || null;
    const mediaType = data.mediaType || (mediaUrl ? 'file' : 'text');

    if (!userId) {
      throw new BadRequestException('User ID is required.');
    }

    if (!content && !mediaUrl) {
      throw new BadRequestException('Write something or upload a file.');
    }

    const circleId = Number(data.circleId) || (await this.getOrCreateDefaultCircle(userId));

    const post = await this.prisma.post.create({
      data: {
        userId,
        circleId,
        content: content || '',
        mediaUrl,
        mediaType,
      },
      include: {
        user: {
          select: this.userSelect(),
        },
        circle: true,
        likes: true,
        comments: {
          include: {
            user: {
              select: this.userSelect(),
            },
          },
        },
      },
    });

    return {
      success: true,
      message: 'Post created successfully.',
      data: post,
    };
  }

  async getSmartPosts(query: any) {
    const posts = await this.prisma.post.findMany({
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        user: {
          select: this.userSelect(),
        },
        circle: true,
        likes: true,
        comments: {
          include: {
            user: {
              select: this.userSelect(),
            },
          },
        },
      },
    });

    return {
      success: true,
      total: posts.length,
      data: posts,
    };
  }

  async getAllPosts() {
    return this.getSmartPosts({});
  }
}

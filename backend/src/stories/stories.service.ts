import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StoriesService {
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

  async createStory(data: any) {
    const userId = Number(data.userId);
    const caption = String(data.caption || '').trim();
    const mediaUrl = data.mediaUrl || null;
    const mediaType = data.mediaType || (mediaUrl ? 'file' : 'text');
    const ageGroup = data.ageGroup || 'adult';
    const durationHours = Number(data.durationHours) || 24;

    if (!userId) {
      throw new BadRequestException('User ID is required.');
    }

    if (!caption && !mediaUrl) {
      throw new BadRequestException('Write a caption or upload photo/video/file.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const expiresAt = new Date(Date.now() + durationHours * 60 * 60 * 1000);

    const story = await this.prisma.story.create({
      data: {
        userId,
        caption,
        mediaUrl,
        mediaType,
        ageGroup,
        expiresAt,
      },
      include: {
        user: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      message: 'Story created successfully.',
      data: story,
    };
  }

  async getStories(query: any) {
    const now = new Date();

    const stories = await this.prisma.story.findMany({
      where: {
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: now } },
        ],
        ...(query?.ageGroup ? { ageGroup: query.ageGroup } : {}),
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        user: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      total: stories.length,
      data: stories,
    };
  }
}

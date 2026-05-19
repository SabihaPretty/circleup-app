import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { allowedContentAges } from '../common/age-access';

@Injectable()
export class ReelsService {
  constructor(private readonly prisma: PrismaService) {}

  async createReel(data: any) {
    const user = await this.prisma.user.findUnique({
      where: { id: Number(data.userId) },
      select: { accountMode: true },
    });

    return this.prisma.reel.create({
      data: {
        caption: data.caption,
        mediaType: data.mediaType || 'video',
        mediaUrl: data.mediaUrl || null,
        ageGroup: data.ageGroup || 'adult',
        category: data.category || 'fun',
        creatorMode: user?.accountMode || data.creatorMode || 'personal',
        userId: Number(data.userId),
        circleId: data.circleId ? Number(data.circleId) : null,
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            nickname: true,
            ageGroup: true,
            profilePic: true,
            trustScore: true,
            accountMode: true,
            creatorBio: true,
            businessName: true,
            businessCategory: true,
          },
        },
        circle: true,
      },
    });
  }

  async getReels(ageGroup = 'adult', circleIdText?: string, category = 'all') {
    const allowedAges = allowedContentAges(ageGroup);
    const circleId = circleIdText ? Number(circleIdText) : undefined;

    const where: any = {
      ageGroup: {
        in: allowedAges,
      },
    };

    if (category && category !== 'all') {
      where.category = category;
    }

    if (circleId) {
      where.OR = [
        { circleId: null },
        { circleId },
      ];
    }

    const reels = await this.prisma.reel.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            nickname: true,
            ageGroup: true,
            profilePic: true,
            trustScore: true,
            accountMode: true,
            creatorBio: true,
            businessName: true,
            businessCategory: true,
          },
        },
        circle: true,
      },
    });

    return {
      success: true,
      total: reels.length,
      filter: {
        viewerAgeGroup: ageGroup,
        allowedAges,
        circleId: circleId || null,
        category,
      },
      data: reels,
    };
  }
}

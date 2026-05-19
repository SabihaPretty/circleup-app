import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class HelpService {
  constructor(private readonly prisma: PrismaService) {}

  async createHelpPost(data: any) {
    return this.prisma.helpPost.create({
      data: {
        title: data.title,
        description: data.description,
        category: data.category,
        location: data.location ?? null,
        userId: Number(data.userId),
        circleId: Number(data.circleId),
      },
    });
  }

  async getAllHelpPosts() {
    return this.prisma.helpPost.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            ageGroup: true,
            trustScore: true,
          },
        },
      },
    });
  }
}

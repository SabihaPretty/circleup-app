import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CirclesService {
  constructor(private readonly prisma: PrismaService) {}

  async createCircle(data: any) {
    return this.prisma.circle.create({
      data: {
        name: data.name,
        type: data.type,
      },
    });
  }

  async getAllCircles() {
    return this.prisma.circle.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        members: {
          select: {
            id: true,
            name: true,
            ageGroup: true,
            trustScore: true,
          },
        },
        posts: true,
      },
    });
  }
}

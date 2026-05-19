import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NicknamesService {
  constructor(private readonly prisma: PrismaService) {}

  async setNickname(data: any) {
    const ownerId = Number(data.ownerId);
    const targetId = Number(data.targetId);
    const nickname = String(data.nickname || '').trim();

    if (!ownerId || !targetId) {
      throw new BadRequestException('Owner ID and Target ID are required.');
    }

    if (!nickname) {
      throw new BadRequestException('Nickname is required.');
    }

    const saved = await this.prisma.userNickname.upsert({
      where: {
        ownerId_targetId: {
          ownerId,
          targetId,
        },
      },
      update: {
        nickname,
      },
      create: {
        ownerId,
        targetId,
        nickname,
      },
      include: {
        target: {
          select: {
            id: true,
            name: true,
            nickname: true,
            ageGroup: true,
            profilePic: true,
          },
        },
      },
    });

    return {
      success: true,
      message: 'Nickname saved successfully.',
      data: saved,
    };
  }

  async myNicknames(ownerId: number) {
    const data = await this.prisma.userNickname.findMany({
      where: { ownerId },
      include: {
        target: {
          select: {
            id: true,
            name: true,
            nickname: true,
            ageGroup: true,
            profilePic: true,
          },
        },
      },
    });

    return {
      success: true,
      total: data.length,
      data,
    };
  }
}

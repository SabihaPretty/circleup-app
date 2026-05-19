import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class GuardianService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private userSelect() {
    return {
      id: true,
      name: true,
      nickname: true,
      email: true,
      ageGroup: true,
      profilePic: true,
      trustScore: true,
      accountMode: true,
      creatorBio: true,
      businessName: true,
      businessCategory: true,
      createdAt: true,
    };
  }

  private makeGuardianCode() {
    const part = randomBytes(3).toString('hex').toUpperCase();
    return `CU-${part}`;
  }

  async createGuardianInvite(data: any) {
    const guardianId = Number(data.guardianId);

    const guardian = await this.prisma.user.findUnique({
      where: { id: guardianId },
      select: this.userSelect(),
    });

    if (!guardian) {
      throw new NotFoundException('Guardian not found');
    }

    if (guardian.ageGroup !== 'adult' && guardian.ageGroup !== 'senior') {
      throw new BadRequestException('Only adult or senior accounts can create guardian code');
    }

    let code = this.makeGuardianCode();

    let existing = await this.prisma.guardianInvite.findUnique({
      where: { code },
    });

    while (existing) {
      code = this.makeGuardianCode();
      existing = await this.prisma.guardianInvite.findUnique({
        where: { code },
      });
    }

    const invite = await this.prisma.guardianInvite.create({
      data: {
        code,
        guardianId,
        relationType: data.relationType || 'parent',
        status: 'active',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      },
      include: {
        guardian: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      message: 'Guardian code created. Share this code only with your child.',
      data: invite,
    };
  }

  async connectByCode(data: any) {
    const childId = Number(data.childId);
    const code = String(data.code || '').trim().toUpperCase();

    if (!code) {
      throw new BadRequestException('Guardian code is required');
    }

    const child = await this.prisma.user.findUnique({
      where: { id: childId },
      select: this.userSelect(),
    });

    if (!child) {
      throw new NotFoundException('Child account not found');
    }

    if (child.ageGroup !== 'kids' && child.ageGroup !== 'teen') {
      throw new BadRequestException('Guardian code is only for kids or teen accounts');
    }

    const invite = await this.prisma.guardianInvite.findUnique({
      where: { code },
      include: {
        guardian: {
          select: this.userSelect(),
        },
      },
    });

    if (!invite) {
      throw new NotFoundException('Invalid guardian code');
    }

    if (invite.status !== 'active') {
      throw new BadRequestException('This guardian code is no longer active');
    }

    if (invite.expiresAt && invite.expiresAt < new Date()) {
      throw new BadRequestException('This guardian code has expired');
    }

    if (invite.guardianId === childId) {
      throw new BadRequestException('You cannot connect to yourself as guardian');
    }

    const existing = await this.prisma.guardianLink.findUnique({
      where: {
        childId_guardianId: {
          childId,
          guardianId: invite.guardianId,
        },
      },
    });

    if (existing) {
      return {
        success: true,
        message: 'Guardian is already connected',
        data: existing,
      };
    }

    const link = await this.prisma.guardianLink.create({
      data: {
        childId,
        guardianId: invite.guardianId,
        relationType: invite.relationType,
        status: 'accepted',
      },
      include: {
        child: {
          select: this.userSelect(),
        },
        guardian: {
          select: this.userSelect(),
        },
      },
    });

    await this.prisma.guardianInvite.update({
      where: { id: invite.id },
      data: { status: 'used' },
    });

    await this.notificationsService.createNotification({
      type: 'guardian_link',
      title: 'Guardian linked',
      message: `${child.nickname || child.name} is now connected to you as a family guardian`,
      targetType: 'guardian',
      targetId: link.id,
      recipientId: invite.guardianId,
      senderId: childId,
    });

    return {
      success: true,
      message: 'Guardian connected successfully',
      data: link,
    };
  }

  async getGuardianLinks(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: this.userSelect(),
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const links = await this.prisma.guardianLink.findMany({
      where: {
        status: 'accepted',
        OR: [
          { childId: userId },
          { guardianId: userId },
        ],
      },
      orderBy: {
        updatedAt: 'desc',
      },
      include: {
        child: {
          select: this.userSelect(),
        },
        guardian: {
          select: this.userSelect(),
        },
      },
    });

    const safeChatUsers = links.map((link) => {
      if (link.childId === userId) {
        return link.guardian;
      }

      return link.child;
    });

    return {
      success: true,
      total: links.length,
      data: links,
      safeChatUsers,
    };
  }

  async removeGuardianLink(linkId: number, userId: number) {
    const link = await this.prisma.guardianLink.findUnique({
      where: { id: linkId },
    });

    if (!link) {
      throw new NotFoundException('Guardian link not found');
    }

    if (link.childId !== userId && link.guardianId !== userId) {
      throw new BadRequestException('You cannot remove this guardian link');
    }

    const updated = await this.prisma.guardianLink.update({
      where: { id: linkId },
      data: {
        status: 'removed',
      },
      include: {
        child: {
          select: this.userSelect(),
        },
        guardian: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      message: 'Guardian link removed',
      data: updated,
    };
  }
}

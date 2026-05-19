import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class SafetyService {
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

  async areBlocked(userOne: number, userTwo: number) {
    const block = await this.prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: userOne, blockedId: userTwo },
          { blockerId: userTwo, blockedId: userOne },
        ],
      },
    });

    return Boolean(block);
  }

  async createReport(data: any) {
    const reporterId = Number(data.reporterId);
    const reportedUserId = data.reportedUserId
      ? Number(data.reportedUserId)
      : null;

    if (!reporterId) {
      throw new BadRequestException('Reporter is required');
    }

    if (!data.reason) {
      throw new BadRequestException('Report reason is required');
    }

    const reporter = await this.prisma.user.findUnique({
      where: { id: reporterId },
      select: this.userSelect(),
    });

    if (!reporter) {
      throw new NotFoundException('Reporter not found');
    }

    if (reportedUserId) {
      const reportedUser = await this.prisma.user.findUnique({
        where: { id: reportedUserId },
        select: this.userSelect(),
      });

      if (!reportedUser) {
        throw new NotFoundException('Reported user not found');
      }

      if (reportedUserId === reporterId) {
        throw new BadRequestException('You cannot report yourself');
      }
    }

    const report = await this.prisma.safetyReport.create({
      data: {
        reporterId,
        reportedUserId,
        targetType: data.targetType || 'user',
        targetId: data.targetId ? Number(data.targetId) : reportedUserId,
        reason: data.reason,
        description: data.description || null,
        severity: data.severity || 'medium',
        status: 'pending',
      },
      include: {
        reporter: {
          select: this.userSelect(),
        },
        reportedUser: {
          select: this.userSelect(),
        },
        reviewer: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      message: 'Report submitted for safety review',
      data: report,
    };
  }

  async getMyReports(userId: number) {
    const reports = await this.prisma.safetyReport.findMany({
      where: {
        reporterId: userId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        reporter: {
          select: this.userSelect(),
        },
        reportedUser: {
          select: this.userSelect(),
        },
        reviewer: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      total: reports.length,
      data: reports,
    };
  }

  async getAdminReports(status = 'all') {
    const where =
      status && status !== 'all'
        ? {
            status,
          }
        : {};

    const reports = await this.prisma.safetyReport.findMany({
      where,
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        reporter: {
          select: this.userSelect(),
        },
        reportedUser: {
          select: this.userSelect(),
        },
        reviewer: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      total: reports.length,
      data: reports,
    };
  }

  async reviewReport(reportId: number, data: any) {
    const allowed = ['pending', 'reviewing', 'resolved', 'dismissed'];
    const status = allowed.includes(data.status) ? data.status : 'reviewing';

    const report = await this.prisma.safetyReport.findUnique({
      where: { id: reportId },
    });

    if (!report) {
      throw new NotFoundException('Report not found');
    }

    const updated = await this.prisma.safetyReport.update({
      where: { id: reportId },
      data: {
        status,
        actionTaken: data.actionTaken || null,
        reviewerId: data.reviewerId ? Number(data.reviewerId) : null,
      },
      include: {
        reporter: {
          select: this.userSelect(),
        },
        reportedUser: {
          select: this.userSelect(),
        },
        reviewer: {
          select: this.userSelect(),
        },
      },
    });

    await this.notificationsService.createNotification({
      type: 'safety_report',
      title: 'Safety report updated',
      message: `Your report is now ${status}`,
      targetType: 'report',
      targetId: reportId,
      recipientId: report.reporterId,
      senderId: data.reviewerId ? Number(data.reviewerId) : null,
    });

    return {
      success: true,
      message: `Report marked as ${status}`,
      data: updated,
    };
  }

  async blockUser(data: any) {
    const blockerId = Number(data.blockerId);
    const blockedId = Number(data.blockedId);

    if (!blockerId || !blockedId) {
      throw new BadRequestException('Blocker and blocked user are required');
    }

    if (blockerId === blockedId) {
      throw new BadRequestException('You cannot block yourself');
    }

    const blockedUser = await this.prisma.user.findUnique({
      where: { id: blockedId },
      select: this.userSelect(),
    });

    if (!blockedUser) {
      throw new NotFoundException('User not found');
    }

    const block = await this.prisma.userBlock.upsert({
      where: {
        blockerId_blockedId: {
          blockerId,
          blockedId,
        },
      },
      update: {
        reason: data.reason || 'Blocked by user',
      },
      create: {
        blockerId,
        blockedId,
        reason: data.reason || 'Blocked by user',
      },
      include: {
        blocked: {
          select: this.userSelect(),
        },
        blocker: {
          select: this.userSelect(),
        },
      },
    });

    await this.prisma.connection.updateMany({
      where: {
        OR: [
          { requesterId: blockerId, receiverId: blockedId },
          { requesterId: blockedId, receiverId: blockerId },
        ],
      },
      data: {
        status: 'blocked',
      },
    });

    return {
      success: true,
      message: 'User blocked successfully',
      data: block,
    };
  }

  async unblockUser(data: any) {
    const blockerId = Number(data.blockerId);
    const blockedId = Number(data.blockedId);

    const result = await this.prisma.userBlock.deleteMany({
      where: {
        blockerId,
        blockedId,
      },
    });

    return {
      success: true,
      message: 'User unblocked',
      deleted: result.count,
    };
  }

  async getBlockedUsers(userId: number) {
    const blocks = await this.prisma.userBlock.findMany({
      where: {
        blockerId: userId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        blocked: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      total: blocks.length,
      data: blocks,
    };
  }

  async getSafetySummary(userId: number) {
    const reportsCount = await this.prisma.safetyReport.count({
      where: {
        reporterId: userId,
      },
    });

    const blockedCount = await this.prisma.userBlock.count({
      where: {
        blockerId: userId,
      },
    });

    const pendingAdminCount = await this.prisma.safetyReport.count({
      where: {
        status: 'pending',
      },
    });

    return {
      success: true,
      data: {
        reportsCount,
        blockedCount,
        pendingAdminCount,
      },
    };
  }
}

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async createNotification(data: any) {
    if (!data.recipientId) {
      return null;
    }

    if (data.senderId && Number(data.senderId) === Number(data.recipientId)) {
      return null;
    }

    return this.prisma.notification.create({
      data: {
        type: data.type || 'general',
        title: data.title || 'New Activity',
        message: data.message || 'You have a new activity',
        targetType: data.targetType || null,
        targetId: data.targetId ? Number(data.targetId) : null,
        recipientId: Number(data.recipientId),
        senderId: data.senderId ? Number(data.senderId) : null,
      },
      include: {
        sender: {
          select: {
            id: true,
            name: true,
            ageGroup: true,
            profilePic: true,
            trustScore: true,
          },
        },
      },
    });
  }

  async getUserNotifications(userId: number) {
    const notifications = await this.prisma.notification.findMany({
      where: {
        recipientId: userId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        sender: {
          select: {
            id: true,
            name: true,
            ageGroup: true,
            profilePic: true,
            trustScore: true,
          },
        },
      },
    });

    const unreadCount = await this.prisma.notification.count({
      where: {
        recipientId: userId,
        isRead: false,
      },
    });

    return {
      success: true,
      total: notifications.length,
      unreadCount,
      data: notifications,
    };
  }

  async getUnreadCount(userId: number) {
    const unreadCount = await this.prisma.notification.count({
      where: {
        recipientId: userId,
        isRead: false,
      },
    });

    return {
      success: true,
      unreadCount,
    };
  }

  async markOneRead(notificationId: number, userId: number) {
    return this.prisma.notification.updateMany({
      where: {
        id: notificationId,
        recipientId: userId,
      },
      data: {
        isRead: true,
      },
    });
  }

  async markAllRead(userId: number) {
    return this.prisma.notification.updateMany({
      where: {
        recipientId: userId,
        isRead: false,
      },
      data: {
        isRead: true,
      },
    });
  }
}

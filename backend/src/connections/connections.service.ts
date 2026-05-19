import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { canConnectSafely } from '../common/age-access';

@Injectable()
export class ConnectionsService {
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

  async areConnected(userOne: number, userTwo: number) {
    const normalConnection = await this.prisma.connection.findFirst({
      where: {
        status: 'accepted',
        OR: [
          { requesterId: userOne, receiverId: userTwo },
          { requesterId: userTwo, receiverId: userOne },
        ],
      },
    });

    if (normalConnection) {
      return true;
    }

    const guardianConnection = await this.prisma.guardianLink.findFirst({
      where: {
        status: 'accepted',
        OR: [
          { childId: userOne, guardianId: userTwo },
          { childId: userTwo, guardianId: userOne },
        ],
      },
    });

    return Boolean(guardianConnection);
  }

  async getSuggestions(userId: number) {
    const me = await this.prisma.user.findUnique({
      where: { id: userId },
      select: this.userSelect(),
    });

    if (!me) {
      throw new NotFoundException('User not found');
    }

    const existingConnections = await this.prisma.connection.findMany({
      where: {
        OR: [
          { requesterId: userId },
          { receiverId: userId },
        ],
      },
    });

    const guardianLinks = await this.prisma.guardianLink.findMany({
      where: {
        OR: [
          { childId: userId },
          { guardianId: userId },
        ],
      },
    });

    const blockedIds = new Set<number>([userId]);

    for (const connection of existingConnections) {
      blockedIds.add(connection.requesterId);
      blockedIds.add(connection.receiverId);
    }

    for (const link of guardianLinks) {
      blockedIds.add(link.childId);
      blockedIds.add(link.guardianId);
    }

    const users = await this.prisma.user.findMany({
      where: {
        id: {
          notIn: Array.from(blockedIds),
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      select: this.userSelect(),
    });

    const safeSuggestions = users.filter((user) => {
      return canConnectSafely(me.ageGroup, user.ageGroup);
    });

    return {
      success: true,
      rule: 'Kids do not use People tab. Kids connect to parent/guardian using Guardian Code only.',
      total: safeSuggestions.length,
      data: safeSuggestions,
    };
  }

  async sendRequest(requesterId: number, receiverId: number) {
    if (requesterId === receiverId) {
      throw new BadRequestException('You cannot connect with yourself');
    }

    const requester = await this.prisma.user.findUnique({
      where: { id: requesterId },
      select: this.userSelect(),
    });

    const receiver = await this.prisma.user.findUnique({
      where: { id: receiverId },
      select: this.userSelect(),
    });

    if (!requester || !receiver) {
      throw new NotFoundException('User not found');
    }

    if (requester.ageGroup === 'kids' || receiver.ageGroup === 'kids') {
      throw new BadRequestException('Kids can connect with guardians only through Guardian Code');
    }

    if (!canConnectSafely(requester.ageGroup, receiver.ageGroup)) {
      throw new BadRequestException(
        `Safe connection rule blocked this request. ${requester.ageGroup} cannot connect with ${receiver.ageGroup}.`,
      );
    }

    const existing = await this.prisma.connection.findFirst({
      where: {
        OR: [
          { requesterId, receiverId },
          { requesterId: receiverId, receiverId: requesterId },
        ],
      },
    });

    if (existing) {
      return {
        success: true,
        message: `Connection already ${existing.status}`,
        data: existing,
      };
    }

    const connection = await this.prisma.connection.create({
      data: {
        requesterId,
        receiverId,
        status: 'pending',
      },
      include: {
        requester: {
          select: this.userSelect(),
        },
        receiver: {
          select: this.userSelect(),
        },
      },
    });

    await this.notificationsService.createNotification({
      type: 'connection_request',
      title: 'New connection request',
      message: `${requester.nickname || requester.name} wants to connect with you`,
      targetType: 'connection',
      targetId: connection.id,
      recipientId: receiverId,
      senderId: requesterId,
    });

    return {
      success: true,
      message: 'Connection request sent',
      data: connection,
    };
  }

  async respond(connectionId: number, userId: number, status: string) {
    const allowed = ['accepted', 'rejected'];
    const cleanStatus = allowed.includes(status) ? status : 'rejected';

    const connection = await this.prisma.connection.findUnique({
      where: { id: connectionId },
      include: {
        requester: {
          select: this.userSelect(),
        },
        receiver: {
          select: this.userSelect(),
        },
      },
    });

    if (!connection) {
      throw new NotFoundException('Connection request not found');
    }

    if (connection.receiverId !== userId) {
      throw new BadRequestException('Only receiver can respond to this request');
    }

    const updated = await this.prisma.connection.update({
      where: { id: connectionId },
      data: {
        status: cleanStatus,
      },
      include: {
        requester: {
          select: this.userSelect(),
        },
        receiver: {
          select: this.userSelect(),
        },
      },
    });

    await this.notificationsService.createNotification({
      type: 'connection_status',
      title: cleanStatus === 'accepted' ? 'Connection accepted' : 'Connection rejected',
      message:
        cleanStatus === 'accepted'
          ? `${connection.receiver.nickname || connection.receiver.name} accepted your connection request`
          : `${connection.receiver.nickname || connection.receiver.name} rejected your connection request`,
      targetType: 'connection',
      targetId: connectionId,
      recipientId: connection.requesterId,
      senderId: userId,
    });

    return {
      success: true,
      message: `Connection ${cleanStatus}`,
      data: updated,
    };
  }

  async blockConnection(connectionId: number, userId: number) {
    const connection = await this.prisma.connection.findUnique({
      where: { id: connectionId },
    });

    if (!connection) {
      throw new NotFoundException('Connection not found');
    }

    if (connection.requesterId !== userId && connection.receiverId !== userId) {
      throw new BadRequestException('You cannot block this connection');
    }

    const updated = await this.prisma.connection.update({
      where: { id: connectionId },
      data: {
        status: 'blocked',
      },
      include: {
        requester: {
          select: this.userSelect(),
        },
        receiver: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      message: 'Connection blocked',
      data: updated,
    };
  }

  async getUserConnections(userId: number) {
    const connections = await this.prisma.connection.findMany({
      where: {
        OR: [
          { requesterId: userId },
          { receiverId: userId },
        ],
      },
      orderBy: {
        updatedAt: 'desc',
      },
      include: {
        requester: {
          select: this.userSelect(),
        },
        receiver: {
          select: this.userSelect(),
        },
      },
    });

    const accepted = connections
      .filter((connection) => connection.status === 'accepted')
      .map((connection) => ({
        ...connection,
        otherUser:
          connection.requesterId === userId
            ? connection.receiver
            : connection.requester,
      }));

    const pendingReceived = connections
      .filter((connection) => connection.status === 'pending' && connection.receiverId === userId)
      .map((connection) => ({
        ...connection,
        otherUser: connection.requester,
      }));

    const pendingSent = connections
      .filter((connection) => connection.status === 'pending' && connection.requesterId === userId)
      .map((connection) => ({
        ...connection,
        otherUser: connection.receiver,
      }));

    const blocked = connections
      .filter((connection) => connection.status === 'blocked')
      .map((connection) => ({
        ...connection,
        otherUser:
          connection.requesterId === userId
            ? connection.receiver
            : connection.requester,
      }));

    return {
      success: true,
      counts: {
        accepted: accepted.length,
        pendingReceived: pendingReceived.length,
        pendingSent: pendingSent.length,
        blocked: blocked.length,
      },
      accepted,
      pendingReceived,
      pendingSent,
      blocked,
    };
  }
}

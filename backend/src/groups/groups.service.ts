import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class GroupsService {
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

  async createGroup(data: any) {
    const creatorId = Number(data.creatorId);

    if (!creatorId) {
      throw new BadRequestException('Creator ID is required.');
    }

    if (!data.name || String(data.name).trim().length < 2) {
      throw new BadRequestException('Group name is required.');
    }

    const creator = await this.prisma.user.findUnique({
      where: { id: creatorId },
      select: this.userSelect(),
    });

    if (!creator) {
      throw new NotFoundException('Creator user not found.');
    }

    const rawMemberIds = Array.isArray(data.memberIds) ? data.memberIds : [];
    const memberIds = Array.from(
      new Set([creatorId, ...rawMemberIds.map((id: any) => Number(id)).filter(Boolean)]),
    );

    const group = await this.prisma.chatGroup.create({
      data: {
        name: String(data.name).trim(),
        description: data.description || null,
        photoUrl: data.photoUrl || null,
        ageGroup: data.ageGroup || creator.ageGroup || 'adult',
        creatorId,
        members: {
          create: memberIds.map((userId: number) => ({
            userId,
            role: userId === creatorId ? 'admin' : 'member',
          })),
        },
      },
      include: {
        creator: { select: this.userSelect() },
        members: {
          include: {
            user: { select: this.userSelect() },
          },
        },
        _count: {
          select: {
            members: true,
            messages: true,
          },
        },
      },
    });

    return {
      success: true,
      message: 'Group created successfully.',
      data: group,
    };
  }

  async myGroups(userId: number) {
    const memberships = await this.prisma.chatGroupMember.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: {
        group: {
          include: {
            creator: { select: this.userSelect() },
            members: {
              include: {
                user: { select: this.userSelect() },
              },
            },
            _count: {
              select: {
                members: true,
                messages: true,
              },
            },
          },
        },
      },
    });

    return {
      success: true,
      total: memberships.length,
      data: memberships.map((item) => item.group),
    };
  }

  async addMember(data: any) {
    const groupId = Number(data.groupId);
    const userId = Number(data.userId);

    if (!groupId || !userId) {
      throw new BadRequestException('Group ID and User ID are required.');
    }

    await this.prisma.chatGroupMember.upsert({
      where: {
        groupId_userId: {
          groupId,
          userId,
        },
      },
      update: {},
      create: {
        groupId,
        userId,
        role: 'member',
      },
    });

    return {
      success: true,
      message: 'Member added successfully.',
    };
  }

  async getMessages(groupId: number) {
    const messages = await this.prisma.groupMessage.findMany({
      where: { groupId },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
          select: this.userSelect(),
        },
      },
    });

    return {
      success: true,
      total: messages.length,
      data: messages,
    };
  }

  async sendMessage(data: any) {
    const groupId = Number(data.groupId);
    const senderId = Number(data.senderId);

    if (!groupId || !senderId) {
      throw new BadRequestException('Group ID and Sender ID are required.');
    }

    if (!data.content || String(data.content).trim().length === 0) {
      throw new BadRequestException('Message content is required.');
    }

    const member = await this.prisma.chatGroupMember.findUnique({
      where: {
        groupId_userId: {
          groupId,
          userId: senderId,
        },
      },
    });

    if (!member) {
      throw new BadRequestException('You are not a member of this group.');
    }

    const message = await this.prisma.groupMessage.create({
      data: {
        groupId,
        senderId,
        content: String(data.content).trim(),
        mediaUrl: data.mediaUrl || null,
        mediaType: data.mediaType || 'text',
      },
      include: {
        sender: {
          select: this.userSelect(),
        },
      },
    });

    return message;
  }
}




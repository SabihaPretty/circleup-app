import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ConnectionsService } from '../connections/connections.service';
import { SafetyService } from '../safety/safety.service';

@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly connectionsService: ConnectionsService,
    private readonly safetyService: SafetyService,
  ) {}

  makeConversationId(userOne: number, userTwo: number) {
    const ids = [Number(userOne), Number(userTwo)].sort((a, b) => a - b);
    return `private_${ids[0]}_${ids[1]}`;
  }

  async sendMessage(data: any) {
    const senderId = Number(data.senderId);
    const receiverId = Number(data.receiverId);

    const blocked = await this.safetyService.areBlocked(senderId, receiverId);

    if (blocked) {
      throw new BadRequestException('Messaging is blocked between these users.');
    }

    const connected = await this.connectionsService.areConnected(senderId, receiverId);

    if (!connected) {
      throw new BadRequestException('You can chat only with accepted safe connections.');
    }

    const conversation =
      data.conversation || this.makeConversationId(senderId, receiverId);

    return this.prisma.message.create({
      data: {
        content: data.content,
        senderId,
        receiverId,
        conversation,
      },
      include: {
        sender: {
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
  }

  async getMessages(conversation: string) {
    return this.prisma.message.findMany({
      where: { conversation },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
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
  }
}

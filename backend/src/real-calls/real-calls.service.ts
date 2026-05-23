import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const AgoraAccessToken = require('agora-access-token');
const RtcTokenBuilder = AgoraAccessToken.RtcTokenBuilder;
const RtcRole = AgoraAccessToken.RtcRole;

@Injectable()
export class RealCallsService {
  constructor(private readonly prisma: PrismaService) {}

  private appId() {
    const appId = process.env.AGORA_APP_ID;
    if (!appId) {
      throw new InternalServerErrorException('AGORA_APP_ID is missing.');
    }
    return appId;
  }

  private appCertificate() {
    const cert = process.env.AGORA_APP_CERTIFICATE;
    if (!cert) {
      throw new InternalServerErrorException('AGORA_APP_CERTIFICATE is missing.');
    }
    return cert;
  }

  private makeToken(channelName: string, uid: number) {
    const expireSeconds = 60 * 60;
    const now = Math.floor(Date.now() / 1000);
    const privilegeExpire = now + expireSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      this.appId(),
      this.appCertificate(),
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpire,
    );

    return {
      appId: this.appId(),
      token,
      channelName,
      uid,
      expiresIn: expireSeconds,
    };
  }

  async startCall(data: any) {
    const callerId = Number(data.callerId);
    const receiverId = Number(data.receiverId);
    const callType = String(data.callType || 'audio');

    if (!callerId || !receiverId) {
      throw new BadRequestException('callerId and receiverId are required.');
    }

    if (callerId === receiverId) {
      throw new BadRequestException('Caller and receiver cannot be same.');
    }

    const channelName = `circleup_${callerId}_${receiverId}_${Date.now()}`;

    const session = await this.prisma.realCallSession.create({
      data: {
        channelName,
        callerId,
        receiverId,
        callType,
        status: 'ringing',
      },
    });

    return {
      success: true,
      message: 'Call started.',
      data: {
        session,
        rtc: this.makeToken(channelName, callerId),
      },
    };
  }

  async incoming(userId: number) {
    if (!userId) {
      throw new BadRequestException('userId is required.');
    }

    const session = await this.prisma.realCallSession.findFirst({
      where: {
        receiverId: userId,
        status: 'ringing',
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return {
      success: true,
      data: session,
    };
  }

  async acceptCall(data: any) {
    const callId = Number(data.callId);
    const userId = Number(data.userId);

    if (!callId || !userId) {
      throw new BadRequestException('callId and userId are required.');
    }

    const session = await this.prisma.realCallSession.findUnique({
      where: { id: callId },
    });

    if (!session) {
      throw new NotFoundException('Call session not found.');
    }

    if (session.receiverId !== userId) {
      throw new BadRequestException('Only receiver can accept this call.');
    }

    const updated = await this.prisma.realCallSession.update({
      where: { id: callId },
      data: {
        status: 'accepted',
        acceptedAt: new Date(),
      },
    });

    return {
      success: true,
      message: 'Call accepted.',
      data: {
        session: updated,
        rtc: this.makeToken(updated.channelName, userId),
      },
    };
  }

  async token(data: any) {
    const channelName = String(data.channelName || '').trim();
    const uid = Number(data.uid);

    if (!channelName || !uid) {
      throw new BadRequestException('channelName and uid are required.');
    }

    return {
      success: true,
      data: this.makeToken(channelName, uid),
    };
  }

  async endCall(data: any) {
    const callId = Number(data.callId);

    if (!callId) {
      return {
        success: true,
        message: 'No callId provided.',
      };
    }

    const existing = await this.prisma.realCallSession.findUnique({
      where: { id: callId },
    });

    if (!existing) {
      return {
        success: true,
        message: 'Call already ended.',
      };
    }

    await this.prisma.realCallSession.update({
      where: { id: callId },
      data: {
        status: 'ended',
        endedAt: new Date(),
      },
    });

    return {
      success: true,
      message: 'Call ended.',
    };
  }

  async rejectCall(data: any) {
    const callId = Number(data.callId);

    if (!callId) {
      throw new BadRequestException('callId is required.');
    }

    await this.prisma.realCallSession.update({
      where: { id: callId },
      data: {
        status: 'rejected',
        endedAt: new Date(),
      },
    });

    return {
      success: true,
      message: 'Call rejected.',
    };
  }
}

import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async getSettings(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        nickname: true,
        email: true,
        phone: true,
        ageGroup: true,
        isEmailVerified: true,
        isPhoneVerified: true,
        twoStepEnabled: true,
        preferredVerifyMode: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return {
      success: true,
      data: user,
    };
  }

  async updateSettings(data: any) {
    const userId = Number(data.userId);

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const preferredVerifyMode =
      data.preferredVerifyMode || user.preferredVerifyMode || 'email';

    if (data.twoStepEnabled === true) {
      if (
        preferredVerifyMode === 'email' &&
        (!user.email || !user.isEmailVerified)
      ) {
        throw new BadRequestException(
          'Verified email is required to enable two-step verification.',
        );
      }

      if (
        preferredVerifyMode === 'phone' &&
        (!user.phone || !user.isPhoneVerified)
      ) {
        throw new BadRequestException(
          'Verified phone number is required to enable two-step verification.',
        );
      }
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        twoStepEnabled:
          typeof data.twoStepEnabled === 'boolean'
            ? data.twoStepEnabled
            : user.twoStepEnabled,
        preferredVerifyMode,
      },
      select: {
        id: true,
        name: true,
        nickname: true,
        email: true,
        phone: true,
        ageGroup: true,
        isEmailVerified: true,
        isPhoneVerified: true,
        twoStepEnabled: true,
        preferredVerifyMode: true,
      },
    });

    return {
      success: true,
      message: 'Settings updated successfully.',
      data: updated,
    };
  }
}

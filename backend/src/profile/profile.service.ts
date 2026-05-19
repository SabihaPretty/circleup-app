import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProfileService {
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
      isEmailVerified: true,
      isPhoneVerified: true,
      twoStepEnabled: true,
      preferredVerifyMode: true,
      createdAt: true,
    };
  }

  async updateProfilePicture(data: any) {
    const userId = Number(data.userId);
    const profilePic = String(data.profilePic || '').trim();

    if (!userId) {
      throw new BadRequestException('User ID is required.');
    }

    if (!profilePic) {
      throw new BadRequestException('Profile picture URL is required.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: { profilePic },
      select: this.userSelect(),
    });

    return {
      success: true,
      message: 'Profile picture updated successfully.',
      data: updatedUser,
    };
  }
}

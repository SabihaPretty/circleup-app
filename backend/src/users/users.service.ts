import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { calculateAgeGroupFromBirthDate } from '../common/age-access';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  private userSelect() {
    return {
      id: true,
      name: true,
      nickname: true,
      email: true,
      phone: true,
      birthDate: true,
      birthYear: true,
      birthMonth: true,
      birthDay: true,
      ageGroup: true,
      isEmailVerified: true,
      isPhoneVerified: true,
      twoStepEnabled: true,
      preferredVerifyMode: true,
      profilePic: true,
      trustScore: true,
      accountMode: true,
      creatorBio: true,
      businessName: true,
      businessCategory: true,
      createdAt: true,
    };
  }

  private normalizeIdentifier(identifier: string) {
    return String(identifier || '').trim().toLowerCase();
  }

  private isEmail(identifier: string) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier);
  }

  private cleanPhone(identifier: string) {
    return String(identifier || '').replace(/[\s-]/g, '');
  }

  private isPhone(identifier: string) {
    const clean = this.cleanPhone(identifier);
    return /^\+?[0-9]{10,15}$/.test(clean);
  }

  private validatePassword(password: string) {
    if (!password || password.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters long.');
    }
  }

  private getBirthDate(data: any) {
    const year = Number(data.birthYear);
    const month = Number(data.birthMonth);
    const day = Number(data.birthDay);

    if (!year || !month || !day) return null;

    const date = new Date(year, month - 1, day);

    if (
      date.getFullYear() !== year ||
      date.getMonth() !== month - 1 ||
      date.getDate() !== day
    ) {
      throw new BadRequestException('Invalid birth date.');
    }

    return date;
  }

  private parseIdentity(data: any) {
    const raw = this.normalizeIdentifier(
      data.emailOrPhone || data.identifier || data.email || data.phone || '',
    );

    if (!raw) {
      throw new BadRequestException('Email or phone number is required.');
    }

    if (this.isEmail(raw)) {
      return {
        email: raw,
        phone: null,
        channel: 'email',
        identifier: raw,
      };
    }

    const cleanPhone = this.cleanPhone(raw);

    if (this.isPhone(cleanPhone)) {
      return {
        email: null,
        phone: cleanPhone,
        channel: 'phone',
        identifier: cleanPhone,
      };
    }

    throw new BadRequestException('Enter a valid email or phone number.');
  }

  async createUser(data: any) {
    this.validatePassword(data.password);

    const identity = this.parseIdentity(data);

    const existingUser = await this.prisma.user.findFirst({
      where: {
        OR: [
          identity.email ? { email: identity.email } : undefined,
          identity.phone ? { phone: identity.phone } : undefined,
        ].filter(Boolean) as any[],
      },
    });

    if (existingUser) {
      throw new ConflictException('This email or phone already exists. Please login or use another one.');
    }

    const birthYear = Number(data.birthYear);
    const birthMonth = Number(data.birthMonth);
    const birthDay = Number(data.birthDay);
    const birthDate = this.getBirthDate(data);

    const autoAgeGroup = calculateAgeGroupFromBirthDate(
      birthYear,
      birthMonth,
      birthDay,
    );

    const verifiedChannel = data.verifiedChannel || null;
    const hashedPassword = await bcrypt.hash(data.password, 10);

    return this.prisma.user.create({
      data: {
        name: data.name,
        nickname: data.nickname || null,
        email: identity.email,
        phone: identity.phone,
        password: hashedPassword,
        birthDate,
        birthYear,
        birthMonth,
        birthDay,
        ageGroup: autoAgeGroup,
        isEmailVerified: verifiedChannel === 'email',
        isPhoneVerified: verifiedChannel === 'phone',
        profilePic: data.profilePic ?? null,
        trustScore:
          autoAgeGroup === 'adult' || autoAgeGroup === 'senior'
            ? verifiedChannel
              ? 35
              : 20
            : 20,
        accountMode: data.accountMode ?? 'personal',
      },
      select: this.userSelect(),
    });
  }

  async getAllUsers() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: this.userSelect(),
    });
  }

  async findByIdentifierWithPassword(identifierText: string) {
    const identity = this.parseIdentity({ emailOrPhone: identifierText });

    return this.prisma.user.findFirst({
      where: {
        OR: [
          identity.email ? { email: identity.email } : undefined,
          identity.phone ? { phone: identity.phone } : undefined,
        ].filter(Boolean) as any[],
      },
    });
  }

  async findByEmailWithPassword(email: string) {
    return this.findByIdentifierWithPassword(email);
  }

  async getUserById(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: this.userSelect(),
    });

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return user;
  }

  async updateUserPassword(userId: number, newPassword: string) {
    this.validatePassword(newPassword);

    const hashedPassword = await bcrypt.hash(newPassword, 10);

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        password: hashedPassword,
      },
      select: this.userSelect(),
    });
  }

  async updateCreatorMode(data: any) {
    return this.prisma.user.update({
      where: {
        id: Number(data.userId),
      },
      data: {
        accountMode: data.accountMode || 'personal',
        creatorBio: data.creatorBio || null,
        businessName: data.businessName || null,
        businessCategory: data.businessCategory || null,
      },
      select: this.userSelect(),
    });
  }
}

import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';
import axios from 'axios';
import { PrismaService } from '../prisma/prisma.service';
import { calculateAgeGroupFromBirthDate } from '../common/age-access';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  private isBcryptHash(password: string) {
    return (
      password.startsWith('$2a$') ||
      password.startsWith('$2b$') ||
      password.startsWith('$2y$')
    );
  }

  private createToken(user: any) {
    return this.jwtService.sign({
      sub: user.id,
      email: user.email,
      phone: user.phone,
      ageGroup: user.ageGroup,
      accountMode: user.accountMode,
    });
  }

  private normalizeText(value: string) {
    return String(value || '').trim().toLowerCase();
  }

  private isEmail(value: string) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  private normalizePhone(value: string) {
    return String(value || '').replace(/[\s()-]/g, '');
  }

  private isInternationalPhone(value: string) {
    return /^\+[1-9]\d{7,14}$/.test(value);
  }

  private parseIdentifier(identifierText: string) {
    const raw = this.normalizeText(identifierText);

    if (!raw) {
      throw new BadRequestException('Email or phone number is required.');
    }

    if (this.isEmail(raw)) {
      return {
        identifier: raw,
        channel: 'email',
      };
    }

    const phone = this.normalizePhone(raw);

    if (this.isInternationalPhone(phone)) {
      return {
        identifier: phone,
        channel: 'phone',
      };
    }

    throw new BadRequestException(
      'Enter a valid email or phone number. Phone number must include country code, for example +8801580645351.',
    );
  }

  private makeCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private makeVerificationToken() {
    return randomBytes(32).toString('hex');
  }

  private getAgeGroupFromBody(data: any) {
    return calculateAgeGroupFromBirthDate(
      Number(data.birthYear),
      Number(data.birthMonth),
      Number(data.birthDay),
    );
  }

  private verificationRequired(ageGroup: string) {
    return ageGroup === 'adult' || ageGroup === 'senior';
  }

  private async sendBrevoEmail(email: string, code: string, subject: string) {
    const apiKey = String(process.env.BREVO_API_KEY || '').trim();
    const senderEmail = String(process.env.BREVO_SENDER_EMAIL || '').trim();
    const senderName = process.env.BREVO_SENDER_NAME || 'CircleUp';

    if (!apiKey.startsWith('xkeysib-')) {
      throw new BadRequestException(
        'Brevo API key is missing or invalid. BREVO_API_KEY must start with xkeysib-.',
      );
    }

    if (!senderEmail || !senderEmail.includes('@')) {
      throw new BadRequestException(
        'Brevo sender email is missing. Set BREVO_SENDER_EMAIL in backend .env.',
      );
    }

    const htmlContent = `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;border-radius:20px;border:1px solid #e5e7eb;background:#ffffff">
        <h2 style="margin:0 0 12px;color:#4f46e5">CircleUp Verification</h2>
        <p style="font-size:15px;color:#111827">Use this verification code to continue:</p>
        <div style="font-size:34px;font-weight:800;letter-spacing:7px;background:#f3f4f6;padding:18px;border-radius:16px;text-align:center;color:#111827">
          ${code}
        </div>
        <p style="color:#6b7280;font-size:13px;line-height:1.6">
          This code will expire in 10 minutes. Do not share this code with anyone.
          If you did not request this code, you can safely ignore this email.
        </p>
      </div>
    `;

    try {
      await axios.post(
        'https://api.brevo.com/v3/smtp/email',
        {
          sender: {
            name: senderName,
            email: senderEmail,
          },
          to: [
            {
              email,
            },
          ],
          subject,
          htmlContent,
          textContent: `Your CircleUp verification code is ${code}. This code will expire in 10 minutes.`,
        },
        {
          headers: {
            accept: 'application/json',
            'api-key': apiKey,
            'content-type': 'application/json',
          },
        },
      );
    } catch (error: any) {
      const details =
        error?.response?.data?.message ||
        error?.response?.data?.code ||
        JSON.stringify(error?.response?.data || {}) ||
        error.message;

      throw new BadRequestException(
        `Email could not be sent. Check BREVO_API_KEY and verified BREVO_SENDER_EMAIL. Details: ${details}`,
      );
    }
  }

  private async createAndSendCode(
    identifier: string,
    channel: string,
    purpose: string,
  ) {
    const code = this.makeCode();
    const hashedCode = await bcrypt.hash(code, 10);

    await this.prisma.verificationCode.updateMany({
      where: {
        identifier,
        purpose,
        isUsed: false,
      },
      data: {
        isUsed: true,
      },
    });

    if (channel === 'email') {
      const subject =
        purpose === 'reset_password'
          ? 'Your CircleUp password reset code'
          : purpose === 'login_2fa'
            ? 'Your CircleUp login verification code'
            : 'Your CircleUp account verification code';

      await this.sendBrevoEmail(identifier, code, subject);
    }

    if (channel === 'phone') {
      const mode = process.env.PHONE_OTP_MODE || 'dev';

      if (mode !== 'dev') {
        throw new BadRequestException(
          'Real SMS provider is not configured. Set PHONE_OTP_MODE=dev for free development phone verification.',
        );
      }

      console.log('');
      console.log('========================================');
      console.log('CircleUp FREE DEV PHONE OTP');
      console.log(`Phone: ${identifier}`);
      console.log(`Purpose: ${purpose}`);
      console.log(`Code: ${code}`);
      console.log('========================================');
      console.log('');
    }

    await this.prisma.verificationCode.create({
      data: {
        identifier,
        channel,
        code: hashedCode,
        purpose,
        isUsed: false,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
    });

    return {
      devCode: channel === 'phone' ? code : null,
    };
  }

  private async verifyStoredCode(
    identifierText: string,
    codeText: string,
    purpose: string,
  ) {
    const parsed = this.parseIdentifier(identifierText);
    const code = String(codeText || '').trim();

    if (!code) {
      throw new BadRequestException('Verification code is required.');
    }

    const records = await this.prisma.verificationCode.findMany({
      where: {
        identifier: parsed.identifier,
        channel: parsed.channel,
        purpose,
        isUsed: false,
        expiresAt: {
          gt: new Date(),
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 5,
    });

    for (const record of records) {
      const matched = await bcrypt.compare(code, record.code);

      if (matched) {
        return {
          parsed,
          record,
        };
      }
    }

    throw new BadRequestException('Invalid or expired verification code.');
  }

  async sendVerification(data: any) {
    const parsed = this.parseIdentifier(data.emailOrPhone || data.identifier);
    const ageGroup = this.getAgeGroupFromBody(data);

    if (!this.verificationRequired(ageGroup)) {
      return {
        success: true,
        requiresVerification: false,
        ageGroup,
        message: 'Verification is not required for kids or teen accounts.',
      };
    }

    const existingUser = await this.usersService.findByIdentifierWithPassword(
      parsed.identifier,
    );

    if (existingUser) {
      throw new BadRequestException('This email or phone is already registered.');
    }

    const delivery = await this.createAndSendCode(
      parsed.identifier,
      parsed.channel,
      'register',
    );

    return {
      success: true,
      requiresVerification: true,
      ageGroup,
      channel: parsed.channel,
      identifier: parsed.identifier,
      devCode: delivery.devCode,
      message:
        parsed.channel === 'email'
          ? 'Verification code has been sent to your email.'
          : `Free development phone code: ${delivery.devCode}`,
    };
  }

  async verifyCode(
    identifierText: string,
    codeText: string,
    purpose = 'register',
  ) {
    const verified = await this.verifyStoredCode(
      identifierText,
      codeText,
      purpose,
    );

    const verifiedToken = this.makeVerificationToken();

    await this.prisma.verificationCode.update({
      where: {
        id: verified.record.id,
      },
      data: {
        verifiedToken,
        verifiedAt: new Date(),
      },
    });

    return {
      success: true,
      channel: verified.parsed.channel,
      identifier: verified.parsed.identifier,
      verificationToken: verifiedToken,
      message: 'Verification successful.',
    };
  }

  private async consumeVerifiedToken(
    identifierText: string,
    verificationToken: string,
    purpose: string,
  ) {
    const parsed = this.parseIdentifier(identifierText);

    if (!verificationToken) {
      throw new BadRequestException(
        'Verification is not completed. Please verify your code first.',
      );
    }

    const record = await this.prisma.verificationCode.findFirst({
      where: {
        identifier: parsed.identifier,
        verifiedToken: verificationToken,
        purpose,
        isUsed: false,
        expiresAt: {
          gt: new Date(),
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    if (!record) {
      throw new BadRequestException(
        'Verification not completed or expired. Please send and verify code again.',
      );
    }

    await this.prisma.verificationCode.update({
      where: {
        id: record.id,
      },
      data: {
        isUsed: true,
      },
    });

    return {
      channel: record.channel,
      identifier: record.identifier,
    };
  }

  async register(data: any) {
    const ageGroup = this.getAgeGroupFromBody(data);
    const parsed = this.parseIdentifier(
      data.emailOrPhone || data.identifier || data.email || data.phone,
    );

    let verifiedChannel: string | null = null;

    if (this.verificationRequired(ageGroup)) {
      const consumed = await this.consumeVerifiedToken(
        parsed.identifier,
        data.verificationToken,
        'register',
      );

      verifiedChannel = consumed.channel;
    }

    const user = await this.usersService.createUser({
      ...data,
      emailOrPhone: parsed.identifier,
      verifiedChannel,
    });

    const token = this.createToken(user);

    return {
      success: true,
      message: 'Registration successful.',
      token,
      user,
    };
  }

  async login(data: any) {
    const identifier =
      data.emailOrPhone || data.identifier || data.email || data.phone;

    const userWithPassword =
      await this.usersService.findByIdentifierWithPassword(identifier);

    if (!userWithPassword) {
      throw new UnauthorizedException('Invalid email/phone or password.');
    }

    const storedPassword = userWithPassword.password;
    let passwordMatched = false;

    if (this.isBcryptHash(storedPassword)) {
      passwordMatched = await bcrypt.compare(data.password, storedPassword);
    } else {
      passwordMatched = storedPassword === data.password;

      if (passwordMatched) {
        await this.usersService.updateUserPassword(
          userWithPassword.id,
          data.password,
        );
      }
    }

    if (!passwordMatched) {
      throw new UnauthorizedException('Invalid email/phone or password.');
    }

    const safeUser = await this.usersService.getUserById(userWithPassword.id);

    if (userWithPassword.twoStepEnabled) {
      const channel =
        userWithPassword.preferredVerifyMode === 'phone' &&
        userWithPassword.phone &&
        userWithPassword.isPhoneVerified
          ? 'phone'
          : 'email';

      const target =
        channel === 'phone' ? userWithPassword.phone : userWithPassword.email;

      if (!target) {
        throw new BadRequestException('Two-step verification target is missing.');
      }

      const delivery = await this.createAndSendCode(
        target,
        channel,
        'login_2fa',
      );

      return {
        success: true,
        requiresTwoStep: true,
        channel,
        identifier: target,
        devCode: delivery.devCode,
        message:
          channel === 'email'
            ? 'Login verification code has been sent to your email.'
            : `Free development login phone code: ${delivery.devCode}`,
      };
    }

    const token = this.createToken(safeUser);

    return {
      success: true,
      message: 'Login successful.',
      token,
      user: safeUser,
    };
  }

  async verifyLoginTwoStep(identifierText: string, codeText: string) {
    const verified = await this.verifyStoredCode(
      identifierText,
      codeText,
      'login_2fa',
    );

    await this.prisma.verificationCode.update({
      where: {
        id: verified.record.id,
      },
      data: {
        isUsed: true,
        verifiedAt: new Date(),
      },
    });

    const userWithPassword =
      await this.usersService.findByIdentifierWithPassword(
        verified.parsed.identifier,
      );

    if (!userWithPassword) {
      throw new UnauthorizedException('User not found.');
    }

    const safeUser = await this.usersService.getUserById(userWithPassword.id);
    const token = this.createToken(safeUser);

    return {
      success: true,
      message: 'Login successful.',
      token,
      user: safeUser,
    };
  }

  async sendPasswordReset(data: any) {
    const parsed = this.parseIdentifier(data.emailOrPhone || data.identifier);

    const user = await this.usersService.findByIdentifierWithPassword(
      parsed.identifier,
    );

    if (!user) {
      throw new BadRequestException('No account found with this email or phone.');
    }

    const delivery = await this.createAndSendCode(
      parsed.identifier,
      parsed.channel,
      'reset_password',
    );

    return {
      success: true,
      channel: parsed.channel,
      identifier: parsed.identifier,
      devCode: delivery.devCode,
      message:
        parsed.channel === 'email'
          ? 'Password reset code has been sent to your email.'
          : `Free development password reset phone code: ${delivery.devCode}`,
    };
  }

  async verifyPasswordReset(data: any) {
    return this.verifyCode(
      data.emailOrPhone || data.identifier,
      data.code,
      'reset_password',
    );
  }

  async resetPassword(data: any) {
    const parsed = this.parseIdentifier(data.emailOrPhone || data.identifier);

    if (!data.newPassword || String(data.newPassword).length < 6) {
      throw new BadRequestException(
        'New password must be at least 6 characters.',
      );
    }

    if (data.newPassword !== data.confirmPassword) {
      throw new BadRequestException(
        'Password and confirm password do not match.',
      );
    }

    await this.consumeVerifiedToken(
      parsed.identifier,
      data.verificationToken,
      'reset_password',
    );

    const user = await this.usersService.findByIdentifierWithPassword(
      parsed.identifier,
    );

    if (!user) {
      throw new BadRequestException('User not found.');
    }

    await this.usersService.updateUserPassword(user.id, data.newPassword);

    return {
      success: true,
      message: 'Password reset successful. Please login with your new password.',
    };
  }


  async changePassword(userId: number, data: any) {
    const currentPassword = String(data.currentPassword || '');
    const newPassword = String(data.newPassword || '');
    const confirmPassword = String(data.confirmPassword || '');

    if (!currentPassword) {
      throw new BadRequestException('Current password is required.');
    }

    if (newPassword.length < 6) {
      throw new BadRequestException('New password must be at least 6 characters.');
    }

    if (newPassword !== confirmPassword) {
      throw new BadRequestException('New password and confirm password do not match.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new UnauthorizedException('User not found.');
    }

    const matched = this.isBcryptHash(user.password)
      ? await bcrypt.compare(currentPassword, user.password)
      : currentPassword === user.password;

    if (!matched) {
      throw new UnauthorizedException('Current password is incorrect.');
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        password: hashedPassword,
      },
    });

    return {
      success: true,
      message: 'Password changed successfully.',
    };
  }
  async getProfile(userId: number) {
    const user = await this.usersService.getUserById(userId);

    return {
      success: true,
      user,
    };
  }
}




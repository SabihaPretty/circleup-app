import { BadRequestException } from '@nestjs/common';

export function requireBrevoConfig() {
  const apiKey = process.env.BREVO_API_KEY;
  const senderEmail = process.env.BREVO_SENDER_EMAIL;

  if (!apiKey || apiKey.includes('your_') || apiKey.length < 20) {
    throw new BadRequestException(
      'Brevo API key is missing or invalid. Set BREVO_API_KEY in backend .env. It should be the Brevo API key, not SMTP password.',
    );
  }

  if (!senderEmail || senderEmail.includes('your_') || !senderEmail.includes('@')) {
    throw new BadRequestException(
      'Brevo sender email is missing or invalid. Set BREVO_SENDER_EMAIL in backend .env and verify this sender in Brevo.',
    );
  }
}

export function requireTwilioVerifyConfig() {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID;

  if (!accountSid || !accountSid.startsWith('AC')) {
    throw new BadRequestException(
      'Twilio Account SID is missing or invalid. TWILIO_ACCOUNT_SID must start with AC.',
    );
  }

  if (!authToken || authToken.includes('your_') || authToken.length < 10) {
    throw new BadRequestException(
      'Twilio Auth Token is missing or invalid. Set TWILIO_AUTH_TOKEN in backend .env.',
    );
  }

  if (!serviceSid || !serviceSid.startsWith('VA')) {
    throw new BadRequestException(
      'Twilio Verify Service SID is missing or invalid. TWILIO_VERIFY_SERVICE_SID must start with VA.',
    );
  }
}

export function normalizeInternationalPhone(phone: string) {
  const cleaned = String(phone || '').replace(/[\s()-]/g, '');

  if (!/^\+[1-9]\d{7,14}$/.test(cleaned)) {
    throw new BadRequestException(
      'Enter phone number with country code, for example +8801XXXXXXXXX, +919XXXXXXXXX, +447XXXXXXXXX or +1XXXXXXXXXX.',
    );
  }

  return cleaned;
}

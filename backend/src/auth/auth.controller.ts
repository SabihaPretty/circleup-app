import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('send-verification')
  sendVerification(@Body() body: any) {
    return this.authService.sendVerification(body);
  }

  @Post('verify-code')
  verifyCode(@Body() body: any) {
    return this.authService.verifyCode(
      body.emailOrPhone || body.identifier || body.email || body.phone,
      body.code,
      'register',
    );
  }

  @Post('register')
  register(@Body() body: any) {
    return this.authService.register(body);
  }

  @Post('login')
  login(@Body() body: any) {
    return this.authService.login(body);
  }

  @Post('login-2fa/verify')
  verifyLoginTwoStep(@Body() body: any) {
    return this.authService.verifyLoginTwoStep(
      body.emailOrPhone || body.identifier || body.email || body.phone,
      body.code,
    );
  }

  @Post('password/forgot-send')
  forgotPasswordSend(@Body() body: any) {
    return this.authService.sendPasswordReset(body);
  }

  @Post('password/forgot-verify')
  forgotPasswordVerify(@Body() body: any) {
    return this.authService.verifyPasswordReset(body);
  }

  @Post('password/reset')
  resetPassword(@Body() body: any) {
    return this.authService.resetPassword(body);
  }


  @UseGuards(JwtAuthGuard)
  @Post('password/change')
  changePassword(@Req() req: any, @Body() body: any) {
    return this.authService.changePassword(req.user.userId, body);
  }
  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: any) {
    return this.authService.getProfile(req.user.userId);
  }
}



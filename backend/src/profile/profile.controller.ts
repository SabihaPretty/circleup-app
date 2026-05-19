import { Body, Controller, Post } from '@nestjs/common';
import { ProfileService } from './profile.service';

@Controller('profile')
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Post('picture')
  updateProfilePicture(@Body() body: any) {
    return this.profileService.updateProfilePicture(body);
  }
}

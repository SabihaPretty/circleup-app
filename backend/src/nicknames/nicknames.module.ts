import { Module } from '@nestjs/common';
import { NicknamesController } from './nicknames.controller';
import { NicknamesService } from './nicknames.service';

@Module({
  controllers: [NicknamesController],
  providers: [NicknamesService],
})
export class NicknamesModule {}

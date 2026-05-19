import { ProfileModule } from './profile/profile.module';
import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { CirclesModule } from './circles/circles.module';
import { PostsModule } from './posts/posts.module';
import { MessagesModule } from './messages/messages.module';
import { CallsModule } from './calls/calls.module';
import { HelpModule } from './help/help.module';
import { AuthModule } from './auth/auth.module';
import { InteractionsModule } from './interactions/interactions.module';
import { StoriesModule } from './stories/stories.module';
import { ReelsModule } from './reels/reels.module';
import { MarketplaceModule } from './marketplace/marketplace.module';
import { NotificationsModule } from './notifications/notifications.module';
import { MediaModule } from './media/media.module';
import { ConnectionsModule } from './connections/connections.module';
import { GuardianModule } from './guardian/guardian.module';
import { SafetyModule } from './safety/safety.module';
import { SearchModule } from './search/search.module';
import { AdminModule } from './admin/admin.module';
import { SettingsModule } from './settings/settings.module';
import { GroupsModule } from './groups/groups.module';
import { NicknamesModule } from './nicknames/nicknames.module';

@Module({
  imports: [ProfileModule, PrismaModule,
    UsersModule,
    CirclesModule,
    PostsModule,
    GuardianModule,
    ConnectionsModule,
    SafetyModule,
    MessagesModule,
    CallsModule,
    HelpModule,
    AuthModule,
    NotificationsModule,
    InteractionsModule,
    StoriesModule,
    ReelsModule,
    MarketplaceModule,
    MediaModule,
    SearchModule,
    AdminModule,
    SettingsModule,
    GroupsModule,
    NicknamesModule],
})
export class AppModule {}






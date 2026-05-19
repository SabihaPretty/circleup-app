import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  private userSelect() {
    return {
      id: true,
      name: true,
      nickname: true,
      email: true,
      ageGroup: true,
      profilePic: true,
      trustScore: true,
      accountMode: true,
      businessName: true,
      businessCategory: true,
      createdAt: true,
    };
  }

  async getDashboard() {
    const [
      totalUsers,
      totalKids,
      totalTeen,
      totalAdult,
      totalSenior,
      totalPosts,
      totalReels,
      totalStories,
      totalProducts,
      totalOrders,
      totalConnections,
      totalGuardianLinks,
      totalReports,
      pendingReports,
      reviewingReports,
      resolvedReports,
      dismissedReports,
      totalBlocks,
      totalNotifications,
      unreadNotifications,
      recentUsers,
      recentPosts,
      recentReports,
      recentProducts,
      recentOrders,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { ageGroup: 'kids' } }),
      this.prisma.user.count({ where: { ageGroup: 'teen' } }),
      this.prisma.user.count({ where: { ageGroup: 'adult' } }),
      this.prisma.user.count({ where: { ageGroup: 'senior' } }),

      this.prisma.post.count(),
      this.prisma.reel.count(),
      this.prisma.story.count(),
      this.prisma.product.count(),
      this.prisma.productOrder.count(),

      this.prisma.connection.count({ where: { status: 'accepted' } }),
      this.prisma.guardianLink.count({ where: { status: 'accepted' } }),

      this.prisma.safetyReport.count(),
      this.prisma.safetyReport.count({ where: { status: 'pending' } }),
      this.prisma.safetyReport.count({ where: { status: 'reviewing' } }),
      this.prisma.safetyReport.count({ where: { status: 'resolved' } }),
      this.prisma.safetyReport.count({ where: { status: 'dismissed' } }),

      this.prisma.userBlock.count(),
      this.prisma.notification.count(),
      this.prisma.notification.count({ where: { isRead: false } }),

      this.prisma.user.findMany({
        orderBy: { createdAt: 'desc' },
        take: 6,
        select: this.userSelect(),
      }),

      this.prisma.post.findMany({
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: {
          user: {
            select: this.userSelect(),
          },
          circle: true,
          _count: {
            select: {
              likes: true,
              comments: true,
            },
          },
        },
      }),

      this.prisma.safetyReport.findMany({
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: {
          reporter: {
            select: this.userSelect(),
          },
          reportedUser: {
            select: this.userSelect(),
          },
          reviewer: {
            select: this.userSelect(),
          },
        },
      }),

      this.prisma.product.findMany({
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: {
          seller: {
            select: this.userSelect(),
          },
          _count: {
            select: {
              orders: true,
            },
          },
        },
      }),

      this.prisma.productOrder.findMany({
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: {
          product: true,
          buyer: {
            select: this.userSelect(),
          },
          seller: {
            select: this.userSelect(),
          },
        },
      }),
    ]);

    const ageBreakdown = [
      {
        label: 'Kids',
        key: 'kids',
        value: totalKids,
      },
      {
        label: 'Teen',
        key: 'teen',
        value: totalTeen,
      },
      {
        label: 'Adult',
        key: 'adult',
        value: totalAdult,
      },
      {
        label: 'Senior',
        key: 'senior',
        value: totalSenior,
      },
    ];

    const contentBreakdown = [
      {
        label: 'Posts',
        key: 'posts',
        value: totalPosts,
      },
      {
        label: 'Stories',
        key: 'stories',
        value: totalStories,
      },
      {
        label: 'Reels',
        key: 'reels',
        value: totalReels,
      },
      {
        label: 'Products',
        key: 'products',
        value: totalProducts,
      },
    ];

    const safetyBreakdown = [
      {
        label: 'Pending',
        key: 'pending',
        value: pendingReports,
      },
      {
        label: 'Reviewing',
        key: 'reviewing',
        value: reviewingReports,
      },
      {
        label: 'Resolved',
        key: 'resolved',
        value: resolvedReports,
      },
      {
        label: 'Dismissed',
        key: 'dismissed',
        value: dismissedReports,
      },
    ];

    const healthScore = this.calculateHealthScore({
      totalUsers,
      pendingReports,
      totalBlocks,
      totalConnections,
      totalGuardianLinks,
    });

    return {
      success: true,
      dashboardName: 'CircleUp Admin Analytics',
      healthScore,
      summary: {
        totalUsers,
        totalKids,
        totalTeen,
        totalAdult,
        totalSenior,
        totalPosts,
        totalStories,
        totalReels,
        totalProducts,
        totalOrders,
        totalConnections,
        totalGuardianLinks,
        totalReports,
        pendingReports,
        reviewingReports,
        resolvedReports,
        dismissedReports,
        totalBlocks,
        totalNotifications,
        unreadNotifications,
      },
      charts: {
        ageBreakdown,
        contentBreakdown,
        safetyBreakdown,
      },
      recent: {
        users: recentUsers,
        posts: recentPosts,
        reports: recentReports,
        products: recentProducts,
        orders: recentOrders,
      },
      recommendations: this.getRecommendations({
        totalUsers,
        totalPosts,
        totalReports,
        pendingReports,
        totalBlocks,
        totalGuardianLinks,
      }),
    };
  }

  private calculateHealthScore(data: any) {
    let score = 80;

    if (data.totalUsers > 0) {
      score += 5;
    }

    if (data.totalConnections > 0) {
      score += 5;
    }

    if (data.totalGuardianLinks > 0) {
      score += 5;
    }

    if (data.pendingReports > 5) {
      score -= 10;
    }

    if (data.totalBlocks > 10) {
      score -= 10;
    }

    if (score > 100) return 100;
    if (score < 0) return 0;

    return score;
  }

  private getRecommendations(data: any) {
    const items: string[] = [];

    if (data.totalUsers === 0) {
      items.push('Start by creating demo users for kids, teens, adults and seniors.');
    }

    if (data.totalPosts === 0) {
      items.push('Add sample posts so the smart feed and explore page look active.');
    }

    if (data.pendingReports > 0) {
      items.push('Review pending safety reports from Safety Center.');
    }

    if (data.totalGuardianLinks === 0) {
      items.push('Test Guardian Code system using one adult and one kids account.');
    }

    if (data.totalBlocks > 0) {
      items.push('Monitor blocked users to identify unsafe behavior patterns.');
    }

    if (items.length === 0) {
      items.push('System looks healthy. Continue testing real users, chat and media upload.');
    }

    return items;
  }
}

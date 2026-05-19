import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { allowedContentAges, allowedConnectionAges } from '../common/age-access';

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  private userSelect() {
    return {
      id: true,
      name: true,
      nickname: true,
      ageGroup: true,
      profilePic: true,
      trustScore: true,
      accountMode: true,
      creatorBio: true,
      businessName: true,
      businessCategory: true,
      createdAt: true,
    };
  }

  private searchText(query: string) {
    return {
      contains: query,
      mode: 'insensitive' as const,
    };
  }

  private buildReactionCounts(likes: any[]) {
    const counts: Record<string, number> = {
      boost: 0,
      support: 0,
      useful: 0,
      trend: 0,
      help: 0,
      concern: 0,
      angry: 0,
    };

    for (const like of likes || []) {
      const type = like.reactionType || 'boost';
      counts[type] = (counts[type] || 0) + 1;
    }

    return counts;
  }

  private async getBlockedIds(userId: number) {
    const blocks = await this.prisma.userBlock.findMany({
      where: {
        OR: [
          { blockerId: userId },
          { blockedId: userId },
        ],
      },
    });

    const ids = new Set<number>();
    ids.add(userId);

    for (const block of blocks) {
      ids.add(block.blockerId);
      ids.add(block.blockedId);
    }

    return Array.from(ids);
  }

  private enrichPost(post: any) {
    const reactionCounts = this.buildReactionCounts(post.likes || []);
    const likesCount = post._count?.likes || 0;
    const commentsCount = post._count?.comments || 0;

    return {
      ...post,
      smartReason: 'Search Match',
      smartScore:
        likesCount * 5 +
        commentsCount * 3 -
        (reactionCounts.concern || 0) * 4 -
        (reactionCounts.angry || 0) * 6,
      reactionCounts,
    };
  }

  async searchAll(userId: number, q = '', type = 'all') {
    const viewer = await this.prisma.user.findUnique({
      where: { id: userId },
      select: this.userSelect(),
    });

    if (!viewer) {
      throw new NotFoundException('User not found');
    }

    const query = String(q || '').trim();
    const viewerAge = viewer.ageGroup || 'adult';
    const allowedAges = allowedContentAges(viewerAge);
    const allowedPeopleAges = allowedConnectionAges(viewerAge);
    const blockedIds = await this.getBlockedIds(userId);

    let users: any[] = [];
    let posts: any[] = [];
    let reels: any[] = [];
    let products: any[] = [];

    if ((type === 'all' || type === 'users') && viewerAge !== 'kids') {
      const where: any = {
        id: {
          notIn: blockedIds,
        },
        ageGroup: {
          in: allowedPeopleAges,
        },
      };

      if (query) {
        where.OR = [
          { name: this.searchText(query) },
          { nickname: this.searchText(query) },
          { businessName: this.searchText(query) },
          { businessCategory: this.searchText(query) },
        ];
      }

      users = await this.prisma.user.findMany({
        where,
        orderBy: {
          trustScore: 'desc',
        },
        take: 20,
        select: this.userSelect(),
      });
    }

    if (type === 'all' || type === 'posts') {
      const where: any = {
        userId: {
          notIn: blockedIds,
        },
        user: {
          ageGroup: {
            in: allowedAges,
          },
        },
      };

      if (query) {
        where.OR = [
          { content: this.searchText(query) },
          { mediaType: this.searchText(query) },
          {
            circle: {
              name: this.searchText(query),
            },
          },
        ];
      }

      const foundPosts = await this.prisma.post.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        take: 30,
        include: {
          user: {
            select: this.userSelect(),
          },
          circle: true,
          likes: {
            select: {
              reactionType: true,
            },
          },
          comments: {
            take: 2,
            orderBy: {
              createdAt: 'desc',
            },
            include: {
              user: {
                select: {
                  id: true,
                  name: true,
                  nickname: true,
                  ageGroup: true,
                },
              },
            },
          },
          _count: {
            select: {
              likes: true,
              comments: true,
            },
          },
        },
      });

      posts = foundPosts.map((post) => this.enrichPost(post));
    }

    if (type === 'all' || type === 'reels') {
      const where: any = {
        userId: {
          notIn: blockedIds,
        },
        ageGroup: {
          in: allowedAges,
        },
      };

      if (query) {
        where.OR = [
          { caption: this.searchText(query) },
          { category: this.searchText(query) },
          { mediaType: this.searchText(query) },
        ];
      }

      reels = await this.prisma.reel.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        take: 30,
        include: {
          user: {
            select: this.userSelect(),
          },
          circle: true,
        },
      });
    }

    if (
      (type === 'all' || type === 'products') &&
      (viewerAge === 'adult' || viewerAge === 'senior')
    ) {
      const where: any = {
        status: 'active',
        sellerId: {
          notIn: blockedIds,
        },
      };

      if (query) {
        where.OR = [
          { name: this.searchText(query) },
          { description: this.searchText(query) },
          { category: this.searchText(query) },
          {
            seller: {
              businessName: this.searchText(query),
            },
          },
        ];
      }

      products = await this.prisma.product.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        take: 30,
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
      });
    }

    const trendingPosts = [...posts]
      .sort((a, b) => (b.smartScore || 0) - (a.smartScore || 0))
      .slice(0, 5);

    const trendingReels = [...reels].slice(0, 5);
    const trendingProducts = [...products].slice(0, 5);

    return {
      success: true,
      query,
      type,
      viewer: {
        id: viewer.id,
        ageGroup: viewerAge,
        allowedContentAges: allowedAges,
        allowedPeopleAges,
      },
      counts: {
        users: users.length,
        posts: posts.length,
        reels: reels.length,
        products: products.length,
      },
      data: {
        users,
        posts,
        reels,
        products,
        trendingPosts,
        trendingReels,
        trendingProducts,
      },
    };
  }
}

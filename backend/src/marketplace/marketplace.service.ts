import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private sellerSelect() {
    return {
      id: true,
      name: true,
      email: true,
      ageGroup: true,
      trustScore: true,
      accountMode: true,
      creatorBio: true,
      businessName: true,
      businessCategory: true,
      profilePic: true,
    };
  }

  async createProduct(data: any) {
    return this.prisma.product.create({
      data: {
        name: data.name,
        description: data.description,
        price: Number(data.price),
        category: data.category || 'general',
        imageUrl: data.imageUrl || null,
        status: data.status || 'active',
        sellerId: Number(data.sellerId),
      },
      include: {
        seller: {
          select: this.sellerSelect(),
        },
      },
    });
  }

  async getProducts(category = 'all', sellerIdText?: string) {
    const where: any = {
      status: 'active',
    };

    if (category && category !== 'all') {
      where.category = category;
    }

    if (sellerIdText) {
      where.sellerId = Number(sellerIdText);
    }

    const products = await this.prisma.product.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        seller: {
          select: this.sellerSelect(),
        },
        _count: {
          select: {
            orders: true,
          },
        },
      },
    });

    return {
      success: true,
      total: products.length,
      data: products,
    };
  }

  async createOrder(data: any) {
    const product = await this.prisma.product.findUnique({
      where: { id: Number(data.productId) },
      include: {
        seller: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    if (!product) {
      return {
        success: false,
        message: 'Product not found',
      };
    }

    const order = await this.prisma.productOrder.create({
      data: {
        productId: Number(data.productId),
        buyerId: Number(data.buyerId),
        sellerId: product.sellerId,
        quantity: Number(data.quantity || 1),
        note: data.note || null,
      },
      include: {
        product: true,
        buyer: {
          select: this.sellerSelect(),
        },
        seller: {
          select: this.sellerSelect(),
        },
      },
    });

    await this.notificationsService.createNotification({
      type: 'order',
      title: 'New product order',
      message: `${order.buyer.name} ordered ${order.product.name}`,
      targetType: 'order',
      targetId: order.id,
      recipientId: order.sellerId,
      senderId: order.buyerId,
    });

    return {
      success: true,
      message: 'Order placed successfully',
      data: order,
    };
  }

  async getSellerOrders(sellerId: number) {
    const orders = await this.prisma.productOrder.findMany({
      where: { sellerId },
      orderBy: { createdAt: 'desc' },
      include: {
        product: true,
        buyer: {
          select: this.sellerSelect(),
        },
        seller: {
          select: this.sellerSelect(),
        },
      },
    });

    return {
      success: true,
      total: orders.length,
      data: orders,
    };
  }

  async getBuyerOrders(buyerId: number) {
    const orders = await this.prisma.productOrder.findMany({
      where: { buyerId },
      orderBy: { createdAt: 'desc' },
      include: {
        product: true,
        buyer: {
          select: this.sellerSelect(),
        },
        seller: {
          select: this.sellerSelect(),
        },
      },
    });

    return {
      success: true,
      total: orders.length,
      data: orders,
    };
  }

  async updateOrderStatus(orderId: number, status: string) {
    const allowed = ['pending', 'accepted', 'completed', 'cancelled'];
    const cleanStatus = allowed.includes(status) ? status : 'pending';

    const updatedOrder = await this.prisma.productOrder.update({
      where: { id: orderId },
      data: { status: cleanStatus },
      include: {
        product: true,
        buyer: {
          select: this.sellerSelect(),
        },
        seller: {
          select: this.sellerSelect(),
        },
      },
    });

    await this.notificationsService.createNotification({
      type: 'order_status',
      title: 'Order status updated',
      message: `Your order for ${updatedOrder.product.name} is now ${cleanStatus}`,
      targetType: 'order',
      targetId: updatedOrder.id,
      recipientId: updatedOrder.buyerId,
      senderId: updatedOrder.sellerId,
    });

    return updatedOrder;
  }

  async getCreatorPublicProfile(userId: number) {
    const creator = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        ...this.sellerSelect(),
        products: {
          orderBy: { createdAt: 'desc' },
          include: {
            _count: {
              select: {
                orders: true,
              },
            },
          },
        },
        reels: {
          orderBy: { createdAt: 'desc' },
          take: 6,
        },
        posts: {
          orderBy: { createdAt: 'desc' },
          take: 6,
        },
        _count: {
          select: {
            products: true,
            reels: true,
            posts: true,
            sellerOrders: true,
          },
        },
      },
    });

    return {
      success: true,
      data: creator,
    };
  }
}

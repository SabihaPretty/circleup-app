import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { MarketplaceService } from './marketplace.service';

@Controller('marketplace')
export class MarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Post('products/create')
  createProduct(@Body() body: any) {
    return this.marketplaceService.createProduct(body);
  }

  @Get('products')
  getProducts(
    @Query('category') category: string,
    @Query('sellerId') sellerId: string,
  ) {
    return this.marketplaceService.getProducts(category || 'all', sellerId);
  }

  @Post('orders/create')
  createOrder(@Body() body: any) {
    return this.marketplaceService.createOrder(body);
  }

  @Get('orders/seller/:sellerId')
  getSellerOrders(@Param('sellerId') sellerId: string) {
    return this.marketplaceService.getSellerOrders(Number(sellerId));
  }

  @Get('orders/buyer/:buyerId')
  getBuyerOrders(@Param('buyerId') buyerId: string) {
    return this.marketplaceService.getBuyerOrders(Number(buyerId));
  }

  @Post('orders/:orderId/status')
  updateOrderStatus(@Param('orderId') orderId: string, @Body() body: any) {
    return this.marketplaceService.updateOrderStatus(
      Number(orderId),
      body.status,
    );
  }

  @Get('creator/:userId')
  getCreatorPublicProfile(@Param('userId') userId: string) {
    return this.marketplaceService.getCreatorPublicProfile(Number(userId));
  }
}

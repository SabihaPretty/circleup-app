import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';
import 'creator_public_profile_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  bool loading = true;
  List products = [];
  List sellerOrders = [];
  List buyerOrders = [];

  String tab = 'products';
  String category = 'all';

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);

    final user = AppSession.currentUser;

    try {
      final productsResult = await ApiService.get(
        '/marketplace/products?category=$category',
      );
      products = productsResult['data'] ?? [];

      if (user != null) {
        final sellerResult = await ApiService.get(
          '/marketplace/orders/seller/${user['id']}',
        );
        sellerOrders = sellerResult['data'] ?? [];

        final buyerResult = await ApiService.get(
          '/marketplace/orders/buyer/${user['id']}',
        );
        buyerOrders = buyerResult['data'] ?? [];
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loading = false);
  }

  Future<void> openCreateProductSheet() async {
    final user = AppSession.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: 'Premium Study Notes');
    final descriptionController = TextEditingController(
      text: 'Useful digital product for students.',
    );
    final priceController = TextEditingController(text: '250');

    String selectedCategory = 'education';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget categoryChip(String value, String label) {
              return ChoiceChip(
                selected: selectedCategory == value,
                label: Text(label),
                onSelected: (_) {
                  setSheetState(() => selectedCategory = value);
                },
              );
            }

            Future<void> createProduct() async {
              if (nameController.text.trim().isEmpty ||
                  priceController.text.trim().isEmpty) {
                showMessage('Product name and price required.');
                return;
              }

              try {
                await ApiService.post('/marketplace/products/create', {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.tryParse(priceController.text.trim()) ?? 0,
                  'category': selectedCategory,
                  'imageUrl': 'dummy-product-image',
                  'sellerId': user['id'],
                });

                if (!mounted) return;
                Navigator.pop(context);
                await loadAll();
                showMessage('Product added to showcase.');
              } catch (e) {
                showMessage('Product create failed: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Product Showcase',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'For creators, teachers, doctors, farmers, local sellers and small businesses.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Product name',
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: '৳ ',
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        categoryChip('education', 'Education'),
                        categoryChip('health', 'Health'),
                        categoryChip('farmer', 'Farmer'),
                        categoryChip('food', 'Food'),
                        categoryChip('local_service', 'Local Service'),
                        categoryChip('digital', 'Digital'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: createProduct,
                        icon: const Icon(Icons.add_business),
                        label: const Text('Add Product'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }

  Future<void> placeOrder(Map<String, dynamic> product) async {
    final user = AppSession.currentUser;
    if (user == null) return;

    final noteController = TextEditingController(
      text: 'I want to order this product.',
    );

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        Future<void> submitOrder() async {
          try {
            final result = await ApiService.post('/marketplace/orders/create', {
              'productId': product['id'],
              'buyerId': user['id'],
              'quantity': 1,
              'note': noteController.text.trim(),
            });

            if (!mounted) return;
            Navigator.pop(context);
            await loadAll();

            showMessage(result['message'] ?? 'Order placed.');
          } catch (e) {
            showMessage('Order failed: $e');
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Place Order',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.shopping_bag),
                ),
                title: Text(product['name'] ?? ''),
                subtitle: Text('৳${product['price']} • ${product['category']}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Order note',
                  filled: true,
                  fillColor: const Color(0xfff8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitOrder,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Confirm Order'),
                ),
              ),
            ],
          ),
        );
      },
    );

    noteController.dispose();
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      await ApiService.post('/marketplace/orders/$orderId/status', {
        'status': status,
      });

      await loadAll();
      showMessage('Order updated: $status');
    } catch (e) {
      showMessage('Status update failed: $e');
    }
  }

  Widget categoryChip(String value, String label) {
    return ChoiceChip(
      selected: category == value,
      label: Text(label),
      onSelected: (_) async {
        setState(() => category = value);
        await loadAll();
      },
    );
  }

  Widget tabChip(String value, String label, IconData icon) {
    return ChoiceChip(
      selected: tab == value,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) {
        setState(() => tab = value);
      },
    );
  }

  void openCreatorProfile(int creatorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorPublicProfileScreen(creatorId: creatorId),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget productCard(Map<String, dynamic> product) {
    final seller = Map<String, dynamic>.from(product['seller'] ?? {});
    final isMine = AppSession.currentUser?['id'] == seller['id'];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.primary.withOpacity(.12),
                child: const Icon(
                  Icons.shopping_bag,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${product['category']} • by ${seller['name'] ?? 'Seller'}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text('৳${product['price']}'),
                backgroundColor: const Color(0xffeef2ff),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(product['description'] ?? ''),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(.10),
                  AppTheme.accent.withOpacity(.08),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    seller['accountMode'] == 'business'
                        ? 'Business verified showcase placeholder'
                        : 'Creator showcase placeholder',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openCreatorProfile(seller['id']),
                  icon: const Icon(Icons.person),
                  label: const Text('Profile'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isMine ? null : () => placeOrder(product),
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text(isMine ? 'Your Product' : 'Order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget orderCard(Map<String, dynamic> order, bool sellerView) {
    final product = Map<String, dynamic>.from(order['product'] ?? {});
    final buyer = Map<String, dynamic>.from(order['buyer'] ?? {});
    final seller = Map<String, dynamic>.from(order['seller'] ?? {});

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.success.withOpacity(.12),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  product['name'] ?? 'Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Chip(label: Text(order['status'] ?? 'pending')),
            ],
          ),
          const SizedBox(height: 8),
          Text('Price: ৳${product['price']} • Qty: ${order['quantity']}'),
          const SizedBox(height: 4),
          Text(
            sellerView
                ? 'Buyer: ${buyer['name'] ?? 'Unknown'}'
                : 'Seller: ${seller['name'] ?? 'Unknown'}',
          ),
          if ((order['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${order['note']}'),
          ],
          if (sellerView) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => updateOrderStatus(order['id'], 'accepted'),
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: () => updateOrderStatus(order['id'], 'completed'),
                  child: const Text('Complete'),
                ),
                OutlinedButton(
                  onPressed: () => updateOrderStatus(order['id'], 'cancelled'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;
    final mode = user?['accountMode'] ?? 'personal';

    return RefreshIndicator(
      onRefresh: loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: AppTheme.darkGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.storefront,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Creator Marketplace',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(label: Text(mode)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Product showcase, creator public profile and order inbox for local business, education, health, farmer and digital services.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: openCreateProductSheet,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Add Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                tabChip('products', 'Products', Icons.shopping_bag),
                tabChip('inbox', 'Order Inbox', Icons.inbox),
                tabChip('my_orders', 'My Orders', Icons.receipt_long),
              ],
            ),
          ),
          if (tab == 'products') ...[
            PremiumCard(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  categoryChip('all', 'All'),
                  categoryChip('education', 'Education'),
                  categoryChip('health', 'Health'),
                  categoryChip('farmer', 'Farmer'),
                  categoryChip('food', 'Food'),
                  categoryChip('local_service', 'Local Service'),
                  categoryChip('digital', 'Digital'),
                ],
              ),
            ),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (products.isEmpty)
              const EmptyState(
                icon: Icons.storefront,
                title: 'No products yet',
                subtitle: 'Add your first creator/business product.',
              )
            else
              ...products.map((item) {
                return productCard(Map<String, dynamic>.from(item));
              }),
          ],
          if (tab == 'inbox') ...[
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (sellerOrders.isEmpty)
              const EmptyState(
                icon: Icons.inbox,
                title: 'No seller orders',
                subtitle: 'Orders for your products will appear here.',
              )
            else
              ...sellerOrders.map((item) {
                return orderCard(Map<String, dynamic>.from(item), true);
              }),
          ],
          if (tab == 'my_orders') ...[
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (buyerOrders.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long,
                title: 'No orders yet',
                subtitle: 'Your placed orders will appear here.',
              )
            else
              ...buyerOrders.map((item) {
                return orderCard(Map<String, dynamic>.from(item), false);
              }),
          ],
        ],
      ),
    );
  }
}

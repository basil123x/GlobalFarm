class CartItemModel {
  final String cartId;
  final String orderId;
  int cartQuantity;
  final CartItem item;
  final CartSeller seller;

  CartItemModel({
    required this.cartId,
    required this.orderId,
    required this.cartQuantity,
    required this.item,
    required this.seller,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      cartId: json['cart_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      cartQuantity:
          int.tryParse(json['cart_quantity']?.toString() ?? '') ?? 0,
      item: CartItem.fromJson(
        json['item'] is Map<String, dynamic>
            ? json['item'] as Map<String, dynamic>
            : Map<String, dynamic>.from(json['item'] ?? {}),
      ),
      seller: CartSeller.fromJson(
        json['seller'] is Map<String, dynamic>
            ? json['seller'] as Map<String, dynamic>
            : Map<String, dynamic>.from(json['seller'] ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'order_id': orderId,
      'cart_quantity': cartQuantity,
      'item': item.toJson(),
      'seller': seller.toJson(),
    };
  }
}

class CartItem {
  final String id;
  final String idx;
  final String name;
  final String price;
  final int availableQuantity;
  final String thumbnail;
  final String store_id;
  final String media;

  CartItem({
    required this.id,
    required this.idx,
    required this.name,
    required this.price,
    required this.availableQuantity,
    required this.thumbnail,
    required this.store_id,
    this.media = '',
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      idx: json['idx']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      availableQuantity:
          int.tryParse(json['available_quantity']?.toString() ?? '') ?? 0,
      thumbnail: json['thumbnail']?.toString() ?? '',
      store_id: json['store_id']?.toString() ?? '',
      media: json['media']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'available_quantity': availableQuantity,
      'thumbnail': thumbnail,
      'store_id': store_id,
      'media': media,
    };
  }
}

class CartSeller {
  final String id;
  final String name;

  CartSeller({required this.id, required this.name});

  factory CartSeller.fromJson(Map<String, dynamic> json) {
    return CartSeller(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class SyncedProduct {
  final String name;
  final String code;
  final int quantity;
  final double price;

  SyncedProduct({
    required this.name,
    required this.code,
    required this.quantity,
    required this.price,
  });

  factory SyncedProduct.fromJson(Map<String, dynamic> json) {
    return SyncedProduct(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'quantity': quantity,
      'price': price,
    };
  }
}
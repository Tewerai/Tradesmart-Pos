class Product {
  String id;
  String name;
  double price;
  double stockPrice;
  dynamic quantity; // Use dynamic to allow both int and String ('N/A')
  String category;
  String measuredIn;
  String barcode;
  String shopId; // Add shopId field
  bool trackStock; // Add trackStock field

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stockPrice,
    required this.quantity,
    required this.category,
    required this.measuredIn,
    required this.barcode,
    required this.shopId, // Initialize shopId in constructor
    required this.trackStock, // Initialize trackStock in constructor
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stockPrice': stockPrice,
      'quantity': quantity,
      'category': category,
      'measuredIn': measuredIn,
      'barcode': barcode,
      'shopId': shopId, // Include shopId in JSON representation
      'trackStock': trackStock, // Include trackStock in JSON representation
    };
  }
}

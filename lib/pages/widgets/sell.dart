class Product {
  final String name;
  final String code;
  final double price;
  final double quantity;
  double? discountAmount; // Add discount per product
  double? discountPercentage; // Add discount percentage per product

  Product({
    required this.name,
    required this.code,
    required this.price,
    required this.quantity,
    this.discountAmount,
    this.discountPercentage,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'price': price,
        'quantity': quantity,
        'discountAmount': discountAmount,
        'discountPercentage': discountPercentage,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        name: json['name'],
        code: json['code'],
        price: json['price'].toDouble(),
        quantity: json['quantity'],
        discountAmount: json['discountAmount']?.toDouble(),
        discountPercentage: json['discountPercentage']?.toDouble(),
      );
  
  // Calculate discounted price for this product
  double getDiscountedPrice() {
    if (discountAmount != null) {
      return price - discountAmount!;
    } else if (discountPercentage != null) {
      return price * (1 - discountPercentage! / 100);
    }
    return price;
  }
  
  // Calculate total with discount
  double getTotalWithDiscount() {
    return getDiscountedPrice() * quantity;
  }
}

class Order {
  final String orderNumber;
  final List<Product> products;
  double total;
  final DateTime timestamp;
  final String customerName;
  final String cashierName;
  bool isRefunded;
  double refundAmount;
  Discount? appliedDiscount;
  double? discountAmount;
  double? originalTotal;

  Order({
    required this.orderNumber,
    required this.products,
    required this.total,
    required this.timestamp,
    required this.customerName,
    required this.cashierName,
    this.isRefunded = false,
    this.refundAmount = 0.0,
    this.appliedDiscount,
    this.discountAmount,
    this.originalTotal,
  });

  Map<String, dynamic> toJson() => {
        'orderNumber': orderNumber,
        'products': products.map((product) => product.toJson()).toList(),
        'total': total,
        'timestamp': timestamp.toIso8601String(),
        'customerName': customerName,
        'cashierName': cashierName,
        'isRefunded': isRefunded,
        'refundAmount': refundAmount,
        'appliedDiscount': appliedDiscount?.toJson(),
        'has_discount': appliedDiscount != null || (products.any((p) => 
            (p.discountAmount != null && p.discountAmount! > 0) || 
            (p.discountPercentage != null && p.discountPercentage! > 0))),
        'discount': _calculateDiscountAmount(),
        'original_total': _calculateOriginalTotal(),
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        orderNumber: json['orderNumber'],
        products: List<Product>.from(
            json['products'].map((product) => Product.fromJson(product))),
        total: json['total'].toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        customerName: json['customerName'],
        cashierName: json['cashierName'],
        isRefunded: json['isRefunded'] ?? false,
        refundAmount: json['refundAmount']?.toDouble() ?? 0.0,
        appliedDiscount: json['appliedDiscount'] != null 
            ? Discount.fromJson(json['appliedDiscount']) 
            : null,
        discountAmount: json['discount']?.toDouble(),
        originalTotal: json['original_total']?.toDouble(),
      );
  
  double _calculateDiscountAmount() {
    if (appliedDiscount != null) {
      if (appliedDiscount!.type == DiscountType.Percentage) {
        double originalTotal = _calculateOriginalTotal();
        return originalTotal * (appliedDiscount!.value / 100);
      } else {
        return appliedDiscount!.value;
      }
    }
    return 0.0;
  }
  
  double _calculateOriginalTotal() {
    double total = 0;
    for (var product in products) {
      total += product.price * product.quantity;
    }
    return total;
  }
}/* DISCOUNT PART*/
class Discount {
  final double value;
  final DiscountType type;

  Discount({required this.value, required this.type});

  Map<String, dynamic> toJson() => {
        'value': value,
        'type': type.index, // Store the index of the DiscountType enum
      };

  factory Discount.fromJson(Map<String, dynamic> json) => Discount(
        value: json['value'],
        type: DiscountType.values[json['type']], // Retrieve enum from index
      );
}

// Define an enum for the discount type
enum DiscountType {
  Percentage,
  Price,
}


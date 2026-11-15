class StockProduct {
  final int id;
  final String serial;
  final String name;
  final double quantity;
  final double price;
  final double stockPrice;

  StockProduct({
    required this.id,
    required this.serial,
    required this.name,
    required this.quantity,
    required this.price,
    required this.stockPrice,
  });

  factory StockProduct.fromJson(Map<String, dynamic> j) => StockProduct(
        id: (j['id'] as num).toInt(),
        serial: j['serial']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        price: (j['price'] as num).toDouble(),
        stockPrice: (j['stock_price'] as num).toDouble(),
      );
}

class OrderDetailRow {
  final String orderNumber, time, productName;
  final double quantity;
  final bool highlight;

  OrderDetailRow({
    required this.orderNumber,
    required this.time,
    required this.productName,
    required this.quantity,
    required this.highlight,
  });

  factory OrderDetailRow.fromJson(Map<String, dynamic> j) => OrderDetailRow(
        orderNumber: j['order_number']?.toString() ?? '',
        time: j['time']?.toString() ?? '',
        productName: j['product_name']?.toString() ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        highlight: j['highlight'] == true,
      );
}
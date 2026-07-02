// lib/models.dart
import 'package:flutter/material.dart';

// Enum for discount types
enum DiscountType { Percentage, Price }

// Discount model
class Discount {
  final double value;
  final DiscountType type;

  Discount({required this.value, required this.type});

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'type': type.toString(),
    };
  }

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      value: json['value']?.toDouble() ?? 0.0,
      type: json['type'].toString().contains('Percentage') 
          ? DiscountType.Percentage 
          : DiscountType.Price,
    );
  }
}

// Product model
class Product {
  final String name;
  final String code;
  final double price;
  final double quantity;

  Product({
    required this.name,
    required this.code,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'price': price,
      'quantity': quantity,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      price: json['price']?.toDouble() ?? 0.0,
      quantity: json['quantity']?.toDouble() ?? 0.0,
    );
  }
}

// Order model
class Order {
  final String orderNumber;
  final List<Product> products;
  final double total;
  final DateTime timestamp;
  final String customerName;
  final String cashierName;

  Order({
    required this.orderNumber,
    required this.products,
    required this.total,
    required this.timestamp,
    required this.customerName,
    required this.cashierName,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderNumber': orderNumber,
      'products': products.map((p) => p.toJson()).toList(),
      'total': total,
      'timestamp': timestamp.toIso8601String(),
      'customerName': customerName,
      'cashierName': cashierName,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderNumber: json['orderNumber'] ?? '',
      products: (json['products'] as List? ?? []).map((p) => Product.fromJson(p)).toList(),
      total: json['total']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      customerName: json['customerName'] ?? '',
      cashierName: json['cashierName'] ?? '',
    );
  }
}
import 'dart:convert';
import 'addstock.dart';
import 'online/online.dart';
import 'settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import your pages and models here
// For demonstration, paths are placeholders and need to be replaced with actual paths in your project
import '../history.dart';
import 'cashup.dart';
import 'expensepage.dart';
import 'products.dart';
import 'sell_page.dart';
import 'storeinfo.dart';
import 'testprinter.dart';

class Order {
  final List<Product> products;
  final double total;
  final DateTime timestamp; // New field for timestamp

  Order({required this.products, required this.total, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'products': products.map((product) => product.toJson()).toList(),
        'total': total,
        'timestamp':
            timestamp.toIso8601String(), // Convert DateTime to a String
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        products: List<Product>.from(
            json["products"].map((x) => Product.fromJson(x))),
        total: json["total"].toDouble(),
        timestamp: DateTime.parse(
            json["timestamp"]), // Convert String back to DateTime
      );
}

class Product {
  final String name;
  final String code;
  final double price;
  final double quantity;

  Product(
      {required this.name,
      required this.code,
      required this.price,
      required this.quantity});

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'price': price,
        'quantity': quantity,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'],
      code: json['code'],
      price: json['price'].toDouble(),
      quantity: json['quantity'].toDouble(),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int totalOrders = 0;
  double totalRevenue = 0.0;
  String shopname = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> ordersJson = prefs.getStringList('orders') ?? [];
      var shopName = prefs.getString('fullname') ?? '';
      print("$shopName ");

      List<Order> loadedOrders = ordersJson
          .map((str) => Order.fromJson(json.decode(str)))
          .toList();

      setState(() {
        shopname = shopName;
        totalOrders = loadedOrders.length;
        totalRevenue =
            loadedOrders.fold(0.0, (sum, order) => sum + order.total);
      });
    } catch (e) {
      print('Error loading orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shopname),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildRevenueSection()), // Added Expanded
                  SizedBox(width: 16),
                  Expanded(child: _buildOrdersSection()), // Added Expanded
                ],
              ),
              SizedBox(height: 20),
              _buildFunctionalityButtons(context),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingBasket(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildOrdersSection() {
    return Container(
      height: 100,
      padding: EdgeInsets.all(12.0), // Adjusted padding value
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.shopping_cart, color: Colors.white, size: 40.0),
          SizedBox(width: 12), // Adjusted spacing value
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders:',
                style: TextStyle(fontSize: 18.0, color: Colors.white),
              ),
              SizedBox(height: 4), // Adjusted spacing value
              Text(
                '$totalOrders',
                style: TextStyle(fontSize: 24.0, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSection() {
    return Container(
      height: 100,
      padding: EdgeInsets.all(12.0), // Adjusted padding value
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.attach_money, color: Colors.white, size: 40.0),
          SizedBox(width: 12), // Adjusted spacing value
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revenue',
                style: TextStyle(fontSize: 18.0, color: Colors.white),
              ),
              SizedBox(height: 4), // Adjusted spacing value
              Text(
                '\$${totalRevenue.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 24.0, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionalityButtons(BuildContext context) {
    return Wrap(
      spacing: 16, // space between each child
      runSpacing: 16, // space between each row
      alignment: WrapAlignment.spaceEvenly,
      children: [
        _buildStyledIcon(
            Icons.add_shopping_cart,
            'Add Sell',
            () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => SellPage1()))),
        _buildStyledIcon(
            Icons.shopping_basket,
            'Products',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => ProductListPage()))),
        _buildStyledIcon(
            Icons.cloud_upload,
            'Upload Sales',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => ViewHistoryPage()))),
        _buildStyledIcon(
            Icons.money_off,
            'Expenses',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => ExpensePage()))),
        _buildStyledIcon(
            Icons.store,
            'Store Info',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => StoreInfoPage()))),
        _buildStyledIcon(
            Icons.business,
            'Back Office',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => MyOnlineApp()))),
        _buildStyledIcon(
            Icons.account_balance_wallet,
            'Cash Up',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => CashoutPage()))),
        _buildStyledIcon(
            Icons.inventory,
            'Add Stock',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => AddStockPage()))),
        _buildStyledIcon(
            Icons.print,
            'Configure printer',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => PrinterPage()))),
        _buildStyledIcon(
            Icons.settings,
            'Settings',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => SettingsPage()))),
      ],
    );
  }

  Widget _buildStyledIcon(IconData icon, String text, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5.0,
              spreadRadius: 1.0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40.0, color: Colors.blue),
            SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBasket() {
    return FloatingActionButton(
      onPressed: () {
        _loadOrders();
      },
      backgroundColor: Colors.green,
      child: Icon(Icons.refresh),
    );
  }
}

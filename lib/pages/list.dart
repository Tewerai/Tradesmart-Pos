import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

// Import your pages
import 'addstock.dart';
import 'online/online.dart';
import 'settings.dart';
import '../history.dart';
import 'cashup.dart';
import 'expensepage.dart';
import 'products.dart';
import 'sell_page.dart';
import 'storeinfo.dart';
import 'testprinter.dart';

// Model classes
class Order {
  final List<Product> products;
  final double total;
  final DateTime timestamp;

  Order({required this.products, required this.total, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'products': products.map((p) => p.toJson()).toList(),
        'total': total,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        products: List<Product>.from(
            json["products"].map((x) => Product.fromJson(x))),
        total: json["total"].toDouble(),
        timestamp: DateTime.parse(json["timestamp"]),
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _getThemePreference(),
      builder: (context, snapshot) {
        bool isDarkMode = snapshot.data ?? false;

        return MaterialApp(
          theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
          home: HomePage(),
        );
      },
    );
  }

  Future<bool> _getThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkMode') ?? false;
  }
}

class HomePage extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int totalOrders = 0;
  double totalRevenue = 0.0;
  String shopname = '';
  String shopId = '';
  String password = '';
  bool isLoading = false;
  bool useHamburgerDisplay = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _checkHamburgerSetting();
  }

  Future<void> _checkHamburgerSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useHamburgerDisplay = prefs.getBool('useHamburgerDisplay') ?? false;
    });
  }

  Future<void> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> ordersJson = prefs.getStringList('orders') ?? [];
      shopname = prefs.getString('fullname') ?? '';
      shopId = prefs.getString('username') ?? '';
      password = prefs.getString('password') ?? '';

      List<Order> loadedOrders =
          ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();

      setState(() {
        totalOrders = loadedOrders.length;
        totalRevenue =
            loadedOrders.fold(0.0, (sum, order) => sum + order.total);
      });
    } catch (e) {
      // print('Error loading orders: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e')),
      );
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        var response = await http.post(
          Uri.parse('https://aphel.blueichor.org/log2.php'),
          body: {'username': shopId, 'password': password},
        );

        if (response.statusCode == 200) {
          var jsondata = json.decode(response.body);
          if (jsondata["success"]) {
            final prefs = await SharedPreferences.getInstance();
            prefs.setString('categories', json.encode(jsondata['categories']));
            prefs.setString('products', json.encode(jsondata["products"]));
            prefs.setString('prices', json.encode(jsondata["prices"]));
            prefs.setString('codes', json.encode(jsondata["codes"]));
            prefs.setString('measure', json.encode(jsondata["measure"]));
            prefs.setString('quantities', json.encode(jsondata["quantities"]));
          }
        }
      } catch (e) {
        // print('Error fetching data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh data: $e')),
        );
      }
    } else {
      print('No internet connection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shopname),
        centerTitle: true,
      ),
      drawer: useHamburgerDisplay ? _buildDrawer() : null,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildRevenueSection()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildOrdersSection()),
                  ],
                ),
                const SizedBox(height: 20),
                if (!useHamburgerDisplay) _buildFunctionalityButtons(context),
                if (useHamburgerDisplay)
                  const Center(
                    child: Text(
                      'Use the menu to navigate',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Menu',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          _buildDrawerItem(Icons.add_shopping_cart, 'Add Sell', SellPage1()),
          _buildDrawerItem(
              Icons.shopping_basket, 'Products', ProductListPage()),
          _buildDrawerItem(
              Icons.cloud_upload, 'Upload Sales', ViewHistoryPage()),
          _buildDrawerItem(Icons.money_off, 'Expenses', ExpensePage()),
          _buildDrawerItem(Icons.store, 'Store Info', StoreInfoPage()),
          _buildDrawerItem(Icons.business, 'Back Office', MyOnlineApp()),
          _buildDrawerItem(
              Icons.account_balance_wallet, 'Cash Up', CashoutPage()),
          _buildDrawerItem(Icons.inventory, 'Add Stock', AddStockPage()),
          _buildDrawerItem(Icons.print, 'Configure printer', PrinterPage()),
          _buildDrawerItem(Icons.settings, 'Settings', SettingsPage()),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String text, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => page)),
    );
  }

  Widget _buildOrdersSection() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.blue, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.white, size: 40.0),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Orders:',
                  style: TextStyle(fontSize: 18.0, color: Colors.white)),
              Text('$totalOrders',
                  style: const TextStyle(fontSize: 20.0, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSection() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.green, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: Colors.white, size: 40.0),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Revenue:',
                  style: TextStyle(fontSize: 18.0, color: Colors.white)),
              Text('R$totalRevenue',
                  style: const TextStyle(fontSize: 20.0, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionalityButtons(BuildContext context) {
    // Expanded functionality buttons with larger icons
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16.0,
      runSpacing: 16.0,
      children: [
        _buildFunctionalityButton(
          context,
          Icons.add_shopping_cart,
          'Sell',
          SellPage1(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.shopping_basket,
          'Products',
          ProductListPage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.money_off,
          'Expenses',
          ExpensePage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.cloud_upload,
          'Upload Sales',
          ViewHistoryPage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.store,
          'Store Info',
          StoreInfoPage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.business,
          'Back Office',
          MyOnlineApp(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.account_balance_wallet,
          'Cash Up',
          CashoutPage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.inventory,
          'Add Stock',
          AddStockPage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.print,
          'Configure Printer',
          PrinterPage(),
        ),
        _buildFunctionalityButton(
          context,
          Icons.settings,
          'Settings',
          SettingsPage(),
        ),
      ],
    );
  }

  Widget _buildFunctionalityButton(
      BuildContext context, IconData icon, String label, Widget page) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      icon: Icon(icon, size: 32.0), // Larger icon size
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(120, 60), // Increase the button size
        textStyle: const TextStyle(fontSize: 18), // Adjust the font size
      ),
    );
  }
}

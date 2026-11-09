import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

// Import your pages
import 'addstock.dart';
import 'guards.dart';
import 'online/online.dart';
import 'online/zimra-backoffice.dart';
import 'settings.dart';
import '../history.dart'; // Keep if other parts of the app use it, otherwise remove
import 'cashup.dart';
import 'expensepage.dart';
import 'products.dart';
import 'sell_page.dart';
import 'storeinfo.dart';
import 'testprinter.dart';
import 'customers.dart'; // <--- NEW: Import the CustomerListPage
import 'invoice.dart'; // <--- NEW: Import the CustomerListPage
import '../fiscal_day_page.dart'; // <--- NEW: Fiscal Day page

// Model classes
class Order {
  final List<Product> products;
  final double total;
  final DateTime timestamp;
  String? cashierName;
  bool isRefunded;
  double refundAmount;
  final String orderNumber;

  Order({
    required this.products,
    required this.total,
    required this.timestamp,
    this.cashierName,
    this.isRefunded = false,
    this.refundAmount = 0.0,
    required this.orderNumber,
  });

  Map<String, dynamic> toJson() => {
        'products': products.map((p) => p.toJson()).toList(),
        'total': total,
        'timestamp': timestamp.toIso8601String(),
        'cashierName': cashierName,
        'isRefunded': isRefunded,
        'refundAmount': refundAmount,
        'orderNumber': orderNumber,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        products: List<Product>.from(
            json["products"].map((x) => Product.fromJson(x))),
        total: json["total"].toDouble(),
        timestamp: DateTime.parse(json["timestamp"]),
        cashierName: json['cashierName'],
        isRefunded: json['isRefunded'] ?? false,
        refundAmount: json['refundAmount'] ?? 0.0,
        orderNumber: json['orderNumber'],
      );
}

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
  String currencySymbol = '\$'; // Default currency symbol
  bool zimraEnabled = false; // <--- NEW: ZIMRA enabled flag

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    _loadOrders();
    _checkHamburgerSetting();
    _loadZimraStatus(); // <--- NEW: Load ZIMRA status
  }

  Future<void> _loadCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  Future<void> _checkHamburgerSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useHamburgerDisplay = prefs.getBool('useHamburgerDisplay') ?? false;
    });
  }

  // <--- NEW: Load ZIMRA status from SharedPreferences
  Future<void> _loadZimraStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      zimraEnabled = prefs.getBool('zimraEnabled') ?? false;
    });
    print('ZIMRA Enabled: $zimraEnabled');
  }

  Future<void> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> ordersJson = prefs.getStringList('orders') ?? [];
      shopname = prefs.getString('fullname') ?? '';
      shopId = prefs.getString('username') ?? '';
      password = prefs.getString('password') ?? '';

      // Load the hide total setting
      bool hideTotal = prefs.getBool('hideTotalOnHomepage') ?? false;

      List<Order> loadedOrders =
          ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();

      setState(() {
        totalOrders = loadedOrders.length;
        totalRevenue = hideTotal
            ? -1
            : loadedOrders.fold(0.0, (sum, order) => sum + order.total);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e')),
      );
    }
  }

  Future<void> _refreshData() async {
    // Reload orders and total revenue
    await _loadOrders();
    setState(() {
      isLoading = true;
    });

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        var response = await http.post(
          Uri.parse('https://blueichor.org/log2.php'),
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

            // <--- NEW: Update ZIMRA status from refresh
            if (jsondata['zimra_enabled'] != null) {
              int zimraEnabledInt = jsondata['zimra_enabled'];
              prefs.setInt('zimra_enabled', zimraEnabledInt);
              prefs.setBool('zimraEnabled', zimraEnabledInt == 1);
              setState(() {
                zimraEnabled = zimraEnabledInt == 1;
              });
            }
          }
        }
      } catch (e) {
        // print('Error fetching data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to refresh data make sure internet connection is available')),
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
          _buildDrawerItem(Icons.add_shopping_cart, 'Sell', SellPage1()),
          _buildDrawerItem(
              Icons.shopping_basket, 'Products', ProductListPage()),
          _buildDrawerItem(
              Icons.group, 'Customers', const CustomerListPage()),
          _buildDrawerItem(
              Icons.cloud_upload, 'Upload Sales', ViewHistoryPage()),
          _buildDrawerItem(Icons.money_off, 'Expenses', ExpensePage()),
          _buildDrawerItem(Icons.store, 'Store Info', StoreInfoPage()),
          _buildDrawerItem(Icons.business, 'Back Office', MyOnlineApp()),
          _buildDrawerItem(
              Icons.account_balance_wallet, 'Cash Up', CashoutPage()),
          _buildDrawerItem(Icons.inventory, 'Add Stock', AddStockPage()),
          _buildDrawerItem(Icons.print, 'Configure Printer', PrinterPage()),
          _buildDrawerItem(Icons.settings, 'Settings', SettingsPage()),
          _buildDrawerItem(Icons.security, 'Guard', GuardApp()),
          // <--- NEW: Only show ZIMRA if enabled
          /*if (zimraEnabled)
            _buildDrawerItem(Icons.satellite_alt, 'Zimra', ZimraApp()),*/
          // <--- NEW: Fiscal Day page — only show if ZIMRA is enabled
          if (zimraEnabled)
            _buildDrawerItem(
                Icons.event_available, 'Fiscal Day', const FiscalDayPage()),
          // <--- NEW: Only show Invoice if enabled (optional)
          // _buildDrawerItem(Icons.sell_sharp, 'Invoice', InvoicePage1()),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String text, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () {
        Navigator.pop(context); // Close the drawer before navigating
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => page));
      },
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
              const Text('Revenue:',
                  style: TextStyle(fontSize: 18.0, color: Colors.white)),
              Text(
                totalRevenue == -1
                    ? 'XX'
                    : '$currencySymbol${totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20.0, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionalityButtons(BuildContext context) {
    // Button data
    final List<Map<String, dynamic>> buttons = [
      {'icon': Icons.add_shopping_cart, 'label': 'Sell', 'page': SellPage1()},
      {
        'icon': Icons.shopping_basket,
        'label': 'Products',
        'page': ProductListPage()
      },
      {'icon': Icons.group, 'label': 'Customers', 'page': const CustomerListPage()},
      {'icon': Icons.money_off, 'label': 'Expenses', 'page': ExpensePage()},
      {
        'icon': Icons.cloud_upload,
        'label': 'Upload Sales',
        'page': ViewHistoryPage()
      },
      {'icon': Icons.store, 'label': 'Store Info', 'page': StoreInfoPage()},
      {'icon': Icons.business, 'label': 'Back Office', 'page': MyOnlineApp()},
      {
        'icon': Icons.account_balance_wallet,
        'label': 'Cash Up',
        'page': CashoutPage()
      },
      {'icon': Icons.inventory, 'label': 'Add Stock', 'page': AddStockPage()},
      {
        'icon': Icons.print,
        'label': 'Configure Printer',
        'page': PrinterPage()
      },
      {'icon': Icons.settings, 'label': 'Settings', 'page': SettingsPage()},
      {'icon': Icons.security, 'label': 'Guards', 'page': GuardApp()},
      {'icon': Icons.sell_sharp, 'label': 'Invoice', 'page': InvoicePage1()},
      // <--- NEW: Only show ZIMRA if enabled
     /* if (zimraEnabled)
        {'icon': Icons.satellite_alt, 'label': 'Zimra', 'page': ZimraApp()},*/
      // <--- NEW: Fiscal Day button — only show if ZIMRA is enabled
      if (zimraEnabled)
        {
          'icon': Icons.event_available,
          'label': 'Fiscal Day',
          'page': const FiscalDayPage(),
        },
    ];

    return Expanded(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 buttons per row
          crossAxisSpacing: 16.0, // Space between buttons horizontally
          mainAxisSpacing: 16.0, // Space between buttons vertically
          childAspectRatio: 1.0, // Aspect ratio for a square-like button
        ),
        padding: const EdgeInsets.all(16.0), // Padding around the grid
        itemCount: buttons.length, // Dynamically get the count
        itemBuilder: (context, index) {
          return _buildFunctionalityButton(
            context,
            buttons[index], // Pass the entire button data
          );
        },
      ),
    );
  }

  Widget _buildFunctionalityButton(
      BuildContext context, Map<String, dynamic> buttonData) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => buttonData['page']),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8.0,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(buttonData['icon'], size: 40.0, color: Colors.blueAccent),
            const SizedBox(height: 8.0),
            Text(
              buttonData['label'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
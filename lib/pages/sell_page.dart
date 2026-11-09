// ignore_for_file: depend_on_referenced_packages, unnecessary_import
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // <--- ADDED FOR RANDOM UNIQUE IDs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradesmart/pages/services/notification_services.dart';
import '../services/inventory_service.dart';
import 'package:vibration/vibration.dart';
import 'printer2.dart';

// --- FIXED IMPORTS HERE ---
import 'widgets/sell.dart' hide Order, Product, Discount, DiscountType;
import 'widgets/historyOrder.dart';
// ---------------------------

import 'credit_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(SellPage1());
}

class SellPage1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SellingPage(),
    );
  }
}

class SellingPage extends StatefulWidget {
  @override
  _SellingPageState createState() => _SellingPageState();
}

class _SellingPageState extends State<SellingPage> {
  Map<String, double> itemQuantities = {};
  double totalPrice = 0.0;
  String searchText = '';
  Discount? appliedDiscount;
  bool _isProcessingOrder = false;

  int orderNumberCounter = 1;

  double get totalItems =>
      itemQuantities.values.fold(0, (sum, quantity) => sum + quantity);

  String fullname = '';
  List<dynamic> products = [];
  List<dynamic> price = [];
  List<dynamic> codes = [];
  List<dynamic> cats = [];
  List<String> categories = [];
  String? selectedCategory;
  List<dynamic> measures = [];
  String currencySymbol = '\$';
  Map<String, double> quickSalePrices = {};
  String shopname = '';

  List<int> quantitiesList = [];
  String shopId = '';
  String password = '';
  bool isLoading = false;

  bool _allowSellOutOfStock = false;
  bool _allowAutomaticUpload = false;
  Set<String> _notifiedLowStockProducts = {};
  Set<String> _notifiedOutOfStockProducts = {};
  int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    loadCurrencySymbol();
    _loadAllowSellOutOfStockSetting();
    _loadData();
    _loadCategories();
    _loadProductQuantities();
    _automaticUpload();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();
    await _loadLowStockThreshold();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllProductsStock();
    });
  }

  Future<void> _loadLowStockThreshold() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowStockThreshold = prefs.getInt('lowStockThreshold') ?? 5;
    });
  }

  void _checkAllProductsStock() {
    if (quantitiesList.isEmpty) return;

    List<Map<String, dynamic>> lowStockProducts = [];

    for (int i = 0; i < products.length; i++) {
      if (i < quantitiesList.length) {
        int quantity = quantitiesList[i];
        String productName = products[i];

        if (quantity <= 0) {
          if (!_notifiedOutOfStockProducts.contains(productName)) {
            _notifiedOutOfStockProducts.add(productName);
            NotificationService.showOutOfStockNotification(
              productName: productName,
              shopName: shopname,
            );
          }
        } else if (quantity <= _lowStockThreshold) {
          if (!_notifiedLowStockProducts.contains(productName)) {
            _notifiedLowStockProducts.add(productName);
            lowStockProducts.add({
              'name': productName,
              'quantity': quantity,
            });
          }
        } else {
          _notifiedLowStockProducts.remove(productName);
          _notifiedOutOfStockProducts.remove(productName);
        }
      }
    }

    if (lowStockProducts.isNotEmpty) {
      NotificationService.showMultipleLowStockNotification(
        lowStockProducts: lowStockProducts,
        shopName: shopname,
      );
    }
  }

  Future<void> _loadProductQuantities() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? quantitiesJson = prefs.getString('quantities');

    if (quantitiesJson != null) {
      try {
        List<dynamic> parsedList = jsonDecode(quantitiesJson);
        setState(() {
          quantitiesList = parsedList
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .toList();
        });
        print('Quantities loaded: $quantitiesList');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAllProductsStock();
        });
      } catch (e) {
        print("Error loading quantities: $e");
        quantitiesList = [];
      }
    } else {
      print('No quantities found');
      quantitiesList = [];
    }
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  Future<void> _loadAllowSellOutOfStockSetting() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowSellOutOfStock = prefs.getBool('allowSellOutOfStock') ?? false;
    });
  }

  Future<void> _saveAllowSellOutOfStockSetting(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allowSellOutOfStock', value);
    setState(() {
      _allowSellOutOfStock = value;
    });
    showToast(value
        ? 'Sell out of stock: ENABLED'
        : 'Sell out of stock: DISABLED');
  }

  Future<void> _automaticUpload() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowAutomaticUpload = prefs.getBool('automaticUpload') ?? false;
    });
  }

  Future<void> _loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      fullname = prefs.getString('fullname') ?? '';
      products =
          (jsonDecode(prefs.getString('products') ?? '[]') as List<dynamic>)
              .cast<String>();
      price = (jsonDecode(prefs.getString('prices') ?? '[]') as List<dynamic>)
          .cast<String>();
      codes = (jsonDecode(prefs.getString('codes') ?? '[]') as List<dynamic>)
          .cast<String>();
      measures =
          (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>)
              .cast<String>();
    });

    shopId = prefs.getString('username') ?? '';
    password = prefs.getString('password') ?? '';
  }

  Future<void> _loadCategories() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? categoriesJson = prefs.getString('categories');
    if (categoriesJson != null) {
      try {
        List<dynamic> decodedCategories = json.decode(categoriesJson);
        final Set<String> categorySet = decodedCategories
            .where((category) =>
                category != null && category is String && category.isNotEmpty)
            .cast<String>()
            .toSet();
        final List<String> filteredCategories = categorySet.toList();

        setState(() {
          categories = ['All', ...filteredCategories];
          selectedCategory = 'All';
          cats = decodedCategories;
        });
      } catch (e) {
        print("Error decoding categories: $e");
      }
    } else {
      print("No categories found in SharedPreferences.");
    }
  }

  int _getFilteredItemCount() {
    final filteredProducts = _getFilteredProducts();
    return filteredProducts.length;
  }

  List<String> _getFilteredProducts() {
    List<String> filteredProducts = [];

    if (selectedCategory == null || selectedCategory == "All") {
      filteredProducts.addAll(products.cast<String>());
    } else {
      for (int i = 0; i < products.length; i++) {
        if (i < cats.length && cats[i] != null) {
          String productCategory = cats[i];
          if (productCategory == selectedCategory) {
            filteredProducts.add(products[i] as String);
          }
        }
      }
    }

    if (searchText.isNotEmpty) {
      filteredProducts = filteredProducts
          .where((item) => item.toLowerCase().contains(searchText.toLowerCase()))
          .toList();
    }

    return filteredProducts;
  }

  Future<String> _getImagePath(String productName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/$productName.jpg';
      if (await File(imagePath).exists()) {
        return imagePath;
      }
      return '';
    } catch (e) {
      print("Error checking image for $productName: $e");
      return '';
    }
  }

  void _manualStockCheck() {
    _checkAllProductsStock();
    showToast('Stock check completed');
  }

  void _resetNotificationTracking() {
    setState(() {
      _notifiedLowStockProducts.clear();
      _notifiedOutOfStockProducts.clear();
    });
    _checkAllProductsStock();
    showToast('Notification tracking reset');
  }

  void _showStockSettingsDialog(BuildContext context) {
    TextEditingController thresholdController = TextEditingController(
      text: _lowStockThreshold.toString(),
    );
    bool allowOutOfStock = _allowSellOutOfStock;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Stock Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Low Stock Alert Threshold',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter threshold (e.g., 5)',
                        suffixText: 'units',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _lowStockThreshold = int.tryParse(value) ?? 5;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text(
                        'Allow Selling Out of Stock',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Enable to allow selling items even when stock is 0',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: allowOutOfStock,
                      onChanged: (bool value) {
                        setState(() {
                          allowOutOfStock = value;
                          _allowSellOutOfStock = value;
                          _saveAllowSellOutOfStockSetting(value);
                        });
                      },
                      activeColor: Colors.green,
                      secondary: Icon(
                        allowOutOfStock ? Icons.check_circle : Icons.cancel,
                        color: allowOutOfStock ? Colors.green : Colors.red,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Notification Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Low Stock Alerts:'),
                              Text(
                                '${_notifiedLowStockProducts.length} products',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Out of Stock Alerts:'),
                              Text(
                                '${_notifiedOutOfStockProducts.length} products',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _manualStockCheck();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Check Stock'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _resetNotificationTracking();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.notifications_off, size: 18),
                            label: const Text('Reset Alerts'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('lowStockThreshold', _lowStockThreshold);
                    await prefs.setBool(
                        'allowSellOutOfStock', _allowSellOutOfStock);
                    _checkAllProductsStock();
                    Navigator.pop(context);
                    showToast('Settings saved and stock checked');
                  },
                  child: const Text('Save & Check'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenWidth > 600;
    final isLandscape = screenWidth > screenHeight;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Shopping Page',
                style: TextStyle(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: DropdownButton<String>(
                hint: const Text('Categories'),
                value: selectedCategory,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedCategory = newValue;
                  });
                },
                items: categories.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card),
            onPressed: _showCreditsList,
            tooltip: 'Credit Records',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showStockSettingsDialog(context);
            },
            tooltip: 'Stock Settings',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: _manualStockCheck,
            tooltip: 'Check stock levels',
          ),
          IconButton(
            icon: const Icon(Icons.notification_important),
            onPressed: _resetNotificationTracking,
            tooltip: 'Reset notification tracking',
          ),
          if (_notifiedLowStockProducts.isNotEmpty ||
              _notifiedOutOfStockProducts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_notifiedLowStockProducts.length + _notifiedOutOfStockProducts.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isProcessingOrder
          ? _buildLoadingIndicator()
          : Row(
              children: [
                Expanded(
                  flex: isLargeScreen ? 65 : 100,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: 'Search',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    onPressed: () {
                                      _scanBarcode();
                                    },
                                  ),
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    searchText = text.toLowerCase();
                                  });
                                },
                              ),
                            ),
                            if (_allowSellOutOfStock)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Sell OOS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isLandscape ? 4 : 3,
                            childAspectRatio: isLandscape ? 0.8 : 0.7,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                          ),
                          itemCount: _getFilteredItemCount(),
                          itemBuilder: (context, index) {
                            final filteredProducts = _getFilteredProducts();

                            if (index < filteredProducts.length) {
                              final itemName = filteredProducts[index];
                              final itemPrice =
                                  price[products.indexOf(itemName)];
                              final productIndex = products.indexOf(itemName);
                              final productCode =
                                  productIndex != -1 ? codes[productIndex] : '';

                              final int availableQuantity =
                                  productIndex != -1 &&
                                          productIndex < quantitiesList.length
                                      ? quantitiesList[productIndex]
                                      : 0;

                              final bool isOutOfStock =
                                  quantitiesList.isNotEmpty &&
                                      availableQuantity <= 0;

                              return Card(
                                color: (!_allowSellOutOfStock && isOutOfStock)
                                    ? Colors.grey[200]
                                    : null,
                                child: InkWell(
                                  onTap: () async {
                                    if (isOutOfStock && !_allowSellOutOfStock) {
                                      showToast('⚠️ $itemName is out of stock');
                                      return;
                                    }

                                    String measureType = measures[productIndex];
                                    double itemKgPrice =
                                        double.tryParse(price[productIndex]) ??
                                            0.0;
                                    String itemCode = codes[productIndex];

                                    if (measureType == "kgs" ||
                                        measureType == "metres" ||
                                        measureType == "centimetres" ||
                                        measureType == "lbs") {
                                      _showKgsDialog(
                                          context, itemName, itemKgPrice);
                                    } else if (measureType == "units") {
                                      bool canAdd =
                                          await _checkQuantityBeforeAdding(
                                              itemName,
                                              itemCode,
                                              1,
                                              availableQuantity);

                                      if (canAdd && mounted) {
                                        setState(() {
                                          itemQuantities.update(
                                              itemName, (value) => ++value,
                                              ifAbsent: () => 1);
                                          totalPrice += double.parse(itemPrice);
                                        });
                                      }
                                    }
                                  },
                                  onLongPress: () {
                                    if (isOutOfStock && !_allowSellOutOfStock) {
                                      showToast('⚠️ $itemName is out of stock');
                                      return;
                                    }
                                    _showQuantityDialog(context, itemName);
                                  },
                                  child: Opacity(
                                    opacity:
                                        (!_allowSellOutOfStock && isOutOfStock)
                                            ? 0.5
                                            : 1.0,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        FutureBuilder<String>(
                                          future: _getImagePath(itemName),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const CircularProgressIndicator();
                                            }
                                            if (snapshot.hasData &&
                                                snapshot.data!.isNotEmpty) {
                                              return Image.file(
                                                File(snapshot.data!),
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                                color: (!_allowSellOutOfStock &&
                                                        isOutOfStock)
                                                    ? Colors.grey
                                                    : null,
                                                colorBlendMode:
                                                    (!_allowSellOutOfStock &&
                                                            isOutOfStock)
                                                        ? BlendMode.saturation
                                                        : null,
                                              );
                                            }
                                            return Icon(
                                              Icons.shopping_basket,
                                              size: 80,
                                              color: (!_allowSellOutOfStock &&
                                                      isOutOfStock)
                                                  ? Colors.grey
                                                  : null,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8.0),
                                        Text(
                                          itemName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLandscape ? 12 : 14,
                                            color: (!_allowSellOutOfStock &&
                                                    isOutOfStock)
                                                ? Colors.grey
                                                : null,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Price: $currencySymbol${itemPrice}',
                                          style: TextStyle(
                                              fontSize: isLandscape ? 11 : 13,
                                              color: (!_allowSellOutOfStock &&
                                                      isOutOfStock)
                                                  ? Colors.grey
                                                  : null),
                                        ),
                                        if (quantitiesList.isEmpty)
                                          Text(
                                            'Stock: Available',
                                            style: TextStyle(
                                                fontSize: isLandscape ? 10 : 11,
                                                color: Colors.green),
                                          )
                                        else if (isOutOfStock)
                                          Text(
                                            _allowSellOutOfStock
                                                ? 'OUT OF STOCK (Sell Allowed)'
                                                : 'OUT OF STOCK',
                                            style: TextStyle(
                                                fontSize: isLandscape ? 10 : 11,
                                                color: _allowSellOutOfStock
                                                    ? Colors.orange
                                                    : Colors.red,
                                                fontWeight: FontWeight.bold),
                                          )
                                        else
                                          Text(
                                            'Stock: $availableQuantity',
                                            style: TextStyle(
                                                fontSize: isLandscape ? 10 : 11,
                                                color: availableQuantity < 5
                                                    ? Colors.orange
                                                    : Colors.green),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return null;
                            }
                          },
                        ),
                      ),
                      if (!isLargeScreen)
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProcessingOrder
                                ? null
                                : () {
                                    _showOrderDialog(context);
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Complete Order $currencySymbol${totalPrice.toStringAsFixed(2)}'),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '$totalItems',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isLargeScreen)
                  Container(
                    width: screenWidth * 0.35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(left: BorderSide(color: Colors.grey[300]!)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(-2, 0),
                        ),
                      ],
                    ),
                    child: _buildOrderPanel(),
                  ),
              ],
            ),
    );
  }

  Widget _buildOrderPanel() {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: itemQuantities.isEmpty
              ? const Center(
                  child: Text(
                    'No items added yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: itemQuantities.entries.map((entry) {
                        String itemName = entry.key;
                        double quantity = entry.value;
                        int productIndex = products.indexOf(itemName);
                        double itemPrice;
                        if (productIndex != -1) {
                          itemPrice = double.parse(price[productIndex]);
                        } else {
                          itemPrice = quickSalePrices[itemName] ?? 0.0;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Quantity: ${quantity.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red,
                                              size: 22),
                                          onPressed: () =>
                                              _updateQuantitySidePanel(
                                                  itemName, -1),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.green,
                                              size: 22),
                                          onPressed: () =>
                                              _updateQuantitySidePanel(
                                                  itemName, 1),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$currencySymbol${(quantity * itemPrice).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Price each: $currencySymbol${itemPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 2),
              ),
              color: Colors.grey[50],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(),
                      child: ElevatedButton(
                        onPressed: _isProcessingOrder
                            ? null
                            : () {
                                _showCalculatorDialog(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Complete Order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$currencySymbol${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$totalItems',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showDiscountDialog(context);
                            },
                            icon: const Icon(Icons.local_offer, size: 20),
                            label: const Text('Apply Discount',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed:
                                _isProcessingOrder ? null : _saveOrderAsDraft,
                            icon: const Icon(Icons.save, size: 20),
                            label: const Text('Save Draft',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showQuickSaleDialog(context);
                            },
                            icon: const Icon(Icons.flash_on, size: 20),
                            label: const Text('Quick Sale',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _saveCredit(-totalPrice);
                            },
                            icon: const Icon(Icons.credit_card, size: 20),
                            label: const Text('Credit',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                itemQuantities.clear();
                                totalPrice = 0.0;
                              });
                              showToast('Cart cleared');
                            },
                            icon: const Icon(Icons.delete_sweep, size: 20),
                            label: const Text('Clear Cart',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showOrderDialog(context);
                            },
                            icon: const Icon(Icons.list_alt, size: 20),
                            label: const Text('View Order Details',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        if (itemQuantities.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10, top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Summary',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Items:',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      '$totalItems',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      '$currencySymbol${totalPrice.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                                if (appliedDiscount != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Discount:',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.purple),
                                        ),
                                        Text(
                                          appliedDiscount!.type ==
                                                  DiscountType.Percentage
                                              ? '${appliedDiscount!.value}%'
                                              : '-$currencySymbol${appliedDiscount!.value.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateQuantitySidePanel(String itemName, int change) async {
    if (change < 0) {
      setState(() {
        double newQuantity = (itemQuantities[itemName] ?? 0) + change;
        if (newQuantity <= 0) {
          itemQuantities.remove(itemName);
        } else {
          itemQuantities[itemName] = newQuantity;
        }
        _recalculateTotal();
      });
      return;
    }

    int productIndex = products.indexOf(itemName);
    if (productIndex != -1) {
      String itemCode = codes[productIndex];
      int availableQuantity = productIndex < quantitiesList.length
          ? quantitiesList[productIndex]
          : 0;

      bool canAdd = await _checkQuantityBeforeAdding(
          itemName, itemCode, change.toDouble(), availableQuantity);

      if (canAdd && mounted) {
        setState(() {
          double newQuantity = (itemQuantities[itemName] ?? 0) + change;
          itemQuantities[itemName] = newQuantity;
          _recalculateTotal();
        });
      }
    } else {
      setState(() {
        double newQuantity = (itemQuantities[itemName] ?? 0) + change;
        itemQuantities[itemName] = newQuantity;
        _recalculateTotal();
      });
    }
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Processing order...\nChecking internet connection...',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    try {
      String barcodeScanRes;
      print('Code Activated');
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666",
        "Cancel",
        true,
        ScanMode.DEFAULT,
      );
      if (!mounted) {
        return;
      }

      print('Barcode: $barcodeScanRes');

      int barcodeIndex = codes.indexOf(barcodeScanRes);

      if (barcodeIndex != -1) {
        String productName = products[barcodeIndex];
        String itemPrice = price[barcodeIndex];
        String itemCode = codes[barcodeIndex];

        int availableQuantity = barcodeIndex < quantitiesList.length
            ? quantitiesList[barcodeIndex]
            : 0;

        if (quantitiesList.isNotEmpty &&
            availableQuantity <= 0 &&
            !_allowSellOutOfStock) {
          showToast('⚠️ $productName is out of stock');
          return;
        }

        String measureType = measures[barcodeIndex];
        if (measureType == "kgs" ||
            measureType == "metres" ||
            measureType == "centimetres" ||
            measureType == "lbs") {
          double itemKgPrice = double.tryParse(itemPrice) ?? 0.0;
          _showKgsDialog(context, productName, itemKgPrice);
        } else {
          bool canAdd = await _checkQuantityBeforeAdding(
              productName, itemCode, 1, availableQuantity);

          if (canAdd && mounted) {
            setState(() {
              itemQuantities.update(productName, (value) => ++value,
                  ifAbsent: () => 1);
              totalPrice += double.parse(itemPrice);
            });
            Vibration.vibrate(duration: 500);
          }
        }
        print(itemQuantities);
      } else {
        print('Product not found for barcode: $barcodeScanRes');
        showToast('Product not found');
      }
    } catch (e) {
      print('Error: $e');
      showToast("Error: $e");
    }
  }

  void _showQuantityDialog(BuildContext context, String itemName) {
    final TextEditingController _quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Quantity for $itemName'),
          content: TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final double quantity =
                    double.tryParse(_quantityController.text) ?? 0;
                if (quantity > 0) {
                  int productIndex = products.indexOf(itemName);
                  if (productIndex != -1) {
                    String itemCode = codes[productIndex];
                    int availableQuantity =
                        productIndex < quantitiesList.length
                            ? quantitiesList[productIndex]
                            : 0;

                    bool canAdd = await _checkQuantityBeforeAdding(
                        itemName, itemCode, quantity, availableQuantity);

                    if (canAdd && mounted) {
                      setState(() {
                        itemQuantities.update(
                            itemName, (value) => value + quantity,
                            ifAbsent: () => quantity);
                        totalPrice +=
                            double.parse(price[productIndex]) * quantity;
                      });
                    }
                  }
                }
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...itemQuantities.entries.map((entry) {
                    String itemName = entry.key;
                    double quantity = entry.value;
                    int productIndex = products.indexOf(itemName);
                    double itemPrice;
                    if (productIndex != -1) {
                      itemPrice = double.parse(price[productIndex]);
                    } else {
                      itemPrice = quickSalePrices[itemName] ?? 0.0;
                    }

                    return Column(
                      children: [
                        ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$itemName x ${quantity.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () =>
                                        _updateQuantity(context, itemName, -1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () =>
                                        _updateQuantity(context, itemName, 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Text(
                              'Price: $currencySymbol${(quantity * itemPrice).toStringAsFixed(2)}'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                  SizedBox(
                    height: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _showDiscountDialog(context);
                              },
                              icon: const Icon(Icons.local_offer),
                              label: const Text('Apply Discount'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showCalculatorDialog(context);
                              },
                              icon: const Icon(Icons.calculate),
                              label: const Text('Complete'),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _isProcessingOrder ? null : _saveOrderAsDraft,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Draft'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showQuickSaleDialog(context);
                              },
                              icon: const Icon(Icons.flash_on),
                              label: const Text('Quick Sale'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuickSaleDialog(BuildContext context) {
    TextEditingController productNameController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    List<String> matchingProducts = [];
    String? selectedProductCode;
    List<String> productNames = products.map((e) => e.toString()).toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Quick Sale'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return productNames.where((product) => product
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      productNameController.text = selection;
                      int index = productNames.indexOf(selection);
                      if (index != -1 && index < codes.length) {
                        selectedProductCode = codes[index].toString();
                      }
                      setState(() {});
                    },
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController fieldController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: productNameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            matchingProducts = productNames
                                .where((product) => product
                                    .toLowerCase()
                                    .contains(value.toLowerCase()))
                                .toList();
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: currencySymbol,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (matchingProducts.isNotEmpty &&
                      productNameController.text.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: matchingProducts.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(matchingProducts[index]),
                            onTap: () {
                              productNameController.text =
                                  matchingProducts[index];
                              int productIndex =
                                  productNames.indexOf(matchingProducts[index]);
                              if (productIndex != -1 &&
                                  productIndex < codes.length) {
                                selectedProductCode =
                                    codes[productIndex].toString();
                              }
                              setState(() {
                                matchingProducts = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (productNameController.text.isNotEmpty &&
                        priceController.text.isNotEmpty) {
                      double priceValue =
                          double.tryParse(priceController.text) ?? 0.0;
                      String productName = productNameController.text;

                      setState(() {
                        itemQuantities.update(
                          productName,
                          (value) => value + 1,
                          ifAbsent: () => 1,
                        );
                        quickSalePrices[productName] = priceValue;
                        totalPrice += priceValue;
                      });

                      Navigator.of(context).pop();
                      Future.delayed(Duration.zero, () {
                        _showOrderDialog(context);
                      });
                    } else {
                      showToast('Please enter both product name and price');
                    }
                  },
                  child: const Text('Add to Sale'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCalculatorDialog(BuildContext context) {
    TextEditingController _controller = TextEditingController();
    String changeText = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            double enteredAmount = double.tryParse(_controller.text) ?? 0.0;
            double currentChange = enteredAmount - totalPrice;

            return AlertDialog(
              title: const Text('Received Amount'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Enter amount',
                    ),
                    onChanged: (value) {
                      setState(() {
                        double enteredValue = double.tryParse(value) ?? 0.0;
                        double result = enteredValue - totalPrice;
                        changeText =
                            'Change: $currencySymbol${result.toStringAsFixed(2)}';
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(changeText,
                      style:
                          const TextStyle(color: Colors.blue, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Amount due: $currencySymbol${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton.icon(
                  onPressed: _isProcessingOrder
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _showCreditDetailsDialog(context);
                        },
                  icon: const Icon(Icons.credit_card, color: Colors.orange),
                  label: const Text(
                    'Credit',
                    style: TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _isProcessingOrder || currentChange < 0
                      ? null
                      : () async {
                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setString(
                              'changes', currentChange.toString());
                          _finalizeOrder();
                          Navigator.of(context).pop();
                        },
                  child: const Text('Complete'),
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreditDetailsDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    DateTime? expectedDate = DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: expectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setState(() => expectedDate = picked);
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.credit_card, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Credit Sale Details'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Amount on Credit:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                '$currencySymbol${totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Debtor Full Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Phone is required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Address is required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expected Repayment Date *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              expectedDate == null
                                  ? 'Tap to select date'
                                  : '${expectedDate!.day}/${expectedDate!.month}/${expectedDate!.year}',
                              style: TextStyle(
                                color: expectedDate == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm Credit Sale'),
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      if (expectedDate == null) {
                        showToast('Please select expected date');
                        return;
                      }
                      Navigator.of(ctx).pop(true);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      await _finalizeCreditOrder(
        debtorName: nameCtrl.text.trim(),
        debtorPhone: phoneCtrl.text.trim(),
        debtorAddress: addressCtrl.text.trim(),
        debtorEmail: emailCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        expectedDate: expectedDate!,
      );
    }
  }

  Future<void> _finalizeCreditOrder({
    required String debtorName,
    required String debtorPhone,
    required String debtorAddress,
    required String debtorEmail,
    required String notes,
    required DateTime expectedDate,
  }) async {
    setState(() => _isProcessingOrder = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isConnected =
          await InternetConnection().hasInternetAccess;

      List<Product> orderProducts = [];
      double originalTotal = 0;
      for (var entry in itemQuantities.entries) {
        final idx = products.indexOf(entry.key);
        final name = entry.key;
        final qty = entry.value;
        double p;
        String code;
        if (idx != -1 && idx < codes.length) {
          code = codes[idx];
          p = double.tryParse(price[idx]) ?? 0.0;
        } else {
          p = quickSalePrices[name] ?? 0.0;
          final sanitized = name.replaceAll(RegExp(r'\s+'), '');
          final rnd = DateTime.now().millisecondsSinceEpoch.remainder(10000);
          code = 'QK_${sanitized}_$rnd';
        }
        orderProducts.add(
            Product(name: name, code: code, price: p, quantity: qty));
        originalTotal += p * qty;
      }

      if (orderProducts.isEmpty) {
        showToast('No products in cart');
        setState(() => _isProcessingOrder = false);
        return;
      }

      final cashierName = await _getActiveCashierName() ?? '';
      
      // --- ADDED RANDOM SUFFIX ---
      final orderNumber = 'CRD-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

      final credit = CreditRecord(
        id: orderNumber,
        debtorName: debtorName,
        debtorPhone: debtorPhone,
        debtorAddress: debtorAddress,
        debtorEmail: debtorEmail.isEmpty ? null : debtorEmail,
        amount: totalPrice,
        expectedDate: expectedDate,
        createdAt: DateTime.now(),
        orderNumber: orderNumber,
        cashierName: cashierName,
        products: orderProducts
            .map((p) => {
                  'name': p.name,
                  'code': p.code,
                  'price': p.price,
                  'quantity': p.quantity,
                })
            .toList(),
        notes: notes.isEmpty ? null : notes,
      );

      final creditList = prefs.getStringList('credits') ?? <String>[];
      creditList.add(jsonEncode(credit.toJson()));
      await prefs.setStringList('credits', creditList);

      final creditorsList =
          prefs.getStringList('creditors') ?? <String>[];
      final creditorEntry = jsonEncode({
        'name': debtorName,
        'phone': debtorPhone,
        'address': debtorAddress,
        'email': debtorEmail,
        'creditId': orderNumber,
        'amount': totalPrice,
        'expectedDate': expectedDate.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      creditorsList.add(creditorEntry);
      await prefs.setStringList('creditors', creditorsList);

      final order = Order(
        orderNumber: orderNumber,
        products: orderProducts,
        total: totalPrice,
        timestamp: DateTime.now(),
        customerName: debtorName,
        cashierName: cashierName,
        appliedDiscount: appliedDiscount,
      );
      final orderJson = jsonEncode(order.toJson());

      _saveOrderLocally(prefs, orderJson);

      if (isConnected && _allowAutomaticUpload) {
        try {
          await _uploadOrderToServer(orderJson, order);
        } catch (e) {
          print('Credit order upload failed: $e');
        }
      }

      showToast(
          'Credit sale recorded for $debtorName (due ${expectedDate.day}/${expectedDate.month}/${expectedDate.year})');

      setState(() {
        itemQuantities.clear();
        totalPrice = 0.0;
        appliedDiscount = null;
        _isProcessingOrder = false;
      });

      if (mounted) {
        // --- PASSING THE ORDER DIRECTLY ---
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => PrinterPage(order: order)),
        );
      }
    } catch (e) {
      print('Credit finalize error: $e');
      showToast('Failed to record credit sale: $e');
      setState(() => _isProcessingOrder = false);
    }
  }

  void _showCreditsList() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('credits') ?? [];
    final credits = list
        .map((s) => CreditRecord.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: 560,
          height: 560,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Credit Records (${credits.length})',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: credits.isEmpty
                    ? const Center(child: Text('No credits recorded'))
                    : ListView.separated(
                        itemCount: credits.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = credits[i];
                          final overdue = DateTime.now()
                              .isAfter(c.expectedDate);
                          return ListTile(
                            leading: Icon(
                              Icons.credit_card,
                              color: c.settled
                                  ? Colors.green
                                  : (overdue ? Colors.red : Colors.orange),
                            ),
                            title: Text(
                                '${c.debtorName} — $currencySymbol${c.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                    decoration: c.settled
                                        ? TextDecoration.lineThrough
                                        : null)),
                            subtitle: Text(
                                'Due: ${c.expectedDate.day}/${c.expectedDate.month}/${c.expectedDate.year}  •  ${c.debtorPhone}\n${c.orderNumber}'),
                            isThreeLine: true,
                            trailing: c.settled
                                ? const Chip(
                                    label: Text('Settled',
                                        style: TextStyle(fontSize: 10)),
                                    backgroundColor: Colors.greenAccent,
                                  )
                                : TextButton(
                                    child: const Text('Settle'),
                                    onPressed: () =>
                                        _settleCredit(c, prefs),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _settleCredit(
      CreditRecord credit, SharedPreferences prefs) async {
    final list = prefs.getStringList('credits') ?? [];
    final updated = <String>[];
    for (final s in list) {
      final c = CreditRecord.fromJson(jsonDecode(s));
      if (c.id == credit.id) {
        c.settled = true;
        c.settledAt = DateTime.now();
        c.amountPaid = c.amount;
        updated.add(jsonEncode(c.toJson()));
      } else {
        updated.add(s);
      }
    }
    await prefs.setStringList('credits', updated);
    if (mounted) {
      Navigator.pop(context);
      _showCreditsList();
      showToast('Credit ${credit.orderNumber} settled');
    }
  }

  void _showDiscountDialog(BuildContext context) {
    TextEditingController discountController = TextEditingController();
    DiscountType selectedDiscountType = DiscountType.Percentage;
    double discountedPrice = totalPrice;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Apply Discount'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Enter discount'),
                    onChanged: (value) {
                      setState(() {
                        double discountValue = double.tryParse(value) ?? 0;
                        if (selectedDiscountType ==
                            DiscountType.Percentage) {
                          double percentage = discountValue / 100;
                          discountedPrice =
                              totalPrice - (totalPrice * percentage);
                        } else {
                          discountedPrice =
                              totalPrice.toDouble() - discountValue.toDouble();
                        }
                      });
                    },
                  ),
                  ListTile(
                    title: const Text('Percentage'),
                    leading: Radio<DiscountType>(
                      value: DiscountType.Percentage,
                      groupValue: selectedDiscountType,
                      onChanged: (DiscountType? value) {
                        setState(() {
                          selectedDiscountType = value!;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Price'),
                    leading: Radio<DiscountType>(
                      value: DiscountType.Price,
                      groupValue: selectedDiscountType,
                      onChanged: (DiscountType? value) {
                        setState(() {
                          selectedDiscountType = value!;
                        });
                      },
                    ),
                  ),
                  Text(
                    'New Price: $currencySymbol${discountedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                double discountValue =
                    double.tryParse(discountController.text) ?? 0;
                appliedDiscount =
                    Discount(value: discountValue, type: selectedDiscountType);
                _applyDiscount(appliedDiscount!);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
            TextButton(
              onPressed: () {
                _saveCredit(-totalPrice);
                Navigator.of(context).pop();
              },
              child: const Text('Credit'),
            ),
          ],
        );
      },
    );
  }

  void _saveCredit(double creditAmount) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('creditAmount', creditAmount);
      showToast(
          'Credit amount saved: $currencySymbol${creditAmount.toStringAsFixed(2)}');
      setState(() {
        totalPrice = creditAmount;
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      showToast('Failed to save credit amount: $e');
      print('Failed to save credit amount: $e');
    }
  }

  void _applyDiscount(Discount discount) {
    double totalBeforeDiscount = totalPrice;
    double discountedTotal = 0;

    if (discount.type == DiscountType.Percentage) {
      double percentage = discount.value / 100;
      discountedTotal =
          totalBeforeDiscount - (totalBeforeDiscount * percentage);
    } else if (discount.type == DiscountType.Price) {
      discountedTotal = totalBeforeDiscount - discount.value;
    }

    if (discountedTotal < 0) {
      showToast('Discount cannot exceed total price');
      return;
    }

    setState(() {
      totalPrice = discountedTotal;
      appliedDiscount = discount;
    });

    _saveDiscount(discount);
  }

  void _saveDiscount(Discount discount) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String discountJson = jsonEncode(discount.toJson());
    prefs.setString('discount', discountJson);
  }

  void _updateQuantity(BuildContext context, String itemName, int change) {
    setState(() {
      double newQuantity = (itemQuantities[itemName] ?? 0) + change;
      if (newQuantity <= 0) {
        itemQuantities.remove(itemName);
      } else {
        itemQuantities[itemName] = newQuantity;
      }

      totalPrice = itemQuantities.keys.fold(0.0, (sum, key) {
        int index = products.indexOf(key);
        double itemPrice;
        if (index == -1) {
          itemPrice = quickSalePrices[key] ?? 0.0;
        } else {
          itemPrice = double.tryParse(price[index]) ?? 0.0;
        }
        return sum + (itemQuantities[key]! * itemPrice);
      });
    });

    Navigator.of(context).pop();
    Future.delayed(Duration.zero, () {
      _showOrderDialog(context);
    });
  }

  Future<bool> _checkQuantityBeforeAdding(String productName,
      String productCode, double quantityToAdd, int availableQuantity) async {
    if (quantitiesList.isEmpty) {
      return true;
    }

    if (_allowSellOutOfStock) {
      return true;
    }

    if (availableQuantity == 0) {
      showToast("⚠️ $productName is out of stock");
      return false;
    }

    double currentCartQuantity = itemQuantities[productName] ?? 0;
    double totalRequested = currentCartQuantity + quantityToAdd;

    if (totalRequested > availableQuantity) {
      showToast(
        "⚠️ Insufficient stock! Only $availableQuantity available",
      );

      _showInsufficientStockDialog(
          productName, availableQuantity, currentCartQuantity);
      return false;
    }

    if (availableQuantity - totalRequested < 5) {
      showToast(
          "⚠️ Low stock: Only ${(availableQuantity - totalRequested).toInt()} left after this sale");
    }

    return true;
  }

  void _showInsufficientStockDialog(
      String productName, int available, double currentInCart) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Insufficient Stock'),
          content: Text('Only $available units of "$productName" are available.\n'
              'You already have $currentInCart in cart.\n\n'
              'Would you like to add the maximum available?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  itemQuantities[productName] = available.toDouble();
                  _recalculateTotal();
                });
                Navigator.pop(context);
              },
              child: const Text('Use Max Available'),
            ),
          ],
        );
      },
    );
  }

  void _recalculateTotal() {
    totalPrice = itemQuantities.keys.fold(0.0, (sum, key) {
      int index = products.indexOf(key);
      double itemPrice;
      if (index == -1) {
        itemPrice = quickSalePrices[key] ?? 0.0;
      } else {
        itemPrice = double.tryParse(price[index]) ?? 0.0;
      }
      return sum + (itemQuantities[key]! * itemPrice);
    });
  }

  void _finalizeOrder() async {
    setState(() {
      _isProcessingOrder = true;
    });

    try {
      bool isConnected = await InternetConnection().hasInternetAccess;

      if (!mounted) return;

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      List<Product> orderProducts = [];
      double originalTotal = 0;

      for (var entry in itemQuantities.entries) {
        int productIndex = products.indexOf(entry.key);
        String name = entry.key;
        double quantity = entry.value;
        double productPrice;
        String code;

        if (productIndex != -1 && productIndex < codes.length) {
          code = codes[productIndex];
          productPrice = double.tryParse(price[productIndex]) ?? 0.0;
        } else {
          productPrice = quickSalePrices[name] ?? 0.0;
          String sanitized = name.replaceAll(RegExp(r'\s+'), '');
          int randomDigits =
              DateTime.now().millisecondsSinceEpoch.remainder(10000);
          code = 'QK_${sanitized}_$randomDigits';
        }

        Product product = Product(
          name: name,
          code: code,
          price: productPrice,
          quantity: quantity,
        );

        orderProducts.add(product);
        originalTotal += productPrice * quantity;
      }

      if (orderProducts.isEmpty) {
        showToast('No products to add to the order.');
        setState(() {
          _isProcessingOrder = false;
        });
        return;
      }

      double finalTotal = totalPrice;

      String? cashierName = await _getActiveCashierName() ?? '';

      // --- ADDED RANDOM SUFFIX ---
      String orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

      Order newOrder = Order(
        orderNumber: orderNumber,
        products: orderProducts,
        total: finalTotal,
        timestamp: DateTime.now(),
        customerName: '',
        cashierName: cashierName,
        appliedDiscount: appliedDiscount,
      );

      String orderJson = jsonEncode(newOrder.toJson());
      bool inventoryUpdated = false;

      if (isConnected && _allowAutomaticUpload == true) {
        try {
          Map<String, dynamic>? uploadResult =
              await _uploadOrderToServer(orderJson, newOrder);

          if (uploadResult != null && uploadResult['success'] == true) {
            showToast('Order uploaded successfully!');
            inventoryUpdated = true;

            try {
              var response = await http.post(
                Uri.parse('https://blueichor.org/log2.php'),
                body: {'username': shopId, 'password': password},
              );

              if (response.statusCode == 200) {
                var jsondata = json.decode(response.body);
                if (jsondata["success"]) {
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setString(
                      'categories', json.encode(jsondata['categories']));
                  prefs.setString(
                      'products', json.encode(jsondata["products"]));
                  prefs.setString('prices', json.encode(jsondata["prices"]));
                  prefs.setString('codes', json.encode(jsondata["codes"]));
                  prefs.setString('measure', json.encode(jsondata["measure"]));
                  prefs.setString(
                      'quantities', json.encode(jsondata["quantities"]));

                  await _loadProductQuantities();
                  _checkAllProductsStock();
                }
              }
            } catch (e) {
              print('Error fetching data: $e');
            }

            if (uploadResult.containsKey('low_stock_products') &&
                uploadResult['low_stock_products'] is List) {
              List<dynamic> lowStock = uploadResult['low_stock_products'];
              for (var item in lowStock) {
                if (item['name'] != null && item['quantity'] != null) {
                  int remaining = item['quantity'];
                  String productName = item['name'];

                  if (remaining <= 0) {
                    NotificationService.showOutOfStockNotification(
                      productName: productName,
                      shopName: shopname,
                    );
                  } else if (remaining <= _lowStockThreshold) {
                    NotificationService.showLowStockNotification(
                      productName: productName,
                      remainingQuantity: remaining,
                      shopName: shopname,
                    );
                  }
                  showToast(
                      '⚠️ Low stock: ${item['name']} (${item['quantity']} left)');
                }
              }
            }
          } else {
            showToast('Upload failed. Saving order locally...');
            _saveOrderLocally(prefs, orderJson);
          }
        } catch (uploadError) {
          print('Upload failed: $uploadError');
          showToast('Upload error. Saving order locally...');
          _saveOrderLocally(prefs, orderJson);
        }
      } else {
        showToast('No internet connection. Order saved locally.');
        _saveOrderLocally(prefs, orderJson);
      }

      setState(() {
        itemQuantities.clear();
        totalPrice = 0.0;
        appliedDiscount = null;
        _isProcessingOrder = false;
      });

      if (mounted) {
        if (inventoryUpdated) {
          // --- PASSING THE ORDER DIRECTLY ---
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => PrinterPage(order: newOrder)),
          );
        } else {
          // --- PASSING THE ORDER DIRECTLY ---
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => PrinterPage(order: newOrder)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      showToast('Failed to finalize order: $e');
      print('Failed to finalize order: $e');
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  Future<void> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> ordersJson = prefs.getStringList('orders') ?? [];
      shopname = prefs.getString('fullname') ?? '';
      shopId = prefs.getString('username') ?? '';
      password = prefs.getString('password') ?? '';

      bool hideTotal = prefs.getBool('hideTotalOnHomepage') ?? false;

      List<Order> loadedOrders =
          ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e')),
      );
    }
  }

  Future<Map<String, dynamic>?> _uploadOrderToServer(
      String orderJson, Order order) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? shopId = prefs.getString('username');
    
    // 1. Check ZIMRA status
    final bool zimraEnabled = prefs.getBool('zimraEnabled') ?? false;
    
    // 2. Route correctly
    final String uploadUrl = zimraEnabled 
        ? "https://blueichor.org/fiscalize.php" 
        : "https://blueichor.org/uploadOffline3.php";

    if (shopId == null) {
      showToast('Shop ID not found. Please check your settings.');
      return null;
    }

    try {
      var response = await http.post(
        Uri.parse(uploadUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': shopId,
          'orders': [order.toJson()],
          'zimra_enabled': zimraEnabled, // <--- Send flag
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['success'] == true) {
          // 3. Save ZIMRA QR
          if (jsonResponse['results'] != null) {
            for (var res in jsonResponse['results']) {
              if (res['qrData'] != null && res['qrData'].toString().isNotEmpty) {
                await prefs.setString('fiscalQr_${order.orderNumber}', res['qrData']);
                print('✅ Saved ZIMRA QR for ${order.orderNumber}: ${res['qrData']}');
              }
            }
          }
          _refreshData();
          return jsonResponse;
        } else {
           showToast('Upload failed: ${jsonResponse['message']}');
           return null;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getString('username') ?? '';
    password = prefs.getString('password') ?? '';
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
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

  void _saveOrderLocally(SharedPreferences prefs, String orderJson) {
    List<String> orders = prefs.getStringList('orders') ?? [];
    orders.add(orderJson);
    prefs.setStringList('orders', orders);
  }

  Future<String?> _getActiveCashierName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentCashier');
  }

  void _saveOrderAsDraft() async {
    if (_isProcessingOrder) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      TextEditingController nameController = TextEditingController();
      String customerName = '';

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Enter Customer Name'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
              onChanged: (value) {
                customerName = value;
              },
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Save'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      if (customerName.isNotEmpty) {
        // --- ADDED RANDOM SUFFIX ---
        String orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';

        Order newOrder = Order(
          orderNumber: orderNumber,
          products: itemQuantities.entries.map((entry) {
            int index = products.indexOf(entry.key);
            return Product(
              name: entry.key,
              code: codes[index],
              price: double.tryParse(price[index]) ?? 0.0,
              quantity: entry.value,
            );
          }).toList(),
          total: totalPrice.toDouble(),
          timestamp: DateTime.now(),
          customerName: customerName,
          cashierName: '',
        );

        String orderJson = jsonEncode(newOrder.toJson());
        List<String> orders = prefs.getStringList('draftOrders') ?? [];
        orders.add(orderJson);
        await prefs.setStringList('draftOrders', orders);

        showToast('Order saved as draft');
        setState(() {
          itemQuantities.clear();
          totalPrice = 0.0;
        });
      } else {
        showToast('Customer name is required');
      }
    } catch (e) {
      showToast('Failed to save order: $e');
      print('Failed to save order: $e');
    }
  }

  void _prepareForNewSale() {
    itemQuantities.clear();
    totalPrice = 0.0;
    fullname = '';
    searchText = '';
    appliedDiscount = null;
    setState(() {});
  }

  void showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white);
  }

  void _showKgsDialog(BuildContext context, String itemName, double itemPrice) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController kgsController = TextEditingController();
    bool isUpdatingAmount = false;
    bool isUpdatingKgs = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Amount or Kgs for $itemName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration:
                      InputDecoration(labelText: "Amount ($currencySymbol)"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    if (isUpdatingAmount) return;
                    double amount = double.tryParse(value) ?? 0;
                    isUpdatingKgs = true;
                    if (itemPrice > 0) {
                      kgsController.text =
                          (amount / itemPrice).toStringAsFixed(2);
                    }
                    isUpdatingKgs = false;
                  },
                ),
                TextField(
                  controller: kgsController,
                  decoration: const InputDecoration(labelText: "Kgs"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    if (isUpdatingKgs) return;
                    double kgs = double.tryParse(value) ?? 0;
                    isUpdatingAmount = true;
                    amountController.text =
                        (kgs * itemPrice).toStringAsFixed(2);
                    isUpdatingAmount = false;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                double kgs = double.tryParse(kgsController.text) ?? 0;
                double amount = double.tryParse(amountController.text) ?? 0;

                if (kgs == 0 && amount > 0 && itemPrice > 0) {
                  kgs = amount / itemPrice;
                } else if (amount == 0 && kgs > 0) {
                  amount = kgs * itemPrice;
                }

                setState(() {
                  double existingQuantity = itemQuantities[itemName] ?? 0;
                  itemQuantities[itemName] = kgs;
                  totalPrice += amount;
                });

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
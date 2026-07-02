// ignore_for_file: depend_on_referenced_packages, unnecessary_import
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/inventory_service.dart';
import 'package:vibration/vibration.dart';
import 'printer2.dart';
import 'widgets/sell.dart';

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
  
  // Store quantities as a List (matches how they were saved in login)
  List<int> quantitiesList = [];
  String shopId = '';
  String password = '';
  
  // NEW: Setting to allow selling out of stock items
  bool _allowSellOutOfStock = false;
  
  @override
  void initState() {
    super.initState();
    loadCurrencySymbol();
    _loadAllowSellOutOfStockSetting();
    _loadData();
    _loadCategories();
    _loadProductQuantities();
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }
  
  // NEW: Load the allow sell out of stock setting
  Future<void> _loadAllowSellOutOfStockSetting() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowSellOutOfStock = prefs.getBool('allowSellOutOfStock') ?? false;
    });
  }

  // Load product quantities as List
  Future<void> _loadProductQuantities() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? quantitiesJson = prefs.getString('quantities');
    
    if (quantitiesJson != null) {
      try {
        List<dynamic> parsedList = jsonDecode(quantitiesJson);
        setState(() {
          quantitiesList = parsedList.map((e) => 
              e is int ? e : int.tryParse(e.toString()) ?? 0
          ).toList();
        });
        print('Quantities loaded: $quantitiesList');
      } catch (e) {
        print("Error loading quantities: $e");
        quantitiesList = [];
      }
    } else {
      print('No quantities found');
      quantitiesList = [];
    }
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
      print('products: $products');
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
          .where(
              (item) => item.toLowerCase().contains(searchText.toLowerCase()))
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
            Text('Shopping Page', style: TextStyle(fontSize: 20)),
            DropdownButton<String>(
              hint: Text('Categories'),
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
          ],
        ),
      ),
      body: _isProcessingOrder
          ? _buildLoadingIndicator()
          : Row(
              children: [
                // Main products area - 65% of screen on large screens
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
                                  border: OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.qr_code_scanner),
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
                            // NEW: Show allow out of stock status indicator
                            if (_allowSellOutOfStock)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              final productCode = productIndex != -1 ? codes[productIndex] : '';
                              
                              // Get quantity from list by index
                              final int availableQuantity = productIndex != -1 && productIndex < quantitiesList.length 
                                  ? quantitiesList[productIndex] 
                                  : 0;
                              
                              // Check if item is out of stock
                              final bool isOutOfStock = quantitiesList.isNotEmpty && availableQuantity <= 0;

                              return Card(
                                // Don't grey out if we allow selling out of stock
                                color: (!_allowSellOutOfStock && isOutOfStock) ? Colors.grey[200] : null,
                                child: InkWell(
                                  onTap: () async {
                                    // Allow tap even if out of stock when setting is enabled
                                    if (isOutOfStock && !_allowSellOutOfStock) {
                                      showToast('⚠️ $itemName is out of stock');
                                      return;
                                    }
                                    
                                    String measureType = measures[productIndex];
                                    double itemKgPrice = double.tryParse(price[productIndex]) ?? 0.0;
                                    String itemCode = codes[productIndex];

                                    if (measureType == "kgs" ||
                                        measureType == "metres" ||
                                        measureType == "centimetres" ||
                                        measureType == "lbs") {
                                      _showKgsDialog(context, itemName, itemKgPrice);
                                    } else if (measureType == "units") {
                                      // Check quantity before adding (respects the setting)
                                      bool canAdd = await _checkQuantityBeforeAdding(
                                          itemName, itemCode, 1, availableQuantity);

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
                                    // Don't dim if we allow selling out of stock
                                    opacity: (!_allowSellOutOfStock && isOutOfStock) ? 0.5 : 1.0,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        FutureBuilder<String>(
                                          future: _getImagePath(itemName),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return CircularProgressIndicator();
                                            }
                                            if (snapshot.hasData &&
                                                snapshot.data!.isNotEmpty) {
                                              return Image.file(
                                                File(snapshot.data!),
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                                color: (!_allowSellOutOfStock && isOutOfStock) ? Colors.grey : null,
                                                colorBlendMode: (!_allowSellOutOfStock && isOutOfStock) ? BlendMode.saturation : null,
                                              );
                                            }
                                            return Icon(
                                              Icons.shopping_basket,
                                              size: 80,
                                              color: (!_allowSellOutOfStock && isOutOfStock) ? Colors.grey : null,
                                            );
                                          },
                                        ),
                                        SizedBox(height: 8.0),
                                        Text(
                                          itemName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLandscape ? 12 : 14,
                                            color: (!_allowSellOutOfStock && isOutOfStock) ? Colors.grey : null,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Price: $currencySymbol${itemPrice}',
                                          style: TextStyle(
                                              fontSize: isLandscape ? 11 : 13,
                                              color: (!_allowSellOutOfStock && isOutOfStock) ? Colors.grey : null),
                                        ),
                                        // Show available quantity or OUT OF STOCK
                                        if (quantitiesList.isEmpty)
                                          Text(
                                            'Stock: Available',
                                            style: TextStyle(
                                                fontSize: isLandscape ? 10 : 11,
                                                color: Colors.green),
                                          )
                                        else if (isOutOfStock)
                                          Text(
                                            _allowSellOutOfStock ? 'OUT OF STOCK (Sell Allowed)' : 'OUT OF STOCK',
                                            style: TextStyle(
                                                fontSize: isLandscape ? 10 : 11,
                                                color: _allowSellOutOfStock ? Colors.orange : Colors.red,
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
                      // Only show the complete button on small screens
                      if (!isLargeScreen)
                        Container(
                          padding: EdgeInsets.all(16.0),
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
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '$totalItems',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Order summary panel - only visible on large screens (35% of screen)
                if (isLargeScreen)
                  Container(
                    width: screenWidth * 0.35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(left: BorderSide(color: Colors.grey[300]!)),
                      boxShadow: [
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
        // Products area - 60% of side panel (fixed height)
        Expanded(
          flex: 6, // 60% of space
          child: itemQuantities.isEmpty
              ? Center(
                  child: Text(
                    'No items added yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
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
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Quantity: ${quantity.toStringAsFixed(2)}',
                                        style: TextStyle(
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
                                          icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red,
                                              size: 22),
                                          onPressed: () =>
                                              _updateQuantitySidePanel(
                                                  itemName, -1),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.add_circle_outline,
                                              color: Colors.green, size: 22),
                                          onPressed: () =>
                                              _updateQuantitySidePanel(
                                                  itemName, 1),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
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
                              padding: EdgeInsets.only(top: 4),
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

        // Bottom section with total and buttons - 40% of side panel (scrollable)
        Expanded(
          flex: 4, // 40% of space
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
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Complete Order button with orange badge
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessingOrder
                            ? null
                            : () {
                                _showCalculatorDialog(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
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
                            SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$currencySymbol${totalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$totalItems',
                                    style: TextStyle(
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
                    SizedBox(height: 16),

                    // Additional action buttons - scrollable area
                    Column(
                      children: [
                        // Discount button
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showDiscountDialog(context);
                            },
                            icon: Icon(Icons.local_offer, size: 20),
                            label: Text('Apply Discount',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        // Save Draft button
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed:
                                _isProcessingOrder ? null : _saveOrderAsDraft,
                            icon: Icon(Icons.save, size: 20),
                            label: Text('Save Draft',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        // Quick Sale button
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showQuickSaleDialog(context);
                            },
                            icon: Icon(Icons.flash_on, size: 20),
                            label: Text('Quick Sale',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        // Credit button
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _saveCredit(-totalPrice);
                            },
                            icon: Icon(Icons.credit_card, size: 20),
                            label:
                                Text('Credit', style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        // Clear Cart button (additional option)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                itemQuantities.clear();
                                totalPrice = 0.0;
                              });
                              showToast('Cart cleared');
                            },
                            icon: Icon(Icons.delete_sweep, size: 20),
                            label: Text('Clear Cart',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        // View Details button (additional option)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showOrderDialog(context);
                            },
                            icon: Icon(Icons.list_alt, size: 20),
                            label: Text('View Order Details',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                        // Total breakdown (additional information)
                        if (itemQuantities.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 10, top: 10),
                            padding: EdgeInsets.all(12),
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
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Items:',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      '$totalItems',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
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
                                    padding: EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
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
                                          style: TextStyle(
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
                    SizedBox(height: 20), // Extra padding at bottom
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
    // If decreasing quantity, no need to check inventory
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
    
    // For increasing quantity, check inventory
    int productIndex = products.indexOf(itemName);
    if (productIndex != -1) {
      String itemCode = codes[productIndex];
      int availableQuantity = productIndex < quantitiesList.length 
          ? quantitiesList[productIndex] 
          : 0;
      
      bool canAdd = await _checkQuantityBeforeAdding(
        itemName, 
        itemCode, 
        change.toDouble(),
        availableQuantity
      );
      
      if (canAdd && mounted) {
        setState(() {
          double newQuantity = (itemQuantities[itemName] ?? 0) + change;
          itemQuantities[itemName] = newQuantity;
          _recalculateTotal();
        });
      }
    } else {
      // Quick sale item - no inventory check
      setState(() {
        double newQuantity = (itemQuantities[itemName] ?? 0) + change;
        itemQuantities[itemName] = newQuantity;
        _recalculateTotal();
      });
    }
  }
  
  Widget _buildLoadingIndicator() {
    return Center(
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
        
        // Check if product is in stock
        int availableQuantity = barcodeIndex < quantitiesList.length 
            ? quantitiesList[barcodeIndex] 
            : 0;
            
        if (quantitiesList.isNotEmpty && availableQuantity <= 0 && !_allowSellOutOfStock) {
          showToast('⚠️ $productName is out of stock');
          return;
        }

        String measureType = measures[barcodeIndex];
        if (measureType == "kgs" || measureType == "metres" || 
            measureType == "centimetres" || measureType == "lbs") {
          double itemKgPrice = double.tryParse(itemPrice) ?? 0.0;
          _showKgsDialog(context, productName, itemKgPrice);
        } else {
          // Check quantity before adding (respects the setting)
          bool canAdd =
              await _checkQuantityBeforeAdding(productName, itemCode, 1, availableQuantity);

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
            decoration: InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () async {
                final double quantity =
                    double.tryParse(_quantityController.text) ?? 0;
                if (quantity > 0) {
                  int productIndex = products.indexOf(itemName);
                  if (productIndex != -1) {
                    String itemCode = codes[productIndex];
                    int availableQuantity = productIndex < quantitiesList.length 
                        ? quantitiesList[productIndex] 
                        : 0;
                    
                    // Check quantity before adding (respects the setting)
                    bool canAdd = await _checkQuantityBeforeAdding(
                      itemName, 
                      itemCode, 
                      quantity,
                      availableQuantity
                    );
                    
                    if (canAdd && mounted) {
                      setState(() {
                        itemQuantities.update(itemName, 
                            (value) => value + quantity,
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
          insetPadding: EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: EdgeInsets.all(24.0),
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
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove),
                                    onPressed: () =>
                                        _updateQuantity(context, itemName, -1),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add),
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
                        SizedBox(height: 8),
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
                              icon: Icon(Icons.local_offer),
                              label: Text('Apply Discount'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showCalculatorDialog(context);
                              },
                              icon: Icon(Icons.calculate),
                              label: Text('Complete'),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed:
                                  _isProcessingOrder ? null : _saveOrderAsDraft,
                              icon: Icon(Icons.save),
                              label: Text('Save Draft'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showQuickSaleDialog(context);
                              },
                              icon: Icon(Icons.flash_on),
                              label: Text('Quick Sale'),
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
              title: Text('Quick Sale'),
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
                        decoration: InputDecoration(
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
                  SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: currencySymbol,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (matchingProducts.isNotEmpty &&
                      productNameController.text.isNotEmpty)
                    Container(
                      constraints: BoxConstraints(maxHeight: 200),
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
                  child: Text('Cancel'),
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
                  child: Text('Add to Sale'),
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
              title: Text('Received Amount'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
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
                  SizedBox(height: 20),
                  Text(changeText,
                      style: TextStyle(color: Colors.blue, fontSize: 16)),
                ],
              ),
              actions: <Widget>[
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
                  child: Text('Complete'),
                ),
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDiscountDialog(BuildContext context) {
    TextEditingController discountController = TextEditingController();
    DiscountType selectedDiscountType = DiscountType.Percentage;
    double discountedPrice = totalPrice;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apply Discount'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Enter discount'),
                    onChanged: (value) {
                      setState(() {
                        double discountValue = double.tryParse(value) ?? 0;
                        if (selectedDiscountType == DiscountType.Percentage) {
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
                    title: Text('Percentage'),
                    leading: Radio(
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
                    title: Text('Price'),
                    leading: Radio(
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
                    style: TextStyle(fontWeight: FontWeight.bold),
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
              child: Text('Cancel'),
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
              child: Text('Apply'),
            ),
            TextButton(
              onPressed: () {
                _saveCredit(-totalPrice);
                Navigator.of(context).pop();
              },
              child: Text('Credit'),
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
/// Distributes discount equally across all products in the order
List<Product> _distributeDiscountEqually(
    List<Product> products, 
    Discount discount, 
    double originalTotal
) {
  if (products.isEmpty) return products;
  
  // Calculate total quantity across all products
  double totalQuantity = products.fold(0, (sum, product) => sum + product.quantity);
  
  // Calculate the total discount amount
  double totalDiscount = 0;
  if (discount.type == DiscountType.Percentage) {
    totalDiscount = originalTotal * (discount.value / 100);
  } else {
    totalDiscount = discount.value;
  }
  
  // Distribute discount proportionally based on product price * quantity
  List<Product> updatedProducts = [];
  double accumulatedDiscount = 0;
  
  for (int i = 0; i < products.length; i++) {
    Product product = products[i];
    
    // Calculate this product's share of the total order value
    double productValue = product.price * product.quantity;
    double proportion = totalQuantity > 0 ? product.quantity / totalQuantity : 0;
    
    // Calculate discount for this product
    double productDiscount = 0;
    double productDiscountPercentage = 0;
    
    if (discount.type == DiscountType.Percentage) {
      // For percentage discount, apply the same percentage to each product
      productDiscountPercentage = discount.value;
      productDiscount = (product.price * product.quantity) * (discount.value / 100);
    } else {
      // For fixed price discount, distribute proportionally by quantity
      productDiscount = totalDiscount * proportion;
    }
    
    // Create updated product with discount
    Product updatedProduct = Product(
      name: product.name,
      code: product.code,
      price: product.price,
      quantity: product.quantity,
      discountAmount: productDiscount,
      discountPercentage: discount.type == DiscountType.Percentage 
          ? discount.value 
          : null,
    );
    
    updatedProducts.add(updatedProduct);
    accumulatedDiscount += productDiscount;
  }
  
  // Handle rounding differences by adjusting the last product
  if (updatedProducts.isNotEmpty && accumulatedDiscount != totalDiscount) {
    double difference = totalDiscount - accumulatedDiscount;
    Product lastProduct = updatedProducts.last;
    updatedProducts[updatedProducts.length - 1] = Product(
      name: lastProduct.name,
      code: lastProduct.code,
      price: lastProduct.price,
      quantity: lastProduct.quantity,
      discountAmount: (lastProduct.discountAmount ?? 0) + difference,
      discountPercentage: lastProduct.discountPercentage,
    );
  }
  
  return updatedProducts;
}

void _applyDiscount(Discount discount) {
  double totalBeforeDiscount = totalPrice;
  double discountedTotal = 0;

  // Calculate the new total
  if (discount.type == DiscountType.Percentage) {
    double percentage = discount.value / 100;
    discountedTotal = totalBeforeDiscount - (totalBeforeDiscount * percentage);
  } else if (discount.type == DiscountType.Price) {
    discountedTotal = totalBeforeDiscount - discount.value;
  }

  // Prevent negative total
  if (discountedTotal < 0) {
    showToast('Discount cannot exceed total price');
    return;
  }

  setState(() {
    totalPrice = discountedTotal;
    appliedDiscount = discount;
    
    // Update the order to include discount on each product
    // This will be used when finalizing the order
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

  // UPDATED: Check quantity before adding - respects the allow sell out of stock setting
  Future<bool> _checkQuantityBeforeAdding(
      String productName, String productCode, double quantityToAdd, int availableQuantity) async {
    
    // If quantitiesList is empty, assume unlimited stock
    if (quantitiesList.isEmpty) {
      return true;
    }

    // If allow sell out of stock is enabled, always allow
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

      // Show dialog with options
      _showInsufficientStockDialog(
          productName, availableQuantity, currentCartQuantity);
      return false;
    }

    // Show warning if getting low
    if (availableQuantity - totalRequested < 5) {
      showToast("⚠️ Low stock: Only ${(availableQuantity - totalRequested).toInt()} left after this sale");
    }

    return true;
  }

  void _showInsufficientStockDialog(
      String productName, int available, double currentInCart) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Insufficient Stock'),
          content:
              Text('Only $available units of "$productName" are available.\n'
                  'You already have $currentInCart in cart.\n\n'
                  'Would you like to add the maximum available?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // Set to maximum available
                  itemQuantities[productName] = available.toDouble();
                  _recalculateTotal();
                });
                Navigator.pop(context);
              },
              child: Text('Use Max Available'),
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


  // UPDATED: Enhanced _finalizeOrder method with better server response handling
 void _finalizeOrder() async {
  setState(() {
    _isProcessingOrder = true;
  });

  try {
    bool isConnected = await InternetConnection().hasInternetAccess;

    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // STEP 1: Create base products without discount
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
        int randomDigits = DateTime.now().millisecondsSinceEpoch.remainder(10000);
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

    // STEP 2: Apply discount equally to all products if a discount is applied
    double finalTotal = totalPrice;
    if (appliedDiscount != null) {
      orderProducts = _distributeDiscountEqually(
        orderProducts,
        appliedDiscount!,
        originalTotal,
      );
      
      // Recalculate total after discount distribution
      finalTotal = orderProducts.fold(0.0, (sum, product) => 
          sum + product.getTotalWithDiscount());
    }

    // STEP 3: Get cashier name
    String? cashierName = await _getActiveCashierName() ?? '';
    
    // STEP 4: Generate order number
    String orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}-$orderNumberCounter';
    orderNumberCounter++;

    // STEP 5: Create the order object
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

    // STEP 6: Upload or save order
    if (isConnected) {
      try {
        Map<String, dynamic>? uploadResult =
            await _uploadOrderToServer(orderJson, newOrder);

        if (uploadResult != null && uploadResult['success'] == true) {
          showToast('Order uploaded successfully!');
          inventoryUpdated = true;

          // Refresh inventory data from server
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
                
                await _loadProductQuantities();
              }
            }
          } catch (e) {
            print('Error fetching data: $e');
          }

          // Show low stock warnings
          if (uploadResult.containsKey('low_stock_products') &&
              uploadResult['low_stock_products'] is List) {
            List<dynamic> lowStock = uploadResult['low_stock_products'];
            for (var item in lowStock) {
              if (item['name'] != null && item['quantity'] != null) {
                showToast('⚠️ Low stock: ${item['name']} (${item['quantity']} left)');
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

    // STEP 7: Clear cart and reset state
    setState(() {
      itemQuantities.clear();
      totalPrice = 0.0;
      appliedDiscount = null;
      _isProcessingOrder = false;
    });

    // STEP 8: Navigate to appropriate page
    if (mounted) {
      if (inventoryUpdated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => PrinterPage()),
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => PrinterPage()),
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
  // UPDATED: Enhanced upload method with better error handling and timeout
  Future<Map<String, dynamic>?> _uploadOrderToServer(
      String orderJson, Order order) async {
    const String uploadUrl = "https://blueichor.org/uploadOffline3.php";
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? shopId = prefs.getString('username');

    if (shopId == null) {
      showToast('Shop ID not found. Please check your settings.');
      return null;
    }

    try {
      print('Uploading order to server...');
      var response = await http.post(
        Uri.parse(uploadUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': shopId,
          'orders': [order.toJson()],
        }),
      ).timeout(Duration(seconds: 30)); // Add timeout

      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        return jsonResponse;
      } else {
        print('Server responded with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
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
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      TextEditingController nameController = TextEditingController();
      String customerName = '';

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Enter Customer Name'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Customer Name'),
              onChanged: (value) {
                customerName = value;
              },
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Save'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      if (customerName.isNotEmpty) {
        String orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
        orderNumberCounter++;

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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                  decoration: InputDecoration(labelText: "Kgs"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
              child: Text('Done'),
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
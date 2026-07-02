// ignore_for_file: depend_on_referenced_packages, unnecessary_import
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:path_provider/path_provider.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

void main() {
  runApp(InvoicePage1());
}

class InvoicePage1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: InvoiceGenerationPage(),
    );
  }
}

class InvoiceGenerationPage extends StatefulWidget {
  @override
  _InvoiceGenerationPageState createState() => _InvoiceGenerationPageState();
}

class _InvoiceGenerationPageState extends State<InvoiceGenerationPage> {
  Map<String, double> itemQuantities = {};
  double totalPrice = 0.0;
  String searchText = '';
  Discount? appliedDiscount;
  String customerName = '';
  String customerAddress = '';
  String customerPhone = '';
  String invoiceNumber = '';
  DateTime invoiceDate = DateTime.now();
  DateTime dueDate = DateTime.now().add(Duration(days: 30));

  int invoiceNumberCounter = 1;

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
  Map<String, double> customItemPrices = {};

  // Printer variables
  BluetoothDevice? _device;
  bool? _connected;
  List<BluetoothDevice> _devices = [];
  // At the top of your state class
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  @override
  void initState() {
    super.initState();
    loadCurrencySymbol();
    _loadData();
    _loadCategories();
    _generateInvoiceNumber();
    _initializePrinter();
  }

  Future<void> _initializePrinter() async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      setState(() {
        _connected = isConnected ?? false;
      });

      // If not connected, try to auto-connect to saved printer
      if (!_connected!) {
        await _autoConnectSavedPrinter();
      }
    } catch (e) {
      print("Error initializing printer: $e");
    }
  }

  Future<void> _disconnect() async {
    try {
      await bluetooth.disconnect();
      setState(() {
        _connected = false;
        _device = null;
      });
      showToast('Disconnected from printer');
    } catch (e) {
      showToast('Error disconnecting: $e');
    }
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
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
    }
  }

  void _generateInvoiceNumber() {
    setState(() {
      invoiceNumber =
          'INV-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${invoiceNumberCounter.toString().padLeft(4, '0')}';
    });
  }

  int _getFilteredItemCount() {
    return _getFilteredProducts().length;
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Invoice Generation', style: TextStyle(fontSize: 20)),
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
      body: Column(
        children: <Widget>[
          // Customer Information Section
          ExpansionTile(
            title: Text('Customer Information',
                style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => customerName = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => customerAddress = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) => customerPhone = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Invoice Number',
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(text: invoiceNumber),
                        onChanged: (value) => invoiceNumber = value,
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: _generateInvoiceNumber,
                      tooltip: 'Generate New Invoice Number',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Invoice Date',
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(
                            text: _formatDate(invoiceDate)),
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Due Date',
                          border: OutlineInputBorder(),
                        ),
                        controller:
                            TextEditingController(text: _formatDate(dueDate)),
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Search and Barcode Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Products',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ),
              onChanged: (text) {
                setState(() {
                  searchText = text.toLowerCase();
                });
              },
            ),
          ),

          // Products Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
              ),
              itemCount: _getFilteredItemCount(),
              itemBuilder: (context, index) {
                final filteredProducts = _getFilteredProducts();
                if (index < filteredProducts.length) {
                  final itemName = filteredProducts[index];
                  final itemPrice = price[products.indexOf(itemName)];

                  return Card(
                    child: InkWell(
                      onTap: () => _addItemToInvoice(itemName, itemPrice),
                      onLongPress: () => _showQuantityDialog(context, itemName),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                );
                              }
                              return Icon(Icons.shopping_basket, size: 80);
                            },
                          ),
                          SizedBox(height: 8.0),
                          Text(itemName,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Price: $currencySymbol${itemPrice}'),
                        ],
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),

          // Invoice Summary Section
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('$currencySymbol${totalPrice.toStringAsFixed(2)}'),
                  ],
                ),
                if (appliedDiscount != null) ...[
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discount:', style: TextStyle(color: Colors.red)),
                      Text(
                          '-$currencySymbol${_calculateDiscountAmount().toStringAsFixed(2)}'),
                    ],
                  ),
                ],
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(
                        '$currencySymbol${_calculateTotal().toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showInvoiceDialog(context),
                      icon: Icon(Icons.receipt),
                      label: Text('View Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showDiscountDialog(context),
                      icon: Icon(Icons.local_offer),
                      label: Text('Discount'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addItemToInvoice(String itemName, String itemPrice) {
    String measureType = measures[products.indexOf(itemName)];
    double itemKgPrice = double.tryParse(itemPrice) ?? 0.0;

    if (measureType == "kgs" ||
        measureType == "metres" ||
        measureType == "centimetres" ||
        measureType == "lbs") {
      _showKgsDialog(context, itemName, itemKgPrice);
    } else if (measureType == "units") {
      setState(() {
        itemQuantities.update(itemName, (value) => ++value, ifAbsent: () => 1);
        totalPrice += double.parse(itemPrice);
      });
    }
  }

  Future<void> _scanBarcode() async {
    try {
      String barcodeScanRes;
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666",
        "Cancel",
        true,
        ScanMode.DEFAULT,
      );
      if (!mounted) return;

      int barcodeIndex = codes.indexOf(barcodeScanRes);
      if (barcodeIndex != -1) {
        String productName = products[barcodeIndex];
        String itemPrice = price[barcodeIndex];
        String measureType = measures[barcodeIndex];

        if (measureType == "kgs") {
          double itemKgPrice = double.tryParse(itemPrice) ?? 0.0;
          _showKgsDialog(context, productName, itemKgPrice);
        } else {
          setState(() {
            itemQuantities.update(productName, (value) => ++value,
                ifAbsent: () => 1);
            totalPrice += double.parse(itemPrice);
          });
        }
        Vibration.vibrate(duration: 500);
      } else {
        showToast('Product not found for barcode: $barcodeScanRes');
      }
    } catch (e) {
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                final double quantity =
                    double.tryParse(_quantityController.text) ?? 0;
                if (quantity > 0) {
                  setState(() {
                    itemQuantities.update(itemName, (value) => value + quantity,
                        ifAbsent: () => quantity);
                    totalPrice +=
                        double.parse(price[products.indexOf(itemName)]) *
                            quantity;
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

  Future<void> _selectDate(BuildContext context, bool isInvoiceDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInvoiceDate ? invoiceDate : dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isInvoiceDate) {
          invoiceDate = picked;
        } else {
          dueDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showInvoiceDialog(BuildContext context) {
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
                  // Invoice Header
                  Text('INVOICE',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(invoiceNumber, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),

                  // Customer Information
                  if (customerName.isNotEmpty) Text('Customer: $customerName'),
                  if (customerAddress.isNotEmpty)
                    Text('Address: $customerAddress'),
                  if (customerPhone.isNotEmpty) Text('Phone: $customerPhone'),
                  SizedBox(height: 16),

                  // Dates
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${_formatDate(invoiceDate)}'),
                      Text('Due: ${_formatDate(dueDate)}'),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Items List
                  ...itemQuantities.entries.map((entry) {
                    String itemName = entry.key;
                    double quantity = entry.value;
                    double itemPrice = _getItemPrice(itemName);
                    double lineTotal = quantity * itemPrice;

                    return ListTile(
                      title: Text('$itemName x $quantity'),
                      subtitle: Text('$currencySymbol$itemPrice each'),
                      trailing: Text(
                          '$currencySymbol${lineTotal.toStringAsFixed(2)}'),
                    );
                  }).toList(),

                  Divider(),

                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('$currencySymbol${totalPrice.toStringAsFixed(2)}'),
                    ],
                  ),

                  if (appliedDiscount != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discount:', style: TextStyle(color: Colors.red)),
                        Text(
                            '-$currencySymbol${_calculateDiscountAmount().toStringAsFixed(2)}'),
                      ],
                    ),
                  ],

                  Divider(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(
                          '$currencySymbol${_calculateTotal().toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _saveInvoiceAsDraft();
                        },
                        child: Text('Save Draft'),
                      ),
                      ElevatedButton(
                        onPressed: _finalizeInvoice,
                        child: Text('Finalize & Print'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _getItemPrice(String itemName) {
    int index = products.indexOf(itemName);
    if (index != -1) {
      return double.tryParse(price[index]) ?? 0.0;
    }
    return customItemPrices[itemName] ?? 0.0;
  }

  double _calculateDiscountAmount() {
    if (appliedDiscount == null) return 0.0;

    if (appliedDiscount!.type == DiscountType.Percentage) {
      return totalPrice * (appliedDiscount!.value / 100);
    } else {
      return appliedDiscount!.value;
    }
  }

  double _calculateTotal() {
    return totalPrice - _calculateDiscountAmount();
  }

  void _showDiscountDialog(BuildContext context) {
    TextEditingController discountController = TextEditingController();
    DiscountType selectedDiscountType = DiscountType.Percentage;
    double discountedTotal = _calculateTotal();

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
                          discountedTotal =
                              totalPrice - (totalPrice * discountValue / 100);
                        } else {
                          discountedTotal = totalPrice - discountValue;
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
                          double discountValue =
                              double.tryParse(discountController.text) ?? 0;
                          discountedTotal =
                              totalPrice - (totalPrice * discountValue / 100);
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('Fixed Amount'),
                    leading: Radio(
                      value: DiscountType.Price,
                      groupValue: selectedDiscountType,
                      onChanged: (DiscountType? value) {
                        setState(() {
                          selectedDiscountType = value!;
                          double discountValue =
                              double.tryParse(discountController.text) ?? 0;
                          discountedTotal = totalPrice - discountValue;
                        });
                      },
                    ),
                  ),
                  Text(
                    'New Total: $currencySymbol${discountedTotal.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                double discountValue =
                    double.tryParse(discountController.text) ?? 0;
                appliedDiscount =
                    Discount(value: discountValue, type: selectedDiscountType);
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _saveInvoiceAsDraft() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Validate required fields
      if (customerName.isEmpty) {
        showToast('Please enter customer name');
        return;
      }

      Invoice invoice = Invoice(
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        customerAddress: customerAddress,
        customerPhone: customerPhone,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        items: itemQuantities.entries.map((entry) {
          return InvoiceItem(
            name: entry.key,
            quantity: entry.value,
            unitPrice: _getItemPrice(entry.key),
          );
        }).toList(),
        subtotal: totalPrice,
        discount: appliedDiscount,
        total: _calculateTotal(),
        status: 'Draft',
      );

      String invoiceJson = jsonEncode(invoice.toJson());
      List<String> invoices = prefs.getStringList('draftInvoices') ?? [];
      invoices.add(invoiceJson);
      await prefs.setStringList('draftInvoices', invoices);

      showToast('Invoice saved as draft');
      _resetInvoice();
    } catch (e) {
      showToast('Failed to save invoice: $e');
    }
  }

  void _finalizeInvoice() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      if (customerName.isEmpty) {
        showToast('Please enter customer name');
        return;
      }

      if (itemQuantities.isEmpty) {
        showToast('Please add items to the invoice');
        return;
      }

      Invoice invoice = Invoice(
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        customerAddress: customerAddress,
        customerPhone: customerPhone,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        items: itemQuantities.entries.map((entry) {
          return InvoiceItem(
            name: entry.key,
            quantity: entry.value,
            unitPrice: _getItemPrice(entry.key),
          );
        }).toList(),
        subtotal: totalPrice,
        discount: appliedDiscount,
        total: _calculateTotal(),
        status: 'Issued',
      );

      String invoiceJson = jsonEncode(invoice.toJson());
      List<String> invoices = prefs.getStringList('issuedInvoices') ?? [];
      invoices.add(invoiceJson);
      await prefs.setStringList('issuedInvoices', invoices);

      showToast('Invoice finalized successfully!');

      // Print the receipt
      await _printReceipt(invoice);

      // Reset the form
      _resetInvoice();
    } catch (e) {
      showToast('Failed to finalize invoice: $e');
    }
  }

  Future<void> _printReceipt(Invoice invoice) async {
    try {
      // Auto-connect to saved printer first
      await _autoConnectSavedPrinter();

      // Check if connected to a printer
      if (_device == null || !_connected!) {
        showToast('Please connect to a printer first');
        return;
      }

      // Generate receipt content using simple text formatting
      final String receiptContent = _generateReceiptText(invoice);

      // Print the receipt using the instance
      await bluetooth.write(receiptContent);

      showToast('Receipt printed successfully!');
    } catch (e) {
      showToast('Printing failed: $e');
    }
  }

  String _generateReceiptText(Invoice invoice) {
    final StringBuffer sb = StringBuffer();

    // Header
    sb.writeln('INVOICE');
    sb.writeln(invoice.invoiceNumber);
    sb.writeln('=' * 32);

    // Company Info
    sb.writeln(fullname.isNotEmpty ? fullname : 'Your Business Name');
    sb.writeln('=' * 32);

    // Customer Information
    sb.writeln('Customer: ${invoice.customerName}');
    if (invoice.customerAddress.isNotEmpty) {
      sb.writeln('Address: ${invoice.customerAddress}');
    }
    if (invoice.customerPhone.isNotEmpty) {
      sb.writeln('Phone: ${invoice.customerPhone}');
    }

    // Dates
    sb.writeln('Date: ${_formatDate(invoice.invoiceDate)}');
    sb.writeln('Due: ${_formatDate(invoice.dueDate)}');
    sb.writeln('=' * 32);

    // Items Header
    sb.writeln('Item'.padRight(20) + 'Qty'.padRight(6) + 'Total'.padLeft(6));
    sb.writeln('-' * 32);

    // Items List
    for (var item in invoice.items) {
      String itemName = item.name.length > 18
          ? '${item.name.substring(0, 15)}...'
          : item.name;
      String quantity = item.quantity.toStringAsFixed(2);
      String total = '${currencySymbol}${item.total.toStringAsFixed(2)}';

      sb.writeln(
          itemName.padRight(20) + quantity.padRight(6) + total.padLeft(6));
    }

    sb.writeln('-' * 32);

    // Subtotal
    sb.writeln('Subtotal:'.padRight(26) +
        '${currencySymbol}${invoice.subtotal.toStringAsFixed(2)}'.padLeft(6));

    // Discount
    if (invoice.discount != null) {
      String discountText = invoice.discount!.type == DiscountType.Percentage
          ? 'Discount (${invoice.discount!.value}%):'
          : 'Discount:';
      double discountAmount = invoice.discount!.type == DiscountType.Percentage
          ? invoice.subtotal * (invoice.discount!.value / 100)
          : invoice.discount!.value;

      sb.writeln(discountText.padRight(26) +
          '-${currencySymbol}${discountAmount.toStringAsFixed(2)}'.padLeft(6));
    }

    // Total
    sb.writeln('=' * 32);
    sb.writeln('TOTAL:'.padRight(26) +
        '${currencySymbol}${invoice.total.toStringAsFixed(2)}'.padLeft(6));
    sb.writeln('=' * 32);

    // Footer
    sb.writeln('Thank you for your business!');
    sb.writeln('Status: ${invoice.status}');
    sb.writeln();
    sb.writeln();
    sb.writeln(); // Extra lines for paper cutting

    return sb.toString();
  }

  Future<void> _autoConnectSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int printerCount = prefs.getInt('printerCount') ?? 0;

      if (printerCount == 0) {
        showToast('No saved printers found.');
        return;
      }

      // Refresh bonded devices list before connecting
      await _refreshBondedDevices();

      for (int i = 0; i < printerCount; i++) {
        // Fetch printer address for each saved printer
        String? printerAddress = prefs.getString('printerAddress$i');

        if (printerAddress != null) {
          bool found = false;

          for (BluetoothDevice device in _devices) {
            if (device.address == printerAddress) {
              _device = device;
              await _connect(); // Connect to the device
              showToast('Connected to ${device.name}');
              found = true;
              break; // Stop after connecting to the first available saved printer
            }
          }

          if (!found) {
            showToast('No matching device found for saved printer $i.');
          }
        } else {
          showToast('No printer address found for printer $i.');
        }
      }
    } catch (e) {
      showToast('Error auto-connecting printer: $e');
    }
  }

  Future<void> _refreshBondedDevices() async {
    try {
      final List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      showToast('Error refreshing devices: $e');
    }
  }

  Future<void> _connect() async {
    if (_device == null) {
      showToast('No device selected.');
      return;
    }

    try {
      await bluetooth.connect(_device!);
      setState(() {
        _connected = true;
      });
      showToast('Connected to ${_device!.name}');
    } catch (e) {
      showToast('Cannot connect: $e');
      setState(() {
        _connected = false;
      });
    }
  }

  void _resetInvoice() {
    setState(() {
      itemQuantities.clear();
      totalPrice = 0.0;
      appliedDiscount = null;
      customerName = '';
      customerAddress = '';
      customerPhone = '';
      _generateInvoiceNumber();
      invoiceDate = DateTime.now();
      dueDate = DateTime.now().add(Duration(days: 30));
    });
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }
}

// Discount Classes
enum DiscountType { Percentage, Price }

class Discount {
  final double value;
  final DiscountType type;

  Discount({required this.value, required this.type});

  Map<String, dynamic> toJson() => {
        'value': value,
        'type': type.toString(),
      };

  factory Discount.fromJson(Map<String, dynamic> json) => Discount(
        value: json['value'],
        type: DiscountType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => DiscountType.Percentage,
        ),
      );
}

// Invoice Classes
class InvoiceItem {
  final String name;
  final double quantity;
  final double unitPrice;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        name: json['name'],
        quantity: json['quantity'],
        unitPrice: json['unitPrice'],
      );
}

class Invoice {
  final String invoiceNumber;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final double subtotal;
  final Discount? discount;
  final double total;
  final String status;

  Invoice({
    required this.invoiceNumber,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.invoiceDate,
    required this.dueDate,
    required this.items,
    required this.subtotal,
    this.discount,
    required this.total,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'customerName': customerName,
        'customerAddress': customerAddress,
        'customerPhone': customerPhone,
        'invoiceDate': invoiceDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount?.toJson(),
        'total': total,
        'status': status,
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        invoiceNumber: json['invoiceNumber'],
        customerName: json['customerName'],
        customerAddress: json['customerAddress'],
        customerPhone: json['customerPhone'],
        invoiceDate: DateTime.parse(json['invoiceDate']),
        dueDate: DateTime.parse(json['dueDate']),
        items: (json['items'] as List)
            .map((item) => InvoiceItem.fromJson(item))
            .toList(),
        subtotal: json['subtotal'],
        discount: json['discount'] != null
            ? Discount.fromJson(json['discount'])
            : null,
        total: json['total'],
        status: json['status'],
      );
}

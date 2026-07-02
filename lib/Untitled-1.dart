import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'pages/widgets/historyOrder.dart'; // Assuming this file contains Order and Product classes
import 'package:qr_flutter/qr_flutter.dart'; // Import for QR code generation
import 'dart:ui' as ui; // For ImageByteFormat
import 'package:image/image.dart' as img; // For image manipulation
import 'dart:typed_data'; // For Uint8List

class ViewHistoryPage extends StatefulWidget {
  @override
  _ViewHistoryPageState createState() => _ViewHistoryPageState();
}

class _ViewHistoryPageState extends State<ViewHistoryPage> {
  List<Order> orders = [];
  double totalRevenue = 0.0;
  int totalOrders = 0;
  bool isLoading = false; // State to manage loading
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance; // Add this line
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _device;
  bool _connected = false;
  String? _selectedOption; // To hold the selected dropdown value
  String currencySymbol = '\$'; // Default value
  List<String> codes = []; // Add this line
  bool _hideTotalOnHomepage = false; // Add this line

  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
    _loadOrders();
    _initBluetooth();
    loadCurrencySymbol();
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  Future<void> _checkPasswordRequirement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool requirePassword = prefs.getBool('addPasswordForUploadStock') ?? false;
    if (requirePassword) {
      _showPasswordDialog();
    }
  }

  Future<void> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    int passwordAttempts = 0;

    bool passwordMatched = false;
    while (passwordAttempts < 3 && !passwordMatched) {
      passwordMatched = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Enter Password'),
                content: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            errorText: passwordAttempts != 0
                                ? 'Wrong password, ${3 - passwordAttempts} attempt(s) remaining'
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: Text('Submit'),
                    onPressed: () async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      String savedPassword = prefs.getString('password') ?? '';
                      if (passwordController.text == savedPassword) {
                        Navigator.of(context).pop(true);
                      } else {
                        setState(() {
                          passwordAttempts++;
                        });
                        if (passwordAttempts >= 3) {
                          Navigator.of(context).pop(false); // Pop with false to indicate failure.
                        }
                      }
                    },
                  ),
                ],
              );
            },
          ) ??
          false; // Ensure it's never null
    }

    if (!passwordMatched && passwordAttempts >= 3) {
      Navigator.of(context).pop(); // Pop the entire page if password attempts fail.
    }
  }

  Future<void> _initBluetooth() async {
    _devices = await bluetooth.getBondedDevices();
    bluetooth.onStateChanged().listen((state) {
      setState(() {
        _connected = state == BlueThermalPrinter.CONNECTED;
      });
    });
    await _autoConnectSavedPrinter();
  }

  Future<bool> _isQuickSale(Order order) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> codes =
        (jsonDecode(prefs.getString('codes') ?? '[]') as List<dynamic>)
            .cast<String>();

    // Check if any product in the order has a code not in the codes list
    for (var product in order.products) {
      if (product.code.isNotEmpty && !codes.contains(product.code)) {
        return true;
      }
    }
    return false;
  }

  /* LOAD ORDERS*/
  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    bool hideTotal = prefs.getBool('hideTotalOnHomepage') ?? false;
    List<String> ordersJson = prefs.getStringList('orders') ?? [];
    List<Order> loadedOrders =
        ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();

    double revenue = 0.0;
    int ordersCount = loadedOrders.length; // Count all orders

    for (var order in loadedOrders) {
      if (!order.isRefunded) {
        if (order.total >= 0) {
          revenue += order.total; // Add positive total directly
        } else {
          // Add the absolute value of the negative total
          revenue += 0;
        }
      }
    }

    setState(() {
      orders = loadedOrders;
      totalRevenue = revenue;
      totalOrders = ordersCount; // Reflects all orders, including refunded
      codes = (jsonDecode(prefs.getString('codes') ?? '[]') as List<dynamic>)
          .cast<String>();
      _hideTotalOnHomepage = hideTotal; // Add this line to update the new state variable
    });
  }

  Future<void> _loadDraftOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> draftOrdersJson = prefs.getStringList('draftOrders') ?? [];
    List<Order> loadedDraftOrders =
        draftOrdersJson.map((str) => Order.fromJson(json.decode(str))).toList();

    setState(() {
      orders = loadedDraftOrders;
      totalRevenue = 0.0; // Drafts may not have a total revenue
      totalOrders = loadedDraftOrders.length;
    });
  }

  /* MARK REFUNDED */
  void _markAsRefunded(int index) async {
    setState(() {
      orders[index].isRefunded = true;
      orders[index].refundAmount = orders[index].total.abs(); // Store the absolute value of the original total as refund amount
    });

    // Save the updated order list to persistent storage
    await _saveOrders();

    // Reload orders to correctly recalculate totalRevenue and update UI
    await _loadOrders();

    Fluttertoast.showToast(
        msg: 'Order marked as refunded',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.orange, // Or a suitable color for refunds
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ordersJson =
        orders.map((order) => json.encode(order.toJson())).toList();
    await prefs.setStringList('orders', ordersJson);
  }

  Future<void> uploadSalesOnline(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    const String uploadUrl =
        "https://blueichor.org/uploadOffline1.php"; // URL for uploading sales
    final prefs = await SharedPreferences.getInstance();
    final String? shopId = prefs.getString('username');
    final String? password = prefs.getString('password');

    if (shopId == null || password == null) {
      print("Username or password not found.");
      Fluttertoast.showToast(
          msg: "Username or password not found.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Prepare the data for upload, excluding orders with negative totals.
    List<Map<String, dynamic>> ordersData = [];
    List<Order> ordersToKeep = [];

    for (var order in orders) {
      if (!order.isRefunded && order.total > 0) {
        ordersData.add(order.toJson());
      } else {
        ordersToKeep.add(order);
      }
    }

    try {
      var response = await http.post(
        Uri.parse(uploadUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'username': shopId,
          'orders': ordersData,
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success']) {
          print(jsonResponse['productUpdates']);
          print("Upload successful. Clearing orders...");

          // Remove only the orders from SharedPreferences
          await clearOrdersFromSharedPreferences(prefs);

          // Update the state to reflect changes
          setState(() {
            orders = ordersToKeep;
            totalRevenue = 0.0; // Assuming you want to reset totalRevenue
            totalOrders = ordersToKeep.length;
          });

          Fluttertoast.showToast(
              msg: "Upload successful",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 16.0);
        } else {
          print("Upload failed: ${jsonResponse['message']}");
          Fluttertoast.showToast(
              msg: "Upload failed: ${jsonResponse['message']}",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0);
        }
      } else {
        print("Server error: ${response.statusCode}");
        Fluttertoast.showToast(
            msg: "Server error: ${response.statusCode}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    } catch (e) {
      print("Error uploading orders: $e");
      Fluttertoast.showToast(
          msg: "Error uploading orders: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> clearOrdersFromSharedPreferences(SharedPreferences prefs) async {
    await prefs.remove('orders');
  }

  Future<void> _printLogo() async {
    final prefs = await SharedPreferences.getInstance();
    String? logoPath = prefs.getString('processedLogoPath');
    bool printLogo = prefs.getBool('printLogo') ?? true;

    if (printLogo && logoPath != null && _connected) {
      try {
        var result = await bluetooth.printImage(logoPath);
        if (result == true) {
          showToast("Logo printed successfully.");
        } else {
          showToast("Failed to print logo.");
        }
      } catch (e) {
        showToast("Error printing logo: $e");
      }
      bluetooth.printNewLine();
    } else {
      if (!_connected) {
        showToast("Printer not connected.");
      } else {
        showToast("Logo path not found or logo printing disabled.");
      }
    }
  }

  Future<void> _printOrderReceipt(Order order) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected != null && isConnected) {
      // Print logo if enabled
      await _printLogo(); // Call the logo printing function

      // Get shop details from SharedPreferences
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var shopName = prefs.getString('fullname');
      var tel = prefs.getString('tel');
      var address = prefs.getString('address');
      bool printQRCode = prefs.getBool('printReceiptId') ?? true;
      String? cashierName = order.cashierName;

      // Print shop header
      bluetooth.printCustom(shopName ?? '', 3, 1);
      bluetooth.printCustom(tel ?? '', 3, 1);
      bluetooth.printCustom(address ?? '', 3, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom('-------------------------------', 1, 0);

      // Print order header
      bluetooth.printCustom('Order Receipt', 2, 1);
      bluetooth.printNewLine();
      bluetooth.printLeftRight('Order Number', order.orderNumber, 1);
      if (cashierName != null && cashierName.isNotEmpty) {
        bluetooth.printLeftRight('Cashier', cashierName, 1);
      }
      bluetooth.printCustom(
          'Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(order.timestamp)}',
          1,
          1);
      bluetooth.printNewLine();
      bluetooth.printCustom('-------------------------------', 1, 0);
      bluetooth.printNewLine();

      // Print products
      bluetooth.printCustom('Products:', 1, 0);
      bluetooth.printNewLine();

      List<Map<String, dynamic>> qrProducts = [];
      List<String> codes = (jsonDecode(prefs.getString('codes1') ?? '[]') as List<dynamic>).cast<String>();
      List<String> measures = (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>).cast<String>();

      for (int i = 0; i < order.products.length; i++) {
        Product product = order.products[i];
        double totalValue = product.price * product.quantity;

        int index = codes.indexOf(product.code);
        String quantityText = '${product.quantity}';
        if (index != -1 && measures.length > index) {
          quantityText += ' ${measures[index]}';
        }

        bluetooth.printCustom(
          "${i + 1}. ${product.name} x $quantityText @ $currencySymbol${product.price} = $currencySymbol${totalValue.toStringAsFixed(2)}",
          1,
          0,
        );

        qrProducts.add({
          "name": product.name,
          "quantity": quantityText,
          "price": product.price,
          "code": product.code,
        });
      }

      bluetooth.printNewLine();
      bluetooth.printCustom('-------------------------------', 1, 0);
      bluetooth.printCustom('Total: $currencySymbol${order.total.toStringAsFixed(2)}', 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      await Future.delayed(Duration(milliseconds: 500)); // Short pause

      // Print QR code if enabled
      if (printQRCode) {
        // Minimal essential data for better scannability
        Map<String, dynamic> qrData = {
          "invoice": order.orderNumber,
        };

        String qrJson = jsonEncode(qrData);

        try {
          // Define a larger source size for better detail
          const int qrImageSourceSize = 384; // Increased source resolution

          final qrPainter = QrPainter(
            data: qrJson,
            version: QrVersions.auto,
            gapless: true,
            color: Colors.black, // QR code color
            emptyColor: Colors.white, // Background color
          );

          // Render the QR code to an image
          final ui.Image qrImage = await qrPainter.toImage(qrImageSourceSize.toDouble());
          final ByteData? byteData =
              await qrImage.toByteData(format: ui.ImageByteFormat.png);
          final Uint8List pngBytes = byteData!.buffer.asUint8List();

          // Convert PNG bytes to an image format suitable for BlueThermalPrinter
          final img.Image? decodedImage = img.decodeImage(pngBytes);
          if (decodedImage != null) {
            // Adjust this width to match your printer's physical printable width
            // Common values: 384 for 58mm printers, 576 for 80mm printers.
            // const int printerPhysicalWidth = 384; // Example for a 58mm printer

            // Resize and convert to grayscale
            final img.Image resizedImage = img.copyResize(decodedImage, width: 250);
            final img.Image grayscaleImage = img.grayscale(resizedImage);

            // You can optionally add a slight sharpening or contrast adjustment here if needed
            // final img.Image finalImage = img.adjustColor(grayscaleImage, contrast: 1.1);

            // Convert List<int> to Uint8List for printing
            final Uint8List bmpBytes = Uint8List.fromList(img.encodeBmp(grayscaleImage));

            bluetooth.printImageBytes(bmpBytes);
            bluetooth.printNewLine();
            bluetooth.printNewLine();
          } else {
            showToast("Failed to decode QR code image.");
          }
        } catch (e) {
          showToast("Error generating or printing QR code image: $e");
          print("QR Code Image Error: $e"); // Log the error for debugging
        }
      }

      bluetooth.printNewLine();
      bluetooth.printCustom('--- End of Receipt ---', 0, 1);
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } else {
      Fluttertoast.showToast(
          msg: "Printer not connected.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  Future<void> _autoConnectSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? printerAddress = prefs.getString('printerAddress0');
    if (printerAddress != null) {
      for (BluetoothDevice device in _devices) {
        if (device.address == printerAddress) {
          _device = device;
          try {
            await bluetooth.connect(_device!);
          } catch (e) {
            print("Error auto-connecting: $e");
            showToast("Failed to auto-connect to printer.");
          }
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order History'),
        automaticallyImplyLeading: false, // This line removes the back button
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTotalRevenueCard(),
                _buildTotalOrdersCard(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String>(
              value: _selectedOption,
              hint: Text('Select an Option'),
              items: <String>['Complete Orders', 'Saved Orders']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedOption = newValue;
                  if (newValue == 'Saved Orders') {
                    _loadDraftOrders();
                  } else {
                    _loadOrders();
                  }
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _buildOrderItem(orders[index], index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isLoading
            ? null
            : () async {
                await uploadSalesOnline(context);
              },
        tooltip: 'Upload Sales Online',
        child: isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Icon(Icons.cloud_upload),
      ),
    );
  }

Widget _buildTotalRevenueCard() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text('Total Revenue'),
          // Apply the conditional logic here to hide the total revenue
          Text(
            _hideTotalOnHomepage
                ? 'XX'
                : '$currencySymbol${totalRevenue.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTotalOrdersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text('Total Orders'),
            Text('$totalOrders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Order order, int index) {
    // Determine if it's a quick sale
    bool isQuickSale = order.products.any((product) =>
        product.code.isEmpty || !codes.contains(product.code));

    // Determine the background color
    Color backgroundColor = Colors.white;
    if (order.isRefunded) {
      backgroundColor = Colors.grey[200]!; // A light grey for refunded
    } else if (order.total < 0) {
      backgroundColor = Colors.red[100]!;
    } else if (isQuickSale) {
      backgroundColor = Colors.orange[100]!;
    }

    // Determine the title text based on the total and hideTotalOnHomepage
    String titleText = order.total >= 0 ? 'Order Total' : 'Credits';

return Card(
  color: backgroundColor,
  child: Stack(
    children: [
      if (isQuickSale)
        Positioned(
          top: 8,
          left: 8,
          child: Icon(Icons.flash_on, color: Colors.orange[800]),
        ),
      ExpansionTile(
        title: Text(
          _hideTotalOnHomepage && order.total >= 0
              ? '$titleText: XX'
              : '$titleText: $currencySymbol${order.total.abs().toStringAsFixed(2)}',
        ),
        subtitle: Text(
          '${isQuickSale ? 'QUICK SALE - ' : ''}'
          'Order ID: ${order.orderNumber}\n'
          // Add this line to show customer name for saved orders
          '${_selectedOption == 'Saved Orders' ? 'Customer: ${order.customerName ?? 'N/A'}\n' : ''}'
          'Cashier: ${order.cashierName ?? 'N/A'}'
        ),
        children: [
          ListTile(
            title: Text('Order Details'),
            subtitle: Text(
                'Order ID: ${order.orderNumber}\n'
                // You might also want to add it here for consistency in the expanded view
                'Customer: ${order.customerName ?? 'N/A'}\n'
                'Cashier: ${order.cashierName ?? 'N/A'}'),
          ),
          ...order.products.map((product) {
            return ListTile(
              title: Text(product.name),
              trailing: Text(
                  '$currencySymbol${product.price.toStringAsFixed(2)} x ${product.quantity}'),
            );
          }).toList(),
          if (order.isRefunded)
            ListTile(
              title: Text("Refunded"),
              subtitle: Text(
                  "Refund Amount: $currencySymbol${order.refundAmount.toStringAsFixed(2)}"),
            ),
          if (order.total < 0 && !order.isRefunded)
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _markAsRefunded(index),
                    child: Text('Refund'),
                  ),
                  ElevatedButton(
                    onPressed: () => _markAsPaid(order),
                    child: Text('Paid'),
                  ),
                ],
              ),
            ),
          if (_selectedOption != 'Saved Orders') ...[
            if (order.total >= 0 && !order.isRefunded)
              ListTile(
                title: TextButton(
                  child: Text("Mark as Refunded"),
                  onPressed: () => _markAsRefunded(index),
                ),
              ),
            if (!order.isRefunded)
              ListTile(
                title: TextButton(
                  child: Text("Print Receipt"),
                  onPressed: () => _printOrderReceipt(order),
                ),
              ),
          ],
          if (_selectedOption == 'Saved Orders')
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _completeDraft(index),
                    child: Text('Complete'),
                  ),
                  ElevatedButton(
                    onPressed: () => _deleteDraft(index),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  ),
);}

  void _completeDraft(int index) async {
    // Handle completing the draft
    Order draftOrder = orders[index];

    // Remove the draft from the list and save the updated list
    orders.removeAt(index);
    await _saveDraftOrders();

    // Move the draft to the complete orders list
    final prefs = await SharedPreferences.getInstance();
    List<String> completeOrdersJson = prefs.getStringList('orders') ?? [];
    completeOrdersJson.add(jsonEncode(draftOrder.toJson()));
    await prefs.setStringList('orders', completeOrdersJson);

    setState(() {
      totalOrders = orders.length; // Update total orders after moving
      // Recalculate total revenue as well since a draft was moved to complete
      _loadOrders();
    });

    Fluttertoast.showToast(
        msg: 'Order Complete',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void _deleteDraft(int index) async {
    // Remove the draft from the list and save the updated list
    orders.removeAt(index);
    await _saveDraftOrders();

    setState(() {
      totalOrders = orders.length;
    });

    Fluttertoast.showToast(
        msg: 'Order Deleted',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> _saveDraftOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> draftOrdersJson =
        orders.map((order) => jsonEncode(order.toJson())).toList();
    await prefs.setStringList('draftOrders', draftOrdersJson);
  }

  void _markAsPaid(Order order) async {
    setState(() {
      // Convert total to positive
      order.total = order.total.abs();
      // Remove from draft orders if it was a draft
      orders.removeWhere((o) => o.orderNumber == order.orderNumber);
    });

    // Save the updated order list to shared preferences
    final prefs = await SharedPreferences.getInstance();
    List<String> completeOrdersJson = prefs.getStringList('orders') ?? [];
    completeOrdersJson.add(jsonEncode(order.toJson()));
    await prefs.setStringList('orders', completeOrdersJson);

    // Reload orders to correctly recalculate totalRevenue and update UI
    await _loadOrders();

    Fluttertoast.showToast(
        msg: 'Order marked as paid',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM);
  }
    @override
  void dispose() {
    // Only disconnect if connected to prevent errors
    if (_connected) {
      bluetooth.disconnect();
    }
    super.dispose();
  }
}

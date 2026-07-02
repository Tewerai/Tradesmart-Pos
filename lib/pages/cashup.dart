import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'widgets/sell.dart'; // Assuming this file contains the Order class definition

class CashoutPage extends StatefulWidget {
  @override
  _CashoutPageState createState() => _CashoutPageState();
}

class _CashoutPageState extends State<CashoutPage> {
  List<Order> orders = [];
  double totalRevenue = 0.0;
  int totalOrders = 0;
  double? startUpAmount;
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  bool _connected = false;
  BluetoothDevice? _device;
  List<BluetoothDevice> _devices = [];
  String currencySymbol = '\$'; // Default value
  bool _hideTotalOnHomepage = false; // Added state variable for hiding totals

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Consolidated initial data loading
  }

  // Consolidated function to load all necessary data
  Future<void> _loadInitialData() async {
    await _loadOrders();
    await _loadStartUpAmount();
    await loadCurrencySymbol();
    await _loadHideTotalPreference(); // Load the hide total preference
    await _initBluetooth();
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  // New function to load the hideTotalOnHomepage preference
  Future<void> _loadHideTotalPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideTotalOnHomepage = prefs.getBool('hideTotalOnHomepage') ?? false;
    });
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> ordersJson = prefs.getStringList('orders') ?? [];
    List<Order> loadedOrders = ordersJson.map((str) => Order.fromJson(json.decode(str))).toList();

    double revenue = 0.0;
    int validOrdersCount = 0; // Counter for non-refunded orders

    for (var order in loadedOrders) {
      // Only include non-refunded orders in revenue and count
      if (!order.isRefunded) {
        revenue += order.total;
        validOrdersCount++;
      }
    }

    setState(() {
      orders = loadedOrders; // Keep all orders for display, but filter for calculations
      totalRevenue = revenue;
      totalOrders = validOrdersCount; // Only count non-refunded orders
    });
  }

  Future<void> _loadStartUpAmount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      startUpAmount = prefs.getDouble('startUpAmount');
    });
  }

  Future<void> _saveStartUpAmount(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('startUpAmount', amount);
    setState(() {
      startUpAmount = amount;
    });
  }

  Future<void> _showStartUpDialog() async {
    TextEditingController controller = TextEditingController();
    double? enteredAmount;

    // Prefill with current startUpAmount if available
    if (startUpAmount != null) {
      controller.text = startUpAmount!.toStringAsFixed(2);
      enteredAmount = startUpAmount;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter Start Up Amount"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: "Enter amount",
            ),
            onChanged: (value) {
              enteredAmount = double.tryParse(value);
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () {
                if (enteredAmount != null) {
                  _saveStartUpAmount(enteredAmount!);
                } else {
                  // Optionally show a toast or error for invalid input
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid number')),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

  Future<void> _autoConnectSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? printerAddress = prefs.getString('printerAddress0'); // Assuming the first saved printer
    if (printerAddress != null) {
      for (BluetoothDevice device in _devices) {
        if (device.address == printerAddress) {
          _device = device;
          try {
            await bluetooth.connect(_device!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auto-connected to ${device.name}')),
            );
          } catch (e) {
            print("Error auto-connecting: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to auto-connect to printer: ${device.name}')),
            );
          }
          break;
        }
      }
    }
  }

  Future<void> _printOrders() async {
    if (_connected) {
      bluetooth.printCustom('Cashout Summary', 2, 1);
      bluetooth.printNewLine();

      final displayRevenue = _hideTotalOnHomepage ? 'XX' : totalRevenue.toStringAsFixed(2);
      final displayOrders = _hideTotalOnHomepage ? 'XX' : totalOrders.toString();
      final displayStartUpAmount = _hideTotalOnHomepage && startUpAmount != null ? 'XX' : (startUpAmount?.toStringAsFixed(2) ?? '--');


      bluetooth.printCustom('Total Revenue: $currencySymbol $displayRevenue', 1, 1);
      bluetooth.printCustom('Total Orders: $displayOrders', 1, 1);
      bluetooth.printCustom('Start-Up Cash: $currencySymbol $displayStartUpAmount', 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom('Order Details:', 1, 1);
      bluetooth.printNewLine();

      // Filter orders to only print non-refunded ones, as per user's likely intention for cashout
      List<Order> nonRefundedOrders = orders.where((order) => !order.isRefunded).toList();

      if (nonRefundedOrders.isEmpty) {
        bluetooth.printCustom('No non-refunded orders to display.', 1, 1);
        bluetooth.printNewLine();
      } else {
        for (var order in nonRefundedOrders) {
          final orderDisplayTotal = _hideTotalOnHomepage ? 'XX' : order.total.toStringAsFixed(2);
          bluetooth.printCustom('Order ID: ${order.orderNumber}', 1, 0); // Use actual orderNumber
          bluetooth.printCustom('Total: $currencySymbol $orderDisplayTotal', 1, 0);
          bluetooth.printCustom('Date: ${DateFormat('yyyy-MM-dd – HH:mm').format(order.timestamp)}', 0, 0);
          bluetooth.printNewLine();
        }
      }

      bluetooth.printCustom('--- End of Report ---', 0, 1);
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Printer not connected.")),
      );
    }
  }

  Widget _buildCard({required String title, required String value, required String tooltip}) {
    // Determine the value to display based on _hideTotalOnHomepage
    String displayedValue = _hideTotalOnHomepage && title.contains('Total') ? 'XX' : value;

    return Expanded( // Use Expanded to make cards take equal space
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4.0), // Add horizontal margin
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title),
                  Tooltip(
                    message: tooltip,
                    child: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Text(
                displayedValue, // Use the adjusted displayedValue
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cashout'),
        automaticallyImplyLeading: false, // This line removes the back button
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCard(
                  title: 'Total Revenue',
                  value: '$currencySymbol${totalRevenue.toStringAsFixed(2)}',
                  tooltip: 'This is the total revenue from non-refunded orders for the day.',
                ),
                _buildCard(
                  title: 'Total Orders',
                  value: '$totalOrders',
                  tooltip: 'This is the total number of non-refunded orders for the day.',
                ),
                Expanded( // Added Expanded for consistency
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: _showStartUpDialog,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.wb_sunny, size: 20),
                                    SizedBox(width: 4),
                                    Text('Start-Up Cash'),
                                  ],
                                ),
                                Tooltip(
                                  message: 'This is the start-up cash amount.',
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _hideTotalOnHomepage && startUpAmount != null
                                  ? 'XX'
                                  : (startUpAmount != null ? '$currencySymbol${startUpAmount!.toStringAsFixed(2)}' : '$currencySymbol--'),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              // Filter orders for display: show only non-refunded ones
              itemCount: orders.where((order) => !order.isRefunded).length,
              itemBuilder: (context, index) {
                final order = orders.where((order) => !order.isRefunded).toList()[index]; // Get the actual non-refunded order

                // Determine display total for individual order
                final orderDisplayTotal = _hideTotalOnHomepage
                    ? 'XX'
                    : order.total.toStringAsFixed(2);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0), // Add margin for better spacing
                  child: ListTile(
                    title: Text('Order ID: ${order.orderNumber}'), // Use actual order number
                    subtitle: Text('Total: $currencySymbol$orderDisplayTotal\nDate: ${DateFormat('yyyy-MM-dd – HH:mm').format(order.timestamp)}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _printOrders,
        child: Icon(Icons.print),
        tooltip: 'Print Orders',
      ),
    );
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
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(GuardApp());
}

class GuardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard Verification',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GuardVerificationPage(),
    );
  }
}

class Order {
  final String invoice;
  final String date;
  final String customer;
  final String cashier;
  final List<dynamic> products;
  final String total;
  final String change;
  final bool verified;

  Order({
    required this.invoice,
    required this.date,
    required this.customer,
    required this.cashier,
    required this.products,
    required this.total,
    required this.change,
    required this.verified,
  });

  Map<String, dynamic> toJson() => {
        'invoice': invoice,
        'date': date,
        'customer': customer,
        'cashier': cashier,
        'products': products,
        'total': total,
        'change': change,
        'verified': verified,
      };

  static Order fromJson(Map<String, dynamic> json) => Order(
        invoice: json['invoice'],
        date: json['date'],
        customer: json['customer'],
        cashier: json['cashier'],
        products: List<dynamic>.from(json['products']),
        total: json['total'],
        change: json['change'],
        verified: json['verified'],
      );
}

class GuardVerificationPage extends StatefulWidget {
  @override
  _GuardVerificationPageState createState() => _GuardVerificationPageState();
}

class _GuardVerificationPageState extends State<GuardVerificationPage> {
  List<Order> scannedOrders = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('scanned_orders') ?? [];
    setState(() {
      scannedOrders = data.map((e) => Order.fromJson(json.decode(e))).toList();
    });
  }

  Future<void> _saveOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final data =
        scannedOrders.map((order) => json.encode(order.toJson())).toList();
    await prefs.setStringList('scanned_orders', data);
  }

  int get totalCount => scannedOrders.length;
  int get verifiedCount => scannedOrders.where((o) => o.verified).length;

  Future<void> _scanQRCode() async {
    if (isScanning) return;

    try {
      isScanning = true;
      String scannedData = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.QR);

      if (scannedData == "-1") return; // user cancelled

      final Map<String, dynamic> qrData = json.decode(scannedData);
      final String scannedInvoice = qrData['invoice'] ?? 'N/A';

      // Check for duplicates
      bool isDuplicate =
          scannedOrders.any((order) => order.invoice == scannedInvoice);

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Receipt already scanned for invoice: $scannedInvoice')),
          );
        }
        return;
      }

      final newOrder = Order(
        invoice: scannedInvoice,
        date: qrData['date'] ?? 'N/A',
        customer: qrData['customer'] ?? 'N/A',
        cashier: qrData['cashier'] ?? 'N/A',
        products: qrData['products'] ?? [],
        total: qrData['total'] ?? '0.00',
        change: qrData['change'] ?? '0.00',
        verified: true,
      );

      setState(() {
        scannedOrders.add(newOrder);
      });

      await _saveOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${newOrder.invoice} scanned successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid or unreadable QR code')),
        );
      }
    } finally {
      isScanning = false;
    }
  }

  Future<void> _uploadQRCode() async {
    if (scannedOrders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No orders to upload')),
        );
      }
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading orders...')),
        );
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? shopid = prefs.getString('username');
      const guardName =
          'Guard Name'; // Replace with actual guard name or get from SharedPreferences

      // Track successfully uploaded orders
      List<Order> successfullyUploaded = [];

      for (final order in scannedOrders) {
        final orderData = {
          'guard_name': guardName,
          'order_id': order.invoice,
          'order_details': json.encode({
            'date': order.date,
            'customer': order.customer,
            'cashier': order.cashier,
            'products': order.products,
            'change': order.change,
          }),
          'total': order.total,
          'time': DateTime.now().toIso8601String(),
          'shopid': shopid,
        };

        final response = await http.post(
          Uri.parse('https://aphel.blueichor.org/save_order.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(orderData),
        );

        if (response.statusCode == 201) {
          successfullyUploaded.add(order);
        } else {
          throw Exception(
              'Failed to upload order ${order.invoice}: ${response.body}');
        }
      }

      // Remove successfully uploaded orders from local storage
      if (successfullyUploaded.isNotEmpty) {
        setState(() {
          scannedOrders.removeWhere((order) => successfullyUploaded.contains(order));
        });
        await _saveOrders();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${successfullyUploaded.length} orders uploaded successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --- Dismissible Logic ---
  void _deleteOrder(int index) {
    setState(() {
      scannedOrders.removeAt(index);
    });
    _saveOrders(); // Save the updated list after deletion
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order deleted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guard Verification'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildStatCard('Total Orders', totalCount, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('Verified', verifiedCount, Colors.green),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scannedOrders.length,
              itemBuilder: (context, index) {
                final order = scannedOrders[index];
                return Dismissible(
                  key: Key(order.invoice), // Unique key for each dismissible item
                  direction: DismissDirection.endToStart, // Only swipe left
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _deleteOrder(index);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('Invoice: ${order.invoice}'),
                      subtitle: Text(
                        'Date: ${order.date}\nCustomer: ${order.customer}\nCashier: ${order.cashier}\nProducts: ${order.products.join(', ')}\nTotal: \$${order.total} | Change: \$${order.change}',
                      ),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                      isThreeLine: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'scanBtn',
            onPressed: _scanQRCode,
            child: const Icon(Icons.camera_alt),
            backgroundColor: Colors.blueAccent,
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'uploadBtn',
            onPressed: _uploadQRCode,
            child: const Icon(Icons.upload_file),
            backgroundColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
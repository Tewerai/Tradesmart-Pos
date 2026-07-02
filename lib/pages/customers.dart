import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Required for currency formatting if desired

// --- Customer Model Class ---
// Place this in a shared models directory (e.g., lib/models/customer.dart)
// or at the top of this file if you prefer.
class Customer {
  final String name;
  final String? surname;
  final String? email;
  final String? tel;
  final double totalSpent;

  Customer({
    required this.name,
    this.surname,
    this.email,
    this.tel,
    this.totalSpent = 0.0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      name: json['name'] as String,
      surname: json.containsKey('surname') ? json['surname'] as String? : null,
      email: json.containsKey('email') ? json['email'] as String? : null,
      tel: json.containsKey('tel') ? json['tel'] as String? : null,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'surname': surname,
      'email': email,
      'tel': tel,
      'totalSpent': totalSpent,
    };
  }
}
// --- End Customer Model Class ---


class CustomerListPage extends StatefulWidget {
  const CustomerListPage({Key? key}) : super(key: key);

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  List<Customer> _customers = [];
  String _currencySymbol = '\$'; // Default currency symbol

  @override
  void initState() {
    super.initState();
    _loadCustomerData(); // Load customer data when the page initializes
    _loadCurrencySymbol(); // Load currency symbol
  }

  /// Loads the list of customers from SharedPreferences.
  Future<void> _loadCustomerData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> customersJson = prefs.getStringList('customers') ?? [];
    setState(() {
      _customers = customersJson.map((jsonString) => Customer.fromJson(json.decode(jsonString))).toList();
    });
  }

  /// Loads the currency symbol from SharedPreferences.
  Future<void> _loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer List'),
        actions: [
          // Refresh button to reload customer data
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomerData,
            tooltip: 'Refresh Customer Data',
          ),
        ],
      ),
      body: _customers.isEmpty
          ? const Center(
              // Display a message if no customers are found
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No customers found. Customers you enter during sales will appear here.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _customers.length,
              itemBuilder: (context, index) {
                final customer = _customers[index];
                return Card(
                  elevation: 4, // Add some shadow for depth
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Slightly rounded corners
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Name (bold and prominent)
                        Text(
                          '${customer.name}${customer.surname != null && customer.surname!.isNotEmpty ? ' ${customer.surname}' : ''}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple, // Distinct color for name
                          ),
                        ),
                        const SizedBox(height: 8), // Spacing below name

                        // Email (if available)
                        if (customer.email != null && customer.email!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.email, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    customer.email!,
                                    style: const TextStyle(fontSize: 15),
                                    overflow: TextOverflow.ellipsis, // Handle long emails
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Phone Number (if available)
                        if (customer.tel != null && customer.tel!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.phone, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  customer.tel!,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),

                        // Separator line
                        Divider(color: Colors.grey[300], thickness: 1),
                        const SizedBox(height: 8),

                        // Total Spent
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Spent:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$_currencySymbol${customer.totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green, // Highlight total spent
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
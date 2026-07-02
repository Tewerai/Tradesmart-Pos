import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<dynamic> names = [];
  List<dynamic> prices = [];
  List<dynamic> quantities = [];
  List<Product> products = [];
  List codes = [];

  String filterQuery = '';

  @override
  void initState() {
    super.initState();
    getProductDetails();
  }

  Future<void> getProductDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String? productsName = prefs.getString('products');
      String? productsCodes = prefs.getString('codes');
      String? productsPrices = prefs.getString('prices');
      String? productsQuantities = prefs.getString('quantities');

      setState(() {
        if (productsName != null) {
          names = json.decode(productsName);
        }
        if (productsCodes != null) {
          codes = json.decode(productsCodes);
        }
        if (productsPrices != null) {
          prices = json.decode(productsPrices);
        }
        if (productsQuantities != null) {
          quantities = json.decode(productsQuantities);
        }

        if (names.isEmpty || prices.isEmpty || quantities.isEmpty) {
          showToast("Product names, prices, or quantities are missing.");
          return;
        }

        if (names.length != prices.length || names.length != quantities.length) {
          showToast("Data length mismatch in products, prices, and quantities.");
          return;
        }

        products = List.generate(names.length, (i) {
          try {
            double price = double.parse(prices[i].toString());
            int quantity = int.parse(quantities[i].toString());
            double amountMade = price * quantity;
            String category = 'Category 1';
            int itemsSold = (quantity ~/ 2);
            return Product(names[i], price, quantity, amountMade, category, itemsSold);
          } catch (e) {
            showToast("Error parsing product at index $i: $e");
            return null;
          }
        }).whereType<Product>().toList();
      });
    } catch (e) {
      showToast("Error fetching product details: $e");
      print("Error fetching product details: $e");
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  List<Product> getFilteredProducts() {
    return products.where((product) {
      final productName = product.name.toLowerCase();
      return productName.contains(filterQuery.toLowerCase());
    }).toList();
  }

  void showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Price: \$${product.price.toStringAsFixed(2)}'),
              Text('Quantity: ${product.quantity}'),
              Text('Amount Made: \$${product.amountMade.toStringAsFixed(2)}'),
              Text('Category: ${product.category}'),
              Text('Items Sold: ${product.itemsSold}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product List'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (query) {
                setState(() {
                  filterQuery = query;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Products',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: getFilteredProducts().length,
              itemBuilder: (context, index) {
                final product = getFilteredProducts()[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: ListTile(
                    title: Text(product.name),
                    subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: () => showProductDetails(product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Product {
  final String name;
  final double price;
  final int quantity;
  final double amountMade;
  String category;
  final int itemsSold;

  Product(this.name, this.price, this.quantity, this.amountMade, this.category, this.itemsSold);
}

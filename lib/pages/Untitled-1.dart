import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http; // Add this import for HTTP requests

import 'printer2.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'widgets/sell.dart';
import 'package:path_provider/path_provider.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'; // Add this import

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
  bool _isProcessingOrder = false; // Add loading state

  int orderNumberCounter = 1; // Counter for generating order numbers

  double get totalItems =>
      itemQuantities.values.fold(0, (sum, quantity) => sum + quantity);

  String fullname = '';
  List<dynamic> products = [];
  List<dynamic> price = [];
  List<dynamic> codes = [];
  List<dynamic> cats = [];

  // Add a list of categories for the dropdown
  List<String> categories = [];
  String? selectedCategory; // To track the selected category
  List<dynamic> measures = [];
  String currencySymbol = '\$'; // Default value
  Map<String, double> quickSalePrices = {};


  @override
  void initState() {
    super.initState();
    loadCurrencySymbol();
    _loadData();
    _loadCategories();
  }

  Future<void> loadCurrencySymbol() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currencySymbol = prefs.getString('currencySymbol') ?? '\$';
    });
  }

  Future<void> _loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
// Assume you've added a 'measures' list alongside your existing data lists

// Within _loadData, load 'measures' similarly to how you load 'products', 'price', etc.

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
      // List<String> pricesStr =
      //    (prefs.getString('prices1') ?? '[]') as List<String>;
      // price = pricesStr.map((e) => double.tryParse(e) ?? 0.0);
      //codes = (prefs.getString('codes1') ?? '[]') as List;
      measures =
          (jsonDecode(prefs.getString('measure') ?? '[]') as List<dynamic>)
              .cast<String>();
    });
    print(measures);
  }


  Future<void> _loadCategories() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? categoriesJson = prefs.getString('categories');
    if (categoriesJson != null) {
      try {
        List<dynamic> decodedCategories = json.decode(categoriesJson);
        // Use a set to filter out duplicates and cast each element to a String.
        final Set<String> categorySet = decodedCategories
            .where((category) =>
                category != null && category is String && category.isNotEmpty)
            .cast<String>() // Cast to String to satisfy the type system.
            .toSet(); // Convert to a set to remove duplicates.
        final List<String> filteredCategories =
            categorySet.toList(); // Convert back to a list.

        setState(() {
          categories = ['All', ...filteredCategories];
          selectedCategory = 'All';
          cats = decodedCategories;
        });
      } catch (e) {
        print("Error decoding categories: $e");
        // Handle or log error
      }
    } else {
      // Handle case where categories is null or not set
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
      // Show all products when no category is selected or when "All" is selected
      filteredProducts.addAll(products.cast<String>());
    } else {
      // Iterate through all products and their categories
      for (int i = 0; i < products.length; i++) {
        // Check if the category at the current index is not null
        if (i < cats.length && cats[i] != null) {
          String productCategory = cats[i];
          // Check if the product's category matches the selected category
          if (productCategory == selectedCategory) {
            filteredProducts.add(products[i] as String);
          }
        }
        // If cats[i] is null, it simply skips the current iteration
      }
    }

    // Further filter products based on search text if any
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
      return imagePath; // Return the image path if it exists
    }
    return ''; // Return an empty string if the image doesn't exist
  } catch (e) {
    print("Error checking image for $productName: $e");
    return ''; // Return an empty string on error
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Shopping Page',
                style: TextStyle(fontSize: 20)), // Title aligned to the left
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
        // If your AppBar has other properties like actions, keep them here.
      ),
      body: _isProcessingOrder ? _buildLoadingIndicator() : Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.qr_code_scanner), // Use the barcode icon
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
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
              ),
              itemCount: _getFilteredItemCount(), // Adjusted item count
              itemBuilder: (context, index) {
  final filteredProducts = _getFilteredProducts(); // Get filtered products

  if (index < filteredProducts.length) {
    final itemName = filteredProducts[index];
    final itemPrice = price[products.indexOf(itemName)];

    return Card(
      child: InkWell(
        onTap: () {
          // Existing onTap logic
          String measureType = measures[products.indexOf(itemName)];
          double itemKgPrice =
              double.tryParse(price[products.indexOf(itemName)]) ?? 0.0;

          if (measureType == "kgs") {
            _showKgsDialog(context, itemName, itemKgPrice);
          } else if (measureType == "metres") {
            _showKgsDialog(context, itemName, itemKgPrice);
          } else if (measureType == "centimetres") {
            _showKgsDialog(context, itemName, itemKgPrice);
          } else if (measureType == "lbs") {
            _showKgsDialog(context, itemName, itemKgPrice);
          } else if (measureType == "units") {
            setState(() {
              itemQuantities.update(itemName, (value) => ++value,
                  ifAbsent: () => 1);
              totalPrice += double.parse(itemPrice);
            });
          }
          print(itemQuantities);
        },
        onLongPress: () {
          _showQuantityDialog(context, itemName);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            FutureBuilder<String>(
              future: _getImagePath(itemName), // Load image path
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator(); // Optional loading indicator
                }
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Image.file(
                    File(snapshot.data!), // Display the image
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  );
                }
                // Fallback to basket icon if no image found
                return Icon(
                  Icons.shopping_basket,
                  size: 80,
                );
              },
            ),
            SizedBox(height: 8.0),
            Text(
              itemName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Price: $currencySymbol${itemPrice}'),
          ],
        ),
      ),
    );
  } else {
    return null; // Return null for items beyond the filtered count
  }
},
),
          ),
          Container(
            padding: EdgeInsets.all(16.0),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessingOrder ? null : () => _showOrderDialog(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Complete Order $currencySymbol${totalPrice.toStringAsFixed(2)}'),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Processing order...\nChecking internet connection...', 
               textAlign: TextAlign.center,
               style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    try {
      String barcodeScanRes;
      // Play sound
     // final player = AudioPlayer();

      /*await player.setUrl('beep-01a.mp3');
      await player.play();*/

      // Vibrate device
      print('Code Activated');
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666", // scan button color
        "Cancel", // cancel button text
        true, // show flash icon
        ScanMode.DEFAULT, // <--- Add this argument
      );
      if (!mounted) {
        return;
      }

      // Process the scanned barcode here
      print('Barcode: $barcodeScanRes');

      // Find the index of the scanned barcode in the 'codes' list
      int barcodeIndex = codes.indexOf(barcodeScanRes);

      if (barcodeIndex != -1) {
        // Barcode found in the 'codes' list, retrieve the associated product name and price
        String productName = products[barcodeIndex];
        String itemPrice = price[barcodeIndex];

        // Add the product to the cart
        String measureType = measures[barcodeIndex];
        if (measureType == "kgs") {
          // If the product is measured in kgs, show a dialog or another UI to handle this case
          double itemKgPrice = double.tryParse(itemPrice) ?? 0.0;
          _showKgsDialog(context, productName, itemKgPrice);
        } else {
          // If the product is measured in units, proceed as before
          setState(() {
            itemQuantities.update(productName, (value) => ++value,
                ifAbsent: () => 1);
            totalPrice += double.parse(itemPrice);
          });
        }
        print(itemQuantities);
        Vibration.vibrate(duration: 500);
      } else {
        // Barcode not found in the 'codes' list
        print('Product not found for barcode: $barcodeScanRes');
      }
    } catch (e) {
      print('Error: $e');
      showToast("Error: $e");
      // Handle the error here, for example by showing a snackbar or an alert dialog
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
                // Display selected items
                ...itemQuantities.entries.map((entry) {
                  String itemName = entry.key;
                  double quantity = entry.value;
                 int productIndex = products.indexOf(itemName);
                 double itemPrice;
                 if (productIndex != -1) {
                   itemPrice = double.parse(price[productIndex]);
                 } else {
                   // If it's a quick sale item, store its price somewhere else (like a quickSalePrices map)
                   itemPrice = quickSalePrices[itemName] ?? 0.0;
                 }

                  return Column(
                    children: [
                      ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$itemName x $quantity'),
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
                // Buttons in two rows
                SizedBox(
                  height: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Discount and Complete Order buttons
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
                      // Save Draft and Quick Sale buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isProcessingOrder ? null : _saveOrderAsDraft,
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

  // Convert products to List<String> to ensure type safety
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
                    // Find the product code
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                            productNameController.text = matchingProducts[index];
                            int productIndex =
                                productNames.indexOf(matchingProducts[index]);
                            if (productIndex != -1 && productIndex < codes.length) {
                              selectedProductCode = codes[productIndex].toString();
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
  String changeText = ''; // Initialize an empty string for change text

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        // Use StatefulBuilder to update the dialog's content
        builder: (context, setState) {
          // Calculate the current change based on the controller's text
          // and totalPrice. This ensures the 'Complete' button's logic
          // is always based on the latest input.
          double enteredAmount = double.tryParse(_controller.text) ?? 0.0;
          double currentChange = enteredAmount - totalPrice;

          return AlertDialog(
            title: Text('Received Amount'),
            content: Column(
              mainAxisSize: MainAxisSize.min, // Use min to fit content
              children: [
                TextField(
                  controller: _controller,
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Enter amount',
                  ),
                  onChanged: (value) {
                    // Update the dialog's state to refresh the displayed change
                    setState(() {
                      double enteredValue = double.tryParse(value) ?? 0.0;
                      double result = enteredValue - totalPrice;
                      changeText = 'Change: $currencySymbol${result.toStringAsFixed(2)}';
                    });
                  },
                ),
                SizedBox(height: 20), // Add some spacing
                // Display the dynamically updated change text
                Text(changeText,
                    style: TextStyle(color: Colors.blue, fontSize: 16)),
              ],
            ),
            actions: <Widget>[
              TextButton(
                // Conditionally enable/disable the 'Complete' button
                // If currentChange is negative, the button will be disabled.
                onPressed: _isProcessingOrder || currentChange < 0
                    ? null // Disable button if processing or change is negative
                    : () async {
                        final SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        // No need to recalculate enteredAmount and result here
                        // as currentChange is already up-to-date.

                        // Save the calculated change to SharedPreferences
                        await prefs.setString('changes', currentChange.toString());
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
    // Define controllers for input field and radio buttons
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
                        // Update the discounted price whenever the discount value changes
                        double discountValue = double.tryParse(value) ?? 0;
                        if (selectedDiscountType == DiscountType.Percentage) {
                          double percentage = discountValue / 100;
                          discountedPrice =
                              totalPrice - (totalPrice * percentage);
                        } else {
                          discountedPrice = totalPrice.toDouble() - discountValue.toDouble();
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
                  // Display the calculated price
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
                // Apply the discount here
                double discountValue = double.tryParse(discountController.text) ?? 0;
                appliedDiscount =
                    Discount(value: discountValue, type: selectedDiscountType);
                _applyDiscount(appliedDiscount!);
                Navigator.of(context).pop();
              },
              child: Text('Apply'),
            ),
            TextButton(
              onPressed: () {
                // Save the total as a negative value (credit)
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
      showToast('Credit amount saved: $currencySymbol${creditAmount.toStringAsFixed(2)}');
      setState(() {
        totalPrice = creditAmount;
      });
      // Pop both the discount dialog and the order dialog from the stack
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Finalize the order
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
      discountedTotal = totalBeforeDiscount.toDouble() -discount.value.toDouble(); //
    }

    setState(() {
      totalPrice = discountedTotal;
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

  // Rebuild the dialog with updated quantities
  Navigator.of(context).pop();
  Future.delayed(Duration.zero, () {
    _showOrderDialog(context);
  });
}

// ========================== UPDATED _finalizeOrder METHOD ==========================
void _finalizeOrder() async {
  // Set processing state to true to show loading indicator
  setState(() {
    _isProcessingOrder = true;
  });
  
  try {
    // Check internet connectivity BEFORE processing the order
    bool isConnected = await InternetConnection().hasInternetAccess;
    
    if (!mounted) return;
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    List<Product> orderProducts = [];
    for (var entry in itemQuantities.entries) {
      int productIndex = products.indexOf(entry.key);
      String name = entry.key;
      double quantity = entry.value;
      double productPrice;
      String code;

      if (productIndex != -1 && productIndex < codes.length) {
        // Normal product
        code = codes[productIndex];
        productPrice = double.tryParse(price[productIndex]) ?? 0.0;
      } else {
        // Quick sale product
        productPrice = quickSalePrices[name] ?? 0.0;
        String sanitized = name.replaceAll(RegExp(r'\s+'), ''); // remove spaces
        int randomDigits = DateTime.now().millisecondsSinceEpoch.remainder(10000);
        code = 'QK_${sanitized}_$randomDigits';
      }

      orderProducts.add(Product(
        name: name,
        code: code,
        price: productPrice,
        quantity: quantity,
      ));
    }

    if (orderProducts.isEmpty) {
      showToast('No products to add to the order.');
      setState(() {
        _isProcessingOrder = false;
      });
      return;
    }

    String? cashierName = await _getActiveCashierName() ?? '';

    String orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}-$orderNumberCounter';
    orderNumberCounter++;

    Order newOrder = Order(
      orderNumber: orderNumber,
      products: orderProducts,
      total: totalPrice.toDouble(),
      timestamp: DateTime.now(),
      customerName: '',
      cashierName: cashierName,
    );

    String orderJson = jsonEncode(newOrder.toJson());
    
    if (isConnected) {
      // If internet is available, upload directly instead of saving locally
      try {
        bool uploadSuccess = await _uploadOrderToServer(orderJson, newOrder);
        
        if (uploadSuccess) {
          showToast('Order uploaded successfully!');
          // Don't save locally - the order is already on the server
        } else {
          // If upload fails, fall back to local storage
          showToast('Upload failed. Saving order locally...');
          _saveOrderLocally(prefs, orderJson);
        }
      } catch (uploadError) {
        print('Upload failed: $uploadError');
        showToast('Upload error. Saving order locally...');
        _saveOrderLocally(prefs, orderJson);
      }
    } else {
      // No internet - save locally to SharedPreferences
      showToast('No internet connection. Order saved locally.');
      _saveOrderLocally(prefs, orderJson);
    }

    // Reset the cart
    setState(() {
      itemQuantities.clear();
      totalPrice = 0.0;
      _isProcessingOrder = false;
    });
    
    // Navigate to printer page
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => PrinterPage()),
        (route) => false,
      );
    }

  } catch (e) {
    showToast('Failed to finalize order: $e');
    print('Failed to finalize order: $e');
    setState(() {
      _isProcessingOrder = false;
    });
  }
}

// Helper method to save order locally
void _saveOrderLocally(SharedPreferences prefs, String orderJson) {
  List<String> orders = prefs.getStringList('orders') ?? [];
  orders.add(orderJson);
  prefs.setStringList('orders', orders);
}

// Helper method to upload order to server
Future<bool> _uploadOrderToServer(String orderJson, Order order) async {
  // This should match your server endpoint from the ViewHistoryPage
  const String uploadUrl = "https://blueichor.org/uploadOffline1.php";
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? shopId = prefs.getString('username');
  
  if (shopId == null) {
    showToast('Shop ID not found. Please check your settings.');
    return false;
  }
  
  try {
    var response = await http.post(
      Uri.parse(uploadUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'username': shopId,
        'orders': [order.toJson()], // Send single order
      }),
    );
    
    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      return jsonResponse['success'] == true;
    } else {
      print('Server responded with status: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print("Upload error: $e");
    return false;
  }
}

// ==========================================================================

  Future<String?> _getActiveCashierName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentCashier');
  }

  void _saveOrderAsDraft() async {
    if (_isProcessingOrder) return;
    
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Get customer name
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

      // Proceed only if customer name is provided
      if (customerName.isNotEmpty) {
        // Generate a unique order number
        String orderNumber =
            'ORD-${DateTime.now().millisecondsSinceEpoch}';
        orderNumberCounter++;

        // Create the Order object
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
          cashierName: '', // Add customer name
        );

        // Save the order
        String orderJson = jsonEncode(newOrder.toJson());
        List<String> orders = prefs.getStringList('draftOrders') ?? [];
        orders.add(orderJson);
        await prefs.setStringList('draftOrders', orders);

        // Notify user and reset state
        showToast('Order saved as draft');
        setState(() {
          itemQuantities.clear();
          totalPrice = 0.0;
        });
        // Navigator.of(context).pop(); // Close the dialog
      } else {
        showToast('Customer name is required');
      }
    } catch (e) {
      showToast('Failed to save order: $e');
      print('Failed to save order: $e');
    }
  }

  void _prepareForNewSale() {
    // Reset necessary fields and states
    itemQuantities.clear();
    totalPrice = 0.0;
    fullname = '';
    searchText = '';
    appliedDiscount = null;
    // Additional reset logic if required
    setState(() {});
  }

// Ensure to define the showToast method if not already defined
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
    // Flags to prevent infinite loop during programmatic updates
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
                  decoration: InputDecoration(labelText: "Amount ($currencySymbol)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    if (isUpdatingAmount) return; // Prevent feedback loop
                    double amount = double.tryParse(value) ?? 0;
                    isUpdatingKgs = true;
                    if (itemPrice > 0) {
                      // Prevent division by zero
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
                    if (isUpdatingKgs) return; // Prevent feedback loop
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

                // Check if either field is empty and calculate if necessary (as fallback)
                if (kgs == 0 && amount > 0 && itemPrice > 0) {
                  kgs = amount / itemPrice;
                } else if (amount == 0 && kgs > 0) {
                  amount = kgs * itemPrice;
                }

                setState(() {
                  double existingQuantity = itemQuantities[itemName] ?? 0;
                  itemQuantities[itemName] =
                      kgs; // Set quantity to kgs as double
                  totalPrice +=
                      amount; // Use the amount directly as it's the latest calculated value
                });

                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }


}
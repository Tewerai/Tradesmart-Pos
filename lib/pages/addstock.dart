import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class AddStockPage extends StatefulWidget {
  @override
  _AddStockPageState createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController stockPriceController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController newCategoryController = TextEditingController();

  String barcodeResult = '';
  String imgPath = '';
  String selectedCategory = 'Electronics'; // Default category
  String selectedMeasure = 'Units'; // Default measure
  bool isSaving = false;
  bool isFormValid = false;
  bool trackStock = true; // Track stock checkbox state set to true by default
  bool isOtherCategory = false;
  List<String> categories = [
    'Electronics',
    'Drinks',
    'Grocery',
    'Toiletries',
    'Other Category'
  ];
  String shopId = '';
  String password = '';

  int _passwordAttempts = 0; // Track the number of password attempts

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _getShopId();
    nameController.addListener(_validateForm);
    priceController.addListener(_validateForm);
    stockPriceController.addListener(_validateForm);
    quantityController.addListener(_validateForm);
    newCategoryController.addListener(_validateForm);
    _checkPasswordRequirement(); // Check password requirement on page load
  }

  Future<void> _checkPasswordRequirement() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool requirePassword = prefs.getBool('addPasswordForStock') ?? false;
    if (requirePassword) {
      _showPasswordDialog();
    }
  }

  Future<void> _showPasswordDialog() async {
    TextEditingController passwordController = TextEditingController();
    int passwordAttempts = 0;
    bool passworGot = true;

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
                          passworGot = false;
                          passwordAttempts++;
                        });
                        if (passwordAttempts >= 3) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    if (!passwordMatched && passwordAttempts >= 3) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadCategories() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      List<String>? savedCategories = prefs.getStringList('_categories');
      if (savedCategories != null && savedCategories.isNotEmpty) {
        categories = savedCategories + ['Other Category'];
      }
    });
  }

  Future<void> _getShopId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      shopId = prefs.getString('username') ?? '';
      password = prefs.getString('password') ?? '';
    });
  }

  void _validateForm() {
    setState(() {
      isFormValid = nameController.text.isNotEmpty &&
          priceController.text.isNotEmpty &&
          stockPriceController.text.isNotEmpty &&
          quantityController.text.isNotEmpty &&
          (!isOtherCategory || newCategoryController.text.isNotEmpty);
    });
  }

  Future<void> _scanBarcode() async {
    try {
      String result = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666', // background color
        'Cancel', // cancel button text
        true, // show flash icon
        ScanMode.BARCODE, // scan mode
      );

      if (result != -1) {
         setState(() {
        barcodeResult = result;
        _validateForm();
      });
      } 

     /* setState(() {
        barcodeResult = result != '-1' ? result : '';
        _validateForm();
      });*/
    } catch (e) {
      print('Error scanning barcode: $e');
    }
  }

  Future<void> _saveProduct() async {
    setState(() {
      isSaving = true;
    });

    // Retrieve values from the form
    String name = nameController.text.trim();
    double price = double.tryParse(priceController.text.trim()) ?? 0.0;
    double stockPrice =
        double.tryParse(stockPriceController.text.trim()) ?? 0.0;
    int quantity =
        trackStock ? int.tryParse(quantityController.text.trim()) ?? 0 : -1;

    // Determine the selected category
    String category =
        isOtherCategory ? newCategoryController.text.trim() : selectedCategory;

    // Convert selectedMeasure to lowercase
    String measureLowerCase = selectedMeasure.toLowerCase();

    // Prepare data to send to the API
    Map<String, dynamic> requestData = {
      'shopId': shopId, // Assuming shopId is the username
      'name': name,
      'price': price,
      'stockPrice': stockPrice,
      'quantity': quantity,
      'category': category,
      'measuredIn': measureLowerCase,
      'barcode': barcodeResult.isNotEmpty
          ? barcodeResult
          : 'product_${Random().nextInt(100000)}',
      'trackStock': trackStock,
    };

    try {
      // Create an IOClient with custom HttpOverrides
      var client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      var ioClient = IOClient(client);

      // Send the product data to the API
      var response = await ioClient.post(
        Uri.parse(
            'https://aphel.blueichor.org/apis/saveProduct.php'), // Replace with your API URL
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success']) {
          // Product saved successfully
          // Fetch product details after saving
            await _saveImageWithProductName(name); // Save the image with product name

          var loginResponse = await ioClient.post(
            Uri.parse(
                'https://aphel.blueichor.org/log2.php'), // Replace with your login API URL
            body: {
              'username': shopId,
              'password': password,
            }, // Assuming shopId is the username
          );

          if (loginResponse.statusCode == 200) {
            var jsondata = json.decode(loginResponse.body);
            if (jsondata["success"]) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                  'categories', json.encode(jsondata['categories']));

              String productsJson = jsonEncode(jsondata["products"]);
              String pricesJson = jsonEncode(jsondata["prices"]);
              String codesJson = jsonEncode(jsondata["codes"]);
              String measureJson = jsonEncode(jsondata["measure"]);
              prefs.setString('quantities', jsonEncode(jsondata["quantities"]));

              prefs.setString('products', productsJson);
              print(productsJson);
              prefs.setString('prices', pricesJson);
              prefs.setString('codes', codesJson);
              prefs.setString('measure', measureJson);
            }
          }

          // If a new category was added, include it in the categories list and save to SharedPreferences
          if (isOtherCategory && !categories.contains(category)) {
            setState(() {
              categories.insert(categories.length - 1,
                  category); // Insert before 'Other Category'
            });
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setStringList('_categories',
                categories.where((c) => c != 'Other Category').toList());
          }

          // Clear the form and show a success message
          nameController.clear();
          priceController.clear();
          stockPriceController.clear();
          quantityController.clear();
          newCategoryController.clear();
          setState(() {
            barcodeResult = '';
            selectedCategory = 'Electronics';
            selectedMeasure = 'Units';
            trackStock = true;
            isFormValid = false;
            isOtherCategory = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Show an error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(jsonResponse['message'] ?? 'Failed to save product'),
            ),
          );
        }
      } else {
        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to save product: HTTP ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      // Handle exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      setState(() {
        isSaving = false; // Stop the loader
      });
    }
  }

Future<void> _addPicture() async {
  final picker = ImagePicker();
  try {
    // Pick an image from the camera
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imgPath = pickedFile.path; // Store the file path
      });

      // Save the image with the product name
      await _saveImageWithProductName(nameController.text.trim());
    } else {
      print('No image selected.');
    }
  } catch (e) {
    print('Error capturing picture: $e');
  }
}

Future<void> _saveImageWithProductName(String productName) async {
  try {
    if (imgPath.isNotEmpty) {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();

      // Create a new path for saving the image
      final newImagePath = '${directory.path}/$productName.jpg';

      // Copy the image file to the new path
      final imageFile = File(imgPath);
      await imageFile.copy(newImagePath);

      print("Image saved at: $newImagePath");
    } else {
      print("No image to save.");
    }
  } catch (e) {
    print("Error saving image: $e");
  }
}

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockPriceController.dispose();
    quantityController.dispose();
    newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Stock'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Product Name'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Price'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: stockPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Stock Price'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity'),
              ),
              SizedBox(height: 16),
              isOtherCategory
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newCategoryController,
                            decoration:
                                InputDecoration(labelText: 'New Category'),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel),
                          onPressed: () {
                            setState(() {
                              isOtherCategory = false;
                              newCategoryController.clear();
                              selectedCategory = 'Electronics';
                            });
                            _validateForm();
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text('Category: '),
                        DropdownButton<String>(
                          value: selectedCategory,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedCategory = newValue!;
                              isOtherCategory = newValue == 'Other Category';
                            });
                            _validateForm();
                          },
                          items: categories
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Measured In: '),
                  DropdownButton<String>(
                    value: selectedMeasure,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedMeasure = newValue!;
                      });
                      _validateForm();
                    },
                    items: <String>[
                      'Units',
                      'Kgs',
                      'Metres',
                      'Centi-Metres',
                      'Pounds'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: trackStock,
                    onChanged: (bool? newValue) {
                      setState(() {
                        trackStock = newValue ?? false;
                      });
                      _validateForm();
                    },
                  ),
                  Text('Track Stock'),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _addPicture, // Function to handle adding a picture
                    icon: Icon(Icons.add_a_photo),
                    label: Text('Add Picture'),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.25),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode, // Scan function
                  ),
                ],
              ),

             /* ElevatedButton(
                onPressed: _scanBarcode,
                child: Text('Scan Barcode'),
              ),*/
              SizedBox(height: 16),
              Text('Barcode: $barcodeResult'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: isFormValid && !isSaving ? _saveProduct : null,
                child: isSaving
                    ? CircularProgressIndicator()
                    : Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(MaterialApp(
    home: AddStockPage(),
  ));
}

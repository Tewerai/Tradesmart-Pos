import 'dart:convert';
import 'home.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SignUpForm extends StatefulWidget {
  @override
  _SignUpFormState createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _ownersNameController = TextEditingController();
  final _ownersSurnameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _passwordController = TextEditingController();
  final _countryController = TextEditingController();
  bool loading = false;

  Country? _selectedCountry;

  Future<void> createUser() async {
    final prefs = await SharedPreferences.getInstance();

    final url = 'https://aphel.blueichor.org/apis/createAccount.php';
    final response = await http.post(Uri.parse(url), body: {
      'ownersName': _ownersNameController.text,
      'ownersSurname': _ownersSurnameController.text,
      'shopName': _shopNameController.text,
      'email': _emailController.text,
      'tel': _telController.text,
      'country': _countryController.text,
      'password': _passwordController.text,
    });

    if (response.statusCode == 200) {
      setState(() {
        loading = false;
      });

      // Parse the response body
      Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        var url = Uri.parse('https://aphel.blueichor.org/log2.php');
        var response = await http.post(url, body: {
          'username': _emailController.text,
          'password': _passwordController.text,
        });
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          if (data['success']) {
            final SharedPreferences prefs = await SharedPreferences.getInstance();

            prefs.setString('fullname', data['fullname']);
            prefs.setString('shopName', data['fullname']);
            prefs.setString('address', data['shopaddress'] ?? '');
            prefs.setString('tel', data['tel'] ?? '');
            prefs.setString('username', _emailController.text);
            prefs.setString('password', _passwordController.text);
            prefs.setString('products', json.encode(data['products']));
            prefs.setString('prices', json.encode(data['prices']));
            prefs.setString('measure', json.encode(data['measure']));
            prefs.setString('codes', json.encode(data['codes']));
            prefs.setString('quantities', json.encode(data['quantities']));
            prefs.setString('categories', json.encode(data['categories']));
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else {
            _showDialog(context, data['message']);
          }
        }
      } else {
        _showDialog(context, data['message']);
      }
    } else {
      setState(() {
        loading = false;
      });
      _showDialog(context, 'Error creating account: ${response.body}');
    }
  }

  void _showDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Login Failed'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        title: Text('Sign Up'),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 64, 185, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _ownersNameController,
                decoration: InputDecoration(
                  labelText: 'Owner\'s Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter owner\'s name';
                  } else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _ownersSurnameController,
                decoration: InputDecoration(
                  labelText: 'Owner\'s Surname',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter owner\'s surname';
                  } else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _shopNameController,
                decoration: InputDecoration(
                  labelText: 'Shop Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_cart),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter shop name';
                  } else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter email';
                  } else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    onSelect: (Country country) {
                      setState(() {
                        _selectedCountry = country;
                        _countryController.text = country.name;
                      });
                    },
                  );
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Please select country';
                      } else {
                        return null;
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _telController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter phone number';
                  } else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter password';
                  } else {
                    return null;
                  }
                },
              ),
              SizedBox(height: 20),
              Stack(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                loading = true;
                              });
                              createUser();
                            }
                          },
                    child: Text('Sign Up'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Color.fromARGB(255, 64, 185, 255),
                      padding: EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (loading)
                    Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: SignUpForm(),
  ));
}

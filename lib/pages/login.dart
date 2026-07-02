// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'home.dart';
import 'sign-up.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    context ??= SecurityContext.defaultContext;

    // Add Let's Encrypt root certificate to the SecurityContext
    try {
      context.setTrustedCertificatesBytes(utf8.encode(_letsEncryptCert));
      print('Certificate added to the security context.');
    } catch (e) {
      print('Error adding certificate to the security context: $e');
    }

    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }

  static const String _letsEncryptCert = """
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----""";
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(LoginPag());
}

Future<void> login(String username, String password, BuildContext context) async {
  var url = Uri.parse('https://blueichor.org/log2.php'); // Replace with your server URL
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Logging in...')),
        ],
      ),
      duration: Duration(seconds: 7),
    ),
  );

  try {
    var response = await http.post(url, body: {
      'username': username,
      'password': password,
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide the loader

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      if (data['success']) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        prefs.setString('fullname', data['fullname']);
        prefs.setString('shopName', data['shopName']);
        prefs.setString('address', data['shopaddress'] ?? '');
        prefs.setString('tel', data['tel'] ?? '');
        prefs.setString('username', username);
        prefs.setString('password', password);
        prefs.setString('products', json.encode(data['products']));
        prefs.setString('prices', json.encode(data['prices']));
        prefs.setString('measure', json.encode(data['measure']));
        prefs.setString('codes', json.encode(data['codes']));
        prefs.setString('quantities', json.encode(data['quantities']));
        prefs.setString('categories', json.encode(data['categories']));
        print(data['fullname']);
        print(data['categories']);
        print(data['measure']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HomePage()), // Navigate to HomePage on success
        );
      } else {
        // Handle login error
        _showSnackBar(context, data['message']);
      }
    } else {
      // Handle server error
      _showSnackBar(context, 'Server error. Please try again later.');
    }
  } catch (e) {
    // Handle network error
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide the loader
    _showSnackBar(context, 'Error: $e');
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}

class LoginPag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
      theme: ThemeData(
        primarySwatch: Colors.blue, // Set your desired primary color
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color: Colors.grey, // Set text color
            fontSize: 18.0,
          ),
        ),
        fontFamily: 'YourCustomFont', // Replace 'YourCustomFont' with the actual font family name
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TradeSmart',
          style: TextStyle(
            color: Colors.black, // Set text color
          ),
        ),
        centerTitle: true,
        elevation: 0, // Remove app bar elevation
        backgroundColor: Colors.transparent, // Set app bar background color to transparent
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align content at the top
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Enter your login details',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey, // Set text color
                ),
              ),
              SizedBox(height: 20), // Add space below the message

              // Email Field with Icon
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // Password Field with Icon
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              // Submit Button with Icon
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: () {
                    login(_usernameController.text, _passwordController.text, context);
                  },
                  icon: Icon(Icons.login),
                  label: Text('Login'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.green, // Set text color
                    minimumSize: Size(double.infinity, 50), // Set button width to the maximum
                    elevation: 5, // Add elevation (shadow)
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Set button border radius
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Create Account Button with Icon
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpForm()), // Navigate to HomePage on success
                  );
                },
                icon: Icon(Icons.person_add),
                label: Text('Create Account'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.blue, // Set text color
                  minimumSize: Size(double.infinity, 50), // Set button width to the maximum
                  elevation: 5, // Add elevation (shadow)
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // Set button border radius
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

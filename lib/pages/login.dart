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
    try {
      context.setTrustedCertificatesBytes(utf8.encode(_letsEncryptCert));
    } catch (e) {
      print('Error adding certificate: $e');
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
  var url = Uri.parse('https://blueichor.org/log2.php');

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

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

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

        int zimraEnabled = data['zimra_enabled'] ?? 0;
        prefs.setInt('zimra_enabled', zimraEnabled);
        prefs.setBool('zimraEnabled', zimraEnabled == 1);

        if (data['zimra_status'] != null) {
          prefs.setString('zimra_status', data['zimra_status']);
        }
        if (data['zimra_device_id'] != null) {
          prefs.setInt('zimra_device_id', data['zimra_device_id']);
        }
        if (data['zimra_fiscal_day_status'] != null) {
          prefs.setString('zimra_fiscal_day_status', data['zimra_fiscal_day_status']);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        _showSnackBar(context, data['message'] ?? 'Invalid credentials.');
      }
    } else {
      _showSnackBar(context, 'Server error. Please try again later.');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'YourCustomFont',
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Prevent double-submit while a request is in flight
  bool _isSubmitting = false;

  // We only need a fade animation for the image now
  late AnimationController _imageFadeController;
  late Animation<double> _imageFadeAnimation;

  // Define the exact blue color from the image
  final Color _brandBlue = const Color(0xFF1148C8);

  @override
  void initState() {
    super.initState();

    // Setup fade animation for the picture
    _imageFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _imageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _imageFadeController,
        curve: Curves.easeIn,
      ),
    );

    _imageFadeController.forward();
  }

  @override
  void dispose() {
    _imageFadeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // 1) Run form validation — blocks empty / short inputs
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2) Block double-submits
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await login(
        _usernameController.text.trim(),
        _passwordController.text,
        context,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // --- Fading Picture Section ---
                  FadeTransition(
                    opacity: _imageFadeAnimation,
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Image.network(
                        'https://img.freepik.com/free-vector/two-business-partners-working-office_74855-6620.jpg?w=740&t=st=1715000000~exp=1715003600~hmac=abcdef',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.business_center,
                              size: 150, color: _brandBlue.withOpacity(0.5));
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Sign In using Email and Password',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Username Field ---
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                        color: _brandBlue, fontWeight: FontWeight.w600),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Please enter your username';
                      if (v.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person, color: _brandBlue),
                      hintText: 'Username',
                      hintStyle: TextStyle(
                          color: _brandBlue.withOpacity(0.7),
                          fontWeight: FontWeight.w600),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: _brandBlue, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: _brandBlue, width: 2.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 2.0),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    style: TextStyle(
                        color: _brandBlue, fontWeight: FontWeight.w600),
                    validator: (value) {
                      final v = value ?? '';
                      if (v.isEmpty) return 'Please enter your password';
                      if (v.length < 2) {
                        return 'Password must be at least 2 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock, color: _brandBlue),
                      hintText: 'Password',
                      hintStyle: TextStyle(
                          color: _brandBlue.withOpacity(0.7),
                          fontWeight: FontWeight.w600),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: _brandBlue, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: _brandBlue, width: 2.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.red, width: 2.0),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- Login Now Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleLogin,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login, color: Color(0xFF5E35B1)),
                      label: Text(
                        _isSubmitting ? 'LOGGING IN…' : 'LOGIN NOW',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E35B1),
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3E5F5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // --- Create Account Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignUpForm(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.person_add,
                          color: Color(0xFF5E35B1)),
                      label: const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- Footer Text ---
                  GestureDetector(
                    onTap: () => _showForgotPasswordDialog(context),
                    child: const Text(
                      'Forgot Password? Troubleshoot',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Reset Password',
            style: TextStyle(
              color: _brandBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email, size: 60, color: Colors.blue[300]),
              const SizedBox(height: 16),
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset link sent to your email!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );
  }
}
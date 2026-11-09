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

class _SignUpFormState extends State<SignUpForm> with SingleTickerProviderStateMixin {
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
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    // Slide animation (from bottom)
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    // Scale animation for fields
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    
    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ownersNameController.dispose();
    _ownersSurnameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    super.dispose();
  }

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
            
            // Show success animation before navigating
            _showSuccessDialog(context);
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

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
              SizedBox(height: 10),
              Text('Account Created!'),
            ],
          ),
          content: Text('Your account has been created successfully.'),
          actions: <Widget>[
            TextButton(
              child: Text('Continue'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Sign Up Failed'),
            ],
          ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E),
              Color(0xFF0D47A1),
              Color(0xFF01579B),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header with Animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_add,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Join TradeSmart today',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  // Form Container with Animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: <Widget>[
                              // Owner's Name
                              _buildAnimatedTextField(
                                controller: _ownersNameController,
                                label: "Owner's Name",
                                icon: Icons.person,
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Please enter owner\'s name';
                                  }
                                  return null;
                                },
                                delay: 0.2,
                              ),
                              SizedBox(height: 16),
                              
                              // Owner's Surname
                              _buildAnimatedTextField(
                                controller: _ownersSurnameController,
                                label: "Owner's Surname",
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Please enter owner\'s surname';
                                  }
                                  return null;
                                },
                                delay: 0.3,
                              ),
                              SizedBox(height: 16),
                              
                              // Shop Name
                              _buildAnimatedTextField(
                                controller: _shopNameController,
                                label: "Shop Name",
                                icon: Icons.shopping_cart,
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Please enter shop name';
                                  }
                                  return null;
                                },
                                delay: 0.4,
                              ),
                              SizedBox(height: 16),
                              
                              // Email
                              _buildAnimatedTextField(
                                controller: _emailController,
                                label: "Email",
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Please enter email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                                delay: 0.5,
                              ),
                              SizedBox(height: 16),
                              
                              // Country Picker with Animation
                              _buildAnimatedCountryPicker(
                                delay: 0.6,
                              ),
                              SizedBox(height: 16),
                              
                              // Phone Number
                              _buildAnimatedTextField(
                                controller: _telController,
                                label: "Phone Number",
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Please enter phone number';
                                  }
                                  return null;
                                },
                                delay: 0.7,
                              ),
                              SizedBox(height: 16),
                              
                              // Password
                              _buildAnimatedTextField(
                                controller: _passwordController,
                                label: "Password",
                                icon: Icons.lock,
                                obscureText: true,
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'Please enter password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                                delay: 0.8,
                              ),
                              SizedBox(height: 24),
                              
                              // Sign Up Button with Animation
                              _buildAnimatedButton(
                                delay: 0.9,
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Already have account?
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account?',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Login',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D47A1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required double delay,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: TweenAnimationBuilder(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: Color(0xFF0D47A1),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF0D47A1), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCountryPicker({required double delay}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: TweenAnimationBuilder(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () {
              showCountryPicker(
                context: context,
                showPhoneCode: true,
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF0D47A1), width: 2),
                  ),
                  prefixIcon: Icon(
                    Icons.location_on,
                    color: Color(0xFF0D47A1),
                  ),
                  suffixIcon: Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF0D47A1),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: _selectedCountry != null 
                      ? '${_selectedCountry!.flagEmoji} ${_selectedCountry!.name} (+${_selectedCountry!.phoneCode})'
                      : 'Select your country',
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please select country';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({required double delay}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: TweenAnimationBuilder(
          duration: Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Container(
            width: double.infinity,
            height: 56,
            child: Stack(
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
                  child: loading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add),
                            SizedBox(width: 8),
                            Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56),
                    elevation: 8,
                    shadowColor: Color(0xFF0D47A1).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),//LitandEpic27
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: SignUpForm(),
    theme: ThemeData(
      fontFamily: 'Roboto',
    ),
  ));
}
import 'pages/home.dart';
import 'pages/login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
 import 'dart:io';


void main() {
   HttpOverrides.global = MyHttpOverrides();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CheckLogin(),
    );
  }
}

class CheckLogin extends StatefulWidget {
  @override
  _CheckLoginState createState() => _CheckLoginState();
}

class _CheckLoginState extends State<CheckLogin> {
  @override
  void initState() {
    super.initState();
    _checkForUsername();
  }

  Future<void> _checkForUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');

    if (username == null) {
      // If username is not found, navigate to Login Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPag()),
      );
    } else {
      // If username exists, navigate to your main page or dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()), // Replace with your main page
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show loading indicator while checking
      ),
    );
  }
}



class MainPage extends StatelessWidget {
  // Build your main page here
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page'),
      ),
      body: Center(
        child: Text('Main Page Content'), // Placeholder for main page content
      ),
    );
  }
}

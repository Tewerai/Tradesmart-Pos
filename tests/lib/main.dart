import 'package:flutter/material.dart';
import 'screen_0.dart';
import 'screen_1.dart';
import 'screen_2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web to App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: 'Screen0',
      routes: {
        'Screen0': (context) => Screen0(),
'Screen1': (context) => Screen1(),
'Screen2': (context) => Screen2()
      },
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Navigation', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(title: Text('Screen0'), onTap: () => Navigator.pushNamed(context, 'Screen0')),
ListTile(title: Text('Screen1'), onTap: () => Navigator.pushNamed(context, 'Screen1')),
ListTile(title: Text('Screen2'), onTap: () => Navigator.pushNamed(context, 'Screen2'))
        ],
      ),
    );
  }
}

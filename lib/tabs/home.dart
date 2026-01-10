import 'package:flutter/material.dart';
import 'package:meow_lang/tabs/analytics.dart';
import 'package:meow_lang/tabs/history.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'appbar.dart';
import 'translate.dart';
import 'meows.dart';
import 'profile.dart';
import 'theme.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    return Scaffold(
      extendBody: true,
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.primaryColor,
              ),
              child: const Text(
                'PROTOTYPE BUILD',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 24,
                ),
              ),
            ),
            SizedBox(height: 50),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                fixedSize: const Size(double.infinity, 50),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                _showColorPalette(context);
              },
              child: const Row(
               
                children: [
                  Icon(Icons.color_lens),
                  SizedBox(width: 12),
                  Text('Change Theme', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            SizedBox(height:10),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                fixedSize: const Size(double.infinity, 50),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryTab()));
              },  
              child: const Row(
               
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 12),
                  Text('History', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: mbar(),
      bottomNavigationBar: CurvedNavigationBar(
        index: index,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.mic_none, size: 30, color: Colors.white),
          Icon(Icons.pets, size: 30, color: Colors.white),
          Icon(Icons.bar_chart, size: 30, color: Colors.white),
          Icon(Icons.person, size: 30, color: Colors.white),
        ],
        color: primary,
        buttonBackgroundColor: primary,
        backgroundColor: Colors.transparent,
        onTap: (i) {
          setState(() {
            index = i;
          });
        },
      ),
      body: index == 0
          ? TranslateMenu()
          : index == 1
          ? MeowMenu()
          : index == 2
          ? AnalyticsTab()
          : ProfileMenu(),
    );
  }

  void _showColorPalette(BuildContext context) {
    final List<Color> colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
      Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
      Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
      Colors.brown, Colors.blueGrey,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme Color'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: colors.map((color) => GestureDetector(
              onTap: () {
                Provider.of<ThemeProvider>(context, listen: false).setColor(color);
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundColor: color,
                radius: 22,
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

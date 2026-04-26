import 'package:flutter/material.dart';
import 'package:meow_lang/tabs/meows.dart';
import 'package:meow_lang/tabs/cats.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'appbar.dart';
import 'translate.dart';
import 'profile.dart';
import 'history.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    return Scaffold(
      extendBody: true,
      appBar: mbar(
        title: _showHistory ? 'History' : null,
        onHistoryPressed: () => setState(() => _showHistory = true),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: index,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.mic_none, size: 30, color: Colors.white),
          Icon(Icons.music_note, size: 30, color: Colors.white),
          Icon(Icons.pets, size: 30, color: Colors.white),
          Icon(Icons.person, size: 30, color: Colors.white),
        ],
        color: primary,
        buttonBackgroundColor: primary,
        backgroundColor: Colors.transparent,
        onTap: (i) {
          setState(() {
            index = i;
            _showHistory = false;
          });
        },
      ),
      body: _showHistory
          ? const HistoryTab()
          : index == 0
              ? const TranslateMenu()
              : index == 1
                  ? const MeowMenu()
                  : index == 2
                      ? const CatsTab()
                      : const ProfileMenu(),
    );
  }
}

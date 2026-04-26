import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class MeowMenu extends StatefulWidget {
  const MeowMenu({super.key});

  @override
  State<MeowMenu> createState() => _MeowMenuState();
}

class _MeowMenuState extends State<MeowMenu> {
  final player = AudioPlayer();
  int _tappedIndex = -1;

  final List<Map<String, String>> _items = [
    {'label': 'Angry', 'image': 'assets/images/angry.png', 'audio': 'audio/angry.mp3'},
    {'label': 'Hungry', 'image': 'assets/images/hungry.png', 'audio': 'audio/hungry.wav'},
    {'label': 'Mother Call', 'image': 'assets/images/mothercall.png', 'audio': 'audio/mothercall.mp3'},
    {'label': 'Paining', 'image': 'assets/images/pain.png', 'audio': 'audio/pain.mp3'},
    {'label': 'Happy', 'image': 'assets/images/happy.png', 'audio': 'audio/happy.mp3'},
    {'label': 'Resting', 'image': 'assets/images/resting.png', 'audio': 'audio/resting.mp3'},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
      
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isTapped = _tappedIndex == index;
        return InkWell(
          onTap: () {
            player.play(AssetSource(item['audio']!));
            setState(() => _tappedIndex = index);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _tappedIndex == index) {
                setState(() => _tappedIndex = -1);
              }
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: 0.0, end: isTapped ? 1.0 : 0.0),
            builder: (context, value, child) {
              final elevation = 6 + (value * 6); // Animate from 6 to 12
              final scale = 1.04 + (value * 0.05); // Animate from 1.0 to 1.05
              return Transform.scale(
                scale: scale,
                child: Card(
                  elevation: elevation,
                  shadowColor: const Color.fromARGB(96, 77, 12, 12),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(item['image']!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  color: Theme.of(context).primaryColor,
                  child: Text(
                    item['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 6.0,
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                ],
              ),
          ),
        );
  });
      }
    
  }

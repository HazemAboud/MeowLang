import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class MeowMenu extends StatefulWidget {
  const MeowMenu({super.key});

  @override
  State<MeowMenu> createState() => _MeowMenuState();
}

class _MeowMenuState extends State<MeowMenu> {
  final player = AudioPlayer();

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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          elevation: 4,
          shadowColor: Colors.black26,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: InkWell(
            onTap: () => player.play(AssetSource(item['audio']!)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Image.asset(
                      item['image']!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  color: Theme.of(context).primaryColor,
                  child: Text(
                    item['label']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

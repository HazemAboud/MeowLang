import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';

class mbar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  final VoidCallback? onHistoryPressed;
  final String? title;

  const mbar({
    super.key,
    this.height = kToolbarHeight,
    this.onHistoryPressed,
    this.title,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = Theme.of(context).primaryColor;
    final titleStyle = theme.appBarTheme.titleTextStyle;

    return AppBar(
      title: Text(title ?? 'MeowLang', style: titleStyle),
      centerTitle: false,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(9),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Image.asset('assets/images/settings.png'),
          onSelected: (value) {
            if (value == 'theme') {
              _showColorPalette(context);
            } else if (value == 'history' && onHistoryPressed != null) {
              onHistoryPressed!();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'theme',
              child: Row(
                children: [
                  Icon(Icons.color_lens),
                  SizedBox(width: 12),
                  Text('Change Theme'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'history',
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 12),
                  Text('History'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showColorPalette(BuildContext context) {
    final List<Color> colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
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
            children: colors
                .map((color) => GestureDetector(
                      onTap: () {
                        Provider.of<ThemeProvider>(context, listen: false)
                            .setColor(color);
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        backgroundColor: color,
                        radius: 22,
                      ),
                    ))
                .toList(),
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
import 'package:flutter/material.dart';

class mbar extends StatelessWidget implements PreferredSizeWidget {
  final double height;

  const mbar({
    super.key,
    this.height = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.appBarTheme.backgroundColor;
    final titleStyle = theme.appBarTheme.titleTextStyle;

    return AppBar(
      title: Text('MeowLang', style: titleStyle),
      centerTitle: false,
      backgroundColor: bg,
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            icon: Image.asset('assets/images/settings.png'),
            onPressed: () {
              Scaffold.of(ctx).openEndDrawer();
            },
            tooltip: 'Settings',
          ),
        ),
      ],
    );
  }
}
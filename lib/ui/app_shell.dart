import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.leading,
    this.backgroundColor,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: backgroundColor ?? t.colors.bg,
      appBar: AppBar(
        title: Text(title),
        leading: leading,
        actions: actions,
      ),
      body: body,
    );
  }
}

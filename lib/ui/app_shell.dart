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
    this.subtitle,
    this.contentPadding,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final Color? backgroundColor;
  final String? subtitle;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: backgroundColor ?? t.colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing.xl,
                t.spacing.lg,
                t.spacing.xl,
                t.spacing.md,
              ),
              child: AppTopBar(
                title: title,
                subtitle: subtitle,
                leading: leading,
                actions: actions,
              ),
            ),
            Expanded(
              child: Padding(
                padding: contentPadding ??
                    EdgeInsets.fromLTRB(
                      t.spacing.xl,
                      0,
                      t.spacing.xl,
                      t.spacing.xl,
                    ),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.lg,
        vertical: t.spacing.md,
      ),
      decoration: BoxDecoration(
        color: t.colors.surface,
        borderRadius: BorderRadius.circular(t.radii.lg),
        border: Border.all(color: t.colors.border, width: 1),
        boxShadow: t.shadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: t.spacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: t.spacing.xs),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.text.bodySmall?.copyWith(
                          color: t.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: t.spacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: t.spacing.sm,
                runSpacing: t.spacing.sm,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

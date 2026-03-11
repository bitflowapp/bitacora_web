import 'package:flutter/material.dart';

class EditorOverflowMenuShell extends StatelessWidget {
  const EditorOverflowMenuShell({
    super.key,
    required this.child,
    required this.onClose,
    this.title = 'Opciones',
    this.maxHeightFactor = 0.75,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;

    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('editor-more-close-x'),
                      tooltip: 'Cerrar',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('editor-more-scroll'),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

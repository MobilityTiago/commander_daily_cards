import 'package:flutter/material.dart';

class CommanderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onRefreshPressed;
  final bool showFilterButton;
  final bool showRefreshButton;

  const CommanderAppBar({
    super.key,
    required this.title,
    this.onFilterPressed,
    this.onRefreshPressed,
    this.showFilterButton = false,
    this.showRefreshButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        if (showRefreshButton)
          IconButton(
            onPressed: onRefreshPressed,
            icon: const Icon(Icons.refresh),
          ),
        if (showFilterButton)
          IconButton(
            onPressed: onFilterPressed,
            icon: const Icon(Icons.filter_alt),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
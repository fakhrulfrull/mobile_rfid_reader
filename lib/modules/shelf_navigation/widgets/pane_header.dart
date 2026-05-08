import 'package:flutter/material.dart';

enum PaneViewState { normal, minimized, fullscreen }

class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    required this.title,
    required this.isLeftPane,
    required this.paneState,
    required this.onToggleMinimize,
    required this.onExtend,
    required this.onToggleFullscreen,
  });

  final String title;
  final bool isLeftPane;
  final PaneViewState paneState;
  final VoidCallback onToggleMinimize;
  final VoidCallback onExtend;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final isFullscreen = paneState == PaneViewState.fullscreen;
    final isMinimized = paneState == PaneViewState.minimized;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.black.withOpacity(0.06),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: isMinimized ? 'Restore panel' : 'Minimize panel',
            icon: Icon(isMinimized ? Icons.unfold_more : Icons.minimize),
            onPressed: onToggleMinimize,
          ),
          IconButton(
            tooltip: isLeftPane ? 'Extend left pane' : 'Extend right pane',
            icon: Icon(isLeftPane
                ? Icons.keyboard_arrow_left
                : Icons.keyboard_arrow_right),
            onPressed: onExtend,
          ),
          IconButton(
            tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen panel',
            icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: onToggleFullscreen,
          ),
        ],
      ),
    );
  }
}

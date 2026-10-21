import 'package:flutter/material.dart';
import 'app_icons.dart';

enum AppTab {
  discover,
  library,
  liked,
}

class MusicBottomNavBar extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;
  final Color? smartBgColor;

  const MusicBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.smartBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      color: Colors.transparent,
      child: Row(
        children: [
          _buildNavItem(
            tab: AppTab.discover,
            label: 'Keşfet',
            iconBuilder: (color) => AppIcons.navDiscover(color: color),
          ),
          _buildNavItem(
            tab: AppTab.library,
            label: 'Kütüphane',
            iconBuilder: (color) => AppIcons.navLibrary(color: color),
          ),
          _buildNavItem(
            tab: AppTab.liked,
            label: 'Beğenilen',
            iconBuilder: (color) => AppIcons.navLiked(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required AppTab tab,
    required String label,
    required Widget Function(Color color) iconBuilder,
  }) {
    final isSelected = currentTab == tab;
    // Active is pure crisp white; inactive is dimmed white
    final activeColor = const Color(0xFFF4F4F6);
    final inactiveColor = const Color(0x80F4F4F6);
    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabSelected(tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 28,
              child: Center(
                child: iconBuilder(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

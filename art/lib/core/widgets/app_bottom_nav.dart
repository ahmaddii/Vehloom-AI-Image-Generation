import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import 'custom_add_button.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.creamLight,
        border: Border(
          top: BorderSide(color: AppColors.lightGrey, width: 1),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(
              context,
              icon: currentIndex == 0 ? Icons.home : Icons.home_outlined,
              label: 'Home',
              index: 0,
              route: '/',
            ),
            _buildNavItem(
              context,
              icon: currentIndex == 1 ? Icons.search : Icons.search_outlined,
              label: 'Discovery',
              index: 1,
              route: '/search',
            ),
            
            // Upload Button
            GestureDetector(
              onTap: () => context.push('/upload'),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: CustomAddButton(),
              ),
            ),
            
            _buildNavItem(
              context,
              icon: currentIndex == 3 ? Icons.emoji_events : Icons.emoji_events_outlined,
              label: 'Top',
              index: 3,
              route: '/top-art',
            ),
            _buildNavItem(
              context,
              icon: currentIndex == 4 ? Icons.person : Icons.person_outline,
              label: 'Profile',
              index: 4,
              route: '/profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required String label, required int index, required String route}) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          context.go(route);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.coral : AppColors.black,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? AppColors.coral : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

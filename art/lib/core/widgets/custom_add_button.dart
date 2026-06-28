import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomAddButton extends StatelessWidget {
  const CustomAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Force rebuild on theme change
    return SizedBox(
      width: 52,
      height: 34,
      child: Stack(
        children: [
          // Left edge (Light Pinkish)
          Positioned(
            left: 0,
            width: 44,
            bottom: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.coralLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Right edge (Darker Pinkish/Coral)
          Positioned(
            right: 0,
            width: 44,
            bottom: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Center black box
          Positioned(
            left: 4,
            right: 4,
            bottom: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add,
                color: AppColors.creamLight,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

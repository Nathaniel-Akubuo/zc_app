import 'package:flutter/material.dart';
import 'package:hng/ui/shared/colors.dart';

class OnlineIndicator extends StatelessWidget {
  const OnlineIndicator(int i, {Key? key}):super(key: key);
  @override
  Widget build(BuildContext context) {
    return const  Icon(
      Icons.circle,
      color: AppColors.zuriPrimaryColor,
      size: 10,
    );
  }
}



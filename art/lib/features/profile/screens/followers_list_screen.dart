import 'package:flutter/material.dart';

class FollowersListScreen extends StatelessWidget {
  final String userId;

  const FollowersListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Followers List for User: $userId')),
    );
  }
}

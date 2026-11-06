import 'package:flutter/material.dart';

class EarnBYCScreen extends StatelessWidget {
  const EarnBYCScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earn BYC'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 64, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Earn More BYC',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Various earning opportunities will be implemented',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
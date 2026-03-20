import 'package:flutter/material.dart';

class FarmerDetailScreen extends StatelessWidget {
  final String farmerId;
  const FarmerDetailScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Detail')),
      body: const Center(
        child: Text('No data found'),
      ),
    );
  }
}

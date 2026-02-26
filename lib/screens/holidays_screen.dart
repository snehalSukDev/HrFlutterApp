import 'package:flutter/material.dart';

class HolidaysScreen extends StatelessWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holidays'),
      ),
      body: const Center(
        child: Text('Holiday list will appear here'),
      ),
    );
  }
}

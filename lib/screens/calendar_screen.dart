import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text('This is the Calendar Screen', style: TextStyle(fontFamily: 'Princess Sofia'))
      ),
    );
  }
}
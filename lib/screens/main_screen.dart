import 'package:flutter/material.dart';
import 'package:journeyjournal/models/route.dart';
import 'package:journeyjournal/screens/map_screen.dart';
import 'package:journeyjournal/screens/route_screen.dart';
import 'package:journeyjournal/screens/calendar_screen.dart';
import 'package:journeyjournal/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  final RouteModel? initialRoute;
  const MainScreen({super.key, this.initialRoute});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoute != null) {
      print("Widget route: ${widget.initialRoute?.name ?? 'No route'}");
      _selectedIndex = 0; // Make sure MapScreen is selected
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapScreen(initialRoute: widget.initialRoute), // Pass initialRoute here
          const RouteScreen(),
          const CalendarScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensures all icons are visible
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

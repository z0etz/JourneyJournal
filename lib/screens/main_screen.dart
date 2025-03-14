import 'package:flutter/material.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/screens/map_screen.dart';
import 'package:journeyjournal/screens/route_screen.dart';
import 'package:journeyjournal/screens/calendar_screen.dart';
import 'package:journeyjournal/screens/settings_screen.dart';
import 'package:journeyjournal/screens/animation_screen.dart';

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
      body: _buildScreen(),
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
            icon: Icon(Icons.play_arrow),
            label: 'Animate',
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

  Widget _buildScreen() {
    // Retrieve the latest saved route
    return FutureBuilder<List<RouteModel>>(
      future: RouteModel.loadRoutes(),
      builder: (context, snapshot) {
        RouteModel? latestRoute;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          latestRoute = snapshot.data!.last;
        }

        switch (_selectedIndex) {
          case 0:
            return MapScreen(initialRoute: latestRoute);
          case 1:
            return AnimationScreen(initialRoute: latestRoute);
          case 2:
            return const RouteScreen();
          case 3:
            return const CalendarScreen();
          case 4:
            return const SettingsScreen();
          default:
            return MapScreen(initialRoute: latestRoute);
        }
      },
    );
  }
}

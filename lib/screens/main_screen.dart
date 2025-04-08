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
  RouteModel? lastViewedRoute; // Tracks the last viewed route

  @override
  void initState() {
    super.initState();
    if (widget.initialRoute != null) {
      print("MainScreen init with route: ${widget.initialRoute?.name}");
      lastViewedRoute = widget.initialRoute;
      _selectedIndex = 0; // Start on MapScreen
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
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.play_arrow), label: 'Animate'),
          BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    return FutureBuilder<List<RouteModel>>(
      future: RouteModel.loadRoutes(),
      builder: (context, snapshot) {
        RouteModel? displayRoute;

        // 1. Clicked route from RouteScreen
        if (widget.initialRoute != null) {
          displayRoute = widget.initialRoute;
          lastViewedRoute = displayRoute; // Update last viewed
          print("Using clicked route: ${displayRoute?.name}");
        }
        // 2. Last viewed route when switching screens
        else if (lastViewedRoute != null) {
          displayRoute = lastViewedRoute;
          print("Using last viewed route: ${displayRoute?.name}");
        }
        // 3. Last saved route if no last viewed
        else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          displayRoute = snapshot.data!.last;
          lastViewedRoute = displayRoute; // Set as last viewed
          print("Using last saved route: ${displayRoute?.name}");
        }
        // 4. No routes exist (handled by MapScreen/AnimationScreen)
        else {
          displayRoute = null;
          print("No routes exist");
        }

        switch (_selectedIndex) {
          case 0:
            return MapScreen(initialRoute: displayRoute);
          case 1:
            return AnimationScreen(initialRoute: displayRoute);
          case 2:
            return const RouteScreen();
          case 3:
            return const CalendarScreen();
          case 4:
            return const SettingsScreen();
          default:
            return MapScreen(initialRoute: displayRoute);
        }
      },
    );
  }
}
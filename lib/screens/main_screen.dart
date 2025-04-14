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
  RouteModel? lastViewedRoute;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoute != null) {
      lastViewedRoute = widget.initialRoute;
      _selectedIndex = 0;
    }
  }

  void _onItemTapped(int index) {
    if (_isSaving && _selectedIndex == 1) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _updateSavingState(bool isSaving) {
    setState(() {
      _isSaving = isSaving;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),
      bottomNavigationBar: Stack(
        children: [
          BottomNavigationBar(
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
          if (_isSaving)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4.0,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    return FutureBuilder<List<RouteModel>>(
      future: RouteModel.loadRoutes(),
      builder: (context, snapshot) {
        RouteModel? displayRoute;

        if (widget.initialRoute != null) {
          displayRoute = widget.initialRoute;
          lastViewedRoute = displayRoute;
        } else if (lastViewedRoute != null) {
          displayRoute = lastViewedRoute;
        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          displayRoute = snapshot.data!.last;
          lastViewedRoute = displayRoute;
        } else {
          displayRoute = null;
        }

        switch (_selectedIndex) {
          case 0:
            return MapScreen(initialRoute: displayRoute);
          case 1:
            return AnimationScreen(
              initialRoute: displayRoute,
              onSavingChanged: _updateSavingState,
            );
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
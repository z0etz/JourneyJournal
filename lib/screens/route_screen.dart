import 'package:flutter/material.dart';
import 'package:journeyjournal/screens/main_screen.dart';
import 'package:journeyjournal/models/route.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
      ),
      body: ListView.builder(
        itemCount: RouteModel.savedRoutes.length,
        itemBuilder: (context, index) {
          final route = RouteModel.savedRoutes[index];
          return ListTile(
            title: Text(route.name),
            subtitle: Text('Points: ${route.routePoints.length}'),
            onTap: () {
              print(route.name);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => MainScreen(initialRoute: route),
                ),
                    (route) => false, // This removes all previous routes
              );
            },
          );
        },
      ),
    );
  }
}

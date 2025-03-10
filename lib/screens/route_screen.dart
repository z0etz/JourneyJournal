import 'package:flutter/material.dart';
import 'package:journeyjournal/screens/main_screen.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
      ),
      body: FutureBuilder(
        future: RouteModel.getRoutesBox(), // Load the box from Hive
        builder: (context, AsyncSnapshot<Box<RouteModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading routes'));
          }

          final box = snapshot.data!; // Access the box

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<RouteModel> box, _) {
              final savedRoutes = box.values.toList(); // Get updated routes
              return ListView.builder(
                itemCount: savedRoutes.length,
                itemBuilder: (context, index) {
                  final route = savedRoutes[index];
                  return ListTile(
                    title: Text(route.name),
                    subtitle: Text('Points: ${route.routePoints.length}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close), // Delete icon
                      onPressed: () async {
                        // Delete the route from Hive
                        await box.delete(route.id);
                      },
                    ),
                    onTap: () {
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
              );
            },
          );
        },
      ),
    );
  }
}

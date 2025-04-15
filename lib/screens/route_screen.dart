import 'package:flutter/material.dart';
import 'package:journeyjournal/screens/main_screen.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  Future<bool> showDeleteRouteConfirmationDialog(BuildContext context, String routeName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the route "$routeName" and all its associated data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Routes'),
      ),
      body: FutureBuilder(
        future: RouteModel.getRoutesBox(),
        builder: (context, AsyncSnapshot<Box<RouteModel>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading routes'));
          }

          final box = snapshot.data!;

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<RouteModel> box, _) {
              final savedRoutes = box.values.toList();
              return ListView.builder(
                itemCount: savedRoutes.length,
                itemBuilder: (context, index) {
                  final route = savedRoutes[index];
                  return ListTile(
                    title: Text(route.name),
                    subtitle: Text('Points: ${route.routePoints.length}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        bool confirm = await showDeleteRouteConfirmationDialog(context, route.name);
                        if (confirm) {
                          await box.delete(route.id);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainScreen(initialRoute: route),
                        ),
                            (route) => false,
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
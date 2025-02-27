import 'package:flutter/material.dart';
import 'package:journeyjournal/models/route_point.dart';
import 'package:journeyjournal/screens/login_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:journeyjournal/models/route_model.dart';
import 'package:journeyjournal/utils/lat_lang_adapter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(RouteModelAdapter());
  Hive.registerAdapter(RoutePointAdapter());
  Hive.registerAdapter(LatLngAdapter());

  // Clear the box before opening it if changes to Hive storage have been made
  // await Hive.deleteBoxFromDisk('routesBox');

  await Hive.openBox<RouteModel>('routesBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journey Journal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}


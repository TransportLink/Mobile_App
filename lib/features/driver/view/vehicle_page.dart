import 'package:flutter/material.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({ super.key });

  @override
  _VehiclePageState createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("vehicle_page"),
    );
  }
}
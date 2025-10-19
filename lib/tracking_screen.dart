// screens/client/tracking_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;

  const TrackingScreen({super.key, required this.requestId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late Map<String, dynamic> request;
  LatLng? providerLocation;
  String status = 'جاري التحديث...';

  @override
  void initState() {
    _startListening();
    super.initState();
  }

  void _startListening() {
    FirebaseFirestore.instance
        .collection('requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      setState(() {
        request = data;
        status = data['status'];
        if (data['provider_lat'] != null && data['provider_lng'] != null) {
          providerLocation = LatLng(data['provider_lat'], data['provider_lng']);
        }
      });

      if (data['status'] == 'completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إكمال الخدمة")),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تتبع المزود")),
      body: providerLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: providerLocation!,
              zoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: providerLocation!,
                    width: 40,
                    height: 40,
                    builder: (ctx) => const Icon(Icons.directions_car, color: Colors.blue),
                  ),
                  Marker(
                    point: LatLng(request['lat'], request['lng']),
                    width: 40,
                    height: 40,
                    builder: (ctx) => const Icon(Icons.location_pin, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 5)],
              ),
              child: Text(
                "الحالة: $status",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
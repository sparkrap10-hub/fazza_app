// models/request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequest {
  final String id;
  final String userId;
  final String? providerId;
  final String serviceType;
  final double lat;
  final double lng;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? rating;

  ServiceRequest({
    required this.id,
    required this.userId,
    this.providerId,
    required this.serviceType,
    required this.lat,
    required this.lng,
    required this.notes,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.rating,
  });

  factory ServiceRequest.fromMap(String id, Map<String, dynamic> data) {
    return ServiceRequest(
      id: id,
      userId: data['user_id'],
      providerId: data['provider_id'],
      serviceType: data['service_type'],
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      notes: data['notes'] ?? '',
      status: data['status'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
      rating: data['rating'],
    );
  }
}
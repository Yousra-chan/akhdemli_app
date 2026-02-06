import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  String id;
  String clientId;
  String providerId;
  String serviceId;
  String serviceTitle;
  double servicePrice;
  DateTime appointmentDate;
  String status; // pending, accepted, confirmed, completed, cancelled, rejected
  String notes;
  DateTime createdAt;
  DateTime? updatedAt;
  String clientName;
  String providerName;
  String clientPhone;
  String providerPhone;
  String? review;
  double? rating;
  DateTime? reviewedAt;

  BookingModel({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.serviceId,
    required this.serviceTitle,
    required this.servicePrice,
    required this.appointmentDate,
    this.status = 'pending',
    this.notes = '',
    required this.createdAt,
    this.updatedAt,
    required this.clientName,
    required this.providerName,
    required this.clientPhone,
    required this.providerPhone,
    this.review,
    this.rating,
    this.reviewedAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      clientId: map['clientId'] ?? '',
      providerId: map['providerId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceTitle: map['serviceTitle'] ?? '',
      servicePrice: (map['servicePrice'] ?? 0).toDouble(),
      appointmentDate: (map['appointmentDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      notes: map['notes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      clientName: map['clientName'] ?? '',
      providerName: map['providerName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      providerPhone: map['providerPhone'] ?? '',
      review: map['review'],
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'providerId': providerId,
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'servicePrice': servicePrice,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'clientName': clientName,
      'providerName': providerName,
      'clientPhone': clientPhone,
      'providerPhone': providerPhone,
      if (review != null) 'review': review,
      if (rating != null) 'rating': rating,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }

  BookingModel copyWith({
    String? id,
    String? clientId,
    String? providerId,
    String? serviceId,
    String? serviceTitle,
    double? servicePrice,
    DateTime? appointmentDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientName,
    String? providerName,
    String? clientPhone,
    String? providerPhone,
    String? review,
    double? rating,
    DateTime? reviewedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      providerId: providerId ?? this.providerId,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      servicePrice: servicePrice ?? this.servicePrice,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientName: clientName ?? this.clientName,
      providerName: providerName ?? this.providerName,
      clientPhone: clientPhone ?? this.clientPhone,
      providerPhone: providerPhone ?? this.providerPhone,
      review: review ?? this.review,
      rating: rating ?? this.rating,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  String toJson() => json.encode(toMap());
}

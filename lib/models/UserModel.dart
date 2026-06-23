import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String photoUrl;
  final Timestamp createdAt;
  final GeoPoint? location;
  final String address;
  final int totalJobs;
  final double rating;
  final String? fcmToken;
  final List<String> serviceIds;

  // YOUR ACTUAL FIELDS (from Firestore)
  final String? profession;
  final bool subscriptionActive;
  final Timestamp? subscriptionExpiry;
  final Timestamp? subscriptionExpiresAt;
  final bool isAdmin;
  final bool isSuspended;
  final bool isBanned;
  final Timestamp? fcmTokenUpdatedAt;
  final List<String> chatIds;
  final List<String> portfolio;
  final bool profileCompleted;

  // Location fields
  final String? wilaya;
  final String? commune;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.photoUrl,
    required this.createdAt,
    this.location,
    required this.address,
    this.totalJobs = 0,
    this.rating = 0.0,
    this.fcmToken,
    this.serviceIds = const [],

    // YOUR ACTUAL FIELDS
    this.profession,
    this.subscriptionActive = false,
    this.subscriptionExpiry,
    this.subscriptionExpiresAt,
    this.isAdmin = false,
    this.isSuspended = false,
    this.isBanned = false,
    this.fcmTokenUpdatedAt,
    this.chatIds = const [],
    this.portfolio = const [],
    this.profileCompleted = false,

    // Location fields
    this.wilaya,
    this.commune,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'location': location,
      'address': address,
      'totalJobs': totalJobs,
      'rating': rating,
      'fcmToken': fcmToken,
      'serviceIds': serviceIds,

      // YOUR ACTUAL FIELDS
      'profession': profession,
      'subscriptionExpiry': subscriptionExpiry,
      'subscriptionActive': subscriptionActive,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt,
      'subscriptionExpiresAt': subscriptionExpiresAt ?? subscriptionExpiry,
      'isAdmin': isAdmin,
      'isSuspended': isSuspended,
      'isBanned': isBanned,
      'chatIds': chatIds,
      'portfolio': portfolio,
      'profileCompleted': profileCompleted,

      // Location fields
      'wilaya': wilaya,
      'commune': commune,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'client',
      photoUrl: data['photoUrl'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      location: data['location'],
      address: data['address'] ?? '',
      totalJobs: data['totalJobs'] ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      fcmToken: data['fcmToken'],
      serviceIds: List<String>.from(data['serviceIds'] ?? []),

      // YOUR ACTUAL FIELDS
      profession: data['profession'],
      subscriptionActive: data['subscriptionActive'] ?? false,
      subscriptionExpiry: data['subscriptionExpiry'],
      fcmTokenUpdatedAt: data['fcmTokenUpdatedAt'],
      chatIds: List<String>.from(data['chatIds'] ?? []),
      portfolio: List<String>.from(data['portfolio'] ?? []),
      profileCompleted: data['profileCompleted'] ??
          (data['wilaya'] != null &&
              data['commune'] != null &&
              data['phone'] != null &&
              data['phone'].toString().isNotEmpty),

      // Admin/Moderation fields
      isSuspended: data['isSuspended'] ?? false,
      isBanned: data['isBanned'] ?? false,

      // Location fields
      wilaya: data['wilaya'],
      commune: data['commune'],
      subscriptionExpiresAt:
          data['subscriptionExpiresAt'] ?? data['subscriptionExpiry'],
      isAdmin: data['role'] == 'admin' || (data['isAdmin'] ?? false),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? photoUrl,
    Timestamp? createdAt,
    GeoPoint? location,
    String? address,
    int? totalJobs,
    double? rating,
    String? fcmToken,
    List<String>? serviceIds,
    String? profession,
    bool? subscriptionActive,
    Timestamp? subscriptionExpiry,
    Timestamp? subscriptionExpiresAt,
    bool? isAdmin,
    Timestamp? fcmTokenUpdatedAt,
    List<String>? chatIds,
    List<String>? portfolio,
    bool? profileCompleted,
    String? wilaya,
    String? commune,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      address: address ?? this.address,
      totalJobs: totalJobs ?? this.totalJobs,
      rating: rating ?? this.rating,
      fcmToken: fcmToken ?? this.fcmToken,
      serviceIds: serviceIds ?? this.serviceIds,
      profession: profession ?? this.profession,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      isAdmin: isAdmin ?? this.isAdmin,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
      chatIds: chatIds ?? this.chatIds,
      portfolio: portfolio ?? this.portfolio,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      wilaya: wilaya ?? this.wilaya,
      commune: commune ?? this.commune,
    );
  }

  bool get isProvider => role == 'provider';
  bool get isClient => role == 'client';
  bool get isGuest => role == 'guest';

  bool get hasValidSubscription {
    final expiry = subscriptionExpiresAt ?? subscriptionExpiry;
    return subscriptionActive &&
        expiry != null &&
        expiry.toDate().isAfter(DateTime.now());
  }
}

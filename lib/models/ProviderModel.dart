import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:service_app/models/UserModel.dart';

class ProviderModel {
  final String? uid;
  String name;
  String profession;
  String address;
  String wilaya;
  String commune;
  double rating; // Changed from final to mutable
  final bool subscriptionActive;
  LatLng? location;

  // Fields required by the UI
  final String phone;
  final String whatsapp; // Will use phone number
  final String description;
  final String photoUrl;
  final List<String> serviceIds;
  final List<String> serviceImages; // Fetched from services collection

  ProviderModel({
    this.uid,
    required this.name,
    required this.profession,
    required this.address,
    required this.wilaya,
    required this.commune,
    required this.phone,
    required this.whatsapp,
    required this.description,
    required this.photoUrl,
    required this.serviceIds,
    this.serviceImages = const [],
    this.rating = 0.0,
    this.subscriptionActive = false,
    this.location,
  });

  factory ProviderModel.fromUser(UserModel user) {
    LatLng? userLocation;
    if (user.location != null) {
      userLocation = LatLng(user.location!.latitude, user.location!.longitude);
    }

    return ProviderModel(
      uid: user.uid,
      name: user.name,
      profession: user.profession ?? 'Service Provider',
      address: user.address,
      wilaya: user.wilaya ?? '',
      commune: user.commune ?? '',
      phone: user.phone,
      whatsapp: user.phone, // Use phone for whatsapp
      description: user.profession ?? 'Professional service provider.',
      photoUrl: user.photoUrl,
      serviceIds: user.serviceIds,
      serviceImages: const [], // Will be fetched separately
      rating: user.rating,
      subscriptionActive: user.subscriptionActive,
      location: userLocation,
    );
  }

  // Factory method to create from Firestore data
  factory ProviderModel.fromFirestore(Map<String, dynamic> data, String id) {
    LatLng? location;
    if (data['location'] != null) {
      final geoPoint = data['location'] as GeoPoint;
      location = LatLng(geoPoint.latitude, geoPoint.longitude);
    }

    return ProviderModel(
      uid: id,
      name: data['name'] ?? '',
      profession: data['profession'] ?? 'Service Provider',
      address: data['address'] ?? '',
      wilaya: data['wilaya'] ?? '',
      commune: data['commune'] ?? '',
      phone: data['phone'] ?? '',
      whatsapp: data['phone'] ?? '', // Use phone for whatsapp
      description: data['description'] ??
          data['profession'] ??
          'Professional service provider.',
      photoUrl: data['photoUrl'] ?? '',
      serviceIds: List<String>.from(data['serviceIds'] ?? []),
      serviceImages: const [], // Will be fetched separately
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      subscriptionActive: data['subscriptionActive'] ?? false,
      location: location,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'profession': profession,
      'address': address,
      'wilaya': wilaya,
      'commune': commune,
      'phone': phone,
      'whatsapp': whatsapp,
      'description': description,
      'photoUrl': photoUrl,
      'serviceIds': serviceIds,
      'serviceImages': serviceImages,
      'rating': rating,
      'subscriptionActive': subscriptionActive,
      'location': location != null
          ? {'latitude': location!.latitude, 'longitude': location!.longitude}
          : null,
    };
  }

  // Helper method to get service images from services collection
  Future<List<String>> fetchServiceImages() async {
    if (serviceIds.isEmpty) return [];

    final images = <String>[];
    final servicesRef = FirebaseFirestore.instance.collection('services');

    for (final serviceId in serviceIds) {
      try {
        final doc = await servicesRef.doc(serviceId).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['images'] is List) {
            final serviceImages = List<String>.from(data['images'] ?? []);
            images.addAll(serviceImages);
          }
        }
      } catch (e) {
        print('Error fetching service images: $e');
      }
    }

    return images;
  }

  // Create a copy with service images
  ProviderModel copyWithServiceImages(List<String> images) {
    return ProviderModel(
      uid: uid,
      name: name,
      profession: profession,
      address: address,
      wilaya: wilaya,
      commune: commune,
      phone: phone,
      whatsapp: whatsapp,
      description: description,
      photoUrl: photoUrl,
      serviceIds: serviceIds,
      serviceImages: images,
      rating: rating,
      subscriptionActive: subscriptionActive,
      location: location,
    );
  }

  // Create a copy with updated rating
  ProviderModel copyWith({
    String? uid,
    String? name,
    String? profession,
    String? address,
    String? wilaya,
    String? commune,
    double? rating,
    bool? subscriptionActive,
    LatLng? location,
    String? phone,
    String? whatsapp,
    String? description,
    String? photoUrl,
    List<String>? serviceIds,
    List<String>? serviceImages,
  }) {
    return ProviderModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      profession: profession ?? this.profession,
      address: address ?? this.address,
      wilaya: wilaya ?? this.wilaya,
      commune: commune ?? this.commune,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      serviceIds: serviceIds ?? this.serviceIds,
      serviceImages: serviceImages ?? this.serviceImages,
      rating: rating ?? this.rating,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      location: location ?? this.location,
    );
  }

  @override
  String toString() {
    return 'ProviderModel{name: $name, profession: $profession, wilaya: $wilaya, commune: $commune}';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart'
    show Timestamp, DocumentSnapshot;

class Service {
  final String id;
  final String providerId;
  final String title;
  final String description;
  final String category;
  final String subcategory;
  final double price;
  final String priceUnit;
  final List<String> images;
  final String location;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double rating;
  final int totalReviews;
  final List<String> tags;

  Service({
    required this.id,
    required this.providerId,
    required this.title,
    required this.description,
    required this.category,
    required this.subcategory,
    required this.price,
    required this.priceUnit,
    this.images = const [],
    required this.location,
    this.latitude,
    this.longitude,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'providerId': providerId,
      'title': title,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'price': price,
      'priceUnit': priceUnit,
      'images': images,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'rating': rating,
      'totalReviews': totalReviews,
      'tags': tags,
    };
  }

  factory Service.fromMap(Map<String, dynamic> map) {
    // Helper function to parse timestamp
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        return DateTime.tryParse(timestamp) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Service(
      id: map['id'] ?? '',
      providerId: map['providerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      subcategory: map['subcategory'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      priceUnit: map['priceUnit'] ?? 'per service',
      images: List<String>.from(map['images'] ?? []),
      location: map['location'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isActive: map['isActive'] ?? true,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as int?) ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  // Factory from Firestore document
  factory Service.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Service.fromMap({...data, 'id': doc.id});
  }

  String get displayPrice {
    return '$price DZD $priceUnit';
  }

  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }

  bool get hasLocation => latitude != null && longitude != null;

  Service copyWith({
    String? id,
    String? providerId,
    String? title,
    String? description,
    String? category,
    String? subcategory,
    double? price,
    String? priceUnit,
    List<String>? images,
    String? location,
    double? latitude,
    double? longitude,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? totalReviews,
    List<String>? tags,
  }) {
    return Service(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      price: price ?? this.price,
      priceUnit: priceUnit ?? this.priceUnit,
      images: images ?? this.images,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      tags: tags ?? this.tags,
    );
  }
}

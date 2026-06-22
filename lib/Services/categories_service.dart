import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/models/CategoryModel.dart';

class CategoriesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all categories from Firestore categories collection
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('isActive', isEqualTo: true)
          .get();
      
      final categories = <CategoryModel>[];

      for (var doc in snapshot.docs) {
        final category = CategoryModel.fromFirestore(doc);
        
        // Fetch subcategories
        final subsSnapshot = await _firestore
            .collection('categories')
            .doc(doc.id)
            .collection('subcategories')
            .where('isActive', isEqualTo: true)
            .get();
            
        final subcategories = subsSnapshot.docs
            .map((d) => SubcategoryModel.fromMap(d.data(), d.id))
            .toList();
        
        categories.add(category.copyWith(subcategories: subcategories));
      }

      return categories;
    } catch (e) {
      debugPrint('❌ Error getting categories: $e');
      return [];
    }
  }

  // Get subcategories for a specific category
  Future<List<SubcategoryModel>> getSubcategories(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('subcategories')
          .where('isActive', isEqualTo: true)
          .get();
          
      return snapshot.docs
          .map((d) => SubcategoryModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting subcategories for $categoryId: $e');
      return [];
    }
  }

  // Get categories as map for dropdowns
  Future<Map<String, List<SubcategoryModel>>> getCategoriesForFilter() async {
    final categories = await getAllCategories();
    final result = <String, List<SubcategoryModel>>{};

    for (var category in categories) {
      result[category.name] = category.subcategories;
    }

    return result;
  }

  // Get category by name (useful for reverse lookup from legacy data)
  Future<CategoryModel?> getCategoryByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
          
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final category = CategoryModel.fromFirestore(doc);
      
      final subcategories = await getSubcategories(doc.id);
      return category.copyWith(subcategories: subcategories);
    } catch (e) {
      debugPrint('❌ Error in getCategoryByName for "$name": $e');
      return null;
    }
  }
}

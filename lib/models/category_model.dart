// lib/models/category_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String defaultDepartment;
  final String? description;
  final String? iconName;
  final bool isActive;
  final int? sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.defaultDepartment,
    this.description,
    this.iconName,
    this.isActive = true,
    this.sortOrder,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CategoryModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Category',
      defaultDepartment: data['defaultDepartment'] as String? ?? 'General Grievances',
      description: data['description'] as String?,
      iconName: data['iconName'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: data['sortOrder'] as int?,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      name: data['name'] as String? ?? 'Unnamed Category',
      defaultDepartment: data['defaultDepartment'] as String? ?? 'General Grievances',
      description: data['description'] as String?,
      iconName: data['iconName'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: data['sortOrder'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'defaultDepartment': defaultDepartment,
      if (description != null) 'description': description,
      if (iconName != null) 'iconName': iconName,
      'isActive': isActive,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
  }
}

// lib/models/categories.dart
import 'dart:convert';

class Category {
  final String id;            // _id จาก backend (Mongo ObjectID as hex string)
  final String categoryName;  // category_name
  final String shortName;     // short_name

  const Category({
    required this.id,
    required this.categoryName,
    required this.shortName,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['_id']?.toString() ?? '',
      categoryName: map['category_name']?.toString() ?? '',
      shortName: map['short_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        '_id': id,
        'category_name': categoryName,
        'short_name': shortName,
      };

  factory Category.fromJson(String source) =>
      Category.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode(toMap());

  static List<Category> listFromJson(String source) {
    final data = jsonDecode(source);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Category.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  Category copyWith({String? id, String? categoryName, String? shortName}) =>
      Category(
        id: id ?? this.id,
        categoryName: categoryName ?? this.categoryName,
        shortName: shortName ?? this.shortName,
      );

  @override
  String toString() =>
      'Category(_id: $id, category_name: $categoryName, short_name: $shortName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          categoryName == other.categoryName &&
          shortName == other.shortName;

  @override
  int get hashCode => Object.hash(id, categoryName, shortName);
}

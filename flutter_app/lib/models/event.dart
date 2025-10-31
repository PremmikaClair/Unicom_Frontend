import 'package:flutter/foundation.dart';

class AppEvent {
  final String id;
  final String title;
  final String? description;
  final String? category;   // e.g., "academic", "social"
  final String? role;       // e.g., "student", "staff", "admin" (who can host/organize)
  final String? location;
  final DateTime startTime;
  final DateTime? endTime;
  final String? imageUrl;
  final String? organizer;  // display name / organization
  final bool? isFree;       // if your backend provides it
  final int? likeCount;     // if you want to sort/popular
  final int? capacity;      // backend: event.max_participation
  final bool? haveForm;     // backend: event.have_form

  const AppEvent({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description,
    this.category,
    this.role,
    this.location,
    this.imageUrl,
    this.organizer,
    this.isFree,
    this.likeCount,
    this.capacity,
    this.haveForm,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    // Handle various id keys
    final rawId = (json['event_id'] ?? json['_id'] ?? json['id'] ?? '').toString();
    DateTime parseTime(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return AppEvent(
      id: rawId,
      // Map newer key 'topic' to title
      title: (json['topic'] ?? json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      // Prefer posted_as.label if present
      role: (() {
        final pa = json['posted_as'];
        if (pa is Map) {
          final m = pa.cast<String, dynamic>();
          final lbl = (m['label'] ?? m['tag'] ?? m['position_key'])?.toString();
          if (lbl != null && lbl.trim().isNotEmpty) return lbl.trim();
        }
        return json['role']?.toString();
      })(),
      location: json['location']?.toString(),
      startTime: parseTime(json['startTime']),
      endTime: json['endTime'] != null ? parseTime(json['endTime']) : null,
      // Accept multiple keys from backend for the event image
      imageUrl: (json['imageUrl'] ?? json['image_url'] ?? json['pictureURL'] ?? json['picture_url'])?.toString(),
      organizer: json['organizer']?.toString(),
      isFree: json['isFree'] is bool ? json['isFree'] as bool : null,
      likeCount: json['likeCount'] is int ? json['likeCount'] as int : null,
      // Map capacity/max_participation
      capacity: (json['capacity'] is int)
          ? json['capacity'] as int
          : (json['max_participation'] is int)
              ? json['max_participation'] as int
              : (int.tryParse('${json['capacity']}') ?? int.tryParse('${json['max_participation']}')),
      haveForm: json['have_form'] is bool ? json['have_form'] as bool : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'role': role,
    'location': location,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'imageUrl': imageUrl,
    'organizer': organizer,
    'isFree': isFree,
    'likeCount': likeCount,
    'capacity': capacity,
    'have_form': haveForm,
  };
}

// lib/models/filter_models.dart

// Lightweight option model used by filter UI
class OptionItem {
  final String id;    // org_path or category _id
  final String label; // display name
  const OptionItem(this.id, this.label);
}

// Aggregated data set for the filter bottom sheet
class FilterData {
  final List<OptionItem> faculties;
  final List<OptionItem> clubs;
  final List<OptionItem> categories;
  final Map<String, List<OptionItem>> departmentsByFaculty;

  const FilterData({
    required this.faculties,
    required this.clubs,
    required this.categories,
    required this.departmentsByFaculty,
  });
}


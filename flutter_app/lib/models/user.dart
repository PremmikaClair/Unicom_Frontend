class UserProfile {
  final int? id; // numeric app id
  final String? oid; // mongo _id (if ever returned)
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? studentId;
  final String? advisorId;
  final String? gender;
  final String? typePerson;
  final String? status;
  final Map<String, dynamic> raw;

  const UserProfile({
    this.id,
    this.oid,
    this.firstName,
    this.lastName,
    this.email,
    this.studentId,
    this.advisorId,
    this.gender,
    this.typePerson,
    this.status,
    this.raw = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    int? _toInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      if (v is double) return v.toInt();
      return null;
    }

    String? _readOid(dynamic value) {
      if (value == null) return null;
      if (value is String) return value.trim().isEmpty ? null : value.trim();
      if (value is Map && value[r'$oid'] != null) {
        final raw = value[r'$oid']?.toString();
        return (raw != null && raw.trim().isNotEmpty) ? raw.trim() : null;
      }
      return value.toString();
    }

    final rawId = j['id'];
    final guessOid = _readOid(
      j['_id'] ??
      j['oid'] ??
      j['objectId'] ??
      j['object_id'] ??
      (rawId is String && rawId.trim().isNotEmpty ? rawId : null),
    );

    return UserProfile(
      id: _toInt(rawId ?? j['seqID'] ?? j['SeqID']),
      oid: guessOid,
      firstName: (j['firstName'] ?? j['firstname'])?.toString(),
      lastName: (j['lastName'] ?? j['lastname'])?.toString(),
      email: j['email']?.toString(),
      studentId: j['student_id']?.toString(),
      advisorId: j['advisor_id']?.toString(),
      gender: j['gender']?.toString(),
      typePerson: j['type_person']?.toString(),
      status: j['status']?.toString(),
      raw: Map<String, dynamic>.from(j),
    );
  }
}

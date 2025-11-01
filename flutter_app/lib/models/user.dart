class UserProfile {
  final int? id; // numeric app id
  final String? oid; // mongo _id (if ever returned)
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? profilePic;
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
    this.profilePic,
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

    return UserProfile(
      id: _toInt(j['id'] ?? j['seqID'] ?? j['SeqID']),
      oid: (j['_id']?.toString()),
      firstName: (j['firstName'] ?? j['firstname'])?.toString(),
      lastName: (j['lastName'] ?? j['lastname'])?.toString(),
      email: j['email']?.toString(),
      profilePic: (j['profile_pic'] ?? j['profile pic'])?.toString(),
      studentId: j['student_id']?.toString(),
      advisorId: j['advisor_id']?.toString(),
      gender: j['gender']?.toString(),
      typePerson: j['type_person']?.toString(),
      status: j['status']?.toString(),
      raw: Map<String, dynamic>.from(j),
    );
  }
}

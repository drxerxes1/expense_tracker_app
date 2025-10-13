import 'package:cloud_firestore/cloud_firestore.dart';

enum OfficerStatus { pending, approved, denied }
enum OfficerRole { president, treasurer, secretary, auditor, moderator, member }

class Officer {
  final String id;
  final String orgId;
  final String userId;
  final String name;
  final String email;
  final OfficerRole role;
  final OfficerStatus status;
  final DateTime joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Officer({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Officer.fromMap(Map<String, dynamic> map) {
    // Handle different data formats for role and status
    String roleString;
    if (map['role'] is int) {
      roleString = OfficerRole.values[map['role']].toString().split('.').last;
    } else {
      roleString = map['role']?.toString() ?? 'member';
    }

    String statusString;
    if (map['status'] is int) {
      statusString = OfficerStatus.values[map['status']].toString().split('.').last;
    } else {
      statusString = map['status']?.toString() ?? 'pending';
    }

    // Handle different date formats
    DateTime parseDate(dynamic dateValue) {
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        return dateValue;
      } else {
        return DateTime.now(); // fallback
      }
    }

    return Officer(
      id: map['id'] ?? '',
      orgId: map['orgId'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: OfficerRole.values.firstWhere(
        (e) => e.toString().split('.').last == roleString,
        orElse: () => OfficerRole.member,
      ),
      status: OfficerStatus.values.firstWhere(
        (e) => e.toString().split('.').last == statusString,
        orElse: () => OfficerStatus.pending,
      ),
      joinedAt: parseDate(map['joinedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,
      'userId': userId,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Officer copyWith({
    String? id,
    String? orgId,
    String? userId,
    String? name,
    String? email,
    OfficerRole? role,
    OfficerStatus? status,
    DateTime? joinedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Officer(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

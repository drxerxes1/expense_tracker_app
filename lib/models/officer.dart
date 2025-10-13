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
    return Officer(
      id: map['id'] ?? '',
      orgId: map['orgId'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: OfficerRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => OfficerRole.member,
      ),
      status: OfficerStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OfficerStatus.pending,
      ),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
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

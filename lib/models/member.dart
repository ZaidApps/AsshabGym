import 'package:cloud_firestore/cloud_firestore.dart';

/// Membership status for device-based members (`members` collection).
///
/// Admin activates a device by setting [membershipStatus] to [active] and
/// [subscriptionExpiryDate] to a future timestamp.
class Member {
  static const String statusPending = 'pending';
  static const String statusActive = 'active';

  final String id;
  final String deviceId;
  final String phoneNumber;
  final Timestamp? subscriptionExpiryDate;
  final String membershipStatus;

  Member({
    required this.id,
    required this.deviceId,
    required this.phoneNumber,
    required this.subscriptionExpiryDate,
    required this.membershipStatus,
  });

  bool get isPending =>
      membershipStatus == statusPending || subscriptionExpiryDate == null;

  bool get isActiveForCheckIn =>
      membershipStatus == statusActive && subscriptionExpiryDate != null;

  factory Member.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Member(
      id: doc.id,
      deviceId: data['device_id'] as String? ?? doc.id,
      phoneNumber: data['phone_number'] as String? ?? '',
      subscriptionExpiryDate:
          data['subscription_expiry_date'] as Timestamp?,
      membershipStatus:
          data['membership_status'] as String? ?? statusPending,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class CheckIn {
  final String? deviceId;
  final String? memberName;
  final String checkinDate;
  final String checkinTime;
  final String deviceType;
  final Timestamp timestamp;

  CheckIn({
    this.deviceId,
    this.memberName,
    required this.checkinDate,
    required this.checkinTime,
    required this.deviceType,
    required this.timestamp,
  });

  factory CheckIn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CheckIn(
      deviceId: data['device_id'],
      memberName: data['member_name'],
      checkinDate: data['checkin_date'],
      checkinTime: data['checkin_time'],
      deviceType: data['device_type'],
      timestamp: data['timestamp'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'device_id': deviceId,
      'member_name': memberName,
      'checkin_date': checkinDate,
      'checkin_time': checkinTime,
      'device_type': deviceType,
      'timestamp': timestamp,
    };
  }
}

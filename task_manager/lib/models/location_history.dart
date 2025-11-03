class LocationHistory {
  final int? id;
  final int taskId;
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime accessedAt;
  final String actionType; // 'view', 'edit', 'complete'

  LocationHistory({
    this.id,
    required this.taskId,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.accessedAt,
    required this.actionType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'accessed_at': accessedAt.toIso8601String(),
      'action_type': actionType,
    };
  }

  factory LocationHistory.fromMap(Map<String, dynamic> map) {
    return LocationHistory(
      id: map['id'],
      taskId: map['task_id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
      accessedAt: DateTime.parse(map['accessed_at']),
      actionType: map['action_type'],
    );
  }

  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  String get actionIcon {
    switch (actionType) {
      case 'view':
        return '👁️';
      case 'edit':
        return '✏️';
      case 'complete':
        return '✅';
      default:
        return '📍';
    }
  }

  String get actionLabel {
    switch (actionType) {
      case 'view':
        return 'Visualizada';
      case 'edit':
        return 'Editada';
      case 'complete':
        return 'Completada';
      default:
        return 'Acessada';
    }
  }
}

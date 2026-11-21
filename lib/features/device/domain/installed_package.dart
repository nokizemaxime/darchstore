import 'package:equatable/equatable.dart';

class InstalledPackage extends Equatable {
  const InstalledPackage({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.signatureSha256,
  });

  final String packageName;
  final String versionName;
  final int versionCode;
  final String signatureSha256;

  @override
  List<Object?> get props => [
    packageName,
    versionName,
    versionCode,
    signatureSha256,
  ];
}

enum InstallEventStatus { awaitingUser, success, cancelled, failure }

class InstallEvent {
  const InstallEvent({
    required this.packageName,
    required this.status,
    this.message,
  });

  final String packageName;
  final InstallEventStatus status;
  final String? message;

  static InstallEvent? parse(Object? raw) {
    if (raw is! Map) return null;
    final packageName = raw['packageName'];
    final statusName = raw['status'];
    if (packageName is! String || statusName is! String) return null;
    final status = switch (statusName) {
      'awaiting_user' => InstallEventStatus.awaitingUser,
      'success' => InstallEventStatus.success,
      'cancelled' => InstallEventStatus.cancelled,
      'failure' => InstallEventStatus.failure,
      _ => null,
    };
    if (status == null) return null;
    final message = raw['message'];
    return InstallEvent(
      packageName: packageName,
      status: status,
      message: message is String && message.isNotEmpty ? message : null,
    );
  }
}

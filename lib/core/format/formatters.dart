String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = ['octets', 'Ko', 'Mo', 'Go'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 10 ? 0 : 1;
  final shown = value.toStringAsFixed(digits).replaceAll('.', ',');
  return '$shown ${units[unit]}';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String androidGeneration(int minSdk) {
  return switch (minSdk) {
    <= 23 => 'Android 6+',
    24 => 'Android 7+',
    26 => 'Android 8+',
    28 => 'Android 9+',
    29 => 'Android 10+',
    30 => 'Android 11+',
    31 => 'Android 12+',
    33 => 'Android 13+',
    34 => 'Android 14+',
    35 => 'Android 15+',
    36 => 'Android 16+',
    _ => 'Android SDK $minSdk+',
  };
}

String shortDigest(String value) {
  if (value.length <= 18) return value;
  return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
}

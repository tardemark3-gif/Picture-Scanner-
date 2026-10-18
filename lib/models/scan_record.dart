class ScanRecord {
  final int? id;
  final String barcode;
  final String picturePath;
  final String pictureFilename;
  final String scannedAt;

  const ScanRecord({
    this.id,
    required this.barcode,
    required this.picturePath,
    required this.pictureFilename,
    required this.scannedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'picture_path': picturePath,
      'picture_filename': pictureFilename,
      'scanned_at': scannedAt,
    };
  }

  factory ScanRecord.fromMap(Map<String, Object?> map) {
    return ScanRecord(
      id: map['id'] as int?,
      barcode: map['barcode'] as String? ?? '',
      picturePath: map['picture_path'] as String? ?? '',
      pictureFilename: map['picture_filename'] as String? ?? '',
      scannedAt: map['scanned_at'] as String? ?? '',
    );
  }
}

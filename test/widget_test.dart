import 'package:flutter_test/flutter_test.dart';
import 'package:picture_scanner/main.dart';

void main() {
  test('Picture Scanner application can be constructed', () {
    const application = PictureScannerApp();
    expect(application, isA<PictureScannerApp>());
  });
}

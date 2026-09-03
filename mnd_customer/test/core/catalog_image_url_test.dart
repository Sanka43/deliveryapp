import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/core/utils/catalog_image_url.dart';

void main() {
  test('pickCatalogImageUrl accepts imageURL and nested downloadURL', () {
    expect(
      pickCatalogImageUrl(<String, dynamic>{
        'imageURL': 'https://example.com/a.jpg',
      }),
      'https://example.com/a.jpg',
    );
    expect(
      pickCatalogImageUrl(<String, dynamic>{
        'image': <String, dynamic>{
          'downloadURL': 'https://example.com/b.jpg',
        },
      }),
      'https://example.com/b.jpg',
    );
    expect(
      pickCatalogImageUrl(<String, dynamic>{
        'logoUrl': 'gs://bucket/path.jpg',
      }),
      'gs://bucket/path.jpg',
    );
  });
}

import 'package:image/image.dart' as imagelib;

/// Decodes raster data with [imagelib.decodeImage], and for JPEGs retries once
/// after stripping APP1 segments when decoding fails on malformed EXIF.
imagelib.Image? decodeImageLenient(List<int> bytes) {
  if (bytes.isEmpty) return null;
  try {
    final decoded = imagelib.decodeImage(bytes);
    if (decoded != null) return decoded;
  } on imagelib.ImageException {
    if (!_isJpeg(bytes)) return null;
    try {
      return imagelib.decodeImage(_stripJpegApp1Segments(bytes));
    } catch (_) {
      return null;
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool _isJpeg(List<int> bytes) => bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

/// Removes APP1 (0xE1) segments — where EXIF typically lives — from a JPEG.
List<int> _stripJpegApp1Segments(List<int> data) {
  if (!_isJpeg(data)) return List<int>.from(data);
  final out = <int>[0xFF, 0xD8];
  var i = 2;
  while (i < data.length) {
    if (data[i] != 0xFF) {
      out.addAll(data.sublist(i));
      break;
    }
    while (i < data.length && data[i] == 0xFF) {
      i++;
    }
    if (i >= data.length) break;
    final marker = data[i];
    i++;
    if (marker == 0xD9) {
      out.addAll([0xFF, 0xD9]);
      break;
    }
    if (marker == 0xDA) {
      out.addAll([0xFF, 0xDA]);
      if (i < data.length) out.addAll(data.sublist(i));
      break;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      out.addAll([0xFF, marker]);
      continue;
    }
    if (i + 1 >= data.length) break;
    final len = (data[i] << 8) | data[i + 1];
    if (len < 2) break;
    final segmentEnd = i + len;
    if (segmentEnd > data.length) break;
    if (marker != 0xE1) {
      out.add(0xFF);
      out.add(marker);
      out.addAll(data.sublist(i, segmentEnd));
    }
    i = segmentEnd;
  }
  return out;
}

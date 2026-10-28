import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The provider an [Image] loads, without the [ResizeImage] that sizes its decode.
ImageProvider unwrapImageProvider(ImageProvider provider) =>
    provider is ResizeImage ? unwrapImageProvider(provider.imageProvider) : provider;

Iterable<ImageProvider> _providers(WidgetTester tester, Finder? within) => tester
    .widgetList<Image>(within == null ? find.byType(Image) : find.descendant(of: within, matching: find.byType(Image)))
    .map((Image image) => unwrapImageProvider(image.image));

/// URLs of the network pictures drawn now, in paint order, optionally only under [within].
List<String> networkImageUrls(WidgetTester tester, {Finder? within}) =>
    _providers(tester, within).whereType<CachedNetworkImageProvider>().map((p) => p.url).toList();

/// Paths of the file pictures drawn now, in paint order, optionally only under [within].
List<String> fileImagePaths(WidgetTester tester, {Finder? within}) =>
    _providers(tester, within).whereType<FileImage>().map((p) => p.file.path).toList();

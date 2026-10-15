import 'package:flutter/widgets.dart';

/// How close to the end of a feed, in logical pixels, the next page starts to load.
const double kFeedLoadMoreExtent = 600;

/// Whether [metrics] are within [kFeedLoadMoreExtent] of the end of the scroll extent.
bool isNearFeedEnd(ScrollMetrics metrics) => metrics.pixels >= metrics.maxScrollExtent - kFeedLoadMoreExtent;

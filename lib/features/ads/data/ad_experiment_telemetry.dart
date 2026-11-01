import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';

/// Contains no account identifiers or ad response data.
class AdExperimentEvent extends AnalyticsEvent {
  const AdExperimentEvent({
    required this.placement,
    required this.format,
    required this.bucket,
    required this.version,
    required this.outcome,
    this.valueMicros,
    this.currency,
    this.precision,
  });

  final String placement;
  final AdExperimentFormat format;
  final int bucket;
  final String version;
  final String outcome;
  final double? valueMicros;
  final String? currency;
  final String? precision;

  @override
  String get eventName => 'ad_experiment';

  @override
  Map<String, Object?> toWireParameters() => <String, Object?>{
    'placement': placement,
    'format': format.name,
    'bucket': bucket,
    'version': version,
    'outcome': outcome,
    if (valueMicros != null) 'value_micros': valueMicros,
    if (currency != null) 'currency': currency,
    if (precision != null) 'precision': precision,
  };
}

void trackAdExperiment(AdExperimentEvent event) {
  analytics.track(event);
}

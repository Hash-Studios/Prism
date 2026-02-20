import 'dart:convert';

class NormalizedAnalyticsEvent {
  const NormalizedAnalyticsEvent({required this.name, required this.parameters});

  final String name;
  final Map<String, Object> parameters;
}

class AnalyticsEventNormalizer {
  const AnalyticsEventNormalizer();

  static const Map<String, String> _legacyEventAliases = <String, String>{
    'reportSetup': 'report_setup',
    'reportWall': 'report_wall',
  };

  static final RegExp _validEventNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  NormalizedAnalyticsEvent normalizeEvent({required String name, Map<String, Object?>? parameters}) {
    return NormalizedAnalyticsEvent(name: normalizeEventName(name), parameters: normalizeParameters(parameters));
  }

  String normalizeEventName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'unknown_event';
    }

    final String? aliased = _legacyEventAliases[trimmed];
    if (aliased != null) {
      return aliased;
    }

    if (_validEventNamePattern.hasMatch(trimmed)) {
      return trimmed;
    }

    final String normalized = _toSnakeCase(trimmed);
    if (normalized.isEmpty) {
      return 'unknown_event';
    }
    return normalized;
  }

  String normalizeScreenName(String screenName) {
    final String trimmed = screenName.trim();
    if (trimmed.isEmpty) {
      return 'unknown_screen';
    }

    final String withoutLeadingSlash = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    if (withoutLeadingSlash.isEmpty) {
      return 'root';
    }

    final String normalized = _toSnakeCase(withoutLeadingSlash);
    if (normalized.isEmpty) {
      return 'unknown_screen';
    }
    return normalized;
  }

  String normalizePropertyName(String name) {
    final String normalized = _toSnakeCase(name);
    if (normalized.isEmpty) {
      return 'unknown_property';
    }
    return normalized;
  }

  Map<String, Object> normalizeParameters(Map<String, Object?>? parameters) {
    if (parameters == null || parameters.isEmpty) {
      return const <String, Object>{};
    }

    final Map<String, Object> normalized = <String, Object>{};
    for (final MapEntry<String, Object?> entry in parameters.entries) {
      final String key = _toSnakeCase(entry.key);
      if (key.isEmpty) {
        continue;
      }
      final Object? value = _normalizeValue(entry.value);
      if (value == null) {
        continue;
      }
      normalized[key] = value;
    }
    return normalized;
  }

  String _toSnakeCase(String raw) {
    final String withWordBoundaries = raw
        .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (Match m) => '${m.group(1)}_${m.group(2)}')
        .replaceAll(RegExp(r'[\s\-.\/]+'), '_')
        .replaceAll(RegExp('[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp('_+'), '_');

    return withWordBoundaries.replaceAll(RegExp(r'^_+|_+$'), '').toLowerCase();
  }

  Object? _normalizeValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Uri) {
      return value.toString();
    }
    if (value is Iterable || value is Map) {
      return jsonEncode(_toJsonSafe(value));
    }
    return value.toString();
  }

  Object? _toJsonSafe(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Uri) {
      return value.toString();
    }
    if (value is Iterable) {
      return value.map<Object?>((Object? item) => _toJsonSafe(item)).toList(growable: false);
    }
    if (value is Map) {
      return value.map<String, Object?>((Object? key, Object? nestedValue) {
        return MapEntry<String, Object?>(key.toString(), _toJsonSafe(nestedValue));
      });
    }
    return value.toString();
  }
}

import 'dart:io';

import 'package:yaml/yaml.dart';

const String _defaultSchemaPath = 'lib/core/analytics/schema/analytics_events.yaml';
const String _defaultOutputPath = 'lib/core/analytics/events/generated/analytics_events.g.dart';

void main(List<String> args) {
  final String schemaPath = args.isNotEmpty ? args.first : _defaultSchemaPath;
  final String outputPath = args.length > 1 ? args[1] : _defaultOutputPath;

  final File schemaFile = File(schemaPath);
  if (!schemaFile.existsSync()) {
    stderr.writeln('Schema file not found: $schemaPath');
    exitCode = 1;
    return;
  }

  final Object? decoded = loadYaml(schemaFile.readAsStringSync());
  if (decoded is! YamlMap) {
    stderr.writeln('Invalid schema. Expected a YAML map.');
    exitCode = 1;
    return;
  }

  final List<YamlMap> events = _readEvents(decoded);
  final String content = _generateFile(events);

  final File outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(content);
  stdout.writeln('Generated ${events.length} analytics event classes at $outputPath');
}

List<YamlMap> _readEvents(YamlMap root) {
  final Object? raw = root['events'];
  if (raw is! YamlList) {
    throw StateError('Schema must define an "events" list.');
  }
  return raw.cast<YamlMap>();
}

String _generateFile(List<YamlMap> events) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.');
  buffer.writeln('//');
  buffer.writeln('// Run: dart run tool/generate_analytics_schema.dart');
  buffer.writeln();
  buffer.writeln("import 'package:Prism/core/analytics/events/analytics_enums.dart';");
  buffer.writeln("import 'package:Prism/core/analytics/events/analytics_event.dart';");
  buffer.writeln();

  for (final YamlMap event in events) {
    final String eventId = _expectString(event, 'id');
    final String className = '${_snakeToPascal(eventId)}Event';
    final List<_FieldSpec> fields = _readFields(event);
    buffer.writeln(_generateClass(eventId: eventId, className: className, fields: fields));
    buffer.writeln();
  }

  return buffer.toString();
}

List<_FieldSpec> _readFields(YamlMap event) {
  final Object? rawFields = event['fields'];
  if (rawFields == null) {
    return const <_FieldSpec>[];
  }
  if (rawFields is! YamlList) {
    throw StateError('Event "${event['id']}" has invalid "fields".');
  }
  return rawFields.cast<YamlMap>().map(_FieldSpec.fromYaml).toList(growable: false);
}

String _generateClass({required String eventId, required String className, required List<_FieldSpec> fields}) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('class $className extends AnalyticsEvent {');
  if (fields.isEmpty) {
    buffer.writeln('  const $className();');
  } else {
    buffer.writeln('  const $className({');
    for (final _FieldSpec field in fields) {
      final String prefix = field.required ? 'required ' : '';
      buffer.writeln('    ${prefix}this.${field.dartName},');
    }
    buffer.writeln('  });');
  }
  buffer.writeln();

  for (final _FieldSpec field in fields) {
    final String nullableSuffix = field.required ? '' : '?';
    buffer.writeln('  final ${field.dartType}$nullableSuffix ${field.dartName};');
  }

  if (fields.isNotEmpty) {
    buffer.writeln();
  }
  buffer.writeln('  @override');
  buffer.writeln("  String get eventName => '$eventId';");
  buffer.writeln();
  buffer.writeln('  @override');
  buffer.writeln('  Map<String, Object?> toWireParameters() {');
  if (fields.isEmpty) {
    buffer.writeln('    return const <String, Object?>{};');
  } else {
    buffer.writeln('    return <String, Object?>{');
    for (final _FieldSpec field in fields) {
      final String serialized = field.serializedValueExpression(forceNonNull: !field.required);
      if (field.required) {
        buffer.writeln("      '${field.wireKey}': $serialized,");
      } else {
        buffer.writeln("      if (${field.dartName} != null) '${field.wireKey}': $serialized,");
      }
    }
    buffer.writeln('    };');
  }
  buffer.writeln('  }');
  buffer.writeln('}');
  return buffer.toString();
}

String _snakeToPascal(String value) {
  return value
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

String _snakeToCamel(String value) {
  final List<String> parts = value.split('_').where((String part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) {
    return value;
  }
  final String first = parts.first.toLowerCase();
  if (parts.length == 1) {
    return first;
  }
  final String rest = parts
      .skip(1)
      .map((String part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join();
  return '$first$rest';
}

String _expectString(YamlMap map, String key) {
  final Object? value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw StateError('Expected non-empty string for key "$key".');
  }
  return value.trim();
}

class _FieldSpec {
  _FieldSpec({
    required this.dartName,
    required this.wireKey,
    required this.type,
    required this.required,
    required this.enumType,
  });

  factory _FieldSpec.fromYaml(YamlMap yaml) {
    final String rawName = _expectString(yaml, 'name');
    final String? configuredKey = (yaml['key'] as String?)?.trim();
    final String wireKey = configuredKey == null || configuredKey.isEmpty ? rawName : configuredKey;
    final String type = _expectString(yaml, 'type').toLowerCase();
    final bool required = (yaml['required'] as bool?) ?? true;
    final String? enumType = (yaml['enum'] as String?)?.trim();
    if (type == 'enum' && (enumType == null || enumType.isEmpty)) {
      throw StateError('Enum field "$rawName" must provide "enum".');
    }
    return _FieldSpec(
      dartName: _snakeToCamel(rawName),
      wireKey: wireKey,
      type: type,
      required: required,
      enumType: enumType,
    );
  }

  final String dartName;
  final String wireKey;
  final String type;
  final bool required;
  final String? enumType;

  String get dartType {
    switch (type) {
      case 'string':
        return 'String';
      case 'int':
        return 'int';
      case 'double':
        return 'double';
      case 'num':
        return 'num';
      case 'bool':
        return 'bool';
      case 'datetime':
        return 'DateTime';
      case 'enum':
        return enumType!;
      default:
        throw StateError('Unsupported field type "$type" for "$dartName".');
    }
  }

  String serializedValueExpression({bool forceNonNull = false}) {
    final String valueRef = forceNonNull ? '$dartName!' : dartName;
    switch (type) {
      case 'enum':
        return '$valueRef.wireValue';
      case 'datetime':
        return '$valueRef.toUtc().toIso8601String()';
      case 'bool':
        return '$valueRef ? 1 : 0';
      default:
        return valueRef;
    }
  }
}

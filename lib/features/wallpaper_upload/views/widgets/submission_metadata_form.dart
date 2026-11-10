import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/biz/wall_release.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/release_time_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Optional title, category and tags for a wallpaper that goes to review. Every field can stay empty.
class SubmissionMetadataForm extends StatefulWidget {
  const SubmissionMetadataForm({
    super.key,
    required this.onChanged,
    this.initial = const SubmissionMetadata(),
    this.showCategory = true,
    this.showRelease = false,
    this.enabled = true,
    this.textEnabled = true,
    this.releaseScheduled = false,
  });

  final SubmissionMetadata initial;
  final ValueChanged<SubmissionMetadata> onChanged;
  final bool showCategory;
  final bool showRelease;
  final bool enabled;

  /// False for an approved and scheduled wall: only the release time can change.
  final bool textEnabled;
  final bool releaseScheduled;

  @override
  SubmissionMetadataFormState createState() => SubmissionMetadataFormState();
}

class SubmissionMetadataFormState extends State<SubmissionMetadataForm> {
  static final TextInputFormatter _lineBreaksToSpaces = FilteringTextInputFormatter.deny(
    RegExp(r'\r\n|[\r\n]'),
    replacementString: ' ',
  );

  late final TextEditingController _title = TextEditingController(text: widget.initial.title);
  late final TextEditingController _description = TextEditingController(text: widget.initial.description);
  final TextEditingController _tagInput = TextEditingController();
  late String _category = widget.initial.category;
  late List<String> _tags = List<String>.of(widget.initial.tags);
  late DateTime? _releaseAt = widget.initial.releaseAt;
  bool _invalid = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    widget.initial.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category,
      tags: List.of(_tags),
      releaseAt: () => _releaseAt,
    ),
  );

  bool flush() {
    if (_tagInput.text.trim().isNotEmpty) _addTags(_tagInput.text);
    _emit();
    final valid = submissionMetadataIsValid(
      widget.initial.copyWith(title: _title.text, description: _description.text, tags: _tags),
    );
    setState(() => _invalid = !valid);
    final DateTime? releaseAt = _releaseAt;
    return valid &&
        (releaseAt == null ||
            releaseAt == widget.initial.releaseAt ||
            releaseTimeProblem(releaseAt, DateTime.now()) == null);
  }

  void useDetails({required String category, required List<String> tags}) {
    setState(() {
      _category = category;
      _tags = List.of(tags);
    });
    _emit();
  }

  void _addTags(String raw) {
    final List<String> next = List<String>.of(_tags);
    for (final String piece in raw.split(',')) {
      final String? tag = normalizeSubmissionTag(piece);
      if (tag != null && !next.contains(tag) && next.length < maxSubmissionTags) next.add(tag);
    }
    setState(() => _tags = next);
    _tagInput.clear();
    _emit();
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool tagsFull = _tags.length >= maxSubmissionTags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_invalid)
          Semantics(
            liveRegion: true,
            child: Text(
              context.l10n.wallMetadataInvalid,
              style: PrismTextStyles.body(context).copyWith(color: colors.error),
            ),
          ),
        Semantics(
          header: true,
          child: Text(
            context.l10n.wallpaperUploadDetailsOptional,
            style: PrismTextStyles.rowTitle(context).copyWith(color: colors.onSurface),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          enabled: widget.enabled && widget.textEnabled,
          maxLength: maxSubmissionTitleLength,
          inputFormatters: [_lineBreaksToSpaces],
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: context.l10n.wallpaperTitle,
            hintText: context.l10n.wallpaperUploadTitleHint,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          enabled: widget.enabled && widget.textEnabled,
          maxLength: maxSubmissionDescriptionLength,
          inputFormatters: [_lineBreaksToSpaces],
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: context.l10n.wallMetadataDescription),
          onChanged: (_) => _emit(),
        ),
        if (widget.showCategory) ...<Widget>[
          Text(
            context.l10n.wallpaperCategory,
            style: PrismTextStyles.rowTitle(context).copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String category in submissionCategories)
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: !widget.enabled || !widget.textEnabled
                      ? null
                      : (_) {
                          setState(() => _category = category);
                          _emit();
                        },
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _tagInput,
          enabled: widget.enabled && widget.textEnabled && !tagsFull,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.wallpaperUploadTags,
            hintText: tagsFull
                ? context.l10n.wallpaperUploadMaxTagsReached(maxSubmissionTags)
                : context.l10n.wallpaperUploadAddTagHint,
            helperText: context.l10n.wallpaperUploadTagsHelp(maxSubmissionTags),
            suffixIcon: PrismIconButton(
              icon: Icons.add,
              tooltip: context.l10n.wallpaperUploadAddTag,
              onPressed: tagsFull || !widget.enabled || !widget.textEnabled
                  ? null
                  : () {
                      PrismHaptics.selection();
                      _addTags(_tagInput.text);
                    },
            ),
          ),
          onChanged: (String value) {
            if (value.contains(',')) _addTags(value);
          },
          onSubmitted: _addTags,
        ),
        if (_tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String tag in _tags)
                InputChip(
                  label: Text(tag),
                  deleteButtonTooltipMessage: context.l10n.wallpaperUploadRemoveTag(tag),
                  onDeleted: !widget.enabled || !widget.textEnabled ? null : () => _removeTag(tag),
                ),
            ],
          ),
        ],
        if (widget.showRelease) ...<Widget>[
          const SizedBox(height: PrismSpace.xl),
          ReleaseTimeRow(
            releaseAt: _releaseAt,
            enabled: widget.enabled,
            allowWhenApproved: !widget.releaseScheduled,
            onChanged: (DateTime? value) {
              PrismHaptics.selection();
              setState(() => _releaseAt = value);
              _emit();
            },
          ),
        ],
      ],
    );
  }
}

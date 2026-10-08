import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:flutter/material.dart';

/// Optional title, category and tags for a wallpaper that goes to review. Every field can stay empty.
class SubmissionMetadataForm extends StatefulWidget {
  const SubmissionMetadataForm({super.key, required this.onChanged, this.initial = const SubmissionMetadata()});

  final SubmissionMetadata initial;
  final ValueChanged<SubmissionMetadata> onChanged;

  @override
  State<SubmissionMetadataForm> createState() => _SubmissionMetadataFormState();
}

class _SubmissionMetadataFormState extends State<SubmissionMetadataForm> {
  late final TextEditingController _title = TextEditingController(text: widget.initial.title);
  final TextEditingController _tagInput = TextEditingController();
  late String _category = widget.initial.category;
  late List<String> _tags = List<String>.of(widget.initial.tags);

  @override
  void dispose() {
    _title.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _emit() =>
      widget.onChanged(SubmissionMetadata(title: _title.text.trim(), category: _category, tags: List.of(_tags)));

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
        Text('Details (optional)', style: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface)),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          maxLength: maxSubmissionTitleLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Title', hintText: 'Name your wallpaper'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        Text('Category', style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            for (final String category in submissionCategories)
              ChoiceChip(
                label: Text(category),
                selected: _category == category,
                onSelected: (_) {
                  setState(() => _category = category);
                  _emit();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tagInput,
          enabled: !tagsFull,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Tags',
            hintText: tagsFull ? 'You added $maxSubmissionTags tags' : 'Add a tag, then tap Done',
            helperText: 'Up to $maxSubmissionTags. Tags help people find your wallpaper.',
            suffixIcon: IconButton(
              tooltip: 'Add tag',
              icon: const Icon(Icons.add),
              onPressed: tagsFull ? null : () => _addTags(_tagInput.text),
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
            runSpacing: 4,
            children: <Widget>[
              for (final String tag in _tags)
                InputChip(
                  label: Text(tag),
                  deleteButtonTooltipMessage: 'Remove tag $tag',
                  onDeleted: () => _removeTag(tag),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

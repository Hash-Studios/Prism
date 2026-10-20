const Set<String> _stopwords = <String>{
  'a',
  'an',
  'and',
  'at',
  'by',
  'for',
  'from',
  'in',
  'is',
  'of',
  'on',
  'the',
  'to',
  'with',
};

final RegExp _separators = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

List<String> searchTermsOf(String text) {
  final List<String> terms = <String>[];
  for (final String word in text.toLowerCase().split(_separators)) {
    if (word.length < 2 || _stopwords.contains(word)) continue;
    final String term = _singular(word);
    if (!terms.contains(term)) terms.add(term);
  }
  return terms;
}

String _singular(String word) {
  if (word.length <= 3) return word;
  if (word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
  if (const <String>['ches', 'shes', 'sses', 'xes', 'zes'].any(word.endsWith)) {
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('s') && !word.endsWith('ss') && !word.endsWith('us') && !word.endsWith('is')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// The tag automatically applied to device-imported contacts.
///
/// It is treated as metadata only: it never links or groups people (no
/// constellation grouping, no shared-tag relationship line/label). It can still
/// be searched and filtered like any other tag.
const String kImportedTag = 'Imported';

bool _isImported(String tag) =>
    tag.trim().toLowerCase() == kImportedTag.toLowerCase();

/// Whether [tag] may be used to link/group people: non-blank and not the
/// special [kImportedTag].
bool isLinkingTag(String tag) => tag.trim().isNotEmpty && !_isImported(tag);

/// The subset of [tags] usable for linking, preserving order.
List<String> linkingTags(Iterable<String> tags) =>
    tags.where(isLinkingTag).toList();

/// The first linking tag — a contact's constellation. Returns '' when the
/// contact has no tags or only the [kImportedTag].
String primaryLinkingTag(List<String> tags) {
  for (final t in tags) {
    if (isLinkingTag(t)) return t;
  }
  return '';
}

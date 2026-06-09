/// How OCR-extracted text is compared between two images.
enum OcrMatchMode {
  /// Token Jaccard — tokens must match exactly (after lowercasing).
  exact,

  /// Substring containment (either direction) plus token overlap / substring
  /// tokens. Handles captures that include timestamps/UI chrome around the
  /// same label text as the reference.
  partial,
}

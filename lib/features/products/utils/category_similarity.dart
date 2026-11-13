import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/category_model.dart';

class CategoryMatch {
  final CategoryModel category;
  final double score;
  final bool isExact;

  const CategoryMatch({
    required this.category,
    required this.score,
    required this.isExact,
  });
}

class CategorySimilarityHelper {
  CategorySimilarityHelper._();

  static String normalizeExact(String text) {
    if (text.isEmpty) return '';
    var s = text.trim().toLowerCase();

    // Remove Arabic diacritics, tatweel, and zero-width characters
    s = s.replaceAll(
      RegExp(r'[\u064B-\u065F\u0670\u0640\u200B-\u200F\uFEFF]'),
      '',
    );

    // Normalize Kurdish/Arabic keyboard character variants
    s = s.replaceAll('ي', 'ی');
    s = s.replaceAll('ى', 'ی');
    s = s.replaceAll('ئ', 'ی');
    s = s.replaceAll('ك', 'ک');
    s = s.replaceAll('ة', 'ە');
    s = s.replaceAll('ه', 'ە');
    s = s.replaceAll('ھ', 'ە');
    s = s.replaceAll('إ', 'ا');
    s = s.replaceAll('أ', 'ا');
    s = s.replaceAll('آ', 'ا');
    s = s.replaceAll('ؤ', 'و');

    const easternArabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(easternArabicDigits[i], '$i');
      s = s.replaceAll(persianDigits[i], '$i');
    }

    s = s.replaceAll(RegExp(r'[\-_/\\()\[\]{}.,:;+*&^%$#@!~`"|]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String normalizeSkeleton(String text) {
    var s = normalizeExact(text);
    if (s.isEmpty) return '';

    // Map near-equivalent Kurdish vowels/consonants often confused in typing
    s = s.replaceAll('ێ', 'ی');
    s = s.replaceAll('ۆ', 'و');
    s = s.replaceAll('ڕ', 'ر');
    s = s.replaceAll('ڵ', 'ل');

    // Collapse consecutive duplicate characters (e.g. وو -> و, یی -> ی, کک -> ک)
    s = s.replaceAll(RegExp(r'(.)\1+'), r'$1');
    return s;
  }

  static double _bigramSimilarity(String s1, String s2) {
    if (s1.length < 2 || s2.length < 2) return 0.0;
    final pairs1 = <String>{};
    for (int i = 0; i < s1.length - 1; i++) {
      pairs1.add(s1.substring(i, i + 2));
    }
    final pairs2 = <String>{};
    for (int i = 0; i < s2.length - 1; i++) {
      pairs2.add(s2.substring(i, i + 2));
    }
    if (pairs1.isEmpty || pairs2.isEmpty) return 0.0;
    final intersection = pairs1.intersection(pairs2).length;
    return (2.0 * intersection) / (pairs1.length + pairs2.length);
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        curr[j + 1] = min(
          min(curr[j] + 1, prev[j + 1] + 1),
          prev[j] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  static double _levenshteinSimilarity(String a, String b) {
    final maxLen = max(a.length, b.length);
    if (maxLen < 4) return 0.0;
    final dist = _levenshtein(a, b);
    final score = 1.0 - (dist / maxLen);
    return score >= 0.65 ? score : 0.0;
  }

  static double _wordSimilarity(String w1, String w2) {
    if (w1 == w2) return 1.0;
    if (w1.length < 2 || w2.length < 2) return 0.0;
    return max(_bigramSimilarity(w1, w2), _levenshteinSimilarity(w1, w2));
  }

  static double calculateSimilarity(String query, String target) {
    final qExact = normalizeExact(query);
    final tExact = normalizeExact(target);

    if (qExact.isEmpty || tExact.isEmpty) return 0.0;
    if (qExact == tExact) return 1.0;

    if (query.trim().length < 2) return 0.0;

    final qSkel = normalizeSkeleton(query);
    final tSkel = normalizeSkeleton(target);

    if (qSkel == tSkel && qSkel.length >= 2) return 0.95;

    if (tExact.contains(qExact) || tSkel.contains(qSkel)) return 0.90;
    if ((qExact.contains(tExact) && tExact.length >= 2) ||
        (qSkel.contains(tSkel) && tSkel.length >= 2)) {
      return 0.85;
    }

    final qTokens = qSkel.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final tTokens = tSkel.split(' ').where((w) => w.trim().isNotEmpty).toList();

    double tokenScore = 0.0;
    if (qTokens.isNotEmpty && tTokens.isNotEmpty) {
      int matchedCount = 0;
      for (final qWord in qTokens) {
        bool found = false;
        for (final tWord in tTokens) {
          if (qWord == tWord) {
            found = true;
            break;
          }
          if (qWord.length >= 3 &&
              tWord.length >= 3 &&
              (tWord.contains(qWord) || qWord.contains(tWord))) {
            found = true;
            break;
          }
          if (_wordSimilarity(qWord, tWord) >= 0.72) {
            found = true;
            break;
          }
        }
        if (found) matchedCount++;
      }
      tokenScore = matchedCount / qTokens.length;
    }

    final qNoSpace = qSkel.replaceAll(' ', '');
    final tNoSpace = tSkel.replaceAll(' ', '');
    final bigramScore = max(
      _bigramSimilarity(qSkel, tSkel),
      _bigramSimilarity(qNoSpace, tNoSpace),
    );
    final levScore = max(
      _levenshteinSimilarity(qSkel, tSkel),
      _levenshteinSimilarity(qNoSpace, tNoSpace),
    );

    return max(tokenScore, max(bigramScore, levScore));
  }

  static List<CategoryMatch> findMatches(
    String query,
    List<CategoryModel> categories, {
    int? excludeCategoryId,
    int maxResults = 4,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final qExact = normalizeExact(trimmed);
    if (qExact.isEmpty) return const [];

    final matches = <CategoryMatch>[];
    for (final cat in categories) {
      if (excludeCategoryId != null && cat.id == excludeCategoryId) {
        continue;
      }
      final tExact = normalizeExact(cat.name);
      if (tExact == qExact) {
        matches.add(CategoryMatch(category: cat, score: 1.0, isExact: true));
        continue;
      }
      if (trimmed.length < 2) continue;

      final score = calculateSimilarity(trimmed, cat.name);
      if (score >= 0.55) {
        matches.add(CategoryMatch(category: cat, score: score, isExact: false));
      }
    }

    matches.sort((a, b) {
      if (a.isExact != b.isExact) return a.isExact ? -1 : 1;
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return a.category.name.compareTo(b.category.name);
    });

    if (matches.length > maxResults) {
      return matches.sublist(0, maxResults);
    }
    return matches;
  }

  static CategoryMatch? findExactMatch(
    String query,
    List<CategoryModel> categories, {
    int? excludeCategoryId,
  }) {
    final qExact = normalizeExact(query);
    if (qExact.isEmpty) return null;

    for (final cat in categories) {
      if (excludeCategoryId != null && cat.id == excludeCategoryId) {
        continue;
      }
      if (normalizeExact(cat.name) == qExact) {
        return CategoryMatch(category: cat, score: 1.0, isExact: true);
      }
    }
    return null;
  }
}

class CategorySimilarityBanner extends StatelessWidget {
  final List<CategoryMatch> matches;
  final Map<int, int>? liveCounts;
  final void Function(CategoryModel category)? onSelectCategory;
  final bool needsConfirmation;
  final String? inlineError;

  const CategorySimilarityBanner({
    super.key,
    required this.matches,
    this.liveCounts,
    this.onSelectCategory,
    this.needsConfirmation = false,
    this.inlineError,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty && (inlineError == null || inlineError!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasExact = matches.any((m) => m.isExact);

    final Color accentColor = hasExact || (inlineError != null && inlineError!.isNotEmpty)
        ? (isDark ? AppColors.dangerDark : AppColors.danger)
        : (isDark ? AppColors.warningDark : AppColors.warning);

    final Color bgColor = accentColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color borderColor = accentColor.withValues(alpha: 0.55);

    final String titleText;
    final String subtitleText;

    if (hasExact) {
      titleText = 'ئەم کاتیگۆرییە پێشتر بوونی هەیە!';
      subtitleText = onSelectCategory != null
          ? 'بۆ ڕێگری لە دووبارەبوونەوە، دەتوانیت کاتیگۆرییە هەبووەکە هەڵبژێریت:'
          : 'بۆ ڕێگری لە دووبارەبوونەوە، تکایە ناوێکی تر بنووسە.';
    } else if (matches.isNotEmpty) {
      titleText = 'ئاگاداری: ${matches.length} کاتیگۆری هاوشێوە دۆزرایەوە!';
      subtitleText = needsConfirmation
          ? 'ئەگەر دڵنیایت ئەمە کاتیگۆرییەکی جیاوازە، دووبارە کرتە لە دوگمەی خوارەوە بکە.'
          : 'بۆ ڕێگری لە دووبارەبوونەوە، دڵنیابە کە مەبەستت ئەمانە نییە:';
    } else {
      titleText = inlineError ?? '';
      subtitleText = '';
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasExact
                      ? Icons.error_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        fontSize: 13,
                      ),
                    ),
                    if (subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: AppTextStyles.caption.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (inlineError != null &&
              inlineError!.isNotEmpty &&
              matches.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              inlineError!,
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.dangerDark : AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...matches.map((m) {
              final count = liveCounts != null
                  ? (liveCounts![m.category.id] ?? 0)
                  : m.category.productsCount;
              final itemAccent = m.isExact
                  ? (isDark ? AppColors.dangerDark : AppColors.danger)
                  : (isDark ? AppColors.warningDark : AppColors.warning);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: m.isExact
                        ? itemAccent.withValues(alpha: 0.5)
                        : theme.colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.category.name,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: itemAccent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  m.isExact ? 'هەمان ناو' : 'هاوشێوەیە',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: itemAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count کاڵا',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onSelectCategory != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(alpha: 0.65),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => onSelectCategory!(m.category),
                        child: Text(
                          'هەڵبژاردن',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

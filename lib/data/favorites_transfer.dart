import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/favorite.dart';

class FavoritesArchiveException implements Exception {
  const FavoritesArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FavoritesArchive {
  const FavoritesArchive._();

  static const format = 'temper-calc-favorites';
  static const version = 1;

  static String encode(List<FavoriteEntry> favorites, {DateTime? exportedAt}) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'favorites': [for (final favorite in favorites) favorite.toJson()],
    });
  }

  static List<FavoriteEntry> decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(_withoutByteOrderMark(source));
    } on FormatException {
      throw const FavoritesArchiveException(
        'The selected file is not valid JSON.',
      );
    }

    if (decoded is! Map<Object?, Object?>) {
      throw const FavoritesArchiveException(
        'The selected file is not a Temper Calc favorites archive.',
      );
    }
    final archive = decoded.cast<String, Object?>();
    if (archive['format'] != format) {
      throw const FavoritesArchiveException(
        'The selected file is not a Temper Calc favorites archive.',
      );
    }
    final archiveVersion = archive['version'];
    if (archiveVersion is! int || archiveVersion != version) {
      throw FavoritesArchiveException(
        'Favorites archive version $archiveVersion is not supported.',
      );
    }
    final values = archive['favorites'];
    if (values is! List<Object?>) {
      throw const FavoritesArchiveException(
        'The favorites archive does not contain a favorites list.',
      );
    }

    return [
      for (var index = 0; index < values.length; index++)
        _decodeFavorite(values[index], index),
    ];
  }

  static FavoriteEntry _decodeFavorite(Object? value, int index) {
    try {
      return FavoriteEntry.fromJson(
        (value! as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } catch (_) {
      throw FavoritesArchiveException(
        'Favorite ${index + 1} in the archive is invalid.',
      );
    }
  }

  static String _withoutByteOrderMark(String value) {
    return value.startsWith('\uFEFF') ? value.substring(1) : value;
  }
}

abstract interface class FavoritesFileTransfer {
  Future<String?> pickArchive();

  Future<bool> saveArchive({
    required String contents,
    required String fileName,
  });
}

class FilePickerFavoritesFileTransfer implements FavoritesFileTransfer {
  const FilePickerFavoritesFileTransfer();

  static const _maximumArchiveBytes = 10 * 1024 * 1024;

  @override
  Future<String?> pickArchive() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import favorites',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null) return null;

    final file = result.files.single;
    if (file.size > _maximumArchiveBytes) {
      throw const FavoritesArchiveException(
        'The selected favorites file is larger than 10 MB.',
      );
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FavoritesArchiveException(
        'The selected favorites file could not be read.',
      );
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const FavoritesArchiveException(
        'The selected favorites file is not valid UTF-8 text.',
      );
    }
  }

  @override
  Future<bool> saveArchive({
    required String contents,
    required String fileName,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export favorites',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(contents)),
    );
    return path != null;
  }
}

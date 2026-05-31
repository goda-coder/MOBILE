import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ImageData {
  ImageData._(this._file, this._bytes);

  final File? _file;
  final Uint8List? _bytes;

  factory ImageData.fromFile(File f) => ImageData._(f, null);
  factory ImageData.fromBytes(Uint8List b) => ImageData._(null, b);

  Future<Uint8List> getBytes() async {
    if (_bytes != null) return _bytes!;
    return await _file!.readAsBytes();
  }

  Future<MultipartFile> toMultipart(String filename) async {
    if (_file != null) return await MultipartFile.fromFile(_file!.path, filename: filename);
    final bytes = _bytes ?? Uint8List(0);
    return MultipartFile.fromBytes(bytes, filename: filename);
  }

  String? get path => _file?.path;
}

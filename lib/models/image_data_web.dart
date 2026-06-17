import 'dart:typed_data';

import 'package:dio/dio.dart';

class ImageData {
  ImageData(this.bytes, {this.name});
  final Uint8List bytes;
  final String? name;

  factory ImageData.fromBytes(Uint8List b, {String? name}) => ImageData(b, name: name);

  Future<Uint8List> getBytes() async => bytes;

  Future<MultipartFile> toMultipart(String filename) async {
    return MultipartFile.fromBytes(bytes, filename: filename);
  }

  String? get path => name;
}

import 'package:dio/dio.dart';

import '../models/api_models.dart';
import 'api_client.dart';

class ChatApi {
  ChatApi(this._c);
  final ApiClient _c;

  Future<List<ChatConversationSummary>> conversations() async {
    try {
      final r = await _c.dio.get('/api/v1/chat/messages');
      final list = (r.data['conversations'] as List).cast<Map<String, dynamic>>();
      return list.map(ChatConversationSummary.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<List<ChatMessage>> messages({String? userId}) async {
    try {
      final r = await _c.dio.get('/api/v1/chat/messages', queryParameters: {
        if (userId != null) 'userId': userId,
      });
      final list = (r.data['messages'] as List).cast<Map<String, dynamic>>();
      return list.map(ChatMessage.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }

  Future<ChatMessage> send({required String content, String? userId}) async {
    try {
      final r = await _c.dio.post('/api/v1/chat/send', data: {
        if (userId != null) 'userId': userId,
        'content': content,
      });
      return ChatMessage.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiClient.toApiError(e);
    }
  }
}

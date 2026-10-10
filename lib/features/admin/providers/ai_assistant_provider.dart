import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

class AiChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isError;
  final String? source;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isError = false,
    this.source,
  });

  bool get isUser => role == 'user';
}

class AiAssistantState {
  final List<AiChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? highlights;

  const AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.highlights,
  });

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? highlights,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      highlights: highlights ?? this.highlights,
    );
  }
}

class AiAssistantNotifier extends StateNotifier<AiAssistantState> {
  final ApiClient _api;

  AiAssistantNotifier(this._api) : super(const AiAssistantState()) {
    _initializeGreeting();
  }

  void _initializeGreeting() {
    final welcomeMessage = AiChatMessage(
      id: 'greeting_${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      content: 'سڵاو بەڕێز خاوەن کار! من یاریدەدەری زیرەکی سیستەمی GARDI ERPـم. دەتوانیت هەر پرسیارێکت لەسەر فرۆشی ئەمڕۆ، قازانجی مانگانە، قەرزی کڕیاران یان بارودۆخی کاڵاکانی ناو کۆگا هەیە لێم بپرسیت.',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [welcomeMessage]);
  }

  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || state.isLoading) return;

    final userMessage = AiChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: trimmedText,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMessage];
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Build history for model context (last 8 messages)
      final historyPayload = state.messages
          .where((m) => !m.isError && m.id != userMessage.id)
          .toList();
      final recentHistory = historyPayload.length > 8
          ? historyPayload.sublist(historyPayload.length - 8)
          : historyPayload;

      final formattedHistory = recentHistory.map((m) => {
        'role': m.role == 'assistant' ? 'assistant' : 'user',
        'content': m.content,
      }).toList();

      final response = await _api.client.post(
        '/ai/assistant/chat',
        data: {
          'message': trimmedText,
          'history': formattedHistory,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final replyText = data['reply']?.toString() ?? 'ببورە، وەڵامێک لە سێرڤەرەوە نەگەڕایەوە.';
        final source = data['source']?.toString();
        Map<String, dynamic>? highlights;
        if (data['context_summary'] is Map) {
          highlights = Map<String, dynamic>.from(data['context_summary'] as Map);
        }

        final assistantMessage = AiChatMessage(
          id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: replyText,
          timestamp: DateTime.now(),
          source: source,
        );

        state = state.copyWith(
          messages: [...state.messages, assistantMessage],
          isLoading: false,
          highlights: highlights,
        );
      } else {
        final errorMsg = response.data?['message']?.toString() ?? 'هەڵەیەک ڕوویدا لە کاتی پەیوەندی کردن بە سێرڤەر.';
        final errMessage = AiChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: '⚠️ $errorMsg',
          timestamp: DateTime.now(),
          isError: true,
        );
        state = state.copyWith(
          messages: [...state.messages, errMessage],
          isLoading: false,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      final parsed = _api.parseError(e);
      final errMessage = AiChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: '⚠️ نەتوانرا وەڵام وەربگیرێت: $parsed',
        timestamp: DateTime.now(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errMessage],
        isLoading: false,
        errorMessage: parsed,
      );
    }
  }

  void clearConversation() {
    state = const AiAssistantState();
    _initializeGreeting();
  }
}

final aiAssistantProvider = StateNotifierProvider<AiAssistantNotifier, AiAssistantState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AiAssistantNotifier(api);
});

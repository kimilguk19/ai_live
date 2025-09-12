import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 마크다운 표시용
import 'package:flutter_dotenv/flutter_dotenv.dart'; // API 키 로드용

void main() async {
  // .env 파일에서 환경 변수를 로드합니다 (선택 사항).
  await dotenv.load(fileName: "assets/.env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Chat Web',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Material 3 사용 권장
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = []; // 사용자 및 모델 메시지를 저장할 목록
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    var apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      // API 키가 없는 경우 처리 (예: 오류 메시지 표시)
      print('API 키를 찾을 수 없습니다.');
      // 앱을 계속 진행하지 못하도록 예외를 던지거나 사용자에게 알릴 수 있습니다.
      throw Exception('API_KEY is not set in .env file');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // 또는 원하는 모델
      apiKey: apiKey,
    );
    _chatSession = _model.startChat();
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      // 메시지 전송 및 응답 스트리밍 (선택 사항)
      // 스트리밍을 사용하면 응답이 생성되는 대로 표시할 수 있습니다.
      final response = await _chatSession.sendMessage(
        Content.text(text),
      );
      final modelResponse = response.text;

      setState(() {
        if (modelResponse != null) {
          _messages.add(Message(text: modelResponse, isUser: false));
        } else {
          _messages.add(Message(text: 'API로부터 응답이 없습니다.', isUser: false));
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(Message(text: '오류: ${e.toString()}', isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
      print('메시지 전송 오류: $e');
    }
  }

  void _scrollToBottom() {
    // 다음 프레임에서 스크롤하여 UI가 업데이트될 시간을 줍니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  message: message.text,
                  isUserMessage: message.isUser,
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: _sendMessage,
                    // 웹에서는 Enter 키로 제출하는 것이 일반적입니다.
                    // 모바일에서는 다음 줄로 이동할 수 있도록 textInputAction을 설정할 수 있습니다.
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_textController.text),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme
                        .of(context)
                        .colorScheme
                        .primary,
                    foregroundColor: Theme
                        .of(context)
                        .colorScheme
                        .onPrimary,
                    padding: const EdgeInsets.all(12.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 메시지를 나타내는 간단한 클래스
class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}

// 채팅 메시지 버블 위젯
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUserMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUserMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery
            .of(context)
            .size
            .width * 0.7),
        // 버블 최대 너비 제한
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isUserMessage
              ? Theme
              .of(context)
              .colorScheme
              .primaryContainer
              : Theme
              .of(context)
              .colorScheme
              .secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        // Markdown 위젯을 사용하여 텍스트를 렌더링합니다.
        // 이렇게 하면 Gemini가 반환하는 마크다운 형식을 올바르게 표시할 수 있습니다.
        child: MarkdownBody(
          data: message,
          selectable: true, // 텍스트를 선택 가능하게 합니다.
        ),
      ),
    );
  }
}
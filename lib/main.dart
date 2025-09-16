import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 외부 파일에 API 키 관리
import 'package:flutter_markdown/flutter_markdown.dart'; // 마크다운 렌더링(화면출력)
import 'package:shared_preferences/shared_preferences.dart'; // 추가
import 'dart:convert'; // JSON 인코딩/디코딩을 위해 추가

// TODO: 여기에 실제 API 키를 입력하세요. (보안상 주의!)
// const String apiKey = 'YOUR_API_KEY';

void main() async {
  // env.js 파일에서 환경(environment) 변수를 로드합니다
  await dotenv.load(fileName: 'assets/env.js');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Gemini Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Material 3 사용 권장
      ),
      home: const ChatScreen(
        title: 'Flutter Gemini Chat',
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = []; // 사용자 및 모델 메시지를 저장할 목록
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isLoading = false;

  // SharedPreferences 키
  static const String _messagesKey = 'chat_messages';

  @override
  void initState() {
    super.initState();
    var apiKey = dotenv.env['GEMINI_API_KEY']; // var형은 null값도 가능하다.
    if(apiKey == null) {
      // API 키가 없는 경우 처리 (예: 오류 메시지 표시)
      print('API 키를 찾을 수 없습니다.');
      // 앱을 계속 진행하지 못하도록 예외를 던지거나 사용자에게 알릴 수 있습니다.
      throw Exception('GEMINI_API_KEY 환경 변수가 설정되지 않았습니다.');
    }
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // 사용할 모델
      apiKey: apiKey,
    );
    _chat = _model.startChat();
    _loadMessages(); // 메시지 불러오기 함수 호출
  }

  // 메시지 불러오기
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString(_messagesKey);
    if (messagesJson != null) {
      try {
        final List<dynamic> decodedMessages = jsonDecode(messagesJson);
        setState(() {
          _messages = decodedMessages
              .map((json) => ChatMessage.fromJson(json))
              .toList()
              .reversed // 최신 메시지가 아래로 가도록 불러온 후 다시 뒤집음
              .toList();
        });
      } catch (e) {
        print('Error loading messages: $e');
        // 오류 처리 (예: 저장된 데이터가 손상된 경우)
      }
    }
  }

  // 메시지 저장하기
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    // UI에서는 최신 메시지가 아래에 있으므로, 저장 시에는 순서를 유지하거나
    // 불러올 때 reversed를 고려해야 합니다. 여기서는 UI 순서대로 저장합니다.
    final List<Map<String, dynamic>> messagesToSave =
    _messages.reversed.map((msg) => msg.toJson()).toList();
    final String messagesJson = jsonEncode(messagesToSave);
    await prefs.setString(_messagesKey, messagesJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [ // 메시지 삭제 버튼 (선택 사항)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true, // 새 메시지가 아래에 표시되도록
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(
                  message: message.text,
                  isUser: message.isUser,
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
            padding: const EdgeInsets.all(8.0),
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
                    ),
                    onSubmitted: _isLoading ? null : _sendMessage,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : () =>
                      _sendMessage(_textController.text),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
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

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _textController.clear();
    await _saveMessages(); // 사용자 메시지 전송 후 즉시 저장

    try {
      final response = await _chat.sendMessage(
        Content.text(text),
      );
      final responseText = response.text;

      if (responseText == null) {
        _showError('모델에서 응답을 받지 못했습니다.');
        return;
      }

      setState(() {
        _messages.insert(0, ChatMessage(text: responseText, isUser: false));
      });
      await _saveMessages(); // 모델 응답 수신 후 저장
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('오류'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            )
          ],
        );
      },
    );
  }
// 메시지 전체 삭제 함수
  Future<void> _clearMessages() async {
    // 삭제 대화상자 표시
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모든 메시지 삭제'),
          content: const Text('모든 메시지를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // 취소
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // 삭제
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if(confirm==true) {
      // SharedPreferences에서 모든 메시지 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_messagesKey);
      setState(() {
        _messages.clear(); // 화면 상태에서 모든 메시지 삭제
      });
    }
  }
}

// 간단한 채팅 메시지 데이터 클래스
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
  // ChatMessage 객체를 JSON 맵으로 변환
  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
  };

  // JSON 맵에서 ChatMessage 객체로 변환
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
  );
}

// 간단한 채팅 말풍선 위젯
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({super.key, required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12.0),
        ),
        //child: Text(message), // 기존 텍스트 위젯을 주석 처리하고 아래코드 사용
        // Markdown 위젯을 사용하여 텍스트를 렌더링합니다.
        // 이렇게 하면 Gemini가 반환하는 마크다운 형식을 올바르게 표시할 수 있습니다.
        child: MarkdownBody(
          data: message,
          selectable: true, // 텍스트를 선택할 수 있도록 설정
        ),
      ),
    );
  }
}
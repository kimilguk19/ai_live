import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 외부 파일에 API 키 관리
import 'package:flutter_markdown/flutter_markdown.dart'; // 마크다운 렌더링(화면출력)

// TODO: 여기에 실제 API 키를 입력하세요. (보안상 주의!)
const String apiKey = String.fromEnvironment('GEMINI_API_KEY');//'YOUR_API_KEY';

void main() { //async
  // .env 파일에서 환경(environment) 변수를 로드합니다
  //await dotenv.load(fileName: 'assets/.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  final List<ChatMessage> _messages = []; // 사용자 및 모델 메시지를 저장할 목록
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    //var apiKey = dotenv.env['GEMINI_API_KEY']; // var형은 null값도 가능하다.
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
}

// 간단한 채팅 메시지 데이터 클래스
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
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
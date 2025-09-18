import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import 'main.dart'; // ChatMessage 클래스를 가져오기 위해 필요할
// import 'package:path_provider/path_provider.dart'; // 모바일용
// import 'package:path/path.dart'; // 모바일용

// ChatMessage 클래스는 기존 코드와 동일하게 사용합니다.
// class ChatMessage { ... }

class ChatDatabase {
  static const String dbName = 'chat_app.db';
  static const String storeName = 'messages';

  // Sembast 데이터베이스 팩토리 (웹용)
  final DatabaseFactory _dbFactory = databaseFactoryWeb;
  Database? _db;

  // 데이터베이스 열기
  //객체가 2번 이상 생성되는 것을 막는 싱글톤 패턴(Singleton Pattern)을 사용
  Future<Database> get database async {
    if (_db == null) { // || !_db!.isOpen 모바일 에서 추가
      _db = await _dbFactory.openDatabase(dbName);
    }
    return _db!;
  }

  // 메시지 저장소 참조
  final _messageStore = intMapStoreFactory.store(storeName);

  // 메시지 추가
  Future<void> insertMessage(ChatMessage message) async {
    final db = await database;
    await _messageStore.add(db, message.toJson());
  }

  // 모든 메시지 불러오기 (최신순 정렬)
  Future<List<ChatMessage>> getAllMessages() async {
    final db = await database;
    // Finder를 사용하여 정렬 (예: 타임스탬프 필드가 있다면 그것으로 정렬)
    // 여기서는 간단히 저장된 순서대로 불러오고 앱 로직에서 reverse 합니다.
    // 또는 Sembast에서 직접 정렬하려면 ChatMessage에 timestamp 필드 추가 고려
    final snapshots = await _messageStore.find(db);
    return snapshots.map((snapshot) {
      return ChatMessage.fromJson(snapshot.value);
    }).toList();
  }

  // 모든 메시지 삭제
  Future<void> deleteAllMessages() async {
    final db = await database;
    await _messageStore.delete(db);
  }

}
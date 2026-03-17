import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/add_medicine_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String serverUrl = 'https://ornamented-jeramy-achromatically.ngrok-free.app';
const String userId = 'user_001';

void main() => runApp(MaterialApp(  //
  home: const PlantCareApp(),
  debugShowCheckedModeBanner: false,

  // 전역 테마 설정
  theme: ThemeData(
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(fontSize: 22),
      bodyMedium: TextStyle(fontSize: 20),
      labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 60),
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 60),
        textStyle: const TextStyle(fontSize:20, fontWeight: FontWeight.bold),
      ),
    ),
    appBarTheme: const AppBarTheme(
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  ),
));

// 전역 약 리스트
class GlobalMedicineList {
  static List<Medicine> medicines = [];
  static List<String> history = [];

  static int plantLevel = 1;
  static int todayMedicine = 0;
  static int totalMedicine = 0;

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = medicines.map((m) => {
      'name': m.name,
      'hour': m.alarmTime.hour,
      'minute': m.alarmTime.minute,
      'beaconId': m.beaconId,
      'isTaken': m.isTaken,
    }).toList();

    await prefs.setString('medicines', jsonEncode(jsonList));
    await prefs.setStringList('medicine_history', history);
    await prefs.setInt('plantLevel', plantLevel);
    await prefs.setInt('todayMedicine', todayMedicine);
    await prefs.setInt('totalMedicine', totalMedicine);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('medicines');

    if (jsonStr != null) {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      medicines = jsonList.map((json) => Medicine(
        name: json['name'],
        alarmTime: TimeOfDay(
          hour: json['hour'],
          minute: json['minute'],
        ),
        beaconId: json['beaconId'] ?? '',
        isTaken: json['isTaken'] ?? false,
      )).toList();
    }

    history = prefs.getStringList('medicine_history') ?? [];
    plantLevel = prefs.getInt('plantLevel') ?? 1;
    todayMedicine = prefs.getInt('todayMedicine') ?? 0;
    totalMedicine = prefs.getInt('totalMedicine') ?? 0;
  }
}

class MedicationManager extends ChangeNotifier {
  final List<Medicine> _medicines = [];

  List<Medicine> get medicines => _medicines;

  void addMedicine(Medicine med) {
    _medicines.add(med);
    notifyListeners();
  }

  void removeMedicine(String name) {
    _medicines.removeWhere((m) => m.name == name);
    notifyListeners();
  }

  void toggleTaken(String name) {
    final med = _medicines.firstWhere((m) => m.name == name);
    med.isTaken = !med.isTaken;
    notifyListeners();
  }
}

class Medicine {
  final String name;
  final TimeOfDay alarmTime;
  final String beaconId;
  bool isTaken;

  Medicine({
    required this.name,
    required this.alarmTime,
    this.beaconId = "",
    this.isTaken = false,
  });
}

class PlantCareApp extends StatefulWidget {
  const PlantCareApp({super.key});

  @override
  State<PlantCareApp> createState() => _PlantCareAppState();
}

class _PlantCareAppState extends State<PlantCareApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.green,
        iconSize: 36,
        selectedFontSize: 20,
        unselectedFontSize: 18,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.eco),
            label: '내 식물',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: '대화하기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '복약 기록',
          ),
        ],
      ),
    );
  }
}

// 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    await GlobalMedicineList.load();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int plantLevel = GlobalMedicineList.plantLevel;
    int totalMedicine = GlobalMedicineList.totalMedicine;
    int todayMedicine = GlobalMedicineList.todayMedicine;

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('내 반려 식물'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 화분 카드
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('🌱 나의 건강나무', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(
                    _getPlantEmoji(plantLevel),
                    style: const TextStyle(fontSize: 120),
                  ),
                  const SizedBox(height: 10),
                  Text('레벨 $plantLevel', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: (totalMedicine % 10) / 10,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.green,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 10),
                  Text('다음 레벨까지 ${10 - (totalMedicine % 10)}번 남았어요!'),
                ],
              ),
            ),

            // 등록된 약 목록
            if (GlobalMedicineList.medicines.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medication, color: Colors.green.shade700, size: 28),
                        const SizedBox(width: 10),
                        const Text('등록된 약', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ...GlobalMedicineList.medicines.map((med) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medication, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  '${med.alarmTime.hour.toString().padLeft(2, '0')}:${med.alarmTime.minute.toString().padLeft(2, '0')}',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(midWidth: 60, minHeight: 60),
                            padding: EdgeInsets.zero,
                            iconSize: 36,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              setState(() {
                                GlobalMedicineList.medicines.remove(med);
                                GlobalMedicineList.medicines = GlobalMedicineList.medicines;
                              });
                              await GlobalMedicineList.save();
                            },
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 복약 현황 카드
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.green.shade700, size: 28),
                      const SizedBox(width: 10),
                      const Text('오늘의 복약 현황', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusCard(
                        '오늘 복약',
                        '$todayMedicine회',
                        Icons.medication,
                        Colors.blue,
                      ),
                      _buildStatusCard(
                        '총 복약',
                        '$totalMedicine회',
                        Icons.favorite,
                        Colors.red,
                      ),
                      _buildStatusCard(
                        '연속 일수',
                        '7일',
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 약 등록 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddMedicineScreen(),
                    ),
                  );

                  if (result != null && result is Medicine) {
                    setState(() {
                      GlobalMedicineList.medicines.add(result);
                      GlobalMedicineList.medicines = GlobalMedicineList.medicines;
                    });
                    await GlobalMedicineList.save();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 24),
                    SizedBox(width: 10),
                    Text('새 약 등록하기'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 약 먹었어요 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showMedicineDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle, size: 24),
                    SizedBox(width: 10),
                    Text('약 먹었어요!'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _getPlantEmoji(int level) {
    switch (level) {
      case 1:
        return '🌱';
      case 2:
        return '🌿';
      case 3:
        return '🪴';
      case 4:
        return '🌳';
      case 5:
        return '🌲';
      default:
        return '🌱';
    }
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  void _showMedicineDialog(BuildContext context) {
    // 단일 String 대신 선택된 약 이름들을 담을 '리스트'를 선언합니다.
    List<String> selectedMedicineNames = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('어떤 약을 드셨나요? (중복 선택 가능)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (GlobalMedicineList.medicines.isEmpty)
                    const Text('등록된 약이 없습니다.\n먼저 약을 등록해주세요.', style: TextStyle(fontSize: 20))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GlobalMedicineList.medicines.map((med) {
                        // 현재 약이 선택된 리스트에 포함되어 있는지 확인
                        final isSelected = selectedMedicineNames.contains(med.name);

                        return FilterChip(
                          label: Text(med.name, style: const TextStyle(fontSize: 22)),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          selected: isSelected,
                          selectedColor: Colors.green.shade200,
                          checkmarkColor: Colors.green.shade900,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                // 선택 시 리스트에 추가
                                selectedMedicineNames.add(med.name);
                              } else {
                                // 해제 시 리스트에서 제거
                                selectedMedicineNames.remove(med.name);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(fontSize: 20)),
                ),
                ElevatedButton(
                  // 하나라도 선택되어야 버튼 활성화
                  onPressed: selectedMedicineNames.isEmpty
                      ? null
                      : () async {
                    setState(() {
                      // 1. 선택한 약의 개수만큼 카운트 증가
                      int count = selectedMedicineNames.length;
                      GlobalMedicineList.todayMedicine += count;
                      GlobalMedicineList.totalMedicine += count;

                      String timestamp = DateTime.now().toString();

                      // 2. 선택된 모든 약을 각각 기록에 추가
                      for (String name in selectedMedicineNames) {
                        GlobalMedicineList.history.insert(0, "$name|$timestamp");
                      }

                      // 3. 레벨업 로직 (10번마다 레벨업)
                      GlobalMedicineList.plantLevel = (GlobalMedicineList.totalMedicine ~/ 10) + 1;
                      if (GlobalMedicineList.plantLevel > 5) GlobalMedicineList.plantLevel = 5;
                    });

                    await GlobalMedicineList.save();
                    Navigator.pop(context);
                    _showGrowthAnimation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text('${selectedMedicineNames.length}개 기록하기', style: const TextStyle(fontSize: 20)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGrowthAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            const Text('식물이 쑥쑥 자라고 있어요!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('건강 관리 잘하고 계세요!', style: TextStyle(fontSize: 20)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

// 대화하기 화면 - 서버 연동 버전
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _wordsSpoken = "마이크 버튼을 눌러 말씀해주세요";
  final List<ChatMessage> _messages = [];
  bool _isRecording = false;
  bool _isLoading = false; // ⭐ AI 답변 대기 중
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _messages.add(ChatMessage(
      text: "안녕하세요! 저는 새싹이예요 🌱 오늘 기분은 어떠세요?",
      isUser: false,
      time: DateTime.now(),
    ));
  }

  void _initSpeech() async {
    PermissionStatus status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) => print('음성 인식 오류: $error'),
        onStatus: (status) => print('음성 인식 상태: $status'),
      );
      if (mounted) {
       setState(() {});
      }
    }
  }

  void _toggleRecording() async {
    if (!_speechEnabled) {
      print('음성 인식이 활성화되지 않았습니다');
      return;
    }

    if (_isRecording) {
      HapticFeedback.lightImpact();
      await _speechToText.stop();
      if (mounted)
      {
        setState(() {
        _isRecording = false;
       });
      }
      

      if (_wordsSpoken.isNotEmpty &&
          _wordsSpoken != "마이크 버튼을 눌러 말씀해주세요") {
        await _sendMessage(_wordsSpoken);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isRecording = true;
        _wordsSpoken = "";
      });

      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
           });
          }
        },
        localeId: "ko_KR",
        listenMode: ListenMode.confirmation,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        time: DateTime.now(),
      ));
      _isLoading = true; // 로딩 시작
      _wordsSpoken = "마이크 버튼을 눌러 말씀해주세요";
    });

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/chat'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'user_id': userId,
          'message': text,
        }),
      ).timeout(const Duration(seconds: 30));

      if(!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add(ChatMessage(
            text: data['reply'],
            isUser: false,
            time: DateTime.now(),
          ));
        });
      } else {
        _addErrorMessage();
      }
    } catch (e) {
      print('서버 에러: $e');
      if (mounted) _addErrorMessage();
      _addErrorMessage();
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addErrorMessage() {
    if (!mounted) return;
    
    setState(() {
      _messages.add(ChatMessage(
        text: '새싹이가 잠시 자리를 비웠어요. 서버가 켜져 있는지 확인해주세요 🌱',
        isUser: false,
        time: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('🌱 새싹이와 대화하기'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length + (_isLoading ? 1 : 0), // ⭐ 로딩 버블 추가
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return _buildLoadingBubble(); // ⭐ 로딩 표시
                }
                final msg = _messages[_messages.length - 1 - (index - (_isLoading ? 1 : 0))];
                return _buildChatBubble(msg);
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isRecording
                          ? Colors.red
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                  ),
                  child: Row(
                    children: [
                      _isRecording
                          ? AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Icon(
                            Icons.graphic_eq,
                            color: Colors.red,
                            size: 24 + (_animationController.value * 8),
                          );
                        },
                      )
                          : Icon(
                        Icons.mic_none,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isRecording
                                  ? "🎤 듣고 있어요..."
                                  : (_isLoading ? "새싹이가 생각 중..." : "준비 완료"), // 로딩 상태 표시
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _wordsSpoken.isEmpty
                                  ? "마이크 버튼을 눌러 말씀해주세요"
                                  : _wordsSpoken,
                                  style: const TextStyle(fontSize:20 ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                InkWell(
                  onTap: _isLoading ? null : _toggleRecording, // 로딩 중엔 비활성화
                  borderRadius: BorderRadius.circular(50),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isLoading
                            ? [Colors.grey.shade400, Colors.grey.shade600] // 로딩 중 회색
                            : _isRecording
                            ? [Colors.red.shade400, Colors.red.shade700]
                            : [Colors.green.shade400, Colors.green.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isRecording
                              ? Colors.red.withOpacity(0.5)
                              : Colors.green.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: _isRecording ? 15 : 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isLoading
                          ? Icons.hourglass_empty // 로딩 아이콘
                          : (_isRecording ? Icons.stop : Icons.mic),
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isLoading
                        ? '🌱 새싹이가 답변 중...'
                        : (_isRecording
                        ? '🛑 버튼을 다시 눌러 녹음 종료'
                        : '🎤 버튼을 눌러 녹음 시작'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 20,
            color: message.isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // 로딩 버블 추가
  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '새싹이가 생각 중... 🌱',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _animationController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

// 복약 기록 화면
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    // 저장된 기록 가져오기
    final historyData = GlobalMedicineList.history;

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('복약 기록'),
        backgroundColor: Colors.green,
      ),
      body: historyData.isEmpty
          ? const Center(child: Text("아직 복약 기록이 없어요. 🌱", style: TextStyle(fontSize: 24)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: historyData.length,
        itemBuilder: (context, index) {
          // 저장된 데이터 파싱 ("약이름|2026-...")
          final parts = historyData[index].split('|');
          final name = parts[0];
          final date = DateTime.parse(parts[1]);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade300, blurRadius: 5, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.medication, color: Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                      const SizedBox(height:6),
                      Text('${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}
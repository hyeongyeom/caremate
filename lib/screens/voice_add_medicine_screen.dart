import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../main.dart';

class VoiceAddMedicineScreen extends StatefulWidget {
  const VoiceAddMedicineScreen({super.key});

  @override
  State<VoiceAddMedicineScreen> createState() => _VoiceAddMedicineScreenState();
}

class _VoiceAddMedicineScreenState extends State<VoiceAddMedicineScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  String _currentStep = 'intro'; // intro, type, time, frequency, days_supply, confirm

  // 수집된 정보
  String _medicineType = ''; // 혈압약, 당뇨약 등
  TimeOfDay? _selectedTime;
  String _frequency = ''; // 매일, 평일
  int _daysSupply = 0; // 며칠치 약인지 (예: 30일)

  // UI 표시용
  String _displayText = '시작하려면 마이크 버튼을 눌러주세요';
  String _spokenText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5); // 천천히 읽기
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    setState(() {
      _displayText = text;
    });
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    if (!_isListening && _speech.isAvailable) {
      setState(() {
        _isListening = true;
        _spokenText = '듣고 있습니다...';
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'ko_KR',
      );

      // 3초 후 자동으로 인식 종료하고 다음 단계로
      Future.delayed(const Duration(seconds: 3), () {
        if (_isListening) {
          _stopListening();
        }
      });
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });

      // 인식된 텍스트 처리
      if (_spokenText.isNotEmpty && _spokenText != '듣고 있습니다...') {
        _processSpokenText(_spokenText);
      }
    }
  }

  void _processSpokenText(String text) {
    print('Recognized: $text, Current step: $_currentStep');

    switch (_currentStep) {
      case 'intro':
      // 시작 단계
        _currentStep = 'type';
        _speak('어떤 약을 드시나요? 예를 들어 혈압약, 당뇨약, 소화제 등을 말씀해주세요');
        break;

      case 'type':
      // 약 종류 입력
        setState(() {
          _medicineType = text;
        });
        _currentStep = 'time';
        _speak('$_medicineType 네. 언제 드시나요? 예를 들어 아침 8시, 저녁 6시처럼 말씀해주세요');
        break;

      case 'time':
      // 시간 입력
        TimeOfDay? parsedTime = _parseTime(text);
        if (parsedTime != null) {
          setState(() {
            _selectedTime = parsedTime;
          });
          _currentStep = 'frequency';
          _speak('${parsedTime.hour}시 ${parsedTime.minute}분 네. 매일 드시나요? 네 또는 아니오로 답해주세요');
        } else {
          _speak('시간을 잘 이해하지 못했어요. 다시 말씀해주세요. 예를 들어 아침 8시라고 말씀해주세요');
        }
        break;

      case 'frequency':
      // 매일/평일 입력
        if (text.contains('네') || text.contains('예') || text.contains('매일')) {
          setState(() {
            _frequency = '매일';
          });
        } else {
          setState(() {
            _frequency = '평일';
          });
        }
        _currentStep = 'days_supply';
        _speak('알겠습니다. 몇 일치 약이 있으신가요? 예를 들어 30일, 60일처럼 말씀해주세요');
        break;

      case 'days_supply':
      // 약 일수 입력
        int? days = _parseDays(text);
        if (days != null) {
          setState(() {
            _daysSupply = days;
          });
          _currentStep = 'confirm';
          _showConfirmation();
        } else {
          _speak('일수를 잘 이해하지 못했어요. 다시 말씀해주세요. 예를 들어 30일이라고 말씀해주세요');
        }
        break;
    }
  }

  TimeOfDay? _parseTime(String text) {
    // 간단한 시간 파싱
    try {
      // "아침 8시", "저녁 6시", "8시", "오후 3시" 등 처리
      int hour = 8; // 기본값

      if (text.contains('1시') || text.contains('한시')) {
        hour = 1;
      } else if (text.contains('2시') || text.contains('두시')) hour = 2;
      else if (text.contains('3시') || text.contains('세시')) hour = 3;
      else if (text.contains('4시') || text.contains('네시')) hour = 4;
      else if (text.contains('5시') || text.contains('다섯')) hour = 5;
      else if (text.contains('6시') || text.contains('여섯')) hour = 6;
      else if (text.contains('7시') || text.contains('일곱')) hour = 7;
      else if (text.contains('8시') || text.contains('여덟')) hour = 8;
      else if (text.contains('9시') || text.contains('아홉')) hour = 9;
      else if (text.contains('10시') || text.contains('열시')) hour = 10;
      else if (text.contains('11시') || text.contains('열한')) hour = 11;
      else if (text.contains('12시') || text.contains('열두')) hour = 12;

      // 오후 처리
      if (text.contains('오후') || text.contains('저녁')) {
        if (hour < 12) hour += 12;
      }
      // 아침 처리
      if (text.contains('아침')) {
        if (hour >= 12) hour -= 12;
      }

      return TimeOfDay(hour: hour, minute: 0);
    } catch (e) {
      return null;
    }
  }

  int? _parseDays(String text) {
    // 약 일수 파싱 ("30일", "60일", "삼십일" 등)
    try {
      // 숫자 추출
      if (text.contains('30') || text.contains('삼십')) return 30;
      if (text.contains('60') || text.contains('육십')) return 60;
      if (text.contains('90') || text.contains('구십')) return 90;
      if (text.contains('7') || text.contains('일주일') || text.contains('7일')) return 7;
      if (text.contains('14') || text.contains('2주') || text.contains('이주일')) return 14;
      if (text.contains('한달') || text.contains('1달')) return 30;
      if (text.contains('두달') || text.contains('2달')) return 60;

      // 숫자만 있는 경우
      final RegExp numberRegex = RegExp(r'\d+');
      final match = numberRegex.firstMatch(text);
      if (match != null) {
        return int.parse(match.group(0)!);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _showConfirmation() {
    String timeStr = _selectedTime != null
        ? '${_selectedTime!.hour}시 ${_selectedTime!.minute}분'
        : '시간 미설정';

    setState(() {
      _displayText = '확인해주세요:\n\n'
          '약: $_medicineType\n'
          '시간: $timeStr\n'
          '빈도: $_frequency\n'
          '약 일수: $_daysSupply일\n\n'
          '저장하시겠어요?';
    });

    _speak('$_medicineType, $timeStr, $_frequency, $_daysSupply일치. 이대로 저장하시겠어요? 네 또는 아니오로 답해주세요');
  }

  void _saveMedicine() {
    if (_selectedTime == null) {
      _speak('시간을 설정하지 않았습니다. 다시 시도해주세요');
      return;
    }

    final medicine = Medicine(
      name: '$_medicineType ($_daysSupply일분)',
      alarmTime: _selectedTime!,
    );

    GlobalMedicineList.medicines.add(medicine);
    GlobalMedicineList.save();

    _speak('$_medicineType이 저장되었습니다. 매일 ${_selectedTime!.hour}시에 알려드릴게요. $_daysSupply일 후에는 약을 다시 받으러 가세요');

    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pop(context, medicine);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('음성으로 약 등록'),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 안내 텍스트
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.mic,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 인식된 텍스트 표시
            if (_spokenText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '당신: $_spokenText',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // 마이크 버튼
            if (_currentStep != 'confirm')
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.red : Colors.green,
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? Colors.red : Colors.green).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop : Icons.mic,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isListening ? '듣고 있습니다...' : '눌러서 말하기',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            // 확인 단계의 버튼들
            if (_currentStep == 'confirm')
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _currentStep = 'intro';
                          _medicineType = '';
                          _selectedTime = null;
                          _frequency = '';
                          _daysSupply = 0;
                          _speak('처음부터 다시 시작할게요. 어떤 약을 드시나요?');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: const Text(
                          '다시하기',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveMedicine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: const Text(
                          '저장하기',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
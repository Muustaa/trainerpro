import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/exercise_set.dart';
import '../models/training_session.dart';
import '../theme/app_theme.dart';
import '../widgets/plate_calculator_dialog.dart';
import '../widgets/animated_widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../data/exercise_images.dart';
import 'auth_screen.dart';

class MainScreen extends StatefulWidget {
  final AppTheme currentTheme;
  final VoidCallback onToggleTheme;
  const MainScreen({
    super.key,
    required this.currentTheme,
    required this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Navigation
  int _activeTab = 0;
  late PageController _pageController;

  // Animations
  late AnimationController _headerAnimController;
  late AnimationController _fabAnimController;
  late AnimationController _glowController;

  // State
  bool _loading = true;
  bool _isSessionActive = false;
  bool _showSettings = false;
  bool _isFirstTime = false;
  bool _hasDraft = false;

  // History Carousel Controller (V8)
  final PageController _historyPageController = PageController();

  // Stats Toggle
  bool _statsUseFirstSet =
      false; // False = Mejor serie (Todas), True = Primera serie

  // Timer
  Timer? _restTimer;
  int _secondsLeft = 180;
  int _defaultRestSeconds = 180;
  bool _showTimer = false;
  bool _isTimerExpanded = false;
  int _totalRestSeconds = 180;

  // Timer position (draggable)
  double _timerPosX = -1;
  double _timerPosY = -1;

  // Training start time
  DateTime? _workoutStartTime;

  // Chatbot state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _chatLoading = false;
  final String _geminiApiKey = '***';
  bool _useCustomApiKey = false;
  String _customApiKey = '';

  // Multi-conversation state
  List<Map<String, dynamic>> _chatConversations = [];
  String _currentConversationId = '';

  // Nav order
  final List<Map<String, dynamic>> _navItems = [
    {'icon': 'play', 'label': 'HOY'},
    {'icon': 'calendar', 'label': 'HISTORIAL'},
    {'icon': 'trendingUp', 'label': 'PROGRESO'},
    {'icon': 'wrench', 'label': 'TOOLS'},
    {'icon': 'messageCircle', 'label': 'CHAT'},
  ];

  // Data
  List<TrainingSession> _sessions = [];
  List<String> _userGroups = [];
  Map<String, Map<String, dynamic>> _customTemplates = {};

  // Static Data
  final List<String> _globalExerciseList = [
    // PECHO
    'PRESS BANCA',
    'PRESS BANCA CON MANCUERNA',
    'PRESS INCLINADO',
    'PRESS INCLINADO MANCUERNA',
    'PRESS DECLINADO',
    'APERTURAS',
    'APERTURAS EN MÁQUINA',
    'APERTURAS CABLE',
    'PULL OVER',
    'PRESS BANCA HALTEROFILIA',
    'PRESS BANCA PAUSA',
    'PRESS BANCA AGARRE ABIERTO',
    'PRESS BANCA AGARRE ESTRECHO',
    'PRESS INCLINADO POLEA', 'CROSS OVER', 'PEC DECK',
    // ESPALDA
    'JALÓN AL PECHO',
    'JALÓN AL PECHO ABIERTO',
    'JALÓN AL PECHO CERRADO',
    'JALÓN AL PECHO NEUTRO',
    'REMO CON BARRA',
    'REMO CON MANCUERNA',
    'REMO EN T',
    'REMO POLEA BAJA',
    'REMO INVERTIDO',
    'REMO MÁQUINA',
    'REMO CERRADO',
    'DOMINADAS',
    'DOMINADAS TRAS NUCA',
    'DOMINADAS SUPINAS',
    'REMO SERRATO',
    'PULL OVER POLEA',
    'REMO SENTADO POLEA',
    'REMADOR',
    'REMO PENDLAY',
    // HOMBROS
    'PRESS MILITAR',
    'PRESS MILITAR MÁQUINA',
    'PRESS MILITAR MANCUERNA',
    'PRESS ARNOLD',
    'LATERALES', 'LATERALES MAQUINA', 'LATERALES CABLE', 'LATERALES POSTERIOR',
    'FRONTALES', 'ELEVACIONES LATERALES', 'FACE PULL', 'PÁJARO',
    'PRESS MILITAR SENTADO', 'PRESS MILITAR HALTEROFILIA', 'UPRIGHT ROW',
    // BÍCEPS
    'CURL DE BÍCEPS',
    'CURL MARTILLO',
    'CURL POLEA',
    'CURL POLEA ALTERNADO',
    'CURL BANCOS',
    'CURL INCLINADO',
    'CURL SENTADO',
    'CURL CONCENTRADO',
    'CURL SCOTT',
    'CURL MANCUERNA ALTERNADO',
    'CURL BARRA RECTA', 'CURL BARRA Z', 'PREACHER CURL', 'CURL BÍCEPS POLEA',
    // TRÍCEPS
    'EXTENSIÓN DE TRÍCEPS',
    'EXTENSIÓN TRÍCEPS POLEA',
    'EXTENSIÓN TRÍCEPS CABLE',
    'EXTENSIÓN TRIC UNILAT',
    'PRESS FRANCES',
    'FONDOS DE TRÍCEPS',
    'SKULL CRUSHERS',
    'EXTENSIÓN POLEA CORDURA',
    'KICKBACKS', 'PRESSESS TRÍCEPS', 'EXTENSIÓN MÁQUINA',
    // PIERNAS - CUÁDRICEPS
    'SENTADILLA', 'SENTADILLA FRONTAL', 'SENTADILLA HACK', 'SENTADILLA BULGARA',
    'SENTADILLA GOBLET',
    'SENTADILLA SMITH',
    'SENTADILLA A UNA PIERNA',
    'PRESS DE PIERNAS',
    'EXTENSIÓN DE CUÁDRICEPS',
    'EXTENSIÓN MÁQUINA',
    'SENTADILLA PROFUNDA',
    'PENCHA',
    // PIERNAS - ISQUIOS
    'PESO MUERTO',
    'PESO MUERTO RUMANO',
    'PESO MUERTO SUMO',
    'PESO MUERTO CON MANCUERNA',
    'FEMORAL TUMBADO', 'FEMORAL SENTADO', 'FEMORAL DE PIE', 'NORDIC CURL',
    'BUCHILLAS', 'HIP THRUST', 'PESO MUERTO STIFF', 'SENTADILLA RUMANA',
    // PIERNAS - GLÚTEOS
    'HIP THRUST BARRA',
    'HIP THRUST MÁQUINA',
    'PATADA DE GLÚTEO',
    'ABDUCCIÓN CADERA',
    'GLUTE BRIDGE',
    'STEP UP',
    'ZANCADAS',
    'ZANCADAS CAMINANDO',
    'ZANCADAS BULGARAS',
    'ZANCADAS INVERTIDAS', 'SENTADILLA SUMO',
    // PIERNAS - PANTORRILLAS
    'ELEVACIÓN DE PANTORRILLAS',
    'ELEVACIÓN PANTORRILLAS MÁQUINA',
    'ELEVACIÓN PANTORRILLAS SMITH',
    'ELEVACIÓN PANTORRILLAS SENTADO', 'PANTORRILLAS UNA PIERNA',
    // PIERNAS - ADUCTORES/ABDUCTORES
    'ADUCTOR', 'ABDUCTOR', 'ADUCTOR MÁQUINA', 'ABDUCTOR MÁQUINA',
    // CENTRO
    'CRUNCH',
    'CRUNCH EN MÁQUINA',
    'PLANCHAS',
    'PLANCHAS LATERALES',
    'RUSSIAN TWIST',
    'LUMBAR EN MÁQUINA',
    'LUMBAR Hiperextension',
    'AB wheel',
    'LEG RAISE',
    'HOLLOW BODY',
    'FRENCH PRESS', 'MOUNTAIN CLIMBERS', 'DEAD BUG', 'BIRD DOG', 'RKC PLANK',
    // CARDIO Y OTROS
    'HAKA', 'SENTADILLA ISOMÉTRICA', 'BURPEES', 'BOX JUMPS', 'KETTLEBELL SWING',
    'BATTLE ROPES', 'SLED PUSH', 'FARMERS WALK', 'TRINEO',
  ];

  Map<String, List<String>> _archivedExercises = {};
  Map<String, List<String>> _exerciseDb = {};
  String _plannerMode = 'sequential';
  Map<String, String> _weeklyPlan = {
    'Lunes': 'DESCANSO',
    'Martes': 'DESCANSO',
    'Miércoles': 'DESCANSO',
    'Jueves': 'DESCANSO',
    'Viernes': 'DESCANSO',
    'Sábado': 'DESCANSO',
    'Domingo': 'DESCANSO',
  };

  // Session State
  String _activeWorkoutType = '';
  List<ExerciseSet> _currentSessionExercises = [];
  String _selectedExercise = '';
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _repsCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  // Adjustment State
  // String _adjustmentType = 'MANTENER'; // REMOVED
  double _adjustmentIncrement = 0.0; // The increment selected for next time
  int _historyCarouselIndex = 0; // Track carousel position

  // --- GETTERS ESTÉTICOS ---
  Color get _accentColor {
    switch (widget.currentTheme) {
      case AppTheme.cyberNeon:
        return const Color(0xFF00F5FF);
      case AppTheme.crimsonBlood:
        return const Color(0xFFFF3131);
      case AppTheme.toxicGreen:
        return const Color(0xFF22C55E);
      case AppTheme.solarFlare:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  // Pinned Notes State
  Map<String, String> _pinnedNotes = {};

  // Settings State
  bool _enableVibration = true;
  bool _enableSound = true;
  bool _enableNotifications = false;
  String _timerSoundType = 'alarm';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Phase 2: Pinned Notes
  Map<String, String> _exerciseNotes = {};

  Color get _cardColor => Colors.transparent;

  // --- CICLO DE VIDA ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();

    // Initialize animation controllers
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _headerAnimController.forward();
    _fabAnimController.forward();

    _loadData();
    _loadNotes(); // Load notes
    _initNotifications();
    _checkPersistentTimer();
    _loadChatHistory();
    _loadDraft(); // Restaura el entrenamiento en curso si la app se cerró
    _loadDataFromFirestore();
    _retryPendingSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _noteCtrl.dispose();
    _historyPageController.dispose();
    _headerAnimController.dispose();
    _fabAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_isSessionActive) {
        _saveDraft();
      }
    } else if (state == AppLifecycleState.resumed) {
      _checkPersistentTimer();
      _retryPendingSync();
    }
  }

  // --- GESTIÓN DE DATOS ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      try {
        final sessionsStr = prefs.getString('trainer_sessions');
        if (sessionsStr != null) {
          _sessions = (jsonDecode(sessionsStr) as List)
              .map((s) => TrainingSession.fromJson(s))
              .toList();
        } else {
          _sessions = [];
        }
      } catch (e) {
        _sessions = [];
      }

      try {
        final templatesStr = prefs.getString('trainer_custom_templates');
        if (templatesStr != null) {
          _customTemplates = Map<String, Map<String, dynamic>>.from(
            jsonDecode(templatesStr).map(
              (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
            ),
          );
        }

        final configStr = prefs.getString('trainer_config');
        if (configStr != null) {
          final config = jsonDecode(configStr);
          _userGroups = List<String>.from(config['groups'] ?? []);
          _exerciseDb = (config['exercises'] as Map).map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v)),
          );
          _archivedExercises = (config['archivedExercises'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v)),
          );
          _plannerMode = config['plannerMode'] ?? 'sequential';
          _weeklyPlan = Map<String, String>.from(
            config['weeklyPlan'] ?? _weeklyPlan,
          );
          _defaultRestSeconds = config['defaultRestSeconds'] ?? 180;

          if (config.containsKey('pinnedNotes')) {
            _pinnedNotes = Map<String, String>.from(config['pinnedNotes']);
          }

          _enableVibration = config['enableVibration'] ?? true;
          _enableSound = config['enableSound'] ?? true;
          _enableNotifications = config['enableNotifications'] ?? false;
          _timerSoundType = config['timerSoundType'] ?? 'alarm';
          _useCustomApiKey = config['useCustomApiKey'] ?? false;
          _customApiKey = config['customApiKey'] ?? '';

          if (_userGroups.isEmpty) {
            _isFirstTime = true;
          }
        } else {
          _isFirstTime = true;
        }
      } catch (e) {
        _isFirstTime = true;
      }
    });

    _checkDraftStatus();
    _loading = false;
  }

  // --- NOTES LOGIC ---
  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('trainer_notes');
    if (notesJson != null) {
      if (mounted) {
        setState(() {
          _exerciseNotes = Map<String, String>.from(json.decode(notesJson));
        });
      }
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trainer_notes', json.encode(_exerciseNotes));
  }

  // --- CHAT HISTORY ---
  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatJson = prefs.getString('trainer_chat_conversations');
    if (chatJson != null && mounted) {
      try {
        final List<dynamic> decoded = jsonDecode(chatJson);
        final loaded = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted) {
          setState(() {
            _chatConversations = loaded;
          });
          if (_chatConversations.isNotEmpty) {
            _loadConversation(_chatConversations.first['id']);
          }
        }
      } catch (e) {
        debugPrint("Error loading conversations: $e");
      }
    }
    if (_currentConversationId.isEmpty) {
      _newConversation();
    }
  }

  void _loadConversation(String id) {
    final conv = _chatConversations.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {},
    );
    if (conv.isNotEmpty) {
      setState(() {
        _currentConversationId = id;
        _chatMessages.clear();
        final msgs = conv['messages'];
        if (msgs is List) {
          for (var e in msgs) {
            final map = e is Map
                ? Map<String, String>.from(
                    e.map((k, v) => MapEntry(k, v.toString())),
                  )
                : <String, String>{};
            _chatMessages.add(map);
          }
        }
      });
    }
  }

  void _newConversation() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newConv = {
      'id': id,
      'title': 'Nueva conversación',
      'messages': <Map<String, String>>[],
      'created': DateTime.now().toIso8601String(),
    };
    setState(() {
      _chatConversations.insert(0, newConv);
      _currentConversationId = id;
      _chatMessages.clear();
    });
    _saveChatHistory();
  }

  void _deleteConversation(String id) {
    setState(() {
      _chatConversations.removeWhere((c) => c['id'] == id);
      if (_currentConversationId == id) {
        if (_chatConversations.isNotEmpty) {
          _loadConversation(_chatConversations.first['id']);
        } else {
          _newConversation();
        }
      }
    });
    _saveChatHistory();
  }

  void _renameConversation(String id, String newTitle) {
    final idx = _chatConversations.indexWhere((c) => c['id'] == id);
    if (idx != -1) {
      setState(() {
        _chatConversations[idx]['title'] = newTitle;
      });
      _saveChatHistory();
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = _chatConversations.indexWhere(
      (c) => c['id'] == _currentConversationId,
    );
    if (idx != -1) {
      _chatConversations[idx]['messages'] = _chatMessages
          .map((m) => {'role': m['role'] ?? '', 'content': m['content'] ?? ''})
          .toList();
      if (_chatMessages.isNotEmpty &&
          _chatConversations[idx]['title'] == 'Nueva conversación') {
        final firstUser = _chatMessages.firstWhere(
          (m) => m['role'] == 'user',
          orElse: () => {'role': '', 'content': ''},
        );
        if (firstUser['content']!.isNotEmpty) {
          final raw = firstUser['content']!;
          final title = raw.length > 30 ? '${raw.substring(0, 30)}...' : raw;
          _chatConversations[idx]['title'] = title;
        }
      }
    }
    await prefs.setString(
      'trainer_chat_conversations',
      jsonEncode(_chatConversations),
    );
  }

  // --- NAV ORDER ---
  IconData _iconFromString(String name) {
    switch (name) {
      case 'play':
        return LucideIcons.play;
      case 'calendar':
        return LucideIcons.calendar;
      case 'trendingUp':
        return LucideIcons.trendingUp;
      case 'wrench':
        return LucideIcons.wrench;
      case 'messageCircle':
        return LucideIcons.messageCircle;
      default:
        return LucideIcons.circle;
    }
  }

  Future<void> _promptEditNote(String exercise) async {
    TextEditingController noteInput = TextEditingController(
      text: _exerciseNotes[exercise] ?? '',
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          "NOTA FIJA: $exercise",
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        content: TextField(
          controller: noteInput,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Ej. Asiento en 4, Agarre ancho...",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white10),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            child: const Text("CANCELAR"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              "GUARDAR",
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              setState(() {
                if (noteInput.text.trim().isEmpty) {
                  _exerciseNotes.remove(exercise);
                } else {
                  _exerciseNotes[exercise] = noteInput.text.trim();
                }
                _saveNotes();
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkDraftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasDraft = prefs.containsKey('trainer_draft_data');
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-update template if it exists (Feature 17)
    if (_customTemplates.containsKey(_activeWorkoutType)) {
      // Get unique exercises from current session
      final currentExNames = _currentSessionExercises
          .map((e) => e.name)
          .toSet()
          .toList();

      // Update template exercise list if we have new ones (or removed ones? User said "update if you make changes")
      // To be safe, we merge: Keep existing template structure, ensure used exercises are in it.
      // Actually, user probably wants the template to REFLECT the current session structure for next time.
      // Let's UPDATE the template's exercise list for the current group/key.

      // BUT, a template can have multiple groups. We only know the active one implies the template name?
      // Wait, _activeWorkoutType IS the template name usually? Or a Group name?
      // In _startWorkout(type), type is passed.
      // If type is a Custom Template Name, we load it.
      // If type is a Group Name (e.g. Pecho), it might be part of a template or standalone.

      // If _activeWorkoutType matches a Custom Template Key:
      if (_customTemplates.containsKey(_activeWorkoutType)) {
        final template = _customTemplates[_activeWorkoutType]!;
        Map<String, dynamic> templateExercises = Map<String, dynamic>.from(
          template['exercises'],
        );
        List<String> groups = List<String>.from(template['groups']);

        bool changed = false;

        // Check if any current exercise is missing from the template definitions
        for (var exName in currentExNames) {
          bool found = false;
          // Search in all groups of the template
          for (var g in groups) {
            List<dynamic> groupExs = templateExercises[g] ?? [];
            if (groupExs.contains(exName)) {
              found = true;
              break;
            }
          }

          if (!found) {
            // New exercise added during session! Add it to the first group (default) or a "General" group?
            // Let's add to the first group for now to ensure it's saved.
            if (groups.isNotEmpty) {
              String targetGroup = groups.first;
              List<dynamic> groupExs = List.from(
                templateExercises[targetGroup] ?? [],
              );
              groupExs.add(exName);
              templateExercises[targetGroup] = groupExs;
              changed = true;
            }
          }
        }

        if (changed) {
          _customTemplates[_activeWorkoutType] = {
            'groups': groups,
            'exercises': templateExercises,
            'weeklyPlan': template['weeklyPlan'],
          };
          _saveCustomTemplates(); // Persist changes
        }
      }
    }

    final draftData = {
      'type': _activeWorkoutType,
      'exercises': _currentSessionExercises.map((e) => e.toJson()).toList(),
      'selectedExercise': _selectedExercise,
      'weightCtrl': _weightCtrl.text,
      'repsCtrl': _repsCtrl.text,
      'noteCtrl': _noteCtrl.text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('trainer_draft_data', jsonEncode(draftData));
    _checkDraftStatus();
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trainer_draft_data');
    _checkDraftStatus();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftStr = prefs.getString('trainer_draft_data');
    if (draftStr != null) {
      try {
        final draft = jsonDecode(draftStr);
        setState(() {
          _isSessionActive = true;
          _activeWorkoutType = draft['type'];
          _selectedExercise = draft['selectedExercise'] ?? '';
          _currentSessionExercises = (draft['exercises'] as List)
              .map((e) => ExerciseSet.fromJson(e))
              .toList();

          if (_exerciseDb[_activeWorkoutType] == null ||
              _exerciseDb[_activeWorkoutType]!.isEmpty) {
            _selectedExercise = '';
          } else if (_selectedExercise.isEmpty ||
              !_exerciseDb[_activeWorkoutType]!.contains(_selectedExercise)) {
            _selectedExercise = _exerciseDb[_activeWorkoutType]!.isNotEmpty
                ? _exerciseDb[_activeWorkoutType]!.first
                : '';
          }
          if (draft['weightCtrl'] != null) {
            _weightCtrl.text = draft['weightCtrl'];
          }
          if (draft['repsCtrl'] != null) {
            _repsCtrl.text = draft['repsCtrl'];
          }
          if (draft['noteCtrl'] != null) {
            _noteCtrl.text = draft['noteCtrl'];
          }
        });
      } catch (e) {
        _clearDraft();
      }
    }
  }

  Future<void> _checkPersistentTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final endTimeStr = prefs.getString('timer_end_time');
    if (endTimeStr != null) {
      final endTime = DateTime.parse(endTimeStr);
      final remaining = endTime.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        _startRestTimer(customSeconds: remaining, persist: true);
      } else {
        await prefs.remove('timer_end_time');
        await _notificationsPlugin.cancelAll();
        setState(() {
          _showTimer = false;
          _isTimerExpanded = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final config = {
      'groups': _userGroups,
      'exercises': _exerciseDb,
      'archivedExercises': _archivedExercises,
      'plannerMode': _plannerMode,
      'weeklyPlan': _weeklyPlan,
      'defaultRestSeconds': _defaultRestSeconds,
      'pinnedNotes': _pinnedNotes,
      'enableVibration': _enableVibration,
      'enableSound': _enableSound,
      'enableNotifications': _enableNotifications,
      'timerSoundType': _timerSoundType,
      'useCustomApiKey': _useCustomApiKey,
      'customApiKey': _customApiKey,
    };
    await prefs.setString('trainer_config', jsonEncode(config));
  }

  Future<void> _saveCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'trainer_custom_templates',
      jsonEncode(_customTemplates),
    );
  }

  // ... (existing code)

  // --- LOGICA TIMER ---
  void _startRestTimer({int? customSeconds, bool persist = true}) async {
    _restTimer?.cancel();
    await _notificationsPlugin.cancelAll();
    _secondsLeft = customSeconds ?? _defaultRestSeconds;
    _totalRestSeconds = _secondsLeft;

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      final endTime = DateTime.now().add(Duration(seconds: _secondsLeft));
      await prefs.setString('timer_end_time', endTime.toIso8601String());
      _scheduleTimerAlarm(endTime);
    }

    setState(() => _showTimer = true);
    _updateNotificationProgress(_secondsLeft, _totalRestSeconds);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      final endTimeStr = prefs.getString('timer_end_time');
      if (endTimeStr == null) {
        timer.cancel();
        setState(() {
          _showTimer = false;
          _isTimerExpanded = false;
        });
        return;
      }
      final endTime = DateTime.parse(endTimeStr);
      final remaining = endTime.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        await _notificationsPlugin.cancelAll();
        _triggerNotification();
        _playTimerSound();
        await prefs.remove('timer_end_time');
        if (_enableVibration) {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 500), () {
            HapticFeedback.heavyImpact();
          });
        }
        setState(() {
          _showTimer = false;
          _isTimerExpanded = false;
        });
      } else {
        setState(() => _secondsLeft = remaining);
        _updateNotificationProgress(remaining, _totalRestSeconds);
      }
    });
  }

  Future<void> _scheduleTimerAlarm(DateTime scheduledTime) async {
    if (!_enableNotifications) {
      return;
    }
    try {
      await _notificationsPlugin.zonedSchedule(
        id: 99,
        title: 'A ENTRENAR',
        body: 'Tu descanso ha terminado',
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        payload: jsonEncode({'type': 'timer_alarm'}),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer_channel',
            'Temporizador Finalizado',
            channelDescription: 'Notifica cuando termina el descanso',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint("Schedule alarm error: $e");
    }
  }

  Future<void> _initNotifications() async {
    try {
      tz.initializeTimeZones();
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );

      // Create notification channels explicitly
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            'rest_timer_progress',
            'Temporizador en Progreso',
            description: 'Muestra el progreso del descanso',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
          ),
        );
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            'rest_timer_channel',
            'Temporizador Finalizado',
            description: 'Notifica cuando termina el descanso',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        // Request notification permission on Android 13+
        await android.requestNotificationsPermission();
        // Permiso de alarma exacta (Android 12+) para que el timer suene
        // aunque la app esté cerrada
        if (await Permission.scheduleExactAlarm.isDenied) {
          await Permission.scheduleExactAlarm.request();
        }
      }
    } catch (e) {
      debugPrint("Notification init error: $e");
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data['type'] == 'timer_alarm' || data['type'] == 'timer_complete') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _activeTab = 0;
              _showTimer = true;
              _isTimerExpanded = true;
            });
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Notification tap error: $e");
    }
  }

  String _formatDuration(Duration d) {
    String h = d.inHours > 0 ? "${d.inHours}h " : "";
    String m = "${d.inMinutes % 60}m";
    return "$h$m";
  }

  String _formatSeconds(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _updateNotificationProgress(int current, int total) async {
    if (!_enableNotifications) {
      return;
    }

    final elapsed = _workoutStartTime != null
        ? DateTime.now().difference(_workoutStartTime!)
        : Duration.zero;
    final elapsedStr = _formatDuration(elapsed);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'rest_timer_progress',
          'Temporizador en Progreso',
          channelDescription: 'Muestra el progreso del descanso',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    try {
      await _notificationsPlugin.show(
        id: 1,
        title: 'Descanso - Quedan ${_formatSeconds(current)}',
        body: 'Entreno: $elapsedStr',
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  Future<void> _triggerNotification() async {
    if (!_enableNotifications) {
      return;
    }
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'rest_timer_channel',
          'Temporizador Finalizado',
          channelDescription: 'Notifica cuando termina el descanso',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          playSound: true,
          enableVibration: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    final elapsed = _workoutStartTime != null
        ? DateTime.now().difference(_workoutStartTime!)
        : Duration.zero;
    await _notificationsPlugin.show(
      id: 2,
      title: '¡A ENTRENAR!',
      body: 'Tu descanso ha terminado. Entreno: ${_formatDuration(elapsed)}',
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode({'type': 'timer_complete'}),
    );
  }

  Future<void> _playTimerSound() async {
    if (!_enableSound) {
      return;
    }
    try {
      final player = AudioPlayer();
      String soundAsset;
      switch (_timerSoundType) {
        case 'beep':
          soundAsset = 'sounds/timer_beep.wav';
          break;
        case 'ding':
          soundAsset = 'sounds/timer_ding.wav';
          break;
        default:
          soundAsset = 'sounds/timer_alarm.wav';
      }
      await player.play(AssetSource(soundAsset));
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 3), () => player.dispose());
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Widget _soundOption(String value, String label) {
    final isSelected = _timerSoundType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timerSoundType = value;
          _saveConfig();
        });
        // Preview sound
        final player = AudioPlayer();
        String asset;
        switch (value) {
          case 'beep':
            asset = 'sounds/timer_beep.wav';
            break;
          case 'ding':
            asset = 'sounds/timer_ding.wav';
            break;
          default:
            asset = 'sounds/timer_alarm.wav';
        }
        player.play(AssetSource(asset)).then((_) {
          Future.delayed(const Duration(seconds: 2), () => player.dispose());
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? _accentColor.withValues(alpha: 0.5)
                : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _accentColor : Colors.white54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // --- LOGICA ENTRENAMIENTO ---
  String _formatNum(double n) {
    if (n % 1 == 0) {
      return n.toInt().toString();
    }
    return n.toString();
  }

  void _addSet() {
    if (_selectedExercise.isEmpty ||
        _weightCtrl.text.isEmpty ||
        _repsCtrl.text.isEmpty) {
      return;
    }
    final now = DateTime.now();
    double weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 0;
    double reps = double.tryParse(_repsCtrl.text.replaceAll(',', '.')) ?? 0;

    double? nextW;
    // Calculate next weight based on increment
    if (_adjustmentIncrement != 0) {
      nextW = weight + _adjustmentIncrement;
    } else {
      nextW = weight; // Mantener
    }

    // Feature 35: Global Suggestion
    // Add exercise to DB if not exists
    if (!_exerciseDb.values.any((list) => list.contains(_selectedExercise))) {
      // Find current group or "General"?
      // _activeWorkoutType is the current key we are in.
      // If it's a Custom Routine (Template), it has groups.
      // But here we are in execution mode. _activeWorkoutType might be the Routine Name.
      // We know `_exerciseDb[_activeWorkoutType]` exists if it's a simple group-based flow.
      // IF we are in a Template flow, `_exerciseDb` contains "Group -> [List]".
      // We need to know which GROUP the exercise belongs to?
      // Actually, `_selectedExercise` comes from the dropdown which is populated from `_exerciseDb`.
      // So it MUST exist, unless we allow Manual Entry of NEW names?
      // User request: "si añades un ejercicio se añada al seleccionador".
      // This likely implies if they type a NEW name or pick one?
      // Wait, there is no "New Exercise" text field. There is only a dropdown + "Add Exercise" button.
      // The "Add Exercise" button (Feature 24? no) allows creating valid exercises.
      // Maybe they mean: If I drag/drop or add an exercise to *Group A*, it should be available in *Group B*?
      // "por si tmb lo quieres poner en otro grupo muscular".
      // Yes. "Archived" or just "Global Search"?
      // Current system: Exercises are scoped to Groups.
      // If I create "Bench Press" in "Chest", it is only in "Chest".
      // Use Case: I want "Bench Press" in "Full Body A" too.
      // Fix: When adding an exercise (via the Add Dialog), suggest existing names from OTHER groups?
      // Ah, this modify needs to be in `_showAddExerciseDialog`.
    }

    final newSet = ExerciseSet(
      name: _selectedExercise.toUpperCase(),
      weight: weight,
      reps: reps,
      note: _noteCtrl.text,
      time:
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      date: now,
      adjustment: _adjustmentIncrement > 0
          ? 'SUBIR'
          : (_adjustmentIncrement < 0 ? 'BAJAR' : 'MANTENER'),
      nextWeight: nextW,
    );

    setState(() {
      _currentSessionExercises.add(newSet);
      // Auto-update weight for next set if desired?
      // User said: "la proxima vez te sugiera ese peso". Usually implies next SESSION.
      // So we keep current weight for now.

      // Reset adjustment
      _adjustmentIncrement = 0.0;

      // FIX V7: Auto-Advance Carousel
      // If we just saved Set 1 (index 0), and Last Session had 3 sets, we want to show Set 2 (index 1).
      // We need to know how many sets contain this exercise in the "Last Session".
      try {
        // FIX 6: Get NEWEST session
        final lastSession = _sessions.firstWhere(
          (s) =>
              s.exercises.any((e) => e.name == _selectedExercise.toUpperCase()),
        );
        int lastSessionCount = lastSession.exercises
            .where((e) => e.name == _selectedExercise.toUpperCase())
            .length;

        // If current index is less than the count (minus 1, since indices are 0-based), advance.
        // E.g. Last session has 3 sets (Index 0, 1, 2).
        // We are at Index 0. We save set 1. We want to go to Index 1.
        // If we are at Index 2. We save set 3. We assume no more sets (Index 3 doesn't exist).
        // User: "que no muestre mas series si no las hay".
        if (_historyCarouselIndex < lastSessionCount - 1) {
          _historyCarouselIndex++;
          // FIX V8: Animate Carousel
          if (_historyPageController.hasClients) {
            _historyPageController.animateToPage(
              _historyCarouselIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        } else {
          // Optional: Show message "No hay más series en el historial"
          // But UI just stays there, which is what user asked ("se queda ahí").
        }
      } catch (e) {
        // No history found, ignore
      }

      // FIX V8: Uncomment Clear inputs
      _weightCtrl.clear();
      _repsCtrl.clear();
      _noteCtrl.clear();
    });

    _saveDraft();
    _startRestTimer();
  }

  // _showFeedbackOverlay REMOVED

  void _promptEditSet(int index) {
    final set = _currentSessionExercises[index];
    final wCtrl = TextEditingController(text: _formatNum(set.weight));
    final rCtrl = TextEditingController(text: _formatNum(set.reps));
    final nCtrl = TextEditingController(text: set.note);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          "EDITAR: ${set.name}",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: wCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Peso",
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: rCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Reps",
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Nota",
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currentSessionExercises.removeAt(index);
                _saveDraft();
              });
              Navigator.pop(c);
            },
            child: const Text(
              "ELIMINAR",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "CANCELAR",
              style: TextStyle(color: Colors.white24),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                double w =
                    double.tryParse(wCtrl.text.replaceAll(',', '.')) ??
                    set.weight;
                double r =
                    double.tryParse(rCtrl.text.replaceAll(',', '.')) ??
                    set.reps;
                _currentSessionExercises[index] = set.copyWith(
                  weight: w,
                  reps: r,
                  note: nCtrl.text,
                );
                _saveDraft();
              });
              Navigator.pop(c);
            },
            child: Text("GUARDAR", style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  ExerciseSet? _getPB(String exName) {
    if (exName.isEmpty) {
      return null;
    }
    List<ExerciseSet> allSets = _sessions
        .expand((s) => s.exercises)
        .where((e) => e.name == exName.toUpperCase())
        .toList();
    if (allSets.isEmpty) {
      return null;
    }

    return allSets.reduce((a, b) {
      return a.effectiveScore > b.effectiveScore ? a : b;
    });
  }

  // --- LOGICA GESTIÓN RUTINAS ---
  void _moveGroup(int index, int delta) {
    if (index + delta < 0 || index + delta >= _userGroups.length) {
      return;
    }
    setState(() {
      final item = _userGroups.removeAt(index);
      _userGroups.insert(index + delta, item);
      _saveConfig();
    });
  }

  void _reorderExercises(String group, int oldIndex, int newIndex) {
    setState(() {
      final items = _exerciseDb[group]!;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      _saveConfig();
    });
  }

  void _archiveExercise(String group, String ex) {
    setState(() {
      _exerciseDb[group]!.remove(ex);
      _archivedExercises[group] ??= [];
      _archivedExercises[group]!.add(ex);
      _saveConfig();
    });
  }

  void _unarchiveExercise(String group, String ex) {
    setState(() {
      _archivedExercises[group]!.remove(ex);
      _exerciseDb[group]!.add(ex);
      _saveConfig();
    });
  }

  void _deleteExercisePermanently(String group, String ex, bool fromArchive) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿BORRAR PARA SIEMPRE?'),
        content: Text('Esto eliminará "$ex" de esta lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (fromArchive) {
                  _archivedExercises[group]?.remove(ex);
                } else {
                  _exerciseDb[group]?.remove(ex);
                }
                _saveConfig();
              });
              Navigator.pop(c);
            },
            child: const Text(
              'BORRAR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _renameExercise(String group, String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('RENOMBRAR EJERCICIO'),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              String newName = ctrl.text.toUpperCase().trim();
              if (newName.isNotEmpty &&
                  newName != oldName &&
                  !_exerciseDb[group]!.contains(newName)) {
                setState(() {
                  int idx = _exerciseDb[group]!.indexOf(oldName);
                  if (idx != -1) {
                    _exerciseDb[group]![idx] = newName;
                    _saveConfig();
                  }
                });
              }
              Navigator.pop(c);
            },
            child: Text('GUARDAR', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  void _renameRoutine(String oldName, String newName) {
    if (newName.isEmpty || oldName == newName) {
      return;
    }
    newName = newName.toUpperCase();
    setState(() {
      int idx = _userGroups.indexOf(oldName);
      if (idx != -1) {
        _userGroups[idx] = newName;
      }
      if (_exerciseDb.containsKey(oldName)) {
        _exerciseDb[newName] = _exerciseDb.remove(oldName)!;
      }
      if (_archivedExercises.containsKey(oldName)) {
        _archivedExercises[newName] = _archivedExercises.remove(oldName)!;
      }
      _weeklyPlan.forEach((key, value) {
        if (value == oldName) {
          _weeklyPlan[key] = newName;
        }
      });
      for (var session in _sessions) {
        if (session.type == oldName) {
          session.type = newName;
        }
      }
      _saveConfig();
      _saveSessions();
    });
  }

  void _setupInitialRoutine(String type) {
    if (_customTemplates.containsKey(type)) {
      final template = _customTemplates[type]!;
      setState(() {
        _userGroups = List<String>.from(template['groups']);
        _exerciseDb = (template['exercises'] as Map).map(
          (k, v) => MapEntry(k.toString(), List<String>.from(v)),
        );
        _weeklyPlan = {
          'Lunes': 'DESCANSO',
          'Martes': 'DESCANSO',
          'Miércoles': 'DESCANSO',
          'Jueves': 'DESCANSO',
          'Viernes': 'DESCANSO',
          'Sábado': 'DESCANSO',
          'Domingo': 'DESCANSO',
        };
        _isFirstTime = false;
        _saveConfig();
      });
      return;
    }

    Map<String, Map<String, List<String>>> presets = {
      'PUSH PULL LEG': {
        'EMPUJE': [
          'PRESS BANCA',
          'PRESS MILITAR',
          'EXTENSIÓN TRICEPS',
          'LATERALES',
        ],
        'TIRÓN': [
          'DOMINADAS',
          'REMO CON BARRA',
          'CURL BICEPS',
          'JALÓN AL PECHO',
        ],
        'PIERNA': ['SENTADILLA', 'PESO MUERTO', 'EXTENSIÓN PIERNA', 'PRENSA'],
      },
      'FULL BODY': {
        'DÍA A': ['SENTADILLA', 'PRESS BANCA', 'REMO CON BARRA', 'CURL BICEPS'],
        'DÍA B': [
          'PESO MUERTO',
          'PRESS MILITAR',
          'DOMINADAS',
          'EXTENSIÓN TRICEPS',
        ],
      },
      'UPPER LOWER': {
        'SUPERIOR': ['PRESS BANCA', 'REMO', 'MILITAR', 'JALÓN'],
        'INFERIOR': ['SENTADILLA', 'PRENSA', 'FEMORAL', 'GEMELO'],
      },
      'ARNOLD SPLIT': {
        'PECHO/ESPALDA': [
          'PRESS BANCA',
          'DOMINADAS',
          'PRESS INCLINADO',
          'REMO T',
        ],
        'HOMBROS/BRAZOS': [
          'PRESS MILITAR',
          'CURL BICEPS',
          'TRICEPS POLEA',
          'LATERALES',
        ],
        'PIERNAS': ['SENTADILLA', 'ZANCADAS', 'EXTENSIONES'],
      },
      'PERSONALIZADO': {},
    };

    setState(() {
      if (presets.containsKey(type)) {
        _userGroups = presets[type]!.keys.toList();
        _exerciseDb = Map<String, List<String>>.from(presets[type]!);
        _weeklyPlan = {
          'Lunes': 'DESCANSO',
          'Martes': 'DESCANSO',
          'Miércoles': 'DESCANSO',
          'Jueves': 'DESCANSO',
          'Viernes': 'DESCANSO',
          'Sábado': 'DESCANSO',
          'Domingo': 'DESCANSO',
        };
      }
      _isFirstTime = false;
      _saveConfig();
    });
  }

  void _saveCurrentAsTemplate() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('GUARDAR PLANTILLA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Guarda tu estructura actual para usarla después de un reinicio.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nombre de la plantilla (ej: "Mi Rutina Pro")',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                setState(() {
                  _customTemplates[ctrl.text.toUpperCase()] = {
                    'groups': _userGroups,
                    'exercises': _exerciseDb,
                  };
                  _saveCustomTemplates();
                });
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Plantilla "${ctrl.text}" guardada para siempre.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text('GUARDAR', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  void _deleteCustomTemplate(String key) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿ELIMINAR PLANTILLA?'),
        content: Text('Se borrará la plantilla "$key".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _customTemplates.remove(key);
                _saveCustomTemplates();
              });
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Plantilla "$key" eliminada.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // --- INTERFAZ PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withValues(
                            alpha: 0.3 * _glowController.value,
                          ),
                          blurRadius: 30 * _glowController.value,
                          spreadRadius: 5 * _glowController.value,
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.dumbbell,
                      size: 48,
                      color: _accentColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_isFirstTime) {
      return _buildOnboarding();
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) => setState(() {
                    _activeTab = i;
                    if (i != 0) {
                      _showSettings = false;
                    }
                  }),
                  children: [
                    _buildAddTab(),
                    _buildHistoryTab(),
                    _buildStatsTab(),
                    _buildToolsTab(),
                    _buildChatTab(),
                  ],
                ),
              ),
              if (!_isSessionActive && _activeTab != 4) _buildBottomNav(),
            ],
          ),
          if (_showTimer) _buildTimerFloating(),
        ],
      ),
    );
  }

  // --- VISTAS AUXILIARES ---
  Widget _buildOnboarding() {
    final routines = [
      'PUSH PULL LEG',
      'FULL BODY',
      'UPPER LOWER',
      'ARNOLD SPLIT',
      'PERSONALIZADO',
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.dumbbell,
                    size: 50,
                    color: _accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    const Text(
                      'ESTRUCTURA DE RUTINA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Selecciona una base para comenzar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              if (_customTemplates.isNotEmpty) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: const Text(
                    'MIS PLANTILLAS GUARDADAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ..._customTemplates.keys.map(
                  (name) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 15 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: PressableScale(
                              onTap: () {
                                _setupInitialRoutine(name);
                                setState(() => _showSettings = false);
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blueAccent.withValues(alpha: 0.3),
                                      Colors.blueAccent.withValues(alpha: 0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.blueAccent.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PressableScale(
                            onTap: () => _deleteCustomTemplate(name),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.trash2,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 20),
              ],

              ...routines.asMap().entries.map(
                (entry) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + entry.key * 100),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: PressableScale(
                      onTap: () {
                        _setupInitialRoutine(entry.value);
                        setState(() => _showSettings = false);
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerFloating() {
    double timerProgress = _totalRestSeconds > 0
        ? (_totalRestSeconds - _secondsLeft) / _totalRestSeconds
        : 0.0;

    if (_isTimerExpanded) {
      return GestureDetector(
        onTap: () => setState(() => _isTimerExpanded = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.95),
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularTimer(
                progress: timerProgress.clamp(0.0, 1.0),
                secondsLeft: _secondsLeft,
                totalSeconds: _totalRestSeconds,
                accentColor: _accentColor,
                isExpanded: true,
              ),
              const SizedBox(height: 40),
              const Text(
                "TOCA PARA MINIMIZAR",
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PressableScale(
                    onTap: () async {
                      setState(
                        () => _secondsLeft = (_secondsLeft - 10).clamp(1, 999),
                      );
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'timer_end_time',
                        DateTime.now()
                            .add(Duration(seconds: _secondsLeft))
                            .toIso8601String(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        LucideIcons.minusCircle,
                        size: 30,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  PressableScale(
                    onTap: () async {
                      setState(
                        () => _secondsLeft = (_secondsLeft + 10).clamp(1, 999),
                      );
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'timer_end_time',
                        DateTime.now()
                            .add(Duration(seconds: _secondsLeft))
                            .toIso8601String(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        LucideIcons.plusCircle,
                        size: 30,
                        color: _accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "TIEMPOS RÁPIDOS",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3, 4, 5].map((min) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PressableScale(
                      onTap: () async {
                        setState(() => _secondsLeft = min * 60);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'timer_end_time',
                          DateTime.now()
                              .add(Duration(seconds: _secondsLeft))
                              .toIso8601String(),
                        );
                        _totalRestSeconds = _secondsLeft;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          "${min}m",
                          style: TextStyle(
                            color: _accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    // Minimized pill - draggable
    double posX = _timerPosX;
    double posY = _timerPosY;
    if (posX == -1) {
      posX = MediaQuery.of(context).size.width - 140;
    }
    if (posY == -1) {
      posY = _isSessionActive ? 40.0 : 110.0;
    }

    return Positioned(
      top: posY,
      left: posX,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () => setState(() => _isTimerExpanded = true),
        onPanUpdate: (details) {
          setState(() {
            _timerPosX = (posX + details.delta.dx).clamp(
              0,
              MediaQuery.of(context).size.width - 120,
            );
            _timerPosY = (posY + details.delta.dy).clamp(
              0,
              MediaQuery.of(context).size.height - 60,
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              const BoxShadow(color: Colors.black45, blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularTimer(
                progress: timerProgress.clamp(0.0, 1.0),
                secondsLeft: _secondsLeft,
                totalSeconds: _totalRestSeconds,
                accentColor: _accentColor,
                isExpanded: false,
              ),
              const SizedBox(width: 6),
              Text(
                "${(_secondsLeft ~/ 60)}:${(_secondsLeft % 60).toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  shadows: [
                    Shadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: () async {
                  _restTimer?.cancel();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('timer_end_time');
                  await _notificationsPlugin.cancelAll();
                  setState(() => _showTimer = false);
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    color: Colors.white24,
                    size: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    IconData themeIcon;
    switch (widget.currentTheme) {
      case AppTheme.cyberNeon:
        themeIcon = LucideIcons.zap;
        break;
      case AppTheme.crimsonBlood:
        themeIcon = LucideIcons.flame;
        break;
      case AppTheme.toxicGreen:
        themeIcon = LucideIcons.radiation;
        break;
      case AppTheme.solarFlare:
        themeIcon = LucideIcons.sun;
        break;
      default:
        themeIcon = LucideIcons.moon;
    }
    return AnimatedBuilder(
      animation: _headerAnimController,
      builder: (context, child) {
        return Opacity(
          opacity: _headerAnimController.value,
          child: Transform.translate(
            offset: Offset(0, -20 * (1 - _headerAnimController.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 60, 24, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PressableScale(
              onTap: widget.onToggleTheme,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(themeIcon, color: _accentColor, size: 20),
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
                children: [
                  const TextSpan(
                    text: 'TRAINER',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: ' PRO',
                    style: TextStyle(
                      color: _accentColor,
                      shadows: [
                        Shadow(
                          color: _accentColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _activeTab == 0
                ? (_isSessionActive
                      ? PressableScale(
                          onTap: () =>
                              setState(() => _showSettings = !_showSettings),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _showSettings
                                  ? _accentColor.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _showSettings ? LucideIcons.x : LucideIcons.edit3,
                              size: 18,
                              color: _showSettings
                                  ? _accentColor
                                  : Colors.white24,
                            ),
                          ),
                        )
                      : PressableScale(
                          onTap: () =>
                              setState(() => _showSettings = !_showSettings),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _showSettings
                                  ? _accentColor.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _showSettings
                                  ? LucideIcons.x
                                  : LucideIcons.settings,
                              size: 18,
                              color: _showSettings
                                  ? _accentColor
                                  : Colors.white24,
                            ),
                          ),
                        ))
                : const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  // --- PESTAÑA 1: HOY / ENTRENAR ---
  Widget _buildAddTab() {
    if (_isSessionActive && !_showSettings) {
      return _buildActiveWorkoutView();
    }
    if (_showSettings) {
      return _buildFullSettings();
    }

    final suggestion = _getSuggestion();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_hasDraft)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 25),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.alertCircle,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ENTRENAMIENTO PENDIENTE",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          "Tienes una sesión sin finalizar.",
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  PressableScale(
                    onTap: _clearDraft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "BORRAR",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    onTap: _loadDraft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text(
                        "RECUPERAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        GestureDetector(
          onTap: () => suggestion['type'] == 'DESCANSO'
              ? null
              : _startWorkout(suggestion['type']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: suggestion['type'] == 'DESCANSO'
                  ? LinearGradient(colors: [_cardColor, Colors.black])
                  : LinearGradient(
                      colors: [
                        _accentColor.withValues(alpha: 0.8),
                        _accentColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: suggestion['type'] != 'DESCANSO'
                  ? [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'RECOMENDACIÓN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  suggestion['type']!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion['reason']!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 35),
        const Text(
          'MIS RUTINAS ACTIVAS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 15),
        ..._userGroups.asMap().entries.map(
          (entry) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + entry.key * 100),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: _accentColor,
                  ),
                ),
                onTap: () => _startWorkout(entry.value),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- PESTAÑA TOOLS ---
  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.share2, color: _accentColor, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    "COMPARTIR RUTINAS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // BOTON 1: COMPARTIR GRUPO/DÍA (Antiguo exportar)
              // BOTON UNIFICADO V4: COMPARTIR
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(
                  LucideIcons.share2,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  "COMPARTIR...",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                onPressed: _showUnifiedShareDialog,
              ),
              const SizedBox(height: 10),
              // BOTON 3: IMPORTAR
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(
                  LucideIcons.download,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  "IMPORTAR CÓDIGO",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                onPressed: _showImportDialog,
              ),
            ],
          ),
        ),

        const Text(
          "HERRAMIENTAS",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.1,
          children: [
            _toolCard("Calculadora 1RM", LucideIcons.calculator, _show1RMTool),
            _toolCard("Calculadora Discos", LucideIcons.disc, _showPlateTool),
            _toolCard("IMC Avanzado", LucideIcons.user, _showBMITool),
            _toolCard(
              "Tabla Porcentajes",
              LucideIcons.percent,
              _showPercentTool,
            ),
            _toolCard(
              "Timer Rápido",
              LucideIcons.timer,
              () => _startRestTimer(),
            ),
            _toolCard("Calculadora Macros", LucideIcons.beef, _showMacroTool),
          ],
        ),

        const SizedBox(height: 25),
        const Text(
          "AJUSTES DE LA APP",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Vibración",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  "Vibrar al terminar el descanso",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                value: _enableVibration,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() {
                    _enableVibration = val;
                    _saveConfig();
                  });
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text(
                  "Sonido",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  "Sonar al terminar el descanso",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                value: _enableSound,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() {
                    _enableSound = val;
                    _saveConfig();
                  });
                },
              ),
              if (_enableSound) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tipo de sonido",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _soundOption('alarm', 'Alarma'),
                          const SizedBox(width: 8),
                          _soundOption('beep', 'Beep'),
                          const SizedBox(width: 8),
                          _soundOption('ding', 'Ding'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text(
                  "Notificaciones",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  "Mostrar notificación persistente del timer",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                value: _enableNotifications,
                activeThumbColor: _accentColor,
                onChanged: (val) async {
                  if (val) {
                    // Request permission first
                    final android = _notificationsPlugin
                        .resolvePlatformSpecificImplementation<
                          AndroidFlutterLocalNotificationsPlugin
                        >();
                    if (android != null) {
                      final granted = await android
                          .requestNotificationsPermission();
                      if (granted != true) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Permiso de notificaciones denegado. Actívalo en Ajustes.",
                              ),
                            ),
                          );
                        }
                        return;
                      }
                    }
                  }
                  setState(() {
                    _enableNotifications = val;
                    _saveConfig();
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? "Notificaciones activadas."
                              : "Notificaciones desactivadas.",
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
        _settingTitle('CUENTA'),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: _buildAuthSection(),
        ),

        const SizedBox(height: 30),
        Text(
          "v2.0.0",
          style: TextStyle(color: Colors.white12, fontSize: 10),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAuthSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _accentColor.withValues(alpha: 0.2),
              child: Text(
                (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user.displayName ?? user.email ?? 'Usuario',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              user.email ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ListTile(
            leading: Icon(LucideIcons.cloud, color: _accentColor, size: 18),
            title: const Text(
              "Subir datos a la nube",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: const Text(
              "Guardar progreso en tu cuenta",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            onTap: _syncDataToFirestore,
          ),
          const Divider(color: Colors.white10, height: 1),
          ListTile(
            leading: const Icon(
              LucideIcons.logOut,
              color: Colors.redAccent,
              size: 18,
            ),
            title: const Text(
              "Cerrar sesión",
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              setState(() {});
            },
          ),
        ],
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(LucideIcons.userCircle, size: 32, color: Colors.white24),
        const SizedBox(height: 8),
        const Text(
          "Inicia sesión para guardar\ntu progreso en la nube",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
                setState(() {});
              },
              child: const Text(
                "INICIAR SESIÓN / REGISTRARSE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<bool> _syncDataToFirestore({bool showFeedback = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    if (showFeedback) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Subiendo datos...")));
    }
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await doc.set({
        'sessions': _sessions.map((s) => s.toJson()).toList(),
        'groups': _userGroups,
        'exerciseDb': _exerciseDb,
        'templates': _customTemplates,
        'weeklyPlan': _weeklyPlan,
        'pinnedNotes': _pinnedNotes,
        'notes': _exerciseNotes,
        'emailVerified': user.emailVerified,
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sincronizado ✓")),
        );
      }
      return true;
    } catch (e) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al sincronizar: $e")),
        );
      }
      return false;
    }
  }

  Future<void> _retryPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('pending_sync') ?? false;
    if (!pending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final synced = await _syncDataToFirestore(showFeedback: false);
    if (synced) {
      await prefs.remove('pending_sync');
    }
  }

  Future<void> _loadDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists || doc.data() == null) {
        return;
      }
      final data = doc.data()!;
      if (data['sessions'] == null && data['groups'] == null) {
        return;
      }

      // No sobrescribir los datos locales del dispositivo (evita "volver atrás")
      final prefs = await SharedPreferences.getInstance();
      final localSessions = prefs.getString('trainer_sessions');
      final localConfig = prefs.getString('trainer_config');
      final hasLocalData =
          (localSessions != null && localSessions != '[]') ||
          (localConfig != null && localConfig.contains('"groups"'));
      if (hasLocalData) {
        return;
      }

      if (data['sessions'] != null) {
        await prefs.setString('trainer_sessions', jsonEncode(data['sessions']));
      }
      if (data['templates'] != null) {
        await prefs.setString(
          'trainer_custom_templates',
          jsonEncode(data['templates']),
        );
      }
      if (data['notes'] != null) {
        await prefs.setString('trainer_notes', jsonEncode(data['notes']));
      }
      if (data['groups'] != null || data['exerciseDb'] != null) {
        final configStr = prefs.getString('trainer_config');
        final config = configStr != null
            ? jsonDecode(configStr) as Map<String, dynamic>
            : {};
        if (data['groups'] != null) {
          config['groups'] = data['groups'];
        }
        if (data['exerciseDb'] != null) {
          config['exercises'] = data['exerciseDb'];
        }
        if (data['weeklyPlan'] != null) {
          config['weeklyPlan'] = data['weeklyPlan'];
        }
        if (data['pinnedNotes'] != null) {
          config['pinnedNotes'] = data['pinnedNotes'];
        }
        await prefs.setString('trainer_config', jsonEncode(config));
      }

      await _loadData();
      await _loadNotes();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error loading from Firestore: $e");
    }
  }

  // LOGICA IMPORT / EXPORT (Actualizada)
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("COMPARTIR GRUPO/DÍA"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Elige un grupo muscular para compartir:",
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 10),
              ..._userGroups.map(
                (g) => ListTile(
                  title: Text(
                    g,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  trailing: const Icon(
                    LucideIcons.copy,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    List<String> exercises = _exerciseDb[g] ?? [];
                    Map<String, dynamic> data = {
                      'type': 'single_group',
                      'name': g,
                      'exercises': exercises,
                    };
                    String jsonStr = jsonEncode(data);
                    String base64Str = base64Encode(utf8.encode(jsonStr));

                    Clipboard.setData(ClipboardData(text: base64Str));
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _accentColor,
                        content: Text("Día '$g' copiado."),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CANCELAR"),
          ),
        ],
      ),
    );
  }

  void _shareFullStructure() {
    Map<String, dynamic> fullData = {
      'type': 'full_structure',
      'groups': _userGroups,
      'exercises': _exerciseDb,
      'weeklyPlan': _weeklyPlan,
    };
    String jsonStr = jsonEncode(fullData);
    String base64Str = base64Encode(utf8.encode(jsonStr));
    Clipboard.setData(ClipboardData(text: base64Str));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _accentColor,
        content: const Text("Rutina completa copiada al portapapeles."),
      ),
    );
  }

  void _shareSingleRoutine() {
    if (_customTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No tienes rutinas guardadas para compartir."),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text("Seleccionar Rutina"),
        backgroundColor: _cardColor,
        children: _customTemplates.keys
            .map(
              (key) => SimpleDialogOption(
                padding: const EdgeInsets.all(15),
                child: Text(
                  key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(c);
                  _generateAndShareRoutine(key);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _generateAndShareRoutine(String key) {
    if (!_customTemplates.containsKey(key)) {
      return;
    }

    final template = _customTemplates[key]!;
    final data = {'type': 'single_routine', 'name': key, 'content': template};

    String jsonString = jsonEncode(data);
    String base64String = base64Encode(utf8.encode(jsonString));
    Clipboard.setData(ClipboardData(text: "TRAINERPRO_ROUTINE::$base64String"));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Rutina '$key' copiada al portapapeles"),
        backgroundColor: _accentColor,
      ),
    );
  }

  void _showImportDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("IMPORTAR"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Pega el código aquí:",
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            child: Text("IMPORTAR", style: TextStyle(color: _accentColor)),
            onPressed: () {
              try {
                String base64Str = ctrl.text.trim();
                if (base64Str.isEmpty) {
                  return;
                }

                String jsonStr = utf8.decode(base64Decode(base64Str));
                Map<String, dynamic> data = jsonDecode(jsonStr);

                // Detectar tipo de importación
                if (data['type'] == 'full_structure') {
                  // Importar estructura completa
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("REEMPLAZAR RUTINA"),
                      content: const Text(
                        "Esto sobrescribirá tu estructura actual. ¿Continuar?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CANCELAR"),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _userGroups = List<String>.from(data['groups']);
                              _exerciseDb = (data['exercises'] as Map).map(
                                (k, v) => MapEntry(
                                  k.toString(),
                                  List<String>.from(v),
                                ),
                              );
                              _weeklyPlan = Map<String, String>.from(
                                data['weeklyPlan'],
                              );
                              _saveConfig();
                            });
                            Navigator.pop(ctx); // Close confirm
                            Navigator.pop(c); // Close import
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Rutina completa importada."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text(
                            "IMPORTAR TODO",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Importar grupo suelto (Legacy o nuevo formato)
                  String originalName = data['name'];
                  List<String> exercises = List<String>.from(data['exercises']);

                  String finalName = originalName;
                  int counter = 2;
                  while (_userGroups.contains(finalName)) {
                    finalName = "$originalName $counter";
                    counter++;
                  }

                  setState(() {
                    _userGroups.add(finalName);
                    _exerciseDb[finalName] = exercises;
                    _saveConfig();
                  });

                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      content: Text("Grupo '$finalName' añadido."),
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text("Error: Código inválido"),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _toolCard(String title, IconData icon, VoidCallback onTap) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accentColor.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, size: 24, color: _accentColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOGOS DE HERRAMIENTAS ---
  void _show1RMTool() {
    final wCtrl = TextEditingController();
    final rCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          double rm = 0;
          double w = double.tryParse(wCtrl.text) ?? 0;
          double r = double.tryParse(rCtrl.text) ?? 0;
          if (w > 0 && r > 0) {
            rm = w * (1 + r / 30);
          }

          return AlertDialog(
            title: const Text("Calculadora 1RM"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Peso (kg)"),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: rCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Repeticiones"),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Text(
                  "${rm.toStringAsFixed(1)} kg",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
                const Text(
                  "1RM Estimado (Epley)",
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CERRAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  // Calculadora de Discos Personalizable (NUEVO DISEÑO CON AGRUPACIÓN)
  void _showPlateTool() {
    Widget getPlateVisual(double weight) {
      double height = 40;
      double width = 4;
      Color color = Colors.grey;

      if (weight == 25) {
        height = 80;
        width = 14;
        color = Colors.red;
      } else if (weight == 20) {
        height = 80;
        width = 12;
        color = Colors.blue;
      } else if (weight == 15) {
        height = 70;
        width = 10;
        color = Colors.yellow;
      } else if (weight == 10) {
        height = 80;
        width = 8;
        color = Colors.green;
      } else if (weight == 5) {
        height = 50;
        width = 5;
        color = Colors.grey;
      } else if (weight == 2.5) {
        height = 40;
        width = 4;
        color = Colors.black54;
      } else {
        height = 35;
        width = 3;
        color = Colors.grey[300]!;
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (c) => PlateCalculatorDialog(
        accentColor: _accentColor,
        cardColor: _cardColor,
        getPlateVisual: getPlateVisual,
      ),
    );
  }

  // IMC Moderno (Formula Trefethen) y Sexo
  void _showBMITool() {
    final hCtrl = TextEditingController();
    final wCtrl = TextEditingController();
    bool isMale = true; // Default

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          double h = double.tryParse(hCtrl.text) ?? 0;
          double w = double.tryParse(wCtrl.text) ?? 0;
          double bmi = 0;
          String status = "";
          Color color = Colors.white;

          if (h > 0 && w > 0) {
            // Formula Trefethen: 1.3 * weight / height^2.5
            bmi = 1.3 * w / math.pow(h / 100, 2.5);

            // Rangos ajustados ligeramente
            if (bmi < 18.5) {
              status = "Bajo Peso";
              color = Colors.yellow;
            } else if (bmi < 25) {
              status = "Normal";
              color = Colors.green;
            } else if (bmi < 30) {
              status = "Sobrepeso";
              color = Colors.orange;
            } else {
              status = "Obesidad";
              color = Colors.red;
            }
          }

          return AlertDialog(
            title: const Text("IMC Pro (Trefethen 1.3)"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text("HOMBRE"),
                      selected: isMale,
                      onSelected: (v) => setState(() => isMale = true),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("MUJER"),
                      selected: !isMale,
                      onSelected: (v) => setState(() => isMale = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Altura (cm)"),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: wCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Peso (kg)"),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                if (bmi > 0)
                  Column(
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isMale ? "Rango Hombre" : "Rango Mujer",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CERRAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSessionContent(int index) {
    // Create a copy of the session to edit
    TrainingSession session = _sessions[index];
    List<ExerciseSet> editedExercises = List.from(session.exercises);

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            title: Text(
              "EDITAR CONTENIDO",
              style: TextStyle(color: _accentColor, fontSize: 14),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: editedExercises.length,
                itemBuilder: (context, i) {
                  final set = editedExercises[i];
                  return ListTile(
                    title: Text(
                      "${set.name} - ${set.weight}kg x ${set.reps}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    subtitle: Text(
                      set.note,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        LucideIcons.edit2,
                        size: 14,
                        color: Colors.blueAccent,
                      ),
                      onPressed: () {
                        // Edit single set
                        final wCtrl = TextEditingController(
                          text: _formatNum(set.weight),
                        );
                        final rCtrl = TextEditingController(
                          text: _formatNum(set.reps),
                        );
                        final nCtrl = TextEditingController(text: set.note);
                        showDialog(
                          context: context,
                          builder: (d) => AlertDialog(
                            title: const Text("EDITAR SERIE"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: wCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Peso",
                                  ),
                                ),
                                TextField(
                                  controller: rCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Reps",
                                  ),
                                ),
                                TextField(
                                  controller: nCtrl,
                                  decoration: const InputDecoration(
                                    labelText: "Nota",
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(d),
                                child: const Text("CANCELAR"),
                              ),
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    editedExercises[i] = set.copyWith(
                                      weight:
                                          double.tryParse(wCtrl.text) ??
                                          set.weight,
                                      reps:
                                          double.tryParse(rCtrl.text) ??
                                          set.reps,
                                      note: nCtrl.text,
                                    );
                                  });
                                  Navigator.pop(d);
                                },
                                child: const Text("GUARDAR"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CANCELAR"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _sessions[index] = session.copyWith(
                      exercises: editedExercises,
                    );
                    _saveSessions();
                  });
                  Navigator.pop(c);
                },
                child: const Text(
                  "GUARDAR CAMBIOS",
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPercentTool() {
    final rmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          double rm = double.tryParse(rmCtrl.text) ?? 0;
          List<int> pcts = [95, 90, 85, 80, 75, 70, 60, 50];

          return AlertDialog(
            title: const Text("Tabla Porcentajes"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: rmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Tu 1RM (kg)"),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  if (rm > 0)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: pcts
                          .map(
                            (p) => Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    "$p%",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  Text(
                                    "${(rm * p / 100).round()}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text("CERRAR"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMacroTool() {
    final weightCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    String gender = 'Hombre';
    String activity = 'Moderado';
    String goal = 'Mantener';

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF121212),
            title: Row(
              children: [
                Icon(LucideIcons.beef, color: _accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  "CALCULAR MACROS",
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: "Peso (kg)",
                            labelStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: _cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: heightCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: "Altura (cm)",
                            labelStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: _cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ageCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: "Edad",
                      labelStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      filled: true,
                      fillColor: _cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _macroDropdown("Sexo", gender, [
                    'Hombre',
                    'Mujer',
                  ], (v) => setState(() => gender = v!)),
                  const SizedBox(height: 8),
                  _macroDropdown("Actividad", activity, [
                    'Sedentario',
                    'Ligero',
                    'Moderado',
                    'Intenso',
                    'Muy intenso',
                  ], (v) => setState(() => activity = v!)),
                  const SizedBox(height: 8),
                  _macroDropdown("Objetivo", goal, [
                    'Perder',
                    'Mantener',
                    'Ganar',
                  ], (v) => setState(() => goal = v!)),
                  const SizedBox(height: 16),
                  _buildMacroResult(
                    weightCtrl,
                    heightCtrl,
                    ageCtrl,
                    gender,
                    activity,
                    goal,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text(
                  "CERRAR",
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _macroDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1F2E),
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMacroResult(
    TextEditingController weightCtrl,
    TextEditingController heightCtrl,
    TextEditingController ageCtrl,
    String gender,
    String activity,
    String goal,
  ) {
    final w = double.tryParse(weightCtrl.text) ?? 0;
    final h = double.tryParse(heightCtrl.text) ?? 0;
    final a = int.tryParse(ageCtrl.text) ?? 0;
    if (w <= 0 || h <= 0 || a <= 0) {
      return const Text(
        "Completa los datos para ver resultados",
        style: TextStyle(color: Colors.white24, fontSize: 11),
      );
    }
    double bmr = gender == 'Hombre'
        ? (10 * w) + (6.25 * h) - (5 * a) + 5
        : (10 * w) + (6.25 * h) - (5 * a) - 161;
    double mult = {
      'Sedentario': 1.2,
      'Ligero': 1.375,
      'Moderado': 1.55,
      'Intenso': 1.725,
      'Muy intenso': 1.9,
    }[activity]!;
    double tdee = bmr * mult;
    if (goal == 'Perder') {
      tdee *= 0.85;
    }
    if (goal == 'Ganar') {
      tdee *= 1.15;
    }
    final protein = w * 2.0;
    final fat = tdee * 0.25 / 9;
    final carbs = (tdee - (protein * 4) - (fat * 9)) / 4;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            "TDEE: ${tdee.round()} kcal/día",
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroItem("Proteína", "${protein.round()}g", _accentColor),
              _macroItem(
                "Carbos",
                "${carbs.round().clamp(0, 9999)}g",
                Colors.orangeAccent,
              ),
              _macroItem("Grasa", "${fat.round()}g", Colors.pinkAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  // --- CONFIGURACIÓN ---
  Widget _buildFullSettings() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_isSessionActive) ...[
          TextButton.icon(
            onPressed: () => setState(() => _showSettings = false),
            icon: const Icon(LucideIcons.arrowLeft, size: 14),
            label: const Text('VOLVER AL ENTRENAMIENTO'),
          ),
          const SizedBox(height: 10),
        ],
        _settingTitle('DESCANSO ENTRE SERIES'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          margin: const EdgeInsets.only(top: 10, bottom: 25),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Text(
                '${_defaultRestSeconds}s',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.minus),
                onPressed: () => setState(() {
                  _defaultRestSeconds = (_defaultRestSeconds - 10).clamp(
                    30,
                    600,
                  );
                  _saveConfig();
                }),
              ),
              IconButton(
                icon: const Icon(LucideIcons.plus),
                onPressed: () => setState(() {
                  _defaultRestSeconds = (_defaultRestSeconds + 10).clamp(
                    30,
                    600,
                  );
                  _saveConfig();
                }),
              ),
            ],
          ),
        ),

        _settingTitle('MODO DE PLANIFICACIÓN'),
        Row(
          children: [
            _modeBtn('CICLO', 'sequential'),
            const SizedBox(width: 10),
            _modeBtn('CALENDARIO', 'calendar'),
          ],
        ),
        const SizedBox(height: 25),

        if (_plannerMode == 'calendar') ...[
          _settingTitle('ASIGNACIÓN POR DÍAS'),
          const SizedBox(height: 10),
          ..._weeklyPlan.keys.map((day) => _daySelector(day)),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _settingTitle('MANTENIMIENTO DE RUTINAS'),
              TextButton.icon(
                onPressed: _promptAddGroup,
                icon: Icon(LucideIcons.plus, size: 12, color: _accentColor),
                label: Text(
                  'AÑADIR NUEVA',
                  style: TextStyle(fontSize: 9, color: _accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._userGroups.asMap().entries.map(
            (entry) => _groupConfigCard(entry.key, entry.value),
          ),
        ],

        const SizedBox(height: 10),
        _settingTitle('ZONA DE PELIGRO / RECONFIGURACIÓN'),

        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
              side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: _saveCurrentAsTemplate,
            icon: const Icon(
              LucideIcons.save,
              size: 16,
              color: Colors.blueAccent,
            ),
            label: const Text(
              'GUARDAR ESTADO ACTUAL COMO PLANTILLA',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),

        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 5, bottom: 40),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (c) => _buildOnboarding(),
            ),
            icon: const Icon(
              LucideIcons.refreshCw,
              size: 16,
              color: Colors.redAccent,
            ),
            label: const Text(
              'REESTABLECER ESTRUCTURA BASE',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white38,
      letterSpacing: 1.5,
    ),
  );

  Widget _modeBtn(String l, String m) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _plannerMode = m;
        _saveConfig();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: _plannerMode == m ? _accentColor : _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            l,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ),
  );

  Widget _daySelector(String day) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(day, style: const TextStyle(fontSize: 12))),
        DropdownButton<String>(
          value: _weeklyPlan[day],
          underline: const SizedBox(),
          dropdownColor: _cardColor,
          items: ['DESCANSO', ..._userGroups]
              .map(
                (g) => DropdownMenuItem(
                  value: g,
                  child: Text(
                    g,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _weeklyPlan[day] = v!;
            _saveConfig();
          }),
        ),
      ],
    ),
  );

  Widget _groupConfigCard(int idx, String name) => Container(
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                LucideIcons.edit2,
                size: 16,
                color: Colors.white38,
              ),
              onPressed: () => _promptRenameGroup(name),
            ),
            IconButton(
              icon: const Icon(
                LucideIcons.trash2,
                size: 16,
                color: Colors.redAccent,
              ),
              onPressed: () => _promptDeleteGroup(idx, name),
            ),
            IconButton(
              icon: const Icon(LucideIcons.arrowUp, size: 16),
              onPressed: () => _moveGroup(idx, -1),
            ),
            IconButton(
              icon: const Icon(LucideIcons.arrowDown, size: 16),
              onPressed: () => _moveGroup(idx, 1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'EJERCICIOS ACTIVOS (MANTÉN PARA REORDENAR)',
          style: TextStyle(
            fontSize: 8,
            color: Colors.white24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        _reorderExercises(name, oldIndex, newIndex);
                      },
          children: [
            ...(_exerciseDb[name] ?? []).map(
              (ex) => ListTile(
                key: ValueKey("cfg-$name-$ex"),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  LucideIcons.gripVertical,
                  size: 14,
                  color: Colors.white10,
                ),
                title: Text(ex, style: const TextStyle(fontSize: 10)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        LucideIcons.edit2,
                        size: 12,
                        color: Colors.white38,
                      ),
                      onPressed: () => _renameExercise(name, ex),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 12,
                        color: Colors.redAccent,
                      ),
                      onPressed: () =>
                          _deleteExercisePermanently(name, ex, false),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.archive,
                        size: 12,
                        color: Colors.orangeAccent,
                      ),
                      onPressed: () => _archiveExercise(name, ex),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        TextButton.icon(
          onPressed: () => _promptAddExercise(name),
          icon: const Icon(LucideIcons.plus, size: 14),
          label: const Text("AÑADIR EJERCICIO", style: TextStyle(fontSize: 10)),
        ),

        if (_archivedExercises[name]?.isNotEmpty == true) ...[
          const SizedBox(height: 15),
          const Text(
            'ARCHIVADOS',
            style: TextStyle(
              fontSize: 8,
              color: Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _archivedExercises[name]!
                .map(
                  (ex) => GestureDetector(
                    onLongPress: () =>
                        _deleteExercisePermanently(name, ex, true),
                    onTap: () => _unarchiveExercise(name, ex),
                    child: Chip(
                      backgroundColor: Colors.white10,
                      label: Text(
                        ex,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white38,
                        ),
                      ),
                      avatar: const Icon(
                        LucideIcons.rotateCcw,
                        size: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    ),
  );

  void _promptRenameGroup(String oldName) {
    final ctrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('RENOMBRAR RUTINA'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nuevo nombre...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              _renameRoutine(oldName, ctrl.text);
              Navigator.pop(c);
            },
            child: Text('GUARDAR', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  void _promptAddExercise(String group) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('AÑADIR EJERCICIO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.database, color: _accentColor, size: 20),
              title: const Text(
                'BASE DE DATOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Buscar ejercicio con imagen',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              onTap: () {
                Navigator.pop(c);
                _promptFromDatabase(group);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: Icon(LucideIcons.pencil, color: _accentColor, size: 20),
              title: const Text(
                'ESCRIBIR EJERCICIO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Escribir nombre manualmente',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              onTap: () {
                Navigator.pop(c);
                _promptCustomExercise(group);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white24)),
          ),
        ],
      ),
    );
  }

  void _promptCustomExercise(String group) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('ESCRIBIR EJERCICIO'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nombre del ejercicio',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white24)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                String name = ctrl.text.trim().toUpperCase();
                setState(() {
                  _exerciseDb[group] ??= [];
                  if (!_exerciseDb[group]!.contains(name)) {
                    _exerciseDb[group]!.add(name);
                  }
                  _saveConfig();
                });
              }
              Navigator.pop(c);
            },
            child: Text('AÑADIR', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  void _promptFromDatabase(String group) {
    String searchQuery = '';
    String selectedGroup = 'TODOS';

    final allMuscleGroups = <String>{
      for (var entry in _globalExerciseList) _getMuscleGroupForExercise(entry),
    }.where((g) => g.isNotEmpty).toList();

    final List<String> muscleGroupFilter = ['TODOS', ...allMuscleGroups];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0E1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String stripAccents(String s) {
              return s
                  .replaceAll('Á', 'A').replaceAll('É', 'E')
                  .replaceAll('Í', 'I').replaceAll('Ó', 'O')
                  .replaceAll('Ú', 'U').replaceAll('Ü', 'U')
                  .replaceAll('Ñ', 'N');
            }

            final filtered = _globalExerciseList.where((ex) {
              final matchesSearch = searchQuery.isEmpty ||
                  stripAccents(ex.toUpperCase()).contains(stripAccents(searchQuery.toUpperCase()));
              final matchesGroup = selectedGroup == 'TODOS' ||
                  _getMuscleGroupForExercise(ex) == selectedGroup;
              return matchesSearch && matchesGroup;
            }).toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.database, color: _accentColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "BASE DE DATOS",
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${filtered.length} ejercicios",
                              style: const TextStyle(color: Colors.white24, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Buscar ejercicio...',
                            hintStyle: const TextStyle(color: Colors.white24),
                            prefixIcon: const Icon(LucideIcons.search, size: 16, color: Colors.white24),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onChanged: (v) => setSheetState(() => searchQuery = v),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: muscleGroupFilter.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final g = muscleGroupFilter[i];
                              final isSelected = selectedGroup == g;
                              return ChoiceChip(
                                label: Text(g, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.white54)),
                                selected: isSelected,
                                selectedColor: _accentColor,
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                onSelected: (_) => setSheetState(() => selectedGroup = g),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron ejercicios',
                              style: TextStyle(color: Colors.white24),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final ex = filtered[i];
                              final imgUrl = exerciseImages[ex];
                              final alreadyAdded = _exerciseDb[group]?.contains(ex) ?? false;
                              return GestureDetector(
                                onTap: alreadyAdded ? null : () {
                                  setState(() {
                                    _exerciseDb[group] ??= [];
                                    if (!_exerciseDb[group]!.contains(ex)) {
                                      _exerciseDb[group]!.add(ex);
                                    }
                                    _saveConfig();
                                  });
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: alreadyAdded
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: alreadyAdded
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: imgUrl != null
                                              ? SvgPicture.network(
                                                  imgUrl,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) => Icon(
                                                    LucideIcons.dumbbell,
                                                    size: 24,
                                                    color: Colors.white24,
                                                  ),
                                                )
                                              : Icon(
                                                  LucideIcons.dumbbell,
                                                  size: 24,
                                                  color: Colors.white24,
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                                        child: Text(
                                          ex,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                            color: alreadyAdded ? Colors.green : Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getMuscleGroupForExercise(String exercise) {
    final upper = exercise.toUpperCase();
    if (upper.contains('PRESS') || upper.contains('APERTURA') || upper.contains('PULL OVER') || upper.contains('PEC DECK') || upper.contains('CROSS OVER')) return 'PECHO';
    if (upper.contains('JALÓN') || upper.contains('REMO') || upper.contains('DOMINADA') || upper.contains('REMADOR') || upper.contains('SERRATO')) return 'ESPALDA';
    if (upper.contains('LATERAL') || upper.contains('FRONTAL') || upper.contains('FACE') || upper.contains('PÁJARO') || upper.contains('MILITAR') || upper.contains('UPRIGHT') || upper.contains('ARNOLD') || upper.contains('ELEVACIÓN')) return 'HOMBROS';
    if (upper.contains('CURL') || upper.contains('PREACHER')) return 'BÍCEPS';
    if (upper.contains('EXTENSIÓN') || upper.contains('TRICEPS') || upper.contains('PRESS FRANCES') || upper.contains('FONDOS') || upper.contains('SKULL') || upper.contains('KICKBACK') || upper.contains('PRESSESS')) return 'TRÍCEPS';
    if (upper.contains('SENTADILLA') || upper.contains('PRESS DE PIERNAS') || upper.contains('PENCHA') || upper.contains('PESO MUERTO')) return 'PIERNAS';
    if (upper.contains('FEMORAL') || upper.contains('NORDIC') || upper.contains('BUCHILLAS')) return 'PIERNAS';
    if (upper.contains('HIP THRUST') || upper.contains('ZANCADA') || upper.contains('STEP UP') || upper.contains('ABDUCCIÓN') || upper.contains('GLUTE') || upper.contains('PATADA')) return 'PIERNAS';
    if (upper.contains('PANTORRILLA') || upper.contains('ELEVACIÓN')) return 'PIERNAS';
    if (upper.contains('ADUCTOR') || upper.contains('ABDUCTOR')) return 'PIERNAS';
    if (upper.contains('CRUNCH') || upper.contains('PLANCHAS') || upper.contains('RUSSIAN') || upper.contains('LUMBAR') || upper.contains('AB') || upper.contains('LEG RAISE') || upper.contains('HOLLOW') || upper.contains('FRENCH') || upper.contains('MOUNTAIN') || upper.contains('DEAD BUG') || upper.contains('BIRD') || upper.contains('RKC')) return 'CENTRO';
    return 'OTROS';
  }

  void _promptAddGroup() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('NUEVA RUTINA / GRUPO'),
        backgroundColor: _cardColor,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej: BRAZO, PIERNA, FULL BODY...',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: _accentColor.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white24),
            ),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                String name = ctrl.text.toUpperCase();
                if (_userGroups.contains(name)) {
                  Navigator.pop(c);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("RUTINA YA EXISTENTE"),
                      content: Text(
                        "¿Quieres duplicar '$name' para hacer frecuencia 2?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CANCELAR"),
                        ),
                        TextButton(
                          onPressed: () {
                            String duplicateName = "$name 2";
                            setState(() {
                              _userGroups.add(duplicateName);
                              _exerciseDb[duplicateName] = List.from(
                                _exerciseDb[name] ?? [],
                              );
                              _saveConfig();
                            });
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            "DUPLICAR",
                            style: TextStyle(
                              color: _accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  setState(() {
                    _userGroups.add(name);
                    _exerciseDb[name] = [];
                    _saveConfig();
                  });
                  Navigator.pop(c);
                }
              }
            },
            child: Text('CREAR', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  void _promptDeleteGroup(int index, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿ELIMINAR GRUPO?'),
        content: Text('Esto quitará $name de tus rutinas activas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white24),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _userGroups.removeAt(index);
                _saveConfig();
              });
              Navigator.pop(c);
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkoutView() {
    final pb = _getPB(_selectedExercise);
    // historySets: Flattened list of ALL past sets for this exercise, ordered most recent first?
    // User said: "TODAS las series anteriores".
    // _getLastSessionSets only gets ONE session. We need accumulated history.
    // Let's filter _sessions for this exercise.
    // FIX V6: Carousel Scope - Show ONLY sets from the LAST session containing this exercise.
    List<ExerciseSet> historySets = [];
    try {
      // Find the most recent session that has this exercise
      // _sessions is sorted Old -> New by default? check _saveSessions.
      // Actually _sessions is usually appended to. So last is newest.
      // But let's search reversed to be sure.
      // FIX 6: Get NEWEST session (firstWhere on standard list finds newest if inserted at 0)
      // _sessions is ordered Newest -> Oldest (Index 0 is Newest, see _finishWorkout)
      final lastSession = _sessions.firstWhere(
        (s) =>
            s.exercises.any((e) => e.name == _selectedExercise.toUpperCase()),
      );
      historySets = lastSession.exercises
          .where((e) => e.name == _selectedExercise.toUpperCase())
          .toList();
    } catch (e) {
      // No history found
      historySets = [];
    }

    // FIX V6: Sort Chronologically (Set 1 -> Last)
    // _sessions usually has them in order of creation.
    // If we took them from a session object, they should be in order.
    // Just in case, ensuring they are not reversed.
    // historySets.sort((a,b) => ...); // Already in order of add.

    // Carousel Index Handling
    // If index is out of bounds (e.g. new history has fewer sets), reset.
    if (_historyCarouselIndex >= historySets.length) {
      _historyCarouselIndex = 0;
    }
    // Default order from _sessions is old->new (if using add).
    // For carousel we probably want New->Old? Or Standard Chronological?
    // User said "Desliza izquierda/derecha". A PageView usually starts at 0.
    // If we want "Last Set" to be visible first, we should start at `historySets.length - 1`.

    // Clear logic REMOVED from build to fix persistence bug.
    // _weightCtrl.clear();
    // _repsCtrl.clear();
    // _noteCtrl.clear();

    // Use historySets (all past sets) instead of lastSets (single session).
    // The Carousel handles display.

    // final activeExercises = ... (removing unused targetHistorySet logic)

    final activeExercises = _exerciseDb[_activeWorkoutType] ?? [];
    if (activeExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.orange),
            const Text(
              "Esta rutina no tiene ejercicios.",
              style: TextStyle(color: Colors.white),
            ),
            TextButton(
              onPressed: () => setState(() => _showSettings = true),
              child: const Text("AÑADIR EJERCICIOS"),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accentColor.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ENTRENANDO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _exitWorkout,
                    icon: const Icon(
                      LucideIcons.logOut,
                      color: Colors.white24,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _startRestTimer(),
                    icon: Icon(
                      LucideIcons.timer,
                      color: _accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    onTap: _finishWorkout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withValues(alpha: 0.2),
                            Colors.redAccent.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.check,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'FINALIZAR',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const Text(
                'TUS EJERCICIOS (MANTÉN PARA REORDENAR)',
                style: TextStyle(fontSize: 8, color: Colors.white24),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 45,
                child: ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        _reorderExercises(_activeWorkoutType, oldIndex, newIndex);
                      },
                  children: activeExercises
                      .map(
                        (ex) => GestureDetector(
                          key: ValueKey("active-$ex"),
                          onTap: () {
                            setState(() => _selectedExercise = ex);
                            _saveDraft();
                            // Clear inputs when selecting new exercise
                            _weightCtrl.clear();
                            _repsCtrl.clear();
                            _noteCtrl.clear();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedExercise == ex
                                  ? _accentColor
                                  : _cardColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedExercise == ex)
                                  const Icon(
                                    LucideIcons.gripVertical,
                                    size: 10,
                                    color: Colors.white38,
                                  ),
                                if (_selectedExercise == ex)
                                  const SizedBox(width: 4),
                                Text(
                                  ex,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_getPB(ex) != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    LucideIcons.trophy,
                                    size: 10,
                                    color: Colors.amber,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 15),
              // PINNED NOTE DISPLAY
              if (_selectedExercise.isNotEmpty)
                GestureDetector(
                  onTap: () => _promptEditNote(_selectedExercise),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _exerciseNotes.containsKey(_selectedExercise)
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _exerciseNotes.containsKey(_selectedExercise)
                            ? Colors.amber.withValues(alpha: 0.3)
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.stickyNote,
                          size: 16,
                          color: _exerciseNotes.containsKey(_selectedExercise)
                              ? Colors.amber
                              : Colors.white24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _exerciseNotes[_selectedExercise] ??
                                "Toque para añadir una nota fija (e.g. ajustes de máquina)...",
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _exerciseNotes.containsKey(_selectedExercise)
                                  ? Colors.amber.withValues(alpha: 0.9)
                                  : Colors.white24,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "HISTORIAL",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (pb != null) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.trophy,
                                      size: 10,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "RÉCORD: ${_formatNum(pb.weight)} KG x ${_formatNum(pb.reps)}",
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        // CAROUSEL NAV
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.chevronLeft,
                              size: 14,
                              color: _historyCarouselIndex > 0
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                            Text(
                              // FIX V8: Show Index of VIEWED set, not CURRENT active set.
                              " ${_historyCarouselIndex + 1}/${historySets.length} ",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color:
                                  _historyCarouselIndex < historySets.length - 1
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // CAROUSEL CONTENT (PageView)
                    SizedBox(
                      height: 120, // Fixed height for carousel
                      child: PageView.builder(
                        controller: _historyPageController,
                        itemCount: historySets.length,
                        reverse:
                            false, // Set 1 is Left (Page 0). Swipe Right -> Set 2.
                        onPageChanged: (idx) {
                          setState(() => _historyCarouselIndex = idx);
                        },
                        itemBuilder: (context, idx) {
                          // We want to show sets in some order.
                          // historySets is usually filtered from _getLastSessionSets which returns LIST.
                          // Actually, user wants "Desliza izquierda/derecha para ver TODAS las series anteriores".
                          // _getLastSessionSets only returns one session. We might need MORE.
                          // If they mean "sets from ALL sessions", that's a lot of data.
                          // "ver anteriores o posteriores series del ultimo entreno". ok, Last Session is enough.

                          final hSet = historySets[idx];

                          return GestureDetector(
                            onTap: () {
                              // "Smart Copy" logic handled by buttons below now
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: _accentColor.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "SERIE ${idx + 1} (${hSet.date.day}/${hSet.date.month})",
                                    style: TextStyle(
                                      color: _accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "${_formatNum(hSet.weight)}kg x ${_formatNum(hSet.reps)}",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (hSet.note.isNotEmpty)
                                    Text(
                                      "Nota: ${hSet.note}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // SMART COPY BUTTONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (historySets.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              minimumSize: const Size(0, 30),
                            ),
                            icon: const Icon(LucideIcons.copy, size: 12),
                            label: Text(
                              "COPIAR: ${_formatNum(historySets[_historyCarouselIndex].weight)}kg",
                              style: const TextStyle(fontSize: 10),
                            ),
                            onPressed: () {
                              setState(() {
                                String val = _formatNum(
                                  historySets[_historyCarouselIndex].weight,
                                );
                                _weightCtrl.value = TextEditingValue(
                                  text: val,
                                  selection: TextSelection.collapsed(
                                    offset: val.length,
                                  ),
                                );
                              });
                            },
                          ),
                        const SizedBox(width: 10),
                        // FIX V7: Show button even if nextWeight is arguably null to debug, OR relax condition.
                        // Ideally we want to show it if we have a suggestion.
                        // Let's assume historySets.last is the "previous session" reference.
                        // FIX V9: Dynamic Suggested Weight
                        // Use the suggestion from the VIEWED set (carousel index), not just the last one.
                        if (historySets.isNotEmpty &&
                            _historyCarouselIndex < historySets.length &&
                            historySets[_historyCarouselIndex].nextWeight !=
                                null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor.withValues(
                                alpha: 0.2,
                              ),
                              foregroundColor: _accentColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              minimumSize: const Size(0, 30),
                            ),
                            icon: const Icon(LucideIcons.trendingUp, size: 12),
                            label: Text(
                              "SUGERIDO: ${_formatNum(historySets[_historyCarouselIndex].nextWeight!)}kg",
                              style: const TextStyle(fontSize: 10),
                            ),
                            onPressed: () {
                              setState(() {
                                if (historySets.isNotEmpty &&
                                    _historyCarouselIndex <
                                        historySets.length &&
                                    historySets[_historyCarouselIndex]
                                            .nextWeight !=
                                        null) {
                                  _weightCtrl.value = TextEditingValue(
                                    text: _formatNum(
                                      historySets[_historyCarouselIndex]
                                          .nextWeight!,
                                    ),
                                    selection: TextSelection.collapsed(
                                      offset: _formatNum(
                                        historySets[_historyCarouselIndex]
                                            .nextWeight!,
                                      ).length,
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              Row(
                children: [
                  _numInput(_weightCtrl, 'PESO'),
                  const SizedBox(width: 15),
                  _numInput(_repsCtrl, 'REPS'),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'OPINIÓN / NOTA DE LA SERIE',
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ADJUSTMENT UI 2.0 (Updated)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<double>(
                    onSelected: (val) {
                      setState(() {
                        _adjustmentIncrement = val;
                      });
                    },
                    itemBuilder: (c) => [
                      const PopupMenuItem(
                        value: 0.0,
                        child: Text(
                          "MANTENER PESO",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 1.25,
                        child: Text(
                          "+ 1.25 kg",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 2.5,
                        child: Text(
                          "+ 2.5 kg",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 5.0,
                        child: Text(
                          "+ 5.0 kg",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 10.0,
                        child: Text(
                          "+ 10.0 kg",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: -1.25,
                        child: Text(
                          "- 1.25 kg",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const PopupMenuItem(
                        value: -2.5,
                        child: Text(
                          "- 2.5 kg",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const PopupMenuItem(
                        value: -5.0,
                        child: Text(
                          "- 5.0 kg",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _adjustmentIncrement == 0
                            ? _cardColor
                            : (_adjustmentIncrement > 0
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _adjustmentIncrement == 0
                              ? Colors.white24
                              : (_adjustmentIncrement > 0
                                    ? Colors.green
                                    : Colors.red),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _adjustmentIncrement == 0
                                ? LucideIcons.minus
                                : (_adjustmentIncrement > 0
                                      ? LucideIcons.trendingUp
                                      : LucideIcons.trendingDown),
                            size: 16,
                            color: _adjustmentIncrement == 0
                                ? Colors.white
                                : (_adjustmentIncrement > 0
                                      ? Colors.green
                                      : Colors.red),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _adjustmentIncrement == 0
                                ? "PROX: MANTENER"
                                : (_adjustmentIncrement > 0
                                      ? "+ ${_formatNum(_adjustmentIncrement)} KG"
                                      : "- ${_formatNum(_adjustmentIncrement.abs())} KG"),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _adjustmentIncrement == 0
                                  ? Colors.white
                                  : (_adjustmentIncrement > 0
                                        ? Colors.green
                                        : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PressableScale(
                onTap: _addSet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accentColor.withValues(alpha: 0.8),
                        _accentColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.check, size: 18, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'GUARDAR SERIE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // LISTA DE SERIES ACTUALES
              ..._currentSessionExercises.asMap().entries.map((entry) {
                int idx = entry.key;
                ExerciseSet s = entry.value;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + idx * 50),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 15 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: PressableScale(
                    onTap: () => _promptEditSet(idx),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _cardColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "#${idx + 1}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${s.name}: ${_formatNum(s.weight)}kg x ${_formatNum(s.reps)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                LucideIcons.edit2,
                                size: 10,
                                color: Colors.white12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.time,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                          if (s.note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                s.note,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _exitWorkout() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿SALIR?'),
        content: const Text(
          'Se guardará un borrador para que puedas continuar luego.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () async {
              _clearDraft();
              _restTimer?.cancel();
              await _notificationsPlugin.cancelAll();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('timer_end_time');
              setState(() {
                _isSessionActive = false;
                _currentSessionExercises.clear();
                _showTimer = false;
                _isTimerExpanded = false;
                _workoutStartTime = null;
              });
              Navigator.pop(c);
            },
            child: const Text(
              'BORRAR TODO',
              style: TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _saveDraft();
              _restTimer?.cancel();
              await _notificationsPlugin.cancelAll();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('timer_end_time');
              setState(() {
                _isSessionActive = false;
                _showTimer = false;
                _isTimerExpanded = false;
              });
              Navigator.pop(c);
            },
            child: Text(
              'SALIR Y GUARDAR',
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _finishWorkout() async {
    _restTimer?.cancel();
    await _notificationsPlugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_end_time');

    if (_currentSessionExercises.isNotEmpty) {
      _sessions.insert(
        0,
        TrainingSession(
          id: DateTime.now().toString(),
          type: _activeWorkoutType,
          exercises: List.from(_currentSessionExercises),
          date: DateTime.now(),
        ),
      );
      await _saveSessions();

      final synced = await _syncDataToFirestore(showFeedback: false);
      if (!synced) {
        await prefs.setBool('pending_sync', true);
      }
    }
    _clearDraft();
    setState(() {
      _currentSessionExercises.clear();
      _isSessionActive = false;
      _activeTab = 1;
      _showTimer = false;
      _isTimerExpanded = false;
      _workoutStartTime = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(1);
        }
      });
    });
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'trainer_sessions',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  Map<String, String> _getSuggestion() {
    if (_plannerMode == 'calendar') {
      final days = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      String dayName = days[DateTime.now().weekday - 1];
      String task = _weeklyPlan[dayName] ?? 'DESCANSO';
      return {'type': task, 'reason': 'Hoy es $dayName'};
    } else {
      if (_sessions.isEmpty || _userGroups.isEmpty) {
        return {
          'type': _userGroups.isNotEmpty ? _userGroups[0] : 'CREA UNA RUTINA',
          'reason': 'Comienza hoy',
        };
      }
      String lastType = _sessions[0].type;
      int lastIdx = _userGroups.indexOf(lastType);
      if (lastIdx == -1) {
        return {'type': _userGroups[0], 'reason': 'Nueva rutina'};
      }
      int nextIdx = (lastIdx + 1) % _userGroups.length;
      return {'type': _userGroups[nextIdx], 'reason': 'Siguiente en el ciclo'};
    }
  }

  void _editHistorySet(TrainingSession session, ExerciseSet set) {
    final wCtrl = TextEditingController(text: _formatNum(set.weight));
    final rCtrl = TextEditingController(text: _formatNum(set.reps));
    final nCtrl = TextEditingController(text: set.note);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("EDITAR SERIE HOLA"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              decoration: const InputDecoration(labelText: "Peso"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: rCtrl,
              decoration: const InputDecoration(labelText: "Reps"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: nCtrl,
              decoration: const InputDecoration(labelText: "Nota"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // Update set values
                // Since 'set' is a reference to the object in the list, we can't just replace fields if it's immutable.
                // ExerciseSet is immutable. We need to replace it in the list.
                int idx = session.exercises.indexOf(set);
                if (idx != -1) {
                  session.exercises[idx] = set.copyWith(
                    weight: double.tryParse(wCtrl.text) ?? set.weight,
                    reps: double.tryParse(rCtrl.text) ?? set.reps,
                    note: nCtrl.text,
                  );
                  _saveSessions();
                }
              });
              Navigator.pop(c);
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }
  // --- RESTORED METHODS ---

  Widget _buildHistoryTab() {
    return _sessions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.calendarX,
                  color: Colors.white.withValues(alpha: 0.1),
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'SIN ACTIVIDAD',
                  style: TextStyle(
                    color: Colors.white12,
                    fontSize: 10,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _sessions.length,
            itemBuilder: (c, i) {
              final session = _sessions[i];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + i * 50),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ExpansionTile(
                    maintainState: true,
                    iconColor: _accentColor,
                    title: Text(
                      session.type,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "${session.date.day}/${session.date.month} - ${session.exercises.length} series",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white24,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            LucideIcons.edit,
                            size: 16,
                            color: _accentColor.withValues(alpha: 0.6),
                          ),
                          onPressed: () => _showSessionOptions(i),
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.copy,
                            size: 16,
                            color: Colors.white38,
                          ),
                          onPressed: () {
                            String summary =
                                "ENTRENAMIENTO: ${session.type} (${session.date.day}/${session.date.month})\n";
                            for (var ex in session.exercises) {
                              summary +=
                                  "- ${ex.name}: ${_formatNum(ex.weight)}kg x ${_formatNum(ex.reps)}";
                              if (ex.note.isNotEmpty) {
                                summary += " [${ex.note}]";
                              }
                              summary += "\n";
                            }
                            Clipboard.setData(ClipboardData(text: summary));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: _accentColor,
                                content: const Text(
                                  "Resumen copiado al portapapeles",
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 16,
                            color: Colors.white24,
                          ),
                          onPressed: () => _deleteSession(i),
                        ),
                      ],
                    ),
                    children: session.exercises
                        .map(
                          (s) => ListTile(
                            dense: true,
                            onLongPress: () => _editHistorySet(session, s),
                            title: Text(
                              "${s.name}: ${_formatNum(s.weight)}kg x ${_formatNum(s.reps)}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Text(
                              s.time,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white12,
                              ),
                            ),
                            subtitle: s.note.isNotEmpty
                                ? Text(
                                    "Nota: ${s.note}",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          );
  }

  // --- PESTAÑA 3: PROGRESO CON GRÁFICA FL_CHART ---
  Widget _buildStatsTab() {
    return Column(
      children: [
        // INTERRUPTOR DE MODO DE GRÁFICA
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _statsUseFirstSet ? "PRIMERA SERIE" : "TODAS LAS SERIES",
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: _statsUseFirstSet,
                activeThumbColor: _accentColor,
                onChanged: (val) {
                  setState(() {
                    _statsUseFirstSet = val;
                  });
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: _userGroups
                .map(
                  (g) => Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ExpansionTile(
                      maintainState: true,
                      title: Text(
                        g,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: (_exerciseDb[g] ?? []).map((ex) {
                        final pb = _getPB(ex);
                        final history = _sessions
                            .expand((s) => s.exercises)
                            .where((e) => e.name == ex.toUpperCase())
                            .toList();
                        // Ordenar historial cronológicamente (antiguo -> nuevo) para la gráfica,
                        // pero reversed para la lista se maneja dentro de _buildStatDetail
                        history.sort(
                          (a, b) => a.date.compareTo(b.date),
                        ); // Ensure chronological for graph
                        return _buildStatDetail(ex, pb, history);
                      }).toList(),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDetail(
    String ex,
    ExerciseSet? pb,
    List<ExerciseSet> history,
  ) {
    // PREPARAR DATOS PARA LA GRÁFICA
    List<FlSpot> spots = [];

    // Lista para el historial visual (filtrada según switch)
    List<dynamic> historyDisplayItems = [];

    if (history.isNotEmpty) {
      // 1. Agrupar por fecha
      Map<String, List<ExerciseSet>> setsByDate = {};

      // Ordenar historial cronológicamente (antiguo -> nuevo) para la gráfica
      List<ExerciseSet> sortedHistory = List.from(history);
      sortedHistory.sort((a, b) => a.date.compareTo(b.date));

      for (var s in sortedHistory) {
        String dateKey = "${s.date.year}-${s.date.month}-${s.date.day}";
        setsByDate.putIfAbsent(dateKey, () => []);
        setsByDate[dateKey]!.add(s);
      }

      int xIndex = 0;
      setsByDate.forEach((key, sets) {
        double yValue = 0;

        if (_statsUseFirstSet) {
          // MODO PRIMERA SERIE
          yValue = sets.first.effectiveScore;
          historyDisplayItems.add(
            sets.first,
          ); // Añadir solo la primera serie a la lista visual
        } else {
          // MODO TODAS LAS SERIES
          yValue = sets.fold(0.0, (acc, item) => acc + item.effectiveScore);

          // Guardar TODAS las series para mostrarlas
          historyDisplayItems.add({
            'date': sets.first.date,
            'sets': sets, // Pasamos la lista completa de series
            'totalScore': yValue,
          });
        }

        spots.add(FlSpot(xIndex.toDouble(), yValue));
        xIndex++;
      });

      // FIX 3: Ensure we have at least 2 spots or handle single point to prevent crash/empty
      if (spots.length == 1) {
        // Add a "zero" point before it so a line can be drawn?
        // Or just show the point. FlChart handles single points but might look empty.
        // Let's ensure x-axis starts at 0.
      }
    }

    return ExpansionTile(
      maintainState: true,
      title: Text(
        ex,
        style: const TextStyle(fontSize: 11, color: Colors.white60),
      ),
      trailing: Text(
        pb != null
            ? "${_formatNum(pb.weight)}kg x ${_formatNum(pb.reps)}"
            : "-",
        style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
      ),
      children: [
        if (spots.isNotEmpty) ...[
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _accentColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: Colors.white,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _accentColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Sin datos.", style: TextStyle(color: Colors.white24)),
          ),

        // HISTORIAL DEBAJO DE LA GRÁFICA (Adaptado)
        if (historyDisplayItems.isNotEmpty) ...[
          const Divider(color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _statsUseFirstSet
                  ? "HISTORIAL (Solo 1ª Serie)"
                  : "HISTORIAL (Todas las series)",
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Invertimos la lista para mostrar lo más reciente arriba
          ...historyDisplayItems.reversed.take(5).map((item) {
            if (item is ExerciseSet) {
              // MODO PRIMERA SERIE
              return ListTile(
                dense: true,
                title: Text(
                  "${_formatNum(item.weight)}kg x ${_formatNum(item.reps)}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "${item.date.day}/${item.date.month} - 1ª Serie",
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              );
            } else {
              // MODO TODAS LAS SERIES (Desglose completo)
              Map<String, dynamic> data = item as Map<String, dynamic>;
              DateTime d = data['date'];
              List<ExerciseSet> daySets = data['sets'];

              // Crear string con todas las series: "60x10, 60x10, 50x8..."
              String setsString = daySets
                  .map((s) => "${_formatNum(s.weight)}x${_formatNum(s.reps)}")
                  .join(", ");

              return ListTile(
                dense: true,
                title: Text(
                  setsString,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  "${d.day}/${d.month} - Score Total: ${_formatNum(data['totalScore'])}",
                  style: TextStyle(fontSize: 10, color: _accentColor),
                ),
              );
            }
          }),
        ],
      ],
    );
  }

  // --- PESTAÑA CHATBOT ---
  Widget _buildChatTab() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.messageCircle, size: 14, color: _accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _chatConversations.length > 1
                        ? (_chatConversations.firstWhere(
                                (c) => c['id'] == _currentConversationId,
                                orElse: () => {'title': 'ENTRENADOR IA'},
                              )['title'] ??
                              'ENTRENADOR IA')
                        : "ENTRENADOR IA",
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _showApiSettings,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _useCustomApiKey
                          ? Colors.greenAccent.withValues(alpha: 0.15)
                          : _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _useCustomApiKey ? LucideIcons.key : LucideIcons.settings,
                      size: 16,
                      color: _useCustomApiKey
                          ? Colors.greenAccent
                          : _accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showConversationsList,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.messageSquarePlus,
                      size: 16,
                      color: _accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _newConversation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: _chatMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.messageCircle,
                          size: 48,
                          color: Colors.white10,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Pregúntame sobre\nentrenamiento y nutrición",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white24, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _chatMessages[index];
                      final isUser = msg['role'] == 'user';
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? _accentColor.withValues(alpha: 0.2)
                                  : _cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isUser
                                    ? _accentColor.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: _buildRichText(msg['content'] ?? '', isUser),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_chatLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _ThinkingDot(
                            delay: i * 200,
                            color: _accentColor,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 36,
            ),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre entrenamiento...',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: _cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PressableScale(
                    onTap: _sendChatMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.send,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text, bool isUser) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _buildChatContext() {
    final buffer = StringBuffer();
    buffer.writeln('=== DATOS DEL USUARIO ===');

    buffer.writeln(
      '\nGrupos musculares configurados: ${_userGroups.isEmpty ? "Ninguno" : _userGroups.join(", ")}',
    );

    if (_exerciseDb.isNotEmpty) {
      buffer.writeln('\nEjercicios por grupo:');
      for (var entry in _exerciseDb.entries) {
        if (entry.value.isNotEmpty) {
          buffer.writeln('- ${entry.key}: ${entry.value.join(", ")}');
        }
      }
    }

    if (_customTemplates.isNotEmpty) {
      buffer.writeln('\nRutinas personalizadas:');
      for (var entry in _customTemplates.entries) {
        buffer.writeln('- ${entry.key}');
        final t = entry.value;
        for (var tEntry in t.entries) {
          if (tEntry.key != 'id' && tEntry.value != null) {
            buffer.writeln('  ${tEntry.key}: ${tEntry.value}');
          }
        }
      }
    }

    buffer.writeln('\nPlan semanal:');
    for (var day in _weeklyPlan.entries) {
      buffer.writeln('- ${day.key}: ${day.value}');
    }

    if (_sessions.isNotEmpty) {
      buffer.writeln(
        '\nHistorial de entrenamientos (${_sessions.length} sesiones):',
      );
      final recent = _sessions.take(10);
      for (var s in recent) {
        final exercises = s.exercises;
        final exerciseSummary = <String, List<String>>{};
        for (var e in exercises) {
          exerciseSummary.putIfAbsent(e.name, () => []);
          exerciseSummary[e.name]!.add(
            '${e.weight}kg x ${e.reps.toInt()} reps${e.note.isNotEmpty ? " (${e.note})" : ""}',
          );
        }
        buffer.writeln(
          '- ${s.type} (${s.date.day}/${s.date.month}/${s.date.year}):',
        );
        for (var ex in exerciseSummary.entries) {
          buffer.writeln('  ${ex.key}: ${ex.value.join(" | ")}');
        }
      }

      buffer.writeln('\nMejores marcas por ejercicio:');
      final Map<String, double> bestWeights = {};
      for (var s in _sessions) {
        for (var e in s.exercises) {
          if (!bestWeights.containsKey(e.name) ||
              e.weight > bestWeights[e.name]!) {
            bestWeights[e.name] = e.weight;
          }
        }
      }
      for (var entry in bestWeights.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}kg');
      }
    } else {
      buffer.writeln('\nSin historial de entrenamientos.');
    }

    return buffer.toString();
  }

  Future<void> _sendChatMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _chatLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    _chatInputController.clear();

    setState(() {
      _chatMessages.add({'role': 'user', 'content': text});
      _chatLoading = true;
    });
    _saveChatHistory();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final activeApiKey = _useCustomApiKey && _customApiKey.isNotEmpty
          ? _customApiKey
          : _geminiApiKey;
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=${Uri.encodeComponent(activeApiKey)}',
      );

      List<Map<String, dynamic>> contents = [];
      for (var msg in _chatMessages) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['content']},
          ],
        });
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'systemInstruction': {
            'parts': [
              {
                'text':
                    'Eres un experto en fitness, entrenamiento de fuerza, nutrición deportiva y salud. Respondes en español, de forma concisa y práctica. Usas **negrita** para resaltar puntos importantes. Si te preguntan algo que no es sobre fitness, redirige amablemente al tema.\n\nAquí tienes los datos del usuario para dar consejos personalizados:\n${_buildChatContext()}',
              },
            ],
          },
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 8192},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        try {
          final candidates = data['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            final candidate = candidates[0];
            if (candidate is Map<String, dynamic>) {
              final content = candidate['content'];
              if (content is Map<String, dynamic>) {
                final parts = content['parts'];
                if (parts is List && parts.isNotEmpty) {
                  final part = parts[0];
                  if (part is Map<String, dynamic>) {
                    final reply =
                        part['text'] ?? 'No pude generar una respuesta.';
                    setState(() {
                      _chatMessages.add({
                        'role': 'model',
                        'content': reply.toString(),
                      });
                      _chatLoading = false;
                    });
                    _saveChatHistory();
                  } else {
                    setState(() {
                      _chatMessages.add({
                        'role': 'model',
                        'content': 'Formato inesperado en partes.',
                      });
                      _chatLoading = false;
                    });
                  }
                } else {
                  setState(() {
                    _chatMessages.add({
                      'role': 'model',
                      'content': 'Respuesta vacía de Gemini.',
                    });
                    _chatLoading = false;
                  });
                }
              } else {
                setState(() {
                  _chatMessages.add({
                    'role': 'model',
                    'content': 'Sin contenido en la respuesta.',
                  });
                  _chatLoading = false;
                });
              }
            } else {
              setState(() {
                _chatMessages.add({
                  'role': 'model',
                  'content': 'Formato de candidato inesperado.',
                });
                _chatLoading = false;
              });
            }
          } else {
            setState(() {
              _chatMessages.add({
                'role': 'model',
                'content': 'Sin candidatos en la respuesta.',
              });
              _chatLoading = false;
            });
          }
        } catch (parseError) {
          setState(() {
            _chatMessages.add({
              'role': 'model',
              'content': 'Error al procesar respuesta: $parseError',
            });
            _chatLoading = false;
          });
        }
      } else {
        String errorMsg = 'Error ${response.statusCode}';
        try {
          final errData = jsonDecode(response.body);
          errorMsg = errData['error']['message'] ?? errorMsg;
        } catch (_) {}
        if (errorMsg.contains('authentication') ||
            errorMsg.contains('credential')) {
          errorMsg =
              'API Key inválida. Verifica que:\n1. La key sea de Google AI Studio (aistudio.google.com)\n2. Esté habilitada la API "Generative Language"\n3. No tenga espacios extra';
        }
        setState(() {
          _chatMessages.add({'role': 'model', 'content': 'Error: $errorMsg'});
          _chatLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'role': 'model',
          'content': 'Error de conexión: $e',
        });
        _chatLoading = false;
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiSettings() {
    final customKeyCtrl = TextEditingController(text: _customApiKey);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.key, size: 18, color: _accentColor),
                      const SizedBox(width: 8),
                      Text(
                        "CONFIGURACIÓN API",
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        RadioGroup<bool>(
                          groupValue: _useCustomApiKey,
                          onChanged: (v) => setSheetState(
                            () => _useCustomApiKey = v ?? false,
                          ),
                          child: Column(
                            children: [
                              RadioListTile<bool>(
                                value: false,
                                title: const Text(
                                  "API de la app",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  "Usar la API integrada de la app",
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                                activeColor: _accentColor,
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 1),
                              RadioListTile<bool>(
                                value: true,
                                title: const Text(
                                  "Mi propia API Key",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: const Text(
                                  "Usar tu propia clave de Google AI Studio",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                                activeColor: _accentColor,
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_useCustomApiKey) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customKeyCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: _cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Obtén tu clave gratis en aistudio.google.com/api-key",
                      style: TextStyle(color: Colors.white24, fontSize: 9),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _customApiKey = customKeyCtrl.text.trim();
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        "GUARDAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConversationsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.messagesSquare,
                          size: 16,
                          color: _accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "CONVERSACIONES",
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _newConversation();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.plus,
                              size: 14,
                              color: _accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _chatConversations.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "No hay conversaciones",
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _chatConversations.length,
                            itemBuilder: (context, i) {
                              final conv = _chatConversations[i];
                              final isActive =
                                  conv['id'] == _currentConversationId;
                              final msgCount =
                                  ((conv['messages'] as List?)
                                      ?.where((m) => m['role'] == 'user')
                                      .toList()
                                      .length) ??
                                  0;
                              final title = conv['title'] ?? 'Sin título';
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 3,
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _loadConversation(conv['id']);
                                  },
                                  onLongPress: () {
                                    _showConversationOptions(
                                      ctx,
                                      conv['id'],
                                      title,
                                    );
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  tileColor: isActive
                                      ? _accentColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  leading: Icon(
                                    LucideIcons.messageCircle,
                                    size: 16,
                                    color: isActive
                                        ? _accentColor
                                        : Colors.white24,
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      color: isActive
                                          ? _accentColor
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    "$msgCount preguntas",
                                    style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 10,
                                    ),
                                  ),
                                  trailing: isActive
                                      ? Icon(
                                          LucideIcons.check,
                                          size: 14,
                                          color: _accentColor,
                                        )
                                      : Icon(
                                          LucideIcons.chevronRight,
                                          size: 14,
                                          color: Colors.white24,
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConversationOptions(
    BuildContext ctx,
    String id,
    String currentTitle,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  LucideIcons.pencil,
                  color: _accentColor,
                  size: 18,
                ),
                title: const Text(
                  "Renombrar",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(c);
                  Navigator.pop(ctx);
                  _showRenameDialog(id, currentTitle);
                },
              ),
              ListTile(
                leading: const Icon(
                  LucideIcons.trash2,
                  color: Colors.redAccent,
                  size: 18,
                ),
                title: const Text(
                  "Eliminar",
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(c);
                  Navigator.pop(ctx);
                  _deleteConversation(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(String id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          "RENOMBRAR",
          style: TextStyle(
            color: _accentColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Nombre de la conversación",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: _accentColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "CANCELAR",
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _renameConversation(id, ctrl.text.trim());
            },
            child: Text("GUARDAR", style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  int _labelToPage(String label) {
    switch (label) {
      case 'HOY':
        return 0;
      case 'HISTORIAL':
        return 1;
      case 'PROGRESO':
        return 2;
      case 'TOOLS':
        return 3;
      case 'CHAT':
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildBottomNav() {
    final navItems = _navItems
        .map(
          (e) => AnimatedNavItem(
            icon: _iconFromString(e['icon'] ?? 'play'),
            label: e['label'] ?? 'HOY',
          ),
        )
        .toList();

    final currentPageLabel = _navItems.firstWhere(
      (e) => _labelToPage(e['label']) == _activeTab,
      orElse: () => _navItems[0],
    )['label'];
    final resolvedIndex = navItems.indexWhere(
      (e) => e.label == currentPageLabel,
    );
    final activeIdx = resolvedIndex >= 0 ? resolvedIndex : 0;

    return AnimatedBottomNav(
      currentIndex: activeIdx,
      accentColor: _accentColor,
      items: navItems,
      onTap: (i) {
        final pageIdx = _labelToPage(navItems[i].label);
        if (_isSessionActive) {
          _saveDraft();
        }
        setState(() {
          _activeTab = pageIdx;
          _showSettings = false;
        });
        _pageController.animateToPage(
          pageIdx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      },
    );
  }

  Widget _numInput(TextEditingController ctrl, String label) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  void _startWorkout(String type) {
    setState(() {
      _activeWorkoutType = type;
      _currentSessionExercises = [];
      _isSessionActive = true;
      _showSettings = false;
      _workoutStartTime = DateTime.now();
      var exList = _exerciseDb[type];
      if (exList != null && exList.isNotEmpty) {
        _selectedExercise = exList[0];
      } else {
        _selectedExercise = '';
        _selectedExercise = '';
      }
      _weightCtrl.clear();
      _repsCtrl.clear();
      _noteCtrl.clear();
      _saveDraft();
    });
  }

  void _deleteSession(int index) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿ELIMINAR SESIÓN?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sessions.removeAt(index);
                _saveSessions();
              });
              Navigator.pop(c);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUnifiedShareDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          "COMPARTIR",
          style: TextStyle(color: _accentColor, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.playCircle, color: Colors.white),
              title: const Text(
                "Rutina Actual / Completa",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              subtitle: const Text(
                "Comparte toda tu estructura activa",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              onTap: () {
                Navigator.pop(c);
                _shareFullStructure();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.save, color: Colors.white),
              title: const Text(
                "Rutina Guardada",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              subtitle: const Text(
                "Elige una plantilla de tus guardadas",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              onTap: () {
                Navigator.pop(c);
                _shareSingleRoutine();
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.calendar, color: Colors.white),
              title: const Text(
                "Grupo Muscular (Día)",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              subtitle: const Text(
                "Ej: Solo 'Pecho'",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              onTap: () {
                Navigator.pop(c);
                _showExportDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CANCELAR"),
          ),
        ],
      ),
    );
  }

  void _showSessionOptions(int index) {
    final session = _sessions[index];
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          "OPCIONES DE SESIÓN",
          style: TextStyle(color: _accentColor, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.calendar, color: Colors.white),
              title: const Text(
                "Cambiar Fecha",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                showDatePicker(
                  context: context,
                  initialDate: session.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                ).then((picked) {
                  if (picked != null) {
                    setState(() {
                      _sessions[index] = session.copyWith(date: picked);
                      _saveSessions();
                    });
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.edit3, color: Colors.white),
              title: const Text(
                "Renombrar Tipo",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                final ctrl = TextEditingController(text: session.type);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("RENOMBRAR SESIÓN"),
                    content: TextField(controller: ctrl),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("CANCELAR"),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _sessions[index] = session.copyWith(
                              type: ctrl.text.toUpperCase(),
                            );
                            _saveSessions();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text("GUARDAR"),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.list, color: Colors.blueAccent),
              title: const Text(
                "Editar Contenido",
                style: TextStyle(color: Colors.blueAccent, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                _showEditSessionContent(index);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
              title: const Text(
                "Eliminar Sesión",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(c);
                _deleteSession(index);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CERRAR"),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDot extends StatefulWidget {
  final int delay;
  final Color color;
  const _ThinkingDot({required this.delay, required this.color});

  @override
  State<_ThinkingDot> createState() => _ThinkingDotState();
}

class _ThinkingDotState extends State<_ThinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

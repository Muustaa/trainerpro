import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

final Map<String, String> exerciseImages = {
  'PRESS BANCA': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/bench-press.png',
  'PRESS INCLINADO': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/incline-bench-press.png',
  'SENTADILLA': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/squat.png',
  'PESO MUERTO': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/deadlift.png',
  'DOMINADAS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/pull-up.png',
  'REMO CON BARRA': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/barbell-row.png',
  'PRESS MILITAR': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/overhead-press.png',
  'CURL DE BÍCEPS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/bicep-curl.png',
  'EXTENSIÓN DE TRÍCEPS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/tricep-extension.png',
  'LATERALES': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/lateral-raise.png',
  'JALÓN AL PECHO': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/lat-pulldown.png',
  'HIP THRUST': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/hip-thrust.png',
  'EXTENSIÓN DE CUÁDRICEPS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/leg-extension.png',
  'FEMORAL TUMBADO': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/leg-curl.png',
  'ELEVACIÓN DE PANTORRILLAS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/calf-raise.png',
  'ZANCADAS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/lunges.png',
  'APERTURAS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/fly.png',
  'REMO POLEA BAJA': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/seated-row.png',
  'FACE PULL': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/face-pull.png',
  'FONDOS DE TRÍCEPS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/dips.png',
  'AB wheel': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/ab-wheel.png',
  'CRUNCH': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/crunch.png',
  'PLANCHAS': 'https://raw.githubusercontent.com/nicklockwood/FXForms/master/Examples/Weights/static/img/plank.png',
};

String? buildExerciseImage(String name) {
  return exerciseImages[name.toUpperCase()];
}

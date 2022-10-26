import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'main.dart' show getHashCode;
import 'run.dart';

class Global {
  String defaultStart;
  double desiredMargin;
  double maxMargin;
  bool justDown;
  String runStartInput;
  bool timePace;
  bool darkMode;
  int minRuns;
  String outAndBack;
  String type;
  bool warmUp;
  List<String> oBValues = ["Loops", "Both", "Out and Back"];
  List<String> runTypeValues = ["Normal Run", "Warmup", "Hillsprint"];
  String downText;
  List<Run> choosen = [];
  List<Run> allRunsList = [];
  List<String> favorites = [];
  List<String> hateds = [];
  Map<String, List<String>> startingPlaces = {};
  final kToday = DateTime.now();
  final kFirstDay = DateTime(DateTime.now().year, DateTime.now().month - 3, DateTime.now().day);
  final kLastDay = DateTime(DateTime.now().year, DateTime.now().month + 3, DateTime.now().day);
  LinkedHashMap<DateTime, dynamic> kPlans = LinkedHashMap(equals: isSameDay, hashCode: getHashCode);
  bool coach;
  String team;
  String group;
  Color color;
  Global({
    this.defaultStart = "Grandview",
    this.desiredMargin = .25,
    this.maxMargin = .5,
    this.justDown = false,
    this.runStartInput = "Grandview",
    this.timePace = false,
    this.darkMode = false,
    this.minRuns = 3,
    this.outAndBack = "Both",
    this.type = "Normal Run",
    this.warmUp = false,
    this.downText = "Look for shorter and longer runs",
    this.coach = false,
    this.team = "None",
    this.group = "None",
    this.color = const Color.fromARGB(255, 200, 162, 200),
  });
}

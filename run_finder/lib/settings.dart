//Settings Screen:
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'keyboardoverlay.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final maxController = TextEditingController();
  FocusNode focusNode1 = FocusNode();
  FocusNode focusNode2 = FocusNode();
  FocusNode focusNode3 = FocusNode();
  final desiredController = TextEditingController();
  final runsController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Row(
        //Padding:
        children: <Widget>[
          const SizedBox(
            width: 20,
          ),
          //some code to make it not throw errors(give it dimensions)
          Expanded(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .9,
              //Actual list View displaying different settings
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  //Choose default starting location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Default Starting Location'),
                      DropdownButton(
                        value: globalVars.defaultStart,
                        icon: const Icon(Icons.expand_more),
                        elevation: 16,
                        underline: Container(
                          height: 2,
                        ),
                        onChanged: (String? newValue) async {
                          setState(() {
                            WidgetsFlutterBinding.ensureInitialized();
                            globalVars.runStartInput = newValue!;
                            globalVars.defaultStart = newValue;
                            syncToProfile();
                          });
                        },
                        items: globalVars.startingPlaces.keys
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + globalVars.defaultStart.toString(),
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Desired Margin of Error
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Desired Accuracy'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '.25',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          controller: desiredController,
                          textInputAction: TextInputAction.done,
                          focusNode: focusNode1,
                          onChanged: (value) async {
                            setState(() {
                              try {
                                globalVars.desiredMargin = double.parse(value);
                                syncToProfile();
                              } catch (_) {}
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + globalVars.desiredMargin.toString() + " miles",
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Maximum Margin of Error
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Maximum Inaccuracy'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '.5',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              try {
                                globalVars.maxMargin = double.parse(value);
                                syncToProfile();
                              } catch (_) {}
                            });
                          },
                          controller: maxController,
                          focusNode: focusNode2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + globalVars.maxMargin.toString() + ' miles',
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Min runs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Minimum Number of Runs'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '3',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              try {
                                globalVars.minRuns = int.parse(value);
                                syncToProfile();
                              } catch (_) {}
                            });
                          },
                          controller: runsController,
                          focusNode: focusNode3,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + globalVars.minRuns.toString() + " runs",
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose whether to only look for shorter runs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(globalVars.downText),
                      Switch(
                        value: globalVars.justDown,
                        onChanged: (value) {
                          setState(() {
                            globalVars.justDown = value;
                            syncToProfile();
                            if (value) {
                              globalVars.downText = 'Look for shorter and longer runs';
                            } else {
                              globalVars.downText = 'Only look for shorter runs';
                            }
                          });
                        },
                      )
                    ],
                  ),
                  //Toggle Time/Pace method
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text((globalVars.timePace)
                          ? "Choose based off of Time/Pace"
                          : "Choose based off of distance"),
                      IconButton(
                          onPressed: () {
                            setState(() {
                              globalVars.timePace = !globalVars.timePace;
                            });
                          },
                          icon: Icon((globalVars.timePace)
                              ? Icons.timer_outlined
                              : Icons.timer_off_outlined))
                    ],
                  ),
                  //privacy
                  TextButton(
                    child: const Text("Privacy Policy"),
                    onPressed: () async {
                      const url = 'https://afoxenrichment.weebly.com/privacy.html';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 20,
          ),
        ],
      ),
      /* floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.table_chart),
        onPressed: _openRuns,
        tooltip: 'See Runs',
        heroTag: 'seeRunsBtn',
      ), */
    );
  }

  /* void _openRuns() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunScreen(
                  runs: fetchRun(),
                )));
  } */

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    desiredController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    focusNode1.addListener(() {
      bool hasFocus = focusNode1.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode3.addListener(() {
      bool hasFocus = focusNode3.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
  }

  // ignore: unused_element
  void _saveSettings() {
    setState(() {
      if (maxController.text != "") {
        globalVars.maxMargin = double.parse(maxController.text);
      }
      if (desiredController.text != "") {
        globalVars.desiredMargin = double.parse(desiredController.text);
      }
      globalVars.defaultStart = globalVars.runStartInput;
    });
  }
}

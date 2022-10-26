//TODO: Comment everyhting, make it have proper practice
import 'dart:async';
import 'dart:core';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'firebase_options.dart';
import 'footer_buttons.dart';
import 'globals.dart';
import 'keyboardoverlay.dart';
import 'plan.dart';
import 'run.dart';

void main() async {
  //TODO: fix the loading color on dark mode
  Color backgroundColor = const Color.fromARGB(255, 200, 162, 200);
  runApp(
    Container(
      color: backgroundColor,
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(),
        ),
      ),
    ),
  ); //Many thing have told me to do this, like firebase/cloud stuff
  WidgetsFlutterBinding.ensureInitialized();
  //Make sure the app isnt an empty white screen for like hours
  Timer timer = Timer(const Duration(seconds: 15), () {
    wontSync();
  });
  //Initilize firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  globalVars = Global();

  //Get preferences from profile(if logged in)
  if (FirebaseAuth.instance.currentUser != null) {
    syncFromProfile();
  }

  globalVars.allRunsList = await fetchRun();
  globalVars.startingPlaces = getStartingPlaces();
  syncFavsandHats();
  globalVars.allRunsList.sort();
  globalVars.runStartInput = globalVars.defaultStart;
  if (timer.isActive) {
    runApp(
      const MyApp(),
    );
  }
  timer.cancel();
}

//Global Variables
late Global globalVars;

void addScheduledRun(String title, String description, double distance, DateTime date) {
  if (globalVars.kPlans[date] != null) {
    globalVars.kPlans[date]!.add(Plan(title, description, distance));
  } else {
    globalVars.kPlans[date] = <Plan>[Plan(title, description, distance)];
  }
  syncToProfile();
}

BoxDecoration backgroundDecoration(BuildContext context) {
  return BoxDecoration(
    color: (Theme.of(context).brightness == Brightness.light) ? globalVars.color : null,
    image: (Theme.of(context).brightness == Brightness.light)
        ? DecorationImage(
            fit: BoxFit.cover,
            invertColors: false,
            opacity: .35,
            colorFilter: ColorFilter.mode(globalVars.color, BlendMode.overlay),
            image: (MediaQuery.of(context).orientation == Orientation.portrait)
                ? const AssetImage('assets/GrandviewMap2.png')
                : const AssetImage('assets/GrandviewMap.png'),
            repeat: ImageRepeat.repeat,
            matchTextDirection: true,
          )
        : DecorationImage(
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
            image: (MediaQuery.of(context).orientation == Orientation.portrait)
                ? const AssetImage('assets/GrandviewMap2.png')
                : const AssetImage('assets/GrandviewMap.png'),
          ),
  );
}

/// Returns a list of [DateTime] objects from [first] to [last], inclusive.
List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

Future<List<Run>> fetchRun() async {
  List<Run> ret = [];
  CollectionReference _collectionRef = FirebaseFirestore.instance.collection('PolyRuns');
  QuerySnapshot querySnapshot = await _collectionRef.get();
  final allData = querySnapshot.docs.map((doc) => doc.data()).toList();
  for (Object? data in allData) {
    Map<String, dynamic> dataMap = data as Map<String, dynamic>;
    if (dataMap['name']! != "PlaceHolder") ret.add(Run.fromMap(dataMap));
  }
  return ret;
}

//TODO: Possibly sync with garmin to have completed runs in calendar?

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

Map<String, List<String>> getStartingPlaces() {
  Map<String, List<String>> places = {};
  for (Run run in globalVars.allRunsList) {
    //print(run.start);
    if (!places.keys.toList().contains(run.start.keys.toString().trim())) {
      places.addAll(run.start);
    }
  }
  return places;
}

void syncFavsandHats() {
  for (Run run in globalVars.allRunsList) {
    if (globalVars.favorites.contains(run.route.toString())) {
      run.favorite = true;
      run.hated = false;
    } else if (globalVars.hateds.contains(run.route.toString())) {
      run.hated = true;
      run.favorite = false;
    }
  }
  for (Run run in globalVars.choosen) {
    if (globalVars.favorites.contains(run.route.toString())) {
      run.favorite = true;
      run.hated = false;
    } else if (globalVars.hateds.contains(run.route.toString())) {
      run.hated = true;
      run.favorite = false;
    }
  }
}

//Function to get all data from the user's document(found through uid) and sync it to the device
void syncFromProfile() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Users');
    Future<DocumentSnapshot<Object?>> doc = _collectionRef.doc(user.uid).get();
    Map<String, dynamic> data;
    doc.then((DocumentSnapshot documentSnapshot) {
      if (documentSnapshot.exists) {
        data = documentSnapshot.data() as Map<String, dynamic>;
        globalVars.favorites = data["Favorites"].cast<String>();
        globalVars.hateds = data["Hateds"].cast<String>();
        globalVars.maxMargin = data["maxMargin"] as double;
        globalVars.justDown = data["justDown"] as bool;
        globalVars.minRuns = data["minRuns"] as int;
        globalVars.desiredMargin = data["desiredMargin"] as double;
        globalVars.defaultStart = data["defaultStart"] as String;
        List<String> events = data["kPlans"].cast<String>() ?? [];
        for (String plan in events) {
          int index = plan.indexOf(":", 20);
          int index2 = plan.indexOf(":", index + 1);
          int index3 = plan.indexOf(":", index2 + 1);
          DateTime date = DateTime.parse(plan.substring(0, index));
          if (!date.isBefore(globalVars.kFirstDay) || !date.isAfter(globalVars.kLastDay)) {
            String title = plan.substring(index + 1, index2);
            String description = plan.substring(index2 + 1, index3);
            double distance = double.parse(plan.substring(index3 + 1));
            Plan eventForm = Plan(title, description, distance);
            if (globalVars.kPlans[date] != null) {
              if (globalVars.kPlans[date].toString().contains(eventForm.toString()) == false) {
                globalVars.kPlans[date]!.add(eventForm);
              }
            } else {
              globalVars.kPlans[date] = <Plan>[eventForm];
            }
          }
        }
        globalVars.coach = data["coach"];
        globalVars.group = data["group"];
        globalVars.team = data["team"];
      }
    });
  }
}

//Function to save all of users info, prefrences to the cloud(document with uid as name)
void syncToProfile() {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Users');
    DocumentReference doc = _collectionRef.doc(user.uid);
    List<String> events = [];
    globalVars.kPlans.forEach((key, value) {
      for (Plan plan in value) {
        events.add(key.toString() + ":" + plan.toJson());
      }
    });
    Map<String, dynamic> info = {
      "Favorites": globalVars.favorites,
      "Hateds": globalVars.hateds,
      "desiredMargin": globalVars.desiredMargin,
      "defaultStart": globalVars.defaultStart,
      "maxMargin": globalVars.maxMargin,
      "justDown": globalVars.justDown,
      "minRuns": globalVars.minRuns,
      "kPlans": events,
      "coach": globalVars.coach,
      "team": globalVars.team,
      "group": globalVars.group,
    };
    doc.set(info);
  }
}

void wontSync() {
  runApp(MaterialApp(
      home: AlertDialog(
    content: const Text("Error syncing to server."),
    actions: [
      TextButton(
          onPressed: () {
            main();
          },
          child: const Text("Try again"))
    ],
  )));
}

//Gets the location of the user
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

//Second Screen:
class ChoosenRunScreen extends StatefulWidget {
  const ChoosenRunScreen({Key? key}) : super(key: key);

  @override
  State<ChoosenRunScreen> createState() => _ChoosenRunScreenState();
}

//Find a long run location
class FindLongRunScreen extends StatefulWidget {
  const FindLongRunScreen({Key? key}) : super(key: key);

  @override
  _FindLongRunScreenState createState() => _FindLongRunScreenState();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Run Finder',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: globalVars.color,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color.fromARGB(255, 24, 149, 233),

        //Floating action buttons use colorshceme.secondary
      ),
      home: const MyHomePage(),
    );
  }
}

//Home page of finding a run
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

//Used to handle inputs of time for timepace mode
class TimeTextInputFormatter extends TextInputFormatter {
  late RegExp _exp;
  TimeTextInputFormatter() {
    _exp = RegExp(r'^[0-9:]+$');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_exp.hasMatch(newValue.text)) {
      TextSelection newSelection = newValue.selection;

      String value = newValue.text;
      String newText;

      String leftChunk = '';
      String rightChunk = '';

      if (value.length >= 8) {
        if (value.substring(0, 7) == '00:00:0') {
          leftChunk = '00:00:';
          rightChunk = value.substring(leftChunk.length + 1, value.length);
        } else if (value.substring(0, 6) == '00:00:') {
          leftChunk = '00:0';
          rightChunk = value.substring(6, 7) + ":" + value.substring(7);
        } else if (value.substring(0, 4) == '00:0') {
          leftChunk = '00:';
          rightChunk = value.substring(4, 5) + value.substring(6, 7) + ":" + value.substring(7);
        } else if (value.substring(0, 3) == '00:') {
          leftChunk = '0';
          rightChunk = value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7, 8) +
              value.substring(8);
        } else {
          leftChunk = '';
          rightChunk = value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7);
        }
      } else if (value.length == 7) {
        if (value.substring(0, 7) == '00:00:0') {
          leftChunk = '';
          rightChunk = '';
        } else if (value.substring(0, 6) == '00:00:') {
          leftChunk = '00:00:0';
          rightChunk = value.substring(6, 7);
        } else if (value.substring(0, 1) == '0') {
          leftChunk = '00:';
          rightChunk = value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7);
        } else {
          leftChunk = '';
          rightChunk = value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7);
        }
      } else {
        leftChunk = '00:00:0';
        rightChunk = value;
      }

      if (oldValue.text.isNotEmpty && oldValue.text.substring(0, 1) != '0') {
        if (value.length > 7) {
          return oldValue;
        } else {
          leftChunk = '0';
          rightChunk = value.substring(0, 1) +
              ":" +
              value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7);
        }
      }

      newText = leftChunk + rightChunk;

      newSelection = newValue.selection.copyWith(
        baseOffset: math.min(newText.length, newText.length),
        extentOffset: math.min(newText.length, newText.length),
      );

      return TextEditingValue(
        text: newText,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }
    return oldValue;
  }
}

class _ChoosenRunScreenState extends State<ChoosenRunScreen> {
  /*@override
  
  void initState() {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory();
    final IFrameElement _iframeElement = IFrameElement();

    _iframeElement.height = '500';
    _iframeElement.width = '500';
    _iframeElement.src = 'https://www.youtube.com/embed/RQzhAQlg2JQ';
    _iframeElement.style.border = 'none';
// ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'iframeElement',
      (int viewId) => _iframeElement,
    );
    Widget _iframeWidget;
    _iframeWidget = HtmlElementView(
      key: UniqueKey(),
      viewType: 'iframeElement',
    );

    

    super.initState();
  }*/
  GoogleMapController? mapController;
  void _setMapFitToTour(Set<Polyline> p) {
    double minLat = p.first.points.first.latitude;
    double minLong = p.first.points.first.longitude;
    double maxLat = p.first.points.first.latitude;
    double maxLong = p.first.points.first.longitude;
    for (var poly in p) {
      for (var point in poly.points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLong) minLong = point.longitude;
        if (point.longitude > maxLong) maxLong = point.longitude;
      }
    }
    mapController!.moveCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLong),
            northeast: LatLng(maxLat, maxLong),
          ),
          20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Run Options"),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: backgroundDecoration(context),
        child: ListView.builder(
            itemCount: globalVars.choosen.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () async {
                  showDialog(
                      context: context,
                      builder: (context) {
                        CameraPosition initialCameraPosition = CameraPosition(
                          target: globalVars.choosen[index].points?.first ??
                              LatLng(
                                double.parse(
                                  globalVars.startingPlaces[globalVars.defaultStart]![0],
                                ),
                                double.parse(
                                  globalVars.startingPlaces[globalVars.defaultStart]![0],
                                ),
                              ),
                        );
                        final id = PolylineId(globalVars.choosen[index].runName);
                        Set<Polyline> polylines = {
                          id: Polyline(
                            polylineId: id,
                            points: globalVars.choosen[index].points!,
                            width: 5,
                          ),
                        }.values.toSet();
                        MapType mapType = MapType.hybrid;

                        return StatefulBuilder(builder: (context, setState) {
                          return Dialog(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * .8,
                              height: MediaQuery.of(context).size.height * .6,
                              child: Stack(
                                children: [
                                  GoogleMap(
                                    initialCameraPosition: initialCameraPosition,
                                    polylines: polylines,
                                    onMapCreated: (cont) {
                                      mapController = cont;
                                      _setMapFitToTour(polylines);
                                    },
                                    mapType: mapType,
                                  ),
                                  Positioned(
                                    right: 10,
                                    top: 30,
                                    child: ElevatedButton(
                                      child: Text("Map type: ${mapType.name}"),
                                      onPressed: () {
                                        if (mapType == MapType.hybrid) {
                                          mapType = MapType.satellite;
                                        } else if (mapType == MapType.satellite) {
                                          mapType = MapType.terrain;
                                        } else if (mapType == MapType.terrain) {
                                          mapType = MapType.normal;
                                        } else {
                                          mapType = MapType.hybrid;
                                        }
                                        setState(() {});
                                      },
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        });
                      });
                },
                child: Card(
                  elevation: 5,
                  child: Stack(
                    children: <Widget>[
                      Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * (.8),
                                child: Text(
                                  globalVars.choosen[index].runName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                                ),
                              ),
                              Text(globalVars.choosen[index].toString(includeName: false)),
                            ],
                          )),
                      //favorite
                      Positioned(
                          child: IconButton(
                            icon: (globalVars.choosen[index].favorite)
                                ? const Icon(Icons.favorite_rounded, color: Colors.pink)
                                : const Icon(
                                    Icons.favorite_border_rounded,
                                    color: Colors.grey,
                                  ),
                            onPressed: () async {
                              globalVars.choosen[index].favorite =
                                  !globalVars.choosen[index].favorite;
                              globalVars.choosen[index].hated = false;
                              if (globalVars.choosen[index].favorite) {
                                globalVars.hateds
                                    .remove(globalVars.choosen[index].runName.toString());
                                globalVars.favorites
                                    .add(globalVars.choosen[index].runName.toString());
                              } else {
                                globalVars.favorites
                                    .remove(globalVars.choosen[index].runName.toString());
                              }
                              syncToProfile();
                              syncFavsandHats();
                              setState(() {});
                            },
                            tooltip: "Favorite",
                          ),
                          right: 1.0),
                      //hated
                      Positioned(
                        child: IconButton(
                          icon: (globalVars.choosen[index].hated)
                              ? Icon(Icons.sports_kabaddi, color: Colors.red[900])
                              : const Icon(Icons.sports_kabaddi_outlined, color: Colors.grey),
                          onPressed: () async {
                            globalVars.choosen[index].hated = !globalVars.choosen[index].hated;
                            globalVars.choosen[index].favorite = false;
                            if (globalVars.choosen[index].hated) {
                              globalVars.favorites
                                  .remove(globalVars.choosen[index].runName.toString());
                              globalVars.hateds.add(globalVars.choosen[index].runName.toString());
                            } else {
                              globalVars.hateds.remove(globalVars.choosen[index].runName.toString());
                            }
                            syncToProfile();
                            syncFavsandHats();
                            setState(() {});
                          },
                          tooltip: "Hate",
                        ),
                        right: 30,
                      )
                    ],
                  ),
                ),
              );
            }),
      ),
    );
  }
}

class _FindLongRunScreenState extends State<FindLongRunScreen> {
  //Create Controller for text field and dispose function to free up memory:
  final myController = TextEditingController();
  final timeController = TextEditingController();
  final paceController = TextEditingController();
  final FocusNode focusNode1 = FocusNode();
  final FocusNode focusNode2 = FocusNode();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final FocusScopeNode currentScope = FocusScope.of(context);
        if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
          FocusManager.instance.primaryFocus!.unfocus();
        }
      },
      child: Scaffold(
        //stop background image from resizing when keyboard is present
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: const FooterButtons("location"),

        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: backgroundDecoration(context),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: MediaQuery.of(context).size.height * .05,
                ),
                Text("Find a Location", style: Theme.of(context).textTheme.headline4),
                SizedBox(
                  height: MediaQuery.of(context).size.height / 8,
                ),

                //Input Desired Mileage:
                (globalVars.timePace)
                    //Time pace
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          //Time:
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              controller: timeController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              decoration: const InputDecoration(
                                hintText: '00:00:00',
                                labelText: "Time: ",
                              ),
                              inputFormatters: <TextInputFormatter>[
                                TimeTextInputFormatter() // This input formatter will do the job
                              ],
                            ),
                          ),
                          //Pace:
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              controller: paceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              decoration: const InputDecoration(
                                hintText: '00:00:00',
                                labelText: "Pace: ",
                              ),
                              inputFormatters: <TextInputFormatter>[
                                TimeTextInputFormatter() // This input formatter will do the job
                              ],
                            ),
                          ),
                        ],
                      )
                    : //Distance mode
                    SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Goal Distance:',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: myController,
                          onSubmitted: (value) {
                            _findLongRun();
                          },
                          focusNode: focusNode1,
                        ),
                      ),

                //Padding
                const SizedBox(height: 20),
                const Text("Type of Run:"),
                DropdownButton(
                  items: globalVars.oBValues.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  icon: const Icon(Icons.expand_more_rounded),
                  value: globalVars.outAndBack,
                  onChanged: (String? value) {
                    setState(() {
                      globalVars.outAndBack = value!;
                    });
                  },
                ),

                //Find run button
                FloatingActionButton(
                  onPressed: _findLongRun,
                  tooltip: 'Find Run',
                  child: const Icon(Icons.search),
                  heroTag: 'findLongRunBtn',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    myController.dispose();
    timeController.dispose();
    paceController.dispose();
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
  }

  void _findLongRun() {
    //empty the list to not keep old possibilites
    globalVars.choosen = [];
    double distance;
    //find and add any runs that match the given parameters

    try {
      if (globalVars.timePace) {
        String lengthStr = timeController.text;
        String paceStr = paceController.text;

        //find the length of the runs in hours
        double length = int.parse(lengthStr.substring(0, 2)).toDouble() +
            int.parse(lengthStr.substring(3, 5)) / 60.0 +
            int.parse(lengthStr.substring(6, 8)) / 3600.0;
        //find the pace in mph
        double pace = 60.0 / int.parse(paceStr.substring(3, 5)) + int.parse(paceStr.substring(6, 8));
        distance = length * pace;
      } else {
        distance = double.parse(myController.text);
      }
      double margin = 0;
      //If they selected Loops only
      if (globalVars.outAndBack == "Loops") {
        while (margin <= globalVars.desiredMargin + .01 ||
            (margin <= globalVars.maxMargin + .01 &&
                globalVars.choosen.length < globalVars.minRuns)) {
          for (Run run in globalVars.allRunsList) {
            //Make sure you start in the right place and its not an out and back
            if (run.start.keys.toString() != "(" + globalVars.defaultStart + ")" && run.loop) {
              //See if they selected shorter runs only
              if (globalVars.justDown) {
                //see if it is within the margin of error
                if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                  //make sure there wont be any repeats
                  if (!globalVars.choosen.contains(run)) {
                    globalVars.choosen.add(run);
                  }
                }
              } else {
                if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                  //make sure there wont be any repeats
                  if (!globalVars.choosen.contains(run)) {
                    globalVars.choosen.add(run);
                  }
                }
              }
            }
          }
          margin += .01;
        }
        //Both out and backs and loops
      } else if (globalVars.outAndBack == "Both") {
        while (margin <= globalVars.desiredMargin + .01 ||
            (margin <= globalVars.maxMargin + .01 &&
                globalVars.choosen.length < globalVars.minRuns)) {
          for (Run run in globalVars.allRunsList) {
            //Make sure you start in the right place
            if (run.start.keys.toString() != "(" + globalVars.defaultStart + ")") {
              //If its a loop
              if (run.loop) {
                //See if they selected shorter runs only
                if (globalVars.justDown) {
                  //see if it is within the margin of error
                  if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                    //make sure there wont be any repeats
                    if (!globalVars.choosen.contains(run)) {
                      globalVars.choosen.add(run);
                    }
                  }
                } else {
                  if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                    //make sure there wont be any repeats
                    if (!globalVars.choosen.contains(run)) {
                      globalVars.choosen.add(run);
                    }
                  }
                }
                //If its an out and back
              } else {
                //See if the run fits
                if (distance / 2.0 <= run.distance) {
                  //make sure there wont be any repeats
                  if (!globalVars.choosen.contains(run)) {
                    globalVars.choosen.add(run);
                  }
                }
              }
            }
          }
          margin += .01;
        }
        //Just out and backs
      } else {
        for (Run run in globalVars.allRunsList) {
          //Make sure you start in the right place
          if (run.start.keys.toString() != "(" + globalVars.defaultStart + ")" && !run.loop) {
            //If they selected Normal Run
            if (globalVars.type == "Normal Run" && !run.hill) {
              //See if the run fits
              if (distance / 2.0 <= run.distance) {
                //make sure there wont be any repeats
                if (!globalVars.choosen.contains(run)) {
                  globalVars.choosen.add(run);
                }
              }
            }
          }
        }
      }
      globalVars.choosen.sort();
      //Go to second Screen:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChoosenRunScreen()),
      );
    } on Exception {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Invalid Input"),
              content: const Text("Check your inputs."),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }
  }
}

class _MyHomePageState extends State<MyHomePage> {
  //Create Controller for text field and dispose function to free up memory:
  final myController = TextEditingController();
  final timeController = TextEditingController();
  final paceController = TextEditingController();
  final FocusNode focusNode1 = FocusNode();
  final FocusNode focusNode2 = FocusNode();

  List<String> selectedSurfaces = ['Road', 'Sidewalk', 'Dirt'];
  List<String> selectedSteepness = ['Flat', 'Medium', 'Steep', 'Everest'];
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return GestureDetector(
      onTap: () {
        final FocusScopeNode currentScope = FocusScope.of(context);
        if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
          FocusManager.instance.primaryFocus!.unfocus();
        }
      },
      child: Scaffold(
        //stop background image from resizing when keyboard is present
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: const FooterButtons("home"),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: backgroundDecoration(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: MediaQuery.of(context).size.height * .05),
              Text("Run Finder", style: Theme.of(context).textTheme.headline4),
              SizedBox(height: MediaQuery.of(context).size.height / 5.9),
              //Text(sheet?.values.row(1)),
              const Text(
                'Select where you are running from:',
              ),
              //Find Run.start:
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  //Get current location and automatically choose a starting place
                  IconButton(
                      tooltip: "Use Current Location",
                      onPressed: () async {
                        String update = globalVars.runStartInput;
                        late Position pos;
                        try {
                          pos = await _determinePosition();
                          for (String start in globalVars.startingPlaces.keys) {
                            if (Geolocator.distanceBetween(
                                    double.parse(globalVars.startingPlaces[start]![0]),
                                    double.parse(globalVars.startingPlaces[start]![1]),
                                    pos.latitude,
                                    pos.longitude) <=
                                1000) {
                              update = start;
                            }
                          }
                        } catch (_) {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("Location Services not enabled"),
                                  content: const Text(
                                      "Please enable location services in settings for this future to work"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Ok"),
                                    ),
                                  ],
                                );
                              });
                        }

                        setState(() {
                          globalVars.runStartInput = update;
                        });
                      },
                      icon: const Icon(Icons.my_location)),
                  //manually select starting place
                  DropdownButton(
                    value: globalVars.runStartInput,
                    icon: const Icon(Icons.expand_more),
                    elevation: 16,
                    underline: Container(
                      height: 2,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        globalVars.runStartInput = newValue!;
                      });
                    },
                    items: globalVars.startingPlaces.keys
                        .toList()
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),

              //Padding
              const SizedBox(height: 10),

              //Input Desired Mileage or time and pace:
              (globalVars.timePace)
                  //Time pace
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        //Time:
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: timeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(
                              hintText: '00:00:00',
                              labelText: "Time: ",
                            ),
                            inputFormatters: <TextInputFormatter>[
                              TimeTextInputFormatter() // This input formatter will do the job
                            ],
                          ),
                        ),
                        //Pace:
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: paceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(
                              hintText: '00:00:00',
                              labelText: "Pace: ",
                            ),
                            inputFormatters: <TextInputFormatter>[
                              TimeTextInputFormatter() // This input formatter will do the job
                            ],
                          ),
                        ),
                      ],
                    )
                  : //Distance mode
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Goal Distance:',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: myController,
                            onSubmitted: (value) {
                              _findRun();
                            },
                            focusNode: focusNode1,
                          ),
                        ),
                        Visibility(
                            visible: (globalVars.kPlans[globalVars.kToday] != null &&
                                globalVars.kPlans[globalVars.kToday].length == 1),
                            child: IconButton(
                              tooltip: "Get Distance From Calendar",
                              icon: const Icon(Icons.lightbulb),
                              onPressed: () {
                                myController.text =
                                    globalVars.kPlans[globalVars.kToday][0].distance.toString();
                                setState(() {});
                              },
                            ))
                      ],
                    ),

              //Padding
              const SizedBox(height: 20),

              SizedBox(
                width: 374,
                child: ExpansionTile(
                  title: SizedBox(
                    width: 300,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        //Toggle out and back(globalVars.outAndBack), loops, and both
                        DropdownButton(
                          items: globalVars.oBValues.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          icon: const Icon(Icons.expand_more_rounded),
                          value: globalVars.outAndBack,
                          onChanged: (String? value) {
                            setState(() {
                              globalVars.outAndBack = value!;
                              if (globalVars.outAndBack != "Out and Back" &&
                                  globalVars.type == "Hillsprint") {
                                globalVars.type = "Normal Run";
                              }
                            });
                          },
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        //Toggle hill sprint, warmup, and Normal Run
                        DropdownButton(
                          items:
                              globalVars.runTypeValues.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          icon: const Icon(Icons.expand_more_rounded),
                          value: globalVars.type,
                          onChanged: (String? value) {
                            setState(() {
                              globalVars.type = value!;
                              if (globalVars.type == "Hillsprint") {
                                globalVars.outAndBack = "Out and Back";
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  children: [
                    SizedBox(
                      width: 315,
                      //Select surface
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          //Select Sidewalk
                          SizedBox(
                            width: 315 / 3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSurfaces.contains("Sidewalk")) {
                                  selectedSurfaces.remove("Sidewalk");
                                } else {
                                  selectedSurfaces.add("Sidewalk");
                                }
                                setState(() {});
                              },
                              child: (selectedSurfaces.contains("Sidewalk")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.terrain),
                                        Text("Sidewalk"),
                                      ],
                                    )
                                  : Text(
                                      "Sidewalk",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Roads
                          SizedBox(
                            width: 315 / 3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSurfaces.contains("Road")) {
                                  selectedSurfaces.remove("Road");
                                } else {
                                  selectedSurfaces.add("Road");
                                }
                                setState(() {});
                              },
                              child: (selectedSurfaces.contains("Road")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.terrain),
                                        Text("Road"),
                                      ],
                                    )
                                  : Text(
                                      "Road",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Dirt
                          SizedBox(
                            width: 315 / 3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSurfaces.contains("Dirt")) {
                                  selectedSurfaces.remove("Dirt");
                                } else {
                                  selectedSurfaces.add("Dirt");
                                }
                                setState(() {});
                              },
                              child: (selectedSurfaces.contains("Dirt")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.terrain),
                                        Text("Dirt"),
                                      ],
                                    )
                                  : Text(
                                      "Dirt",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 332,
                      //Select Steepness
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          //Select Flat
                          SizedBox(
                            //width: 315 / 4.3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Flat")) {
                                  selectedSteepness.remove("Flat");
                                } else {
                                  selectedSteepness.add("Flat");
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Flat")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Flat"),
                                      ],
                                    )
                                  : Text(
                                      "Flat",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Medium
                          SizedBox(
                            //width: 315 / 3.9,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Medium")) {
                                  selectedSteepness.remove("Medium");
                                } else {
                                  selectedSteepness.add("Medium");
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Medium")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Medium"),
                                      ],
                                    )
                                  : Text(
                                      "Medium",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Steep
                          SizedBox(
                            //width: 315 / 3.9,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Steep")) {
                                  selectedSteepness.remove("Steep");
                                } else {
                                  selectedSteepness.add("Steep");
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Steep")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Steep"),
                                      ],
                                    )
                                  : Text(
                                      "Steep",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Everest
                          SizedBox(
                            //width: 315 / 3.9,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Everest")) {
                                  selectedSteepness.remove("Everest");
                                } else {
                                  selectedSteepness.add("Everest");
                                  //globalVars.type = "Hillsprint";
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Everest")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Everest"),
                                      ],
                                    )
                                  : Text(
                                      "Everest",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              //Find run button
              FloatingActionButton(
                onPressed: _findRun,
                tooltip: 'Find Run',
                child: const Icon(Icons.search),
                heroTag: 'findRunBtn',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    myController.dispose();
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
  }

  void _findRun() {
    //empty the list to not keep old possibilites
    globalVars.choosen = [];
    double distance;
    //find and add any runs that match the given parameters

    try {
      if (globalVars.timePace) {
        String lengthStr = timeController.text;
        String paceStr = paceController.text;

        //find the length of the runs in hours
        double length = int.parse(lengthStr.substring(0, 2)).toDouble() +
            int.parse(lengthStr.substring(3, 5)) / 60.0 +
            int.parse(lengthStr.substring(6, 8)) / 3600.0;
        //find the pace in mph
        double pace = 60.0 / int.parse(paceStr.substring(3, 5)) + int.parse(paceStr.substring(6, 8));
        distance = length * pace;
      } else {
        distance = double.parse(myController.text);
      }
      double margin = 0;
      //If they selected Loops only
      if (globalVars.outAndBack == "Loops") {
        while (margin <= globalVars.desiredMargin + .01 ||
            (margin <= globalVars.maxMargin + .01 &&
                globalVars.choosen.length < globalVars.minRuns)) {
          for (Run run in globalVars.allRunsList) {
            bool goodSurface = true;
            bool goodSteepness = true;
            for (String surface in run.surfaces) {
              if (!selectedSurfaces.contains(surface)) {
                goodSurface = false;
              }
            }
            if (run.steepness < 45) {
              goodSteepness = selectedSteepness.contains('Flat');
            } else if (run.steepness < 75) {
              goodSteepness = selectedSteepness.contains('Medium');
            } else if (run.steepness < 125) {
              goodSteepness = selectedSteepness.contains('Steep');
            } else {
              goodSteepness = selectedSteepness.contains('Everest');
            }

            if (goodSteepness && goodSurface) {
              //Make sure you start in the right place and its not an out and back
              if (run.start.keys.toString() == ("(" + globalVars.runStartInput + ")") && run.loop) {
                //If they selected Normal Run
                if (globalVars.type == "Normal Run" && !run.hill) {
                  //See if they selected shorter runs only
                  if (globalVars.justDown) {
                    //see if it is within the margin of error
                    if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  }
                  //If they selected Warmup
                } else if (globalVars.type == "Warmup" && run.warmUp) {
                  //See if they selected shorter runs only
                  if (globalVars.justDown) {
                    //see if it is within the margin of error
                    if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  }
                }
              }
            }
          }
          margin += .01;
        }
      } //Both out and backs and loops
      else if (globalVars.outAndBack == "Both") {
        while (margin <= globalVars.desiredMargin + .01 ||
            (margin <= globalVars.maxMargin + .01 &&
                globalVars.choosen.length < globalVars.minRuns)) {
          for (Run run in globalVars.allRunsList) {
            bool goodSurface = true;
            bool goodSteepness = true;
            for (String surface in run.surfaces) {
              if (!selectedSurfaces.contains(surface)) {
                goodSurface = false;
              }
            }
            if (run.steepness < 45) {
              goodSteepness = selectedSteepness.contains('Flat');
            } else if (run.steepness < 75) {
              goodSteepness = selectedSteepness.contains('Medium');
            } else if (run.steepness < 125) {
              goodSteepness = selectedSteepness.contains('Steep');
            } else {
              goodSteepness = selectedSteepness.contains('Everest');
            }

            if (goodSteepness && goodSurface) {
              //Make sure you start in the right place
              if (run.start.keys.toString() == ("(" + globalVars.runStartInput + ")")) {
                //If they selected Normal Run
                if (globalVars.type == "Normal Run" && !run.hill) {
                  //If its a loop
                  if (run.loop) {
                    //See if they selected shorter runs only
                    if (globalVars.justDown) {
                      //see if it is within the margin of error
                      if (run.distance >= (distance - margin) &&
                          run.distance <= (distance + margin)) {
                        //make sure there wont be any repeats
                        if (!globalVars.choosen.contains(run)) {
                          globalVars.choosen.add(run);
                        }
                      }
                    } else {
                      if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                        //make sure there wont be any repeats
                        if (!globalVars.choosen.contains(run)) {
                          globalVars.choosen.add(run);
                        }
                      }
                    }
                    //If its an out and back
                  } else {
                    //See if the run fits
                    if (distance / 2.0 <= run.distance) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  }
                  //If they selected Warmup
                } else if (globalVars.type == "Warmup" && run.warmUp) {
                  //If its a loop
                  if (run.loop) {
                    //See if they selected shorter runs only
                    if (globalVars.justDown) {
                      //see if it is within the margin of error
                      if (run.distance >= (distance - margin) &&
                          run.distance <= (distance + margin)) {
                        //make sure there wont be any repeats
                        if (!globalVars.choosen.contains(run)) {
                          globalVars.choosen.add(run);
                        }
                      }
                    } else {
                      if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                        //make sure there wont be any repeats
                        if (!globalVars.choosen.contains(run)) {
                          globalVars.choosen.add(run);
                        }
                      }
                    }
                  } //If its an out and back
                  else {
                    //See if the run fits
                    if (distance / 2.0 <= run.distance) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  }
                  //If they selected Hill sprint only
                } else if (globalVars.type == "Hillsprint" && run.hill) {
                  //If its a loop
                  if (run.loop) {
                    //See if they selected shorter runs only
                    if (globalVars.justDown) {
                      //see if it is within the margin of error
                      if (run.distance >= (distance - margin) &&
                          run.distance <= (distance + margin)) {
                        //make sure there wont be any repeats
                        if (!globalVars.choosen.contains(run)) {
                          globalVars.choosen.add(run);
                        }
                      }
                    } else {
                      if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                        //make sure there wont be any repeats
                        if (!globalVars.choosen.contains(run)) {
                          globalVars.choosen.add(run);
                        }
                      }
                    }
                    //If its an out and back
                  } else {
                    //See if the run fits
                    if (distance / 2.0 <= run.distance) {
                      //make sure there wont be any repeats
                      if (!globalVars.choosen.contains(run)) {
                        globalVars.choosen.add(run);
                      }
                    }
                  }
                }
              }
            }
          }
          margin += .01;
        }
      } //Just out and backs
      else {
        for (Run run in globalVars.allRunsList) {
          bool goodSurface = true;
          bool goodSteepness = true;
          for (String surface in run.surfaces) {
            if (!selectedSurfaces.contains(surface)) {
              goodSurface = false;
            }
          }
          if (run.steepness < 45) {
            goodSteepness = selectedSteepness.contains('Flat');
          } else if (run.steepness < 75) {
            goodSteepness = selectedSteepness.contains('Medium');
          } else if (run.steepness < 125) {
            goodSteepness = selectedSteepness.contains('Steep');
          } else {
            goodSteepness = selectedSteepness.contains('Everest');
          }

          if (goodSteepness && goodSurface) {
            //Make sure you start in the right place
            if (run.start.keys.toString() == ("(" + globalVars.runStartInput + ")") && !run.loop) {
              //If they selected Normal Run
              if (globalVars.type == "Normal Run" && !run.hill) {
                //See if the run fits
                if (distance / 2.0 <= run.distance) {
                  //make sure there wont be any repeats
                  if (!globalVars.choosen.contains(run)) {
                    globalVars.choosen.add(run);
                  }
                }
                //If they selected Warmup
              } else if (globalVars.type == "Warmup" && run.warmUp) {
                //See if the run fits
                if (distance / 2.0 <= run.distance) {
                  //make sure there wont be any repeats
                  if (!globalVars.choosen.contains(run)) {
                    globalVars.choosen.add(run);
                  }
                }
                //If they selected Hill sprint only
              } else if (globalVars.type == "Hillsprint" && run.hill) {
                //See if the run fits
                if (distance / 2.0 <= run.distance) {
                  //make sure there wont be any repeats
                  if (!globalVars.choosen.contains(run)) {
                    globalVars.choosen.add(run);
                  }
                }
              }
            }
          }
        }
      }
      if (globalVars.choosen.isEmpty) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("No runs :("),
                content: const Text("Check your inputs, maybe widen your search."),
                actions: [
                  TextButton(
                    child: const Text("OK"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            });
      } else {
        globalVars.choosen.sort();

        //Go to second Screen:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChoosenRunScreen()),
        );
      }
    } on Exception {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Invalid Input"),
              //content: const Text("Check your inputs."),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }
  }
}

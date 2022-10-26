import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'footer_buttons.dart';
import 'main.dart' show backgroundDecoration, globalVars, syncToProfile;
import 'plan.dart';
import 'run.dart';

//TODO: when they edit their name, have it update in the globalVars.team as well as in their own profile
class TeamPage extends StatefulWidget {
  const TeamPage({Key? key}) : super(key: key);

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  DateTime startDay = mostRecentMonday(globalVars.kToday);

  Future<void> addToTeam(String name) async {
    CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Teams');
    DocumentReference doc = _collectionRef.doc(name);

    await doc.get().then((DocumentSnapshot documentSnapshot) async {
      if (documentSnapshot.exists) {
        //Add the person in to main document
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;

        (data["Unassigned"]! as List<dynamic>).add(FirebaseAuth.instance.currentUser!.displayName! +
            "," +
            FirebaseAuth.instance.currentUser!.uid);
        await doc.update(data);
        //Add the person in to scheduled runs
        await doc
            .collection("Scheduled Runs")
            .get()
            .then((QuerySnapshot<Map<String, dynamic>> value) async {
          for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
            if (element.id != "blank") {
              Map<String, List<dynamic>> data = element.data().cast<String, List<dynamic>>();
              data["Unassigned"]!.add("Not Completed");

              await doc.collection("Scheduled Runs").doc(element.id).update(data);
            }
          }
        });
        //add the person in to weekly mileages
        await doc
            .collection("Weekly Mileage")
            .get()
            .then((QuerySnapshot<Map<String, dynamic>> value) async {
          for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
            if (element.id != "blank") {
              Map<String, List<dynamic>> data = element.data().cast<String, List<dynamic>>();
              data["Unassigned"]!.add("0");

              await doc.collection("Weekly Mileage").doc(element.id).update(data);
            }
          }
        });
        //will have to do some kind of syncing of past runs? - but they arent stored/tracked anyways until you join a globalVars.team(yet)

        //add the person on their own document
        await FirebaseFirestore.instance
            .collection("Users")
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({"team": name, "group": "Unassigned"});
        globalVars.team = name;
        globalVars.group = "Unassigned";
        //refresh to the right page

        setState(() {});
      } else {
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Name of globalVars.team doesn't exist"),
                content: const Text("Try changing the name"),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Ok"))
                ],
              );
            });
      }
    });
  }

  Future<DateTime> _selectDate(BuildContext context, DateTime addDate) async {
    final kToday = DateTime.now();
    final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
    final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: addDate, firstDate: kFirstDay, lastDate: kLastDay);
    if (picked != null && picked != addDate) {
      setState(() {
        addDate = picked;
      });
    }
    return addDate;
  }

  Future<void> removeFromTeam() async {
    User user = FirebaseAuth.instance.currentUser!;
    String name = user.displayName!;
    String uid = user.uid;
    String nameUid = name + "," + uid;
    DocumentReference teamDoc = FirebaseFirestore.instance.collection("Teams").doc(globalVars.team);
    late int index;

    ///remove them from their old globalVars.group on globalVars.team document, get index while youre at it
    await teamDoc.get().then((DocumentSnapshot documentSnapshot) async {
      Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
      index = (data[globalVars.group]! as List<dynamic>).indexOf(nameUid);
      (data[globalVars.group]! as List<dynamic>).removeAt(index);
      index++;
      await teamDoc.update(data);
    });

    ///loop throuhg every weekly mileage and remove the runner's info
    await teamDoc
        .collection("Scheduled Runs")
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> value) async {
      for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
        if (element.id != "blank") {
          Map<String, List<dynamic>> data = element.data().cast<String, List<dynamic>>();
          data[globalVars.group]!.removeAt(index);
          await teamDoc.collection("Scheduled Runs").doc(element.id).update(data);
        }
      }
    });

    ///loop through every scheduled run and remove the runner's info
    await teamDoc
        .collection("Weekly Mileage")
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> value) async {
      for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
        if (element.id != "blank") {
          Map<String, List<dynamic>> data = element.data().cast<String, List<dynamic>>();
          data[globalVars.group]!.removeAt(index);
          await teamDoc.collection("Weekly Mileage").doc(element.id).update(data);
        }
      }
    });

    ///change globalVars.coach, globalVars.team, globalVars.group to default values here
    globalVars.coach = false;
    globalVars.team = "None";
    globalVars.group = "None";

    ///then push to their user document(sync to profile)
    syncToProfile();
  }

  void addRun() {
    //[getMileagesForWeek()][LinkedHashMap<String, dynamic>] has requiremnt of ", ___ miles" where ___ is the number of miles that week
    //I assume itll be done the same way as coach assigned it?
    //itd be great if I could choose what route they choose too
    String runName = "";
    final commentsController = TextEditingController();
    final distanceController = TextEditingController();
    DateTime addDate = DateTime.now();
    List<String> runNames = [];
    for (var element in globalVars.allRunsList) {
      runNames.add(element.runName);
    }
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .5,
              width: MediaQuery.of(context).size.width * .75,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        "Add a run",
                        style: Theme.of(context).textTheme.headline6,
                      ),
                    ),
                    //route name
                    Autocomplete<String>(
                      optionsBuilder: ((textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        return runNames.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      }),
                      fieldViewBuilder: (BuildContext context,
                          TextEditingController fieldTextEditingController,
                          FocusNode fieldFocusNode,
                          VoidCallback onFieldSubmitted) {
                        return TextField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            decoration: const InputDecoration(
                              label: Text("Route Name"),
                            ),
                            onChanged: (value) {
                              runName = value;
                            });
                      },
                      optionsViewBuilder: (
                        BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options,
                      ) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            child: Container(
                              width: 300,
                              height: 200,
                              color: const Color.fromARGB(255, 89, 89, 89),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(10.0),
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(index);

                                  return GestureDetector(
                                    onTap: () {
                                      onSelected(option);
                                    },
                                    child: ListTile(
                                      title: Text(
                                        option,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      onSelected: (value) {
                        //change name of run
                        runName = value;
                        //autofill in a nice lil distance
                        Run run =
                            globalVars.allRunsList.firstWhere((Run run) => run.runName == runName);
                        if (run.loop) {
                          distanceController.text = run.distance.toString();
                        } else {
                          distanceController.text = (run.distance * 2).toString();
                        }
                      },
                    ),
                    //comments
                    TextField(
                      decoration: const InputDecoration(
                        label: Text("Comments"),
                      ),
                      controller: commentsController,
                      maxLines: null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        //distance
                        SizedBox(
                          width: 200,
                          child: TextField(
                            decoration: const InputDecoration(
                              label: Text("Distance Ran"),
                            ),
                            controller: distanceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(signed: false, decimal: true),
                          ),
                        ),
                        //date
                        IconButton(
                          onPressed: () async {
                            addDate = await _selectDate(context, addDate);
                          },
                          icon: const Icon(Icons.today),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              //first check if their inputs are valid
                              if (runName == "") {
                                showDialog(
                                  context: context,
                                  builder: (contex) => AlertDialog(
                                    title: const Text("Please enter a route name"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Ok"),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (distanceController.text == "") {
                                showDialog(
                                  context: context,
                                  builder: (contex) => AlertDialog(
                                    title: const Text("Please enter a distance"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Ok"),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    });
                                String dateString = dateToString(addDate);
                                DocumentReference teamDoc = FirebaseFirestore.instance
                                    .collection("Teams")
                                    .doc(globalVars.team);
                                int? index;
                                String comments = commentsController.text;
                                String outgoingText = runName;
                                User user = FirebaseAuth.instance.currentUser!;
                                String name = user.displayName!;
                                String uid = user.uid;
                                String nameUid = name + "," + uid;
                                if (comments != "") {
                                  outgoingText += ", " + comments;
                                }
                                outgoingText += ", " + distanceController.text + " miles";
                                await teamDoc.get().then((DocumentSnapshot documentSnapshot) {
                                  Map<String, dynamic> data =
                                      documentSnapshot.data() as Map<String, dynamic>;
                                  index =
                                      (data[globalVars.group]! as List<dynamic>).indexOf(nameUid) + 1;
                                });
                                try {
                                  await teamDoc
                                      .collection("Scheduled Runs")
                                      .doc(dateString)
                                      .get()
                                      .then((DocumentSnapshot documentSnapshot) async {
                                    Map<String, dynamic> data =
                                        documentSnapshot.data() as Map<String, dynamic>;
                                    (data[globalVars.group]! as List<dynamic>)[index!] = outgoingText;
                                    await teamDoc
                                        .collection("Scheduled Runs")
                                        .doc(dateString)
                                        .update(data);
                                  });
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  //addup the weekly miles to get nicer ones
                                  await addWeeklyMiles(mostRecentMonday(addDate));
                                  setState(() {});
                                } catch (_) {
                                  //TODO: figure out what to do if the coach hasnt assigned a run on that day yet
                                  Navigator.pop(context);
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text("Can't save run"),
                                          content: const Text(
                                              "Can only save runs on days your coach has assigned a run on"),
                                          actions: [
                                            TextButton(
                                              onPressed: () async {
                                                var url =
                                                    "https://afoxenrichment.weebly.com/contact.html";
                                                if (await canLaunch(url)) {
                                                  await launch(url);
                                                } else {
                                                  throw 'Could not launch $url';
                                                }
                                              },
                                              child: const Text("Complain about it"),
                                            ),
                                            ElevatedButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text("Ok"))
                                          ],
                                        );
                                      });
                                }
                              }
                            },
                            child: const Text("Done"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    FloatingActionButton? floatingActionButton;
    if (globalVars.team != "None") {
      floatingActionButton = FloatingActionButton(
        onPressed: () {
          addRun();
        },
        child: const Icon(Icons.add),
      );
    }
    if (globalVars.coach) {
      return (globalVars.team == "None") ? const CreateTeam() : const CoachViewTeam();
    } else {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: const FooterButtons("team"),
        floatingActionButton: floatingActionButton,
        //TODO: pull to refresh(retrieve data)
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: backgroundDecoration(context),
          child: Center(
            child: Column(
              children: (globalVars.team ==
                      "None") //check to see if they are on a globalVars.team, if they arent then only let them join a globalVars.team
                  ? [
                      JoinTeam(
                        controller: controller,
                        addToTeam: addToTeam,
                      ),
                    ]
                  :
                  //TODO: show the route that globalVars.coach picked out
                  ///use the same function for suggesting to globalVars.coach as you do for suggesting to to athletes
                  [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).backgroundColor,
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromARGB(255, 30, 30, 30),
                              spreadRadius: 5,
                              blurRadius: 9,
                            ),
                          ],
                        ),
                        height: MediaQuery.of(context).size.height * .16,
                        child: Column(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * .05),
                            TextButton(
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text("Want to leave ${globalVars.team}?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                          "Warning: This cannot be undone"),
                                                      content: Text(
                                                          "This will delete all your data on ${globalVars.team} and cannot be undone.\nDo you understand?"),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text("Cancel"),
                                                        ),
                                                        TextButton(
                                                          onPressed: () async {
                                                            await removeFromTeam();
                                                            Navigator.pop(context);

                                                            setState(() {});
                                                          },
                                                          child: const Text(
                                                            "I understand, go ahead",
                                                            style: TextStyle(color: Colors.grey),
                                                          ),
                                                        ),
                                                      ],
                                                      actionsAlignment: MainAxisAlignment.spaceEvenly,
                                                    );
                                                  });
                                            },
                                            child: const Text("Yes"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text("No"),
                                          ),
                                        ],
                                      );
                                    });
                              },
                              child: Text(
                                globalVars.team,
                                style: Theme.of(context).textTheme.headline5,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    startDay = startDay.subtract(const Duration(days: 7));
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.west,
                                    size: 20,
                                  ),
                                ),
                                TextButton(
                                  onPressed: (() => setState(() {
                                        startDay = mostRecentMonday(DateTime.now());
                                      })),
                                  child: Text(
                                    "Week of ${mostRecentMonday(
                                      startDay,
                                    ).toString().substring(5, 10)} to ${mostRecentMonday(startDay).add(
                                          const Duration(days: 6),
                                        ).toString().substring(5, 10)}",
                                    style: Theme.of(context).textTheme.bodyText2,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    startDay = startDay.add(const Duration(days: 7));
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.east,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * .73,
                          child: ListView(
                            controller: ScrollController(),
                            children: <Widget>[
                              AssignedRuns(
                                startDay: startDay,
                              ),
                              //Leave Team button
                            ],
                          ),
                        ),
                      ),
                    ],
            ),
          ),
        ),
      );
    }
  }
}

class AssignedRuns extends StatefulWidget {
  const AssignedRuns({Key? key, required this.startDay}) : super(key: key);
  final DateTime startDay;

  @override
  State<AssignedRuns> createState() => _AssignedRunsState();
}

class _AssignedRunsState extends State<AssignedRuns> {
  String weeklyMileage = "";
  String assignedWeeklyMileage = "";

  //turns DateTime to string found in the database
  String dateToString(DateTime date) => date.toString().substring(0, 10);

  Future<List<Widget>> getRuns() async {
    DocumentReference doc = FirebaseFirestore.instance.collection("Teams").doc(globalVars.team);
    int index = -1;
    List<Widget>? assignedRuns;

    await doc.get().then((value) {
      Map<String, dynamic> data = value.data() as Map<String, dynamic>;
      index = (data[globalVars.group]! as List<dynamic>).indexWhere(
            (element) {
              return element ==
                  (FirebaseAuth.instance.currentUser!.displayName! +
                      "," +
                      FirebaseAuth.instance.currentUser!.uid);
            },
          ) +
          1;
    });
    //get weekly mileage
    try {
      await doc.collection("Weekly Mileage").doc(dateToString(widget.startDay)).get().then((value) {
        Map<String, dynamic> data = value.data() as Map<String, dynamic>;
        assignedWeeklyMileage = (data[globalVars.group]! as List<dynamic>)[0];
        weeklyMileage = (data[globalVars.group]! as List<dynamic>)[index];
      });
    } catch (_) {
      assignedWeeklyMileage = "0";
      weeklyMileage = "0";
    }
    //TODO: now way this is the most effecient way to do this
    ///maybe something with lists or maps?
    for (int i = 0; i < 7; i++) {
      DateTime day = widget.startDay.add(Duration(days: i));
      String assignedRun = "Not Assigned";
      String completedRun = "--";
      //get the run itself
      await doc.collection("Scheduled Runs").get().then((QuerySnapshot querySnapshot) async {
        for (var element in querySnapshot.docs) {
          if (element.id == dateToString(day)) {
            Map<String, dynamic> data = element.data() as Map<String, dynamic>;
            assignedRun = (data[globalVars.group]! as List<dynamic>)[0];
            completedRun = (data[globalVars.group]! as List<dynamic>)[index];
          }
        }
      });
      //get the length of the run(after the last comma to the end)
      double distance = -1;
      if (assignedRun != "Not Assigned") {
        distance = double.parse(
          assignedRun.substring(
            assignedRun.lastIndexOf(",") + 2,
            assignedRun.lastIndexOf(" "),
          ),
        );
      }
      //empty choosen, then find runs that fit qualifications(if more than three, choose them at random)
      //need to find a run that is flat, one that is a loop, and one that is an out and back
      //general idea is to loop through generalVars.allRunsList and make a list of all the runs that satisfy distance, and special condition
      List<Run> flats = [];
      List<Run> loops = [];
      List<Run> outAndBacks = [];
      List<RunCard> suggestedRuns = [];
      if (distance != -1) {
        for (Run run in globalVars.allRunsList) {
          if (run.start.keys.toList()[0] == globalVars.defaultStart) {
            //start with the flat
            double margin = globalVars.desiredMargin;
            if ((run.distance <= distance + margin && run.distance >= distance - margin) &&
                run.steepness < 100) {
              flats.add(run);
            }

            //then do loops
            if ((run.distance <= distance + margin && run.distance >= distance - margin) &&
                run.loop) {
              loops.add(run);
            }

            //lastly, out and backs
            if (run.distance >= distance / 2 && !run.loop) {
              outAndBacks.add(run);
            }
          }
        }
        //choose some random ones, make sure there arent any repeats, add them to choosen
        final random = Random();

        //make sure it isnt empty
        if (flats.isNotEmpty) {
          suggestedRuns.add(
            RunCard(
              context: context,
              run: flats[random.nextInt(flats.length)],
              width: MediaQuery.of(context).size.width * .9,
            ),
          );
        }

        //make sure it isnt empty
        if (loops.isNotEmpty) {
          RunCard runCard = RunCard(
            context: context,
            run: loops[random.nextInt(loops.length)],
            width: MediaQuery.of(context).size.width * .9,
          );
          //checks if the run is already in suggested runs
          if (suggestedRuns.where((element) => element.run.route == runCard.run.route).isEmpty) {
            suggestedRuns.add(
              runCard,
            );
          }
        }

        //make sure it isnt empty
        if (outAndBacks.isNotEmpty) {
          RunCard runCard = RunCard(
            context: context,
            run: outAndBacks[random.nextInt(outAndBacks.length)],
            width: MediaQuery.of(context).size.width * .9,
          );
          //checks if the run is already in suggested runs
          if (suggestedRuns.where((element) => element.run.route == runCard.run.route).isEmpty) {
            suggestedRuns.add(
              runCard,
            );
          }
        }
      }

      //create widget to add to the list
      Widget toAdd = (distance !=
              -1) //only make it expansion tile if there actually is an assigned run
          ? Card(
              child: ExpansionTile(
                title: ListTile(
                  title: Text(day.toString().substring(5, 10)),
                  subtitle: Column(children: [
                    Text(
                      completedRun,
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    Text(
                      assignedRun,
                    ),
                  ]),
                ),
                children: [
                  const Text("Suggested Runs:"),
                  Column(
                      children: (suggestedRuns.isEmpty) //checks to see if there actually are any runs
                          //that fit the criteria, of not then we say there are no runs
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text("No Suggested Runs"),
                              ),
                            ]
                          : suggestedRuns),
                ],
              ),
            )
          : //other wise just make it a boring old card
          Card(
              child: ListTile(
              title: Text(day.toString().substring(5, 10)),
              subtitle: Column(children: [
                Text(
                  completedRun,
                  style: Theme.of(context).textTheme.headline6,
                ),
                Text(
                  assignedRun,
                ),
              ]),
            ));
      if (assignedRuns != null) {
        assignedRuns.add(toAdd);
      } else {
        assignedRuns = [toAdd];
      }
    }
    return assignedRuns!;
  }

  @override
  void initState() {
    super.initState();
    getRuns();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getRuns(),
        builder: (context, AsyncSnapshot<List<Widget>> snapshot) {
          if (snapshot.hasData) {
            return Column(
              children: snapshot.data! +
                  <Widget>[
                    Text(
                      'Assigned Weekly Mileage: $assignedWeeklyMileage\nCompleted Weekly Mileage: $weeklyMileage',
                      textAlign: TextAlign.center,
                    ),
                  ],
            );
          } else {
            return const Center(child: SizedBox(width: 40, child: CircularProgressIndicator()));
          }
        });
  }
}

class RunCard extends StatelessWidget {
  const RunCard({
    Key? key,
    required this.context,
    required this.run,
    this.width,
  }) : super(key: key);

  final BuildContext context;
  final Run run;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () async {
        var url = "https://www.mappedometer.com/?maproute=" + run.route.toString();
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          throw 'Could not launch $url';
        }
      },
      child: Card(
        elevation: 5,
        child: Container(
            width: width,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * (.8),
                  child: Text(
                    run.runName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                  ),
                ),
                Text(run.toString(includeName: false)),
              ],
            )),
      ),
    );
  }
}

class JoinTeam extends StatelessWidget {
  const JoinTeam({
    Key? key,
    required this.controller,
    required this.addToTeam,
  }) : super(key: key);
  final Function(String name) addToTeam;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 10),
            Text(
              "Join a Team",
              style: Theme.of(context).textTheme.headline5,
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(label: Text("Team Name")),
              onSubmitted: (String name) => addToTeam(name),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => addToTeam(controller.text), child: const Text("Join")),
            SizedBox(
              height: MediaQuery.of(context).size.height * .2,
            ),
            Tooltip(
              child: TextButton(
                  child: Text(
                    "Want to create a team?\nClick here",
                    style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark)
                            ? Colors.grey
                            : const Color.fromARGB(255, 64, 64, 64)),
                    textAlign: TextAlign.center,
                  ),
                  onPressed: () async {
                    const url = 'https://afoxenrichment.weebly.com/coach.html';
                    if (await canLaunch(url)) {
                      await launch(url);
                    } else {
                      throw 'Could not launch $url';
                    }
                  }),
              message: "Takes you to website to sign up",
            ),
            SizedBox(
              height: MediaQuery.of(context).size.width * .02,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * .6,
              child: Center(
                child: Text(
                  "Want to join an already created team as a coach?\nJoin a team normally and have the exisiting coach make you one",
                  style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark)
                          ? Colors.grey
                          : const Color.fromARGB(255, 64, 64, 64)),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CoachViewTeam extends StatefulWidget {
  const CoachViewTeam({Key? key}) : super(key: key);

  @override
  State<CoachViewTeam> createState() => _CoachViewTeamState();
}

class _CoachViewTeamState extends State<CoachViewTeam> {
  Map<String, List<Map<String, String>>> groups = {};
  Map<String, String> namesToUid = {};
  Map<String, List<String>> athletes = {};
  DateTime selectedDate = DateTime.now();
  Future<void> retrieveData() async {
    DocumentReference doc = FirebaseFirestore.instance.collection('Teams').doc(globalVars.team);

    await doc.get().then((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
      data.forEach(
        (key, value) {
          List<Map<String, String>> values = [];
          for (var element in (value as List<dynamic>)) {
            List<String> elements = (element as String).split(",");
            values.add({elements[0]: elements[1]});
            namesToUid[elements[0]] = elements[1];
            if (athletes[key] == null) {
              athletes[key] = [elements[0]];
            } else {
              athletes[key]!.add(elements[0]);
            }
          }
          groups[key] = values;
        },
      );
    });
  }

  //Get the runs for a specific day
  Future<Map<String, List<String>>> getRunsForDay(DateTime date) async {
    Map<String, List<String>> runs = {};

    String dateString = date.toString().substring(0, 10);
    DocumentReference doc = FirebaseFirestore.instance
        .collection('Teams')
        .doc(globalVars.team)
        .collection('Scheduled Runs')
        .doc(dateString);
    await doc.get().then(
      (DocumentSnapshot documentSnapshot) {
        Map<String, dynamic> data =
            (documentSnapshot.data() != null) ? documentSnapshot.data() as Map<String, dynamic> : {};
        data.forEach((groupName, listOfRuns) {
          runs[groupName] = listOfRuns.cast<String>() ?? [];
        });
      },
    );

    return runs;
  }

  Future<DateTime> _selectDate(BuildContext context, DateTime addDate) async {
    final kToday = DateTime.now();
    final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
    final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: addDate, firstDate: kFirstDay, lastDate: kLastDay);
    if (picked != null && picked != addDate) {
      setState(() {
        addDate = picked;
      });
    }
    return addDate;
  }

  Widget _buildExpandableTile(String currentGroup, List<String> items) {
    return ExpansionTile(
      title: Text(
        currentGroup,
      ),
      children: <Widget>[
        SizedBox(
          height: items.length * 48,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: ((context, index) {
              return ListTile(
                title: Text(
                  items[index],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableRow(Widget title, List<List<String>> items, List<double> widths) {
    if (items[1].isEmpty) {
      items[1] = List.generate(items[0].length, (index) => "");
    }
    if (items[2].isEmpty) {
      items[2] = List.generate(items[0].length, (index) => "");
    }
    return ExpansionTile(
      title: title,
      children: (items.isNotEmpty)
          ? <Widget>[
              SizedBox(
                height: items[0].length * 48,
                child: ListView.builder(
                  itemCount: items[0].length,
                  itemBuilder: ((context, index) {
                    return ListTile(
                      title: Row(
                        children: [
                          SizedBox(
                            width: widths[0],
                            child: Text(items[0][index]),
                          ),
                          SizedBox(
                            width: widths[1],
                            child: Text(items[1][index]),
                          ),
                          SizedBox(
                            width: widths[2],
                            child: Text(items[2][index]),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ]
          : [],
    );
  }

  void _changeRunner(List<String> runnerInfo) async {
    //runnerInfo is [name, newGroup, uid]
    DocumentReference _teamCollectionDoc =
        FirebaseFirestore.instance.collection("Teams").doc(globalVars.team);
    String oldGroup = "";

    ///Steps to do:
    ///change globalVars.group in runners document
    DocumentReference userDoc = FirebaseFirestore.instance.collection("Users").doc(runnerInfo[2]);

    await userDoc.get().then(((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
      oldGroup = data["group"];
    }));
    await userDoc.update({"group": runnerInfo[1]});
    if (runnerInfo[1] == "Coaches") {
      await userDoc.update({"coach": true});
    } else {
      await userDoc.update({"coach": false});
    }

    ///change globalVars.team in groups
    int oldIndex =
        groups[oldGroup]!.indexWhere((element) => element.values.toList()[0] == runnerInfo[2]) + 1;
    groups[oldGroup]!.removeAt(oldIndex - 1);
    groups[runnerInfo[1]]!.add({runnerInfo[0]: runnerInfo[2]});

    ///change globalVars.team on globalVars.team document
    Map<String, List<String>> groupsFormatted = {};
    groups.forEach((String groupName, List<Map<String, String>> listOfAthletes) {
      for (Map<String, String> athlete in listOfAthletes) {
        if (groupsFormatted[groupName] == null) {
          groupsFormatted[groupName] = [athlete.keys.toList()[0] + ',' + athlete.values.toList()[0]];
        } else {
          groupsFormatted[groupName]!
              .add(athlete.keys.toList()[0] + ',' + athlete.values.toList()[0]);
        }
      }
      if (listOfAthletes.isEmpty) {
        groupsFormatted[groupName] = [];
      }
    });

    await _teamCollectionDoc.set(groupsFormatted);

    ///change runners data for every scheduled run
    //some code that loops through every document in the scheduled runs collection
    await _teamCollectionDoc
        .collection("Scheduled Runs")
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> value) async {
      for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
        if (element.id != "blank") {
          Map<String, List<dynamic>> data = element.data().cast<String, List<dynamic>>();

          String run = data[oldGroup]![oldIndex] as String;
          data[oldGroup]!.removeAt(oldIndex);
          data[runnerInfo[1]]!.add(run);

          await _teamCollectionDoc.collection("Scheduled Runs").doc(element.id).update(data);
        }
      }
    });

    ///change runners data for every weekly mileage
    await _teamCollectionDoc
        .collection("Weekly Mileage")
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> value) async {
      for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
        if (element.id != "blank") {
          Map<String, List<dynamic>> data = element.data().cast<String, List<dynamic>>();

          String mileage = data[oldGroup]![oldIndex] as String;
          data[oldGroup]!.removeAt(oldIndex);
          data[runnerInfo[1]]!.add(mileage);

          await _teamCollectionDoc.collection("Weekly Mileage").doc(element.id).update(data);
        }
      }
    });

    ///call retrieve data to fix everything, maybe even will have to add miles
    retrieveData();
    setState(() {});
  }

//allows the globalVars.coach to assign runs to the globalVars.team
  void assignRun() async {
    List<TableRow> tableRows = [
      TableRow(
        children: <Widget>[
          Text(
            "Group",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "Title",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "Descripiton",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "Distance",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ];
    final allDescriptionController = TextEditingController();
    final allTitleController = TextEditingController();
    final allDistanceController = TextEditingController();
    List<String> groupNames = [];
    Map<String, List<TextEditingController>> controllers = {
      "description": <TextEditingController>[],
      "title": <TextEditingController>[],
      "distance": <TextEditingController>[]
    };

    //loop thorugh and make an iddividual row for each globalVars.group
    for (String groupName in groups.keys) {
      if (groupName != "Coaches") {
        final descriptionController = TextEditingController();
        controllers["description"]!.add(descriptionController);
        final titleController = TextEditingController();
        controllers["title"]!.add(titleController);
        final distanceController = TextEditingController();
        controllers["distance"]!.add(distanceController);
        groupNames.add(groupName);
        tableRows.add(
          TableRow(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 15, 5, 5),
                child: Text(
                  groupName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextField(
                controller: titleController,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TextField(
                  controller: descriptionController,
                ),
              ),
              TextField(
                controller: distanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        );
      }
    }
    //All groups rows
    tableRows.insert(
      1,
      TableRow(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 15, 5, 5),
            child: Text(
              "All Groups",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextField(
            controller: allTitleController,
            decoration: const InputDecoration(hintText: "Ex. Recovery Day"),
            onChanged: (value) {
              //So i flipped the fuck out when this worked, basically it just makes all the other textfields change to the "all groups" avlue - WITHOUT CALLING SETSTATE!!!!
              //I thought it would so f***** hard to not lose valuse and send the updates!!!!
              //V. happy abt this code, also very concise
              for (TextEditingController element in controllers["title"]!) {
                element.text = value;
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: TextField(
              controller: allDescriptionController,
              decoration: const InputDecoration(hintText: "Recovery Pace - go slow"),
              onChanged: (value) {
                for (TextEditingController element in controllers["description"]!) {
                  element.text = value;
                }
              },
            ),
          ),
          TextField(
            controller: allDistanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: "6"),
            onChanged: (value) {
              for (TextEditingController element in controllers["distance"]!) {
                element.text = value;
              }
            },
          ),
        ],
      ),
    );
    DateTime addDate = selectedDate;

    //Actual UI Dsiplay
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: <Widget>[
                  Center(
                    child: Text(
                      "Assign a Run",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Table(
                    columnWidths: const {
                      0: FractionColumnWidth(.15),
                      1: FractionColumnWidth(.25),
                      2: FractionColumnWidth(.33),
                      3: FractionColumnWidth(.1),
                    },
                    children: tableRows,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      ElevatedButton(
                          onPressed: () async {
                            //Code to actually assign the run to the athletes
                            //Need to be careful and fill in the lengths correctly, make the doucment titles the right way etc as i had made before, should be crazy fun
                            //Start by making a friestore instance to improve latency
                            DocumentReference teamDoc =
                                FirebaseFirestore.instance.collection("Teams").doc(globalVars.team);
                            CollectionReference schedRunsCollection =
                                teamDoc.collection("Scheduled Runs");

                            String addDateString = addDate.toString().substring(0, 10);
                            DateTime monday = mostRecentMonday(addDate);
                            Map<String, List<String>> groupsToRuns = {};
                            //Then loop through every globalVars.group on the globalVars.team
                            for (String groupName in groupNames) {
                              int index = groupNames.indexOf(groupName);
                              int num = groups[groupName]!.length;

                              //Stuff to get scheduled runs working
                              if (controllers["title"]![index].text != "" &&
                                  controllers["description"]![index].text != "" &&
                                  controllers["distance"]![index].text != "") {
                                Plan planned = Plan(
                                  controllers["title"]![index].text,
                                  controllers["description"]![index].text,
                                  double.parse(controllers["distance"]![index].text),
                                );
                                groupsToRuns[groupName] = [planned.toDatabaseString()];
                                while (groupsToRuns[groupName]!.length <= num) {
                                  groupsToRuns[groupName]!.add("Not Completed");
                                }
                              }
                            }

                            schedRunsCollection.doc(addDateString).update(groupsToRuns).onError(
                                (error, stackTrace) =>
                                    schedRunsCollection.doc(addDateString).set(groupsToRuns));

                            await addWeeklyMiles(monday);
                            //at the end pop the dialog and call setState
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text("Assign")),
                      IconButton(
                        onPressed: () async {
                          addDate = await _selectDate(context, addDate);
                        },
                        icon: const Icon(Icons.today),
                      ),
                    ],
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  )
                ],
              ),
            ),
          );
        });
  }

  void assignRunners() {
    List<List<String>> athletesToGroups =
        []; //Lists of [name, globalVars.group, uid] for each athlete/globalVars.coach
    for (String groupName in athletes.keys) {
      for (String athlete in athletes[groupName]!) {
        athletesToGroups.add([athlete, groupName, namesToUid[athlete]!]);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              itemCount: athletesToGroups.length,
              itemBuilder: (context, index) {
                if (FirebaseAuth.instance.currentUser!.displayName != athletesToGroups[index][0]) {
                  return ListTile(
                    title: Row(
                      children: [
                        Text(athletesToGroups[index][0]),
                        DropdownButton(
                            value: athletesToGroups[index][1],
                            items: groups.keys.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              athletesToGroups[index][1] = value!;
                              _changeRunner(athletesToGroups[index]);
                              setState(() {});
                            })
                      ],
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    ),
                  );
                } else {
                  return ListTile(
                    title: Row(
                      children: <Widget>[
                        Text(athletesToGroups[index][0]),
                        const Tooltip(
                          child: Text("(You)", style: TextStyle(color: Colors.grey)),
                          message:
                              "Please go to https://afoxenrichment.weebly.com/contact.html to request a change of team ownership",
                        )
                      ],
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, List<String>>> getMileagesForWeek(DateTime monday) async {
    Map<String, List<String>> mileages = {};
    String dateString = monday.toString().substring(0, 10);
    DocumentReference doc = FirebaseFirestore.instance
        .collection('Teams')
        .doc(globalVars.team)
        .collection('Weekly Mileage')
        .doc(dateString);
    await doc.get().then((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data =
          (documentSnapshot.data() != null) ? documentSnapshot.data() as Map<String, dynamic> : {};
      data.forEach((groupName, listOfRuns) {
        mileages[groupName] = listOfRuns.cast<String>() ?? [];
      });
    });
    return mileages;
  }

//Function to dynamically build the rows of the table
  Future<List<Widget>> generateTable() async {
    if (groups.isEmpty) {
      await retrieveData();
    }
    Size size = MediaQuery.of(context).size;
    double coulmn1Width = size.width * .285;
    double coulmn2Width = size.width * .46;
    double coulmn3Width = size.width * .1;
    Map<int, String> weekdays = {
      1: "Mon",
      2: "Tue",
      3: "Wed",
      4: "Thur",
      5: "Fri",
      6: "Sat",
      7: "Sun"
    };
    List<Widget> tableRows = [
      //Default Header Table Row
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(255, 30, 30, 30),
              spreadRadius: 5,
              blurRadius: 9,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              globalVars.team,
              style: Theme.of(context).textTheme.headline4,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                //Assign runs button
                SizedBox(
                  width: coulmn1Width,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: size.height * .01, horizontal: size.width * .07),
                    child:
                        ElevatedButton(onPressed: () => assignRun(), child: const Text("Assign Run")),
                  ),
                ),
                //Date and ability to go back and forth
                SizedBox(
                  width: coulmn2Width,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          selectedDate = selectedDate.subtract(const Duration(days: 1));
                          setState(() {});
                        },
                        icon: const Icon(Icons.west),
                      ),
                      TextButton(
                          onPressed: (() => setState(() {
                                selectedDate = DateTime.now();
                              })),
                          child: Text(
                            ((selectedDate.toString().substring(0, 10) ==
                                        DateTime.now().toString().substring(0, 10))
                                    ? "Today, "
                                    : "") +
                                weekdays[selectedDate.weekday]! +
                                " " +
                                selectedDate.month.toString() +
                                "/" +
                                selectedDate.day.toString(),
                            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                          )),
                      IconButton(
                        onPressed: () {
                          selectedDate = selectedDate.add(const Duration(days: 1));
                          setState(() {});
                        },
                        icon: const Icon(Icons.east),
                      ),
                    ],
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  ),
                ),
                //Weekly Mileage
                SizedBox(
                  width: coulmn3Width,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: size.height * .01, horizontal: size.width * .001),
                    child: const Center(child: Text("Weekly Mileage")),
                  ),
                ),
                IconButton(
                  onPressed: assignRunners,
                  icon: const Icon(Icons.group_add),
                  tooltip: "Assign Runners To Groups",
                ),
              ],
            ),
          ],
        ),
      )
    ];

    List<String> groupsNames = groups.keys.toList();
    Map<String, List<String>> groupsToRuns = await getRunsForDay(selectedDate);

    Map<String, List<String>> weeklyMileages =
        await getMileagesForWeek(mostRecentMonday(selectedDate));

    for (String groupName in groupsNames) {
      if (groupName != "Coaches") {
        tableRows.add(_buildExpandableRow(
            Row(
              children: [
                //Name of runner/globalVars.group
                SizedBox(
                  width: coulmn1Width,
                  child: Text(groupName),
                ),
                //Run
                SizedBox(
                  width: coulmn2Width,
                  child: Text(groupsToRuns[groupName]?[0] ?? ""),
                ),
                //Weekly Mileage
                SizedBox(
                  width: coulmn3Width,
                  child: Text(weeklyMileages[groupName]?[0] ?? ""),
                ),
              ],
            ),
            [
              athletes[groupName] ?? [],
              groupsToRuns[groupName]?.sublist(1) ?? [],
              weeklyMileages[groupName]?.sublist(1) ?? []
            ],
            [
              coulmn1Width,
              coulmn2Width,
              coulmn3Width
            ]));
      }
    }
    tableRows.add(_buildExpandableTile("Coaches", athletes["Coaches"]!));
    return tableRows;
  }

  @override
  Widget build(BuildContext context) {
    double _width = MediaQuery.of(context).size.width;
    double _height = MediaQuery.of(context).size.height;

    Future<List<Widget>> tableRows = generateTable();

    return Scaffold(
      bottomNavigationBar: const FooterButtons("team"),
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: backgroundDecoration(context),
        child: Center(
          child: SizedBox(
            width: _width,
            height: _height,
            child: FutureBuilder<List<Widget>>(
                future: tableRows,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView(children: snapshot.data!);
                  } else {
                    return const Center(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                }),
          ),
        ),
      ),
    );
  }
}

class CreateTeam extends StatefulWidget {
  const CreateTeam({Key? key}) : super(key: key);

  @override
  State<CreateTeam> createState() => _CreateTeamState();
}

class _CreateTeamState extends State<CreateTeam> {
  final nameController = TextEditingController();
  final ScrollController _controller = ScrollController();
  List<String> groups = ["General"];
  String teamName = "Team Name";
  void _scrollDown() {
    _controller.animateTo(
      _controller.position.maxScrollExtent + 75,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _scrollUp() {
    _controller.animateTo(
      _controller.position.maxScrollExtent - 75,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    double listHeight = MediaQuery.of(context).size.height * .55;
    return Scaffold(
        //TODO: fix this title
        appBar: AppBar(
          title: const Text("Create a Team"),
        ),
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: const FooterButtons("team"),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: backgroundDecoration(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
            child: Center(
              child: Column(
                children: <Widget>[
                  //Team name
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      label: Text(teamName),
                    ),
                    onSubmitted: (value) {
                      teamName = value;
                      setState(() {});
                    },
                  ),
                  //Mileage Groups
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Mileage Groups",
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 60,
                    height: listHeight,
                    child: ListView.builder(
                      controller: _controller,
                      itemCount: groups.length,
                      itemBuilder: ((context, index) {
                        final myController = TextEditingController();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 60,
                            height: 75,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                              child: Stack(
                                children: [
                                  TextField(
                                    onSubmitted: ((value) {
                                      groups[index] = value;

                                      setState(() {});
                                    }),
                                    controller: myController,
                                    decoration: InputDecoration(
                                      label: Text(groups[index]),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    child: IconButton(
                                        onPressed: () {
                                          groups[index] = myController.text;
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.done)),
                                  )
                                ],
                              ),
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.onPrimary),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: <Widget>[
                          //Add globalVars.group button
                          Visibility(
                            visible: groups.length < 10,
                            child: IconButton(
                                onPressed: () {
                                  groups.add("Group #" + (groups.length + 1).toString());
                                  setState(() {});
                                  if ((groups.length * 80) - 80 > listHeight) {
                                    _scrollDown();
                                  }
                                },
                                icon: const Icon(Icons.add)),
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          //subtract globalVars.group button
                          Visibility(
                            visible: groups.length > 1,
                            child: IconButton(
                                onPressed: () {
                                  groups.removeLast();
                                  setState(() {});
                                  if ((groups.length * 80) > listHeight) {
                                    _scrollUp();
                                  }
                                },
                                icon: const Icon(Icons.remove)),
                          )
                        ],
                      ),
                      ElevatedButton(
                          onPressed: () {
                            CollectionReference _collectionRef =
                                FirebaseFirestore.instance.collection('Teams');
                            DocumentReference doc = _collectionRef.doc(teamName);
                            doc.get().then((DocumentSnapshot documentSnapshot) async {
                              //Check if the document exists or not
                              //If it does, suggest they try a new name
                              if (documentSnapshot.exists) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Name of globalVars.team already exists"),
                                        content: const Text("Try changing the name"),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: const Text("Ok"))
                                        ],
                                      );
                                    });
                              } else if (groups.contains("Coaches")) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Cannot call a globalVars.group "Coaches"'),
                                        content: const Text(
                                            "Try changing the name(don't worry, \nthere is a way to add coaches later)"),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: const Text("Ok"))
                                        ],
                                      );
                                    });
                              } else if (groups.contains("Unassigned")) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title:
                                            const Text('Cannot call a globalVars.group "Unassigned"'),
                                        content: const Text(
                                            "Try changing the name(this is where\nnew runners automatically go)"),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: const Text("Ok"))
                                        ],
                                      );
                                    });
                              } else {
                                User user = FirebaseAuth.instance.currentUser!;

                                Map<String, dynamic> data = {
                                  "Coaches": [user.displayName! + "," + user.uid],
                                  "Unassigned": []
                                };
                                for (var element in groups) {
                                  data[element] = [];
                                }
                                await doc.set(data);
                                await doc.collection("Scheduled Runs").doc("blank").set({});
                                await doc.collection("Weekly Mileage").doc("blank").set({});
                                globalVars.team = teamName;
                                globalVars.group = "Coaches";
                                syncToProfile();
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Team Succesfully Created")));
                              }
                            });
                          },
                          child: const Text("Create Team"))
                    ],
                  )
                  //Logo/profile pics?
                  //Descripiton
                ],
              ),
            ),
          ),
        ));
  }
}

void findTeam(context) {
  showDialog(
      context: context,
      builder: (context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: Text("Boo!")),
          ),
        );
      });
}

DateTime mostRecentMonday(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

String dateToString(DateTime date) => date.toString().substring(0, 10);

Future<void> addWeeklyMiles(DateTime monday) async {
  //function that will add up the miles for the week starting on given monday
  Map<String, List<String>> mileages = {};
  CollectionReference _collectionRef = FirebaseFirestore.instance
      .collection('Teams')
      .doc(globalVars.team)
      .collection('Scheduled Runs');
  //Loop through the next 7 days
  for (int i = 0; i <= 7; i++) {
    String dateString = monday.add(Duration(days: i)).toString().substring(0, 10);
    DocumentReference doc = _collectionRef.doc(dateString);
    await doc.get().then((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data =
          (documentSnapshot.data() != null) ? documentSnapshot.data() as Map<String, dynamic> : {};
      data.forEach((groupName, runs) {
        List<String> listOfRuns = runs.cast<String>();
        for (int j = 0; j < listOfRuns.length; j++) {
          String run = listOfRuns[j];

          if (run != "Not Completed" && run != "") {
            //essentially if j=0
            if (mileages[groupName] == null) {
              mileages[groupName] = [run.substring(run.lastIndexOf(", ") + 2, run.lastIndexOf(" "))];
            } else {
              double newMiles =
                  double.parse((run.substring(run.lastIndexOf(", ") + 2, run.lastIndexOf(" "))));
              try {
                mileages[groupName]![j] =
                    (double.parse(mileages[groupName]![j]) + newMiles).toString();
              } catch (_) {
                mileages[groupName]!.add(newMiles.toString());
              }
            }
          } else {
            if (mileages[groupName]!.length < j + 1) {
              mileages[groupName]!.add("0.0");
            }
          }
        }
      });
    });
  }

  FirebaseFirestore.instance
      .collection('Teams')
      .doc(globalVars.team)
      .collection('Weekly Mileage')
      .doc(monday.toString().substring(0, 10))
      .update(mileages)
      .onError(((error, stackTrace) {
    FirebaseFirestore.instance
        .collection('Teams')
        .doc(globalVars.team)
        .collection('Weekly Mileage')
        .doc(monday.toString().substring(0, 10))
        .set(mileages);
  }));
}

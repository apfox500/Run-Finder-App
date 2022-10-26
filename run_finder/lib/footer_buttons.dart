import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:run_finder/create_run.dart';

import 'login.dart';
import 'main.dart';
import 'map.dart';
import 'run_list.dart';
import 'team.dart';

class FooterButtons extends StatelessWidget {
  final String page;
  const FooterButtons(this.page, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    bool showTeam = true;
    if (!(Platform.isMacOS || MediaQuery.of(context).size.width >= 500) && globalVars.coach) {
      showTeam = false;
    }

    var instance = FirebaseAuth.instance;
    return SizedBox(
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          //Find a location "location"
          IconButton(
            icon: Icon(
              Icons.explore,
              color: (page == "location") ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              if (page != "location") {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.fade,
                    fullscreenDialog: true,
                    child: const FindLongRunScreen(),
                  ),
                );
              }
            },
            tooltip: "Find a Location",
          ),
          //List of runs "list"
          IconButton(
            icon: Icon(Icons.list_alt,
                color: (page == "list") ? Theme.of(context).colorScheme.primary : null),
            onPressed: () {
              if (page != "list") {
                Navigator.push(
                  context,
                  PageTransition(
                    fullscreenDialog: true,
                    type: PageTransitionType.fade,
                    child: const RunScreen(),
                  ),
                );
              }
            },
            tooltip: "List of Runs",
          ),
          //map "map"
          Visibility(
            visible: !Platform.isMacOS,
            child: IconButton(
              icon: Icon(
                Icons.map,
                color: (page == "map") ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: () {
                if (page != "map") {
                  Navigator.push(
                    context,
                    PageTransition(
                      fullscreenDialog: true,
                      type: PageTransitionType.fade,
                      child: const MapViewPage(),
                    ),
                  );
                }
              },
              tooltip: "Map",
            ),
          ),
          //Home "home"
          IconButton(
            icon: Icon(
              Icons.home,
              color: (page == "home") ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              if (page != "home") {
                Navigator.push(
                  context,
                  PageTransition(
                    fullscreenDialog: true,
                    type: PageTransitionType.fade,
                    child: const MyHomePage(),
                  ),
                );
              }
            },
            tooltip: "Home",
          ),
          //Add "add"
          IconButton(
            icon: Icon(
              Icons.add,
              color: (page == "add") ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              if (page != "add") {
                Navigator.push(
                  context,
                  PageTransition(
                    fullscreenDialog: true,
                    type: PageTransitionType.fade,
                    child: const CreateRunPage(),
                  ),
                );
              }
            },
            tooltip: "Home",
          ),

          //team "team"
          IconButton(
            icon: Icon(
              Icons.groups,
              color: (page == "team")
                  ? Theme.of(context).colorScheme.primary
                  : ((instance.currentUser != null && showTeam) ? null : Colors.grey),
            ),
            onPressed: () {
              if (!showTeam) {
                showDialog(
                    context: context,
                    builder: (context) =>
                        AlertDialog(title: const Text("Phone width is too small"), actions: <Widget>[
                          TextButton(onPressed: Navigator.of(context).pop, child: const Text("Ok"))
                        ]));
              } else if (instance.currentUser != null) {
                if (page != "team") {
                  Navigator.push(
                    context,
                    PageTransition(
                      fullscreenDialog: true,
                      type: PageTransitionType.fade,
                      child: const TeamPage(),
                    ),
                  );
                } else {
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                              title: const Text("Must be logged in to access team feature"),
                              actions: <Widget>[
                                TextButton(
                                    onPressed: Navigator.of(context).pop, child: const Text("Ok"))
                              ]));
                }
              }
            },
            tooltip: "Team",
          ),
          //profile "profile"
          IconButton(
            icon: Icon(
              Icons.person,
              color: (page == "profile") ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              if (page != "profile") {
                Navigator.push(
                  context,
                  PageTransition(
                    fullscreenDialog: true,
                    type: PageTransitionType.fade,
                    child: const LoginPage(),
                  ),
                );
              }
            },
            tooltip: "Profile",
          ),
        ],
      ),
    );
  }
}

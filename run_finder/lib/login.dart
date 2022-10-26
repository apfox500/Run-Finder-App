import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutterfire_ui/auth.dart';

import 'globals.dart';
import 'main.dart';
import 'settings.dart';

String accountTypeText = "Athlete";

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

///TODO: update name in teams doc when the person changes their name
///TODO: gotta make login with google and apple work at same time
class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // If the user is already signed-in, use it as initial data
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData) {
          //clears data when the user signs out
          globalVars.coach = false;
          globalVars.team = "None";
          globalVars.group = "None";
          globalVars.kPlans = <DateTime, dynamic>{} as LinkedHashMap<DateTime, dynamic>;
          globalVars = Global();

          return Scaffold(
            appBar: AppBar(
              title: const Text(""),
            ),
            body: const SignInScreen(
              providerConfigs: [
                EmailProviderConfiguration(),
              ],
              headerMaxExtent: 50,
              showAuthActionSwitch: true,
            ),
          );
        }
        if (snapshot.data?.uid != null) {
          bool exists = false;
          FirebaseFirestore.instance.collection("Users").get().then((value) async {
            for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
              if (element.id == snapshot.data?.uid) {
                exists = true;
              }
            }
            if (exists) {
              syncFromProfile();
            } else {
              syncToProfile();
            }
          });
        }

        // Render your application if authenticated
        return ProfileScreen(
          children: [
            //Easter egg bc gavin a bestie chill fella fr fr
            Visibility(
              visible: FirebaseAuth.instance.currentUser!.displayName == "Gavin Utroske",
              child: const Text(
                "GAVIN UTROSKE!!!!!!!",
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 0, 162),
                ),
              ),
            ),
            //Settings
            ListTile(
              leading: const SizedBox(
                  width: 20,
                  child: Icon(
                    Icons.settings,
                  )),
              title: const Text('Settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            Text("You are ${(globalVars.coach) ? "a" : "not a"} coach account"),
            Visibility(
              visible: Theme.of(context).brightness == Brightness.light,
              child: TextButton(
                onPressed: () {
                  if (globalVars.color == const Color.fromARGB(255, 200, 162, 200)) {
                    globalVars.color = const Color.fromARGB(255, 0, 142, 40);
                  } else {
                    globalVars.color = const Color.fromARGB(255, 200, 162, 200);
                  }
                },
                child: const Text("Change Color"),
              ),
            ),
          ],
          /* children: <Widget>[
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(accountTypeText),
                Switch(
                  value: coach,
                  onChanged: (value) {
                    coach = value;
                    syncToProfile();
                    if (value) {
                      accountTypeText = 'Coach';
                    } else {
                      accountTypeText = 'Athlete';
                    }
                    setState(() {});
                  },
                )
              ],
            ),
          ], */
          /* providerConfigs: [
            EmailProviderConfiguration(),
            GoogleProviderConfiguration(
                clientId: '392360097024-bmhramlnsig8cc0b8ev6mgc70sg3172l.apps.googleusercontent.com'),
          ], */
        );
      },
    );
  }
}

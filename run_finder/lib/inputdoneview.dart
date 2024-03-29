import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class InputDoneView extends StatelessWidget {
  const InputDoneView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: double.infinity,
        height: 40,
        child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
              child: CupertinoButton(
                padding: const EdgeInsets.only(right: 24.0, top: 4.0, bottom: 4.0, left: 24),
                onPressed: () {
                  FocusScope.of(context).requestFocus(FocusNode());
                },
                child: Text(
                  "Done",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
                color: Theme.of(context).colorScheme.secondary,
              ),
            )));
  }
}

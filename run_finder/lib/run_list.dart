import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/material.dart';
import 'package:flutterfire_ui/firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'footer_buttons.dart';
import 'main.dart';
import 'run.dart';

//Screen to display all runs we have on record
class RunScreen extends StatefulWidget {
  const RunScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final controller = TextEditingController();
  bool search = false;

  ScrollController myScrollController = ScrollController();
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
    final runsQuery = FirebaseFirestore.instance.collection('PolyRuns').orderBy("distance");
    return Scaffold(
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: const FooterButtons("list"),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: backgroundDecoration(context),
        child: Center(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * .05),
              Text("List of Runs", style: Theme.of(context).textTheme.headline4),
              Visibility(
                visible: search,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    decoration: const InputDecoration(labelText: "Name of run"),
                    controller: controller,
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ),
              ),
              SizedBox(
                height: (MediaQuery.of(context).size.height * ((search) ? .93 : .99)) - 70 - 36 - 50,
                width: MediaQuery.of(context).size.width,
                child: FirestoreListView<Map<String, dynamic>>(
                  query: runsQuery,
                  itemBuilder: (context, snapshot) {
                    Map<String, dynamic> runMap = snapshot.data();

                    if (runMap.isNotEmpty &&
                        runMap["name"]
                            .toString()
                            .toLowerCase()
                            .contains(controller.text.toLowerCase())) {
                      Run run = Run.fromMap(runMap);
                      return InkWell(
                        onTap: () async {
                          showDialog(
                              context: context,
                              builder: (context) {
                                CameraPosition initialCameraPosition = CameraPosition(
                                  target: run.points?.first ??
                                      LatLng(
                                        double.parse(
                                          globalVars.startingPlaces[globalVars.defaultStart]![0],
                                        ),
                                        double.parse(
                                          globalVars.startingPlaces[globalVars.defaultStart]![0],
                                        ),
                                      ),
                                );
                                final id = PolylineId(run.runName);
                                Set<Polyline> polylines = {
                                  id: Polyline(
                                    polylineId: id,
                                    points: run.points!,
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
                                        run.runName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 25),
                                      ),
                                    ),
                                    Text(run.toString(includeName: false)),
                                  ],
                                ),
                              ),
                              /* //favorite
                              Positioned(
                                  child: IconButton(
                                    icon: (run.favorite)
                                        ? const Icon(Icons.favorite_rounded, color: Colors.pink)
                                        : const Icon(
                                            Icons.favorite_border_rounded,
                                            color: Colors.grey,
                                          ),
                                    onPressed: () async {
                                      run.favorite = !run.favorite;
                                      run.hated = false;
                                      if (run.favorite) {
                                        globalVars.hateds.remove(run.runName.toString());
                                        globalVars.favorites.add(run.runName.toString());
                                      } else {
                                        globalVars.favorites.remove(run.runName.toString());
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
                                  icon: (run.hated)
                                      ? Icon(Icons.sports_kabaddi, color: Colors.red[900])
                                      : const Icon(Icons.sports_kabaddi_outlined, color: Colors.grey),
                                  onPressed: () async {
                                    run.hated = !run.hated;
                                    run.favorite = false;
                                    if (run.hated) {
                                      globalVars.favorites.remove(run.runName.toString());
                                      globalVars.hateds.add(run.runName.toString());
                                    } else {
                                      globalVars.hateds.remove(run.runName.toString());
                                    }
                                    syncToProfile();
                                    syncFavsandHats();
                                    setState(() {});
                                  },
                                  tooltip: "Hate",
                                ),
                                right: 30,
                              )
                             */
                            ],
                          ),
                        ),
                      );
                    }
                    return Container();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.search),
        onPressed: () => setState(() {
          search = !search;
        }),
      ),
      /* FloatingActionButton()
        child: const Icon(Icons.add),
        onPressed: () async {
          Navigator.push(
            context,
            PageTransition(child: const CreateRunPage(), type: PageTransitionType.rightToLeft),
          );
          /* bool dismissible = false;
          showDialog(
              barrierDismissible: dismissible,
              context: context,
              builder: (context) {
                return const Center(child: CircularProgressIndicator());
              });
          await _syncRuns();
          dismissible = true;
          Navigator.of(context, rootNavigator: true).pop(); */
        },
        tooltip: 'Create Run',
        heroTag: 'createBtn',
      ),
     */
    );
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:run_finder/main.dart';
import 'package:run_finder/run.dart';
import 'package:url_launcher/url_launcher.dart';

import 'footer_buttons.dart';

//TODO: switch over to Open Street Map
///https://pub.dev/packages/flutter_osm_plugin

class CreateRunPage extends StatefulWidget {
  const CreateRunPage({Key? key}) : super(key: key);

  @override
  State<CreateRunPage> createState() => _CreateRunPageState();
}

class _CreateRunPageState extends State<CreateRunPage> {
  GoogleMapController? mapController; //controller for Google map
  GoogleMapController? miniMapController;
  Set<Marker> markers = {}; //markers for google map
  //Grandview track latLng
  LatLng grandviewTrack = const LatLng(39.5889, -104.7470);
  PolylineId id = const PolylineId("new run");
  Map<PolylineId, Polyline> polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  String googleApiKey = "AIzaSyCO1ZEjr9xOXaggZA2d1IrmbZEjBzx7QuY";
  List<LatLng> points = [];
  List<List<LatLng>> oldPolys = [];
  //Info about the run
  double distance = 0.0;
  double up = 0;
  double down = 0;
  LatLng? startLatLng;
  List<LatLng> polylineCoordinates = [];
  List<String> modes = [];
  String mode = "Road/Path";
  bool goodToGoBack = true;
  MapType mapType = MapType.hybrid;
  /* getDirections() async {
    List<LatLng> polylineCoordinates = [];

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleAPiKey,
      PointLatLng(startLocation.latitude, startLocation.longitude),
      PointLatLng(endLocation.latitude, endLocation.longitude),
      travelMode: TravelMode.walking,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    } else {
      print(result.errorMessage);
    }
    addPolyLine(polylineCoordinates);
  } */

  addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("run");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Theme.of(context).primaryColor,
      points: polylineCoordinates,
      width: 8,
    );
    polylines[id] = polyline;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const FooterButtons("add"),
      body: Stack(
        children: [
          GoogleMap(
            //Map widget from google_maps_flutter package
            zoomGesturesEnabled: true, //enable Zoom in, out on map
            initialCameraPosition: CameraPosition(
              //innital position in map
              target: grandviewTrack, //initial position
              zoom: 17, //initial zoom level
            ),
            markers: markers, //markers to show on map
            mapType: mapType,
            onMapCreated: (controller) {
              //method called when map is created
              setState(() {
                mapController = controller;
              });
            },
            myLocationEnabled: true,
            polylines: Set<Polyline>.of(polylines.values),
            onTap: (LatLng latLng) async {
              //code to add new point to line
              await drawLine(latLng);
              //move the camera
              CameraUpdate.newLatLng(latLng);
              setState(() {});
            },
          ),
          //lil card thing
          Visibility(
            visible: points.isNotEmpty,
            child: Positioned(
              bottom: 25,
              left: 15,
              child: Stack(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: SizedBox(
                        height: 125,
                        width: 175,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              "Distance: ${double.parse((distance).toStringAsFixed(2))}",
                            ),
                            DropdownButton(
                                value: mode,
                                items: ["Road/Path", "Straight line"]
                                    .map(
                                      (String e) => DropdownMenuItem(
                                        child: Text(e),
                                        value: e,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (String? value) {
                                  mode = value!;
                                  setState(() {});
                                }),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                /* //go back
                                TextButton(
                                  onPressed: () {
                                    if (!goodToGoBack) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Are you sure?"),
                                          content: const Text("You will lose all progress"),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                Navigator.of(context, rootNavigator: true).pop();
                                              },
                                              child: const Text("Yes, go Back"),
                                            )
                                          ],
                                        ),
                                      );
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text("Go Back"),
                                ),
                                 */ //svae run
                                ElevatedButton(
                                  onPressed: () async {
                                    await saveRun(context);
                                  },
                                  child: const Text("Save Run"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 5,
                    bottom: 10,
                    child: TextButton(
                      child: Row(
                        children: const [
                          Text(
                            "Undo",
                            style: TextStyle(fontSize: 12),
                          ),
                          Icon(
                            Icons.undo,
                            size: 12,
                          ),
                        ],
                      ),
                      onPressed: () => undoLastPoint(),
                      onLongPress: () {
                        //remove all points
                        undoAll();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
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
          ),
        ],
      ),
    );
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 0.6213711922;
  }

  calculateDistanceElevation(List<LatLng> polylineCoordinates, {bool elevation = false}) async {
    //distance
    distance = 0;
    for (var i = 0; i < polylineCoordinates.length - 1; i++) {
      distance += calculateDistance(polylineCoordinates[i].latitude, polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude, polylineCoordinates[i + 1].longitude);
    }
    //elevation
    if (elevation) {
      List<double> elevations = [];
      int samples = (distance * 100).toInt();
      if (samples > 512) samples = 512;
      //format the url request to make
      //TODO: handle if there are more than the allowed 512 points or 8192 characters
      String locations = "";
      for (LatLng coord in polylineCoordinates) {
        if (locations == "") {
          locations += coord.latitude.toString() + "," + coord.longitude.toString();
        } else {
          locations += "|" + coord.latitude.toString() + "," + coord.longitude.toString();
        }
      }
      //get the elevation data
      String url =
          "https://maps.googleapis.com/maps/api/elevation/json?path=$locations&key=$googleApiKey&samples=$samples";
      http.Response response = await http.get(
        Uri.parse(url),
      );
      //store the results in elevation list
      if ((jsonDecode(response.body) as Map<String, dynamic>)['status'] == "OK") {
        List<dynamic> results =
            (jsonDecode(response.body) as Map<String, dynamic>)['results'] as List<dynamic>;
        for (var result in results) {
          Map<String, dynamic> resultMap = result as Map<String, dynamic>;
          elevations.add(resultMap['elevation']);
        }
        //code to add up all the elevations in up and down
        for (int i = 1; i < elevations.length; i++) {
          double change = elevations[i] - elevations[i - 1];
          if (change > 0) {
            up += change;
          } else {
            down += change * (-1);
          }
        }
      }
    }
  }

  createRun(String name, String start, double distance, double up, double down, double steep,
      bool outBack, List<String> surfaces, String type) async {
    Run run = Run(
      distance: distance,
      start: {
        start: [
          //This was flipped:/ but Im far too lazy to totally reprogram everything so I'll just flip it when I have to.
          points.first.longitude.toString(),
          points.first.latitude.toString(),
        ],
      },
      loop: !outBack,
      steepness: steep,
      surfaces: surfaces,
      warmUp: type == "Warm Up",
      hill: type == "Hill Sprint",
      elevation: ((outBack) ? (up + down) : up).toStringAsFixed(
        2,
      ),
      points: polylines.values.first.points,
      markers: markers,
      runName: name,
    );
    //print(run.polyline!.toJson());
    //print(run.toFirebase());
    await FirebaseFirestore.instance
        .collection("PolyRuns")
        .doc(name)
        .set(run.toFirebase(FirebaseAuth.instance.currentUser?.displayName ?? "Unknown"));
    goodToGoBack = true;
  }

  drawLine(LatLng latLng, {bool undo = false}) async {
    //add to the points of the route
    goodToGoBack = false;
    points.add(latLng);

    modes.add(mode);

    if (markers.isEmpty) {
      markers.add(
        Marker(
          markerId: MarkerId(latLng.toString()),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    } else if (markers.length == 1) {
      //if there are two points, draw a line between them
      //add to the markers
      markers.add(
        Marker(
          markerId: MarkerId(latLng.toString()),
          position: latLng,
        ),
      );
      if (mode == "Road/Path") {
        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          googleApiKey,
          PointLatLng(points[0].latitude, points[0].longitude),
          PointLatLng(points[1].latitude, points[1].longitude),
          travelMode: TravelMode.walking,
        );
        if (result.points.isNotEmpty) {
          for (PointLatLng point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
      } else {
        for (LatLng element in points) {
          polylineCoordinates.add(element);
        }
      }
      polylines[id] = Polyline(
        polylineId: id,
        points: polylineCoordinates,
        width: 7,
        color: Theme.of(context).primaryColor,
      );
      calculateDistanceElevation(polylineCoordinates);
    } else {
      var index = points.length - 2;
      LatLng oldMarkerPosition = points[index];
      //moves the marker from old position to new one
      markers.removeWhere((element) => element.position == oldMarkerPosition);
      markers.add(
        Marker(
          markerId: MarkerId(latLng.toString()),
          position: latLng,
        ),
      );
      if (mode == "Road/Path") {
        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          googleApiKey,
          PointLatLng(points[index].latitude, points[index].longitude),
          PointLatLng(points.last.latitude, points.last.longitude),
          travelMode: TravelMode.walking,
        );
        if (result.points.isNotEmpty) {
          for (PointLatLng point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
      } else {
        polylineCoordinates.add(points.last);
      }
      polylines[id] = Polyline(
        polylineId: id,
        points: polylineCoordinates,
        width: 7,
        color: Theme.of(context).primaryColor,
      );
      calculateDistanceElevation(polylineCoordinates);
    }
    if (!undo) {
      mapController!.animateCamera(
        CameraUpdate.newLatLng(
          latLng,
        ),
      );
    }
    if (polylines.isNotEmpty) {
      oldPolys.add(
        List<LatLng>.from(polylines[id]!.points),
      );
    }
  }

  @override
  void initState() {
    //you can add more markers here
    super.initState();
    undoAll();
  }

  Future<void> saveRun(BuildContext context) async {
    if (points.length > 1) {
      //code to save the run to the database
      //popupdialog to finalize name, out and back, other settings
      final nameController = TextEditingController();
      final startController = TextEditingController();
      startController.text = globalVars.defaultStart;
      List<String> surfaces = [];
      String type = "Normal Run";
      bool outBack = true;
      double endpointDistance = calculateDistance(points.first.latitude, points.first.longitude,
              points.last.latitude, points.last.longitude) *
          5280;
      if (endpointDistance < 200) {
        //if the start and end are within 200 feet of each other
        outBack = false;
      }
      await calculateDistanceElevation(
        polylineCoordinates,
        elevation: true,
      );
      showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(builder: (context, setState) {
              return Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      //title
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Save Run",
                          style: Theme.of(context).textTheme.headline6,
                        ),
                      ),
                      //name
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          label: Text("Name of Run"),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      //distance
                      Text("Distance: ${double.parse(distance.toStringAsFixed(2))}"),
                      //elevation
                      Text("Elevation data: ${double.parse(
                        up.toStringAsFixed(
                          2,
                        ),
                      )} ft up, ${double.parse(
                        down.toStringAsFixed(
                          2,
                        ),
                      )} ft down"),
                      //steepness
                      Text(
                        "Steepness: ${double.parse(
                          ((outBack) ? (up + down) / distance : up / distance).toStringAsFixed(
                            2,
                          ),
                        )} ft/mile",
                      ),
                      //out and back
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          //loop
                          TextButton(
                            onPressed: () {
                              outBack = false;
                              setState(() {});
                            },
                            child: (!outBack)
                                ? const Text("Loop")
                                : Text(
                                    "Loop",
                                    style:
                                        TextStyle(color: Theme.of(context).colorScheme.onBackground),
                                  ),
                          ),
                          //out and back
                          TextButton(
                            onPressed: () {
                              outBack = true;
                              setState(() {});
                            },
                            child: (outBack)
                                ? const Text("Out and Back")
                                : Text(
                                    "Out and Back",
                                    style:
                                        TextStyle(color: Theme.of(context).colorScheme.onBackground),
                                  ),
                          ),
                        ],
                      ),
                      //Starting place
                      TextField(
                        controller: startController,
                        decoration: const InputDecoration(
                          label: Text("Starting Point"),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      //surfaces/types
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          //Surfaces
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Surfaces",
                                style: TextStyle(fontSize: 18),
                              ),
                              //Road
                              TextButton(
                                onPressed: () {
                                  if (surfaces.contains("Road")) {
                                    surfaces.remove("Road");
                                  } else {
                                    surfaces.add("Road");
                                  }
                                  setState(() {});
                                },
                                child: (surfaces.contains("Road")
                                    ? Row(
                                        children: const [
                                          Icon(Icons.edit_road),
                                          Text("Road"),
                                        ],
                                      )
                                    : Text(
                                        "Road",
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onBackground),
                                      )),
                              ),
                              //Sidewalk
                              TextButton(
                                onPressed: () {
                                  if (surfaces.contains("Sidewalk")) {
                                    surfaces.remove("Sidewalk");
                                  } else {
                                    surfaces.add("Sidewalk");
                                  }
                                  setState(() {});
                                },
                                child: (surfaces.contains("Sidewalk")
                                    ? Row(
                                        children: const [
                                          Icon(Icons.transfer_within_a_station),
                                          Text("Sidewalk"),
                                        ],
                                      )
                                    : Text(
                                        "    Sidewalk   ",
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onBackground),
                                      )),
                              ),
                              //Dirt
                              TextButton(
                                onPressed: () {
                                  if (surfaces.contains("Dirt")) {
                                    surfaces.remove("Dirt");
                                  } else {
                                    surfaces.add("Dirt");
                                  }
                                  setState(() {});
                                },
                                child: (surfaces.contains("Dirt")
                                    ? Row(
                                        children: const [
                                          Icon(Icons.grass),
                                          Text("Dirt"),
                                        ],
                                      )
                                    : Text(
                                        "Dirt",
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onBackground),
                                      )),
                              ),
                            ],
                          ),
                          //Types
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Types",
                                style: TextStyle(fontSize: 18),
                              ),
                              //Normal Run
                              TextButton(
                                onPressed: () {
                                  type = "Normal Run";
                                  setState(() {});
                                },
                                child: (type == ("Normal Run")
                                    ? const Text("Normal Run")
                                    : Text(
                                        "Normal Run",
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onBackground),
                                      )),
                              ),
                              //Warm Up
                              TextButton(
                                onPressed: () {
                                  type = "Warm Up";
                                  setState(() {});
                                },
                                child: (type == ("Warm Up")
                                    ? const Text("Warm Up")
                                    : Text(
                                        "Warm Up",
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onBackground),
                                      )),
                              ),
                              //Hill Sprint
                              TextButton(
                                onPressed: () {
                                  type = "Hill Sprint";
                                  setState(() {});
                                },
                                child: (type == ("Hill Sprint")
                                    ? const Text("Hill Sprint")
                                    : Text(
                                        "Hill Sprint",
                                        style: TextStyle(
                                            color: Theme.of(context).colorScheme.onBackground),
                                      )),
                              ),
                            ],
                          ),
                        ],
                      ),
                      //lil baby mini map
                      SizedBox(
                        width: 300,
                        height: 250,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: points[0],
                            zoom: 16,
                          ),
                          zoomControlsEnabled: false,
                          polylines: Set<Polyline>.of(polylines.values),
                          markers: markers,
                          myLocationButtonEnabled: false,
                          myLocationEnabled: false,
                          rotateGesturesEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          onMapCreated: (GoogleMapController controller) async {
                            setState(() {
                              miniMapController = controller;
                              miniMapController!.setMapStyle('''[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f5f5f5"
      }
    ]
  },
  {
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#f5f5f5"
      }
    ]
  },
  {
    "featureType": "administrative",
    "stylers": [
      {
        "visibility": "simplified"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.neighborhood",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#ecf9ec"
      }
    ]
  },
  {
    "featureType": "poi",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#eeeeee"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#e5e5e5"
      },
      {
        "visibility": "simplified"
      }
    ]
  },
  {
    "featureType": "poi.school",
    "stylers": [
      {
        "visibility": "simplified"
      }
    ]
  },
  {
    "featureType": "poi.school",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "simplified"
      }
    ]
  },
  {
    "featureType": "poi.school",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.sports_complex",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#ffffff"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dadada"
      },
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dadada"
      },
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "road.local",
    "stylers": [
      {
        "color": "#d6d6d6"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#9be0fe"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  }
]''');
                              _setMapFitToTour(Set<Polyline>.of(polylines.values));
                              setState(() {});
                            });
                          },
                        ),
                      ),
                      //buttons
                      Row(
                        children: [
                          //cancel
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(context),
                          ),
                          //Save run
                          ElevatedButton(
                            onPressed: () async {
                              //code to save run
                              if (nameController.text == "") {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("No Name"),
                                    content: const Text("Please enter a name for the run"),
                                    actions: [
                                      TextButton(
                                        child: const Text("Ok"),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ),
                                );
                              } else if (startController.text == "") {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("No Starting Point"),
                                    content: const Text("Please enter a name for the starting point"),
                                    actions: [
                                      TextButton(
                                        child: const Text("Ok"),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ),
                                );
                              } else if (surfaces.isEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("No Surfaces"),
                                    content: const Text("Please select the surfaces the run is on"),
                                    actions: [
                                      TextButton(
                                        child: const Text("Ok"),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ),
                                );
                              } else {
                                final runsQuery = FirebaseFirestore.instance.collection('PolyRuns');
                                bool duplicate = false;
                                await runsQuery.get().then((value) {
                                  for (var element in value.docs) {
                                    if (element.id == nameController.text) {
                                      duplicate = true;
                                    }
                                  }
                                });
                                if (!duplicate) {
                                  await createRun(
                                    nameController.text,
                                    startController.text,
                                    distance,
                                    up,
                                    down,
                                    ((outBack) ? (up + down) / distance : up / distance),
                                    outBack,
                                    surfaces,
                                    type,
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Created ${nameController.text} run!'),
                                    ),
                                  );
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Duplicate Name"),
                                      content: RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(
                                              text:
                                                  "Please select a name that isnt being used already, if you think this is an error, please contact me on my website",
                                            ),
                                            TextSpan(
                                                style: TextStyle(
                                                    color: Theme.of(context).colorScheme.secondary),
                                                text: " here",
                                                recognizer: TapGestureRecognizer()
                                                  ..onTap = () async {
                                                    var url =
                                                        "https://afoxenrichment.weebly.com/contact.html";
                                                    if (await canLaunch(url)) {
                                                      await launch(url);
                                                    } else {
                                                      throw 'Could not launch $url';
                                                    }
                                                  })
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text("Ok"),
                                          onPressed: () => Navigator.pop(context),
                                        )
                                      ],
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text("Save"),
                          )
                        ],
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      )
                    ],
                  ),
                ),
              );
            });
          });
    }
  }

  void undoAll() {
    markers = {};
    points = [];
    distance = 0;
    startLatLng = null;
    up = 0;
    down = 0;
    polylines = {};
    polylineCoordinates = [];
    modes = [];
    oldPolys = [];
    goodToGoBack = true;
  }

  undoLastPoint() async {
    /* if (points.isNotEmpty) {
      //remove last from points
      List<LatLng> pointsAdd = [...points];
      pointsAdd.removeLast();
      //copy and remove last from modes
      List<String> modesAdd = [...modes];
      modesAdd.removeLast();
      undoAll();

      for (int i = 0; i < modesAdd.length; i++) {
        //loop thorugh every point with its mode and redraw the whole line :(
        //I'm sure there must be a better way to do this but i can't think of one so here goes
        mode = modesAdd[i];
        await drawLine(pointsAdd[i], undo: true);
      }
    } */
    //print(oldPolys);
    if (oldPolys.length > 1) {
      oldPolys.removeLast();
      points.removeLast();
      polylineCoordinates = List<LatLng>.from(oldPolys.last);
      polylines[id] = Polyline(
        polylineId: id,
        points: polylineCoordinates,
        width: 7,
        color: Theme.of(context).primaryColor,
      );
      //moves the marker to the last known point
      markers = {markers.first};
      markers.add(
        Marker(
          markerId: MarkerId(
            points.last.toString(),
          ),
          position: points.last,
        ),
      );
      calculateDistanceElevation(polylineCoordinates);
    } else if (oldPolys.isEmpty) {
      undoAll();
    } else {
      polylines = {};
      markers = {markers.first};
      polylineCoordinates = [];
      distance = 0;
      up = 0;
      down = 0;
      oldPolys.removeLast();
      points.removeLast();
    }
    if (points.isNotEmpty) {
      mapController!.animateCamera(
        CameraUpdate.newLatLng(
          points.last,
        ),
      );
    }

    setState(() {});
  }

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
    miniMapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLong), northeast: LatLng(maxLat, maxLong)), 20));
  }
}

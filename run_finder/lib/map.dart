import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:run_finder/footer_buttons.dart';

import 'main.dart';
import 'run.dart';

class MapViewPage extends StatefulWidget {
  const MapViewPage({Key? key}) : super(key: key);

  @override
  State<MapViewPage> createState() => _MapViewPageState();
}

class _MapViewPageState extends State<MapViewPage> {
  late Future<Map<PolylineId, Polyline>> polylines;
  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();
  }

  Future<Map<PolylineId, Polyline>> getPolylines() async {
    Map<PolylineId, Polyline> polylinesFuture = {};

    final runsQuery = FirebaseFirestore.instance.collection('PolyRuns');
    await runsQuery.get().then((QuerySnapshot<Map<String, dynamic>> value) {
      for (var element in value.docs) {
        if (element.id != "-1") {
          Map<String, dynamic> data = element.data();
          Run run = Run.fromMap(data);
          PolylineId id = PolylineId(run.runName);
          Color color = Theme.of(context).colorScheme.secondary;
          polylinesFuture[id] = Polyline(
            consumeTapEvents: true,
            polylineId: id,
            points: run.points!,
            color: color,
            width: 5,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                //TODO: make this run stick around
                //possibly use a modal sheet here instead of snack bar
                SnackBar(
                  content: Container(
                    height: 100,
                    padding: const EdgeInsets.all(8),
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
                    ),
                  ),
                ),
              );
            },
          );
        }
      }
    });
    return polylinesFuture;
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
    mapController!.moveCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLong),
            northeast: LatLng(maxLat, maxLong),
          ),
          20),
    );
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 0.6213711922;
  }

  @override
  Widget build(BuildContext context) {
    String defaultName = globalVars.defaultStart;
    LatLng defaultLatLng = LatLng(
      double.parse(globalVars.startingPlaces[defaultName]![0]),
      double.parse(
        globalVars.startingPlaces[defaultName]![1],
      ),
    );
    Set<Marker> markers = {};
    globalVars.startingPlaces.forEach((key, value) {
      markers.add(
        Marker(
          markerId: MarkerId(key),
          position: LatLng(
            double.parse(value[1]),
            double.parse(
              value[0],
            ),
          ),
          infoWindow: InfoWindow(
            title: key,
            snippet: (globalVars.defaultStart == key) ? "Your default start" : null,
          ),
        ),
      );
    });
    return Scaffold(
      body: FutureBuilder<Map<PolylineId, Polyline>>(
        future: getPolylines(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return GoogleMap(
              initialCameraPosition: CameraPosition(target: defaultLatLng, zoom: 16),
              myLocationEnabled: true,
              polylines: snapshot.data!.values.toSet(),
              markers: markers,
              onMapCreated: (GoogleMapController googleMapController) {
                mapController = googleMapController;
                _setMapFitToTour(snapshot.data!.values.where(
                    //basically just include runs that are within 200 ft of the default start
                    (element) {
                  final dist = calculateDistance(
                          element.points.first.latitude,
                          element.points.first.longitude,
                          double.parse(globalVars.startingPlaces[globalVars.defaultStart]![1]),
                          double.parse(globalVars.startingPlaces[globalVars.defaultStart]![0])) *
                      5280;
                  return dist <= 200;
                }).toSet());
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      bottomNavigationBar: const FooterButtons("map"),
    );
  }
}

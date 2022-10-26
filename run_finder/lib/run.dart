import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'main.dart';

//Run class and its declaration and variables and methods to get runs
class Run implements Comparable<Run> {
  String runName;

  int? route;
  double distance;
  String elevation;
  Map<String, List<String>> start;
  bool loop;
  bool hill;
  bool warmUp;
  bool favorite;
  bool hated;
  double steepness;
  List<String> surfaces;
  List<LatLng>? points;
  Set<Marker>? markers;
  Run({
    this.runName = 'Unnamed Run',
    this.route,
    required this.distance,
    this.elevation = 'No Elevation Data Included',
    required this.start,
    required this.loop,
    this.hill = false,
    this.warmUp = false,
    this.favorite = false,
    this.hated = false,
    required this.steepness,
    required this.surfaces,
    this.points,
    this.markers,
  });

  factory Run.fromMap(Map<String, dynamic> json, {BuildContext? context}) {
    List<String> surface = [];
    try {
      surface = json['surface'].split(', ');
    } on Exception {
      surface.add(json['surface']);
    }
    List<LatLng>? pointsList;
    if (json['points'] != null) {
      pointsList = (json['points'] as List<dynamic>)
          .map(
            (e) => LatLng(
              double.parse((e as String).substring(0, e.indexOf(","))),
              double.parse(e.substring(e.indexOf(",") + 1)),
            ),
          )
          .toList();
      //print(pointsList);
    }
    return Run(
      runName: json['name'],
      route: json['route'],
      distance: (json['distance'] is double) ? json['distance'] : json['distance'].toDouble(),
      elevation: (json['elevation gain'] == "")
          ? 'No Elevation Data Included'
          : json['elevation gain'].toString(),
      start: {json['starting place']: json['(long, lat)'].split(',')},
      loop: json['loop'],
      hill: json['hill repeats'],
      warmUp: json['warm up'],
      steepness: json['steepness'].toDouble(),
      hated: (json['hated']) ? (globalVars.hateds.contains(json['route']) ? true : false) : false,
      favorite:
          (json['favorite']) ? (globalVars.favorites.contains(json['route']) ? true : false) : false,
      surfaces: surface,
      points: pointsList,
    );
  }

  @override
  int compareTo(Run other) {
    //if both are favorites
    if (favorite && other.favorite) {
      if (distance > other.distance) {
        return 1;
      } else if (distance < other.distance) {
        return -1;
      }
      //just this one is a favorite
    } else if (favorite) {
      return -1;
      //the other one is a favorite
    } else if (other.favorite) {
      return 1;
    } else {
      //neither is a favorite
      //if this one is hated
      if (hated) {
        return 1;
        //if the other one is hated
      } else if (other.hated) {
        return -1;
        //if neither are hated or favorited
      } else {
        if (distance > other.distance) {
          return 1;
        } else if (distance < other.distance) {
          return -1;
        } else {
          return 0;
        }
      }
    }
    return 0;
  }

  Map<String, dynamic> toFirebase(String user) {
    var ret = {
      'name': runName,
      'route': route,
      'distance': distance,
      'elevation gain': elevation,
      'starting place': start.keys.first,
      'loop': loop,
      'hill repeats': hill,
      'warm up': warmUp,
      'steepness': steepness,
      'hated': hated,
      'favorite': favorite,
      'surface': surfaces.join(", "),
      '(long, lat)': start.values.join(",").replaceAll("[", "").replaceAll("]", ""),
      'created by': user,
    };
    ret['points'] = points!.map((e) => e.latitude.toString() + "," + e.longitude.toString()).toList();
    return ret;
  }

  @override
  String toString({bool includeName = true}) {
    String ret = "";
    if (includeName) {
      ret += runName + ": ";
    }
    if (warmUp) {
      ret += "Traditonally a warmup, a ";
    } else if (hill) {
      ret += "Tradtionally a hill sprint route, a ";
    } else {
      ret += "A ";
    }
    ret += distance.toStringAsFixed(2) +
        " mile " +
        ((loop) ? "loop" : "long out and back") +
        ", starting at " +
        start.keys.toString().substring(1, start.keys.toString().length - 1);
    ret += " on " + surfaces.join(', ');
    if (elevation != "") {
      ret += " and taking you up " +
          elevation.toString() +
          " feet (" +
          steepness.toStringAsFixed(2) +
          " ft/mi).";
    } else {
      ret += ".";
    }
    return ret;
  }
}

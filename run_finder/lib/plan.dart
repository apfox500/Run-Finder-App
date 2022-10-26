class Plan {
  final String title;
  final String description;
  final double distance;

  const Plan(this.title, this.description, this.distance);

  @override
  String toString() {
    return title + ": " + distance.toString() + " miles" "\n" + description;
  }

//What we're using in the teams database
  String toDatabaseString() {
    return title + ": " + description + ", " + distance.toString() + " miles";
  }

//not really json, but its close enough
  String toJson() {
    return title + ":" + description + ":" + distance.toString();
  }
}

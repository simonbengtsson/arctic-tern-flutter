import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';

class MapPage extends StatefulWidget {
  final Journey journey;
  final List<JourneyStop> stops;

  const MapPage({super.key, required this.journey, required this.stops});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  DateTime? lastUpdated;
  LivePosition? vehiclePosition;
  var mapController = MapController();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      this.setState(() {
        // To change bus indicator even if no new data is available
        this.lastUpdated = DateTime.now();
      });
      fetchData();
    });
    mixpanelInstance.track('Page Shown', properties: {
      'Page Name': 'Map',
    });
  }

  @override
  dispose() {
    super.dispose();
    timer?.cancel();
  }

  fetchData() async {
    final pos = await vasttrafikApi.vehiclePosition(widget.journey.journeyGid);
    if (this.mounted) {
      this.setState(() {
        this.vehiclePosition = pos;
      });
    }
  }

  Widget buildOpenStreetMap() {
    final coords =
        widget.stops.map((e) => LatLng(e.stop.lat, e.stop.lon)).toList();
    final isRecent = this.vehiclePosition != null &&
        this
            .vehiclePosition!
            .updatedAt
            .isAfter(DateTime.now().subtract(Duration(minutes: 2)));
    var initial = CameraFit.coordinates(
        coordinates: coords,
        padding: EdgeInsets.only(top: 20, bottom: 50, left: 20, right: 20));
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCameraFit: initial),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'vasttrafik_nara.flown.io',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              strokeWidth: 7,
              points: coords,
              color: widget.journey.bgColor,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            ...coords.asMap().entries.map((it) {
              final isLastOrFirst = it.key == coords.length - 1 || it.key == 0;
              return Marker(
                point: it.value,
                height: isLastOrFirst ? 12 : 7,
                width: isLastOrFirst ? 12 : 7,
                child: Tooltip(
                  message: widget.stops[it.key].stop.name,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.journey.fgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 20,
                bottom: 20,
                child: Wrap(
                  spacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final position = await getCurrentLocation(context)
                              .timeout(Duration(seconds: 5));
                          mapController.move(
                              LatLng(position.latitude, position.longitude),
                              16);
                        } catch (err) {
                          print('Location error');
                        }
                      },
                      child: const Icon(
                        Icons.my_location,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        mapController.fitCamera(initial);
                      },
                      child: const Icon(
                        Icons.polyline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        CurrentLocationLayer(),
        if (this.vehiclePosition != null)
          AnimatedLocationMarkerLayer(
              style: LocationMarkerStyle(
                markerSize: Size(30, 30),
                marker: Container(
                  decoration: BoxDecoration(
                    color: widget.journey.bgColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: isRecent
                      ? Icon(
                          Icons.train,
                          color: widget.journey.fgColor,
                        )
                      : CupertinoActivityIndicator(
                          color: widget.journey.fgColor,
                        ),
                ),
              ),
              position: LocationMarkerPosition(
                latitude: vehiclePosition!.lat,
                longitude: vehiclePosition!.lon,
                accuracy: 0,
              )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.journey.shortName + ' ' + widget.journey.direction,
        ),
      ),
      body: buildOpenStreetMap(),
    );
  }
}

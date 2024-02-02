import 'package:vasttrafik_nara/common.dart';
import 'package:vasttrafik_nara/map_page.dart';
import 'package:vasttrafik_nara/stop_page.dart';
import 'package:vasttrafik_nara/vasttrafik.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JourneyPage extends StatefulWidget {
  final Deparature journey;

  JourneyPage(this.journey);

  @override
  createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  JourneyDetail? journeyDetail;
  ScrollController? _scrollController;
  bool loading = true;

  _JourneyPageState();

  @override
  initState() {
    super.initState();
    fetchData().then((item) {
      trackEvent('Page Shown', {
        'Page Name': 'Journey',
        'Journey Name': widget.journey.name,
        'Journey Direction': widget.journey.direction,
        'Journey Id': widget.journey.journeyRefId,
        'Shown Stop Count': item.length
      });
    });
  }

  Future<List<JourneyStop>> fetchData() async {
    var ref = widget.journey.journeyRefId;
    var detail =
        await vasttrafikApi.getJourneyDetails(widget.journey.stopId, ref);

    if (this.mounted) {
      this.setState(() {
        this.journeyDetail = detail;
        this.loading = false;
      });
    }

    return journeyDetail!.stops;
  }

  hexColor(hexStr) {
    var hex = 'FF' + hexStr.substring(1);
    var numColor = int.parse(hex, radix: 16);
    return Color(numColor);
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.journey.bgColor;
    var lum = bgColor.computeLuminance();

    final stops = this.journeyDetail?.stops ?? [];
    var stopIndex =
        stops.indexWhere((stop) => stop.stopPointId == widget.journey.stopId);
    if (stopIndex == -1) {
      stopIndex = 0;
    }
    this._scrollController =
        ScrollController(initialScrollOffset: stopIndex * 56.0);

    var loader = Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
            child: Column(children: <Widget>[
          CupertinoActivityIndicator(animating: true, radius: 15.0)
        ])));

    var listView = loading || this.journeyDetail == null
        ? loader
        : ListView.builder(
            itemCount: stops.length,
            controller: this._scrollController,
            itemBuilder: (context, index) {
              final stop = stops[index];
              var isActive = stop.stopPointId == widget.journey.stopId;
              var time = '';
              var depTime = stop.departureTime;
              if (depTime != null) {
                time = formatDepartureTime(depTime, false);
              }
              var style = TextStyle(
                fontSize: 18.0,
                color: isActive
                    ? Theme.of(context).colorScheme.onBackground
                    : Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(index < stopIndex ? 0.3 : 0.8),
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
              );

              return Container(
                  child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StopPage(stop: stop.stop),
                    ),
                  );
                },
                selected: isActive,
                title: Text(stop.stop.name, style: style),
                trailing: Text(time, style: style),
              ));
            });

    return Scaffold(
        appBar: AppBar(
          backgroundColor: bgColor,
          systemOverlayStyle: lum < 0.7
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          iconTheme: IconThemeData(color: widget.journey.fgColor),
          actions: [
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'Map',
              onPressed: stops.isEmpty
                  ? null
                  : () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPage(
                              journey: widget.journey,
                              detail: this.journeyDetail!),
                        ),
                      );
                    },
            ),
          ],
          title: Text(widget.journey.shortName + ' ' + widget.journey.direction,
              style: TextStyle(color: widget.journey.fgColor)),
        ),
        body: listView);
  }
}

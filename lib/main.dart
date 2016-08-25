// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' hide Point;

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// Allow circles to grow this much beyond the edges of the screen.
const kExpandBorders = 100.0;

/// Colors of circles on the screen will be randomly chosen from this list.
final circleColors = [
  0xffFC3761,
  0xff3876FD,
  0xff84CE73,
  0xffFD8F38,
  0xff8E4DBB,
  0xffFDD749
].map((c) => new Color(c)).toList();

/// Represents a single circle that's expanding and contracting.
class Circle {
  static final rand = new Random();
  Point center;
  Color color = circleColors[rand.nextInt(circleColors.length)];
  double radius = 1.0;
  double velocity = 0.9;
  bool flip = false;

  void flipIfZero() {
    if (velocity.isNegative && radius <= 1.0) {
      flip = true;
    }
  }

  void flipIntersectingCircles(Circle c2) {
    Circle c1 = this;
    final squared = (pow(c1.center.x - c2.center.x, 2.0) +
        pow(c1.center.y - c2.center.y, 2.0));
    final distance = sqrt(squared);
    if (distance < (c1.radius + c2.radius)) {
      // Edge case: ignore two concentric circles not yet touching.
      if (distance >= (c1.radius - c2.radius).abs()) {
        c1.flip = true;
        c2.flip = true;
      }
    }
  }

  /// Reverse the circles growth if it intersects with the edges of the
  /// rendering area.
  ///
  /// kExpandBorders can be set to allow the rendering area to be larger than
  /// the screen.
  /// The size information is only available from [CustomPainter.paint],
  /// so we can't do this test at the same time as [flipIntersectingCircles].
  void flipIfIntersectsView(Size size) {
    if (velocity > 0.0) {
      if (center.x - radius < -kExpandBorders ||
          center.y - radius < -kExpandBorders ||
          center.x + radius > size.width + kExpandBorders ||
          center.y + radius > size.height + kExpandBorders) {
        flip = true;
      }
    }
  }

  void _applyFlip() {
    if (flip) {
      velocity = -velocity;
      flip = false;
    }
  }

  void updateRadius() {
    _applyFlip();
    radius += velocity;
  }
}

class BouncingCircles extends StatefulWidget {
  @override
  _BouncingCirclesState createState() => new _BouncingCirclesState();
}

class _BouncingCirclesState extends State<BouncingCircles> {
  final circles = <Circle>[];
  final controller = new AnimationController()
    ..repeat(period: const Duration(seconds: 60));

  _BouncingCirclesState() {
    controller.addListener(() => setState(markCirclesToFlip));
    circles.add(new Circle()..center = new Point(100.0, 100.0));
  }

  @override
  void dispose() {
    controller.stop();
    super.dispose();
  }

  void _clearCircles() {
    setState(circles.clear);
  }

  void markCirclesToFlip() {
    for (final c in circles) {
      c.flipIfZero();
    }

    for (int i = 0; i < circles.length - 1; i++) {
      for (int j = i + 1; j < circles.length; j++) {
        circles[i].flipIntersectingCircles(circles[j]);
      }
    }
  }

  void _tapped(BuildContext context, TapDownDetails details) {
    Point local = ((context.findRenderObject() as RenderBox)
        .globalToLocal(details.globalPosition));

    setState(() {
      circles.add(new Circle()..center = local);
      if (circles.length > 50) circles.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(title: new Text('Bouncing Circles')),
        body: new Builder(
            builder: (context) => new GestureDetector(
                onTapDown: (TapDownDetails details) =>
                    _tapped(context, details),
                child: new Container(
                    decoration: new BoxDecoration(
                        backgroundColor: const Color(0xFF000000)),
                    child: new CustomPaint(
                        foregroundPainter: new CirclePainter(circles))))),
        floatingActionButton: new FloatingActionButton(
            onPressed: _clearCircles,
            tooltip: 'Clear',
            child: new Icon(Icons.clear)));
  }
}

/// Renders all circles at once, which is much simpler than trying to represent
/// each circle as a separate widget.
///
/// You can't move this code into [_BouncingCirclesState] because CustomPainter
/// has its own [build] function.
class CirclePainter extends CustomPainter {
  final circles;

  CirclePainter(this.circles);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = new Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final circle in circles) {
      circle.flipIfIntersectsView(size);
      circle.updateRadius();
      paint.color = circle.color;
      canvas.drawCircle(circle.center, circle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

void main() {
  runApp(new MaterialApp(
      title: 'Bouncing Circles',
      routes: <String, WidgetBuilder>{
        '/': (BuildContext context) => new BouncingCircles()
      }));
}

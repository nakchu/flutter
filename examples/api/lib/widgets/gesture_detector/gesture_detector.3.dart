import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      home: TestApp(),
    ),
  );
}

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  State<StatefulWidget> createState() => TestAppState();
}

class TestAppState extends State<TestApp> {
  Offset _basePosition = Offset.zero;
  Offset _dragPosition = Offset.zero;
  @override
  Widget build(BuildContext context) {
    final Offset offset = _dragPosition - _basePosition;
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.all(100),
        child: DragRectBoundaryProvider(
          child: Stack(
            children: <Widget>[
              Container(
                color: Colors.green,
              ),
              Positioned(
                top: offset.dy,
                left: offset.dx,
                child: Builder(
                  builder: (BuildContext context) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (DragStartDetails details) {
                        setState(() {
                          _basePosition = details.globalPosition - offset;
                          _dragPosition = details.globalPosition;
                        });
                      },
                      onPanUpdate: (DragUpdateDetails details) {
                        if (details.isWithinBoundary) {
                          setState(() {
                            _dragPosition = details.globalPosition;
                          });
                        }
                      },
                      onPanOutOfBoundary: (DragOutOfBoundaryDetails details) {
                        setState(() {
                          _dragPosition = details.nearestPositionWithinBoundary;
                        });
                      },
                      dragBoundaryBehavior: DragOutOfBoundaryBehavior.callOutOfBoundary,
                      dragBoundaryProviderBuilder: (BuildContext context) => DragRectBoundaryProvider.of(context),
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.red,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

void main() {
  runApp(SunnyApp());
}

class SunnyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynamic Data Points',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Map<String, dynamic>? _dataPoints;
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchDataPoints();
  }

  Future<void> _fetchDataPoints() async {
    const String url = 'http://103.49.233.45:8000/config/data_points.yaml';
    try {
      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final yamlMap = loadYaml(response.body) as YamlMap;
        final dataPoints = _convertYamlMapToDartMap(yamlMap['data_points'] as YamlMap);
        setState(() {
          _dataPoints = dataPoints;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data points');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(e.toString());
    }
  }

  Map<String, dynamic> _convertYamlMapToDartMap(YamlMap yamlMap) {
    return yamlMap.map((key, value) {
      if (value is YamlMap) {
        return MapEntry(key, _convertYamlMapToDartMap(value));
      } else {
        return MapEntry(key, value);
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  final _pageTitles = ['Comp', 'Cond', 'Frozen Rooms'];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_dataPoints == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Error')),
        body: Center(child: Text('Failed to load configuration.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_currentIndex]),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          Level3Page(level3Data: _dataPoints!['plcs']?['comp'] ?? {}, title: 'Comp', iconPath: 'assets/images/comp.png'),
          Level3Page(level3Data: _dataPoints!['plcs']?['cond'] ?? {}, title: 'Cond', iconPath: 'assets/images/cond.png'),
          Level3Page(level3Data: _dataPoints!['plcs']?['frozen_rooms'] ?? {}, title: 'Frozen Rooms', iconPath: 'assets/images/frozen.png'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/comp.png',
              width: 24,
              height: 24,
            ),
            label: 'Comp',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/cond.png',
              width: 24,
              height: 24,
            ),
            label: 'Cond',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/images/frozen.png',
              width: 24,
              height: 24,
            ),
            label: 'Frozen Rooms',
          ),
        ],
      ),
    );
  }
}

class Level3Page extends StatelessWidget {
  final Map<String, dynamic> level3Data;
  final String title;
  final String iconPath;

  Level3Page({required this.level3Data, required this.title, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: level3Data.entries.map<Widget>((entry) {
        final rowHeader = entry.key;
        final cardsData = entry.value as Map<String, dynamic>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                _capitalize(rowHeader),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            // Cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cardsData.keys.map<Widget>((cardKey) {
                final level6Data = cardsData[cardKey] as Map<String, dynamic>;
                final writeData = level6Data['write'] as Map<String, dynamic>?;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card for level 5 item
                    GestureDetector(
                      onTap: () {
                        print('Tapped on $cardKey');
                      },
                      child: Card(
                        elevation: 4,
                        margin: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                iconPath,
                                width: 40,
                                height: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                _capitalize(cardKey),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Buttons for 'write' data
                    if (writeData != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: writeData.entries.map<Widget>((entry) {
                          final level7Key = entry.key;
                          final level8Data = entry.value as Map<String, dynamic>;
                          final type = level8Data['type'];

                          if (type == 'INTEGER') {
                            // Render small button for 'INTEGER' type
                            return ElevatedButton(
                              onPressed: () {
                                print('Tapped on $level7Key');
                              },
                              child: Text(level7Key),
                            );
                          } else if (type == 'DIGITAL' && level8Data.containsKey('bits')) {
                            // Render individual buttons for each bit under 'DIGITAL'
                            final bits = level8Data['bits'] as Map<String, dynamic>;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: bits.entries.map<Widget>((bitEntry) {
                                final bitName = bitEntry.value;
                                return ElevatedButton(
                                  onPressed: () {
                                    print('Tapped on $bitName');
                                  },
                                  child: Text(bitName),
                                );
                              }).toList(),
                            );
                          }
                          return SizedBox.shrink();
                        }).toList(),
                      ),
                  ],
                );
              }).toList(),
            ),
            Divider(), // Add a divider after each row header
          ],
        );
      }).toList(),
    );
  }

  String _capitalize(String text) {
    return text.replaceAll('_', ' ').split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}


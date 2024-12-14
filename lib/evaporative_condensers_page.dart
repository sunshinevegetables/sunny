import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'evap_cond_details.dart'; // Import the new details page

class EvaporativeCondensersPage extends StatefulWidget {
  @override
  _EvaporativeCondensersPageState createState() => _EvaporativeCondensersPageState();
}

class _EvaporativeCondensersPageState extends State<EvaporativeCondensersPage> {
  List<dynamic> _condensers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCondensers();
  }

  Future<void> _fetchCondensers() async {
    const String url = 'http://103.49.233.45:8000/config/cond_config.yaml';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final yamlMap = loadYaml(response.body);

        // Parse and convert YamlList to a standard Dart List
        final List<dynamic> condensers = (yamlMap['evap_cond'] as YamlList)
            .map((item) => Map<String, dynamic>.from(item as YamlMap))
            .toList();

        setState(() {
          _condensers = condensers;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load condensers: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(e.toString());
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Evaporative Condensers')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _condensers.isEmpty
              ? Center(child: Text('No condensers found'))
              : ListView.builder(
                  itemCount: _condensers.length,
                  itemBuilder: (context, index) {
                    final condenser = _condensers[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        leading: Icon(Icons.cloud),
                        title: Text(condenser['name']),
                        onTap: () {
                          // Navigate to EvapCondDetailsPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EvapCondDetailsPage(condenserName: condenser['name']),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

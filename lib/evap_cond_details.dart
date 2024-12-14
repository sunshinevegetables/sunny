import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'dart:convert';

class EvapCondDetailsPage extends StatefulWidget {
  final String condenserName;

  EvapCondDetailsPage({required this.condenserName});

  @override
  _EvapCondDetailsPageState createState() => _EvapCondDetailsPageState();
}

class _EvapCondDetailsPageState extends State<EvapCondDetailsPage> {
  Map<String, dynamic>? _dataPoints; // Holds the data for the selected condenser
  Map<String, dynamic>? _registerConfig; // Configuration for registers
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConfiguration();
  }

  Future<void> _fetchConfiguration() async {
    const String configUrl = 'http://103.49.233.45:8000/config/evap_cond_digital_register_config.yaml';
    const String dataUrl = 'http://103.49.233.45:8000/plc_data';

    try {
      // Fetch the configuration
      final configResponse = await http.get(Uri.parse(configUrl));
      if (configResponse.statusCode == 200) {
        final yamlMap = loadYaml(configResponse.body);
        final config = _convertYamlMapToDartMap(yamlMap['registers'] as YamlMap);
        setState(() {
          _registerConfig = config;
        });
      } else {
        throw Exception('Failed to load register configuration');
      }

      // Fetch the condenser data
      final dataResponse = await http.get(Uri.parse(dataUrl));
      if (dataResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(dataResponse.body);
        if (data.containsKey(widget.condenserName)) {
          setState(() {
            _dataPoints = data[widget.condenserName]['data'] as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          throw Exception('Condenser data not found for ${widget.condenserName}');
        }
      } else {
        throw Exception('Failed to load condenser data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _sendWriteSignal(String register, int bit, int value, String plcType, String plcName) async {
  const String writeUrl = 'http://103.49.233.45:8000/bit_write_signal';
  try {
    final response = await http.post(
      Uri.parse(writeUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'plc_type': plcType,      // Add PLC type
        'plc_name': plcName,      // Add PLC name
        'register': register,     // Register name
        'bit': bit,               // Bit to write
        'value': value,           // Value to write (1 or 0)
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Command sent successfully')),
      );
    } else {
      throw Exception('Failed to send command: ${response.statusCode}');
    }
  } catch (e) {
    _showErrorDialog('Failed to send command: $e');
  }
}


  // Convert YamlMap to Dart Map
  Map<String, dynamic> _convertYamlMapToDartMap(YamlMap yamlMap) {
    final Map<String, dynamic> result = {};
    yamlMap.forEach((key, value) {
      if (value is YamlMap) {
        result[key] = _convertYamlMapToDartMap(value);
      } else if (value is YamlList) {
        result[key] = value.map((item) => item is YamlMap ? _convertYamlMapToDartMap(item) : item).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  // Get the value of a specific bit in a 16-bit integer
  int getBitValue(int value, int bit) {
    return (value >> bit) & 1;
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
      appBar: AppBar(title: Text(widget.condenserName)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : (_dataPoints == null || _registerConfig == null)
              ? Center(child: Text('No data found for this condenser'))
              : ListView.builder(
                  itemCount: _dataPoints!.length,
                  itemBuilder: (context, index) {
                    final entry = _dataPoints!.entries.elementAt(index);
                    final registerName = entry.key;
                    final value = entry.value;

                    // Filter control signals for the current condenser
                    final condFilter = "COND_${widget.condenserName.split(' ').last}";
                    if (!registerName.contains(condFilter)) {
                      return SizedBox.shrink(); // Skip registers not matching the filter
                    }

                    if (_registerConfig!.containsKey(registerName)) {
                      final config = _registerConfig![registerName];
                      final type = config['type'];

                      if (type == 'DIGITAL' && config['bits'] != null) {
                        final bitConfig = config['bits'] as Map<String, dynamic>;
                        return Card(
                          margin: EdgeInsets.all(8),
                          child: ExpansionTile(
                            title: Text('$registerName (${config['description']})'),
                            subtitle: Text('Value: $value'),
                            children: bitConfig.entries.map((bitEntry) {
                              final bitNumber = int.parse(bitEntry.key.split(' ')[1]);
                              final bitName = bitEntry.value;
                              final bitValue = getBitValue(value, bitNumber);

                              // START, STOP, RESET Buttons
                              if (bitName == "START" || bitName == "STOP" || bitName == "RESET") {
                                return ListTile(
                                  title: Text(bitName),
                                  trailing: GestureDetector(
                                    onLongPress: () => _sendWriteSignal(
                                      registerName, bitNumber, 1, "plc", "Main PLC",
                                    ),
                                    onLongPressUp: () => _sendWriteSignal(
                                      registerName, bitNumber, 0, "plc", "Main PLC",
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                      ),
                                      child: Text(bitName),
                                    ),
                                  ),
                                );
                              }

                              // AUTO/MANUAL or LOCAL/REMOTE Toggle Buttons
                              if (bitName == "AUTO/MANUAL" || bitName == "LOCAL/REMOTE") {
                                final isAutoOrLocal = bitValue == 1;
                                return ListTile(
                                  title: Text(bitName),
                                  trailing: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAutoOrLocal ? Colors.blue : Colors.orange,
                                    ),
                                    child: Text(
                                      isAutoOrLocal
                                          ? (bitName.contains("AUTO") ? "Auto" : "Remote")
                                          : (bitName.contains("AUTO") ? "Manual" : "Local"),
                                    ),
                                  ),
                                );
                              }

                              // PUMP TRIP, PUMP ON, FAIL TO START Status Labels
                              if (bitName == "PUMP TRIP" || bitName == "PUMP ON" || bitName == "FAIL TO START") {
                                final isActive = bitValue == 1;
                                return ListTile(
                                  title: Text(bitName),
                                  trailing: Text(
                                    isActive ? "On" : "Off",
                                    style: TextStyle(
                                      color: isActive
                                          ? (bitName == "PUMP ON" ? Colors.green : Colors.red)
                                          : (bitName == "PUMP ON" ? Colors.red : Colors.green),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }

                              // Default Fallback for Other Bits
                              return ListTile(
                                title: Text(bitName),
                                subtitle: Text('Bit $bitNumber: $bitValue'),
                              );
                            }).toList(),
                          ),
                        );
                      } else {
                        // Render INT or FLOAT registers
                        return Card(
                          margin: EdgeInsets.all(8),
                          child: ListTile(
                            title: Text('$registerName (${config['description']})'),
                            subtitle: Text('Value: $value'),
                          ),
                        );
                      }
                    } else {
                      // Unconfigured register
                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ListTile(
                          title: Text(registerName),
                          subtitle: Text('Value: $value (Unconfigured)'),
                        ),
                      );
                    }
                  },
                ),
    );
  }

}

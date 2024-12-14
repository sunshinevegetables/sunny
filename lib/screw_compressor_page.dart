import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'dart:convert';

class ScrewCompressorPage extends StatefulWidget {
  final Map<String, dynamic> compressor;

  ScrewCompressorPage({required this.compressor});

  @override
  _ScrewCompressorPageState createState() => _ScrewCompressorPageState();
}

class _ScrewCompressorPageState extends State<ScrewCompressorPage> {
  Map<String, dynamic>? _dataPoints; // Holds filtered data for the compressor
  Map<String, dynamic>? _registerConfig; // Configuration for control registers
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConfiguration();
  }

  Future<void> _fetchConfiguration() async {
    const String configUrl = 'http://103.49.233.45:8000/config/screw_comp_digital_register_config.yaml';
    const String dataUrl = 'http://103.49.233.45:8000/plc_data';

    try {
      // Fetch the configuration
      final configResponse = await http.get(Uri.parse(configUrl));
      if (configResponse.statusCode == 200) {
        final yamlMap = loadYaml(configResponse.body) as YamlMap;
        final screwCompressorConfig = _convertYamlMapToDartMap(yamlMap['registers']['Screw_Compressors'] as YamlMap);
        setState(() {
          _registerConfig = screwCompressorConfig;
        });
      } else {
        throw Exception('Failed to load register configuration');
      }

      // Fetch the screw compressor data
      final dataResponse = await http.get(Uri.parse(dataUrl));
      if (dataResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(dataResponse.body);

        // Extract relevant data for the selected compressor
        final compressorKey = "COMP_${widget.compressor['name'].split(' ').last}"; // E.g., "COMP_1"
        if (data['Main PLC']['data'].containsKey(compressorKey)) {
          setState(() {
            _dataPoints = data['Main PLC']['data'][compressorKey] as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          throw Exception('Compressor data not found for ${widget.compressor['name']}');
        }
      } else {
        throw Exception('Failed to load compressor data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(e.toString());
    }
  }



  Future<void> _sendWriteSignal(String register, int bit, int value) async {
    const String writeUrl = 'http://103.49.233.45:8000/bit_write_signal';
    try {
      final response = await http.post(
        Uri.parse(writeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plc_type': 'screw_comp',
          'plc_name': widget.compressor['name'],
          'register': register,
          'bit': bit,
          'value': value,
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

  int getBitValue(int value, int bit) {
    return (value >> bit) & 1;
  }

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
      appBar: AppBar(title: Text(widget.compressor['name'])),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : (_dataPoints == null || _registerConfig == null)
              ? Center(child: Text('No data found for this compressor'))
              : ListView.builder(
                  itemCount: _registerConfig!.length,
                  itemBuilder: (context, index) {
                    final compressorKey = "COMP_${widget.compressor['name'].split(' ').last}";
                    final compressorConfig = _registerConfig![compressorKey];
                    if (compressorConfig == null) {
                      return SizedBox.shrink();
                    }

                    // Render control signals (DIGITAL)
                    final wrConfig = compressorConfig['WR'];
                    if (wrConfig != null && wrConfig['type'] == 'DIGITAL' && wrConfig['bits'] != null) {
                      final bitConfig = wrConfig['bits'] as Map<String, dynamic>;
                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ExpansionTile(
                          title: Text('${compressorKey} WR (${wrConfig['description']})'),
                          subtitle: Text('Digital Control Register'),
                          children: bitConfig.entries.map((bitEntry) {
                            final bitNumber = int.parse(bitEntry.key.split(' ')[1]);
                            final bitName = bitEntry.value;

                            return ListTile(
                              title: Text(bitName),
                              trailing: GestureDetector(
                                onLongPress: () => _sendWriteSignal(compressorKey, bitNumber, 1),
                                onLongPressUp: () => _sendWriteSignal(compressorKey, bitNumber, 0),
                                child: ElevatedButton(
                                  onPressed: () {},
                                  child: Text(bitName),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }

                    // Render measurement signals (FLOAT or INT)
                    final sucPressure = compressorConfig['SUC_PRESSURE'];
                    if (sucPressure != null && (sucPressure['type'] == 'FLOAT' || sucPressure['type'] == 'INT')) {
                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ListTile(
                          title: Text('${compressorKey} SUC_PRESSURE (${sucPressure['description']})'),
                          subtitle: Text('Value: ${_dataPoints![compressorKey]}'),
                        ),
                      );
                    }

                    return SizedBox.shrink();
                  },
                ),
    );
  }

}

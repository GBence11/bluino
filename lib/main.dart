import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluino',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const BluetoothLedPage(),
    );
  }
}

class BluetoothLedPage extends StatefulWidget {
  const BluetoothLedPage({super.key});

  @override
  _BluetoothLedPageState createState() => _BluetoothLedPageState();
}

class _BluetoothLedPageState extends State<BluetoothLedPage> {
  String connectionStatus = "Nincs kapcsolat";
  bool isConnected = false;
  BluetoothConnection? connection;
  String receivedMessage = '';
  int batteryPercentage = 82;
  double? voltage;
  double? current;
  double? power;
  String buffer = '';

  List<BluetoothDevice> devicesList = [];
  StreamSubscription<Uint8List>? _streamSubscription;

  void getBondedDevices() async {
    List<BluetoothDevice> devices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      devicesList = devices;
    });
  }

  void connectToSelectedDevice(BluetoothDevice device) async {
    try {
      final newConnection = await BluetoothConnection.toAddress(device.address);
      print('Connected to the device');
      setState(() {
        connection = newConnection;
        isConnected = true;
        connectionStatus = "Kapcsolódva: ${device.name}";
      });

      _streamSubscription = connection!.input!.listen((Uint8List data) {
        final decoded = utf8.decode(data);
        buffer += decoded;
        int index;
        while ((index = buffer.indexOf('\n')) != -1) {
          String message = buffer.substring(0, index).trim();
          buffer = buffer.substring(index + 1);
          try {
            final jsonData = json.decode(message);
            if (jsonData is Map<String, dynamic>) {
              handleJsonData(jsonData);
            }
          } catch (_) {
            print("Nem sikerült feldolgozni:" + message);
          }
        }

        setState(() {
          receivedMessage = decoded;
        });

        if (decoded.contains('!')) {
          connection!.finish();
          print('Disconnecting by local host');
        }
      });

      _streamSubscription!.onDone(() {
        print('Disconnected by remote request');
        setState(() {
          isConnected = false;
          connectionStatus = "Kapcsolat bontva";
        });
      });
    } catch (e) {
      print('Connection error: \$e');
      setState(() {
        isConnected = false;
        connectionStatus = "Hiba a kapcsolódáskor";
      });
    }
  }

  void sendMessage(String message) {
    if (connection != null && isConnected) {
      connection!.output.add(utf8.encode("\$message\r\n"));
      print("Üzenet küldve:" + message);
    }
  }

  void handleJsonData(Map<String, dynamic> jsonData) {
    setState(() {
      voltage = (jsonData['volt'] as num?)?.toDouble();
      current = (jsonData['amper'] as num?)?.toDouble();
      power = (jsonData['watt'] as num?)?.toDouble();
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    connection?.dispose();
    super.dispose();
  }

  IconData _getBatteryIcon() {
    if (batteryPercentage >= 90) {
      return Icons.battery_full;
    } else if (batteryPercentage >= 80) {
      return Icons.battery_6_bar;
    } else if (batteryPercentage >= 70) {
      return Icons.battery_5_bar;
    } else if (batteryPercentage >= 50) {
      return Icons.battery_4_bar;
    } else if (batteryPercentage >= 40) {
      return Icons.battery_3_bar;
    } else if (batteryPercentage >= 20) {
      return Icons.battery_2_bar;
    } else if (batteryPercentage >= 10) {
      return Icons.battery_1_bar;
    } else {
      return Icons.battery_alert;
    }
  }

  Color _getBatteryColor() {
    if (batteryPercentage >= 40) {
      return Colors.green;
    } else if (batteryPercentage >= 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bluino")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              connectionStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                getBondedDevices();
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Válassz egy eszközt"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: devicesList.length,
                          itemBuilder: (context, index) {
                            BluetoothDevice device = devicesList[index];
                            return ListTile(
                              title: Text(device.name ?? "Névtelen"),
                              subtitle: Text(device.address),
                              onTap: () {
                                Navigator.of(context).pop();
                                connectToSelectedDevice(device);
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              child: const Text("Bluetooth eszközök"),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Volt : ${voltage?.toStringAsFixed(2) ?? '-'} V",
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Amper : ${current?.toStringAsFixed(2) ?? '-'} A",
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Watt : ${power?.toStringAsFixed(2) ?? '-'} W",
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Icon(
                      _getBatteryIcon(),
                      size: 80,
                      color: _getBatteryColor(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "$batteryPercentage%",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SecondPage(
                      connection: connection,
                      isConnected: isConnected,
                      sendMessage: sendMessage,
                      voltage: voltage,
                      current: current,
                      power: power,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: const Text("DCDC/Buckboost"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isConnected
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LampPage(
                            connection: connection,
                            isConnected: isConnected,
                            sendMessage: sendMessage,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: const Text("Lamp"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      batteryPercentage = (batteryPercentage - 1).clamp(0, 100);
                    });
                  },
                  child: const Text("-"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      batteryPercentage = (batteryPercentage + 1).clamp(0, 100);
                    });
                  },
                  child: const Text("+"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SecondPage extends StatefulWidget {
  final BluetoothConnection? connection;
  final bool isConnected;
  final Function(String) sendMessage;
  final double? voltage;
  final double? current;
  final double? power;

  const SecondPage({
    super.key,
    required this.connection,
    required this.isConnected,
    required this.sendMessage,
    this.voltage,
    this.current,
    this.power,
  });

  @override
  _SecondPageState createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  double _sliderValue = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DCDCmodul")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Slider(
              value: _sliderValue,
              min: 5,
              max: 40,
              divisions: 35,
              label: _sliderValue.toStringAsFixed(0),
              onChanged: (double value) {
                setState(() {
                  _sliderValue = value;
                });
              },
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Volt : ${widget.voltage?.toStringAsFixed(2) ?? '-'} V",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Amper : ${widget.current?.toStringAsFixed(2) ?? '-'} A",
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Watt : ${widget.power?.toStringAsFixed(2) ?? '-'} W",
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Érték: ${_sliderValue.toStringAsFixed(1)}",
              style: const TextStyle(fontSize: 18),
            ),
            ElevatedButton(
              onPressed: () {
                final jsonMessage = jsonEncode({
                  "M": 1,
                  "Vout": _sliderValue * 1000,
                });
                widget.sendMessage(jsonMessage);
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: const Text("Beállítás"),
            ),
          ],
        ),
      ),
    );
  }
}

class LampPage extends StatefulWidget {
  final BluetoothConnection? connection;
  final bool isConnected;
  final Function(String) sendMessage;

  const LampPage({
    super.key,
    required this.connection,
    required this.isConnected,
    required this.sendMessage,
  });

  @override
  _LampPageState createState() => _LampPageState();
}

class _LampPageState extends State<LampPage> {
  bool isOn = false;
  double brightness = 0.5;

  void sendLampState() {
    final message = jsonEncode({
      "lamp": isOn ? 1 : 0,
      "brightness": brightness,
    });
    widget.sendMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lámpa vezérlés")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Lámpa be / ki"),
              value: isOn,
              onChanged: (value) {
                setState(() {
                  isOn = value;
                  sendLampState();
                });
              },
            ),
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: -1, // Függőleges csúszka
                  child: Slider(
                    value: brightness,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    label: "${(brightness * 100).round()}%",
                    onChanged: (value) {
                      setState(() {
                        brightness = value;
                        sendLampState();
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class pchargePage extends StatelessWidget {
  const pchargePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Telefon töltő modul")),
      body: const Center(
        child: Text(
          'Coming soon',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// A SecondPage, LampPage, pchargePage osztályok logikailag nem változnak, mivel azok nem használják a Bluetooth streamet közvetlenül,
// így azok kódját nem szükséges módosítani a jelen hiba javítása miatt.

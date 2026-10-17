import 'package:flutter/services.dart';
class BluetoothService {
  BluetoothService._();
  static final instance = BluetoothService._();
  static const _methods = MethodChannel('wasl/bluetooth/methods');
  static const _events = EventChannel('wasl/bluetooth/events');
  Stream<Map<String,dynamic>> get events => _events.receiveBroadcastStream()
    .map((e) => Map<String,dynamic>.from(e as Map));
  Future<void> createRoom(String roomId, String code, String name) =>
    _methods.invokeMethod('startRoom', {'roomId':roomId,'code':code,'ownerName':name});
  Future<void> discover() => _methods.invokeMethod('discover');
  Future<void> join(String address, String code, String name) =>
    _methods.invokeMethod('joinRoom', {'address':address,'code':code,'name':name});
  Future<void> approve(String id, bool accept) =>
    _methods.invokeMethod('approveMember', {'requestId':id,'accepted':accept});
  Future<void> send(Map<String,Object?> packet) => _methods.invokeMethod('sendPacket',packet);
  Future<void> disconnect() => _methods.invokeMethod('disconnect');
}

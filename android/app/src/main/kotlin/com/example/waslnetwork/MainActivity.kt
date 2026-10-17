package com.example.waslnetwork

import android.Manifest
import android.bluetooth.*
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity: FlutterActivity() {
 private val method="wasl/bluetooth/methods"; private val event="wasl/bluetooth/events"
 private val uuid=UUID.fromString("31f6ad9e-46f3-4b13-93c0-4c4e1ad28a10")
 private val executor=Executors.newCachedThreadPool(); private val handler=Handler(Looper.getMainLooper())
 private var sink:EventChannel.EventSink?=null; private var adapter:BluetoothAdapter?=null
 private var server:BluetoothServerSocket?=null; private var code=""; private var roomId=""; private var host=false
 private val running=AtomicBoolean(false); private val sockets=CopyOnWriteArrayList<BluetoothSocket>()
 private val outputs=CopyOnWriteArrayList<OutputStream>(); private val pending=java.util.concurrent.ConcurrentHashMap<String,BluetoothSocket>()
 private val blocked=java.util.concurrent.ConcurrentHashMap.newKeySet<String>()
 private val receiver=object:BroadcastReceiver(){override fun onReceive(c:Context?,i:Intent?){if(i?.action==BluetoothDevice.ACTION_FOUND){val d=i.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)?:return; emit(mapOf("type" to "device","name" to (try{d.name?:"Bluetooth device"}catch(_:Exception){"Bluetooth device"}),"address" to d.address))}}}
 override fun configureFlutterEngine(engine:FlutterEngine){super.configureFlutterEngine(engine);adapter=BluetoothAdapter.getDefaultAdapter()
 EventChannel(engine.dartExecutor.binaryMessenger,event).setStreamHandler(object:EventChannel.StreamHandler{override fun onListen(a:Any?,s:EventChannel.EventSink?){sink=s};override fun onCancel(a:Any?){sink=null}})
 MethodChannel(engine.dartExecutor.binaryMessenger,method).setMethodCallHandler{call,result->when(call.method){
 "startRoom"->{if(!check(result))return@setMethodCallHandler;roomId=call.argument<String>("roomId")?:"";code=call.argument<String>("code")?:"";startHost(result)}
 "discover"->{if(!check(result))return@setMethodCallHandler;try{try{unregisterReceiver(receiver)}catch(_:Exception){};registerReceiver(receiver,IntentFilter(BluetoothDevice.ACTION_FOUND));adapter?.cancelDiscovery();if(adapter?.startDiscovery()==true)result.success(null)else result.error("SCAN","Could not start discovery",null)}catch(e:Exception){result.error("SCAN",e.message,null)}}
 "joinRoom"->{if(!check(result))return@setMethodCallHandler;join(call.argument<String>("address")?:"",call.argument<String>("code")?:"",call.argument<String>("name")?:"Member",result)}
 "approveMember"->{val id=call.argument<String>("requestId")?:"";val accepted=call.argument<Boolean>("accepted")?:false;val s=pending.remove(id);if(s==null){result.error("REQUEST","Request expired",null)}else{executor.execute{try{val o=s.outputStream;synchronized(o){o.write((JSONObject().put("type",if(accepted)"accepted" else "rejected").put("roomId",roomId).toString()+"\n").toByteArray());o.flush()};if(accepted){sockets.add(s);outputs.add(o);handleHost(s)}else s.close()}catch(_:Exception){} };result.success(null)}}
 "banDevice"->{val id=call.argument<String>("deviceId")?:"";blocked.add(id);sockets.toList().forEach{try{if(it.remoteDevice.address==id)it.close()}catch(_:Exception){}};result.success(null)}
 "sendPacket"->{val map=call.arguments as? Map<*,*>?:emptyMap<Any,Any>();val p=JSONObject();map.forEach{k,v->if(k is String)p.put(k,v)};if(!running.get())result.error("OFFLINE","No active connection",null)else{send(p);result.success(null)}}
 "disconnect"->{stopAll();result.success(null)}
 else->result.notImplemented()
 }}
 }
 private fun check(r:MethodChannel.Result):Boolean{if(Build.VERSION.SDK_INT>=31&&!arrayOf(Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT,Manifest.permission.BLUETOOTH_ADVERTISE).all{ContextCompat.checkSelfPermission(this,it)==PackageManager.PERMISSION_GRANTED}){ActivityCompat.requestPermissions(this,arrayOf(Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT,Manifest.permission.BLUETOOTH_ADVERTISE),400);r.error("PERMISSION","Grant Bluetooth permissions and retry",null);return false};if(adapter==null){r.error("NO_BLUETOOTH","Bluetooth is not supported",null);return false};if(adapter?.isEnabled!=true){startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),503);r.error("BLUETOOTH_OFF","Enable Bluetooth and retry",null);return false};return true}
 private fun emit(m:Map<String,Any?>){handler.post{sink?.success(m)}};private fun state(m:String,c:Boolean){emit(mapOf("type" to "state","message" to m,"connected" to c))}
 private fun startHost(r:MethodChannel.Result){stopAll();host=true;running.set(true);executor.execute{try{server=adapter!!.listenUsingRfcommWithServiceRecord("Wasl-$code",uuid);state("Room ready: $code",true);handler.post{r.success(null)};while(running.get()){val s=server?.accept()?:break;executor.execute{handshake(s)}}}catch(e:Exception){if(running.get())emit(mapOf("type" to "error","message" to "Host error: ${e.message}"));handler.post{if(running.get())r.error("HOST",e.message,null)}}}}
 private fun handshake(s:BluetoothSocket){try{val reader=BufferedReader(InputStreamReader(s.inputStream,Charsets.UTF_8));val p=JSONObject(reader.readLine()?:throw Exception("No join packet"));val addr=s.remoteDevice.address;if(blocked.contains(addr)||p.optString("code")!=code){s.close();return};pending[addr]=s;emit(mapOf("type" to "joinRequest","requestId" to addr,"name" to p.optString("name","Member"),"address" to addr))}catch(_:Exception){try{s.close()}catch(_:Exception){}}}
 private fun handleHost(s:BluetoothSocket){try{val reader=BufferedReader(InputStreamReader(s.inputStream,Charsets.UTF_8));while(running.get()&&!s.isClosed){val line=reader.readLine()?:break;val p=JSONObject(line);relay(p,s.outputStream);emit(mapOf("type" to "packet","packet" to toMap(p)))}}catch(_:Exception){}finally{sockets.remove(s);try{s.close()}catch(_:Exception){}}}
 private fun join(address:String,pin:String,name:String,r:MethodChannel.Result){stopAll();host=false;running.set(true);executor.execute{var s:BluetoothSocket?=null;try{adapter!!.cancelDiscovery();s=adapter!!.getRemoteDevice(address).createRfcommSocketToServiceRecord(uuid);s.connect();val out=s.outputStream;val reader=BufferedReader(InputStreamReader(s.inputStream,Charsets.UTF_8));synchronized(out){out.write((JSONObject().put("type","join").put("code",pin).put("name",name).toString()+"\n").toByteArray());out.flush()};val reply=JSONObject(reader.readLine()?:throw Exception("No owner response"));if(reply.optString("type")!="accepted")throw Exception("Owner rejected request");roomId=reply.optString("roomId");sockets.add(s);outputs.add(out);state("Connected to room",true);handler.post{r.success(null)};while(running.get()&&!s.isClosed){val line=reader.readLine()?:break;emit(mapOf("type" to "packet","packet" to toMap(JSONObject(line))))}}catch(e:Exception){try{s?.close()}catch(_:Exception){};state("Disconnected",false);handler.post{r.error("CONNECT",e.message,null)}}}}
 private fun send(p:JSONObject){try{val b=(p.toString()+"\n").toByteArray(Charsets.UTF_8);if(host){relay(p,null);emit(mapOf("type" to "packet","packet" to toMap(p)))}else{val o=outputs.firstOrNull()?:throw Exception("No socket");synchronized(o){o.write(b);o.flush()}}}catch(e:Exception){emit(mapOf("type" to "error","message" to e.message))}}
 private fun relay(p:JSONObject,exclude:OutputStream?){val b=(p.toString()+"\n").toByteArray(Charsets.UTF_8);outputs.toList().forEach{o->if(o!==exclude)try{synchronized(o){o.write(b);o.flush()}}catch(_:Exception){}}}
 private fun toMap(p:JSONObject):Map<String,Any?>{val m=mutableMapOf<String,Any?>();val it=p.keys();while(it.hasNext()){val k=it.next();m[k]=p.get(k)};return m}
 private fun stopAll(){running.set(false);try{server?.close()}catch(_:Exception){};server=null;pending.values.forEach{try{it.close()}catch(_:Exception){}};pending.clear();sockets.forEach{try{it.close()}catch(_:Exception){}};sockets.clear();outputs.clear()}
 override fun onDestroy(){stopAll();try{unregisterReceiver(receiver)}catch(_:Exception){};executor.shutdownNow();super.onDestroy()}
}

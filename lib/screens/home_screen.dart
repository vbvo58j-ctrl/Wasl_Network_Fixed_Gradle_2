import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/bluetooth_service.dart';
import '../services/local_database.dart';

const supportUrl = 'https://wsend.co/967737414884';
class HomeScreen extends StatefulWidget {
 const HomeScreen({super.key});
 @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
 final bt=BluetoothService.instance, db=LocalDatabase.instance;
 final name=TextEditingController(text:'مستخدم'), roomName=TextEditingController(), code=TextEditingController(), message=TextEditingController();
 StreamSubscription? sub;
 List<Map<String,Object?>> rooms=[], messages=[];
 List<Map<String,dynamic>> devices=[];
 String? roomId, selectedAddress;
 String status='غير متصل', background='فاتح';
 bool owner=false, connected=false, scanning=false;
 @override void initState(){super.initState(); _load(); sub=bt.events.listen(_event,onError:(e)=>_snack('خطأ بلوتوث: $e'));}
 @override void dispose(){sub?.cancel();name.dispose();roomName.dispose();code.dispose();message.dispose();super.dispose();}
 Future<void> _load() async { final p=await SharedPreferences.getInstance(); name.text=p.getString('name')??'مستخدم'; background=p.getString('background')??'فاتح'; rooms=await db.rooms(); if(mounted)setState((){}); }
 String get user=>name.text.trim().isEmpty?'مستخدم':name.text.trim();
 void _snack(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 String _newCode(){const chars='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';final r=Random.secure();return List.generate(6,(_)=>chars[r.nextInt(chars.length)]).join();}
 String _id()=>DateTime.now().microsecondsSinceEpoch.toString();
 void _event(dynamic raw) async {if(!mounted||raw is! Map)return; final e=Map<String,dynamic>.from(raw);
  switch(e['type']){
   case 'device': if(!devices.any((d)=>d['address']==e['address']))setState(()=>devices.add(e)); break;
   case 'state':setState(() { status='${e['message']??''}'; connected=e['connected']==true; });break;
   case 'joinRequest': if(owner) _approveDialog(e); break;
   case 'packet': final p=Map<String,dynamic>.from(e['packet'] as Map); if(p['type']=='message'&&roomId!=null){await db.saveMessage({'room_id':roomId,'sender':'${p['senderName']??'عضو'}','body':'${p['body']??''}','created':DateTime.now().toIso8601String()}); await _loadMessages();} break;
   case 'error':_snack('${e['message']??'حدث خطأ'}');break;
  }}
 Future<void> _approveDialog(Map<String,dynamic> e) async {final id='${e['requestId']}';final accept=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('طلب انضمام'),content:Text('قبول ${e['name']??'عضو'}؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رفض')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('قبول'))])); try{await bt.approve(id,accept==true);}catch(err){_snack('$err');}}
 Future<void> _create() async {final c=TextEditingController();final n=await showDialog<String>(context:context,builder:(x)=>AlertDialog(title:const Text('إنشاء مجتمع'),content:TextField(controller:c,decoration:const InputDecoration(labelText:'اسم المجتمع')),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim()),child:const Text('إنشاء'))]));if(n==null||n.isEmpty)return;final id=_id(), pin=_newCode();try{await bt.createRoom(id,pin,user);await db.saveRoom({'id':id,'name':n,'code':pin,'owner':1,'created':DateTime.now().toIso8601String()});setState(() { roomId=id; owner=true; connected=true; status='الغرفة جاهزة'; });await _loadMessages();if(mounted)showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('رمز المجتمع'),content:SelectableText('$n\n$pin'),actions:[FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('حسنًا'))]));}catch(e){_snack('تعذر الإنشاء: $e');}}
 Future<void> _search() async {setState(() { devices=[]; scanning=true; });try{await bt.discover();}catch(e){_snack('$e');}await Future.delayed(const Duration(seconds:12));if(mounted)setState(()=>scanning=false);}
 Future<void> _join() async {if(selectedAddress==null||code.text.trim().length!=6){_snack('اختر جهازًا وأدخل الرمز المكوّن من 6 أحرف');return;}try{await bt.join(selectedAddress!,code.text.trim().toUpperCase(),user);_snack('أُرسل الطلب. انتظر موافقة المنشئ.');}catch(e){_snack('فشل الاتصال: $e');}}
 Future<void> _loadMessages() async {if(roomId==null)return;messages=await db.messages(roomId!);if(mounted)setState((){});}
 Future<void> _send() async {if(message.text.trim().isEmpty||!connected||roomId==null)return;final body=message.text.trim();try{await bt.send({'type':'message','roomId':roomId,'senderName':user,'body':body,'sentAt':DateTime.now().toIso8601String()});await db.saveMessage({'room_id':roomId,'sender':user,'body':body,'created':DateTime.now().toIso8601String()});message.clear();await _loadMessages();}catch(e){_snack('فشل الإرسال: $e');}}
 Future<void> _file() async {if(!connected){_snack('اتصل بمجتمع أولاً');return;}final f=await FilePicker.platform.pickFiles(withData:true);if(f==null||f.files.isEmpty)return;final file=f.files.single;if(file.bytes==null){_snack('تعذرت قراءة الملف');return;}if(file.bytes!.length>4*1024*1024){_snack('الحد الحالي 4 ميغابايت');return;}try{await bt.send({'type':'file','roomId':roomId,'name':file.name,'data':file.bytes,'senderName':user});_snack('تم تمرير الملف إلى خدمة البلوتوث');}catch(e){_snack('$e');}}
 Future<void> _settings() async {final p=await SharedPreferences.getInstance();if(!mounted)return;showModalBottomSheet(context:context,builder:(c)=>StatefulBuilder(builder:(c,ss)=>Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المستخدم')),const SizedBox(height:12),const Text('خلفية المحادثة'),Wrap(spacing:8,children:['فاتح','أخضر','أزرق'].map((v)=>ChoiceChip(label:Text(v),selected:background==v,onSelected:(_)async{setState(()=>background=v);ss((){});await p.setString('background',v);}).toList()),ListTile(leading:const Icon(Icons.support_agent),title:const Text('الدعم عبر واتساب'),onTap:()=>launchUrl(Uri.parse(supportUrl),mode:LaunchMode.externalApplication)),FilledButton(onPressed:()async{await p.setString('name',user);if(c.mounted)Navigator.pop(c);_snack('حُفظت الإعدادات');},child:const Text('حفظ'))]))));}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('وصل • شبكة محلية'),actions:[IconButton(onPressed:_search,icon:const Icon(Icons.search)),IconButton(onPressed:_settings,icon:const Icon(Icons.settings)),IconButton(onPressed:_create,icon:const Icon(Icons.group_add))]),floatingActionButton:FloatingActionButton.small(onPressed:()=>launchUrl(Uri.parse(supportUrl),mode:LaunchMode.externalApplication),child:const Icon(Icons.support_agent)),body:Column(children:[ListTile(leading:const Icon(Icons.bluetooth),title:Text(status),trailing:connected?IconButton(onPressed:bt.disconnect,icon:const Icon(Icons.link_off)):null),if(roomId==null)Expanded(child:ListView(padding:const EdgeInsets.all(12),children:[Card(child:ListTile(title:const Text('إنشاء مجتمع'),subtitle:const Text('رمز جديد في كل مرة'),trailing:IconButton(onPressed:_create,icon:const Icon(Icons.add)))),Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[OutlinedButton(onPressed:scanning?null:_search,child:Text(scanning?'جار البحث':'البحث عن أجهزة')), ...devices.map((d)=>RadioListTile<String>(value:'${d['address']}',groupValue:selectedAddress,onChanged:(v)=>setState(()=>selectedAddress=v),title:Text('${d['name']??'جهاز'}'),subtitle:Text('${d['address']}'))),TextField(controller:code,maxLength:6,decoration:const InputDecoration(labelText:'رمز الاقتران')),FilledButton(onPressed:_join,child:const Text('طلب الانضمام'))]))),const Text('المجتمعات المحفوظة'),...rooms.map((r)=>ListTile(title:Text('${r['name']}'),onTap:(){setState(() { roomId='${r['id']}'; owner=r['owner']==1; });_loadMessages();}))]))else Expanded(child:Column(children:[ListTile(title:Text(rooms.firstWhere((r)=>r['id']==roomId,orElse:()=>{'name':'المجتمع'})['name'].toString()),subtitle:Text(owner?'منشئ':'مشارك'),trailing:IconButton(onPressed:_file,icon:const Icon(Icons.attach_file))),Expanded(child:ListView(children:messages.map((m)=>ListTile(title:Text('${m['sender']}'),subtitle:Text('${m['body']}'))).toList())),SafeArea(child:Row(children:[Expanded(child:TextField(controller:message,decoration:const InputDecoration(hintText:'اكتب رسالة'))),IconButton(onPressed:_send,icon:const Icon(Icons.send))]))]))]));
}

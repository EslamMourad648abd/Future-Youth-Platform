import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/fyp_routes.dart';
import '../../../core/theme/brand_colors.dart';

class AdminDashboardPage extends StatefulWidget {
 const AdminDashboardPage({super.key});
 @override State<AdminDashboardPage> createState()=>_AdminDashboardPageState();
}
class _AdminDashboardPageState extends State<AdminDashboardPage> {
 bool busy=false;
 Future<void> _reviewTeacher(String id,String decision) async {
  String? reason;
  if(decision=='reject'){final c=TextEditingController(); final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Reject application'),content:TextField(controller:c,maxLines:3,decoration:const InputDecoration(labelText:'Reason (required)')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:(){reason=c.text.trim();Navigator.pop(ctx,reason!.isNotEmpty);},child:const Text('Reject'))]));if(ok!=true)return;}
  await _call('reviewTeacher',{'teacherId':id,'decision':decision,if(reason!=null)'reason':reason});
 }
 Future<void> _reviewCourse(String id,String decision) async {
  String? reason;
  if(decision=='reject'){final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Reject course'),content:TextField(controller:c,maxLines:3,decoration:const InputDecoration(labelText:'Reason (required)')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:(){reason=c.text.trim();Navigator.pop(ctx,reason!.isNotEmpty);},child:const Text('Reject'))]));if(ok!=true)return;}
  await _call('reviewCourseContent',{'courseId':id,'decision':decision,if(reason!=null)'reason':reason});
 }
 Future<void> _call(String name,Map<String,dynamic> data) async {
  setState(()=>busy=true);
  try{await FirebaseFunctions.instance.httpsCallable(name).call(data);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Review saved.')));}
  on FirebaseFunctionsException catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message??'Action failed')));}
  catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Action failed: $e')));}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  backgroundColor:const Color(0xFFF5F7FC),
  appBar:AppBar(backgroundColor:BrandColors.navy,foregroundColor:Colors.white,title:const Text('Future Youth • Admin'),
   actions:[IconButton(tooltip:'Create admin',onPressed:()=>context.push(FypRoutes.adminCreateAdmin),icon:const Icon(Icons.person_add_alt_1)),IconButton(tooltip:'Sign out',onPressed:()async{await FirebaseAuth.instance.signOut();if(context.mounted)context.go(FypRoutes.entry);},icon:const Icon(Icons.logout))]),
  body:busy?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(20),children:[
   Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(gradient:const LinearGradient(colors:[BrandColors.navy,Color(0xFF3D56A6)]),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(Icons.admin_panel_settings_outlined,color:Colors.white,size:34),SizedBox(height:12),Text('Platform control center',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)),SizedBox(height:8),Text('Review educator applications and course submissions before students can access them.',style:TextStyle(color:Colors.white70,height:1.4))])),
   const SizedBox(height:24),const _Heading('Teacher applications','Approve educators before they publish courses.'),const SizedBox(height:10),
   StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').where('role',isEqualTo:'teacher').where('approvalStatus',isEqualTo:'pending').snapshots(),builder:(context,snap){
    if(snap.hasError)return _Message('Could not load teacher applications: ${snap.error}');if(!snap.hasData)return const LinearProgressIndicator();if(snap.data!.docs.isEmpty)return const _Message('No pending teacher applications.');
    return Column(children:snap.data!.docs.map((doc){final d=doc.data();return _Card(icon:Icons.school_outlined,title:(d['displayName']??'Teacher').toString(),subtitle:(d['email']??doc.id).toString(),approve:()=>_reviewTeacher(doc.id,'approve'),reject:()=>_reviewTeacher(doc.id,'reject'));}).toList());
   }),
   const SizedBox(height:24),const _Heading('Course submissions','Review course details and lesson readiness before approval.'),const SizedBox(height:10),
   StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('courses').where('approvalStatus',isEqualTo:'pending').snapshots(),builder:(context,snap){
    if(snap.hasError)return _Message('Could not load course submissions: ${snap.error}');if(!snap.hasData)return const LinearProgressIndicator();if(snap.data!.docs.isEmpty)return const _Message('No pending course submissions.');
    return Column(children:snap.data!.docs.map((doc){final d=doc.data();return _Card(icon:Icons.play_lesson_outlined,title:(d['title']??'Untitled course').toString(),subtitle:'${d['subject']??'Subject not set'} • Teacher: ${d['teacherId']??'Unknown'}',approve:()=>_reviewCourse(doc.id,'approve'),reject:()=>_reviewCourse(doc.id,'reject'));}).toList());
   }),
   const SizedBox(height:20),OutlinedButton.icon(onPressed:()=>context.push(FypRoutes.adminCreateAdmin),icon:const Icon(Icons.admin_panel_settings_outlined),label:const Text('Create administrator')),
  ]));
}
class _Heading extends StatelessWidget{final String title,subtitle;const _Heading(this.title,this.subtitle);@override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:BrandColors.navy)),const SizedBox(height:4),Text(subtitle,style:TextStyle(color:Colors.blueGrey.shade600))]);}
class _Card extends StatelessWidget{final IconData icon;final String title,subtitle;final VoidCallback approve,reject;const _Card({required this.icon,required this.title,required this.subtitle,required this.approve,required this.reject});@override Widget build(BuildContext context)=>Card(elevation:0,margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:BorderSide(color:Colors.blueGrey.shade100)),child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[Row(children:[CircleAvatar(backgroundColor:const Color(0xFFEAF0FF),child:Icon(icon,color:BrandColors.navy)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:4),Text(subtitle,style:TextStyle(color:Colors.blueGrey.shade600))]))]),const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton(onPressed:reject,child:const Text('Reject'))),const SizedBox(width:10),Expanded(child:FilledButton(style:FilledButton.styleFrom(backgroundColor:const Color(0xFF00A651)),onPressed:approve,child:const Text('Approve'))])])));}
class _Message extends StatelessWidget{final String text;const _Message(this.text);@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Text(text));}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
class SetWallPaperDemo extends StatefulWidget {
  @override
  _SetWallPaperDemoState createState() => _SetWallPaperDemoState();
}

class _SetWallPaperDemoState extends State<SetWallPaperDemo> {
  static const platform = const MethodChannel("flutter.prism.set_wallpaper");
  static  String url = "https://cdn.pixabay.com/photo/2017/08/25/18/48/art-2681039_960_720.jpg";

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
       alignment: Alignment.center,
       decoration: BoxDecoration(
         image: DecorationImage(
           image: NetworkImage(url),
         )
       ),
       child: RaisedButton(color: Colors.white,onPressed: (){
         _setWallPaper();

       },child: Text("Set WallPaper",style: TextStyle(color: Colors.pink),),),
      ),
    );
  }

  void _setWallPaper() async{
   
    bool result;
    try{
      result = await platform.invokeMethod("set_wallpaper",<String, dynamic>{
        'url': url,
      });
      print(result);
    }catch(e){
      print(e);
    }

  }
}

import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
      home:  Scaffold(
        body:Homescreen())));
}

class Homescreen extends StatelessWidget {
  
  createAlertDialog(BuildContext context){
    TextEditingController custom =TextEditingController();
    return showDialog(context: context,builder:(context){
      return AlertDialog (
          shape: RoundedRectangleBorder(borderRadius:BorderRadius.circular(20.0)),
          title: Text('Create New Collection'),
        content: TextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(500.00)),
              borderSide: BorderSide(color: Colors.grey)),
              filled: true,
              fillColor: Colors.grey,
            focusColor: Colors.blueGrey,
              labelText: 'Collectin Name',
            ),
            controller: custom,
          ),
        actions: <Widget>[
          SizedBox(width: 75),
          FlatButton(
             color: Colors.limeAccent,
             shape: StadiumBorder(),
              child: Text('OK',style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: (){}),
              FlatButton(
                color: Colors.black12,
                      shape: StadiumBorder(),
        
            child: Text('Cancel',style: TextStyle(fontWeight: FontWeight.bold),),
            onPressed: (){

            }),
    
        ],
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    return  SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
               child: FlatButton(onPressed:(){
              createAlertDialog(context);
             },
             child: Text('alert')),
        ),
                ),
    
    );
  }
}

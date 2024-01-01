import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:socket_io_client/socket_io_client.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(
    const MaterialApp(
      title: 'Flutter Chat',
      home: ChatWidget(),
    ),
  );
}

class ChatMessage {
  final String username;
  final String message;
  final DateTime timestamp;
  final String imageLink;

  ChatMessage({required this.username, required this.message, required this.timestamp, required this.imageLink});
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({Key? key}) : super(key: key);

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  String username = "";
  String mobileNumber = "";
  String profileID = "";
  String imageLink = '';
  late Socket socket;

  List<ChatMessage> chatMessages = [];

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  void connectToServer() {
    try {
      socket = io(
        'https://115.0.9.107:3000',
        OptionBuilder().setTransports(['websocket']).enableAutoConnect().build(),
      );

      socket.on(
        'connect',
        (data) => {
          socket.emit("get_form"),
          print('Socket is connected $data'),
          openUsernameDialog(),
        },
      );

      socket.on('chat_message', (data) {
        Map<String, dynamic> messageData = json.decode(data);
        // toastMessage('Message received from server $messageData', Colors.red);
        handleChatMessage(messageData);
      });

      socket.connect();

      // Additional Socket.IO event listeners
      socket.on('history_load', (data) => print("history_load event $data"));
      socket.on('form_data', (data) => handleFormData(data));
      socket.on('notification', (data) => handleNotification(data));
      socket.on('notif_rec', (data) => print("notif_rec event $data"));
      socket.on('load_history', (data) => print("load_history event $data"));
    } catch (e) {
      print(e.toString());
    }
  }

  void handleChatMessage(Map<String, dynamic> data) {
    // Extract the message from the received data
    String messageText = data['message'];
    String messageId = '';
    if (data['message_type'] == 'image') {
      messageId = data['id'].toString();
      imageLink =
          'https://key-connect-app.khazanapk.com/wa_data/download_files/includes/get_files_content.php?project_id=1&client_id=1&profile_id=$profileID&message_id=$messageId';
    }

    // Create a new ChatMessage object
    ChatMessage newMessage = ChatMessage(username: data['sender'], message: messageText, timestamp: DateTime.now(), imageLink: imageLink);

    // Add the new message to the chatMessages list
    setState(() {
      chatMessages.add(newMessage);
    });

    // Scroll to the bottom of the ListView to show the new message
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void sendMessage(String message) {
    socket.emit("save_form",
        {"name": username, "contact_no": mobileNumber, "token": "WluI9jEKHL6lfjaRXEp4r31swmtlROna", "client_id": '1', "project_id": '1'});
    socket.emit(
      'save_message',
      {
        "temp_message_id": DateTime.now().millisecondsSinceEpoch.toString(),
        "msg": message,
        "token": "WluI9jEKHL6lfjaRXEp4r31swmtlROna",
        "client_id": '1',
        "account_id": 'WluI9jEKHL6lfjaRXEp4r31swmtlROna',
        "project_id": '1',
        "parent_document_id": "",
        "message_direction": "In"
      },
    );
    socket.on('chat_message', (data) => {print("chat_message event $data")});
    setState(() {
      // Assuming you have a ChatMessage model class
      ChatMessage newMessage = ChatMessage(username: username, message: message, timestamp: DateTime.now(), imageLink: imageLink);
      chatMessages.add(newMessage);
    });
  }

  void handleFormData(dynamic data) {
    print('Printing from here form_data event ${data.toString()}');
    print(data.toString());
  }

  void handleNotification(dynamic data) {
    Map<String, dynamic> notificationData = json.decode(data);
    print(notificationData['profile_id']);
    profileID = notificationData['profile_id'].toString();
  }

  static toastMessage(String message, Color color) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: color,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void openUsernameDialog() {
    showDialog(
      context: context,
      builder: ((context) => Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8, // Adjust the width as needed
              child: AlertDialog(
                title: const Text("Enter your details to Join Chat"),
                content: Column(
                  mainAxisSize: MainAxisSize.min, // Set to min to take only the required space
                  children: [
                    TextField(
                      onChanged: (value) => username = value,
                      decoration: const InputDecoration(hintText: "Enter your name"),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => mobileNumber = value,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: "Enter your mobile number"),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Validate the fields if needed
                      if (username.isNotEmpty && mobileNumber.isNotEmpty) {
                        Navigator.of(context).pop();
                      } else {
                        // Show an error message or handle validation as needed
                      }
                    },
                    child: const Text("Join Chat"),
                  )
                ],
              ),
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    return chatMessages[index].imageLink != ''
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              height: 80,
                              width: 80,
                              child: Center(
                                  child: Image.network(
                                chatMessages[index].imageLink,
                                errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                                  return const Text(
                                    'NoImage',
                                    style: TextStyle(fontSize: 8),
                                  );
                                },
                                fit: BoxFit.cover,
                                height: 40,
                                width: 40,
                                frameBuilder: (_, image, loadingBuilder, __) {
                                  if (loadingBuilder == null) {
                                    return const SizedBox(
                                      height: 25,
                                      width: 25,
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  return image;
                                },
                              )),
                            ),
                          )
                        : Align(
                            alignment: chatMessages[index].username == username ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: chatMessages[index].username == username ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chatMessages[index].username,
                                    style: TextStyle(
                                      color: chatMessages[index].username == username ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chatMessages[index].message,
                                    style: TextStyle(
                                      color: chatMessages[index].username == username ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${chatMessages[index].timestamp.hour}:${chatMessages[index].timestamp.minute}',
                                    style: TextStyle(
                                      color: chatMessages[index].username == username ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: TextField(
                        controller: _textController,
                        maxLines: null, // Allows multiple lines
                        minLines: 1, // Minimum lines
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: const OutlineInputBorder(),
                          hintText: 'Type a message',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.attach_file),
                                onPressed: () {
                                  // Handle attachment action
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt),
                                onPressed: () {
                                  // Handle camera action
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      String message = _textController.text;
                      if (message.isNotEmpty) {
                        sendMessage(message);
                        _textController.clear();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(16),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/models/MessageModel.dart';
import 'package:service_app/screens/chat/disscussion/disscussion_constants.dart';
import 'package:intl/intl.dart';

Widget buildDiscussionAppBar(
  BuildContext context,
  String contactName,
  bool isOnline,
  String? profileImageUrl,
) {
  final double topPadding = MediaQuery.of(context).padding.top;

  return Container(
    padding: EdgeInsets.fromLTRB(20, topPadding + 15, 20, 15),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromARGB(255, 12, 94, 153),
          Color(0xFF4A6FDC),
          Color(0xFF667EEA),
          Color(0xFF764BA2),
        ],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      boxShadow: [
        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            CupertinoIcons.back,
            color: kLightTextColor,
            size: 28,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                // Fixed CircleAvatar with profile image support
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: kLightBackgroundColor,
                    child: profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profileImageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  CupertinoIcons.person_fill,
                                  color: kPrimaryBlue,
                                  size: 20,
                                );
                              },
                            ),
                          )
                        : Icon(
                            CupertinoIcons.person_fill,
                            color: kPrimaryBlue,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactName,
                      style: const TextStyle(
                        color: kLightTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Exo2',
                      ),
                    ),
                    Text(
                      isOnline ? "Online" : "Offline",
                      style: TextStyle(
                        color: isOnline ? kOnlineStatusGreen : Colors.white70,
                        fontSize: 13,
                        fontFamily: 'Exo2',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget buildMessageBubble(MessageModel message, String currentUserId,
    [String? profileImageUrl]) {
  final bool isSent = message.senderId == currentUserId;

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    child: Row(
      mainAxisAlignment:
          isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isSent)
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColorFromName(message.senderId),
            ),
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      profileImageUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          CupertinoIcons.person_fill,
                          color: Colors.white,
                          size: 14,
                        );
                      },
                    ),
                  )
                : Icon(
                    CupertinoIcons.person_fill,
                    color: Colors.white,
                    size: 14,
                  ),
          ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: isSent ? null : Colors.white,
              gradient: isSent
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF667EEA),
                        Color(0xFF764BA2),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: isSent
                  ? null
                  : Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
              boxShadow: isSent
                  ? [
                      BoxShadow(
                        color: Color(0xFF667EEA).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isSent ? kLightTextColor : kDarkTextColor,
                    fontSize: 15,
                    fontFamily: 'Exo2',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.timestamp.toDate()),
                  style: TextStyle(
                    color: isSent
                        ? kLightTextColor.withOpacity(0.7)
                        : kMutedTextColor,
                    fontSize: 10,
                    fontFamily: 'Exo2',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isSent)
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColorFromName(currentUserId),
            ),
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      profileImageUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          CupertinoIcons.person_fill,
                          color: Colors.white,
                          size: 14,
                        );
                      },
                    ),
                  )
                : Icon(
                    CupertinoIcons.person_fill,
                    color: Colors.white,
                    size: 14,
                  ),
          ),
      ],
    ),
  );
}

// Helper function to generate consistent colors from user IDs
Color _getColorFromName(String name) {
  int hash = name.hashCode;
  return Color(hash & 0xFFFFFF).withOpacity(1.0);
}

Widget buildDateSeparator(String date) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 20),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF667EEA),
          Color(0xFF764BA2),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Color(0xFF667EEA).withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Text(
      date,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: 'Exo2',
      ),
    ),
  );
}

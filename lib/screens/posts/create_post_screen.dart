import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:service_app/screens/posts/posts_screen.dart';
import 'package:service_app/Services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:service_app/ViewModel/auth_view_model.dart';
import 'package:service_app/providers/language_provider.dart';
import 'posts_constants.dart';
import 'package:service_app/screens/posts/posts_widgets.dart';
import 'package:image_picker/image_picker.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _handleCreatePost(Post post) async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    try {
      await _firestoreService.addPost(post);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              post.type == PostType.seeking
                  ? languageProvider.tr('request_published', category: 'posts')
                  : languageProvider.tr('offer_published', category: 'posts'),
            ),
            backgroundColor: kPrimaryBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.trParams(
                'error_creating_post',
                category: 'posts',
                params: {'error': e.toString()},
              ),
            ),
            backgroundColor: kSeekingColor,
          ),
        );
      }
    }
  }

  void _showCreatePostModal() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final currentUser = authViewModel.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.tr('please_sign_in', category: 'posts'),
          ),
          backgroundColor: kSeekingColor,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CreatePostModal(
          onPostCreated: _handleCreatePost,
          user: currentUser,
          imagePicker: ImagePicker(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: kLightBackgroundColor,
      appBar: AppBar(
        title: Text(
          languageProvider.tr('service_exchange', category: 'posts'),
          style: const TextStyle(
            color: kDarkTextColor,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            fontFamily: 'Exo2',
          ),
        ),
        backgroundColor: kLightBackgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: kPrimaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(CupertinoIcons.search, color: kPrimaryBlue),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Post>>(
        stream: _firestoreService.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kPrimaryBlue),
                  const SizedBox(height: 16),
                  Text(
                    languageProvider.tr('loading_posts', category: 'posts'),
                    style: TextStyle(color: kMutedTextColor),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: kSeekingColor,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    languageProvider.tr('unable_to_load_posts',
                        category: 'posts'),
                    style: TextStyle(
                      color: kDarkTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageProvider.tr('try_again_later', category: 'posts'),
                    style: TextStyle(color: kMutedTextColor),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      languageProvider.tr('try_again', category: 'posts'),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: kPrimaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.doc_text,
                      color: kPrimaryBlue,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    languageProvider.tr('no_posts_yet', category: 'posts'),
                    style: TextStyle(
                      color: kDarkTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      languageProvider.tr('be_first_to_share',
                          category: 'posts'),
                      style: TextStyle(
                        color: kMutedTextColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _showCreatePostModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      languageProvider.tr('create_first_post',
                          category: 'posts'),
                    ),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostCard(post: posts[index]);
            },
          );
        },
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _showCreatePostModal,
          icon: const Icon(CupertinoIcons.add_circled_solid),
          label: Text(
            languageProvider.tr('create_post', category: 'posts'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

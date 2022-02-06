import 'dart:io';

import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';
import 'package:neko_launcher_neo/main.dart';
import 'package:neko_launcher_neo/src/stylesheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ActivityType { offline, online, game }

class NekoUser extends ChangeNotifier {
  String uid;
  String name;
  ActivityType activityType;
  String? activity;
  DateTime? lastActivity;
  late final RealtimeSubscription subscription;

  NekoUser(
      {required this.uid,
      required this.name,
      required this.activityType,
      required this.activity,
      required this.lastActivity}) {
    Fimber.i("Creating $name's profile. (UID: $uid)");
    subscription = supabase.client
        .from("profiles:id=eq.$uid")
        .on(SupabaseEventTypes.update, (data) {
      stdout.writeln("Updating profile $uid.");
      Fimber.i("(User: $uid) Updating profile.");
      name = data.newRecord!["username"];
      activityType =
          ActivityType.values[data.newRecord!["activity_type"] as int];
      activity = data.newRecord!["activity_details"];
      lastActivity = data.newRecord!["activity_timestamp"] != null
          ? DateTime.parse(data.newRecord!["activity_timestamp"])
          : null;
      notifyListeners();
    }).subscribe();
  }

  factory NekoUser.fromRow(Map<String, dynamic> row) {
    return NekoUser(
      uid: row["id"],
      name: row["username"],
      activityType: ActivityType.values[row["activity_type"] as int],
      activity: row["activity_details"],
      lastActivity: row["activity_timestamp"] != null
          ? DateTime.parse(row["activity_timestamp"])
          : null,
    );
  }

  void updateActivity(ActivityType type, {String? details}) {
    stdout.writeln("Updating activity");
    supabase.client
        .from("profiles:id=eq.$uid")
        .update({
          "activity_type": type.index,
          "activity_details": details,
          "activity_timestamp": DateTime.now().toIso8601String()
        })
        .execute()
        .then((_) {
          stdout.writeln("Executed update");
        });
  }

  Widget activityText() {
    switch (activityType) {
      case ActivityType.offline:
        return const Text.rich(
          TextSpan(text: "Offline"),
          style: TextStyle(color: Colors.grey),
        );
      case ActivityType.online:
        return const Text.rich(
          TextSpan(text: "Online"),
          style: TextStyle(color: Colors.blue),
        );
      case ActivityType.game:
        return Text.rich(
          TextSpan(children: [
            const TextSpan(text: "Playing "),
            TextSpan(text: activity, style: Styles.bold)
          ]),
          style: const TextStyle(color: Colors.green),
        );
    }
  }
}

class Social extends StatefulWidget {
  const Social({Key? key}) : super(key: key);

  @override
  State<Social> createState() => _SocialState();
}

class _SocialState extends State<Social> {
  bool _isLoading = true;

  void refreshState() {
    setState(() {});
  }

  Future<void> _load() async {
    await supabase.client
        .from("profiles")
        .select()
        .eq("id", supabase.client.auth.currentUser!.id)
        .execute()
        .then((response) {
      userProfile = NekoUser.fromRow(response.data[0]);
    });
  }

  @override
  void initState() {
    super.initState();
    if (userProfile == null) {
      _load().then((_) {
        if (userProfile != null) {
          setState(() {
            _isLoading = false;
            userProfile!.addListener(refreshState);
          });
        }
      });
    } else {
      _isLoading = false;
      userProfile!.addListener(refreshState);
    }
  }

  @override
  void dispose() {
    userProfile!.removeListener(refreshState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
            appBar: AppBar(
              title: Text("${userProfile!.name}'s Social"),
              actions: [
                IconButton(
                  tooltip: "Log out",
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () {
                    supabase.client.auth.signOut();
                    Navigator.pushReplacementNamed(
                      context,
                      "/",
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            // CircleAvatar(
                            //   radius: 64,
                            //   backgroundColor: Colors.transparent,
                            //   backgroundImage:
                            //       NetworkImage(userProfile!.avatar),
                            //   child: IconButton(
                            //     splashRadius: 64,
                            //     color: Colors.transparent,
                            //     tooltip: "Change avatar",
                            //     constraints: BoxConstraints(
                            //         minHeight: 128, minWidth: 128),
                            //     icon: Icon(Icons.camera_alt),
                            //     onPressed: () {
                            //       {
                            //         FilePicker.platform
                            //             .pickFiles(
                            //           type: FileType.image,
                            //         )
                            //             .then((result) {
                            //           if (result != null) {
                            //             supabase.client.storage
                            //                 .from("avatars")
                            //                 .upload(
                            //                   "${userProfile!.uid}-${result.files.single.name}",
                            //                   File(result.files.single.path!),
                            //                 )
                            //                 .then((response) {
                            //               supabase.client
                            //                   .from("profiles")
                            //                   .update({
                            //                     "avatar_url": response.data,
                            //                   })
                            //                   .eq("id", userProfile!.uid)
                            //                   .execute();
                            //             });
                            //           }
                            //         });
                            //       }
                            //     },
                            //   ),
                            // ),
                            Text(
                              userProfile!.name,
                              style: TextStyle(fontSize: 24),
                            ),
                            userProfile?.activityText() ??
                                const SizedBox.shrink(),
                            TextButton(
                                onPressed: () {
                                  supabase.client
                                      .from("profiles")
                                      .update({
                                        "username": "maak4422",
                                      })
                                      .eq("id", userProfile!.uid)
                                      .execute();
                                },
                                child: Text("Change username"))
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
  }
}

class SignIn extends StatefulWidget {
  const SignIn({Key? key}) : super(key: key);

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _signinKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();

  final _signinEmailKey = GlobalKey<FormFieldState>();
  final _signinPasswordKey = GlobalKey<FormFieldState>();

  final _signupUsernameKey = GlobalKey<FormFieldState>();
  final _signupEmailKey = GlobalKey<FormFieldState>();
  final _signupPasswordKey = GlobalKey<FormFieldState>();
  final _signupConfirmKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Sign in or sign up"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: _signinKey,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Sign in",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          key: _signinEmailKey,
                          decoration:
                              const InputDecoration(labelText: "E-mail"),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          key: _signinPasswordKey,
                          decoration:
                              const InputDecoration(labelText: "Password"),
                          obscureText: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                            child: const Text("Sign in"),
                            onPressed: () {
                              if (_signinKey.currentState!.validate()) {
                                supabase.client.auth
                                    .signIn(
                                        email:
                                            _signinEmailKey.currentState!.value,
                                        password: _signinPasswordKey
                                            .currentState!.value)
                                    .then((response) {
                                  if (supabase.client.auth.currentSession !=
                                      null) {
                                    Navigator.of(context).pop();
                                  }
                                });
                              }
                            }),
                      )
                    ],
                  ),
                ),
              )),
              const VerticalDivider(),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: _signupKey,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Create new account",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          key: _signupUsernameKey,
                          decoration:
                              const InputDecoration(labelText: "Username"),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your username";
                            }
                            if (value.length < 3) {
                              return "Username must be at least 3 characters";
                            }
                            supabase.client
                                .from("profiles")
                                .select()
                                .eq("username", value)
                                .execute()
                                .then((response) {
                              if (response.data.length > 0) {
                                return "Username already taken";
                              }
                            });
                            return null;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          key: _signupEmailKey,
                          decoration:
                              const InputDecoration(labelText: "E-mail"),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your e-mail";
                            }
                            if (!RegExp(
                                    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                                .hasMatch(value)) {
                              return "Please enter a valid e-mail";
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          key: _signupPasswordKey,
                          decoration:
                              const InputDecoration(labelText: "Password"),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your password";
                            }
                            if (value.length < 8) {
                              return "Password must be at least 8 characters";
                            }
                            if (!value.contains(RegExp(r"[0-9]"))) {
                              return "Password must contain at least one number";
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          key: _signupConfirmKey,
                          decoration: const InputDecoration(
                              labelText: "Confirm password"),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please confirm your password";
                            }
                            if (value !=
                                _signupPasswordKey.currentState!.value) {
                              return "Passwords do not match";
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                            child: const Text("Sign up"),
                            onPressed: () {
                              if (_signinKey.currentState!.validate()) {
                                supabase.client.auth
                                    .signUp(_signupEmailKey.currentState!.value,
                                        _signupPasswordKey.currentState!.value)
                                    .then((value) {
                                  if (supabase.client.auth.currentSession !=
                                      null) {
                                    supabase.client
                                        .from("profiles")
                                        .insert({
                                          "id": supabase
                                              .client.auth.currentUser!.id,
                                          "username": _signupUsernameKey
                                              .currentState!.value
                                        })
                                        .execute()
                                        .then((response) {
                                          if (response.hasError) {
                                            stdout.writeln(
                                                response.error?.message);
                                          } else {
                                            userProfile =
                                                NekoUser.fromRow(response.data);
                                            Navigator.of(context).pop();
                                          }
                                        }, onError: (error) {
                                          stdout.writeln(error);
                                        });
                                  }
                                });
                              }
                            }),
                      )
                    ],
                  ),
                ),
              ))
            ],
          ),
        ));
  }
}
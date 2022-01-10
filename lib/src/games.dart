import 'dart:ui';
import 'package:flutter/material.dart';
import "dart:convert";
import "dart:io";
import "package:intl/intl.dart";
import "package:file_picker/file_picker.dart";

import 'package:neko_launcher_neo/main.dart';
import 'package:neko_launcher_neo/src/stylesheet.dart';

class Game extends ChangeNotifier {
  late String path;
  String name = "Name missing";
  String exec = "";
  String bg = "";
  String desc = "No description.";
  int time = 0;
  List<dynamic> tags = [];
  Map<String, dynamic> activity = {};
  bool? emulate = false;
  bool favourite = false;
  bool nsfw = false;
  late ImageProvider<Object> imgProvider;

  final datePattern = DateFormat("ddMMyyyy");

  Game(this.path) {
    update();
  }

  Game.fromExe(this.exec) {
    var file = File(exec);
    path = gamesFolder.path +
        "\\" +
        (file.path.split("\\").last).split(".").first +
        ".json";
    if (File(path).existsSync()) {
      path = gamesFolder.path +
          "\\" +
          (file.path.split("\\").last).split(".").first +
          DateTime.now().millisecondsSinceEpoch.toString() +
          ".json";
    }
    File(path).createSync();
    stdout.writeln(file.parent.path);
    name = file.parent.path.split("\\").last;
    save();
    resolveImageProvider();
    listKey.currentState!.loadGames();
  }

  void resolveImageProvider() {
    if (bg.startsWith("http")) {
      imgProvider = NetworkImage(bg);
    } else {
      imgProvider = FileImage(File(bg));
    }
  }

  void updateActivity() {
    var end = DateTime.now();
    var start = end.subtract(const Duration(days: 28));
    var difference = end.difference(start);
    var days =
        List.generate(difference.inDays, (i) => start.add(Duration(days: i)));
    var oldAvtivity = activity;
    Map<String, dynamic> newActivity = {};
    for (var day in days) {
      newActivity[datePattern.format(day)] =
          oldAvtivity[datePattern.format(day)] ?? 0;
    }
    activity = newActivity;
  }

  void update() {
    var json = jsonDecode(File(path).readAsStringSync());
    name = json["name"];
    exec = json["exec"];
    bg = json["bg"];
    desc = json["desc"];
    time = json["time"];
    tags = json["tags"];
    activity = json["activity"];
    emulate = json["emulate"] ?? false;
    favourite = json["is_favourite"] ?? false;
    nsfw = json["nsfw"] ?? false;
    resolveImageProvider();
    updateActivity();
    notifyListeners();
  }

  void save() {
    var json = {
      "name": name,
      "exec": exec,
      "bg": bg,
      "desc": desc,
      "time": time,
      "tags": tags,
      "activity": activity,
      "emulate": emulate,
      "is_favourite": favourite,
      "nsfw": nsfw
    };
    File(path).writeAsStringSync(jsonEncode(json));
    update();
  }

  void folder() {
    if (exec.isEmpty) {
      return;
    }
    stdout.writeln("Opened folder");
    Process.run("explorer", [File(exec).parent.path]);
  }

  void favouriteToggle() {
    favourite = !favourite;
    save();
    stdout.writeln("Toggled favourite");
  }

  Future<void> delete(context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete $name?"),
          content: SingleChildScrollView(
            child: ListBody(
              children: const [
                Text("Are you sure you want to delete this game?"),
                Text(
                  "All recorded activity will be lost.",
                  style: Styles.bold,
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Yes", style: Styles.bold),
              onPressed: () {
                File(path).deleteSync();
                Navigator.of(context).pop();
                navigatorKey.currentState!.pushReplacementNamed("/");
                stdout.writeln("Deleted $name");
                listKey.currentState!.loadGames();
              },
            ),
            TextButton(
              child: const Text("No", style: Styles.bold),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Map<String, String> prettyTime() {
    var s = time;
    var m = s ~/ 60;
    var h = m / 60;
    var d = h / 24;

    var text = "$s seconds";
    if (m > 0 && h < 1) {
      text = m == 1 ? "$m minute" : "$m minutes";
    } else if (h >= 1 && d < 1) {
      text = h == 1
          ? "${h.toStringAsPrecision(2)} hour"
          : "${h.toStringAsPrecision(2)} hours";
    } else if (d >= 1) {
      text = d == 1
          ? "${d.toStringAsPrecision(2)} day"
          : "${d.toStringAsPrecision(2)} days";
    }

    var sentenceTime = d >= 1 ? "$h hours" : "$m minutes";

    var anecdote = "You couldn't really have done anything in that time.";

    return {
      "text": text,
      "sentence": sentenceTime,
      "anecdote": anecdote,
    };
  }
}

class GameButton extends StatefulWidget {
  final Game game;
  final void Function() onTap;

  const GameButton({
    Key? key,
    required this.game,
    required this.onTap,
  }) : super(key: key);

  @override
  _GameButtonState createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool isHovering = false;

  void refreshState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.game.addListener(refreshState);
    launcherConfig.addListener(refreshState);
  }

  @override
  void dispose() {
    widget.game.removeListener(refreshState);
    launcherConfig.removeListener(refreshState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return (launcherConfig.hideNsfw && widget.game.nsfw)
        ? const SizedBox.shrink()
        : AnimatedContainer(
            transformAlignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..translate(isHovering ? 10.0 : 0.0, 0.0, 0.0),
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.black,
              image: DecorationImage(
                filterQuality: FilterQuality.low,
                opacity: 0.33,
                image: widget.game.imgProvider,
                fit: BoxFit.cover,
              ),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: (launcherConfig.blurNsfw && widget.game.nsfw) &&
                            !isHovering
                        ? 10.0
                        : 0.0),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    onHover: (val) {
                      setState(() {
                        isHovering = val;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                            child: Icon(
                              Icons.favorite,
                              color: widget.game.favourite
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.transparent,
                            ),
                          ),
                          Flexible(
                            child: Stack(
                                alignment: AlignmentDirectional.centerStart,
                                children: [
                                  Text(
                                    widget.game.name,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: (launcherConfig.blurNsfw &&
                                                    widget.game.nsfw) &&
                                                !isHovering
                                            ? Colors.transparent
                                            : null),
                                  ),
                                  AnimatedOpacity(
                                    duration: Styles.duration,
                                    opacity: (launcherConfig.blurNsfw &&
                                                widget.game.nsfw) &&
                                            !isHovering
                                        ? 1.0
                                        : 0.0,
                                    child: const Chip(
                                        label: Text("NSFW"),
                                        backgroundColor: Colors.redAccent),
                                  ),
                                ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
  }
}

class GameDetails extends StatefulWidget {
  final Game game;

  const GameDetails({Key? key, required this.game}) : super(key: key);

  @override
  GameDetailsState createState() => GameDetailsState();
}

class GameDetailsState extends State<GameDetails> {
  bool canPlay = true;
  final _tagController = TextEditingController();
  final _tagFocus = FocusNode();

  void addTag(String tag) {
    if (widget.game.tags.contains(tag) || tag.isEmpty) {
      return;
    }
    _tagController.clear();
    widget.game.tags.add(tag);
    widget.game.save();
    _tagFocus.requestFocus();
  }

  void play() {
    var exec = widget.game.exec;
    List<String> args = [];
    if (exec.isEmpty) {
      return;
    }
    if (widget.game.emulate == true) {
      exec = launcherConfig.lePath;
      args.add(widget.game.exec);
    }
    stdout.writeln("Started playing");
    var start = DateTime.now();
    setState(() => canPlay = false);
    Process.run(exec, args, runInShell: true).then((value) {
      stdout.writeln("Finished playing");
      var end = DateTime.now();
      var diff = end.difference(start);
      widget.game.time += diff.inSeconds;
      var activityKey = widget.game.datePattern.format(start);
      stdout.writeln("Activity key: $activityKey");
      if (widget.game.activity.containsKey(activityKey)) {
        widget.game.activity[activityKey] += diff.inSeconds;
      } else {
        widget.game.activity[activityKey] = diff.inSeconds;
      }
      setState(() {
        canPlay = true;
        widget.game.save();
      });
    });
  }

  void refreshState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.game.addListener(refreshState);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocus.dispose();
    widget.game.removeListener(refreshState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var time = widget.game.prettyTime();
    return Stack(
      children: [
        Container(
            decoration: BoxDecoration(
                image: DecorationImage(
          image: widget.game.imgProvider,
          fit: BoxFit.cover,
        ))),
        Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.99),
            ],
          )),
        ),
        Scaffold(
            floatingActionButton: FloatingActionButton(
              child: Icon(widget.game.favourite
                  ? Icons.favorite
                  : Icons.favorite_border),
              onPressed: () => {
                setState(() => {widget.game.favouriteToggle()}),
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  width: 600,
                  duration: const Duration(seconds: 2),
                  content: Text(
                    !widget.game.favourite
                        ? "Removed ${widget.game.name} from favourites."
                        : "Added ${widget.game.name} to favourites",
                  ),
                  action: SnackBarAction(
                      label: "Undo",
                      onPressed: () => {
                            setState(() => {widget.game.favouriteToggle()})
                          }),
                ))
              },
              tooltip: widget.game.favourite
                  ? "Remove from favourites"
                  : "Add to favourites",
            ),
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              title: Row(
                children: [
                  Text(
                    widget.game.name,
                    style: const TextStyle(fontSize: 36),
                  ),
                  if (widget.game.nsfw)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Chip(
                        label: Text("NSFW"),
                        backgroundColor: Colors.redAccent,
                      ),
                    ),
                ],
              ),
              actions: [
                ButtonBar(
                  children: [
                    Row(
                      children: [
                        if (launcherConfig.lePath == "" &&
                            widget.game.emulate == true)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Tooltip(
                              child: Icon(
                                Icons.error,
                                color: Theme.of(context).errorColor,
                              ),
                              message:
                                  "Set LocaleEmulator path in the Launcher's settings to play.",
                            ),
                          ),
                        ElevatedButton(
                            child: Row(
                              children: widget.game.emulate == true
                                  ? ([
                                      const Icon(Icons.language),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      const Text(
                                        "スタート",
                                        style: Styles.bold,
                                      ),
                                    ])
                                  : ([
                                      const Text(
                                        "PLAY",
                                        style: Styles.bold,
                                      ),
                                    ]),
                            ),
                            onPressed: canPlay &&
                                    (launcherConfig.lePath != "" ||
                                        widget.game.emulate == false)
                                ? play
                                : null),
                      ],
                    ),
                    OutlinedButton(
                        child: const Text(
                          "FOLDER",
                          style: Styles.bold,
                        ),
                        onPressed: widget.game.folder),
                    OutlinedButton(
                        child: const Text(
                          "CONFIG",
                          style: Styles.bold,
                        ),
                        onPressed: () => navigatorKey.currentState!
                            .pushNamed("/config", arguments: widget.game)),
                  ],
                ),
              ],
            ),
            body: ListView(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                          child: NekoCard(
                              title: time["text"],
                              body: RichText(
                                  text: TextSpan(children: [
                                const TextSpan(text: "You have played "),
                                TextSpan(
                                    text: widget.game.name, style: Styles.bold),
                                const TextSpan(text: " for "),
                                TextSpan(
                                    text: time["sentence"], style: Styles.bold),
                                const TextSpan(text: ".\n"),
                                TextSpan(text: time["anecdote"]),
                              ])))),
                      Expanded(
                        child: NekoCard(
                          title: "Tags",
                          body: Wrap(
                            children: widget.game.tags.map((tag) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Chip(
                                  onDeleted: () {
                                    widget.game.tags.remove(tag);
                                    widget.game.save();
                                  },
                                  label: Text(tag),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                              );
                            }).toList(),
                          ),
                          actions: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  focusNode: _tagFocus,
                                  controller: _tagController,
                                  decoration: const InputDecoration(
                                    labelText: "Add tag",
                                    hintText: "Tag",
                                  ),
                                  onSubmitted: addTag,
                                ),
                              ),
                              IconButton(
                                splashRadius: Styles.splash,
                                icon: const Icon(Icons.add),
                                onPressed: () =>
                                    addTag(_tagController.value.text),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                        child: NekoCard(
                      title: "Activity",
                      body: Text(widget.game.desc),
                    ))
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: NekoCard(
                      title: "Description",
                      body: Text(widget.game.desc),
                    ))
                  ],
                )
              ],
            )),
      ],
    );
  }
}

class GameConfig extends StatefulWidget {
  final Game game;

  const GameConfig({Key? key, required this.game}) : super(key: key);

  @override
  GameConfigState createState() => GameConfigState();
}

class GameConfigState extends State<GameConfig> {
  final _formKey = GlobalKey<FormState>();
  final _execKey = GlobalKey<FormFieldState>();
  final _bgKey = GlobalKey<FormFieldState>();
  bool pendingChanges = false;

  void highlightSave() {
    setState(() {
      pendingChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text("Editing " + widget.game.name),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                tooltip: "Open JSON in text editor",
                splashRadius: Styles.splash,
                icon: const Icon(Icons.edit),
                onPressed: () => {
                  Process.run("start", ['"edit"', widget.game.path],
                      runInShell: true)
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                tooltip: "Save changes",
                splashRadius: Styles.splash,
                icon: const Icon(
                  Icons.save,
                ),
                onPressed: !pendingChanges
                    ? null
                    : () => {
                          _formKey.currentState!.save(),
                          widget.game.save(),
                          Navigator.pop(context),
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            width: 600,
                            duration: const Duration(seconds: 2),
                            content: Text(
                              "Saved ${widget.game.name}",
                            ),
                          ))
                        },
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
              onChanged: highlightSave,
              key: _formKey,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    onSaved: (newValue) =>
                        widget.game.name = newValue ?? widget.game.name,
                    initialValue: widget.game.name,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Title",
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    key: _execKey,
                    onSaved: (newValue) =>
                        widget.game.exec = newValue ?? widget.game.exec,
                    initialValue: widget.game.exec,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "Executable path",
                        suffixIcon: NekoPathSuffix(
                          fieldKey: _execKey,
                          type: FileType.custom,
                          extensions: const ["exe"],
                        )),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    key: _bgKey,
                    onSaved: (newValue) =>
                        widget.game.bg = newValue ?? widget.game.bg,
                    initialValue: widget.game.bg,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: "Background image path",
                        suffixIcon: NekoPathSuffix(
                          fieldKey: _bgKey,
                          type: FileType.image,
                        )),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      textAlignVertical: TextAlignVertical.top,
                      expands: true,
                      maxLines: null,
                      onSaved: (newValue) =>
                          widget.game.desc = newValue ?? widget.game.desc,
                      initialValue: widget.game.desc,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Description",
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            FormField(
                              initialValue: widget.game.emulate,
                              onSaved: (bool? newValue) => widget.game.emulate =
                                  newValue ?? widget.game.emulate,
                              builder: (FormFieldState<bool> field) {
                                return Row(
                                  children: [
                                    const Text("Emulate Locale"),
                                    Switch(
                                      value: field.value ?? false,
                                      onChanged: (bool value) =>
                                          field.didChange(value),
                                    ),
                                    if (field.hasError)
                                      Text(field.errorText ?? "",
                                          style: TextStyle(
                                              color:
                                                  Theme.of(context).errorColor))
                                  ],
                                );
                              },
                              autovalidateMode: AutovalidateMode.always,
                              validator: (value) {
                                if (value == true &&
                                    launcherConfig.lePath == "") {
                                  return "Set LocaleEmulator path in the Launcher's settings!";
                                }
                                return null;
                              },
                            ),
                            const VerticalDivider(),
                            FormField(
                              initialValue: widget.game.nsfw,
                              onSaved: (bool? newValue) => widget.game.nsfw =
                                  newValue ?? widget.game.nsfw,
                              builder: (FormFieldState<bool> field) {
                                return Row(
                                  children: [
                                    const Text("NSFW"),
                                    Switch(
                                      value: field.value ?? false,
                                      onChanged: (bool value) =>
                                          field.didChange(value),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ButtonStyle(backgroundColor:
                            MaterialStateColor.resolveWith((states) {
                          return states.contains(MaterialState.disabled)
                              ? Colors.grey.shade600.withOpacity(0.5)
                              : Colors.redAccent;
                        })),
                        child: const Text("DELETE", style: Styles.bold),
                        onPressed: () {
                          widget.game.delete(context);
                        },
                      ),
                    ],
                  ),
                )
              ])),
        ));
  }
}

class GameList extends StatefulWidget {
  const GameList({Key? key}) : super(key: key);

  @override
  GameListState createState() => GameListState();
}

enum Sorting {
  nameAsc,
  nameDesc,
  timeAsc,
  timeDesc,
}

enum Filtering { all, favourite, neverPlayed }

class GameListState extends State<GameList> {
  List<Game> games = [];
  Sorting sorting = Sorting.nameAsc;
  final _sortingKey = GlobalKey<PopupMenuButtonState>();

  void sort() {
    switch (sorting) {
      case Sorting.nameAsc:
        games.sort((a, b) => a.name.compareTo(b.name));
        break;
      case Sorting.nameDesc:
        games.sort((a, b) => b.name.compareTo(a.name));
        break;
      case Sorting.timeAsc:
        games.sort((a, b) => a.time.compareTo(b.time));
        break;
      case Sorting.timeDesc:
        games.sort((a, b) => b.time.compareTo(a.time));
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    loadGames();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void loadGames() {
    setState(() {
      games = [];
      gamesFolder.listSync().forEach((f) {
        if (f is File) {
          games.add(Game(f.path));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                  tooltip: "View homescreen",
                  splashRadius: Styles.splash,
                  padding: const EdgeInsets.all(1),
                  icon: const Icon(Icons.home),
                  onPressed: () {
                    navigatorKey.currentState!.pushReplacementNamed(
                      "/",
                    );
                  }),
              const Expanded(
                child: Center(
                  child: Text(
                    "Games",
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                child: PopupMenuButton(
                    key: _sortingKey,
                    tooltip: "Change sorting",
                    child: IconButton(
                      hoverColor: Theme.of(context).hoverColor,
                      splashColor: Theme.of(context).splashColor,
                      splashRadius: Styles.splash,
                      icon: const Icon(Icons.filter_list),
                      onPressed: () =>
                          _sortingKey.currentState!.showButtonMenu(),
                    ),
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<Sorting>>[
                          const PopupMenuItem<Sorting>(
                            value: Sorting.nameAsc,
                            child: Text("Name (A-Z)"),
                          ),
                          const PopupMenuItem<Sorting>(
                            value: Sorting.nameDesc,
                            child: Text("Name (Z-A)"),
                          ),
                          const PopupMenuItem<Sorting>(
                            value: Sorting.timeDesc,
                            child: Text("Most played"),
                          ),
                          const PopupMenuItem<Sorting>(
                            value: Sorting.timeAsc,
                            child: Text("Least played"),
                          ),
                        ],
                    onSelected: (Sorting s) {
                      setState(() {
                        sorting = s;
                      });
                    }),
              ),
            ],
          ),
        ),
        games.isNotEmpty
            ? Expanded(
                child: ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    return GameButton(
                      game: games[index],
                      onTap: () {
                        games[index].update();
                        if (navigatorKey.currentState!.canPop()) {
                          navigatorKey.currentState!.pop();
                        }
                        navigatorKey.currentState!.pushReplacementNamed(
                          "/game",
                          arguments: games[index],
                        );
                      },
                    );
                  },
                ),
              )
            : Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text("It's empty here... ",
                            style: TextStyle(
                                fontSize: 24,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onBackground)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [Icon(Icons.arrow_forward, size: 40)],
                      ),
                    )
                  ],
                ),
              )
      ],
    );
  }
}

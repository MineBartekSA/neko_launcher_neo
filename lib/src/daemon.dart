import 'dart:io';

import 'package:fimber_io/fimber_io.dart';
import 'package:flutter/material.dart';

import 'package:neko_launcher_neo/main.dart';
import 'package:neko_launcher_neo/src/games.dart';

class GameDaemon extends ChangeNotifier {
  void play(Game game) async {
    var exec = game.exec;
    if (game.launchExec != null) {
      exec = game.launchExec!;
    }

    List<String> args = [];
    Map<String, String> env = {};
    if (exec.isEmpty) {
      return;
    }

    if (Platform.isLinux) {
      if (game.emulate) {
        env.addAll({"LANG": "ja_JP.UTF-8"});
      }
      if (game.exec.endsWith(".exe")) {
        exec = "wine";
        args.add(game.exec);
      }

      // Only set activity on Linux
      game.started();
    } else {
      if (game.emulate) {
        exec = launcherConfig.lePath;
        args.add(game.exec);
      }
    }

    final process = Process.run(exec, args, environment: env, runInShell: Platform.isLinux ? false : game.emulate ? false : true);

    if (Platform.isLinux) {
      process.then((value) {
        game.stopped();
      });
    }
  }
}

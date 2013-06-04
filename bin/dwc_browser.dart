// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Compiles Dart Web Components from within a Chrome extension.
 * The Chrome extension logic exists outside of Dart as Dart does not support
 * Chrome extension APIs at this time.
 */
library dwc_browser;

import 'dart:html';
import 'package:web_ui/src/compiler.dart';
import 'package:web_ui/src/file_system.dart' as fs;
import 'package:web_ui/src/file_system/browser.dart';
import 'package:web_ui/src/messages.dart';
import 'package:web_ui/src/options.dart';
import 'package:web_ui/src/utils.dart';
import 'package:js/js.dart' as js;

fs.FileSystem fileSystem;

void main() {
  js.scoped(() {
    js.context.setOnParseCallback(new js.Callback.many(parse));
  });
}

/**
 * Process the input file at [sourceUri] with the 'dwc' compiler.
 * [sourcePagePort] is a Chrome extension port used to communicate back to the
 * source page that will consume these proxied urls.
 * See extension/background.js.
 */
void parse(js.Proxy sourcePagePort, String sourceUri) {
  // TODO(jacobr): we need to send error messages back to sourcePagePort.
  js.retain(sourcePagePort);
  print("Processing: $sourceUri");
  Uri uri = Uri.parse(sourceUri);
  fileSystem = new BrowserFileSystem(uri.scheme, sourcePagePort);
  // TODO(jacobr): provide a way to pass in options.
  var options = CompilerOptions.parse(['--no-colors', uri.path]);
  var messages = new Messages(options: options, shouldPrint: false);
  asyncTime('Compiled $sourceUri', () {
    var compiler = new Compiler(fileSystem, options, messages);
    return compiler.run().then((_) {
      for (var file in compiler.output) {
        fileSystem.writeString(file.path, file.contents);
      }
      var ret = fileSystem.flush();
      js.scoped(() {
        js.context.proxyMessages(sourcePagePort,
            js.array(messages.messages.map(
                (m) => [m.level.name, m.toString()]).toList()));
      });
      js.release(sourcePagePort);
      return ret;
    });
  }, printTime: true);
}

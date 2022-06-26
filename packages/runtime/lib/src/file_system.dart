import 'dart:convert';
import 'dart:io';

/// Recursively copies the contents of the directory at [src] to [dst].
///
/// Creates directory at [dst] recursively if it doesn't exist.
void copyDirectory({required Uri src, required Uri dst}) {
  final srcDir = Directory.fromUri(src);
  final dstDir = Directory.fromUri(dst);
  if (!dstDir.existsSync()) {
    dstDir.createSync(recursive: true);
  }

  srcDir.listSync().forEach((fse) {
    if (fse is File) {
      final outPath = dstDir.uri
          .resolve(fse.uri.pathSegments.last)
          .toFilePath(windows: Platform.isWindows);
      fse.copySync(outPath);
    } else if (fse is Directory) {
      final segments = fse.uri.pathSegments;
      final outPath = dstDir.uri.resolve(segments[segments.length - 2]);
      copyDirectory(src: fse.uri, dst: outPath);
    }
  });
}

/// Reads .dart_tool/package_config.json file from [packagesFileUri] and returns map of package name to its location on disk.
///
/// If locations on disk are relative Uris, they are resolved by [relativeTo]. [relativeTo] defaults
/// to the CWD.
Map<String, Uri> getResolvedPackageUris(
  Uri packagesFileUri, {
  Uri? relativeTo,
}) {
  final _relativeTo = relativeTo ?? Directory.current.uri;
  final packagesFile = File.fromUri(packagesFileUri);
  if (!packagesFile.existsSync()) {
    throw StateError(
      "No .dart_tool/package_config.json file found at '$packagesFileUri'. "
      "Run 'pub get' in directory '${packagesFileUri.resolve('../')}'.",
    );
  }

  String input = packagesFile.readAsStringSync();
  List packages = jsonDecode(input)['packages'];
  return Map.fromEntries(packages.map((p) {
    String rootUri = p['rootUri'];
    Uri uri = Uri.parse(rootUri);
    final packageName = p['name'];
    if (uri.isAbsolute) {
      return MapEntry(packageName,
          Directory.fromUri(uri.resolve(p['packageUri'])).parent.uri);
    }

    uri = Uri.parse(rootUri);
    String catPath = '${_relativeTo.resolveUri(uri).toFilePath()}';
    if (catPath.endsWith('/')) {
      catPath = catPath.substring(0, catPath.length - 1);
    }
    catPath = '$catPath/${p['packageUri']}';
    return MapEntry(packageName, Uri.parse(catPath).normalizePath());
  }));
}

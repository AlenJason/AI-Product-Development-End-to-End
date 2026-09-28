import 'dart:io';

void main() {
  var file = File('lib/widgets/app_widgets.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll(RegExp(r'(children:\s*options\.map\(\(option\)\s*\{\s*.*?return ChoiceChip\(.*?\);\s*\}\))(\s*,)', dotAll: true), r'\1.toList()\2');
  
  content = content.replaceAll(RegExp(r'(children:\s*ingredients\s*\.map\(\(item\)\s*=>\s*Container\(.*?\)\))(\s*,)', dotAll: true), r'\1.toList()\2');
  
  content = content.replaceAll(RegExp(r'(children:\s*tags\s*\.map\(\(tag\)\s*=>\s*Container\(.*?\)\))(\s*,)', dotAll: true), r'\1.toList()\2');
  
  file.writeAsStringSync(content);
}

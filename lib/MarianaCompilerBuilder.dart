import 'package:build/build.dart';
import 'package:mariana_flutter_compiler/src/MarianaCompiler.dart';
import 'package:source_gen/source_gen.dart';

Builder starterBuilder(BuilderOptions options) => SharedPartBuilder([MarianaCompiler()], "starter");
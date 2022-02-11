import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:mariana_flutter/annotation/FeignAnnotation.dart';
import 'package:mariana_flutter/annotation/MarianaAnnotation.dart';
import 'package:source_gen/source_gen.dart';

class MarianaCompiler extends GeneratorForAnnotation<MarianaApplication> {
  @override
  generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    @override
    String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
      if (element is! ClassElement) {
        final name = element.displayName;
        throw InvalidGenerationSourceError(
          'Generator cannot target `$name`.',
          todo: 'Remove the [MarianaCompiler] annotation from `$name`.',
        );
      }
      return _implementClass(element, annotation);
    }
  }

  String _implementClass(ClassElement element, ConstantReader annotation) {
    String mainMethodSource = _createMainMethodSource(element);
    String applicationSource = _createApplicationSource(element);
    return DartFormatter().format('$mainMethodSource $applicationSource');
  }

  String _createMainMethodSource(ClassElement element) {
    MethodElement? initializeMethod;
    MethodElement? sessionMethod;
    var initializeType = TypeChecker.fromRuntime(Initialize);
    var sessionType = TypeChecker.fromRuntime(Session);
    for (MethodElement method in element.methods) {
      if (initializeType.hasAnnotationOf(method, throwOnUnresolved: false)) {
        initializeMethod = method;
      } else if (sessionType.hasAnnotationOf(method, throwOnUnresolved: false)) {
        sessionMethod = method;
      }
      if (initializeMethod != null && sessionMethod != null) {
        break;
      }
    }
    if (initializeMethod == null) {
      throw InvalidGenerationSourceError(
        'Generator cannot target `${element.name}`.',
        todo: 'Remove the [MarianaApplication] annotation from `${element.name}`.',
      );
    }

    String runApplicationMethod = "void runApplication(application) ${initializeMethod.returnType.isDartAsyncFuture ? "async" : ""} {"
        "WidgetsFlutterBinding.ensureInitialized();"
        "var routes = ${initializeMethod.returnType.isDartAsyncFuture ? "await" : ""} application.${initializeMethod.displayName}();"
        "FlutterApplication.run(routes, application.getInitializeCallbackList(), ${sessionMethod == null ? null : "application.${sessionMethod.displayName}()"});"
        "}";

    String mainMethod = "void main() {"
        "var application = ${element.name}Impl();"
        "runApplication(application);"
        "if (Platform.isAndroid) {"
        "SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent));"
        "}"
        "}";

    return "$runApplicationMethod $mainMethod";
  }

  String _createApplicationSource(ClassElement element) {
    StringBuffer result = StringBuffer();
    var configType = TypeChecker.fromRuntime(Config);
    for (MethodElement method in element.methods) {
      var dartObject = configType.firstAnnotationOf(method, throwOnUnresolved: false);
      if (dartObject != null) {
        String? name = ConstantReader(dartObject).peek("configurationName")?.stringValue;
        result.write("\"$name\": ${method.displayName},");
      }
    }
    String auto = _createFeignSource(element);
    return "class ${element.name}Impl with ${element.name} {"
        "Map<String?, InitializeCallback> getInitializeCallbackList() {"
        "return {$result};"
        "}"
        "$auto"
        "}";
  }

  String _createFeignSource(ClassElement element) {
    StringBuffer result = StringBuffer();
    Map<TypeChecker, MethodElement> methods = {};
    var feignAutoType = TypeChecker.fromRuntime(EnableFeign);
    if (feignAutoType.hasAnnotationOf(element, throwOnUnresolved: false)) {
      var feignType = TypeChecker.fromRuntime(Feign);
      var feignLoadingType = TypeChecker.fromRuntime(FeignLoading);
      var feignErrorType = TypeChecker.fromRuntime(FeignError);
      var feignDismissType = TypeChecker.fromRuntime(FeignDismiss);
      var feignCallType = TypeChecker.fromRuntime(FeignCall);
      var feignLogoutType = TypeChecker.fromRuntime(FeignLogout);
      for (MethodElement method in element.methods) {
        if (feignType.hasAnnotationOf(method, throwOnUnresolved: false)) {
          methods[feignType] = method;
        } else if (feignLoadingType.hasAnnotationOf(method, throwOnUnresolved: false)) {
          methods[feignLoadingType] = method;
        } else if (feignErrorType.hasAnnotationOf(method, throwOnUnresolved: false)) {
          methods[feignErrorType] = method;
        } else if (feignDismissType.hasAnnotationOf(method, throwOnUnresolved: false)) {
          methods[feignDismissType] = method;
        } else if (feignCallType.hasAnnotationOf(method, throwOnUnresolved: false)) {
          methods[feignCallType] = method;
        } else if (feignLogoutType.hasAnnotationOf(method, throwOnUnresolved: false)) {
          methods[feignLogoutType] = method;
        }
      }
      StringBuffer _statement = StringBuffer();
      if (methods[feignCallType] != null) {
        _statement.write("FeignConfig.setDataCallback(${methods[feignCallType]!.displayName});");
        if (methods[feignErrorType]!.isAbstract) {
          result.write(
              "void ${methods[feignCallType]!.displayName}(handler, value) {"
                  "if(value.success) {"
                  "try {"
                  "handler.call(value.data);"
                  "} catch (e) {"
                  "handler.call();"
                  "}"
                  "} else {"
                  "switch (value.status) {"
                  "case 20001:"
                  "case 401: {"
                  "${methods[feignLogoutType]!.displayName}();"
                  "}"
                  "}"
                  "TipUtil.showToast(value.message);"
                  "}"
                  "}");
        }
      }
      if (methods[feignErrorType] != null) {
        _statement.write("FeignConfig.setErrorCallback(${methods[feignErrorType]!.displayName});");
        if (methods[feignErrorType]!.isAbstract) {
          result.write("void ${methods[feignErrorType]!.displayName}(error) {"
              "String message;"
              "if (error.error is HttpException || error.error is SocketException) {"
              "message = \"网络连接异常,请检查网络....\";"
              "} else {"
              "message = \"服务器异常,请稍候...\";"
              "}"
              "TipUtil.showToast(message);"
              "}");
        }
      }
      if (methods[feignLoadingType] != null && methods[feignDismissType] != null) {
        _statement.write("FeignConfig.setPreparedCallback(${methods[feignLoadingType]!.displayName});");
        _statement.write("FeignConfig.setFinishCallback(${methods[feignDismissType]!.displayName});");
      }
      result.write("void ${methods[feignType]!.displayName}(config) {"
          "FeignConfig.init(config);"
          "$_statement"
          "}");
      return result.toString();
    }
    return "";
  }
}
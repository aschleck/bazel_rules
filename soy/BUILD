package(default_visibility = ["//visibility:public"])

java_binary(
    name = "SoyParseInfoGenerator",
    main_class = "com.google.template.soy.SoyParseInfoGenerator",
    runtime_deps = [":soy_jar"],
)

java_binary(
    name = "SoyHeaderCompiler",
    main_class = "com.google.template.soy.SoyHeaderCompiler",
    runtime_deps = [":soy_jar"],
)

java_binary(
    name = "SoyToJbcSrcCompiler",
    main_class = "com.google.template.soy.SoyToJbcSrcCompiler",
    runtime_deps = [":soy_jar"],
)

java_binary(
    name = "SoyToJsSrcCompiler",
    main_class = "com.google.template.soy.SoyToJsSrcCompiler",
    runtime_deps = [":soy_jar"],
)

java_binary(
    name = "SoyToPySrcCompiler",
    main_class = "com.google.template.soy.SoyToPySrcCompiler",
    runtime_deps = [":soy_jar"],
)

java_import(
    name = "soy_jar",
    jars = ["soy-2021-02-01-with-dependencies.jar"],
    visibility = ["//visibility:private"],
)


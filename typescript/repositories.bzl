load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:java.bzl", "java_import_external")

def ts_repositories():
  http_archive(
      name = "io_bazel_rules_closure",
      sha256 = "d66deed38a0bb20581c15664f0ab62270af5940786855c7adc3087b27168b529",
      strip_prefix = "rules_closure-0.11.0",
      urls = [
          "https://mirror.bazel.build/github.com/bazelbuild/rules_closure/archive/0.11.0.tar.gz",
          "https://github.com/bazelbuild/rules_closure/archive/0.11.0.tar.gz",
      ],
  )

  java_import_external(
      name = "com_google_template_soy",
      licenses = ["notice"],  # Apache 2.0
      jar_urls = [
          "https://repo1.maven.org/maven2/com/google/template/soy/2021-02-01/soy-2021-02-01.jar",
      ],
      jar_sha256 = "60c59b9f5d3074b5b72b18f00efd4c96d10deb0693a16f40ce538657c51f63a4",
      deps = [
          "@args4j",
          "@com_google_code_findbugs_jsr305",
          "@com_google_code_gson",
          "@com_google_common_html_types",
          "@com_google_guava",
          "@com_google_inject_extensions_guice_assistedinject",
          "@com_google_inject_extensions_guice_multibindings",
          "@com_google_inject_guice",
          "@com_google_protobuf//:protobuf_java",
          "@com_ibm_icu_icu4j",
          "@javax_inject",
          "@org_json",
          "@org_ow2_asm",
          "@org_ow2_asm_analysis",
          "@org_ow2_asm_commons",
          "@org_ow2_asm_util",
      ],
      extra_build_file_content = "\n".join([
          ("java_binary(\n" +
           "    name = \"%s\",\n" +
           "    main_class = \"com.google.template.soy.%s\",\n" +
           "    output_licenses = [\"unencumbered\"],\n" +
           "    runtime_deps = [\":com_google_template_soy\"],\n" +
           ")\n") % (name, name)
          for name in (
              "SoyParseInfoGenerator",
              "SoyHeaderCompiler",
              "SoyToJbcSrcCompiler",
              "SoyToJsSrcCompiler",
              "SoyToPySrcCompiler",
          )
      ]),
  )

load("@io_bazel_rules_closure//closure:repositories.bzl", "rules_closure_dependencies", "rules_closure_toolchains")

def repositories_deps():
  rules_closure_dependencies(omit_com_google_template_soy=True)
  rules_closure_toolchains()


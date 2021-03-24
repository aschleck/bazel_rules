def ts_binary(
    name,
    deps,
    base_modules=None):
  src_names_file = name + "__srcs"
  _gen_file_list_arg_as_file(
      out_name = src_names_file,
      targets = deps + [str(Label("//typescript:system.d.ts"))])

  js_deps = _add_suffix(deps, "_js_deps")
  js_src_names_file = name + "__js_srcs"
  _gen_file_list_arg_as_file(
      out_name = js_src_names_file,
      targets = js_deps)

  compile_file = name + ".c.js"
  relative_root = "../" * native.package_name().count("/")
  ts_config = str(Label("//typescript:tsconfig.json.in"))
  soy_js = str(Label("//typescript:soy.min.js"))
  soy_support_js = str(Label("//typescript:soy_support.js"))
  native.genrule(
      name = name + "_compile",
      srcs = deps + [
          src_names_file,
          soy_js,
          soy_support_js,
          ts_config,
      ],
      outs = [compile_file],
      cmd = "\n".join([
          "list=\"$$(sed -E \"s/ /\\\", \\\"/g;s/(.*)/\\\"\\1\\\"/\" $(location " + src_names_file + "))\"",
          "sed \"s|__FILES__|$$list|\" $(location %s) > tsconfig.json" % ts_config,
          "tsc --outFile $(location %s) --strict" % compile_file,
          "cat $(location %s) >> out.js" % soy_js,
          "cat $(location %s) >> out.js" % soy_support_js,
          "cat $(location %s) >> out.js" % compile_file,
          "mv out.js $(location %s)" % compile_file,
      ]),
      visibility = ["//visibility:private"],
  )

  support_file = "support.js"
  native.genrule(
      name = name + "_copy_support",
      srcs = [
          str(Label("//typescript:system.min.js")),
          str(Label("//typescript:named-register.js")),
      ],
      outs = [support_file],
      cmd = "cat $(SRCS) > $@",
      visibility = ["//visibility:private"],
  )

  loader_file = "loader.js"
  raw_js = "\n".join([
          "",
          "document.addEventListener('DOMContentLoaded', () => {",
      ] + ["System.import('%s');" % m for m in base_modules or []] + [
          "});"
      ])
  native.genrule(
      name = name + "_loader",
      srcs = [js_src_names_file] + js_deps,
      outs = [loader_file],
      cmd = "echo \"%s\" > $@ ;" % raw_js
          + " for f in $$(cat $(location " + js_src_names_file + "));"
          + " do"
          + "   basic=\"$$(echo $${f%%.*} | sed \"s|bazel-out/k8-fastbuild/bin/||\")\";"
          + "   echo \"System.register('$$basic', [], function(exports) {\" >> $@ ;"
          + "   echo \"  return {'execute': function() {\" >> $@ ;"
          + "   echo \"    const _this = {};\" >> $@ ;"
          + "   echo \"    (function() {\" >> $@ ;"
          + "   cat $$f >> $@ ;"
          + "   echo \"    }).call(_this);\" >> $@ ;"
          + "   echo \"    Object.entries(_this).forEach(e => \" >> $@ ;"
          + "   echo \"        exports(e[0], e[1]));\" >> $@ ;"
          + "   echo \"  }}});\" >> $@ ;"
          + " done",
      visibility = ["//visibility:private"],
  )

  native.genrule(
      name = name + "_merge",
      srcs = [
          support_file,
          compile_file,
          loader_file,
      ],
      outs = [name + ".js"],
      cmd = "\n".join([
          "cat $(location :%s) >> $@" % support_file,
          "cat $(location :%s) >> $@" % compile_file,
          "cat $(location :%s) >> $@" % loader_file,
      ]),
      visibility = ["//visibility:private"],
  )

  native.filegroup(
      name = name,
      srcs = [
          name + ".js",
      ],
  )

def ts_library(
    name,
    srcs,
    js_srcs = None,
    deps = None,
    **kwargs):
  native.filegroup(
      name = name,
      srcs = srcs + (deps or []),
      **kwargs
  )

  native.filegroup(
      name = name + "_js_deps",
      srcs = (js_srcs or []) + _add_suffix(deps or [], "_js_deps"),
      **kwargs
  )

def _gen_file_list_arg_as_file(
    out_name,
    targets,
    compatible_with = None):
  filtered = []
  for f in targets:
    if not f.endswith('.d.ts'):
      filtered.append(f)

  native.genrule(
      name = out_name + "_gen",
      srcs = filtered,
      outs = [out_name],
      cmd = "if [ -n \"$(SRCS)\" ] ; "
          + "then "
          + "  echo -n $$(echo \"$(SRCS)\") > $@ ; "
          + "fi ; "
          + "touch $@",  # touch the file, in case empty
      compatible_with = compatible_with,
      visibility = ["//visibility:private"],
  )

def _add_suffix(targets, suffix):
  transformed = []
  for t in targets:
    if t.find(":") >= 0:
      base = t
    else:
      base = t + ":" + t.rsplit("/")[-1]
    transformed.append(base + suffix)
  return transformed


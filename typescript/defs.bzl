TsLibraryInfo = provider(fields = ["js", "ts"])

def _ts_binary_impl(ctx):
    all_js = []
    all_ts = []
    for dep in ctx.attr.deps:
        for f in dep[TsLibraryInfo].js.to_list():
            all_js.append(f)
        for f in dep[TsLibraryInfo].ts.to_list():
            all_ts.append(f)
    all_js = depset(all_js).to_list()
    all_ts = depset(all_ts).to_list()

    base_module_js = ctx.actions.declare_file("base_module.js")
    ctx.actions.write(base_module_js, "\n".join([
        "",
        "document.addEventListener('DOMContentLoaded', () => {",
    ] + ["System.import('%s');" % m for m in ctx.attr.base_modules or []] + [
        "});"
    ]))

    wrapped_js = ctx.actions.declare_file("wrapped_raw_js.js")
    wrapped_js_commands = ["set -e"]
    for f in all_js:
        wrapped_js_commands = wrapped_js_commands + [
            "echo \"System.register('{}', [], function(exports) {{\" >> {}".format(f.short_path.replace(".js", ""), wrapped_js.path),
            "echo \"  return {{'execute': function() {{\" >> {}".format(wrapped_js.path),
            "echo \"    const _this = {{}};\" >> {}".format(wrapped_js.path),
            "echo \"    (function() {{\" >> {}".format(wrapped_js.path),
            "cat {} >> {}".format(f.path, wrapped_js.path),
            "echo \"    }}).call(_this);\" >> {}".format(wrapped_js.path),
            "echo \"    Object.entries(_this).forEach(e => \" >> {}".format(wrapped_js.path),
            "echo \"        exports(e[0], e[1]));\" >> {}".format(wrapped_js.path),
            "echo \"  }}}}}});\" >> {}".format(wrapped_js.path),
        ]

    ctx.actions.run_shell(
        inputs = all_js,
        outputs = [wrapped_js],
        command = "\n".join(wrapped_js_commands),
    )

    compiled_ts = ctx.actions.declare_file(ctx.attr.name + ".js")
    ctx.actions.run_shell(
        inputs = all_ts + ctx.files._support_js + [
            ctx.file._tsconfig,
            base_module_js,
            wrapped_js,
        ],
        outputs = [compiled_ts],
        command = "\n".join([
            "set -e",
            "cp {} tsconfig.json".format(ctx.file._tsconfig.path),
        ] + [
            "cat {} >> {}".format(f.path, compiled_ts.path)
            for f in ctx.files._support_js
        ] + [
            "tsc --outFile tsc.js --strict",
            "cat tsc.js >> {}".format(compiled_ts.path),
        ] + [
            "cat {} >> {}".format(f.path, compiled_ts.path)
            for f in [wrapped_js, base_module_js]
        ]),
    )

    return DefaultInfo(
        files = depset([compiled_ts]),
    )

ts_binary = rule(
    implementation = _ts_binary_impl,
    attrs = {
        "base_modules": attr.string_list(),
        "deps": attr.label_list(),
        "_tsconfig": attr.label(default="//typescript:tsconfig.json.in", allow_single_file=[".in"]),
        "_support_js": attr.label_list(default=[
            "//typescript:soy.min.js",
            "//typescript:soy_support.js",
            "//typescript:system.min.js",
            "//typescript:named-register.js",
        ], allow_files=[".js"]),
    },
)

def _ts_library_impl(ctx):
    js = list(ctx.files.js_srcs)
    ts = list(ctx.files.srcs)
    for dep in ctx.attr.deps:
        for f in dep[TsLibraryInfo].js.to_list():
            js.append(f)
        for f in dep[TsLibraryInfo].ts.to_list():
            ts.append(f)

    return TsLibraryInfo(
        js = depset(js),
        ts = depset(ts),
    )

ts_library = rule(
    implementation = _ts_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files=[".ts"], default=[]),
        "js_srcs": attr.label_list(allow_files=[".js"], default=[]),
        "deps": attr.label_list(),
    },
)


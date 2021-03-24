load("@io_bazel_rules_closure//closure:defs.bzl", "closure_js_template_library")
load(":defs.bzl", "ts_library")

_DEP_COMPILER = "@com_google_template_soy//:SoyHeaderCompiler"
_JS_COMPILER = "@com_google_template_soy//:SoyToJsSrcCompiler"

SoyInputsInfo = provider(fields = ["inputs"])
SoyWrappersInfo = provider(fields = ["wrappers"])

def _compile_impl(ctx):
    transitive_deps = []
    for d in ctx.attr.deps:
        for f in d[SoyInputsInfo].inputs:
            transitive_deps.append(f)

    compiled_deps = ctx.actions.declare_file(ctx.attr.name + ".deps.gz")
    ctx.actions.run(
        inputs = ctx.files.srcs + transitive_deps,
        outputs = [compiled_deps],
        executable = ctx.executable.dep_compiler,
        arguments = [
            "--output",
            compiled_deps.path,
            "--srcs",
            " ".join([f.path for f in ctx.files.srcs]),
        ] + ([
            "--depHeaders",
            " ".join([d.path for d in transitive_deps]),
        ] if transitive_deps else []),
    )

    ctx.actions.run(
        inputs = ctx.files.srcs + transitive_deps,
        outputs = ctx.outputs.outputs,
        executable = ctx.executable.js_compiler,
        arguments = [
            "--outputPathFormat",
            "%s/{INPUT_DIRECTORY}/{INPUT_FILE_NAME}.js" % ctx.configuration.genfiles_dir.path,
            "--srcs",
            " ".join([f.path for f in ctx.files.srcs]),
        ] + ([
            "--depHeaders",
            " ".join([d.path for d in transitive_deps]),
        ] if transitive_deps else []),
    )

    return SoyInputsInfo(
        inputs = [compiled_deps] + transitive_deps,
    )

_compile = rule(
    implementation = _compile_impl,
    attrs = {
        "srcs": attr.label_list(allow_empty=False, allow_files=[".soy"], mandatory=True),
        "deps": attr.label_list(),
        "outputs": attr.output_list(),
        "dep_compiler": attr.label(cfg="host", executable=True, default=_DEP_COMPILER),
        "js_compiler": attr.label(cfg="host", executable=True, default=_JS_COMPILER),
    },
)

def _ts_wrappers_impl(ctx):
    commands = []
    outputs = []
    count = 0
    for f in ctx.files.js_srcs:
        basic = f.short_path.replace(".soy.js", "_soy")
        out = ctx.actions.declare_file(f.basename.replace(".soy.js", "_soy.ts"), sibling=f)
        outputs.append(out)

        commands.extend([
            "echo \"import * as rule from './%s_rule';\" >> %s" % (ctx.attr.name, out.path),
            "echo \"import * as wrapped_%s from '%s_wrapped';\" >> %s" % (count, basic, out.path),
            "echo \"export function dep_link(): void {\n  rule.link();\n}\" >> %s" % out.path,
            "grep 'function(opt_data, opt_ijData)' %s | awk '{print $1}' | sed 's/^.*\\.\\([^.]*\\)/export function \\1(opt_data?: object, opt_ijData?: object): string {\\n  return wrapped_%s.\\1(opt_data, opt_ijData);\\n}/' >> %s" % (f.path, count, out.path),
        ])
        count += 1

    count = 0
    rule_ts = ctx.actions.declare_file("%s_rule.ts" % ctx.attr.name)
    for dep in ctx.attr.soy_deps:
        for wrapper in dep[SoyWrappersInfo].wrappers:
            basic = wrapper.short_path.replace('.ts', '')
            commands.append(
                "echo \"import * as dep_%s from '%s';\" >> %s" % (count, basic, rule_ts.path))
            count += 1
    commands.append("echo \"export function link(): void {\" >> %s" % rule_ts.path)
    for i in range(count):
        commands.append("echo \"  dep_%s.dep_link();\" >> %s" % (i, rule_ts.path))
    commands.append("echo \"}\" >> %s" % rule_ts.path)

    ctx.actions.run_shell(
        inputs = ctx.files.js_srcs,
        outputs = outputs + [rule_ts],
        command = "\n".join(commands),
    )

    return [
        DefaultInfo(
            files = depset(outputs + [rule_ts]),
        ),
        SoyWrappersInfo(
            wrappers = outputs,
        ),
    ]

_ts_wrappers = rule(
    implementation = _ts_wrappers_impl,
    attrs = {
        "js_srcs": attr.label_list(allow_empty=False, allow_files=[".js"], mandatory=True),
        "soy_deps": attr.label_list(),
    },
)

def _ts_declarations_impl(ctx):
    commands = []
    outputs = []
    for f in ctx.files.js_srcs:
        out = ctx.actions.declare_file(f.basename.replace(".soy.js", "_soy_wrapped.d.ts"), sibling=f)
        commands.append(
            "grep 'function(opt_data, opt_ijData)' %s | awk '{print $1}' | sed 's/^.*\\.\\([^.]*\\)/export function \\1(opt_data?: object, opt_ijData?: object): string;/' > %s" % (f.path, out.path))
        outputs.append(out)

    ctx.actions.run_shell(
        inputs = ctx.files.js_srcs,
        outputs = outputs,
        command = "\n".join(commands),
    )

    return [
        DefaultInfo(
            files = depset(outputs),
        ),
    ]

_ts_declarations = rule(
    implementation = _ts_declarations_impl,
    attrs = {
        "js_srcs": attr.label_list(allow_empty=False, allow_files=[".js"], mandatory=True),
    },
)

def _soy_wrapped_js_impl(ctx):
    commands = []
    outputs = []
    for f in ctx.files.js_srcs:
        out = ctx.actions.declare_file(f.basename.replace(".soy", "_soy_wrapped.js"), sibling=f)
        commands.extend([
            "namespace=\"$(grep goog.provide %s | sed -E \"s/goog.provide..(\\S+)..;/\\1/\")\"" % f.path,
            "echo \"let provide_cursor = window;\" >> %s" % out.path,
            "echo \"const provide_split = '$namespace'.split('.');\" >> %s" % out.path,
            "echo \"for (const key of provide_split.slice(0, -1)) {\" >> %s" % out.path,
            "echo \"  if (!provide_cursor[key]) {\" >> %s" % out.path,
            "echo \"    provide_cursor[key] = {};\" >> %s" % out.path,
            "echo \"  }\" >> %s" % out.path,
            "echo \"  provide_cursor = provide_cursor[key];\" >> %s" % out.path,
            "echo \"}\" >> %s" % out.path,
            "echo \"provide_cursor[provide_split[provide_split.length - 1]] = this;\" >> %s" % out.path,
            "cat %s | grep -E 'goog.provide|goog.require' | sed \"s/goog.\\w*('\\(\\w*\\)\\(\\..*\\)\\?');/const \\1 = window.\\1;/\" | sort -u >> %s" % (f.path, out.path),
            "cat %s | grep -v goog.provide | grep -v goog.require >> %s" % (f.path, out.path),
        ])
        outputs.append(out)

    ctx.actions.run_shell(
        inputs = ctx.files.js_srcs,
        outputs = outputs,
        command = "\n".join(commands),
    )

    return [
        DefaultInfo(
            files = depset(outputs),
        ),
    ]

_soy_wrapped_js = rule(
    implementation = _soy_wrapped_js_impl,
    attrs = {
        "js_srcs": attr.label_list(allow_empty=False, allow_files=[".js"], mandatory=True),
    },
)

def ts_library_from_soy(name, srcs, soy_deps=[]):
    compiled_js = [src + ".js" for src in srcs]
    _compile(
        name = name + "_compile",
        srcs = srcs,
        deps = [d + "_compile" for d in soy_deps],
        outputs = compiled_js,
    )

    _ts_wrappers(
        name = name + "_wrappers",
        js_srcs = compiled_js,
        soy_deps = [d + "_wrappers" for d in soy_deps],
    )

    _ts_declarations(
        name = name + "_declarations",
        js_srcs = compiled_js,
    )

    _soy_wrapped_js(
        name = name + "_wrapped_js",
        js_srcs = compiled_js,
    )

    ts_library(
        name = name,
        srcs = [
            ":%s_wrappers" % name,
            ":%s_declarations" % name,
        ],
        deps = soy_deps,
        js_srcs = [
            ":%s_wrapped_js" % name,
        ],
    )

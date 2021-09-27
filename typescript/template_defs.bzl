load(":defs.bzl", "TsLibraryInfo")
load("//soy:defs.bzl", "SoyInputsInfo")

_JS_COMPILER = Label("//soy:SoyToJsSrcCompiler")

SoyTsInfo = provider(fields = ["js", "ts", "rules"])

def _compile_recursive_impl(target, ctx):
    srcs = []
    soy_js_files = []
    for s in ctx.rule.attr.srcs:
        for src in s.files.to_list():
            srcs.append(src)
            soy_js_files.append(
                ctx.actions.declare_file(src.basename + ".js"))

    direct_deps = []
    indirect_deps = []
    for d in ctx.rule.attr.deps:
        for f in d[SoyInputsInfo].direct:
            direct_deps.append(f)
        for f in d[SoyInputsInfo].indirect:
            direct_deps.append(f)
            indirect_deps.append(f)

    ctx.actions.run(
        inputs = srcs + direct_deps + indirect_deps,
        outputs = soy_js_files,
        executable = ctx.executable._js_compiler,
        arguments = [
            "--outputPathFormat",
            "%s/{INPUT_DIRECTORY}/{INPUT_FILE_NAME}.js" % ctx.configuration.genfiles_dir.path,
            "--srcs",
            " ".join([f.path for f in srcs]),
        ] + ([
            "--depHeaders",
            ",".join([d.path for d in direct_deps]),
        ] if direct_deps else []) + ([
            "--indirectDepHeaders",
            ",".join([d.path for d in indirect_deps]),
        ] if indirect_deps else []),
    )

    commands = []
    ts_wrappers = []
    count = 0
    for f in soy_js_files:
        basic = f.short_path.replace(".soy.js", "_soy")
        out = ctx.actions.declare_file(f.basename.replace(".soy.js", "_soy.ts"), sibling=f)
        ts_wrappers.append(out)

        commands.extend([
            "echo \"import * as rule from './%s_rule';\" >> %s" % (ctx.rule.attr.name, out.path),
            "echo \"import * as wrapped_%s from '%s_wrapped';\" >> %s" % (count, basic, out.path),
            "echo \"export function dep_link(): void {\n  rule.link();\n}\" >> %s" % out.path,
            "grep 'function(opt_data, opt_ijData)' %s | awk '{print $1}' | sed 's/^.*\\.\\([^.]*\\)/export function \\1(opt_data?: object, opt_ijData?: object): string {\\n  return wrapped_%s.\\1(opt_data, opt_ijData);\\n}/' >> %s" % (f.path, count, out.path),
        ])
        count += 1

    count = 0
    rule_ts = ctx.actions.declare_file("%s_rule.ts" % ctx.rule.attr.name)
    for dep in ctx.rule.attr.deps:
        for wrapper in dep[SoyTsInfo].ts.to_list():
            basic = wrapper.short_path.replace('.ts', '')
            commands.append(
                "echo \"import * as dep_%s from '%s';\" >> %s" % (count, basic, rule_ts.path))
            count += 1
    commands.append("echo \"export function link(): void {\" >> %s" % rule_ts.path)
    for i in range(count):
        commands.append("echo \"  dep_%s.dep_link();\" >> %s" % (i, rule_ts.path))
    commands.append("echo \"}\" >> %s" % rule_ts.path)

    ctx.actions.run_shell(
        inputs = soy_js_files,
        outputs = ts_wrappers + [rule_ts],
        command = "\n".join(commands),
    )

    commands = []
    output_declarations = []
    for f in soy_js_files:
        out = ctx.actions.declare_file(f.basename.replace(".soy.js", "_soy_wrapped.d.ts"), sibling=f)
        commands.append(
            "grep 'function(opt_data, opt_ijData)' %s | awk '{print $1}' | sed 's/^.*\\.\\([^.]*\\)/export function \\1(opt_data?: object, opt_ijData?: object): string;/' > %s" % (f.path, out.path))
        output_declarations.append(out)

    ctx.actions.run_shell(
        inputs = soy_js_files,
        outputs = output_declarations,
        command = "\n".join(commands),
    )

    commands = []
    js_wrappers = []
    for f in soy_js_files:
        out = ctx.actions.declare_file(f.basename.replace(".soy.js", "_soy_wrapped.js"), sibling=f)
        js_wrappers.append(out)
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

    ctx.actions.run_shell(
        inputs = soy_js_files,
        outputs = js_wrappers,
        command = "\n".join(commands),
    )

    all_js = soy_js_files + js_wrappers
    all_ts = ts_wrappers + output_declarations + [rule_ts]
    for dep in ctx.rule.attr.deps:
        for f in dep[TsLibraryInfo].js.to_list():
            all_js.append(f)
        for f in dep[TsLibraryInfo].ts.to_list():
            all_ts.append(f)

    rules = [rule_ts]
    return [
        SoyTsInfo(
            js = depset(soy_js_files + js_wrappers),
            ts = depset(ts_wrappers),
            rules = depset([rule_ts]),
        ),
        TsLibraryInfo(
            js = depset(all_js),
            ts = depset(all_ts),
        ),
    ]

_compile_recursive = aspect(
    implementation = _compile_recursive_impl,
    attr_aspects = ["deps"],
    attrs = {
        "_js_compiler": attr.label(cfg="host", executable=True, default=_JS_COMPILER),
    },
)

def _compile_top_impl(ctx):
    all_js = []
    all_ts = []
    js = []
    ts = []
    rules = []
    for dep in ctx.attr.deps:
        for f in dep[SoyTsInfo].js.to_list():
            js.append(f)
        for f in dep[SoyTsInfo].ts.to_list():
            ts.append(f)
        for f in dep[SoyTsInfo].rules.to_list():
            rules.append(f)
        for f in dep[TsLibraryInfo].js.to_list():
            all_js.append(f)
        for f in dep[TsLibraryInfo].ts.to_list():
            all_ts.append(f)
    return [
        DefaultInfo(
            files = depset(js + ts + rules),
        ),
        SoyTsInfo(
            js = depset(js),
            ts = depset(ts),
            rules = depset(rules),
        ),
        TsLibraryInfo(
            js = depset(all_js),
            ts = depset(all_ts),
        ),
    ]

_compile_top = rule(
    implementation = _compile_top_impl,
    attrs = {
        "deps": attr.label_list(aspects = [_compile_recursive]),
    },
)

def ts_library_from_soy(name, srcs, soy_deps):
    _compile_top(
        name = name,
        deps = soy_deps,
    )

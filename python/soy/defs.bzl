load("//soy:defs.bzl", "SoyInputsInfo")

_PY_COMPILER = Label("//soy:SoyToPySrcCompiler")
_SOY_RUNTIME = Label("//python/soy/support")

SoyPyInfo = provider(fields = ["all_py", "py"])

def _compile_recursive_impl(target, ctx):
    srcs = []
    soy_py_files = []
    for s in ctx.rule.attr.srcs:
        for src in s.files.to_list():
            srcs.append(src)
            soy_py_files.append(
                ctx.actions.declare_file(src.basename.replace(".soy", ".py")))

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
        outputs = soy_py_files,
        executable = ctx.executable._py_compiler,
        arguments = [
            "--runtimePath",
            ctx.files._soy_runtime[0].dirname.replace("external/", "").replace("/", "."),
            "--outputPathFormat",
            "%s/{INPUT_DIRECTORY}/{INPUT_FILE_NAME_NO_EXT}.py" % ctx.configuration.genfiles_dir.path,
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

    all_py_files = list(soy_py_files)
    for d in ctx.rule.attr.deps:
        for f in d[SoyPyInfo].all_py.to_list():
            all_py_files.append(f)
    for f in ctx.attr._soy_runtime[PyInfo].transitive_sources.to_list():
        all_py_files.append(f)

    return [
        SoyPyInfo(
            all_py = depset(all_py_files),
            py = depset(soy_py_files),
        ),
    ]

_compile_recursive = aspect(
    implementation = _compile_recursive_impl,
    attr_aspects = ["deps"],
    attrs = {
        "_soy_runtime": attr.label(default=_SOY_RUNTIME),
        "_py_compiler": attr.label(cfg="host", executable=True, default=_PY_COMPILER),
    },
)

def _compile_top_impl(ctx):
    top_py = []
    all_py = []
    for dep in ctx.attr.deps:
        for f in dep[SoyPyInfo].py.to_list():
            top_py.append(f)
        for f in dep[SoyPyInfo].all_py.to_list():
            all_py.append(f)

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(files=all_py),
        ),
        PyInfo(
            imports = depset(),
            transitive_sources = depset(all_py),
        ),
    ]

_compile_top = rule(
    implementation = _compile_top_impl,
    attrs = {
        "deps": attr.label_list(aspects = [_compile_recursive]),
    },
)

def py_library_from_soy(name, srcs, soy_deps):
    _compile_top(
        name = name,
        deps = soy_deps,
    )

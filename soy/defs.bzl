_DEP_COMPILER = Label("//soy:SoyHeaderCompiler")

SoyInputsInfo = provider(fields = ["direct", "indirect"])

def _compile_impl(ctx):
    direct_deps = []
    indirect_deps = []
    for d in ctx.attr.deps:
        for f in d[SoyInputsInfo].direct:
            direct_deps.append(f)
        for f in d[SoyInputsInfo].indirect:
            direct_deps.append(f)
            indirect_deps.append(f)

    compiled_deps = ctx.actions.declare_file(ctx.attr.name + ".deps.gz")
    ctx.actions.run(
        inputs = ctx.files.srcs + direct_deps + indirect_deps,
        outputs = [compiled_deps],
        executable = ctx.executable.dep_compiler,
        arguments = [
            "--output",
            compiled_deps.path,
            "--srcs",
            " ".join([f.path for f in ctx.files.srcs]),
        ] + ([
            "--depHeaders",
            ",".join([d.path for d in direct_deps]),
        ] if direct_deps else []) + ([
            "--indirectDepHeaders",
            ",".join([d.path for d in indirect_deps]),
        ] if indirect_deps else []),
    )

    return [
        DefaultInfo(
            files = depset(ctx.files.srcs),
        ),
        SoyInputsInfo(
          direct = [compiled_deps],
          indirect = indirect_deps,
        ),
    ]

_compile = rule(
    implementation = _compile_impl,
    attrs = {
        "srcs": attr.label_list(allow_empty=False, allow_files=[".soy"], mandatory=True),
        "deps": attr.label_list(),
        "dep_compiler": attr.label(cfg="host", executable=True, default=_DEP_COMPILER),
    },
)

def soy_library(name, srcs, deps=[]):
    _compile(
        name = name,
        srcs = srcs,
        deps = deps,
    )

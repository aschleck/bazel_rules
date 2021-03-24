BASE_IMAGES = {
    "alpine:latest": {
        "label": "docker.io/library/alpine:latest",
        "package_cmd": "apk add --no-cache %s",
        "extra_packages": [
            "gcompat",
            "libstdc++",
        ],
    },
    "debian:sid": {
        "label": "docker.io/library/debian:sid",
        "package_cmd":
            """apt-get update && \
               apt-get install -y %s && \
               rm -rf /var/lib/apt/lists/*""",
        "extra_packages": [],
    },
}

def _container_impl(ctx):
  base = BASE_IMAGES[ctx.attr.base_image]
  if not base:
    fail("Unable to find image " + ctx.attr.base_image)

  base_image = base["label"]
  extra_packages = list(ctx.attr.extra_packages) + base["extra_packages"]
  extra_package_cmds = []

  if PyInfo in ctx.attr.binary:
    if ctx.attr.base_image == "alpine:latest":
      base_image = "docker.io/library/python:alpine"
    else:
      extra_packages.append("python3-dev")
    extra_package_cmds.append("ln -s /usr/bin/python3 /usr/bin/python")

  if extra_packages:
    package_cmds = " && \\\n".join(
        [base["package_cmd"] % " ".join(extra_packages)] + extra_package_cmds)
  else:
    package_cmds = "true"

  dockerfile = ctx.actions.declare_file("Dockerfile")
  executable = ctx.attr.binary[DefaultInfo].files_to_run.executable
  runfiles_dir = "app.runfiles/" + ctx.workspace_name
  ctx.actions.write(
      output = dockerfile,
      content = """
          FROM %s
          RUN %s
          COPY runfiles.tar /
          RUN tar -xf /runfiles.tar && ln -s /%s/%s /%s
          ENTRYPOINT ["/%s"]
          WORKDIR /%s
      """ % (
          base_image,
          package_cmds,
          runfiles_dir,
          executable.short_path,
          executable.basename,
          executable.basename,
          runfiles_dir,
      )
  )

  runfiles = ctx.attr.binary[DefaultInfo].default_runfiles.files.to_list()
  copy_cmds = []
  for f in runfiles:
    copy_cmds.append("mkdir -p $(dirname %s/%s)" % (runfiles_dir, f.short_path))
    copy_cmds.append("cp -r %s %s/%s" % (f.path, runfiles_dir, f.short_path))

  container = ctx.actions.declare_file(ctx.label.name)
  if ctx.attr.builder == "buildah-root":
    build_cmd = "sudo buildah bud --layers"
  else:
    fail("Unknown builder " + ctx.attr.builder)

  ctx.actions.run_shell(
      inputs = [dockerfile] + runfiles,
      outputs = [container],
      command = "\n".join([
          "set -e",
      ] + copy_cmds + [
          "tar -chf runfiles.tar app.runfiles",
          "%s -f %s -t %s ." % (build_cmd, dockerfile.path, ctx.attr.image_name),
          "echo %s > %s" % (ctx.attr.image_name, container.path),
      ]),
      # sudo apt-get install crun
      use_default_shell_env = True,
      # Need to communicate with the Podman socket
      execution_requirements = {
          "no-sandbox": "True",
      },
  )
  return DefaultInfo(files = depset([container]))

container = rule(
    implementation = _container_impl,
    attrs = {
      "binary": attr.label(),
      "image_name": attr.string(),
      "builder": attr.string(
          default="buildah-root",
          values=["buildah-root"]),
      "base_image": attr.string(),
      "extra_packages": attr.string_list(default=[]),
    },
)

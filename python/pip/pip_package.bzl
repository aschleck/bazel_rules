def pip_package():
  name = native.package_name().split('/')[-1]

  native.genrule(
      name = "package",
      srcs = [],
      cmd = """
  DUMMY_HOME=/tmp/$$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
  rm -rf $$DUMMY_HOME
  mkdir -p $$DUMMY_HOME
  HOME=$$DUMMY_HOME \
    python3 -m pip install --no-cache-dir --disable-pip-version-check --no-build-isolation \
    --target=$@ """ + name.replace('_', '-') + """
	rm -rf $$DUMMY_HOME
  """,
      outs = ["pip"],
  )

  native.genrule(
      name = "init",
			srcs = [],
			cmd = "\n".join([
          "echo '",
          "import os",
          "import site",
          "import sys",
          "site.addsitedir(",
          "    os.path.dirname(os.path.abspath(__file__)) + \"/pip\")",
          "sys.path.insert(",
          "    0,",
          "    os.path.dirname(os.path.abspath(__file__)) + \"/pip\")",
          "' | cat > $@",
      ]),
			outs = ["__init__.py"],
	)

  native.py_library(
      name = name,
      srcs = ["__init__.py"] + native.glob(["pip/*.py"]),
      imports = ["pip"],
			data = [":package"],
  )


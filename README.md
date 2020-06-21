# A random Bazel rule

## Python Pip packages

I found the [official rules](https://github.com/bazelbuild/rules_python) to be
annoying, so I've made a less safe alternative.

### Usage

1. Add a reference to this repository in your `WORKSPACE` file:
   ```
   http_archive(
       name = "aprils_rules",
       urls = ["https://github.com/aschleck/bazel_rules/archive/master.tar.gz"],
       strip_prefix = "bazel_rules-master",
   )
   ```
1. Create a directory with the same name as the Pip package anywhere in your workspace:
   `mkdir -p pip/flask`
1. Create a BUILD file for it with the following contents:
   ```
    package(default_visibility = ["//visibility:public"])
    load("@aprils_rules//python/pip:pip_package.bzl", "pip_package")
    pip_package()
    ```
1. Depend on the package from your Python target:
   ```
    py_binary(
        name = "mabel",
        srcs = glob(["*.py"]),
        deps = [
            "//pip/flask",
        ],
    )
    ```
1. And load it in your Python file:
   ```
   import pip.flask
   import flask

   app = flask.Flask(__name__)
   ```

# Random Bazel rules

* [Setup](#setup)
* [Docker container rules](#docker-container-rules)
	+ [Usage](#usage)
* [Python Pip packages](#python-pip-packages)
	+ [Usage](#usage-1)
* [Typescript with Soy support](#typescript-with-soy-support)
	+ [Setup](#setup-1)
	+ [Simple example](#simple-example)
	+ [Example with a base module](#example-with-a-base-module)
	+ [Example with raw JS](#example-with-raw-js)
	+ [Example Soy usage](#example-soy-usage)

## Setup

Add a reference to this repository in your `WORKSPACE` file:
   ```starlark
   http_archive(
       name = "aprils_rules",
       urls = ["https://github.com/aschleck/bazel_rules/archive/master.tar.gz"],
       strip_prefix = "bazel_rules-master",
   )
   ```

## Docker container rules

The [official rules](https://github.com/bazelbuild/rules_docker) are very
complicated. There's probably some good reasons, but I just wanted things to be
easy while allowing me to specify packages to install at build time.

**The Docker rule is very incomplete. In particular, it only allows building
with root `buildah` (because I use it Kubernetes without a registry.)**

**Additionally, while it allows specifying an Alpine image, note that Bazel
must be configured to build with `musl` or else the binaries wont work inside
the container.**

### Usage

1. First, allow password-less `buildah` invocations in your `/etc/sudoers' file.
   ```
   april ALL=(ALL) NOPASSWD: /usr/bin/buildah
   ```
1. Then use the BUILD rules. If the binary target is a Python binary, Python
   will be automatically installed.
   ```starlark
   load("@aprils_rules//docker:defs.bzl", "container")

   cc_binary(
       name = "app",
       srcs = glob(["*.cpp"]) + glob(["*.hpp"]),
   )

   container(
       name = "container",
       binary = ":app",
       image_name = "package/app",
       base_image = "debian:sid"
       extra_packages = [
           "pulseaudio", # the list of apk or apt-get packages to install
       ],
   )
   ```

## Python Pip packages

I found the [official rules](https://github.com/bazelbuild/rules_python) to be
annoying, so I've made a less safe alternative.

### Usage

1. Create a directory with the same name as the Pip package anywhere in your workspace:
   `mkdir -p pip/flask`
1. Create a BUILD file for it with the following contents:
   ```starlark
    package(default_visibility = ["//visibility:public"])
    load("@aprils_rules//python/pip:pip_package.bzl", "pip_package")
    pip_package()
    ```
1. Depend on the package from your Python target:
   ```starlark
    py_binary(
        name = "mabel",
        srcs = glob(["*.py"]),
        deps = [
            "//pip/flask",
        ],
    )
    ```
1. And load it in your Python file:
   ```python
   import pip.flask  # mirrors the file layout, in this case pip/flask
   import flask

   app = flask.Flask(__name__)
   ```

## Typescript with Soy support

The [official rules](https://bazelbuild.github.io/rules_nodejs/TypeScript.html)
are made for using NodeJS, which seemed annoying to set up. Naturally, I've
made an incredibly hacky alternative.

Four additions beyond simple Typescript support:

1. This uses System.JS module loading
1. This allows forcing specific modules to load when the DOM is ready
1. This allows using code from raw JS files (provided there is a .d.ts file)
   in your Typescript
1. This allows compiling and using Soy templates

### Setup

1. Add the following to your `WORKSPACE` file.
   ```starlark
   load("@aprils_rules//typescript:repositories.bzl", "ts_repositories")
   ts_repositories()
   load("@aprils_rules//typescript:repositories_deps.bzl", "repositories_deps")
   repositories_deps()
   ```

### Simple example

1. Write your Typescript files.
   ```typescript
   import { hello } from './same_directory_file';
   import { goodbye } from 'relative/to/workspace/root/file';

   export function act(): void {
     hello();
     goodbye();
   }
   ```
1. Define your Typescript libraries.
   ```starlark
   load("@aprils_rules//typescript:defs.bzl", "ts_library")

   ts_library(
       name = "example",
       srcs = glob(["*.ts"]),
       deps = [
           "//relative/to/workspace/root",
       ],
   )
   ```
1. Define your Typescript binary.
   ```starlark
   load("@aprils_rules//typescript:defs.bzl", "ts_binary")

   # Generates a file named app.js
   ts_binary(
       name = "app",
       deps = [
           "//app/lib:example",
       ],
   )

### Example with a base module

If you need code to run after the page loads, define a base module.

1. As an example, create `app/bootstrap.ts`.
   ```typescript
   module Bootstrap {
     console.log('hello!');
   }
   ```
1. Then, reference it from the `ts_binary` rule.
   ```starlark
   load("@aprils_rules//typescript:defs.bzl", "ts_binary", "ts_library")

   ts_library(
      name = "app_lib",
      srcs = glob(["*.ts"]),
   )

   ts_binary(
       name = "app",
       deps = [
           ":app_lib",
       ],
       base_modules = [
           "app/bootstrap",
       ],
   )

### Example with raw JS

1. Create a raw Javascript file.
   ```javascript
   function be_nice() {
     console.log("you're amazing!");
   }
   ```
1. Create a Typescript declarations file. This file must match the name of the
   raw JS file (for example, if the JS is `nice.js` this must be `nice.d.ts`.)
   ```typescript
   export declare function be_nice(): void;
   ```
1. Create a Typescript library for it.
   ```starlark
   load("@aprils_rules//typescript:defs.bzl", "ts_library")

   ts_library(
       name = "nice",
       srcs = ["nice.d.ts"]),
       js_srcs = [
          "nice.js",
       ],
   )
   ```
1. Depend on it like any other Typescript library.

### Example Soy usage

**Please note that there is currently no type checking on inputs passed to
Soy.**

1. Create an amazing Soy file, for example `app/app.soy`.
   ```soy
   {namespace not.actually.used}

   {template .message}
     {@param name: string}
     Hello world, {$name}!
   {/template}
   ```
1. Make a `BUILD` rule for it and have your code depend on it like any other
   Typescript library.
   ```starlark
   load("@aprils_rules//typescript:template_defs.bzl", "ts_library_from_soy")

   ts_library(
       name = "app_lib",
       deps = [
           ":soy",
       ],
   )

   ts_library_from_soy(
       name = "soy",
       srcs = glob(["*.soy"]),
       soy_deps = [
           "//app:app_soy",
       ],
   )
   ```
1. Reference it by full path (not relative!) in your Typescript code.
   ```typescript
   import * as templates from 'app/app_soy';

   export function render_message(): string {
     return templates.message({name: 'April'});
   }
   ```

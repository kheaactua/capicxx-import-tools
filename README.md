# CommonAPI Build Tools

This package contains the build tools for the CommonAPI C++ project.
- Conan definitions for vsomeip, capicxx-core-runtime, capicxx-someip-runtime, capicxx-cmake-modules, and capicxx-generators
- CMake macros to run the CommonAPI generators
- Soong module to run the CommonAPI generators

The impetus of this project is twofold, first by providing Conan recipes this
greatly simplifies the effort in building CommonAPI projects complicated by
their dependencies. Second, this project introduces
`capicxx-cmake-modules` and `capi_genrule` which renders using the CommonAPI
libraries and tools on Android (AOSP) much easier.

The structure of this repository is geared towards being an example rather than
for actual deployment.  In practise the subcomponents of this repository
should exist in their own repositories.  More on this in
[expansion](#Expanding) section.

# Conan

The Conan recipes in this repository are here to create a "wholistic" build
environment for CommonAPI.  The aim is the greatly simplify (especially with
cross-compilation) the steps to setup a CommonAPI project.  While Conan was
first chosen as a way to keep this repository organized as a single
demonstration repository, the Conan recipes provide true value and can be used
in a real projects.

Conversely, the CMake scripts in this repository can be used entirely without
Conan.  The Conan setup here simply connects the dots (`CMAKE_PREFIX_PATH`,
headers, _etc_) between the various packages.

Please see the [Conan](conan/README.md) section for how to use the Conan recipes.

# Modules

## capicxx-core-runtime, vsomeip, capicxx-someip-runtime

These modules build the unmodified CommonAPI runtime libraries sourced from
[Covesa](https://github.com/covesa).

## capicxx-cmake-modules

Provides CMake Find scripts to Common API assets and their dependencies.  These
modules support the SomeIP middleware (DBus is also supported but not well tested.)

Please see its [README](conan/capicxx-cmake-modules/README.md) for more information.

## capi-config

This module contains the CommonAPI configuration files for the vsomeip
middleware.  It's extremely minimal in this example, but does provide a good
mechanism for injecting configuration.  This module would contain specific
configuration content for your specific deployment.

Currently is exports a `commonapi.ini`, this can easily be expanded to include
vsomeip configuration files too.

## example-app

This is a simple (as simple as can be just about) example app included here to
show the usage of `capicxx-cmake-modules`/`capi_genrule`.

## workspace

This is another example module that exists here strictly for demonstration
purposes in the Conan setup.  As described in [Conan](conan/README.md), this
module is used to create a virtual environment that includes the `example-app`
and all its dependencies.

# Android

Please see the [Android](soong/README.md) section for how to use the
`capi_genrule` and `capi_app` modules in your Android project to build,
generate, and link against the CommonAPI libraries.

# Expanding

## Simple Addition

As discussed above, this project is laid out as it is to be a simple one-repo
example.  It can be expanded upon though.  If for instance you have a CommonAPI
project and want to take advantage of the tools here without the overhead of
re-organizing this project, you can model it after the example-app project:

- Create a new conan recipe in `conan/<your-project-name>`
- Add your source files in that directory, and export them in the `conanfile.py`
- In the `conan/workspace/conanfile.py`, include your project in the `requires` list

## Proper Deployment

For an actual workspace, I think it's best that this repository be split into multiple repositories:
- `conan-config`: A repository dedicated to your organization's/project's Conan
  config - this is where the remotes, config, profiles, _etc_ should live.  See
  [conan config](https://docs.conan.io/2.4/reference/commands/config.html).
- `capicxx-conan`: A repository that contains all the Conan recipes, similar to
  [conan-center-index](https://github.com/conan-io/conan-center-index/tree/master/recipes)
- Each of the modules in the `conan/` directory should be their own repository


[modeline]: # ( vim: set fenc=utf-8 spell spl=en ts=2 sw=2 expandtab sts=0 ff=unix : )

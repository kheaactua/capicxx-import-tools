#  Overview

Provides CMake Find scripts to Common API assets and their dependencies.  These
modules support the SomeIP middleware (DBus is also supported but not well tested.)

# Description

The project wraps all the CommonAPI (capicxx) assets into targets with proper
namespaces.  While `capicxx-{someip,core}-{runtime,tools}` do actually provide
`Config.cmake` files, these files fail to export useful targets.  The scripts
provided in this package use the exported `Config.cmake` files, but wrap them
in namespaced targets along with their dependencies.

This is done by having a "_parent_" `FindCommonAPIImporter.cmake` file that
defines targets for the defined components.

Example usage:
```cmake
find_package(CommonAPIImporter 3.2.3 REQUIRED COMPONENTS Core SomeIP gen)
```

Note that the version is only applied to the external assets
(`capicxx-{dbus,core,someip}-{runtime,tools}`.)

The "`gen`" component is a virtual component that will be provided by either
the `DBus-gen` or `SomeIP-gen` component (depending on which is selected, if both
are this virtual component cannot be used.)

With this package, you get the following targets:
- `CommonAPI::Core`: Core component (should always be used and linked)
- `CommonAPI::Transport`: Your middleware target (either`someip` or `DBus` right now)
- `CommonAPI::Core::gen`, `CommonAPI::Transport::gen`, `CommonAPI::DBus::gen`, `CommonAPI::SomeIP::gen`: Generator targets for CommonAPI core code. (in case you want to call these directly)

There is also a macro provided to run the generators, `SET_UP_GEN_FILES` in the
include `${CAPI_GENERATE_INCLUDE}`.  This macro sets up all the generated
sources to be built by the `CommonAPI::Core::gen` and
`CommonAPI::Transport::gen`.  If you do no supply a generator component, no
generator will be provided and the following example will not work
(`SET_UP_GEN_FILES` will output errors.)

The `SET_UP_GEN_FILES` macro above creates rules for building your generated
sources, these sources are specified as dependencies of your target, and thus
when your client app is configured, the sources are automatically generated.

# Internals

The package works by the "parent" FindScript looping over the requested
components and delegating the work to include files in the `impl` subdirectory.
Those includes define interface targets such as `common_api_core` with all
their required dependencies.  The parent then assigns aliases to these targets
to simulate namespaces, _i.e._ `common_api_core` becomes `CommonAPI::Core`.

This is done because CMake can only apply namespaces (any symbol with a `::` in
its name) to `IMPORTED` or `ALIAS` targets.  This is limiting because
`IMPORTED` targets are a lot more constrained, and really we want `INTERFACE`
targets in order to carry the dependencies along.

Note that the `capicxx-*` projects due actually export CMake `Config.cmake`
files that could be directly imported, however the targets created in these
packages are incomplete and still require the user to perform more
bootstrapping.  Thus, the CommonAPI find scripts in this repository do leverage
the `capicxx-*` exported packages, but wrap them in easy to use targets.

[modeline]: # ( vim: set fenc=utf-8 spell spl=en ts=2 sw=2 expandtab sts=0 ff=unix : )

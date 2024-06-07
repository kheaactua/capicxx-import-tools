# Overview

Provides Conan recipes to build the CommonAPI runtime libraries and
generators, as well as an example app that uses them.

## Prerequisites

- Install Conan (v2.3+)
- Setup Conan profiles

Please follow the instructions at [Conan Getting
Started](https://docs.conan.io/2/installation.html) to install Conan.  Once
installed, you'll have to setup your build profiles (see
[Profiles](https://docs.conan.io/2/reference/config_files/profiles.html#profiles)).

In addition to the default profile (likely gcc), there are two example profiles
in [conan/profiles](profiles/) in this repository.  To use
these, either install them into `~/.conan2/profiles`, or specify them when issuing conan commands, _e.g._:
```sh
conan install . -pr conan/config/profiles/clang
```

Please see the [Profiles](#Profiles) below for more details.

## Building

The conan recipes aren't yet uploaded to `conancenter` or any other remote yet,
so you will have to export and build them.

There are several recipes in this project:
- `capicxx-core-runtime`, `capicxx-vsomeip-runtime`, `capicxx-someip-runtime`: The CommonAPI runtime libraries with the vsomeip middleware
- `capicxx-generators`: The CommonAPI generators.  This will download the generator archived from GitHub and install them into this package.
- `capicxx-cmake-modules`: CMake find scripts to locate the CommonAPI assets.  See below.
- `example-app`: An example project that uses the CommonAPI generators and links against the generated sources.
- `workspace`: A virtual environment that will install the example project and all its dependencies, along with shell scripts that load the environment.

For simplicity, see the [build_all.sh](build_all.sh) script to build the entire
project.  This will generate a virtual run environment, to load it source the
file `conanrun.sh`, your session will then be populated with the appropriate
environment variables (_e.g._ `PATH`, `LD_LIBRARY_PATH`, _etc_.)

The example app can then be executed with:
```sh
# Load the environment
. ./conanrun.sh

# Run the service
example-service &

# Run the client
example-client
```
The client (proxy) will connect and then the app will cease - this example is a
tiny trivial example intended to show how to use the CommonAPI generators and
runtime libraries rather than how to use CommonAPI well.

If you experience build issues, enable the option `verbose_makefile`, this is
an option I put into these recipes to generate verbose build files.  I did
this because the intrinsic `tools.build/*:verbosity=verbose` and
`tools.compilation/*:verbosity=verbose` don't seem to do anything.

You could also consult the [Package Development
Flow](https://docs.conan.io/2/tutorial/developing_packages/local_package_development_flow.html)
documentation.

# Profiles

This repository contains a few example profiles, including one for x86\_64
clang and one for QNX. The QNX profile is untested as the current vsomeip
releases do not support QNX, but does still provide guidance on how to create a
Conan QNX profile.  There are some caveats:
1. This profile requires that `QNX_HOST` and `QNX_TARGET` are set in your
   environment, and the `qcc` and `q++` compilers are in your path.  This is
   typically done by sourcing the `qnxsdp-env.sh` in your QNX SDP installation.
   Note that a profile _could_ set this up, but because of licensing and
   installation processes there is no general way to do this in a public
   instructions like these.
1. This repository currently targets the public vsomeip3.4 release which is
   still undergoing integration work to better support QNX.  As such it is not
   expected that this branch with this tag will build.

You can use these profiles by either installing them into `~/.conan2/profiles`
with the `config config install` command or by specifying their path.  In both
cases, assuming `CONAN_BASE` is still set as specified above:
1. Install the profiles (copies the contents to `~/.conan2`):
```sh
conan config install ${CONAN_BASE}/config

# Use the profile
conan install . -pr clang
```
2. Use the profile in place
```sh
conan install . -pr ${CONAN_BASE}/profiles/clang
```

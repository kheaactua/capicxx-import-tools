# Overview

The Android portion of this project adds (bootstraps) a Soong module to run the
CommonAPI generators (Core and SomeIP, DBus is not supported.)  Note that the
generators have their binaries included in this repository - this is done
because the AOSP build must be able to access everything _via_ git.

# Setup

Add this project into your manifest
<span style="background-color: #FFFF00">TODO: Change URLs</span>
```xml
<remote name="kheaactua" fetch="https://github.com/kheaactua/capicxx-import-tools" />
<project name="capicxx-import-tools" path="prebuilts/capi-generators" remote="kheaactua" revision="refs/heads/master" />
```

This will deploy the generators into the workspace at the paths:
- `prebuilts/capi-generators/generators/core`
- `prebuilts/capi-generators/generators/someip`

The `Android.bp` file contains definitions to import the generators as
`prebuilt_build_tool`, as well as importing the `capi_genrule` module that a
component can use to generate CommonAPI source files.  Additionally, when a
build is run, the outputting Soong documents will include the reference
material for `capi_genrule`.

This Soong file also creates a `capi_app` `default` module which can be used to
apply all the traits required to link against the CommonAPI libraries.  This is
done by adding the `capi_app` to the `defaults` of your module.

Please see the [Android.bp](../conan/example-app/Android.bp) in the minimal example
(`conan/example-app`) for how to use `capi_genrule`.

[modeline]: # ( vim: set fenc=utf-8 spell spl=en ts=2 sw=2 expandtab sts=0 ff=unix : )

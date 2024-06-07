#!/usr/bin/env python
# -*- coding: utf-8 -*-

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout


class CapicxxCMakeModulesRecipe(ConanFile):
    name = "capicxx-cmake-modules"
    package_type = "unknown"
    settings = "os", "build_type"
    author = "Matthew Russell <matthew.g.russell@gmail.com>"
    description = "CMake modules to import and use capicxx generators"

    version = "0.7.5"
    user = "kheaactua"
    channel = "stable"

    tool_requires = "cmake/[>=3.23]"
    requires = (
        "capicxx-core-runtime/[>=3.2.3r7, include_prerelease]@covesa/stable",
        "capicxx-someip-runtime/[>=3.2.3r8, include_prerelease]@covesa/stable",
        "capicxx-generators/3.2.14@kheaactua/stable",
        "vsomeip/3.4.10@covesa/stable",
    )
    exports_sources = ("CMakeLists.txt", "FindScripts/*.cmake")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        tc = CMakeToolchain(self)
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.builddirs = ["lib/cmake"]

#!/usr/bin/env python
# -*- coding: utf-8 -*-

from conan import ConanFile
from conan.tools.cmake import CMake, cmake_layout


class ExampleAppConan(ConanFile):
    name = "example-app"
    package_type = "application"
    settings = "os", "compiler", "build_type", "arch"
    author = "Matthew Russell <matthew.g.russell@gmail.com>"
    description = "Covesa CommonAPI Minimal example"

    version = "1.0.0"
    user = "kheaactua"
    channel = "stable"

    options = {
        "verbose_makefile": [True, False],
    }
    default_options = {"verbose_makefile": False}

    tool_requires = ("cmake/[>=3.23]", "gtest/[>=1.10]", "capicxx-generators/3.2.14@kheaactua/prebuilt")
    requires = "capicxx-cmake-modules/[>=0.7.5]@kheaactua/stable"

    generators = "CMakeToolchain"

    exports_sources = (
        "fidl/*.fidl",
        "fidl/*.fdepl",
        "src/**/*.hpp",
        "src/**/*.cpp",
        "CMakeLists.txt",
    )

    def layout(self):
        cmake_layout(self)

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

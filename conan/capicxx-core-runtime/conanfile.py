#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout
from conan.tools.scm import Git


class CapicxxCoreRuntimeConan(ConanFile):
    name = "capicxx-core-runtime"
    package_type = "shared-library"
    settings = "os", "compiler", "build_type", "arch"
    license = "https://github.com/COVESA/capicxx-core-runtime/blob/master/LICENSE"
    author = "https://github.com/COVESA/capicxx-core-runtime/blob/master/AUTHORS"
    description = "Covesa capicxx-core-runtime"

    version = "3.2.3r7"
    user = "covesa"
    channel = "stable"

    options = {
        "verbose_makefile": [True, False],
    }
    default_options = {"verbose_makefile": False}

    tool_requires = ("cmake/[>=3.23]", "gtest/[>=1.10]")

    def layout(self):
        cmake_layout(self, src_folder="src", build_folder="bld")

    def source(self):
        git = Git(self)
        git.clone(url="https://github.com/covesa/capicxx-core-runtime.git", target=".")

        tag = re.sub(r"r", "-r", self.version)
        git.checkout(tag)

    def generate(self):
        tc = CMakeToolchain(self)

        if self.settings.os == "Neutrino":
            tc.cache_variables["PKG_CONFIG_EXECUTABLE"] = ""
        tc.cache_variables["CMAKE_VERBOSE_MAKEFILE"] = self.options.verbose_makefile

        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure(
            variables={
                "USE_FILE": False,
                "USE_CONSOLE": False,
                "USE_DLT": False,
            }
        )
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["CommonAPI"]
        self.cpp_info.builddirs = ["lib/cmake"]

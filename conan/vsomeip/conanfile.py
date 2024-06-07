#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMakeDeps, CMake, cmake_layout
from conan.tools.scm import Git
from conan.tools.files import get


class VSomeIPConan(ConanFile):
    name = "vsomeip"
    package_type = "shared-library"
    settings = "os", "compiler", "build_type", "arch"
    license = "https://github.com/COVESA/vsomeip/blob/master/LICENSE"
    author = "https://github.com/COVESA/vsomeip/blob/master/AUTHORS"
    url = "https://github.com/covesa/vsomeip.git"
    description = "An implementation of Scalable service-Oriented MiddlewarE over IP"
    topics = ("tcp", "C++", "networking")

    version = "3.4.10"
    user = "covesa"
    channel = "stable"

    options = {
        "verbose_makefile": [True, False],
        "multiple_routingmanagers": [True, False],
        "install_routingmanager": [True, False],
        "disable_security": [True, False],
        "enable_signal_handling": [True, False],
    }
    default_options = {
        "disable_security": True,
        "verbose_makefile": False,
        "multiple_routingmanagers": True,
        "install_routingmanager": True,
        "enable_signal_handling": True,
        "boost/*:shared": False,
        "boost/*:without_context": True,
        "boost/*:without_fiber": True,
        "boost/*:without_coroutine": True,
        "boost/*:without_mpi": True,
    }

    def config_options(self):
        if self.settings.os == "Linux":
            self.default_options["boost/*:with_stacktrace_backtrace"] = True

    def requirements(self):
        self.requires("boost/[>=1.82]")
        self.requires("benchmark/[>=1.8]", libs=True)

        if self.settings.os == "Linux":
            self.requires("gtest/[>=1.10]", libs=True)

    def layout(self):
        cmake_layout(self, src_folder="vsomeip-source")

    def source(self):
        git = Git(self)
        git.clone(url="https://github.com/covesa/vsomeip.git", target=".")
        git.checkout(self.version)

        # vsomeip wants googletest as source
        get(
            self,
            **self.conan_data["gtest-sources"]["1.10.0"],
            strip_root=True,
            destination=os.path.join("..", "gtest"),
        )

    def generate(self):
        # Without this, we won't find benchmark
        cd = CMakeDeps(self)
        cd.generate()

        tc = CMakeToolchain(self)

        tc.cache_variables["CMAKE_POLICY_DEFAULT_CMP0093"] = "NEW"

        # Not sure why, but boost when imported by Conan doesn't have
        # BOOST_VERSION_MACRO defined (despite using CMake>1.15), this was also
        # reported at
        # https://github.com/conan-io/conan-center-index/issues/22249 .  Adding
        # it back in.  Being careful about how I build the version string such
        # that custom forks of the conan boost recipes will still work
        bc = self.dependencies["boost"].ref.version
        boost_version_macro = (
            f"{bc.major.value:<02}{bc.minor.value:<02}{bc.patch.value:<02}"
        )
        tc.cache_variables["Boost_VERSION_MACRO"] = f'"{boost_version_macro}"'

        tc.cache_variables["ENABLE_MULTIPLE_ROUTING_MANAGERS"] = (
            self.options.multiple_routingmanagers
        )
        tc.cache_variables["ENABLE_SIGNAL_HANDLING"] = (
            self.options.enable_signal_handling
        )
        tc.cache_variables["VSOMEIP_INSTALL_ROUTINGMANAGERD"] = (
            self.options.install_routingmanager
        )
        tc.cache_variables["DISABLE_SECURITY"] = self.options.disable_security

        if self.settings.os == "Neutrino":
            tc.cache_variables["PKG_CONFIG_EXECUTABLE"] = ""

        tc.cache_variables["CMAKE_VERBOSE_MAKEFILE"] = self.options.verbose_makefile

        tc.cache_variables["GTEST_ROOT"] = os.path.join(
            self.source_folder, "..", "gtest"
        )

        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.builddirs = ["lib/cmake"]
        self.cpp_info.libs = ["vsomeip3", "vsomeip3-sd", "vsomeip3-e2e"]
        if not self.options.multiple_routingmanagers:
            self.cpp_info.libs.append("vsomeip3-cfg")

        if self.settings.os == "Windows":
            self.cpp_info.systm_libs.extend(["winmm", "ws2_32"])
        elif self.settings.os == "Neutrino":
            self.cpp_info.system_libs.extend(["socket", "regex"])

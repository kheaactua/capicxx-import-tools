#!/usr/bin/env python
# -*- coding: utf-8 -*-

from conan import ConanFile


class CapiWorkspaceConan(ConanFile):
    name = "capi-workspace"
    package_type = "application"
    settings = "os", "compiler", "build_type", "arch"
    author = "Matthew Russell <matthew.g.russell@gmail.com>"
    description = "Covesa capicxx-example workspace"

    version = "1.0.0"
    user = "kheaactua"
    channel = "stable"

    requires = ("example-app/1.0.0@kheaactua/stable",)

    generators = ("VirtualRunEnv", "VirtualBuildEnv")

    def requirements(self):
        self.requires("capi-config/[>=1.0]@kheaactua/stable", run=True, libs=True)

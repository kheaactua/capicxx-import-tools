#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os

from conan import ConanFile
from conan.tools.files import copy


class ExampleCapiConfigConan(ConanFile):
    name = "capi-config"
    package_type = "application"
    author = "Matthew Russell <matthew.g.russell@gmail.com>"
    description = "CommonAPI configuration for example app"

    version = "1.0.0"
    user = "kheaactua"
    channel = "stable"

    exports_sources = "commonapi.ini"

    def package(self):
        copy(self, "commonapi.ini", src=self.source_folder, dst=self.package_folder)

    def package_info(self):
        self.runenv_info.define(
            "COMMONAPI_CONFIG", os.path.join(self.package_folder, "commonapi.ini")
        )

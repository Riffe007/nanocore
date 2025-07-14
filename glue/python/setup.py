"""
NanoCore Python Bindings Setup
"""

from setuptools import setup, Extension, find_packages
from pathlib import Path
import platform
import os

# Read the README
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text() if (this_directory / "README.md").exists() else ""

# Platform-specific settings
if platform.system() == "Windows":
    extra_compile_args = ["/O2", "/std:c++17"]
    extra_link_args = []
    libraries = ["nanocore_ffi"]
elif platform.system() == "Darwin":
    extra_compile_args = ["-O3", "-std=c++17", "-march=native"]
    extra_link_args = ["-framework", "CoreFoundation"]
    libraries = ["nanocore_ffi"]
else:  # Linux
    extra_compile_args = ["-O3", "-std=c++17", "-march=native", "-fPIC"]
    extra_link_args = ["-Wl,-rpath,$ORIGIN"]
    libraries = ["nanocore_ffi"]

# Build the extension
nanocore_module = Extension(
    "nanocore._nanocore",
    sources=["nanocore/nanocore_module.c"],
    include_dirs=["../../glue/ffi/include"],
    library_dirs=["../../build/lib"],
    libraries=libraries,
    extra_compile_args=extra_compile_args,
    extra_link_args=extra_link_args,
)

setup(
    name="nanocore",
    version="0.1.0",
    author="NanoCore Team",
    author_email="team@nanocore.dev",
    description="High-performance assembly VM Python bindings",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/nanocore/nanocore",
    packages=find_packages(),
    ext_modules=[nanocore_module],
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Interpreters",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Assembly",
        "Programming Language :: C",
        "Programming Language :: Rust",
    ],
    python_requires=">=3.8",
    install_requires=[
        "numpy>=1.20.0",
        "cffi>=1.15.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0",
            "pytest-benchmark>=4.0",
            "black>=22.0",
            "mypy>=0.990",
            "sphinx>=5.0",
        ],
    },
)
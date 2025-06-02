from setuptools import setup, Extension, find_packages
from Cython.Build import cythonize
import pathlib

here = pathlib.Path(__file__).parent

extensions = [
    Extension(
        "pyrut",
        sources=["pyrut/rut.pyx"],
        extra_compile_args=["-O3", "-march=native"],
        language="c"
    ),
]

setup(
    name="PyRut",
    version="1.0.4",
    description="High-performance Chilean RUT validation & formatting (Cython)",
    long_description=here.joinpath("README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    author="Bastian Garcia",
    author_email="bastiang@uc.cl",
    url="https://github.com/cve-zh00/PyRut",
    packages=find_packages(),
    ext_modules=cythonize(extensions),
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Cython",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.8",
    zip_safe=False,
)

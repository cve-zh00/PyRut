# PyRut

PyRut is a high-performance Python module leveraging Cython to accelerate computational tasks while maintaining the simplicity of Python. PyRut provides functions designed to handle Chilean RUT numbers (Rol Único Tributario) including validation, formatting, and computing verification digits.

## Installation

Install PyRut directly from PyPI:

    pip install PyRut

For development purposes or to build from source, clone the repository and run:

    python setup.py build_ext --inplace

## Usage

Below are examples demonstrating the functions provided by the 'rut' module.

### Validating a RUT

    from pyrut import validate_rut

    # Validate RUT using the Cython implementation
    if validate_rut("210496157"):
        print("Valid RUT")
    else:
        print("Invalid RUT")

### Formatting a RUT

    from pyrut import format_rut

    # Format the RUT string (e.g., "21049615-7" to "21.049.615-7")
    formatted_rut = format_rut("21049615-7", dots=True)
    print("Formatted RUT:", formatted_rut)

### Computing the Verification Digit

    from pyrut import verification_digit

    # Calculate the verification digit for a given RUT number
    digit = verification_digit("21049615")
    print("Verification Digit:", digit)


### Using Type

    from fastapi import FastAPI
    from pyrut.types import Rut

    app = FastAPI()

    @app.get("/persona-c/{rut}")
    async def root(rut: Rut):
        return {"message": "Hello World", "rut": rut}


## Documentation

Detailed module documentation is available in the docs directory. See docs/index.md for complete details.

## Running Tests

Unit tests are located in the tests directory. Run them using a testing framework like pytest:

    pytest pyrut/tests
    


## Contributing

Contributions are welcome! Please submit issues and pull requests for improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

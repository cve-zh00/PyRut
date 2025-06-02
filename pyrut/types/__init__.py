from typing import Annotated
from pydantic import BeforeValidator

from .rut import validate_rut_string

Rut = Annotated[str, BeforeValidator(validate_rut_string)]

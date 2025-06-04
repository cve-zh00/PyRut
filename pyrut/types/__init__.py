from typing import Annotated
from pydantic import BeforeValidator
from functools import partial

from pyrut import validate_rut_string

Rut = Annotated[str, BeforeValidator(partial(validate_rut_string, suspicious=False))]

RutNotSuspicious = Annotated[str, BeforeValidator(partial(validate_rut_string, suspicious=True))]

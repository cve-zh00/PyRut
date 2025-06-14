from fastapi import FastAPI
from pyrut.types import Rut
from itertools import cycle
from pydantic import BeforeValidator
from typing import Annotated

def validar_rut(rut):
    rut = rut.upper().replace("-", "").replace(".", "")
    rut_aux = rut[:-1]
    dv = rut[-1:]

    if not rut_aux.isdigit() or not (1_000_000 <= int(rut_aux) <= 25_000_000):
        return False

    revertido = map(int, reversed(rut_aux))
    factors = cycle(range(2, 8))
    suma = sum(d * f for d, f in zip(revertido, factors))
    residuo = suma % 11

    if dv == 'K':
        return residuo == 1
    if dv == '0':
        return residuo == 11

    if residuo == 11 - int(dv):
        return rut
    else:
        raise ValueError(f"Invalid RUT: {rut}")



app = FastAPI()

RutPy = Annotated[str, BeforeValidator(validar_rut)]

@app.get("/person/{rut}")
async def rutcython(rut: Rut):
    return {"message": "Hello World", "rut": rut}

@app.get("/person/{rut}")
async def rutpython(rut: RutPy):
    return {"message": "Hello World", "rut": rut}

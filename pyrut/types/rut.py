from py_rut import validate_rut

def validate_rut_string(v: str) -> str:
    if validate_rut(v):
        return v
    else:
        raise ValueError(f"Invalid RUT: {v}")

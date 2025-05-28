import pytest
from pyrut import validate_rut, format_rut, verification_digit

def test_validate_rut_valid():
    # Se espera que este RUT sea válido
    assert validate_rut("210496157") == True

def test_validate_rut_invalid():
    # Asumimos que un RUT con ceros no es válido
    assert validate_rut("000000000") == False

def test_format_rut():
    # Se espera que al formatear "21049615-7" se obtenga "21.049.615-7"
    formatted = format_rut("21049615-7", dots=True)
    expected = "21.049.615-7"
    assert formatted == expected

def test_verification_digit():
    # Se espera que el dígito verificador para "21049615" sea "6"
    digit = verification_digit("21049615")
    expected = "7"
    assert digit == expected

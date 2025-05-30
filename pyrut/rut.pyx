# distutils: language = c
# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True

from libc.stdint cimport uint16_t, uint8_t, uint64_t
from libc.stddef cimport size_t
from libc.stdlib cimport malloc, free
from cpython.bytes cimport PyBytes_AsString, PyBytes_AsStringAndSize
from libc.stdlib cimport free
from cpython.unicode cimport PyUnicode_FromStringAndSize
from libc.string cimport strlen

cpdef bint validate_rut(str input_rut):
    """
    Valida un solo RUT (str) y devuelve True/False.
    """
    cdef bytes b = input_rut.encode('utf-8')
    cdef char *data = PyBytes_AsString(b)
    cdef bint result = _validate_rut(data)
    return result


cpdef str format_rut(str rut, bint dots=True, bint uppercase=True, bint ignore_invalid=False):
    """
    Formatea un RUT (str) con puntos y guión.
    """
    cdef bytes b = rut.encode('utf-8')
    cdef char *data = PyBytes_AsString(b)
    cdef char *formatted_rut = format_rut_c(data, dots, uppercase, ignore_invalid)
    cdef str result = formatted_rut.decode('utf-8')
    free(formatted_rut)
    return result



cdef char* format_rut_c(const char* rut,
                        bint dots,
                        bint uppercase,
                        bint ignore_invalid):
    cdef const char* p = rut
    cdef char c, dv_char = 0
    cdef Py_ssize_t total_valid = 0
    cdef size_t i, body_len, out_len
    cdef char* out
    cdef char* dst
    cdef Py_ssize_t ndots = 0

    # ——————————————
    # 1) Primer pase: contar dígitos + capturar DV
    # ——————————————
    for i in range(strlen(rut)):
        c = p[i]
        if b'0' <= c <= b'9' or c == b'K' or c == b'k':
            dv_char = c
            total_valid += 1
        elif c == b'.' or c == b'-' or c == b' ':
            continue
        else:
            if not ignore_invalid:
                return NULL

    if total_valid < 2:
        return NULL

    body_len = total_valid - 1

    #    forzar mayúscula vía bitmasking (más rápida que rama)
    if uppercase:
        dv_char &= 0xDF  # convierte 'k' a 'K' si procede

    if dots:
        ndots = (body_len - 1) // 3

    # body_len dígitos + ndots puntos + '-' + DV + '\0'
    out_len = body_len + ndots + 3

    out = <char*> malloc(out_len)
    if not out:
        return NULL

    # ——————————————
    # 3) Segundo pase: construir la cadena formateada
    # ——————————————
    dst = out
    total_valid = 0  # reusar como contador de dígitos emitidos

    for i in range(strlen(rut)):
        c = p[i]
        if b'0' <= c <= b'9' or c == b'K' or c == b'k':
            if total_valid < body_len:
                # insertar punto si toca
                if dots and total_valid > 0 and ((body_len - total_valid) % 3) == 0:
                    dst[0] = b'.'; dst += 1

                # emitir dígito o 'K'/'k'
                if (c == b'K' or c == b'k'):
                    if uppercase:
                        dst[0] = b'K'
                    else:
                        dst[0] = b'k'
                else:
                    dst[0] = c
                dst += 1

            total_valid += 1

    # añadir guión, dígito verificador y terminador
    dst[0] = b'-'; dst += 1
    dst[0] = dv_char; dst += 1
    dst[0] = b'\0'

    return out

cdef inline uint8_t compute_dv_from_int(uint64_t body) nogil:
    """
    Calcula el dígito verificador de un RUT dado como entero (sin DV).
    Devuelve:
        - 0–9 para DV '0'–'9'
        - 10 para DV 'K'
    """
    cdef uint64_t n = body
    cdef int total = 0
    cdef int mul = 2
    cdef int digit

    # Recorrer dígitos de derecha a izquierda
    while n > 0:
        digit = <int>(n % 10)
        total += digit * mul
        mul = mul + 1 if mul < 7 else 2
        n //= 10

    cdef int m = 11 - (total % 11)
    if m == 11:
        return 0    # equivale a '0'
    elif m == 10:
        return 10   # equivale a 'K'
    else:
        return m

cdef inline str _verification_digit_from_int(int dv):
    cdef char dv_char
    if dv == 11:
        dv_char = b'0'
    elif dv == 10:
        dv_char = b'K'
    else:
        dv_char = <char>(dv + 0)  # 48 == ord('0')


    return PyUnicode_FromStringAndSize(&dv_char, 1)


cpdef str verification_digit(rut):
    """
    Devuelve el dígito verificador:
        - 0..9 para '0'..'9'
        - 10 para 'K'
    Acepta `rut` como str (sin DV) o como int (sin DV).
    """
    cdef char *data
    cdef Py_ssize_t length
    cdef int dv
    cdef bytes b

    if isinstance(rut, str):
        # 1) codifica a bytes y extrae buffer + longitud
        b = rut.encode('utf-8')
        if PyBytes_AsStringAndSize(b, &data, &length) != 0:
            raise ValueError("Error al codificar RUT a bytes")
        # 2) calcula DV sobre la cadena
        dv = compute_dv(data, <size_t>length)

        return _verification_digit_from_int(dv)

    elif isinstance(rut, int):
        # 3) convierte el entero a uint64_t y calcula DV
        dv = compute_dv_from_int(<uint64_t>rut)

        return _verification_digit_from_int(dv)

    else:
        raise TypeError(f"Tipo no válido: {type(rut).__name__}")


cdef inline char compute_dv(char *s, size_t body_len) nogil:
    cdef uint16_t total = 0
    cdef uint16_t m
    cdef int mul = 2
    cdef size_t i = body_len
    # recorrer de derecha a izquierda sin usar range
    while i > 0:
        i -= 1
        total += (s[i] - 48) * mul  # '0' -> 48
        if mul < 7:
            mul += 1
        else:
            mul = 2
    m = 11 - (total % 11)
    if m == 11:
        return <char>48  # '0'
    elif m == 10:
        return <char>75  # 'K'
    else:
        return <char>(48 + m)

cdef inline char* clean_rut(char* src) :
    cdef char *dst = src
    cdef char c
    while True:
        c = src[0]
        if c == b'\0':
            break
        src += 1
        if c >= b'0' and c <= b'9':
            dst[0] = c
            dst += 1
        elif c == b'K' or c == b'k':
            dst[0] = b'K'
            dst += 1
        elif c == b'.' or c == b'-' or c == b' ':
            # ignorar separadores
            continue
        else:
            return b''

    dst[0] = b'\0'

    return dst

cdef bint _validate_rut(char *s):
    cdef char *src = s
    cdef char *dst = clean_rut(s)

    if dst == b'':
        return False
    # Longitud mínima: al menos un dígito + DV
    cdef size_t length = <size_t>(dst - s)
    if length < 2:
        return False

    # Validación del dígito verificador
    cdef char expected = compute_dv(s, length - 1)
    return s[length - 1] == expected

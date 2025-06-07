# cython: language_level=3, boundscheck=False, wraparound=False, infer_types=True


from libc.stdint cimport uint16_t
from libc.stddef cimport size_t
from libc.stdlib cimport malloc, free
from cpython.bytes cimport PyBytes_AsString
from libc.stdlib cimport free
from cpython.unicode cimport PyUnicode_FromStringAndSize, PyUnicode_AsUTF8String
from libc.string cimport strlen
from cpython.list cimport PyList_GET_SIZE


from cpython.list cimport PyList_GET_SIZE




cdef inline char* encode(str r) noexcept:
    cdef:
        bytes b = PyUnicode_AsUTF8String(r)
        char *data = PyBytes_AsString(b)
    return data

cpdef bint validate_rut(str input_rut, bint suspicious=False):
    """
    Valida un solo RUT (str) y devuelve True/False.
    """
    cdef char* data = encode(input_rut)
    cdef bint result = _validate_rut(data, suspicious)
    
    return result


cpdef list validate_list_ruts(list ruts, bint suspicious=False):
    """
    Valida una lista de RUTs (list) y devuelve una lista de True/False.
    """
    cdef:
        Py_ssize_t len_list = PyList_GET_SIZE(ruts)
        bint is_valid

    for i in range(len_list):

        rut = encode(ruts[i])
        is_valid = _validate_rut(rut, suspicious)
        if not is_valid:
            ruts[i] = False

    return ruts

cpdef validate_rut_string(str v, bint suspicious=False):
    cdef:
        char* data = encode(v)
        bint result = _validate_rut(data, suspicious)
    if result:
        return v
    else:
        raise ValueError("Invalid RUT")


cpdef str format_rut(str rut, bint dots=True, bint uppercase=True, bint ignore_invalid=False):
    """
    Formatea un RUT (str) con puntos y guión.
    """
    cdef char *data = encode(rut)
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
    cdef size_t len_rut = strlen(rut)
    # ——————————————
    # 1) Primer pase: contar dígitos + capturar DV
    # ——————————————
    for i in range(len_rut):
        c = p[i]
        if '0' <= c <= '9' or c == 'K' or c == 'k':
            dv_char = c
            total_valid += 1
        elif c == '.' or c == '-' or c == ' ':
            continue
        else:
            if not ignore_invalid:
                return NULL

    if total_valid < 2:
        return b''

    body_len = total_valid - 1

    if dots:
        ndots = (body_len - 1) // 3

    # body_len dígitos + ndots puntos + '-' + DV + '\0'
    out_len = body_len + ndots + 3

    out = <char*> malloc(out_len)
    if not out:
        return b""

    # ——————————————
    # 3) Segundo pase: construir la cadena formateada
    # ——————————————
    dst = out
    total_valid = 0  # reusar como contador de dígitos emitidos

    for i in range(len_rut):
        c = p[i]
        if '0' <= c <= '9' or c == 'K' or c == 'k':
            if total_valid < body_len:
                # insertar punto si corresponde
                if dots and total_valid > 0 and ((body_len - total_valid) % 3) == 0:
                    dst[0] = '.'; dst += 1
                if c == 'K' or c == 'k':
                    if uppercase:
                        dst[0] = 'K'
                    else:
                        dst[0] = 'k'
                else:
                    dst[0] = c
                dst += 1

            total_valid += 1


    dst[0] = '-';
    dst += 1;
    if dv_char == 'K' or dv_char == 'k':
        if uppercase:
            dst[0] = 'K'
        else:
            dst[0] = 'k'
    else:
        dst[0] = dv_char

    dst += 1;
    dst[0] = '\0';

    return out


cdef inline int compute_dv_from_int(int body) nogil:
    """
    Calcula el dígito verificador de un RUT dado como entero (sin DV).
    Devuelve:
        - 0–9 para DV '0'–'9'
        - 10 para DV 'K'
    """
    cdef int n = body
    cdef int total = 0
    cdef int mul = 2
    cdef int digit

    # Recorrer dígitos de derecha a izquierda
    while n > 0:
        digit = (n % 10)
        total += digit * mul
        mul = mul + 1 if mul < 7 else 2
        n //= 10

    cdef int m = 11 - (total % 11)
    if m == 11:
        return 0    # equivale a '0'
    elif m == 10:
        return 10   # equivale a 'K'
    else:
        return 48 + m

cdef inline str _verification_digit_from_int(int dv):
    cdef char dv_char
    if dv == 11:

        return '0'
    elif dv == 10:
        return 'K'
    elif dv == 0:
        return '0'
    else:
        dv_char = <char>(dv)
        return PyUnicode_FromStringAndSize(&dv_char, 1)


cpdef str verification_digit(rut):
    """
    Devuelve el dígito verificador:
        - 0..9 para '0'..'9'
        - 10 para 'K'
    Acepta `rut` como str (sin DV) o como int (sin DV).
    """

    cdef char *data
    cdef int dv
    cdef char *b
    cdef char dv_char

    cdef char cleaned[99]
    cdef size_t length
    if isinstance(rut, str):
        # 1) codifica a bytes y extrae buffer + longitud
        b = encode(rut)
        clean_rut(b, cleaned)
        if cleaned[0] == b'\0':
            raise ValueError("RUT inválido")

        # Longitud del RUT limpio
        length = strlen(cleaned)
        if length < 1:
            raise ValueError("RUT inválido")


        dv_char = compute_dv(b)
        return PyUnicode_FromStringAndSize(&dv_char, 1)

    elif isinstance(rut, int):
        dv = compute_dv_from_int(rut)
        return _verification_digit_from_int(dv)

    else:
        raise TypeError(f"Tipo no válido: {type(rut).__name__}")

cdef inline char compute_dv(char *s) noexcept nogil:
    cdef int total = 0
    cdef uint16_t m
    cdef int mul = 2
    cdef size_t i = strlen(s)
    while i > 0:
        i -= 1
        total += (s[i] - 48) * mul  # '0' == 48
        if mul < 7:
            mul += 1
        else:
            mul = 2

    m = 11 - (total % 11)
    if m == 11:
        return b'0'
    elif m == 10:
        return <char>75
    else:
        return <char>(m + 48)

cdef inline void clean_rut(const char* src, char* dst) noexcept nogil:
    cdef char c
    cdef int points = 0
    cdef int g = 0
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
        elif c == b'.':

            if points > 1:
                # más de un punto, limpiar salida
                dst[0] = b'\0'
                return
            points += 1
        elif c == b'-':

            if g > 1:
                # más de un guión, limpiar salida
                dst[0] = b'\0'
                return
            g += 1
        elif c == b' ':
            # espacio en blanco, ignorar
            continue
        else:
            # carácter inválido, limpiar salida
            dst[0] = b'\0'
            return
    dst[0] = b'\0'


cdef inline bint is_suspicious(char* s) noexcept nogil:
    """
    Devuelve True si todos los caracteres en s (hasta '\0')
    son iguales entre sí. Si la cadena está vacía (s[0] == '\0'),
    se considera que cumple (devuelve True).
    """
    cdef char first = s[0]
    cdef char c

    # Si la cadena está vacía, asumimos que "todos los caracteres son iguales"
    if first == b'\0':
        return True

    # Avanzamos un puntero para comparar el resto
    s += 1
    while True:
        c = s[0]
        if c == b'\0':
            break
        if c != first:
            return False
        s += 1

    return True



cdef bint _validate_rut(char *s, bint suspicious) :
    cdef const char *src = s
    cdef char cleaned[50]  # Buffer de salida, tamaño suficiente para un RUT
    cdef bint valid = True
    cdef char dv
    clean_rut(src, cleaned)

    # Verifica si el resultado quedó vacío (fallo por carácter inválido)
    if cleaned[0] == b'\0':
        return False

    # Longitud del RUT limpio
    cdef size_t length = strlen(cleaned)
    if length < 1:
        return False
    dv = <char>(cleaned[length - 1])
    cleaned[length-1] = '\0'
    if suspicious:
        valid = is_suspicious(cleaned)
        if valid:
            return False

    cdef char expected = compute_dv(cleaned)


    return dv == expected

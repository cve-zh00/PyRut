import pytest
import pyrut
from pyrut.types import Rut, RutNotSuspicious
from pydantic import ValidationError


class TestValidateRut:
    """Tests for validate_rut function"""

    def test_valid_ruts(self):
        """Test with valid RUTs in different formats"""
        valid_ruts = [
            "11.111.111-1",
            "11111111-1",
            "111111111",
            "12.345.678-5",
            "12345678-5",
            "123456785",
        ]

        for rut in valid_ruts:
            assert pyrut.validate_rut(rut), f"RUT {rut} should be valid"

    def test_invalid_ruts(self):
        """Test with invalid RUTs"""
        invalid_ruts = [
            "11.111.111-2",  # Wrong check digit
            "12.345.678-6",  # Wrong check digit
            "7.654.321-J",   # Invalid check digit
            "123456789",     # Wrong length
            "1234567",       # Too short
            "12345678901",   # Too long
            "",              # Empty string
            "abcdefgh-i",    # Non-numeric body
            "12.34x.678-5",  # Invalid character in body
            "12345678-Z",    # Invalid check digit
            "12..345.678-5", # Double dot
        ]

        for rut in invalid_ruts:
            assert not pyrut.validate_rut(rut), f"RUT {rut} should be invalid"

    def test_suspicious_ruts(self):
        """Test suspicious RUTs (all same digits)"""
        suspicious_ruts = [
            "11111111-1",
            "22222222-2",
            "33333333-3",
            "44444444-4",
            "55555555-5",
            "66666666-6",
            "77777777-7",
            "88888888-8",
            "99999999-9"
        ]

        # Without suspicious flag, they should be valid
        for rut in suspicious_ruts:
            assert pyrut.validate_rut(rut, suspicious=False)

        # With suspicious flag, they should be invalid
        for rut in suspicious_ruts:
            assert not pyrut.validate_rut(rut, suspicious=True)

    def test_edge_cases(self):
        """Test edge cases"""
        # Minimum valid RUT
        assert pyrut.validate_rut("1-9")

        # RUT with spaces
        assert pyrut.validate_rut(" 12.345.678-5 ")

        # Mixed case K
        assert pyrut.validate_rut("7654321k") == pyrut.validate_rut("7654321K")


class TestFormatRut:
    """Tests for format_rut function"""

    def test_format_with_dots(self):
        """Test formatting with dots enabled"""
        test_cases = [
            ("12345678-5", "12.345.678-5"),
            ("123456785", "12.345.678-5"),
            ("7654321K", "7.654.321-K"),
            ("7654321k", "7.654.321-K"),
            ("1234567-0", "1.234.567-0"),
            ("12345-6", "12.345-6"),
            ("123-4", "123-4"),
            ("12-3", "12-3"),
            ("1-9", "1-9")
        ]

        for input_rut, expected in test_cases:
            result = pyrut.format_rut(input_rut, dots=True, uppercase=True)
            assert result == expected, f"Format {input_rut} -> expected {expected}, got {result}"

    def test_format_without_dots(self):
        """Test formatting without dots"""
        test_cases = [
            ("12.345.678-5", "12345678-5"),
            ("123456785", "12345678-5"),
            ("7.654.321-K", "7654321-K"),
            ("7654321k", "7654321-K")
        ]

        for input_rut, expected in test_cases:
            result = pyrut.format_rut(input_rut, dots=False, uppercase=True)
            assert result == expected, f"Format {input_rut} -> expected {expected}, got {result}"

    def test_format_lowercase(self):
        """Test formatting with lowercase K"""
        test_cases = [
            ("7654321K", "7.654.321-k"),
            ("7654321k", "7.654.321-k"),
            ("7.654.321-K", "7.654.321-k")
        ]

        for input_rut, expected in test_cases:
            result = pyrut.format_rut(input_rut, dots=True, uppercase=False)
            assert result == expected, f"Format {input_rut} -> expected {expected}, got {result}"

    def test_format_combinations(self):
        """Test all combinations of formatting options"""
        input_rut = "7654321k"

        # dots=True, uppercase=True
        assert pyrut.format_rut(input_rut, dots=True, uppercase=True) == "7.654.321-K"

        # dots=True, uppercase=False
        assert pyrut.format_rut(input_rut, dots=True, uppercase=False) == "7.654.321-k"

        # dots=False, uppercase=True
        assert pyrut.format_rut(input_rut, dots=False, uppercase=True) == "7654321-K"

        # dots=False, uppercase=False
        assert pyrut.format_rut(input_rut, dots=False, uppercase=False) == "7654321-k"

    


class TestVerificationDigit:
    """Tests for verification_digit function"""

    def test_verification_digit_string(self):
        """Test verification digit calculation with string input"""
        test_cases = [
            ("12345678", "5"),
            ("11111111", "1"),
            ("7654321", "6"),
            ("1234567", "4"),
            ("9999999", "3"),
            ("1", "9"),
            ("12", "4"),
            ("123", "6")
        ]

        for rut_body, expected_dv in test_cases:
            result = pyrut.verification_digit(rut_body)
            assert result == expected_dv, f"VD for {rut_body} -> expected {expected_dv}, got {result}"

    def test_verification_digit_int(self):
        """Test verification digit calculation with integer input"""
        test_cases = [
            (12345678, "5"),
            (11111111, "1"),
            (7654321, "6"),
            (1234567, "4"),
            (9999999, "3"),
            (1, "9"),
            (12, "4"),
            (123, "6")
        ]

        for rut_body, expected_dv in test_cases:
            result = pyrut.verification_digit(rut_body)
            assert result == expected_dv, f"VD for {rut_body} -> expected {expected_dv}, got {result}"

    def test_verification_digit_edge_cases(self):
        """Test edge cases for verification digit"""
        # Test with very large numbers
        large_num = 999999999
        dv = pyrut.verification_digit(large_num)
        assert isinstance(dv, str)
        assert dv in "0123456789K"

        # Test with zero
        assert pyrut.verification_digit(0) in "0123456789K"

    def test_verification_digit_invalid_input(self):
        """Test verification digit with invalid input types"""
        invalid_inputs = [
            [],
            {},
            None,
            3.14,
            "abc"
        ]

        for invalid_input in invalid_inputs:
            with pytest.raises((TypeError, ValueError)):
                pyrut.verification_digit(invalid_input)


class TestPydanticTypes:
    """Tests for Pydantic type annotations"""

    def test_rut_type_valid(self):
        """Test Rut type with valid RUTs"""
        from pydantic import BaseModel

        class TestModel(BaseModel):
            rut: Rut

        valid_ruts = [
            "11.111.111-1",
            "12345678-5",
            "7654321-6"
        ]

        for rut in valid_ruts:
            model = TestModel(rut=rut)
            assert model.rut == rut

    def test_rut_type_invalid(self):
        """Test Rut type with invalid RUTs"""
        from pydantic import BaseModel

        class TestModel(BaseModel):
            rut: Rut

        invalid_ruts = [
            "11.111.111-2",
            "invalid-rut",
            "12345678-Z"
        ]

        for rut in invalid_ruts:
            with pytest.raises(ValidationError):
                TestModel(rut=rut)

    def test_rut_not_suspicious_type(self):
        """Test RutNotSuspicious type"""
        from pydantic import BaseModel

        class TestModel(BaseModel):
            rut: RutNotSuspicious

        # Valid non-suspicious RUT should work
        model = TestModel(rut="12.345.678-5")
        assert model.rut == "12.345.678-5"

        # Suspicious RUT should fail
        with pytest.raises(ValidationError):
            TestModel(rut="11.111.111-1")


class TestIntegration:
    """Integration tests combining multiple functions"""

    def test_format_and_validate_cycle(self):
        """Test that formatted RUTs are still valid"""
        test_ruts = [
            "12345678-5",
            "76543216",
            "1234567-4"
        ]

        for rut in test_ruts:
            # Format the RUT
            formatted = pyrut.format_rut(rut, dots=True, uppercase=True)
            # Validate the formatted RUT
            assert pyrut.validate_rut(formatted), f"Formatted RUT {formatted} should be valid"

    def test_verification_digit_integration(self):
        """Test that calculated verification digits make valid RUTs"""
        test_bodies = ["12345678", "7654321", "1234567"]

        for body in test_bodies:
            dv = pyrut.verification_digit(body)
            full_rut = f"{body}-{dv}"
            assert pyrut.validate_rut(full_rut), f"RUT {full_rut} with calculated DV should be valid"

    def test_clean_and_validate(self):
        """Test validation with various dirty inputs"""
        dirty_ruts = [
            "  12.345.678-5  ",
            "12 345 678-5",
            "12.345.678 - 5",
            "12-345-678-5"
        ]

        for dirty_rut in dirty_ruts:
            # Should either validate or fail gracefully
            result = pyrut.validate_rut(dirty_rut)
            assert isinstance(result, bool)


class TestPerformance:
    """Performance and stress tests"""

    def test_validate_many_ruts(self):
        """Test validation of many RUTs"""
        # Generate test RUTs
        test_ruts = []
        for i in range(1000000, 1001000):  # 1000 RUTs
            body = str(i)
            dv = pyrut.verification_digit(body)
            test_ruts.append(f"{body}-{dv}")

        # Validate all RUTs
        for rut in test_ruts:
            assert pyrut.validate_rut(rut), f"Generated RUT {rut} should be valid"

    def test_format_many_ruts(self):
        """Test formatting of many RUTs"""
        test_ruts = [f"1234567{i}-{pyrut.verification_digit(f'1234567{i}')}"
                    for i in range(10)]

        for rut in test_ruts:
            formatted = pyrut.format_rut(rut, dots=True, uppercase=True)
            assert isinstance(formatted, str)
            assert len(formatted) > len(rut.replace(".", ""))  # Should be longer due to dots

x = "8f7f3f167d4e10dfa4f6f0c7948e573c8fa2275af2e2435671f2ced0ee4e003f00"
y = "a904f1534f9837aa56ad2e6268b2ab48a628ee6a85ef9afc850827303eb74d47"

def le_hex_to_decimal(hex_string: str) -> int:
    """
    Convert little-endian hex string to decimal integer.
    
    Args:
        hex_string: Hex string in little-endian format (e.g., "86f70eacaf67c855a952d19d974d54b759d711957a1065037af7d8cfc148b2b800")
        
    Returns:
        Decimal integer value
    """
    # Remove any leading/trailing whitespace and ensure even length
    hex_string = hex_string.strip()
    if len(hex_string) % 2 != 0:
        raise ValueError("Hex string must have even length")
    
    # Convert hex to bytes and reverse for little-endian
    hex_bytes = bytes.fromhex(hex_string)
    le_bytes = hex_bytes[::-1]  # Reverse byte order
    
    # Convert to decimal
    return int.from_bytes(le_bytes, byteorder='big')

# Example usage
decimal_value = le_hex_to_decimal(x)
print(f"Little-endian hex: {x}")
print(f"Decimal value: {decimal_value}")

decimal_value = le_hex_to_decimal(y)
print(f"Little-endian hex: {y}")
print(f"Decimal value: {decimal_value}")
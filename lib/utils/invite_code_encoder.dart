import 'dart:convert';

/// Utility class for encoding and decoding invite codes
/// Uses JSON -> Base64 -> XOR obfuscation -> Base62 encoding for security and compactness
class InviteCodeEncoder {
  // Secret key for XOR obfuscation (in production, use a more secure key)
  static const String _secretKey = 'org_wallet_2024_secure_invite_key';
  
  // Base62 alphabet (0-9, a-z, A-Z) for compact encoding
  static const String _base62Chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Encode organization invite data into a short, secure code
  /// 
  /// Parameters:
  /// - [orgId]: Organization ID
  /// - [orgName]: Organization name (for display in code)
  /// - [role]: Role for the invite (default: 'member')
  /// 
  /// Returns: A short encoded string in format "OrgName/ShortCode" (< 12 chars for code part)
  static String encodeInviteCode({
    required String orgId,
    required String orgName,
    String role = 'member',
  }) {
    try {
      // Map role to single character code
      final roleChar = _roleToChar(role);
      
      // Combine orgId with role character
      final combined = '$orgId|$roleChar';
      
      // Apply XOR obfuscation directly on bytes
      final orgBytes = utf8.encode(combined);
      final obfuscatedBytes = _xorEncryptBytes(orgBytes, utf8.encode(_secretKey));
      
      // Convert directly to base62 (much shorter than base64)
      final base62Code = _bytesToBase62(obfuscatedBytes);
      
      // Format as OrgName/Code
      final sanitizedOrgName = _sanitizeOrgName(orgName);
      return '$sanitizedOrgName/$base62Code';
    } catch (e) {
      throw Exception('Failed to encode invite code: $e');
    }
  }

  /// Map role string to single character
  static String _roleToChar(String role) {
    switch (role.toLowerCase()) {
      case 'president': return 'P';
      case 'treasurer': return 'T';
      case 'secretary': return 'S';
      case 'auditor': return 'A';
      case 'moderator': return 'M';
      case 'member': return 'm';
      default: return 'm';
    }
  }

  /// Map character back to role string
  static String _charToRole(String char) {
    switch (char) {
      case 'P': return 'president';
      case 'T': return 'treasurer';
      case 'S': return 'secretary';
      case 'A': return 'auditor';
      case 'M': return 'moderator';
      case 'm': return 'member';
      default: return 'member';
    }
  }

  /// Sanitize org name for use in invite code (alphanumeric + underscore, max 20 chars)
  static String _sanitizeOrgName(String name) {
    // Remove special characters, keep alphanumeric and spaces
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
    // Replace spaces with underscores and limit length
    final sanitized = cleaned.replaceAll(' ', '_').substring(0, cleaned.length > 20 ? 20 : cleaned.length);
    return sanitized.isEmpty ? 'Org' : sanitized;
  }

  /// Decode invite code back to organization data
  /// 
  /// Parameters:
  /// - [code]: The encoded invite code string in format "OrgName/Code"
  /// 
  /// Returns: Map containing 'orgId' and 'role', or null if invalid
  static Map<String, dynamic>? decodeInviteCode(String code) {
    try {
      if (code.isEmpty) return null;
      
      // Split by '/' to get orgName and code parts
      final parts = code.split('/');
      if (parts.length != 2) {
        // Try old format (just code) for backward compatibility
        return _decodeCodeOnly(code);
      }
      
      final codePart = parts[1].trim();
      if (codePart.isEmpty) return null;
      
      // Convert from base62 back to bytes
      final obfuscatedBytes = _base62ToBytes(codePart);
      
      // Reverse XOR obfuscation
      final decryptedBytes = _xorEncryptBytes(obfuscatedBytes, utf8.encode(_secretKey));
      final decrypted = utf8.decode(decryptedBytes);
      
      // Split by '|' to get orgId and role char
      final dataParts = decrypted.split('|');
      if (dataParts.length != 2) return null;
      
      final orgId = dataParts[0];
      final roleChar = dataParts[1];
      final role = _charToRole(roleChar);
      
      return {
        'orgId': orgId,
        'role': role,
      };
    } catch (e) {
      // Return null for invalid codes (don't expose error details)
      return null;
    }
  }

  /// Decode code-only format (for backward compatibility)
  static Map<String, dynamic>? _decodeCodeOnly(String code) {
    try {
      // Try old JSON-based format
      final obfuscated = _fromBase62(code);
      final base64Encoded = _xorDecrypt(obfuscated, _secretKey);
      final jsonBytes = base64Decode(base64Encoded);
      final jsonString = utf8.decode(jsonBytes);
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final orgId = payload['id'] as String? ?? payload['orgId'] as String?;
      final role = payload['r'] as String? ?? payload['role'] as String? ?? 'member';
      
      if (orgId == null) return null;
      
      return {
        'orgId': orgId,
        'role': role,
      };
    } catch (e) {
      return null;
    }
  }

  /// XOR encryption on bytes (more efficient)
  static List<int> _xorEncryptBytes(List<int> data, List<int> key) {
    final result = <int>[];
    for (int i = 0; i < data.length; i++) {
      result.add(data[i] ^ key[i % key.length]);
    }
    return result;
  }

  /// XOR encryption (simple obfuscation, not true encryption) - for backward compatibility
  static String _xorEncrypt(String data, String key) {
    final result = StringBuffer();
    for (int i = 0; i < data.length; i++) {
      final dataChar = data.codeUnitAt(i);
      final keyChar = key.codeUnitAt(i % key.length);
      final encryptedChar = dataChar ^ keyChar;
      result.writeCharCode(encryptedChar);
    }
    return result.toString();
  }

  /// XOR decryption (reverse of encryption)
  static String _xorDecrypt(String data, String key) {
    return _xorEncrypt(data, key); // XOR is symmetric
  }

  /// Convert bytes directly to base62 (more efficient)
  static String _bytesToBase62(List<int> bytes) {
    if (bytes.isEmpty) return '';
    
    // Convert bytes to big integer (represent as base-256 number)
    BigInt number = BigInt.zero;
    for (final byte in bytes) {
      number = number * BigInt.from(256) + BigInt.from(byte);
    }
    
    // Convert to base62
    if (number == BigInt.zero) return _base62Chars[0];
    
    final result = StringBuffer();
    while (number > BigInt.zero) {
      result.write(_base62Chars[(number % BigInt.from(62)).toInt()]);
      number = number ~/ BigInt.from(62);
    }
    
    // Reverse to get correct order
    return result.toString().split('').reversed.join();
  }

  /// Convert from base62 back to bytes
  static List<int> _base62ToBytes(String input) {
    if (input.isEmpty) return [];
    
    // Convert from base62 to big integer
    BigInt number = BigInt.zero;
    for (int i = 0; i < input.length; i++) {
      final charIndex = _base62Chars.indexOf(input[i]);
      if (charIndex == -1) {
        throw FormatException('Invalid base62 character: ${input[i]}');
      }
      number = number * BigInt.from(62) + BigInt.from(charIndex);
    }
    
    // Convert big integer to bytes
    final bytes = <int>[];
    if (number == BigInt.zero) {
      bytes.add(0);
    } else {
      while (number > BigInt.zero) {
        bytes.add((number % BigInt.from(256)).toInt());
        number = number ~/ BigInt.from(256);
      }
      // Reverse the bytes list
      for (int i = 0; i < bytes.length ~/ 2; i++) {
        final temp = bytes[i];
        bytes[i] = bytes[bytes.length - 1 - i];
        bytes[bytes.length - 1 - i] = temp;
      }
    }
    
    return bytes;
  }

  /// Convert from base62 back to string (for backward compatibility)
  static String _fromBase62(String input) {
    final bytes = _base62ToBytes(input);
    return utf8.decode(bytes);
  }
}

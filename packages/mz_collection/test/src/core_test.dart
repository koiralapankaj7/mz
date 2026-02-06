import 'package:mz_collection/src/core.dart';
import 'package:test/test.dart';

void main() {
  group('Tristate', () {
    test('should have correct values', () {
      expect(Tristate.values, hasLength(3));
      expect(Tristate.yes, isNotNull);
      expect(Tristate.no, isNotNull);
      expect(Tristate.toggle, isNotNull);
    });
  });

  group('TriStateX.resolve', () {
    test('should return true for yes', () {
      expect(Tristate.yes.resolve(false), isTrue);
      expect(Tristate.yes.resolve(true), isTrue);
      expect(Tristate.yes.resolve(null), isTrue);
    });

    test('should return false for no', () {
      expect(Tristate.no.resolve(true), isFalse);
      expect(Tristate.no.resolve(false), isFalse);
      expect(Tristate.no.resolve(null), isFalse);
    });

    test('should invert the value for toggle', () {
      expect(Tristate.toggle.resolve(true), isFalse);
      expect(Tristate.toggle.resolve(false), isTrue);
      expect(Tristate.toggle.resolve(null), isTrue);
    });
  });

  group('TriStateBoolX.toTristate', () {
    test('should return Tristate.yes for true', () {
      const value = true;
      expect(value.toTristate, equals(Tristate.yes));
    });

    test('should return Tristate.no for false', () {
      const value = false;
      expect(value.toTristate, equals(Tristate.no));
    });

    test('should return Tristate.no for null', () {
      const bool? value = null;
      expect(value.toTristate, equals(Tristate.no));
    });
  });
}

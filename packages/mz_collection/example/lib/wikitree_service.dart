import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service for fetching family tree data from WikiTree API.
///
/// WikiTree is a free, collaborative genealogy website with
/// millions of profiles connected in a single tree.
class WikiTreeService {
  WikiTreeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://api.wikitree.com/api.php';
  static const _appId = 'MZCollectionExample';

  /// Fetches a person's profile by WikiTree ID.
  ///
  /// Example IDs:
  /// - "Churchill-4" (Winston Churchill)
  /// - "Windsor-1" (Queen Elizabeth II)
  /// - "Einstein-1" (Albert Einstein)
  /// - "Roosevelt-8" (Franklin D. Roosevelt)
  ///
  /// Throws [WikiTreeException] on error.
  Future<WikiTreePerson> getPerson(String wikiTreeId) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'getPerson',
        'key': wikiTreeId,
        'fields': _personFields,
        'appId': _appId,
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw WikiTreeException(
        'Network error. If running on web, try macOS/iOS/Android instead '
        '(CORS restriction).',
      );
    }

    if (response.statusCode != 200) {
      throw WikiTreeException('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    if (json.isEmpty) {
      throw WikiTreeException('Empty response');
    }

    final data = json[0] as Map<String, dynamic>;
    if (data['status'] != 0) {
      throw WikiTreeException('API error: status ${data['status']}');
    }

    final profile = data['person'] as Map<String, dynamic>?;
    if (profile == null) {
      throw WikiTreeException('Person not found: $wikiTreeId');
    }

    return WikiTreePerson.fromJson(profile);
  }

  /// Fetches relatives (parents, children, siblings, spouses) for a person.
  ///
  /// Throws [WikiTreeException] on error.
  Future<WikiTreeRelatives> getRelatives(String wikiTreeId) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'getRelatives',
        'keys': wikiTreeId,
        'getParents': '1',
        'getChildren': '1',
        'getSiblings': '1',
        'getSpouses': '1',
        'fields': _personFields,
        'appId': _appId,
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw WikiTreeException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw WikiTreeException('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    if (json.isEmpty) {
      throw WikiTreeException('Empty response');
    }

    final data = json[0] as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw WikiTreeException('No items in response');
    }

    final personData = items[0] as Map<String, dynamic>;
    final person = personData['person'] as Map<String, dynamic>?;
    if (person == null) {
      throw WikiTreeException('Person data not found');
    }

    return WikiTreeRelatives.fromJson(person);
  }

  /// Searches for people by name.
  Future<List<WikiTreePerson>> searchPeople(String query) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'action': 'searchPerson',
          'Query': query,
          'fields': _personFields,
          'appId': _appId,
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        return [];
      }

      final json = jsonDecode(response.body) as List<dynamic>;
      if (json.isEmpty) return [];

      final results = <WikiTreePerson>[];
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          final person = WikiTreePerson.fromJson(item);
          if (person.id.isNotEmpty) {
            results.add(person);
          }
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }

  static const _personFields = 'Id,Name,FirstName,MiddleName,LastNameAtBirth,'
      'LastNameCurrent,Nicknames,BirthDate,DeathDate,BirthLocation,'
      'DeathLocation,Gender,Photo,Father,Mother';
}

/// A person from WikiTree.
class WikiTreePerson {
  const WikiTreePerson({
    required this.id,
    required this.wikiTreeId,
    required this.firstName,
    required this.lastName,
    this.lastNameAtBirth,
    this.middleName,
    this.nicknames,
    this.birthDate,
    this.deathDate,
    this.birthLocation,
    this.deathLocation,
    this.gender,
    this.photoUrl,
    this.fatherId,
    this.motherId,
  });

  factory WikiTreePerson.fromJson(Map<String, dynamic> json) {
    return WikiTreePerson(
      id: (json['Id'] ?? 0).toString(),
      wikiTreeId: json['Name']?.toString() ?? '',
      firstName: json['FirstName']?.toString() ?? '',
      lastName: json['LastNameCurrent']?.toString() ??
          json['LastNameAtBirth']?.toString() ??
          '',
      lastNameAtBirth: json['LastNameAtBirth']?.toString(),
      middleName: json['MiddleName']?.toString(),
      nicknames: json['Nicknames']?.toString(),
      birthDate: json['BirthDate']?.toString(),
      deathDate: json['DeathDate']?.toString(),
      birthLocation: json['BirthLocation']?.toString(),
      deathLocation: json['DeathLocation']?.toString(),
      gender: _parseGender(json['Gender']?.toString()),
      photoUrl: json['Photo']?.toString(),
      fatherId: json['Father']?.toString(),
      motherId: json['Mother']?.toString(),
    );
  }

  final String id;
  final String wikiTreeId;
  final String firstName;
  final String lastName;
  final String? lastNameAtBirth;
  final String? middleName;
  final String? nicknames;
  final String? birthDate;
  final String? deathDate;
  final String? birthLocation;
  final String? deathLocation;
  final WikiTreeGender? gender;
  final String? photoUrl;
  final String? fatherId;
  final String? motherId;

  String get fullName {
    if (middleName != null && middleName!.isNotEmpty) {
      return '$firstName $middleName $lastName';
    }
    return '$firstName $lastName';
  }

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '?';
    final last = lastName.isNotEmpty ? lastName[0] : '?';
    return '$first$last';
  }

  int? get birthYear => _extractYear(birthDate);
  int? get deathYear => _extractYear(deathDate);

  bool get hasParents => fatherId != null || motherId != null;

  static WikiTreeGender? _parseGender(String? value) {
    if (value == null) return null;
    if (value == 'Male') return WikiTreeGender.male;
    if (value == 'Female') return WikiTreeGender.female;
    return null;
  }

  static int? _extractYear(String? date) {
    if (date == null || date.isEmpty) return null;
    // WikiTree dates can be in various formats: "1879", "1879-03-14", etc.
    final match = RegExp(r'(\d{4})').firstMatch(date);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}

enum WikiTreeGender { male, female }

/// Relatives of a WikiTree person.
class WikiTreeRelatives {
  const WikiTreeRelatives({
    required this.person,
    required this.parents,
    required this.children,
    required this.siblings,
    required this.spouses,
  });

  factory WikiTreeRelatives.fromJson(Map<String, dynamic> json) {
    return WikiTreeRelatives(
      person: WikiTreePerson.fromJson(json),
      parents: _parseRelatives(json['Parents']),
      children: _parseRelatives(json['Children']),
      siblings: _parseRelatives(json['Siblings']),
      spouses: _parseRelatives(json['Spouses']),
    );
  }

  final WikiTreePerson person;
  final List<WikiTreePerson> parents;
  final List<WikiTreePerson> children;
  final List<WikiTreePerson> siblings;
  final List<WikiTreePerson> spouses;

  static List<WikiTreePerson> _parseRelatives(dynamic data) {
    if (data == null) return [];
    if (data is! Map) return [];

    final relatives = <WikiTreePerson>[];
    for (final value in (data as Map<String, dynamic>).values) {
      if (value is Map<String, dynamic>) {
        relatives.add(WikiTreePerson.fromJson(value));
      }
    }
    return relatives;
  }
}

/// Exception thrown when WikiTree API fails.
class WikiTreeException implements Exception {
  WikiTreeException(this.message);

  final String message;

  @override
  String toString() => message;
}

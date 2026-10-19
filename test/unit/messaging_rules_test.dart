import 'package:flutter_test/flutter_test.dart';

import 'package:keel/models/app_user.dart';
import 'package:keel/models/messaging_rules.dart';

/// The permission model for messaging, in one place. These are the rules
/// `firestore.rules` repeats, so a change here is a change there.
void main() {
  group('ranking', () {
    test('developer is below lead, which is below manager', () {
      expect(UserRole.developer.rank, lessThan(UserRole.lead.rank));
      expect(UserRole.lead.rank, lessThan(UserRole.manager.rank));
    });

    test('a role outranks only the roles strictly below it', () {
      expect(UserRole.manager.outranks(UserRole.lead), isTrue);
      expect(UserRole.manager.outranks(UserRole.developer), isTrue);
      expect(UserRole.lead.outranks(UserRole.developer), isTrue);

      expect(UserRole.lead.outranks(UserRole.manager), isFalse);
      expect(UserRole.developer.outranks(UserRole.lead), isFalse);
      for (final role in UserRole.values) {
        expect(role.outranks(role), isFalse);
      }
    });
  });

  group('creating a group and adding people', () {
    test('leads and managers can', () {
      expect(MessagingRules.canCreateGroup(UserRole.manager), isTrue);
      expect(MessagingRules.canCreateGroup(UserRole.lead), isTrue);
      expect(MessagingRules.canAddMembers(UserRole.manager), isTrue);
      expect(MessagingRules.canAddMembers(UserRole.lead), isTrue);
    });

    test('developers cannot', () {
      expect(MessagingRules.canCreateGroup(UserRole.developer), isFalse);
      expect(MessagingRules.canAddMembers(UserRole.developer), isFalse);
    });
  });

  group('removing somebody from a group', () {
    bool canRemove(UserRole actor, UserRole target) {
      return MessagingRules.canRemove(
        actorId: 'actor',
        actorRole: actor,
        targetId: 'target',
        targetRole: target,
      );
    }

    test('a manager can remove a lead or a developer', () {
      expect(canRemove(UserRole.manager, UserRole.lead), isTrue);
      expect(canRemove(UserRole.manager, UserRole.developer), isTrue);
    });

    test('a lead can remove a developer', () {
      expect(canRemove(UserRole.lead, UserRole.developer), isTrue);
    });

    test('a lead cannot remove a manager', () {
      expect(canRemove(UserRole.lead, UserRole.manager), isFalse);
    });

    test('people of the same rank cannot remove each other', () {
      expect(canRemove(UserRole.manager, UserRole.manager), isFalse);
      expect(canRemove(UserRole.lead, UserRole.lead), isFalse);
      expect(canRemove(UserRole.developer, UserRole.developer), isFalse);
    });

    test('a developer cannot remove anybody else', () {
      for (final target in UserRole.values) {
        expect(canRemove(UserRole.developer, target), isFalse);
      }
    });

    test('anybody can remove themselves', () {
      for (final role in UserRole.values) {
        expect(
          MessagingRules.canRemove(
            actorId: 'me',
            actorRole: role,
            targetId: 'me',
            targetRole: role,
          ),
          isTrue,
        );
      }
    });
  });

  group('what may be sent', () {
    test('a blank message is refused, whitespace included', () {
      expect(MessagingRules.problemWithMessage(''), isNotNull);
      expect(MessagingRules.problemWithMessage('   \n '), isNotNull);
    });

    test('the limit counts trimmed characters', () {
      const limit = MessagingRules.maxMessageLength;

      expect(MessagingRules.problemWithMessage('a' * limit), isNull);
      expect(MessagingRules.problemWithMessage('  ${'a' * limit}  '), isNull);
      expect(MessagingRules.problemWithMessage('a' * (limit + 1)), isNotNull);
    });

    test('a group needs a name, and a short one', () {
      const limit = MessagingRules.maxGroupNameLength;

      expect(MessagingRules.problemWithGroupName('  '), isNotNull);
      expect(MessagingRules.problemWithGroupName('Ledger rebuild'), isNull);
      expect(MessagingRules.problemWithGroupName('a' * limit), isNull);
      expect(MessagingRules.problemWithGroupName('a' * (limit + 1)), isNotNull);
    });
  });
}

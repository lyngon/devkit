# A migration was edited after it ran

- **Date**: 2026-08-19
- **Caught in**: [fix(orders): restore the migration that production ran](https://github.com/example/shop/pull/212)

The agent changed a column type in a migration that production had already run, where it should have added a new migration.
The deploy failed on the checksum of the migration, and the change was reverted.

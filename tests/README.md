# TeleportFavorites Test Organization

This document explains the organization of tests, mocks, and fakes in the TeleportFavorites mod.

## Directory Structure

The tests are organized as follows:

```
tests/
├── mocks/          # Mock implementations for dependencies
├── fakes/          # Fake data and factories for testing
└── *_spec.lua      # Test files
```

## Test Files

All test files follow the naming convention `*_spec.lua` and are located in the root of the tests directory. 
The tests use the Busted framework (http://olivinelabs.com/busted/).

## Mocks vs Fakes

- **Mocks**: Used to simulate dependencies that the code under test relies on. Located in the `mocks/` directory.
- **Fakes**: Used to create test data, particularly for simulating single-player and multiplayer scenarios. Located in the `fakes/` directory.

## Consolidated Mocks

Instead of duplicating mock implementations across test files, we use consolidated mock files:

- `mocks/tag_editor_mocks.lua`: Contains all mocks needed for testing tag editor functionality
- `mocks/mock_cache.lua`: Mock implementation of the Cache module
- `mocks/mock_modules.lua`: General mock implementations for various modules
- `mocks/mock_player_data.lua`: Mock implementations for player-related data
- `mocks/mock_storage.lua`: Mock implementation of storage functionality

## Testing Strategy

1. **Unit Tests**: Test each function in isolation, mocking all dependencies.
2. **Integration Tests**: Test how components work together, with minimal mocking.
3. **Single Player vs Multiplayer**: Use the appropriate fake data factories to test both scenarios.

## Writing New Tests

When writing new tests:

1. Reuse existing mocks and fakes when possible
2. If new mocks are needed, add them to the appropriate consolidated mock file
3. Follow the existing patterns for test organization
4. Ensure tests run in both single-player and multiplayer scenarios if applicable

## Running Tests

Tests are run using the Busted framework. Use the following command:

```
busted -v
```

To run tests with coverage reporting:

```
busted -c -v
```

## Coverage Reports

Coverage reports are generated using LuaCov. The reports can be found in:

- `luacov.report.out`: Detailed coverage report
- `coverage_summary.md`: Summary of coverage statistics

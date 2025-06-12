# Test Organization Guidelines

## Location of Test Files

All test files should be placed in the `/tests` directory, not in the root of the project. This ensures:

1. **Organized Structure**: Clear separation between production code and test code
2. **Easy Test Discovery**: All tests in one location for better discoverability
3. **Simplified CI/CD**: Easier configuration of continuous integration/testing
4. **Clean Root Directory**: Prevent cluttering of the project root with non-essential files

## Naming Conventions

- All test files should follow the naming pattern `test_[module_name].lua`
- Test files should mirror the structure of the code they are testing
- For modules with multiple test files, use `test_[module_name]_[specific_feature].lua`

## Test File Organization Example

```
Project Root
├── tests/
│   ├── test_player_favorites.lua
│   ├── test_settings_integration.lua
│   ├── test_command_pattern.lua
│   ├── test_dispatcher.lua
│   ├── test_strategy_pattern.lua
│   └── core/
│       ├── cache/
│       │   └── test_cache.lua
│       └── utils/
│           └── test_helpers.lua
├── core/
│   ├── cache/
│   └── utils/
└── ...
```

## Migration Process

When moving test files from root to the tests directory:

1. Move the file to the appropriate location in the tests directory
2. Update any require paths within the file
3. Update any references to the test file in other files
4. Do not keep copies of test files in both locations

## Best Practices

- Tests should be independent and not rely on specific environment configurations
- Tests should clean up after themselves
- Use descriptive test names that explain what is being tested
- Group related tests within the same file
- Follow the same coding standards as the main codebase

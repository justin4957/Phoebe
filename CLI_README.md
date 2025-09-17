# Phoebe CLI - G-Expression Management Tool

A comprehensive command-line interface for working with G-expressions and the Phoebe API, built using inspiration from the `melas` validation components and `gexpression` construction utilities.

## Features

### ✅ Core Functionality
- **G-Expression Creation**: Create literals, references, vectors, applications, lambdas, and more
- **Validation**: Comprehensive validation using components adapted from melas project
- **API Integration**: Full CRUD operations with the Phoebe API
- **File Management**: Temporary and permanent file storage for expressions
- **Interactive REPL**: Build and test expressions interactively
- **Examples**: Rich set of example G-expressions for learning

### 🔧 Installation & Usage

#### Via Mix (Recommended)
```bash
# Show help
mix phoebe help

# Create G-expressions
mix phoebe create lit 42
mix phoebe create ref "x"
mix phoebe create lam "x,y" "ref(x)"

# Show examples
mix phoebe examples

# Interactive REPL
mix phoebe repl

# File operations
mix phoebe save myfile.json identity
mix phoebe load identity

# API operations (when server is running)
mix phoebe list
mix phoebe get identity
mix phoebe publish expression.json
```

#### Direct Executable
```bash
# Make executable
chmod +x bin/phoebe

# Use directly
./bin/phoebe help
./bin/phoebe examples
```

## Architecture

### Core Components

1. **Phoebe.CLI** - Main command parser and dispatcher
2. **Phoebe.CLI.ApiClient** - HTTP client for Phoebe API interactions
3. **Phoebe.CLI.Validator** - G-expression validation (adapted from melas)
4. **Phoebe.CLI.GExpressionBuilder** - Expression construction utilities (inspired by gexpression)
5. **Phoebe.CLI.FileManager** - Temporary and permanent file operations
6. **Phoebe.CLI.REPL** - Interactive expression building environment

### Integration Points

- **From melas**: Validation logic with comprehensive error reporting
- **From gexpression**: Construction patterns and expression building utilities
- **Phoebe API**: Full integration with G-expression repository

## Commands

### Expression Building
```bash
mix phoebe create lit <value>          # Literal values
mix phoebe create ref <name>           # Variable references
mix phoebe create vec <items...>       # Vectors
mix phoebe create app <fn> <args>      # Function applications
mix phoebe create lam <params> <body>  # Lambda functions
mix phoebe create fix <expr>           # Fixed-point combinators
```

### File Operations
```bash
mix phoebe temp list                   # List temporary files
mix phoebe temp clean                  # Clean old temp files
mix phoebe save <file> <name>          # Save file permanently
mix phoebe load <name>                 # Load saved file
```

### API Operations
```bash
mix phoebe list                        # List all expressions
mix phoebe get <name>                  # Get specific expression
mix phoebe publish <file>              # Publish expression
mix phoebe validate <file>             # Validate JSON file
```

### Interactive Mode
```bash
mix phoebe repl                        # Start interactive REPL
mix phoebe build                       # Interactive builder
```

## REPL Commands

The interactive REPL provides a rich environment for building G-expressions:

### Expression Building
- `lit <value>` - Create literals
- `ref <name>` - Create references
- `vec <items>` - Create vectors
- `app <fn> [args]` - Create applications
- `lam <params> <body>` - Create lambdas

### Variable Management
- `var <name>=` - Assign current expression to variable
- `vars` - List saved variables
- `show [var]` - Display current expression or variable

### File & API Operations
- `save <name>` - Save current expression
- `load <name>` - Load saved expression
- `list` - List API expressions
- `get <name>` - Get expression from API
- `publish <title>` - Publish current expression

### Analysis & Validation
- `validate` - Validate current expression
- `analyze` - Analyze expression structure
- `examples` - Show G-expression examples

## Example Usage

### Creating a Lambda Function
```bash
mix phoebe create lam "x,y" "app(ref(add), vec(ref(x), ref(y)))"
```

### Interactive Session
```bash
mix phoebe repl
phoebe> lit 42
phoebe> var answer=
phoebe> lam x $answer
phoebe> validate
phoebe> save my_function
phoebe> quit
```

### Working with Files
```bash
# Create and save
mix phoebe create lit 42 -o answer.json
mix phoebe validate answer.json
mix phoebe save answer.json my_answer

# Load and use
mix phoebe load my_answer
```

## G-Expression Types

The CLI supports all standard G-expression types:

- **lit** - Literal values (numbers, strings, booleans)
- **ref** - Variable references
- **vec** - Vectors/arrays of expressions
- **app** - Function applications
- **lam** - Lambda functions with parameters and body
- **fix** - Fixed-point combinator for recursion
- **match** - Pattern matching expressions

## Configuration

### Environment Variables
- `EDITOR` or `VISUAL` - Editor for interactive editing
- `PHOEBE_API_URL` - Override default API URL

### CLI Options
- `--base-url` - API base URL
- `--temp-dir` - Temporary files directory
- `--format` - Output format (json, pretty, compact)
- `--output` - Output file path

## Development Status

### ✅ Completed Features
- [x] Main CLI module with command parsing
- [x] API client with full HTTP support
- [x] G-expression validation from melas components
- [x] Expression construction utilities from gexpression patterns
- [x] Temporary file management with auto-cleanup
- [x] Permanent file storage with organized directories
- [x] Interactive REPL with rich command set
- [x] Comprehensive examples and help system

### 🔧 Known Issues
- HTTP client may have dependency issues in some environments
- Some warning messages from deprecated Elixir syntax (non-breaking)

### 🚀 Future Enhancements
- Syntax highlighting in REPL
- Expression visualization
- Batch operations
- Plugin system for custom G-expression types
- Integration with external editors

## Contributing

The CLI is designed to be modular and extensible. Key extension points:

1. Add new G-expression types in `GExpressionBuilder`
2. Extend validation rules in `Validator`
3. Add new REPL commands in `REPL`
4. Enhance file formats in `FileManager`

## Testing

Basic functionality can be tested with:

```bash
# Test examples (always works)
mix phoebe examples

# Test expression creation
mix phoebe create lit 42

# Test validation
echo '{"g": "lit", "v": 42}' > test.json
mix phoebe validate test.json

# Test REPL
mix phoebe repl
```

The CLI provides a complete toolkit for working with G-expressions, from simple command-line operations to complex interactive development workflows.
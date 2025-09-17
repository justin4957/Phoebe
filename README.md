# Phoebe

**Phoebe** is a minimal MVP package repository for user-submitted [JSON G-Expression](https://github.com/json-g/json_ge_lib) files and libraries. It provides both a REST API and web interface for publishing, discovering, and managing G-Expression packages.

## Features

- 🚀 **Unauthenticated Package Publishing** - Easy package submission without user registration
- 🔍 **Search & Discovery** - Find G-Expressions by name, title, or description
- 📦 **Version Management** - Semantic versioning support for package iterations
- ✅ **G-Expression Validation** - Comprehensive validation based on the JSON G-Expression specification
- 🌐 **REST API** - Full programmatic access for tooling and integrations
- 💻 **Web UI** - User-friendly interface built with Phoenix LiveView
- 📊 **Download Tracking** - Monitor package usage and popularity

## G-Expression Support

Phoebe validates and stores JSON G-Expressions with support for all core expression types:
- `lit` - Literal values
- `ref` - Variable references
- `app` - Function applications
- `vec` - Vectors/arrays
- `lam` - Lambda functions
- `fix` - Fixed-point combinator
- `match` - Pattern matching

## Quick Start

### Prerequisites

- Elixir 1.15+ with Phoenix 1.8
- PostgreSQL 9.4+ (for JSONB support)

### Setup

1. **Clone and setup the project:**
   ```bash
   git clone <repository-url>
   cd phoebe
   mix setup
   ```

2. **Start the development server:**
   ```bash
   mix phx.server
   ```

3. **Visit the application:**
   - Web UI: http://localhost:4000
   - API: http://localhost:4000/api/v1

### Sample Data

The application comes with sample G-Expressions. To reset and reseed:

```bash
mix ecto.reset
```

## REST API

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/expressions` | List all G-Expressions (supports `?search=term`) |
| `POST` | `/api/v1/expressions` | Create new G-Expression |
| `GET` | `/api/v1/expressions/:name` | Get specific G-Expression with versions |
| `POST` | `/api/v1/expressions/:name/versions` | Add new version to G-Expression |
| `GET` | `/api/v1/expressions/:name/versions/:version` | Get specific version |

### Creating a G-Expression

```bash
curl -X POST http://localhost:4000/api/v1/expressions \
  -H "Content-Type: application/json" \
  -d '{
    "g_expression": {
      "name": "my_function",
      "title": "My Function",
      "description": "A simple example function",
      "expression_data": {
        "g": "lam",
        "v": {
          "params": ["x"],
          "body": {"g": "ref", "v": "x"}
        }
      },
      "tags": ["example", "lambda"]
    }
  }'
```

### Adding a Version

```bash
curl -X POST http://localhost:4000/api/v1/expressions/my_function/versions \
  -H "Content-Type: application/json" \
  -d '{
    "version": {
      "version": "1.0.0",
      "expression_data": {
        "g": "lam",
        "v": {
          "params": ["x"],
          "body": {"g": "ref", "v": "x"}
        }
      }
    }
  }'
```

### Searching G-Expressions

```bash
curl "http://localhost:4000/api/v1/expressions?search=lambda"
```

## Response Format

All API responses follow this structure:

```json
{
  "data": [...],
  "meta": {
    "total": 42
  }
}
```

G-Expression objects include:
- `name` - Unique identifier
- `title` - Display title
- `description` - Package description
- `expression_data` - The JSON G-Expression
- `tags` - Array of tags for categorization
- `downloads_count` - Download counter
- `versions` - Array of available versions (when included)

## Development

### Database Commands

```bash
# Setup database
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# Reset database
mix ecto.reset

# Drop database
mix ecto.drop
```

### Running Tests

```bash
mix test
```

## Architecture

- **Framework:** Phoenix 1.8 with Elixir
- **Database:** PostgreSQL with JSONB support
- **Frontend:** Phoenix LiveView
- **Validation:** Custom G-Expression validator
- **API:** RESTful JSON API

## Future Enhancements

- User authentication and package ownership
- Private repositories and organizations
- Advanced search with tag filtering
- Documentation generation from G-Expressions
- Package dependency management
- Community features (ratings, comments)

## Contributing

This is a minimal MVP implementation. Contributions welcome for:
- Additional G-Expression type support
- Enhanced validation rules
- UI/UX improvements
- Performance optimizations
- Documentation improvements

## License

[Add your license here]

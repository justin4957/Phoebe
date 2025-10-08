# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Phoebe is a minimal MVP package repository for user-submitted JSON G-Expression files and libraries. It provides both a REST API and web interface for publishing, discovering, and managing G-Expression packages.

**Tech Stack:**
- Phoenix 1.8 (Elixir web framework)
- Phoenix LiveView for web UI
- PostgreSQL with JSONB support (for storing G-Expressions)
- Ecto for database operations
- RESTful JSON API

## Development Commands

### Setup & Database
```bash
# Initial setup (install deps, create DB, run migrations, seed)
mix setup

# Start development server
mix phx.server
# Access at http://localhost:4000

# Database operations
mix ecto.create      # Create database
mix ecto.migrate     # Run migrations
mix ecto.reset       # Drop, recreate, migrate, and seed
mix ecto.drop        # Drop database
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run previously failed tests
mix test --failed
```

### Code Quality
```bash
# Pre-commit checks (compile with warnings as errors, format, test)
mix precommit
```

### CLI Tool
```bash
# G-Expression CLI operations
mix phoebe help              # Show help
mix phoebe examples          # Show example G-expressions
mix phoebe create lit 42     # Create G-expressions
mix phoebe repl              # Interactive REPL
mix phoebe list              # List expressions via API
mix phoebe validate file.json # Validate JSON file
```

## Architecture

### Module Structure

**Core Contexts:**
- `Phoebe.Repository` - Main context for G-Expressions and versions (CRUD operations, search, downloads tracking)
- `Phoebe.Repository.GExpression` - Schema for G-Expression packages
- `Phoebe.Repository.Version` - Schema for versioned G-Expressions
- `Phoebe.GExpression.Validator` - Validates JSON G-Expression structures against specification

**Web Layer:**
- `PhoebeWeb.Router` - Defines routes for both LiveView UI and REST API
- `PhoebeWeb.API.GExpressionController` - REST API for G-Expressions
- `PhoebeWeb.API.VersionController` - REST API for version management
- `PhoebeWeb.ExpressionLive` - LiveView for browsing expressions
- `PhoebeWeb.HomeLive` - Home page LiveView
- `PhoebeWeb.ApiDocsLive` - API documentation LiveView

**CLI Components:**
- `Phoebe.CLI` - Main CLI command parser and dispatcher
- `Phoebe.CLI.ApiClient` - HTTP client for Phoebe API
- `Phoebe.CLI.Validator` - G-expression validation adapted from melas
- `Phoebe.CLI.GExpressionBuilder` - Expression construction utilities
- `Phoebe.CLI.FileManager` - File operations for expressions
- `Phoebe.CLI.REPL` - Interactive expression building

### G-Expression Types

Valid G-Expression types (validated by `Phoebe.GExpression.Validator`):
- `lit` - Literal values (numbers, strings, booleans, arrays)
- `ref` - Variable references (must be valid identifiers)
- `app` - Function applications (requires `fn` field, optional `args`)
- `vec` - Vectors/arrays of expressions
- `lam` - Lambda functions (requires `params` array and `body`)
- `fix` - Fixed-point combinator for recursion
- `match` - Pattern matching (requires `expr` and `branches`)

### API Structure

All API endpoints are under `/api/v1`:
- `GET /api/v1/expressions` - List/search expressions
- `POST /api/v1/expressions` - Create expression
- `GET /api/v1/expressions/:name` - Get expression with versions
- `PUT /api/v1/expressions/:name` - Update expression
- `DELETE /api/v1/expressions/:name` - Delete expression
- `POST /api/v1/expressions/:name/versions` - Add version
- `GET /api/v1/expressions/:name/versions/:version` - Get specific version
- `DELETE /api/v1/expressions/:name/versions/:version` - Delete version

### Database Schema

**g_expressions table:**
- `name` (string, unique) - Package identifier
- `title` (string) - Display title
- `description` (text) - Package description
- `expression_data` (jsonb) - The JSON G-Expression
- `tags` (array of strings) - Categorization tags
- `downloads_count` (integer) - Download counter
- Has many `versions`

**versions table:**
- `version` (string) - Semantic version
- `expression_data` (jsonb) - Versioned G-Expression
- `g_expression_id` (foreign key)

## Important Guidelines

### HTTP Requests
- Use the `:req` (Req) library for HTTP requests (already included as dependency)
- **Avoid** using `:httpoison`, `:tesla`, or `:httpc`

### Pre-commit Hook
- Always run `mix precommit` before committing changes
- This runs compile with warnings as errors, format, and tests

### Phoenix/Elixir Specific
- Follow all Phoenix v1.8 and Elixir guidelines from AGENTS.md
- Use `Phoebe.Repository` context for all G-Expression data operations
- Preload associations when accessing them in templates
- Use `Phoebe.GExpression.Validator.validate/1` for validating G-Expression structures
- G-Expression data is stored in JSONB columns, accessed via `expression_data` field

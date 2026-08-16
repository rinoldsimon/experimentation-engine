# Experimentation Engine: Backend API

This is the Ruby on Rails (API-only) backend for the Experimentation Engine platform. It handles deterministic variant assignment, event tracking, and LLM-assisted variant generation via background jobs.

## Development

**Note:** For full system setup (including the database and frontend), please see the [Root README](../README.md).

If you are working strictly within the backend context:

```bash
# Run tests (once RSpec is configured)
bundle exec rspec

# Open Rails console
bin/rails console

# Run database migrations
bin/rails db:migrate

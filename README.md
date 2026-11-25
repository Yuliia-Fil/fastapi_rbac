# Full Stack FastAPI Template

[![Test Docker Compose](../../actions/workflows/test-docker-compose.yml/badge.svg)](../../actions/workflows/test-docker-compose.yml)
[![Test Backend](../../actions/workflows/test-backend.yml/badge.svg)](../../actions/workflows/test-backend.yml)

## Run locally

Install Docker with Docker Compose and start Docker. From the repository root, use the included local `.env` configuration. PostgreSQL runs as the `db` service, with a Docker volume for its data.

```sh
docker compose run --build --rm backend bash scripts/prestart.sh
docker compose watch
```

Prestart applies migrations and creates the bootstrap admin using `FIRST_SUPERUSER` and `FIRST_SUPERUSER_PASSWORD` from `.env`. The app and API are at <http://localhost:8000>, Swagger UI is at <http://localhost:8000/docs>, and Mailpit is at <http://localhost:8025>.

For separate development servers, install Python 3.14, uv and Bun. Start PostgreSQL and Mailpit from the root with `docker compose up -d db mailpit`. In `backend/`, run `uv sync`, `uv run bash scripts/prestart.sh`, then `uv run fastapi dev`. In a second terminal from the root, run `bun install` and `bun run dev`. Vite serves the frontend at <http://localhost:5173>.

### Seed demo accounts

After prestart has migrated the database, run this explicit seed command on the local development stack.

```sh
docker compose exec backend python -m app.seed
```

With a host-run backend, use `FASTAPI_ENV=development uv run python -m app.seed` from `backend/`. The seed can be rerun and reports a conflict if a demo account exists with different credentials, role or status. All three demo accounts use the local-only password `rbac-local-only`.

| Role | Email |
| --- | --- |
| Admin | `rbac-admin@example.com` |
| Manager | `rbac-manager@example.com` |
| Member | `rbac-member@example.com` |

### Run tests

Stop the regular dev stack before starting the test project so the published ports are free. Run the test script from the repository root.

```sh
COMPOSE_PROJECT_NAME=fastapi-rbac-tests bash ./scripts/test.sh
```

The script removes the test project's volumes. On a running **disposable** stack, use `docker compose exec backend bash scripts/tests-start.sh`. The Pytest session fixture deletes users and items at teardown. For a focused run on that stack, use `docker compose exec backend pytest tests/api/routes/test_rbac.py`.

### Database migrations

For a new schema change, generate a revision inside the backend container. Review its SQL and any data backfill before applying it.

```sh
docker compose exec backend alembic revision --autogenerate -m "Describe the schema change"
docker compose exec backend alembic upgrade head
```

The RBAC migration converts existing superusers to admins and other users to members. It replaces the Boolean with `role`. Downgrading the schema converts admins back to superusers and managers and members to regular users. Deploy the updated backend and regenerated frontend together because the API field changed.

## Role-based access control

| Action | Admin | Manager | Member |
| --- | :---: | :---: | :---: |
| List all users | ✓ | ✓ | |
| Create managed users | ✓ | | |
| View metrics | ✓ | ✓ | |
| View and update own profile or change own password | ✓ | ✓ | ✓ |
| Read or update another user's profile or assign roles | ✓ | | |
| Delete another user | ✓ | | |
| Delete own account | | ✓ | ✓ |

FastAPI's authentication dependency validates the bearer token and loads the user on every protected request. The role-to-capability mapping lives in `backend/app/api/permissions.py`. Routes use a dependency for fixed capabilities and the same policy for target-specific checks. Missing or invalid credentials receive `401` with a Bearer challenge. Inactive users and insufficient permissions receive `403`. Admins retain access to all items and the email utilities. Managers and members can access their own items.

PostgreSQL stores one role per user with a default of `member` and a constraint limiting the allowed values. The API validates role assignments in admin-managed creation and update requests. Public signup always creates a member. Signup and self-profile update reject role and account-status fields. The existing development-only fixture remains available to create member accounts for browser tests.

`GET /api/v1/users/me` returns the signed-in user's `role` and `capabilities`. React shares that response between route guards and controls. A user who opens a forbidden page sees an access-denied message and stays signed in. After an OpenAPI change, regenerate the typed client with `bash ./scripts/generate-client.sh` from the root.

Metrics displays a stub because the template has no metrics data source. Settings remains available to every role for their own account. The template has no separate global settings surface.

## Technology Stack and Features

- ⚡ [**FastAPI**](https://fastapi.tiangolo.com) for the Python backend API.
  - 🧰 [SQLModel](https://sqlmodel.tiangolo.com) for the Python SQL database interactions (ORM).
  - 🔍 [Pydantic](https://docs.pydantic.dev), used by FastAPI, for the data validation and settings management.
  - 💾 [PostgreSQL](https://www.postgresql.org) as the SQL database.
- 🚀 [React](https://react.dev) for the frontend.
  - 🧩 Built into the backend application and served by FastAPI on the same domain as the API.
  - 💃 Using TypeScript, hooks, [Vite](https://vitejs.dev), and other parts of a modern frontend stack.
  - 🎨 [Tailwind CSS](https://tailwindcss.com) and [shadcn/ui](https://ui.shadcn.com) for the frontend components.
  - 🤖 An automatically generated frontend client.
  - 🧪 [Playwright](https://playwright.dev) for end-to-end testing.
  - 🦇 Dark mode support.
- ☁️ [FastAPI Cloud](https://fastapicloud.com) for deployment.
- 🐋 [Docker Compose](https://www.docker.com) for local services and self-hosted deployment.
  - 📞 [Traefik](https://traefik.io) as a reverse proxy with automatic HTTPS.
- 🔒 Secure password hashing by default.
- 🔑 JWT (JSON Web Token) authentication.
- 📫 Email-based password recovery.
- ✉️ [React Email](https://react.email) for email templates.
- 📬 [Mailpit](https://mailpit.axllent.org) for local email testing during development.
- ✅ Tests with [Pytest](https://pytest.org).
- 🏭 CI (continuous integration) and CD (continuous deployment) based on GitHub Actions.

### Dashboard Login

![Dashboard login screenshot](img/login.png)

### Dashboard - Admin

![Admin dashboard screenshot](img/dashboard.png)

### Dashboard - Items

![Items dashboard screenshot](img/dashboard-items.png)

### Dashboard - Dark Mode

![Dark mode dashboard screenshot](img/dashboard-dark.png)

### React Email Templates

![Email templates screenshot](img/react-email.png)

### Mailpit - Local Email Testing

![Mailpit screenshot](img/mailpit.png)

### Interactive API Documentation

![API docs](img/docs.png)

## How to Use It

Click the **Use this template** button at the top of this page to create a new repository.

## Backend Development

Backend docs: [backend/README.md](./backend/README.md).

## Frontend Development

Frontend docs: [frontend/README.md](./frontend/README.md).

## Deployment

FastAPI Cloud deployment: [deployment.md](./deployment.md).

Self-hosted deployment with Docker Compose: [deployment-docker-compose.md](./deployment-docker-compose.md).

## Development

General development docs: [development.md](./development.md).

This includes the local FastAPI and Vite workflow, Docker Compose services, `.env` configuration, and more.

## Release Notes

Check the file [release-notes.md](./release-notes.md).

## License

The Full Stack FastAPI Template is licensed under the terms of the MIT license.

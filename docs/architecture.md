# Architecture Overview

## Project Information

- **Project Name:** JavaScript NoteBook
- **Frontend:** JavaScript / TypeScript (React)
- **Backend:** Python (FastAPI)
- **Database:** PostgreSQL
- **Deployment:** Docker + Kubernetes
- **Cloud Provider:** AWS

---

# High Level Architecture

```text
        ┌─────────────────────┐
        │        Proxy        │
        │        Nginx        │
        └─────────┬───────────┘
                  | HTTPS
         ┌────────┴────────┐
         ▼                 ▼
┌─────────────────────┐ ┌─────────────────────┐
│    Python Backend   │ │     Frontend        │
│ FastAPI Application │ │       React         │
└────┬────────────┬───┘ └─────────────────────┘
     │            │
     ▼            ▼
┌────────────┐ ┌────────────┐
│ PostgreSQL │ │  AI Tools  │
│  Database  │ │            │
└────────────┘ └────────────┘
```

## Frontend Architecture
### Technology Stack
| Component | Technology |
| --- | --- |
| Framework | React |
| State Management | Redux |
| Routing | React Router |
| Language | TypeScript |
| UI Library | TailwindCSS |
| API Client | Axios / Fetch |
| Build Tool | Vite |

### Frontend Structure
```text
ui/
├── src/
│   ├── api/
│   ├── components/
│   ├── pages/
│   ├── hooks/
│   ├── store/
│   ├── layouts/
│   ├── utils/
│   ├── styles/
│   └── types/
├── public/
├── tests/
└── package.json
```

### Frontend Principles
* Component-based architecture
* Reusable UI components
* Separation of business logic and presentation
* Centralized API layer
* Type-safe interfaces
* Lazy loading for pages/modules

## Backend Architecture
### Technology Stack
| Component | Technology |
| --- |------------|
| Framework | FastAPI    |
| ORM | SQLAlchemy |
| Authentication | JWT + OPT  |

### Backend Structure
```text
api/
├── app/
│   ├── api/
│   ├── services/
│   ├── repositories/
│   ├── models/
│   ├── schemas/
│   ├── middleware/
│   ├── core/
│   ├── workers/
│   └── utils/
├── tests/
├── alembic/
└── requirements.txt
```

### Backend Layers
#### API Layer Responsible for:
* HTTP endpoints
* Request validation
* Response serialization
* Authentication
#### Service Layer Responsible for:
* Business logic
* Transactions
* Domain rules
#### Repository Layer Responsible for:
* Database access
* Query abstraction
* ORM operations

## Database Architecture
### PostgreSQL (Main Principles)
* ID primary keys
* Normalized schema
* Foreign key constraints
* Indexed frequently queried fields
* Soft delete support where required

### Migration Strategy
* Alembic migrations
* One migration per feature
* Backward compatible changes
* Rollback support

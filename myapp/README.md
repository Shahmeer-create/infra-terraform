# MyApp

Full-stack application deployed on AWS.

## Architecture

| Component  | Service     | What it does                    |
|-----------|-------------|---------------------------------|
| Frontend  | AWS Amplify | React app served via CDN        |
| Backend   | ECS Fargate | Express API behind ALB          |
| Database  | RDS MySQL   | Relational data (users, photos) |
| Storage   | S3          | Photo files (private, via VPC endpoint) |

## Project Structure

```
├── frontend/          React app (deployed to Amplify)
│   ├── src/
│   │   ├── App.jsx    Main component (Health, Users, Photos tabs)
│   │   ├── api.js     API client (reads VITE_API_URL from env)
│   │   └── main.jsx   Entry point
│   └── package.json
│
├── backend/           Express API (deployed to ECS via Docker)
│   ├── server.js      Main server + health check
│   ├── db.js          MySQL connection pool (reads env vars)
│   ├── s3.js          S3 client (uses IAM Task Role, no keys)
│   ├── migrate.js     Creates tables (run once)
│   ├── routes/
│   │   ├── users.js   CRUD for users
│   │   └── photos.js  Upload/list/view/delete photos in S3
│   ├── Dockerfile     Container image for ECS
│   └── package.json
│
├── amplify.yml        Amplify build config
└── .gitignore
```

## Local Development

### Backend
```bash
cd backend
cp .env.example .env    # edit with your local MySQL credentials
npm install
node migrate.js         # create tables
npm start               # runs on http://localhost:3000
```

### Frontend
```bash
cd frontend
cp .env.example .env    # points to http://localhost:3000
npm install
npm run dev             # runs on http://localhost:5173
```

## Environment Variables

### Backend (injected by ECS from Terraform + Secrets Manager)
- `DB_HOST` — RDS endpoint
- `DB_PORT` — MySQL port (3306)
- `DB_USERNAME` — database user
- `DB_PASSWORD` — database password
- `DB_NAME` — database name
- `S3_PHOTOS_BUCKET` — S3 bucket name for photos
- `AWS_REGION` — AWS region
- `FRONTEND_URL` — Amplify URL (for CORS)

### Frontend (injected by Amplify at build time)
- `VITE_API_URL` — Backend ALB URL
```

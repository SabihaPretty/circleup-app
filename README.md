# CircleUp App

CircleUp is a safe, age-based social communication platform.

## Main Features

- Age-based registration: Kids, Teen, Adult, Senior
- Circle-based profile: Family, Friends, Campus, Work, Local Area, Business
- Social post feed
- Smart chat
- Audio/video call demo
- Local help feed
- Trust score system
- AI memory timeline placeholder
- Kids safe mode concept

## Project Structure

CIRCLEUP_APP/
├── backend/   NestJS + PostgreSQL + Prisma API
├── frontend/  Flutter mobile/web app
└── README.md  Main project documentation

## Backend Run

cd C:\Users\USER\CIRCLEUP_APP\backend
npm run start

Backend URL:
http://localhost:5000

## Frontend Run

cd C:\Users\USER\CIRCLEUP_APP\frontend
flutter run -d chrome

## Important API URLs

GET  /users
POST /users/register
GET  /circles
POST /circles/create
GET  /posts
POST /posts/create
GET  /messages
POST /messages/send
POST /calls/start
GET  /help
POST /help/create
POST /auth/login

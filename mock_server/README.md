# Mock Server

A local JSON mock server for development using [json-server](https://github.com/typicode/json-server).

## Setup

```bash
npm install -g json-server@0.17.4
```

## Run

```bash
cd mock_server
json-server --watch db.json --routes routes.json --port 8080
```

Or from the project root:

```bash
json-server --watch mock_server/db.json --routes mock_server/routes.json --port 8080
```

## Endpoints

| Method | Endpoint          | Description         |
|--------|-------------------|---------------------|
| GET    | /api/posts        | List all posts      |
| GET    | /api/posts/:id    | Get post by ID      |
| POST   | /api/posts        | Create a post       |
| PUT    | /api/posts/:id    | Update a post       |
| DELETE | /api/posts/:id    | Delete a post       |
| GET    | /api/feeds        | List all feed items |
| GET    | /api/feeds/:id    | Get feed item by ID |
| POST   | /api/feeds        | Create a feed item  |
| PUT    | /api/feeds/:id    | Update a feed item  |
| DELETE | /api/feeds/:id    | Delete a feed item  |

## Query Features (built into json-server)

```bash
# Pagination
GET /api/posts?_page=1&_limit=5

# Sort
GET /api/feeds?_sort=created_at&_order=desc

# Filter
GET /api/posts?author_id=user_1
GET /api/feeds?author_name=Sarah%20Chen

# Full-text search
GET /api/posts?q=flutter

# Slice
GET /api/feeds?_start=0&_end=5
```

## Flutter Integration

Run the app with the mock server URL:

```bash
flutter run --dart-define=BASE_URL=http://localhost:8080/api
```

For Android emulator, use `10.0.2.2` instead of `localhost`:

```bash
flutter run --dart-define=BASE_URL=http://10.0.2.2:8080/api
```

For iOS simulator, `localhost` works directly.

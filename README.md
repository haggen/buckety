# Buckety

> Mind your front end.

- RESTful
- NoSQL
- Fast start
- Authorize with UID+CORS

**Note:** Not ready for production. This project still in very early stages of development and currently aims only to support prototyping applications.

## Usage:

Each application has a registry in our database:

```javascript
{
  _id: '...',
  origin: '*',
  xhr_only: true,
  database_url: '...'
}
```

Now your application is ready to store and retrieve data:

```
GET          http://127.0.0.1:4567/<_id>/<collection>       //=> [...]
GET          http://127.0.0.1:4567/<_id>/<collection>/<_id> //=> {...}
POST   {...} http://127.0.0.1:4567/<_id>/<collection>       //=> 201
PUT    {...} http://127.0.0.1:4567/<_id>/<collection>/<_id> //=> 200
DELETE       http://127.0.0.1:4567/<_id>/<collection>/<_id> //=> 200
```

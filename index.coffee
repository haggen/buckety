express = require('express')
mongo   = require('mongoskin')
moniker = require('moniker')

web     = express()
db      = mongo.db(process.env.DATABASE_URL, safe: true)

web.use express.logger()
web.use express.methodOverride()
web.use express.bodyParser()
web.use express.compress()
web.use express.static('public')

# Admin

web.set('view engine', 'jade')
web.engine 'jade', require('jade').__express

web.get '/', (request, response) ->
  db.collection('_apps').find().toArray (err, docs) ->
    db.collectionNames (err, collections) ->
      for app in docs
        app.collections = collections.filter (collection) -> ~collection.name.indexOf(app._id)
      response.render('index', apps: docs)

web.get '/new', (request, response) ->
  response.render('new', app: {name: moniker.choose(), origin: '*'})

web.post '/', (request, response) ->
  db.collection('_apps').insert request.body, (err, doc) ->
    response.redirect('/')

web.get '/edit/:_id', (request, response) ->
  db.collection('_apps').findById request.params._id, (err, doc) ->
    response.render('edit', app: doc)

web.post '/:_id', (request, response) ->
  db.collection('_apps').updateById request.params._id, {$set: request.body}, (err, doc) ->
    response.redirect('/')

web.get '/delete/:_id', (request, response) ->
  db.collection('_apps').removeById request.params._id, (err, doc) ->
    response.redirect('/')

# API

Buckety =
  cache: {}

  fetch: (app, callback) ->
    if app of Buckety.cache
      callback(Buckety.cache[app])
    else
      db.collection('_apps').findOne {name: app}, (err, doc) ->
        if doc
          doc.collection = (name) ->
            db.collection("b#{doc._id}_#{name}")
        Buckety.cache[app] = if err then null else doc
        Buckety.fetch(app, callback)

web.all '/:_id/*'
  # Find application
  , (request, response, next) ->
    Buckety.fetch request.params._id, (app) ->
      if app then next() else response.send(404)

  # Access control
  , (request, response, next) ->
    Buckety.fetch request.params._id, (app) ->
      referrer = request.headers['Referrer'] or '*'
      for origin in app.origin.split("\n")
        if referrer.indexOf(origin) >= 0
          return next()
      response.send(403)

  # CORS
  , (request, response, next) ->
    Buckety.fetch request.params._id, (app) ->
      response.header('Access-Control-Allow-Origin', app.origin)
      response.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE')
      response.header('Access-Control-Allow-Headers', 'X-Requested-With, Accept, Origin, Referer, User-Agent, Content-Type, Authorization')

      (request.method == 'OPTIONS') and response.send(200) or next()

web.get '/:app/:collection', (request, response) ->
  Buckety.fetch request.params.app, (app) ->
    query = JSON.parse(request.query.q or '{}')
    collection = app.collection(request.params.collection)
    collection.find(query).toArray (err, docs) -> response.json(docs)

web.get '/:app/:collection/:_id', (request, response) ->
  Buckety.fetch request.params.app, (app) ->
    collection = app.collection(request.params.collection)
    collection.findById request.params._id, (err, doc) ->
      if doc then response.json(doc) else response.send(404)

web.post '/:app/:collection', (request, response) ->
  Buckety.fetch request.params.app, (app) ->
    collection = app.collection(request.params.collection)
    collection.insert request.body, (err) -> response.send(201)

web.put '/:app/:collection/:_id', (request, response) ->
  Buckety.fetch request.params.app, (app) ->
    collection = app.collection(request.params.collection)
    collection.updateById request.params._id, {$set: request.body}, (err) -> response.send(200)

web.delete '/:app/:collection/:_id', (request, response) ->
  Buckety.fetch request.params.app, (app) ->
    collection = app.collection(request.params.collection)
    collection.removeById request.params._id, (err) -> response.send(200)

web.listen(process.env.PORT)

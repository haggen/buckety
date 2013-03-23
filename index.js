var express, mongo, api, apps, db;

express = require('express');
mongo = require('mongoskin');

apps = {};
api = express();
db = mongo.db(process.env.DATABASE_URL);

api.use(express.methodOverride());
api.use(express.bodyParser());
api.use(express.logger());

// Authentication
api.all(

  '/:_id/*',

  function(request, response, next) {
    var app = apps[request.params._id];

    if(app === undefined) {
      db.collection('apps').findById(request.params._id, function(err, doc) {
        if(err || doc === null) {
          response.send(404);
        } else {
          app = apps[request.params._id] = doc;
          app.db = null;
          next();
        }
      });
    } else {
      next();
    }
  },

  function(request, response, next) {
    var app = apps[request.params._id];

    app.timestamp = (new Date).getTime();

    // console.log('App checkin:', app._id, app.timestamp);

    if(app.db === null) {
      app.db = mongo.db(app.database_url);

      app.timeout = setInterval(function() {
        var now = (new Date).getTime();

        // console.log('Tick:', now);

        if(now - app.timestamp > process.env.DATABASE_TIMEOUT) {
          app.db.close();
          app.db = null;

          clearInterval(app.timeout);
          app.timeout = null;

          // console.log('Timeout:', app._id);
        }
      }, process.env.TIMEOUT_TICK);

      next();
    } else {
      next();
    }
  },

  function(request, response, next) {
    var app = apps[request.params._id];

    if(!request.xhr && app.xhr_only) {
      response.send(403);
    } else {
      next();
    }
  },

  function(request, response, next) {
    var app = apps[request.params._id];

    response.header('Access-Control-Allow-Origin', app.origin);
    response.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE');
    response.header('Access-Control-Allow-Headers', 'X-Requested-With, Accept, Origin, Referer, User-Agent, Content-Type, Authorization, X-Mindflash-SessionID');

    (request.method === 'OPTIONS') && response.send(200) || next();
  }
);

api.get('/:app/:collection', function(request, response) {
  var app, collection, query;

  app = apps[request.params.app];
  query = JSON.parse(request.query.q || '{}');
  collection = app.db.collection(request.params.collection);

  collection.find(query).toArray(function(err, docs) {
    response.json(docs);
  });
});

api.get('/:app/:collection/:_id', function(request, response) {
  var app, collection;

  app = apps[request.params.app];
  collection = app.db.collection(request.params.collection);

  collection.findById(request.params._id, function(err, doc) {
    response.json(doc);
  });
});

api.post('/:app/:collection', function(request, response) {
  var app, collection;

  app = apps[request.params.app];
  collection = app.db.collection(request.params.collection);

  collection.insert(request.body, function(err) {
    response.send(201);
  });
});

api.put('/:app/:collection/:_id', function(request, response) {
  var app, collection;

  app = apps[request.params.app];
  collection = app.db.collection(request.params.collection);

  collection.updateById(request.params._id, {$set: request.body}, function(err) {
    response.send(200);
  });
});

api.del('/:app/:collection/:_id', function(request, response) {
  var app, collection;

  app = apps[request.params.app];
  collection = app.db.collection(request.params.collection);

  collection.removeById(request.params._id, function(err) {
    response.send(200);
  });
});

api.listen(process.env.PORT);

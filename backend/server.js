var redis = require('redis');
var client = redis.createClient();
client.on('connect', function() {
    console.log('redis connected');
});

var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);

/*
app.configure(function() {
    app.use(express.bodyParser());
    app.use(express.static(__dirname + "/public"));
});
*/

io.on('connection', function(socket) {
    console.log("Socket ID: " + socket.id + " connected");

    socket.on('disconnect', function() {
        console.log('Player disconnected');
    });

});

http.listen(3001, function() {
    console.log("Listening on port 3001");
});

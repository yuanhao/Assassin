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

    socket.on('updateLocation', function(msg) {
        console.log("Update Location: " + msg['socketId']);
        console.log("Lat: " + msg['lat'] + ", Lng: " + msg['lng'] + "\n\n");
        var playerSID = msg['socketId'];
        var playerIsKiller = msg['isKiller'];
        var playerLat = msg['lat'];
        var playerLng = msg['lng'];

        if (playerIsKiller  == "0") {
            io.emit('updateLocation', msg);
        }

        // Update to Redis datastore
        client.hmset("players", [playerSID, ' { "isKiller": "' + playerIsKiller + '", "lat": "' + playerLat + '", "lng": "' + playerLng + '" }'], function(e, r) {
            console.log(r);
        });
    });

});

http.listen(3001, function() {
    console.log("Listening on port 3001");
});

var express = require('express');
var app = express();

var redis = require("redis");
var client = redis.createClient();

function setJsonResponseHeaders(res, data) {
    res.header('content-type', 'text/javascript');
    res.header('content-length', data == null ? 0 : data.length);    
    res.end(data);
}


app.get('/vote/:game_id/:player_id/:grade/:team_id', function (req, res) {
    var game_id = req.params.game_id;
    var player_id = req.params.player_id;
    var grade = req.params.grade;
    var team_id = req.params.team_id;
    var ip_address = request.connection.remoteAddress;

    var has_voted = client.hexists('user_votes', ip_address + ':' + game_id + ':' + player_id);
    if (!has_voted) {

        var player_key = team_id + ":" + game_id + ':' + player_id;
        
        // Record the vote
        client.hset('user_votes', ip_address + ':' + game_player_key, grade);

        // Calculate the new average based on existing count and average
        var count   = client.hget('game_player_grade_count', player_key, grade);
        var average = client.hget('game_player_grade_average', player_key, grade);
        var new_average = (count * average + grade) / (count + 1);

        // Record new count and new average
        client.hset('game_player_grade_count', player_key, count + 1);
        client.hset('game_player_grade_average', player_key, new_average);
        
        // be interested in the same game)
        var team_game_player_key = team_id + ':' + game_player_key;
        client.sadd(player_key, );

        // Get members
        client.zrange(team_game_key, 0, -1);
        

        setJsonResponseHeaders(res, "OK");
        return;
    }
});



app.get('/hello.txt', function(req, res){
      var body = 'Hello World';
        res.setHeader('Content-Type', 'text/plain');
          res.setHeader('Content-Length', body.length);
            res.end(body);
});
app.listen(3000);
console.log('Listening on port 3000');

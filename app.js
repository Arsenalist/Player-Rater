// Generated by CoffeeScript 1.6.3
var app, client, express, findLetterGrade, gradeMap, port, rtg, setJsonResponseHeaders;

express = require("express");

app = express();

app.use(express.bodyParser());

if (process.env.REDISTOGO_URL) {
  rtg = require("url").parse(process.env.REDISTOGO_URL);
  client = require("redis").createClient(rtg.port, rtg.hostname);
  client.auth(rtg.auth.split(":")[1]);
} else {
  client = require("redis").createClient();
}

gradeMap = {
  'A+': 4,
  'A': 3.85,
  'A-': 3.7,
  'B+': 3.3,
  'B': 3,
  'B-': 2.7,
  'C+': 2.3,
  'C': 2,
  'C-': 1.7,
  'D+': 1.3,
  'D': 1,
  'D-': .7,
  'F': 0
};

findLetterGrade = function(numerical) {
  if ((4 >= numerical && numerical > 3.85)) {
    return 'A+';
  } else if ((3.85 >= numerical && numerical > 3.7)) {
    return 'A-';
  } else if ((3.7 >= numerical && numerical > 3.3)) {
    return 'A';
  } else if ((3.3 >= numerical && numerical > 3)) {
    return 'B+';
  } else if ((3 >= numerical && numerical > 2.7)) {
    return 'B';
  } else if ((2.7 >= numerical && numerical > 2.3)) {
    return 'B-';
  } else if ((2.3 >= numerical && numerical > 2)) {
    return 'C+';
  } else if ((2 >= numerical && numerical > 1.7)) {
    return 'C';
  } else if ((1.7 >= numerical && numerical > 1.3)) {
    return 'C-';
  } else if ((1.3 >= numerical && numerical > 1)) {
    return 'D+';
  } else if ((1 >= numerical && numerical > .7)) {
    return 'D';
  } else if ((.7 >= numerical && numerical > .5)) {
    return 'D-';
  } else if (numerical <= .5) {
    return 'F';
  } else {
    return null;
  }
};

setJsonResponseHeaders = function(res, data) {
  res.header("content-type", "text/javascript");
  res.header("content-length", (data == null ? 0 : data.length));
  return res.end(data);
};

app.get("/mediator.html", function(req, res) {
  return res.sendfile("./mediator.html");
});

app.get("/client.js", function(req, res) {
  return res.sendfile("./client.js");
});

app.get("/mediator.js", function(req, res) {
  return res.sendfile("./mediator.js");
});

app.post("/rating", function(req, res) {
  var game_id, ip_address, team_id;
  team_id = req.body.team_id;
  game_id = req.body.game_id;
  ip_address = req.connection.remoteAddress;
  return client.hvals("" + team_id + ":" + game_id, function(err, reply) {
    var ind, json, multi, r, results, user_vote_key, _i, _j, _len, _len1;
    results = new Array();
    for (_i = 0, _len = reply.length; _i < _len; _i++) {
      r = reply[_i];
      json = JSON.parse(r);
      json['grade'] = findLetterGrade(parseFloat(json['average']));
      results.push(json);
    }
    multi = client.multi();
    for (ind = _j = 0, _len1 = results.length; _j < _len1; ind = ++_j) {
      r = results[ind];
      user_vote_key = "" + ip_address + ":" + game_id + ":" + r.player_id;
      multi.hexists("user_votes", user_vote_key);
    }
    return multi.exec(function(err, replies) {
      var i, _k, _len2;
      if (err != null) {
        console.log(err);
      }
      for (i = _k = 0, _len2 = replies.length; _k < _len2; i = ++_k) {
        r = replies[i];
        results[i]["voted"] = r === 1;
      }
      console.log(results);
      results = JSON.stringify(results);
      return setJsonResponseHeaders(res, results);
    });
  });
});

app.post("/vote", function(req, res) {
  var game_id, grade, ip_address, player_id, team_id, user_vote_key;
  game_id = req.body.game_id;
  player_id = req.body.player_id;
  grade = req.body.player_grade;
  team_id = req.body.team_id;
  ip_address = req.connection.remoteAddress;
  if (!grade in gradeMap) {
    res.status(506);
    setJsonResponseHeaders(res, "Invalid grade.");
    return;
  }
  grade = parseFloat(gradeMap[grade]);
  console.log("game ", game_id, "player ", player_id, "grade ", grade, "team ", team_id);
  user_vote_key = "" + ip_address + ":" + game_id + ":" + player_id;
  return client.hexists("user_votes", user_vote_key, function(err, has_voted) {
    var average, count, multi, new_average, player_key;
    if (!has_voted) {
      player_key = "" + team_id + ":" + game_id + ":" + player_id;
      count = average = new_average = 0;
      multi = client.multi();
      multi.hset("user_votes", user_vote_key, grade);
      multi.hget("game_player_grade_count", player_key);
      multi.hget("game_player_grade_average", player_key);
      return multi.exec(function(err, replies) {
        var letter_grade, set_multi;
        count = ((replies[1] != null) ? parseInt(replies[1]) : 0);
        new_average = replies[2] != null ? (count * parseFloat(replies[2]) + grade) / (count + 1) : grade;
        set_multi = client.multi();
        set_multi.hset("game_player_grade_count", player_key, count + 1);
        set_multi.hset("game_player_grade_average", player_key, new_average);
        set_multi.hset("" + team_id + ":" + game_id, player_id, JSON.stringify({
          player_id: player_id,
          average: new_average,
          count: count + 1
        }));
        set_multi.exec(function(err, replies) {
          if (err != null) {
            return console.log(err);
          }
        });
        letter_grade = findLetterGrade(new_average);
        if (letter_grade != null) {
          return setJsonResponseHeaders(res, JSON.stringify({
            grade: letter_grade,
            count: count + 1
          }));
        } else {
          console.log("Can't calculate grade");
          res.status(506);
          return setJsonResponseHeaders(res, "Grade could not be calculated.");
        }
      });
    } else {
      console.log("Voted already");
      res.status(506);
      return setJsonResponseHeaders(res, "Already voted.");
    }
  });
});

port = process.env.PORT || 3000;

app.listen(port);

console.log("Listening on port " + port);

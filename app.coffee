express = require("express")

app = express()
app.use(express.bodyParser());

if process.env.REDISTOGO_URL?
  rtg  = require("url").parse(process.env.REDISTOGO_URL);
  client = require("redis").createClient(rtg.port, rtg.hostname);
  client.auth(rtg.auth.split(":")[1]);  
else
  client = require("redis").createClient();


gradeMap =
  'A+': 4
  'A' : 3.85
  'A-': 3.7
  'B+': 3.3
  'B' : 3
  'B-': 2.7
  'C+': 2.3
  'C' : 2
  'C-': 1.7
  'D+': 1.3
  'D' : 1
  'D-': .7
  'F' : 0


findLetterGrade = (numerical) ->
  if 4 >= numerical > 3.85
    return 'A+'
  else if 3.85 >=  numerical > 3.7
    return 'A-'
  else if 3.7 >=  numerical > 3.3
    return 'A'
  else if 3.3 >=  numerical > 3
    return 'B+'
  else if 3 >=  numerical > 2.7
    return 'B'
  else if 2.7 >=  numerical > 2.3
    return 'B-'
  else if 2.3 >=  numerical > 2
    return 'C+'
  else if 2 >=  numerical > 1.7
    return 'C'
  else if 1.7 >=  numerical > 1.3
    return 'C-'
  else if 1.3 >=  numerical > 1
    return 'D+'
  else if 1 >=  numerical > .7
    return 'D'
  else if .7 >=  numerical > .5
    return 'D-'
  else if numerical <= .5
    return 'F'
  else
    return null


setJsonResponseHeaders = (res, data) ->
  res.header "content-type", "text/javascript"
  res.header "content-length", (if not data? then 0 else data.length)
  res.end data

app.get "/mediator.html", (req, res) ->
  res.sendfile("./mediator.html")

app.get "/client.js", (req, res) ->
  res.sendfile("./client.js")

app.get "/mediator.js", (req, res) ->
  res.sendfile("./mediator.js")

app.get "/rating/:team_id/:game_id", (req, res) ->
  team_id = req.params.team_id
  game_id = req.params.game_id
  ip_address = req.connection.remoteAddress

  client.hvals "#{team_id}:#{game_id}", (err, reply) ->    
    results = new Array()
    for r in reply
      json = JSON.parse(r)
      json['grade'] = findLetterGrade(parseFloat(json['average']))
      results.push json

    multi = client.multi()

    for r, ind in results
      console.log ind
      user_vote_key = "#{ip_address}:#{game_id}:#{r.player_id}"
      multi.hexists "user_votes", user_vote_key
    multi.exec (err, replies) ->
      console.log "returned from multi"
      console.log replies
      for r, i in replies
        results[i]["voted"] = (r == 1)
      console.log results
      results = JSON.stringify(results)
      setJsonResponseHeaders res, results

    


app.post "/vote", (req, res) ->
  game_id = req.body.game_id
  player_id = req.body.player_id
  grade = req.body.player_grade
  team_id = req.body.team_id
  ip_address = req.connection.remoteAddress

  if not grade of gradeMap
      res.status(506)
      setJsonResponseHeaders res, "Invalid grade."
      return
  grade = parseFloat(gradeMap[grade])
  console.log "letter grade from user mapped to #{grade}"


  console.log "game ", game_id, "player ", player_id, "grade ", grade, "team ", team_id
  user_vote_key = "#{ip_address}:#{game_id}:#{player_id}"
  client.hexists "user_votes", user_vote_key, (err, has_voted) ->
    if true or not has_voted
      player_key = "#{team_id}:#{game_id}:#{player_id}"
      # Record the vote
      # Calculate the new average based on existing count and average
      count = average = new_average = 0

      multi = client.multi()
      multi.hset "user_votes", user_vote_key, grade      
      multi.hget "game_player_grade_count", player_key
      multi.hget "game_player_grade_average", player_key
      multi.exec (err, replies) -> 
        count = (if (replies[1]?) then parseInt(replies[1]) else 0)        
        new_average = if replies[2]? then ((count * parseFloat(replies[2]) + grade) / (count + 1)) else grade
        set_multi = client.multi()
        set_multi.hset "game_player_grade_count", player_key, count + 1
        set_multi.hset "game_player_grade_average", player_key, new_average
        set_multi.hset "#{team_id}:#{game_id}", player_id, JSON.stringify(
          player_id: player_id
          average: new_average
          count: count + 1
        )
        set_multi.exec()
        letter_grade = findLetterGrade(new_average)
        if letter_grade?   
          setJsonResponseHeaders res, JSON.stringify({grade: letter_grade, count: count + 1})
        else
          console.log " can't calculate grade - doing the 506"
          res.status(506)
          setJsonResponseHeaders res, "Grade could not be calculated."

    else
      console.log "voted already"
      res.status(506)
      setJsonResponseHeaders res, "Already voted."

app.listen 3000
console.log "Listening on port 3000"
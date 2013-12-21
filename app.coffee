express = require("express")
redis = require("redis")

app = express()
app.use(express.bodyParser());
client = redis.createClient()


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

app.get "/grades", (req, res) ->
  res.sendfile("./static/grader.html")

app.get "/client.js", (req, res) ->
  res.sendfile("./client.js")

app.get "/grader.js", (req, res) ->
  res.sendfile("./grader.js")

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
        results[i]["voted"] = r == 1
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
      client.hset "user_votes", user_vote_key, grade
      
      # Calculate the new average based on existing count and average
      count = average = new_average = 0
      client.hget "game_player_grade_count", player_key, (err, reply) ->
        count = (if (reply?) then parseInt(reply) else 0)
        client.hget "game_player_grade_average", player_key, (err, average) ->
          new_average = if average? then ((count * parseFloat(average) + grade) / (count + 1)) else grade
          multi = client.multi()
          multi.hset "game_player_grade_count", player_key, count + 1
          multi.hset "game_player_grade_average", player_key, new_average
          multi.hset "#{team_id}:#{game_id}", player_id, JSON.stringify(
            player_id: player_id
            average: new_average
            count: count + 1
          )
          multi.exec()
          letter_grade = findLetterGrade(new_average)
          console.log "new letter grade is ", letter_grade, " and is based on ", new_average
          if letter_grade?   
            console.log "valid letter grade"         
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
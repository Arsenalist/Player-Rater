express = require("express")
app = express()
expressValidator = require('express-validator')
app.use(express.bodyParser())
app.use(expressValidator())

app.use (req, res, next) ->
  team_id = req.body.team_id
  if (team_id? and team_id != 'tor')
      setJsonResponseHeaders res, "Team not allowed."
  else
    next()

if process.env.REDISTOGO_URL
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


findRemoteAddress = (req) ->
  remote_address = req.headers["x-forwarded-for"]
  if remote_address?
    list = remote_address.split(",")
    remote_address = list[0]
  else
    remote_address = req.connection.remoteAddress

  return remote_address.trim() 
  

setJsonResponseHeaders = (res, data) ->
  res.header "content-type", "text/javascript"
  res.header "content-length", (if not data? then 0 else data.length)
  res.end data

app.get "/mediator.html", (req, res) ->
  res.sendfile("./mediator.html")

app.get "/client.min.js", (req, res) ->
  res.sendfile("./client.min.js")

app.get "/mediator.min.js", (req, res) ->
  res.sendfile("./mediator.min.js")

app.post "/rating", (req, res) ->
  team_id = req.body.team_id
  game_id = req.body.game_id
  ip_address = findRemoteAddress(req)
  client.hvals "#{team_id}:#{game_id}", (err, reply) ->
    results = new Array()
    for r in reply
      json = JSON.parse(r)
      json['grade'] = findLetterGrade(parseFloat(json['average']))
      results.push json

    multi = client.multi()

    active_game_key = "active_game:#{game_id}"
    multi.exists active_game_key

    for r, ind in results
      user_vote_key = "#{ip_address}:#{game_id}:#{r.player_id}"
      multi.hexists "user_votes", user_vote_key

    multi.exec (err, replies) ->
      console.log err if err?
      # allow game voting if game is active, or if there's no votes yet
      allow_game_voting = replies[0] == 1 or replies.length == 1
      for r, i in replies[1..]
        results[i]["allow_voting"] = replies[i] == 0
      #console.log results
      results = JSON.stringify({"allow_game_voting": allow_game_voting, "grades": results})
      setJsonResponseHeaders res, results

    
 

app.post "/vote", (req, res) ->

  req.checkBody('team_id', 'Invalid Team ID').notEmpty()
  req.checkBody('game_id', 'Invalid Game ID').notEmpty().isInt()
  req.checkBody('player_id', 'Invalid Player ID').notEmpty()  
  req.checkBody('player_grade', 'Invalid Player Grade').notEmpty()

  errors = req.validationErrors()
  if (errors)
    res.status(400)
    setJsonResponseHeaders res, JSON.stringify(errors)
    return


  team_id = req.body.team_id
  game_id = req.body.game_id
  player_id = req.body.player_id
  grade = req.body.player_grade
  
  ip_address = findRemoteAddress(req)

  if not grade of gradeMap
      res.status(506)
      setJsonResponseHeaders res, "Invalid grade."
      return
  grade = parseFloat(gradeMap[grade])

  console.log "Game: #{game_id}, Player: #{player_id}, Grade: #{grade}, Team: #{team_id}"
  user_vote_key = "#{ip_address}:#{game_id}:#{player_id}"
  player_key = "#{team_id}:#{game_id}:#{player_id}"
  active_game_key = "active_game:#{game_id}"

  outer_multi = client.multi()

  outer_multi.get active_game_key  
  outer_multi.hexists "user_votes", user_vote_key
  outer_multi.hset "user_votes", user_vote_key, grade      
  outer_multi.hget "game_player_grade_count", player_key
  outer_multi.hget "game_player_grade_average", player_key

  outer_multi.exec (err, replies) ->
    count = average = new_average = 0

    game_enabled = not not replies[0]
    has_voted = not not replies[1]        
    # Ignoring replies[2] as that's the hset whose return value we don't really care about        
    count = (if (replies[3]?) then parseInt(replies[3]) else 0)
    new_average = if replies[4]? then ((count * parseFloat(replies[4]) + grade) / (count + 1)) else grade


    # If they've voted, deny
    if has_voted
      res.status(506)
      setJsonResponseHeaders res, "Already voted."
      return

    # If game is not enabled, it means it either has never been voted on OR has been voted
    # on and has simply expired, we want to disallow voting if it's the second case
    if (!game_enabled and count > 0)
      res.status(506)
      setJsonResponseHeaders res, "Game expired."
      return

    # Game has never been voted on, implying that it's OK to vote (even if first votes 
    # is weeks later).  For the first vote, we also start the ticker on game_enabled
    else if count == 0
      client.set active_game_key, 1
      # 24-hour expiry
      client.expire active_game_key, 86400

    # There have been votes (and game is enabled which is implied by first if failing)
    set_multi = client.multi()
    set_multi.hset "game_player_grade_count", player_key, count + 1
    set_multi.hset "game_player_grade_average", player_key, new_average
    set_multi.hset "#{team_id}:#{game_id}", player_id, JSON.stringify(
      player_id: player_id
      average: new_average
      count: count + 1
    )
    set_multi.exec (err, replies)->
      console.log err if err?
    letter_grade = findLetterGrade(new_average)
    if letter_grade?   
      setJsonResponseHeaders res, JSON.stringify({grade: letter_grade, count: count + 1})
    else
      console.log "Can't calculate grade"
      res.status(506)
      setJsonResponseHeaders res, "Grade could not be calculated."

port = process.env.PORT || 3000
app.listen( port )
console.log "Listening on port #{port}"
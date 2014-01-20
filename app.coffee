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
  'tl': 1
  'jr' : 1
  'th': 1


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

calculatePercentages = (grade) ->
  total = grade['tl'] + grade['jr'] + grade['th']
  grade['tl'] = Math.floor(grade['tl']*100/total)
  grade['jr'] = Math.floor(grade['jr']*100/total)
  grade['th'] = Math.floor(grade['th']*100/total)
  return grade

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
  game_key_for_expiry = "user_votes:#{game_id}:#{team_id}"

  client.hvals "#{team_id}:#{game_id}", (err, reply) ->
    results = new Array()
    for r in reply
      json = JSON.parse(r)
      results.push calculatePercentages(json)

    multi = client.multi()

    active_game_key = "active_game:#{game_id}"
    multi.exists active_game_key

    for r, ind in results
      user_vote_key = "#{ip_address}:#{game_id}:#{r.player_id}"
      multi.hexists game_key_for_expiry, user_vote_key

    multi.exec (err, replies) ->
      console.log err if err?
      # allow game voting if game is active, or if there's no votes yet
      allow_game_voting = replies[0] == 1 or replies.length == 1
      result_replies = replies[1..]
      for r, i in result_replies
        results[i]["allow_voting"] = result_replies[i] == 0
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

  console.log "Game: #{game_id}, Player: #{player_id}, Grade: #{grade}, Team: #{team_id}"
  game_key_for_expiry = "user_votes:#{game_id}:#{team_id}"
  user_vote_key = "#{ip_address}:#{game_id}:#{player_id}"
  player_key = "#{team_id}:#{game_id}:#{player_id}"
  active_game_key = "active_game:#{game_id}"

  outer_multi = client.multi()

  outer_multi.get active_game_key  
  outer_multi.hexists game_key_for_expiry, user_vote_key
  outer_multi.hset game_key_for_expiry, user_vote_key, grade   
  outer_multi.hget "game_player_grade", player_key
  outer_multi.expire game_key_for_expiry, 86400

  outer_multi.exec (err, replies) ->
    count = average = new_average = 0

    game_enabled = not not replies[0]
    has_voted = not not replies[1]        
    # Ignoring replies[2] as that's the hset whose return value we don't really care about        
    stored_grade = if (replies[3]?) then JSON.parse(replies[3]) else {tl: 0, jr: 0, th: 0}


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
    stored_grade[grade] = stored_grade[grade] + 1
    stored_grade['player_id'] = player_id
    new_stored_grade = JSON.stringify(stored_grade)    

    set_multi.hset "game_player_grade", player_key, new_stored_grade
    set_multi.hset "#{team_id}:#{game_id}", player_id, new_stored_grade
    set_multi.exec (err, replies)->
      console.log err if err?
      setJsonResponseHeaders res, JSON.stringify(calculatePercentages(stored_grade))

port = process.env.PORT || 3000
app.listen( port )
console.log "Listening on port #{port}"
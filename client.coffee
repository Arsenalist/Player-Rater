
addLoadEvent = (func) ->
  oldonload = window.onload; 
  if (typeof window.onload != 'function')
    window.onload = func
  else
    window.onload = () -> 
      oldonload();  
      func();       

initGradeDisplay = ->
	iframe = document.getElementById("grader-iframe")
	message =
		type: 'populate-grades'
		data: 
			game_id: iframe.getAttribute("data-game-id")
			team_id: iframe.getAttribute("data-team-id")
	iframe.contentWindow.postMessage(JSON.stringify(message), '*')

gradeSelectCallback = (e)->
	iframe = document.getElementById("grader-iframe")
	message =
		type: 'record-grade'
		data: 
			game_id: iframe.getAttribute("data-game-id")
			team_id: iframe.getAttribute("data-team-id")
			player_id: e.target.previousElementSibling.getAttribute("data-player-id")
			player_grade: e.target.value

	e.target.style.display = 'none'
	iframe.contentWindow.postMessage(JSON.stringify(message), '*')

showSelectBox = (player_id) ->
	document.getElementById("user-grade-container-#{player_id}").nextElementSibling.style.display = ''
	false

displayGrades = (message) ->
	populateSelectBox()		
	grades = message['data']['grades']
	allow_game_voting = message['data']['allow_game_voting']
	player_ids_with_grades = []
	for g in grades
		if not not g.player_id
			displayGrade(g, g.allow_voting and allow_game_voting)
			player_ids_with_grades.push g.player_id
	grade_holders = document.getElementsByClassName("grade-holder")
	for gh in grade_holders
		player_id = gh.getAttribute("data-player-id")
		# technically, this player_id should never be null as the markup of the page should be correct
		if player_id? and player_id not in player_ids_with_grades
			grade =
				player_id: player_id
				grade: '-'
				count: 0
			displayGrade(grade, allow_game_voting)



displayGrade = (grade, show_control) -> 
	user_grade_container = document.getElementById("user-grade-container-#{grade.player_id}")
	# Do not attempt to display a grade if the container is not found, this can happen
	# when we are rendering another recap for the same team/game, only this time fewer players
	# are being reated
	if not user_grade_container
		return
	if 'th' of grade
		html = "
			  <ul style=\"text-align:left;font-size: .6em; list-style-type:none; margin: 0; padding: 0\">
			   <li><span style=\"width:#{grade['tl']}%;\">Low #{grade['tl']}%</span></li>
			   <li><span style=\"width:#{grade['jr']}%;\">Right #{grade['jr']}%</span></li>
			   <li><span style=\"width:#{grade['th']}%;\">High #{grade['th']}%</span></li>
			  </ul>"

		user_grade_container.innerHTML = html

	if show_control
		user_grade_container.nextElementSibling.style.display = ""
	else
		user_grade_container.nextElementSibling.style.display = "none"

updateGrade = (message) ->
	displayGrade(message['data'], false)

populateSelectBox = (message) ->
	grade_holders = document.getElementsByClassName("grade-holder")
	select_options = '<select><option>Rate the grade!</option><option value="tl">Too Low</option><option value="jr">Just Right</option><option value="th">Too High</option></select>'

	for g in grade_holders
		select = document.createElement('select')
		select.innerHTML = select_options
		select.onchange = gradeSelectCallback
		select.setAttribute("style", "width: 60px; font-size: .6em")
		select.style.display = ''
		g.parentNode.insertBefore(select, null);

windowLoadHandler = (e) ->
	message = JSON.parse(e.data) 
	switch message['type']
		when 'updated-grade' then updateGrade(message)
		when 'display-grades' then displayGrades(message)

addLoadEvent  ->
	window.addEventListener "message", windowLoadHandler, false
	initGradeDisplay()

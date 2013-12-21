
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
			player_id: e.target.previousSibling.previousSibling.getAttribute("data-player-id")
			player_grade: e.target.value

	e.target.style.display = 'none'
	iframe.contentWindow.postMessage(JSON.stringify(message), '*')

showSelectBox = (player_id) ->
	document.getElementById("user-grade-container-#{player_id}").nextSibling.style.display = ''
	false

displayGrades = (message) ->
	populateSelectBox()
	grades = message['data']['grades']
	player_ids_with_grades = []
	for g in grades
		displayGrade(g, !g.voted)
		player_ids_with_grades.push g.player_id
	grade_holders = document.getElementsByClassName("grade-holder")
	for gh in grade_holders
		if gh.getAttribute("data-player-id") not in player_ids_with_grades
			grade =
				player_id: gh.getAttribute("data-player-id")
				grade: '-'
				count: 0
			displayGrade(grade, true)



displayGrade = (grade, show_control) -> 
	user_grade_container = document.getElementById("user-grade-container-#{grade.player_id}")
	html = "
		<div style=\"margin-top: 3px; padding: 4px; text-align:center; background: #cc0000; color: white; font-weight: bold\" class='user-grade'>#{grade.grade}</div>
		<div style=\"padding: 4px; text-align: center; color: white; background: black; font-weight: bold; font-size: .8em\" class='user-grade-count'>#{grade.count}</div>"
	user_grade_container.innerHTML = html
	if show_control
		user_grade_container.nextSibling.style.display = "";
	else
		user_grade_container.nextSibling.style.display = "none";

updateGrade = (message) ->
	displayGrade(message['data'], false)

populateSelectBox = (message) ->
	grade_holders = document.getElementsByClassName("grade-holder")
	grades = ['Rate!', 'A+', 'A-', 'A', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'D-', 'F']
	select_options = ""
	for g in grades
		select_options += "<option>#{g}</option>"

	for g in grade_holders
		select = document.createElement('select')
		select.innerHTML = select_options
		select.onchange = gradeSelectCallback
		select.setAttribute("style", "font-size: .6em")
		select.style.display = ''
		g.appendChild(select)

windowLoadHandler = (e) ->
	message = JSON.parse(e.data) 
	switch message['type']
		when 'updated-grade' then updateGrade(message)
		when 'display-grades' then displayGrades(message)

addLoadEvent  ->
	window.addEventListener "message", windowLoadHandler, false
	initGradeDisplay()

jQuery(document).ready ( $ ) ->

	grades = ['-', 'A+', 'A-', 'A', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'D-', 'F']
	select_options = ""
	for g in grades
		select_options += "<option>#{g}</option>"
	message =
		type: 'select-options'
		data:
			select_options: select_options
	window.parent.postMessage(JSON.stringify(message), '*')

	window.addEventListener  "message", (e) ->
		message = JSON.parse(e.data) 
		switch message['type']
			when 'record-grade' then recordGrade(message)
			when 'populate-grades' then populateGrades(message)

	populateGrades = (message) ->
		team_id = message['data']['team_id']
		game_id = message['data']['game_id']
		$.ajax(
			url: "http://localhost:3000/rating/#{team_id}/#{game_id}"
			type: 'GET'
			dataType: 'json'
		)
		.done (data) ->
			message =
				type: 'display-grades'
				data:
					grades: data
			window.parent.postMessage(JSON.stringify(message), '*')



	recordGrade = (message) ->
		params = message['data']
		$.ajax(
			url: "http://localhost:3000/vote"
			data: params
			type: 'POST'
			dataType: 'json'
		)
		.done (data) ->
			message =
				type: 'updated-grade'
				data:
					grade: data.grade
					player_id: params['player_id']
					count: data.count
			window.parent.postMessage(JSON.stringify(message), '*')
		

			   

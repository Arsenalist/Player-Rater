jQuery(document).ready ( $ ) ->

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
		

			   

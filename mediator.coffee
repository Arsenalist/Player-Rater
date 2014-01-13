jQuery(document).ready ( $ ) ->

	window.addEventListener  "message", (e) ->
		message = JSON.parse(e.data) 
		switch message['type']
			when 'record-grade' then recordGrade(message)
			when 'populate-grades' then populateGrades(message)

	populateGrades = (message) ->
		team_id = message['data']['team_id']
		game_id = message['data']['game_id']
		params =
			team_id: team_id
			game_id: game_id			
		$.ajax(
			url: "/rating"
			data: params
			type: 'POST'
			dataType: 'json'
		)
		.done (data) ->
			message =
				type: 'display-grades'
				data:
					data
			window.parent.postMessage(JSON.stringify(message), '*')



	recordGrade = (message) ->
		params = message['data']
		$.ajax(
			url: "/vote"
			data: params
			type: 'POST'
			dataType: 'json'
		)
		.done (data) ->
			message =
				type: 'updated-grade'
				data:
					data
			window.parent.postMessage(JSON.stringify(message), '*')
		

			   

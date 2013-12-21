// Generated by CoffeeScript 1.6.3
jQuery(document).ready(function($) {
  var populateGrades, recordGrade;
  window.addEventListener("message", function(e) {
    var message;
    message = JSON.parse(e.data);
    switch (message['type']) {
      case 'record-grade':
        return recordGrade(message);
      case 'populate-grades':
        return populateGrades(message);
    }
  });
  populateGrades = function(message) {
    var game_id, team_id;
    team_id = message['data']['team_id'];
    game_id = message['data']['game_id'];
    return $.ajax({
      url: "http://localhost:3000/rating/" + team_id + "/" + game_id,
      type: 'GET',
      dataType: 'json'
    }).done(function(data) {
      message = {
        type: 'display-grades',
        data: {
          grades: data
        }
      };
      return window.parent.postMessage(JSON.stringify(message), '*');
    });
  };
  return recordGrade = function(message) {
    var params;
    params = message['data'];
    return $.ajax({
      url: "http://localhost:3000/vote",
      data: params,
      type: 'POST',
      dataType: 'json'
    }).done(function(data) {
      message = {
        type: 'updated-grade',
        data: {
          grade: data.grade,
          player_id: params['player_id'],
          count: data.count
        }
      };
      return window.parent.postMessage(JSON.stringify(message), '*');
    });
  };
});

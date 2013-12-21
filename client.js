// Generated by CoffeeScript 1.6.3
var addLoadEvent, displayGrade, displayGrades, gradeSelectCallback, initGradeDisplay, populateSelectBox, showSelectBox, updateGrade, windowLoadHandler,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

addLoadEvent = function(func) {
  var oldonload;
  oldonload = window.onload;
  if (typeof window.onload !== 'function') {
    return window.onload = func;
  } else {
    return window.onload = function() {
      oldonload();
      return func();
    };
  }
};

initGradeDisplay = function() {
  var iframe, message;
  iframe = document.getElementById("grader-iframe");
  message = {
    type: 'populate-grades',
    data: {
      game_id: iframe.getAttribute("data-game-id"),
      team_id: iframe.getAttribute("data-team-id")
    }
  };
  return iframe.contentWindow.postMessage(JSON.stringify(message), '*');
};

gradeSelectCallback = function(e) {
  var iframe, message;
  iframe = document.getElementById("grader-iframe");
  message = {
    type: 'record-grade',
    data: {
      game_id: iframe.getAttribute("data-game-id"),
      team_id: iframe.getAttribute("data-team-id"),
      player_id: e.target.previousSibling.previousSibling.getAttribute("data-player-id"),
      player_grade: e.target.value
    }
  };
  e.target.style.display = 'none';
  return iframe.contentWindow.postMessage(JSON.stringify(message), '*');
};

showSelectBox = function(player_id) {
  document.getElementById("user-grade-container-" + player_id).nextSibling.style.display = '';
  return false;
};

displayGrades = function(message) {
  var g, gh, grade, grade_holders, grades, player_ids_with_grades, _i, _j, _len, _len1, _ref, _results;
  populateSelectBox();
  grades = message['data']['grades'];
  player_ids_with_grades = [];
  for (_i = 0, _len = grades.length; _i < _len; _i++) {
    g = grades[_i];
    displayGrade(g, !g.voted);
    player_ids_with_grades.push(g.player_id);
  }
  grade_holders = document.getElementsByClassName("grade-holder");
  _results = [];
  for (_j = 0, _len1 = grade_holders.length; _j < _len1; _j++) {
    gh = grade_holders[_j];
    if (_ref = gh.getAttribute("data-player-id"), __indexOf.call(player_ids_with_grades, _ref) < 0) {
      grade = {
        player_id: gh.getAttribute("data-player-id"),
        grade: '-',
        count: 0
      };
      _results.push(displayGrade(grade, true));
    } else {
      _results.push(void 0);
    }
  }
  return _results;
};

displayGrade = function(grade, show_control) {
  var html, user_grade_container;
  user_grade_container = document.getElementById("user-grade-container-" + grade.player_id);
  html = "		<div style=\"margin-top: 3px; padding: 4px; text-align:center; background: #cc0000; color: white; font-weight: bold\" class='user-grade'>" + grade.grade + "</div>		<div style=\"padding: 4px; text-align: center; color: white; background: black; font-weight: bold; font-size: .8em\" class='user-grade-count'>" + grade.count + "</div>";
  user_grade_container.innerHTML = html;
  if (show_control) {
    return user_grade_container.nextSibling.style.display = "";
  } else {
    return user_grade_container.nextSibling.style.display = "none";
  }
};

updateGrade = function(message) {
  return displayGrade(message['data'], false);
};

populateSelectBox = function(message) {
  var g, grade_holders, grades, select, select_options, _i, _j, _len, _len1, _results;
  grade_holders = document.getElementsByClassName("grade-holder");
  grades = ['Rate!', 'A+', 'A-', 'A', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D+', 'D', 'D-', 'F'];
  select_options = "";
  for (_i = 0, _len = grades.length; _i < _len; _i++) {
    g = grades[_i];
    select_options += "<option>" + g + "</option>";
  }
  _results = [];
  for (_j = 0, _len1 = grade_holders.length; _j < _len1; _j++) {
    g = grade_holders[_j];
    select = document.createElement('select');
    select.innerHTML = select_options;
    select.onchange = gradeSelectCallback;
    select.setAttribute("style", "font-size: .6em");
    select.style.display = '';
    _results.push(g.appendChild(select));
  }
  return _results;
};

windowLoadHandler = function(e) {
  var message;
  message = JSON.parse(e.data);
  switch (message['type']) {
    case 'updated-grade':
      return updateGrade(message);
    case 'display-grades':
      return displayGrades(message);
  }
};

addLoadEvent(function() {
  window.addEventListener("message", windowLoadHandler, false);
  return initGradeDisplay();
});

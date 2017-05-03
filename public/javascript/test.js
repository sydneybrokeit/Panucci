var hddComplete = false;
var memComplete = false;
var printed = false;

$(document).ready(function(){
  var timer = window.setInterval(updateStatus,1000);
});



function updateStatus() {
  $.getJSON("/status.json", function(status){
    var hddStatus = status.hddStatus;
    console.log("Set hddStatus");
    var memStatus = status.memoryStatus;
    console.log("Set memStatus");
    if (memComplete == false) {
      if (memStatus == 'PASS') {
        console.log("Made it into if statement");
        $("#memTest").removeClass("load fa-spin");
        $("#memTest").addClass("success");
        memComplete = true;
      } else if (memStatus == 'FAIL') {
        $("#memTest").removeClass("load fa-spin");
        $("#memTest").addClass("failure");
        memComplete = true;
      }
    }


    if (hddComplete == false) {
      if (hddStatus == 'PASS') {
        console.log("Made it into if statement");
        $("#hddTest").removeClass("load fa-spin");
        $("#hddTest").addClass("success");
        hddComplete = true;
      } else if (hddStatus == 'FAIL') {
        $("#hddTest").removeClass("load fa-spin");
        $("#hddTest").addClass("failure");
        hddComplete = true;
      } else if (hddStatus == "ERROR: SMART Not Supported by Drive") {
        $("#hddTest").removeClass("load fa-spin");
        $("#hddTest").addClass("question");
        hddComplete = true;
      }
    }

    if (hddComplete == true && memComplete == true && printed == false) {
      $.ajax({
        url: "/printlabel"
      }).done(function() {
        printed = true;
      });
    }

    if (hddStatus == 'PASS' && memStatus == 'PASS') {
      if (status.hasOwnProperty('modelMatch')) {
        modelStatus = status.modelMatch;
        procStatus = status.procMatch;
        if (modelStatus && procStatus) {
          $("#proceed").removeClass("disabled");
          $("#proceed").removeAttr("disabled");
          $("#proceed").attr("href", "/clone");
          $("#proceed").click(function() {
            $.ajax({
              url: "/logdb"
            });
          });
        }
      } else {
      console.log("hm.");
        $("#proceed").removeClass("disabled");
        $("#proceed").removeAttr("disabled");
        $("#proceed").attr("href", "/clone");
        $("#proceed").click(function() {
          $.ajax({
            url: "/logdb"
          });
        });
      }
    }
  });
}

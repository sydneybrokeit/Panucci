$(document).ready(function(){
  var timer = window.setInterval(updateStatus, 3000);
});


function updateStatus() {
  $.getJSON("/status.json", function(status){
    var hddStatus = status.hddStatus;
    console.log("Set hddStatus");
    var memStatus = status.memoryStatus;
    console.log("Set memStatus");
    if (memStatus == 'PASS') {
      console.log("Made it into if statement");
      $("#memTest").removeClass("fa fa-circle-o-notch fa-spin fa-3x fa-right");
      $("#memTest").addClass("fa fa-check fa-3x success fa-right");
    } else if (memStatus == 'FAIL') {
      $("#memTest").removeClass("fa fa-circle-o-notch fa-spin fa-3x fa-right");
      $("#memTest").addClass("fa fa-times fa-3x failure fa-right");
    }

    if (hddStatus == 'PASS') {
      console.log("Made it into if statement");
      $("#hddTest").removeClass("fa fa-circle-o-notch fa-spin fa-3x fa-right");
      $("#hddTest").addClass("fa fa-check fa-3x success fa-right");
    } else if (hddStatus == 'FAIL') {
      $("#hddTest").removeClass("fa fa-circle-o-notch fa-spin fa-3x fa-right");
      $("#hddTest").addClass("fa fa-times fa-3x failure fa-right");
    }

    if (hddStatus == 'FAIL' && memStatus == 'PASS') {
      console.log("hm.");
      $("#proceed").removeClass("disabled");
      $("#proceed").removeAttr("disabled")
    }
  });
}

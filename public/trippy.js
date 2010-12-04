$(function(){
  $('#commute_check').click(function(){
    if ($('#commute_check').attr("checked") == true){
      $('#tasks').hide();
      $('#location_field').attr("disabled", "");
      $('#destination_field').attr("disabled", "");
    } else {
      $('#tasks').show();
      $('#location_field').attr("disabled", "disabled");
      $('#destination_field').attr("disabled", "disabled");
    }
  });
	
})

var Trippy = {
	startJobChecker : function() {
		Trippy.checker_endpoint = "/articles_ready/" + articles_hash;
		window.job_checker = window.setInterval(Trippy.checkJobStatus,5000);
	},
	checkJobStatus : function() {
		$.get(Trippy.checker_endpoint, function(data) {
			var msg = data["msg"];
			if (msg === "not_ready") {
				$("h2.article_status").append(".");
			} else {
				clearInterval(window.job_checker);
				$("h2.article_status").empty();
				var i;
				for(i = 0; i < data["articles"]["articles"].length ; i++) {
					$("#articles").append("<li>" +
					 	"<h2>" + data["articles"]["articles"][i]["title"] + "<\/h2>" +
						data["articles"]["articles"][i]["text"] + "<\/li>");
				}
				$("h2.article_status").append("In your " + data["articles"]["journey_length"] + " minute long journey " +
					"you can read " + data["articles"]["articles"].length + " articles");
			}
		});
		
	},
	stopJobChecker : function() {
		clearInterval(window.job_checker);
	}
	
}
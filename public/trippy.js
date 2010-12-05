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
  $('#gps').click(function(){
    navigator.geolocation.getCurrentPosition(
      function(pos){
        geo = {};
        geo.lat = pos.coords.latitude;
        geo.lng = pos.coords.longitude;
        $('#location_field').attr("disabled","disabled");
        $('#location_field').val(geo.lat+" , "+geo.lng);
        $('#geo_long').val(geo.lng);
        $('#geo_lat').val(geo.lat);
      },
      function(){
        $('h2.article_status').html("Your location could not be found. Please enter it manually.").show();
      }
    );
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
			} else if(msg === "error"){
			  clearInterval(window.job_checker)
			  $("h2.article_status").empty().addClass("sad_article_status").append("Error! Please try again");
			} else {
				clearInterval(window.job_checker);
				$("h2.article_status").empty();
				var i;
				for(i = 0; i < data["articles"]["articles"].length ; i++) {
					$("#articles").append("<li>" +
					 	"<h2>" + data["articles"]["articles"][i]["title"] + "<\/h2>" +
						data["articles"]["articles"][i]["html"] + "<\/li>");
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

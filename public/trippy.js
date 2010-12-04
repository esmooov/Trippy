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

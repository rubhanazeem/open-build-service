$(document).ready(function() {
  $('.line-new-comment').on('click', function(){
    var lineNumber = $(this).data('id')
    var requestNumber = $(this).data('request-number')
    var actionId = $(this).data('action-id')
    var fileName = $(this).data('file-name')
    var url = '/request/' + requestNumber + '/request_action/' + actionId + '/inline_comment/' + lineNumber + '/?file_name=' + fileName

    $.ajax({
      url: url
    });
  })
})
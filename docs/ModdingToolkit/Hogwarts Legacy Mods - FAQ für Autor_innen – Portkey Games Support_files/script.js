/////////////////////////////// Alert Banner  ////////////////////////////////

// if (window.location.href == "https://mortalkombatgamessupport.wbgames.com/hc/en-us") {
  
// MW-Notification Banner
document.addEventListener('DOMContentLoaded', async function () {
  // Article label to be considered for the alerts
  const label = 'alert'

  // Show the article body within the alertbox? (Boolean: true/false)
  const showArticleBody = false

  // Get current help center locale
  const locale = document
    .querySelector('html')
    .getAttribute('lang')
    .toLowerCase()

  // URL to be called to get the alert data
  const url = `/api/v2/help_center/${locale}/articles.json?label_names=${label}`

  // Raw data collected from the endpoint above
  const data = await (await fetch(url)).json()

  // List of articles returned
  const articles = (data && data.articles) || []

  // Handle returned articles
  for (let i = 0; i < articles.length; i++) {
    const url = articles[i].html_url
    const title = articles[i].title
    const body = articles[i].body

    const html = `
      <div class="ns-box ns-bar ns-effect-slidetop ns-type-notice ns-show">
        <div class="ns-box-inner">
          <span class="megaphone"></span> <!-- Entypo fonts -->
          <!-- <i class="fa-solid fa-arrows-to-eye"></i> FontAwesome fonts -->
          <p>
            <a href="${url}">${title}</a>
            ${showArticleBody ? body : ''}
          </p>
        </div>
        <span class="ns-close"></span>
      </div>
    `

    // Append current alert to the alertbox container
    document.querySelector('.alertbox').insertAdjacentHTML('beforeend', html)
  }
})

document.addEventListener('click', function (event) {
  // Close alertbox
  if (event.target.matches('.ns-close')) {
    event.preventDefault()
    event.target.parentElement.remove()
  }
})

/////////////////////////////// End Alert Banner  ////////////////////////////////

//QR Code field support
$(document).ready(function() 
{ 
  $('#request_custom_fields_1500012913822').parent('.request_custom_fields_1500012913822').hide();
  $('#request_custom_fields_360026188474').parent('.request_custom_fields_360026188474').hide();
  $('#request_custom_fields_114098425151').parent('.request_custom_fields_114098425151').hide();
});

$(document).ready(function() {
  
var ticketForm = location.search.split('ticket_form_id=')[1];
if (ticketForm == 4416191958419)		
  { 
    $('#request_custom_fields_114100686932').val('harry_potter_magic_awakened');
  }
  
var tagsToRemove = ['developer_options','harry_potter_for_kinect','google_stadia','fantastic_beasts_cases','harry_potter_spells','harry_potter_wizards_unite','ipad__ipad_pro_2020','ipad__ipad_air_2020','apple_arcade','platform__wbga','baseball','harry_potter_magic_awakened'];
  removeTagsWeDontWant();
  
  function removeTagsWeDontWant()
  {
    const removeNodes = (node) => {
      for (let i = 0; i < node.childNodes.length; i++) {
        const wasRemoved = removeNodes(node.childNodes[i]);
        if (wasRemoved) {
          i--;
        }
      }

      if (node.nodeType === 1 && tagsToRemove.includes(node.getAttribute("id"))) {
        node.parentNode.removeChild(node);
        return true;
      }
      return false;
    };

    const observer = new MutationObserver(mutationList =>
      mutationList.filter(m => m.type === 'childList').forEach(m => {
        m.addedNodes.forEach(removeNodes); 
      }));  
    document.querySelectorAll('.nesty-panel').forEach(panel => observer.observe(panel,{childList: true, subtree: true}));
  }

  // social share popups
  $(".share a").click(function(e) {
    e.preventDefault();
    window.open(this.href, "", "height = 500, width = 500");
  });

  // show form controls when the textarea receives focus or backbutton is used and value exists
  var $commentContainerTextarea = $(".comment-container textarea"),
    $commentContainerFormControls = $(".comment-form-controls, .comment-ccs");

  $commentContainerTextarea.one("focus", function() {
    $commentContainerFormControls.show();
  });

  if ($commentContainerTextarea.val() !== "") {
    $commentContainerFormControls.show();
  }

  // Expand Request comment form when Add to conversation is clicked
  var $showRequestCommentContainerTrigger = $(".request-container .comment-container .comment-show-container"),
    $requestCommentFields = $(".request-container .comment-container .comment-fields"),
    $requestCommentSubmit = $(".request-container .comment-container .request-submit-comment");

  $showRequestCommentContainerTrigger.on("click", function() {
    $showRequestCommentContainerTrigger.hide();
    $requestCommentFields.show();
    $requestCommentSubmit.show();
    $commentContainerTextarea.focus();
  });

  // Mark as solved button
  var $requestMarkAsSolvedButton = $(".request-container .mark-as-solved:not([data-disabled])"),
    $requestMarkAsSolvedCheckbox = $(".request-container .comment-container input[type=checkbox]"),
    $requestCommentSubmitButton = $(".request-container .comment-container input[type=submit]");

  $requestMarkAsSolvedButton.on("click", function () {
    $requestMarkAsSolvedCheckbox.attr("checked", true);
    $requestCommentSubmitButton.prop("disabled", true);
    $(this).attr("data-disabled", true).closest("form").submit();
  });

  // Change Mark as solved text according to whether comment is filled
  var $requestCommentTextarea = $(".request-container .comment-container textarea");

  $requestCommentTextarea.on("keyup", function() {
    if ($requestCommentTextarea.val() !== "") {
      $requestMarkAsSolvedButton.text($requestMarkAsSolvedButton.data("solve-and-submit-translation"));
      $requestCommentSubmitButton.prop("disabled", false);
    } else {
      $requestMarkAsSolvedButton.text($requestMarkAsSolvedButton.data("solve-translation"));
      $requestCommentSubmitButton.prop("disabled", true);
    }
  });

  // Disable submit button if textarea is empty
  if ($requestCommentTextarea.val() === "") {
    $requestCommentSubmitButton.prop("disabled", true);
  }

  // Submit requests filter form in the request list page
  $("#request-status-select, #request-organization-select")
    .on("change", function() {
      search();
    });

  // Submit requests filter form in the request list page
  $("#quick-search").on("keypress", function(e) {
    if (e.which === 13) {
      search();
    }
  });

  function search() {
    window.location.search = $.param({
      query: $("#quick-search").val(),
      status: $("#request-status-select").val(),
      organization_id: $("#request-organization-select").val()
    });
  }

  $(".header .icon-menu").on("click", function(e) {
    e.stopPropagation();
    var menu = document.getElementById("user-nav");
    var isExpanded = menu.getAttribute("aria-expanded") === "true";
    menu.setAttribute("aria-expanded", !isExpanded);
  });

  if ($("#user-nav").children().length === 0) {
    $(".header .icon-menu").hide();
  }

  // Submit organization form in the request page
  $("#request-organization select").on("change", function() {
    this.form.submit();
  });

  // Toggles expanded aria to collapsible elements
  $(".collapsible-nav, .collapsible-sidebar").on("click", function(e) {
    e.stopPropagation();
    var isExpanded = this.getAttribute("aria-expanded") === "true";
    this.setAttribute("aria-expanded", !isExpanded);
  });
  
  // unsubscribe users to all topics/posts/sections/articles START
 // if(HelpCenter.user.role === 'end-user') {
    console.log('fire')
  var getLocation = function(href) {
    var l = document.createElement("a");
    l.href = href;
    return l;
  };
  $.getJSON("/api/v2/help_center/users/me/subscriptions.json", function(data) { 
          var output = "";
          for (var i in data.subscriptions) {
            var x = getLocation(data.subscriptions[i].url);
            console.log(x.pathname)
            $.ajax({
                url: x.pathname,
                contentType:'application/json',
                type: 'DELETE',
            }); 
          }
  });
//}
  // unsubscribe users to all topics/posts/sections/articles END
  
});

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

Turbo.StreamActions.scroll_to_bottom = function () {
  const endOfConversation = document.getElementById("end-of-conversation");

  if (endOfConversation == null) {
    console.log("WARNING: could not find 'end-of-conversation' element.")
  } else {
    endOfConversation.scrollIntoView();
  }
}
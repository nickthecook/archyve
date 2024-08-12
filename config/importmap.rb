# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "marked" # @12.0.1
pin "highlight.js", to: "https://ga.jspm.io/npm:highlight.js@11.9.0/es/index.js"
pin "@stimulus-components/clipboard", to: "@stimulus-components--clipboard.js" # @5.0.0
